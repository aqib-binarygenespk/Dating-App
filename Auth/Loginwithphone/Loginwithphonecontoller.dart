import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:hive/hive.dart';

import '../../services/api_services.dart';
import '../../hive_utils/hive_boxes.dart';
import '../../Dashbaord/dashboard/Dashboard.dart';
import '../../Dashbaord/profile/profile_controller.dart';
import 'loginwithphonecode.dart';
import 'package:dating_app/utils/jwt_utils.dart'; // helps extract user_id from JWT

class LoginWithPhoneController extends GetxController {
  final TextEditingController phoneController = TextEditingController();
  // Should be a full international number, e.g. +923001234567
  String internationalPhone = '';
  final RxBool isLoading = false.obs;

  static const _hiveSessionTokenKey = 'session_token';

  /// Basic local check for digits if you're letting users type without '+'
  String? validatePhone(String? number) {
    if (number == null || number.trim().isEmpty) {
      return 'Phone number is required';
    }
    // Only digits 9–15 (used if you have a local numeric field)
    if (!RegExp(r'^[0-9]{9,15}$').hasMatch(number.trim())) {
      return 'Please enter a valid phone number';
    }
    return null;
  }

  /// Remove spaces/dashes/parentheses but keep the leading '+'
  String _normalizeE164(String input) {
    return input.replaceAll(RegExp(r'[-\s()]'), '');
  }

  /// Step 1: Request login code
  Future<void> sendCode() async {
    final e164 = _normalizeE164(internationalPhone);

    // Strict E.164 per backend
    if (!RegExp(r'^\+[1-9]\d{1,14}$').hasMatch(e164)) {
      Get.snackbar(
        'Error',
        'Enter a valid phone number in international format (e.g., +923001234567)',
        backgroundColor: const Color(0xFFB00020),
        colorText: Colors.white,
      );
      return;
    }

    try {
      isLoading.value = true;

      // Backend sample: POST /api/sendlogincode
      // Returns: { success, message, token, token_type }
      final resp = await ApiService.postJson('sendlogincode', {
        "phone_number": e164,
        "type": "login", // harmless extra; backend ignores it
      });

      final ok = resp['success'] == true;
      final msg = (resp['message'] ?? '').toString();

      if (!ok) {
        // Attempt to surface validation errors, etc.
        final errors = resp['errors'];
        String detail = '';
        if (errors is Map && errors.isNotEmpty) {
          final firstKey = errors.keys.first;
          final list = errors[firstKey];
          if (list is List && list.isNotEmpty) detail = ' — ${list.first}';
        }
        Get.snackbar(
          'Failed',
          msg.isNotEmpty ? '$msg$detail' : 'Could not send code$detail',
          backgroundColor: const Color(0xFFB00020),
          colorText: Colors.white,
        );
        return;
      }

      // MUST: capture session token (session_id) from backend
      final sessionToken = (resp['token'] ?? '').toString().trim();
      if (sessionToken.isEmpty) {
        Get.snackbar(
          'Error',
          'No session token returned by server.',
          backgroundColor: const Color(0xFFB00020),
          colorText: Colors.white,
        );
        return;
      }

      // persist for safety (and pass via arguments as well)
      final box = Hive.box(HiveBoxes.userBox);
      await box.put(_hiveSessionTokenKey, sessionToken);

      Get.snackbar('Info', msg.isNotEmpty ? msg : 'Login OTP sent');

      // Navigate to OTP screen
      Get.to(
            () => const LoginWithPhoneCodeScreen(),
        arguments: {
          'phone': e164,
          'type': 'login',
          'session_token': sessionToken, // important
        },
      );
    } catch (e) {
      Get.snackbar(
        'Error',
        e.toString(),
        backgroundColor: const Color(0xFFB00020),
        colorText: Colors.white,
      );
    } finally {
      isLoading.value = false;
    }
  }

