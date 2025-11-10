import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hive/hive.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../services/api_services.dart';
import '../../hive_utils/hive_boxes.dart';
import '../../Dashbaord/dashboard/Dashboard.dart';
import '../../Dashbaord/profile/profile_controller.dart';

class LoginWithPhoneCodeController extends GetxController {
  // ---- reactive UI state ----
  final timerSeconds = 0.obs;      // remaining seconds in countdown
  final isTimeUp = true.obs;       // true when resend is allowed
  final isVerifying = false.obs;   // verify button loading
  final isSending = false.obs;     // resend button loading

  final maskedNumber = 'xxxx'.obs; // e.g. +9230xxxxxx67
  final enteredOtp = ''.obs;       // 4-digit code

  final List<TextEditingController> controllers =
  List.generate(4, (_) => TextEditingController());

  Timer? _timer;

  // ---- args we expect from previous screen ----
  late final String phoneNumber;      // +92300...
  late String sessionToken;           // UUID from /sendlogincode
  late final String flowType;         // "login" | "signup" (not used by backend here)

  // Laravel endpoints
  static const String _sendLoginCodeEndpoint   = 'sendlogincode';
  static const String _verifyLoginCodeEndpoint = 'verifylogincode';

  // Local countdown target: backend expiry is 10 minutes; we mirror that client-side
  static const int _otpLifespanSeconds = 600; // 10 * 60

