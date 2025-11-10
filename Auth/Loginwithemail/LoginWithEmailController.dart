import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hive/hive.dart';
import 'package:flutter/foundation.dart'; // kDebugMode
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart'; // 👈 for Storage probe

import '../../services/api_services.dart';
import '../../hive_utils/hive_boxes.dart';
import '../../Dashbaord/dashboard/Dashboard.dart';
import '../../Dashbaord/profile/profile_controller.dart';
import '../activate/activateui.dart';
import 'package:dating_app/utils/jwt_utils.dart'; // 👈 helps extract user_id from JWT

// ===== Error Dialog =====
void showLoginErrorDialog(String message) {
  Get.dialog(
    Center(
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: 300,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 10,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 48),
              const SizedBox(height: 12),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 16,
                  color: Colors.black87,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Get.back(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const Text("Ok", style: TextStyle(color: Colors.white, fontSize: 16)),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
    barrierDismissible: false,
  );
}

// ===== Controller =====
class LoginWithEmailController extends GetxController {
  var email = ''.obs;
  var password = ''.obs;

  var emailError = ''.obs;
  var passwordError = ''.obs;
  var isLoading = false.obs;

  Future<void> login() async {
    emailError.value = '';
    passwordError.value = '';
    isLoading.value = true;

    if (email.value.isEmpty) emailError.value = 'Email is required';
    if (password.value.isEmpty) passwordError.value = 'Password is required';
    if (emailError.value.isNotEmpty || passwordError.value.isNotEmpty) {
      isLoading.value = false;
      return;
    }

    final payload = {
      'email': email.value.trim(),
      'password': password.value.trim(),
    };

    try {
      final response = await ApiService.post('login', payload, isJson: true);
      // ignore: avoid_print
      print("🔑 Login API Response: $response");

      if (response['success'] == true) {
        final data = response['data'] ?? {};
        final jwt = data['token'];
        final firebaseUid = data['firebase_uid'];
        final firebaseCustomTokenFromLogin = data['firebase_custom_token'];

        final box = Hive.box(HiveBoxes.userBox);
        await box.put('auth_token', jwt);
        if (firebaseUid != null) await box.put('firebase_uid', firebaseUid);

        // 👇 persist numeric user_id from JWT "sub"
        final myId = JwtUtils.tryExtractUserId(jwt?.toString());
        if (myId != null && myId > 0) {
          await box.put('user_id', myId);
          await box.put('id', myId); // alias for safety
          // ignore: avoid_print
          print('✅ Saved user_id=$myId from JWT');
        } else {
          // ignore: avoid_print
          print('⚠️ Could not extract user_id from JWT');
        }

        // Optional: if backend ever returns user object with id/name/avatar
        if (data['user'] != null) {
          final user = data['user'];
          await box.put('name', user['name']);
          final idFromUser = int.tryParse('${user['id']}');
          if (idFromUser != null && idFromUser > 0) {
            await box.put('user_id', idFromUser);
            await box.put('id', idFromUser);
          }
          final avatar = (user['photo'] ?? user['profile_image'] ?? user['avatar_url'])?.toString();
          if (avatar != null && avatar.trim().isNotEmpty) {
            await box.put('profile_image', avatar);
          }
        }

        // ✅ Firebase sign-in
        await _signIntoFirebase(
          customTokenFromLogin: firebaseCustomTokenFromLogin,
          expectedUid: firebaseUid,
        );

        // Pull profile (also populates avatar/fields locally)
        final profileController = Get.put(ProfileController());
        await profileController.fetchProfile();

        // Dev snapshot
        // ignore: avoid_print
        print('👀 userBox snapshot => {'
            'user_id: ${box.get('user_id')}, '
            'id: ${box.get('id')}, '
            'auth_token: ${box.get('auth_token') != null ? 'set' : 'null'}, '
            'firebase_uid: ${box.get('firebase_uid')}'
            '}');

        isLoading.value = false;
        Get.snackbar("Success", "Login successful!");
        Get.offAll(() => const DashboardScreen());
      } else {
        isLoading.value = false;

        // ✅ Detect deactivated account
        final isDeactivated = response['code'] == 'ACCOUNT_DEACTIVATED' ||
            (response['message']?.toString().toLowerCase().contains('deactivate') ?? false);
        if (isDeactivated) {
          _showReactivateDialog();
        } else {
          showLoginErrorDialog("Incorrect email or password.\nPlease try again.");
        }
      }
    } catch (e) {
      isLoading.value = false;
      // ignore: avoid_print
      print("❌ Login error: $e");
      showLoginErrorDialog("Login failed: ${e.toString()}");
    }
  }

  Future<void> _signIntoFirebase({
    String? customTokenFromLogin,
    String? expectedUid,
  }) async {
    final auth = FirebaseAuth.instance;
    try {
      final customToken = customTokenFromLogin ?? await _fetchFirebaseCustomToken();
      final cred = await auth.signInWithCustomToken(customToken);
      // ignore: avoid_print
      print('✅ Firebase signed in as UID: ${cred.user?.uid}');
      if (expectedUid != null && cred.user?.uid != expectedUid) {
        // ignore: avoid_print
        print('⚠️ Firebase UID mismatch (server: $expectedUid, client: ${cred.user?.uid})');
      }

      // 👉 Run the Storage quick probe **after** sign-in (debug only)
      if (kDebugMode) {
        await _storageQuickProbe();
      }
    } catch (e) {
      // ignore: avoid_print
      print('❌ Firebase sign-in failed: $e');
      Get.snackbar('Firebase', 'Could not sign into Firebase: $e',
          backgroundColor: const Color(0xFFB00020), colorText: Colors.white);
    }
  }

  Future<String> _fetchFirebaseCustomToken() async {
    // Expecting backend route that returns {"success": true, "token": "<customToken>"}
    final res = await ApiService.post('firebase/custom-token', {});
    if (res['success'] == true && (res['token'] ?? res['firebase_custom_token']) != null) {
      return (res['token'] ?? res['firebase_custom_token']).toString();
    }
    throw Exception(res['message'] ?? 'Could not get Firebase custom token');
  }

  // ===== Storage Quick Probe (debug diagnostic) =====
  Future<void> _storageQuickProbe() async {
    final ref = FirebaseStorage.instance
        .ref('_health/quick_${DateTime.now().millisecondsSinceEpoch}.txt');
    try {
      await ref.putString('ok', metadata: SettableMetadata(contentType: 'text/plain'));
      final url = await ref.getDownloadURL();
      debugPrint('✅ Storage quick write OK: $url');
    } on FirebaseException catch (e) {
      debugPrint('❌ Storage quick write failed: code=${e.code} message=${e.message}');
    } catch (e) {
      debugPrint('❌ Storage quick write failed: $e');
    }
  }

  void _showReactivateDialog() {
    Get.dialog(
      Center(
        child: Material(
          color: Colors.transparent,
          child: Container(
            width: 320,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 10)],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.lock_outline, color: Colors.orange, size: 48),
                const SizedBox(height: 12),
                const Text("Account Deactivated",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.black87)),
                const SizedBox(height: 8),
                const Text(
                  "Your account is deactivated. Would you like to reactivate it?",
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 15, color: Colors.black54),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Get.back(),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text("Cancel"),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          Get.back();
                          Get.to(() => const ActivateNumberScreen());
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text("Reactivate", style: TextStyle(color: Colors.white)),
                      ),
                    ),
                  ],
                )
              ],
            ),
          ),
        ),
      ),
      barrierDismissible: false,
    );
  }
}