  /// Step 2: Verify the code and log in
  ///
  /// Call this from LoginWithPhoneCodeScreen when the user enters the OTP.
  Future<void> verifyCodeAndLogin({
    required String phoneE164,
    required String code,
    String? sessionToken, // prefer passing in; we also fallback to Hive
  }) async {
    try {
      isLoading.value = true;

      // Fallback to stored token if not passed
      final box = Hive.box(HiveBoxes.userBox);
      final effectiveSessionToken =
      (sessionToken ?? box.get(_hiveSessionTokenKey)?.toString() ?? '').trim();

      if (effectiveSessionToken.isEmpty) {
        Get.snackbar(
          'Error',
          'Missing session token. Please request a new code.',
          backgroundColor: const Color(0xFFB00020),
          colorText: Colors.white,
        );
        return;
      }

      final resp = await ApiService.postJson(
        'verifylogincode',
        {
          "phone_number": phoneE164,
          "code": code,
          "type": "login",
        },
        token: effectiveSessionToken, // << attach as Bearer
      );

      if (resp['success'] == true) {
        final data = resp['data'] ?? {};
        final jwt = data['token'];
        final firebaseUid = data['firebase_uid'];
        final firebaseCustomTokenFromLogin = data['firebase_custom_token'];

        // Persist auth & profile basics
        await box.put('auth_token', jwt);
        if (firebaseUid != null) await box.put('firebase_uid', firebaseUid);

        // Extract numeric user_id from JWT "sub"
        final myId = JwtUtils.tryExtractUserId(jwt?.toString());
        if (myId != null && myId > 0) {
          await box.put('user_id', myId);
          await box.put('id', myId);
          // ignore: avoid_print
          print('✅ Saved user_id=$myId from JWT');
        } else {
          // ignore: avoid_print
          print('⚠️ Could not extract user_id from JWT');
        }

        // Optional user object
        if (data['user'] != null) {
          final user = data['user'];
          await box.put('name', user['name']);
          final idFromUser = int.tryParse('${user['id']}');
          if (idFromUser != null && idFromUser > 0) {
            await box.put('user_id', idFromUser);
            await box.put('id', idFromUser);
          }
          final avatar = (user['photo'] ??
              user['profile_image'] ??
              user['avatar_url'])
              ?.toString();
          if (avatar != null && avatar.trim().isNotEmpty) {
            await box.put('profile_image', avatar);
          }
        }

        await _signIntoFirebase(
          customTokenFromLogin: firebaseCustomTokenFromLogin,
          expectedUid: firebaseUid,
        );

        // Fetch profile to warm up app state
        final profileController = Get.put(ProfileController());
        await profileController.fetchProfile();

        // Clean up session token once verified
        await box.delete(_hiveSessionTokenKey);

        // Dev snapshot
        // ignore: avoid_print
        print('👀 userBox snapshot => {'
            'user_id: ${box.get('user_id')}, '
            'id: ${box.get('id')}, '
            'auth_token: ${box.get('auth_token') != null ? 'set' : 'null'}, '
            'firebase_uid: ${box.get('firebase_uid')}'
            '}');

        Get.offAll(() => const DashboardScreen());
        Get.snackbar('Success', 'Logged in!');
      } else {
        final msg = resp['message']?.toString() ?? 'Verification failed';
        Get.snackbar(
          'Error',
          msg,
          backgroundColor: const Color(0xFFB00020),
          colorText: Colors.white,
        );
      }
    } catch (e) {
      Get.snackbar(
        'Error',
        e.toString(),
        backgroundColor: const Color(0xFFB00020),
        colorText: Colors.white,
      );
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> _signIntoFirebase({
    String? customTokenFromLogin,
    String? expectedUid,
  }) async {
    final auth = FirebaseAuth.instance;
    try {
      final customToken =
          customTokenFromLogin ?? await _fetchFirebaseCustomToken();
      final cred = await auth.signInWithCustomToken(customToken);
      // ignore: avoid_print
      print('✅ Firebase signed in as UID: ${cred.user?.uid}');
      if (expectedUid != null && cred.user?.uid != expectedUid) {
        // ignore: avoid_print
        print(
            '⚠️ Firebase UID mismatch (server: $expectedUid, client: ${cred.user?.uid})');
      }
    } catch (e) {
      // ignore: avoid_print
      print('❌ Firebase sign-in failed: $e');
      Get.snackbar(
        'Firebase',
        'Could not sign into Firebase: $e',
        backgroundColor: const Color(0xFFB00020),
        colorText: Colors.white,
      );
    }
  }

  Future<String> _fetchFirebaseCustomToken() async {
    final res = await ApiService.post('firebase/custom-token', {});
    if (res['success'] == true &&
        (res['token'] ?? res['firebase_custom_token']) != null) {
      return (res['token'] ?? res['firebase_custom_token']).toString();
    }
    throw Exception(res['message'] ?? 'Could not get Firebase custom token');
  }

  @override
  void onClose() {
    phoneController.dispose();
    super.onClose();
  }
}