  void _safeSnack(String title, String msg, {Color? bg}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Get.snackbar(title, msg,
          backgroundColor: bg ?? Colors.black87, colorText: Colors.white);
    });
  }

  @override
  void onInit() {
    super.onInit();
    final args = Get.arguments ?? {};
    phoneNumber = (args['phone'] as String?)?.trim() ?? '';
    sessionToken = (args['session_token'] as String?)?.trim() ?? '';
    flowType =
    (args['type'] as String?)?.toLowerCase() == 'signup' ? 'signup' : 'login';

    if (phoneNumber.isEmpty || !phoneNumber.startsWith('+') || sessionToken.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Get.back();
        _safeSnack('Error', 'Missing phone/session token. Please try again.', bg: Colors.redAccent);
      });
      return;
    }

    maskedNumber.value = _maskPhone(phoneNumber);

    for (final c in controllers) {
      c.addListener(() {
        enteredOtp.value = controllers.map((e) => e.text.trim()).join();
      });
    }

    // Start a fresh 10-minute timer (server expiry)
    _startTimer(_otpLifespanSeconds);
  }

  String _maskPhone(String e164) {
    if (e164.length <= 6) return e164;
    final start = 4;
    final end = e164.length - 2;
    return e164.replaceRange(start, end, 'xxxx');
  }

  // ---- timer helpers ----
  void _startTimer(int seconds) {
    _timer?.cancel();
    if (seconds <= 0) {
      isTimeUp.value = true;
      timerSeconds.value = 0;
      return;
    }
    timerSeconds.value = seconds;
    isTimeUp.value = false;

    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (timerSeconds.value > 0) {
        timerSeconds.value--;
      } else {
        isTimeUp.value = true;
        t.cancel();
      }
    });
  }

  // ---- actions ----
  Future<void> resend() async {
    if (!isTimeUp.value || isSending.value) return;

    try {
      isSending.value = true;

      // Backend expects: { phone_number: "+923001234567" }
      final resp = await ApiService.postJson(_sendLoginCodeEndpoint, {
        "phone_number": phoneNumber,
        "type": "login", // harmless; backend ignores extra key
      });

      final ok = resp['success'] == true;
      final msg = (resp['message'] ?? 'Code re-sent').toString();

      if (!ok) {
        final errors = resp['errors'];
        String detail = '';
        if (errors is Map && errors.isNotEmpty) {
          final firstKey = errors.keys.first;
          final list = errors[firstKey];
          if (list is List && list.isNotEmpty) detail = ' — ${list.first}';
        }
        _safeSnack('Failed', '$msg$detail', bg: Colors.redAccent);
        return;
      }

      // IMPORTANT: server returns a NEW session token (uuid)
      final newToken = (resp['token'] ?? '').toString().trim();
      if (newToken.isEmpty) {
        _safeSnack('Error', 'Server did not return a new session token.', bg: Colors.redAccent);
        return;
      }
      sessionToken = newToken;

      // Restart local 10-minute timer
      _startTimer(_otpLifespanSeconds);
      _safeSnack('Info', msg.isNotEmpty ? msg : 'OTP re-sent');
    } catch (e) {
      _safeSnack('Error', e.toString(), bg: Colors.redAccent);
    } finally {
      isSending.value = false;
    }
  }

  Future<void> verifyAndProceed() async {
    final code = enteredOtp.value;
    if (code.length != 4 || int.tryParse(code) == null) {
      _safeSnack('Oops', 'Enter the 4-digit code', bg: Colors.redAccent);
      return;
    }

    try {
      isVerifying.value = true;

      // Backend requires: { token: <uuid>, otp_code: "1234" }
      final resp = await ApiService.postJson(_verifyLoginCodeEndpoint, {
        "token": sessionToken,
        "otp_code": code,
      });

      if (resp['success'] == true) {
        // JWT
        final jwt = (resp['token'] ?? resp['data']?['token'] ?? '').toString();
        // Firebase Custom Token
        final firebaseCustomToken =
        (resp['firebase_custom_token'] ?? resp['data']?['firebase_custom_token'])
            ?.toString();

        final box = Hive.box(HiveBoxes.userBox);
        if (jwt.isNotEmpty) {
          await box.put('auth_token', jwt);
        }

        // Optional user object
        final user = (resp['user'] ?? resp['data']?['user']);
        if (user is Map && user.isNotEmpty) {
          if (user['name'] != null) await box.put('name', user['name']);
          if (user['id'] != null) await box.put('user_id', user['id']);
          if (user['phone_number'] != null) await box.put('phone_number', user['phone_number']);
          // if server includes firebase_uid inside user, store it too (optional)
          if (user['firebase_uid'] != null) await box.put('firebase_uid', user['firebase_uid']);
          // common avatar fields if any
          final avatar = (user['photo'] ?? user['profile_image'] ?? user['avatar_url'])?.toString();
          if (avatar != null && avatar.trim().isNotEmpty) {
            await box.put('profile_image', avatar);
          }
        }

        // Sign into Firebase (custom token provided by backend)
        if (firebaseCustomToken != null && firebaseCustomToken.isNotEmpty) {
          await _signIntoFirebaseWithCustomToken(firebaseCustomToken);
        }

        // Warm up profile
        final profileController = Get.put(ProfileController());
        await profileController.fetchProfile();

        isVerifying.value = false;
        Get.snackbar("Success", "Login successful!");
        Get.offAll(() => const DashboardScreen());
      } else {
        isVerifying.value = false;

        final msg = (resp['message'] ?? 'Verification failed').toString();
        _safeSnack('Invalid Code', msg, bg: Colors.redAccent);
      }
    } catch (e) {
      isVerifying.value = false;
      _safeSnack('Error', e.toString(), bg: Colors.redAccent);
    }
  }

  Future<void> _signIntoFirebaseWithCustomToken(String customToken) async {
    try {
      final auth = FirebaseAuth.instance;
      final cred = await auth.signInWithCustomToken(customToken);
      // ignore: avoid_print
      print('✅ Firebase signed in as UID: ${cred.user?.uid}');
    } catch (e) {
      // ignore: avoid_print
      print('❌ Firebase sign-in failed: $e');
      _safeSnack('Firebase', 'Could not sign into Firebase: $e', bg: Colors.redAccent);
    }
  }

  @override
  void onClose() {
    _timer?.cancel();
    for (final c in controllers) {
      c.dispose();
    }
    super.onClose();
  }
}
