import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:dating_app/services/api_services.dart'; // <- same ApiService you use elsewhere
import 'package:dating_app/themesfolder/theme.dart';
import '../../../themesfolder/alertmessageprofiel/alertprofile.dart';


class ResetPasswordController extends GetxController {
  final emailController = TextEditingController();
  final isLoading = false.obs;

  static const _resetEndpoint = 'reset-password'; // POST { email }
  static const _verifyEndpoint = 'verify-otp';    // POST { email, code }

  bool _isValidEmail(String email) => GetUtils.isEmail(email);

  /// Step 1: ask backend to send OTP, then open OTP dialog.
  Future<void> sendResetLink() async {
    final email = emailController.text.trim();

    if (!_isValidEmail(email)) {
      Get.snackbar(
        "Invalid Email",
        "Please enter a valid email address.",
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.redAccent,
        colorText: Colors.white,
      );
      return;
    }

    try {
      isLoading.value = true;

      // Call your backend: POST /reset-password
      final res = await ApiService.postJson(_resetEndpoint, {'email': email});

      // The backend returns 200 whether the email exists or not to avoid enumeration.
      final success = (res is Map && (res['success'] == true || res['message'] != null));
      if (!success) {
        _toast("Couldn’t send code. Please try again.");
        return;
      }

      // Optionally, for dev you might get res['code'] (but we won't trust it).
      // Open OTP dialog that collects the 4-digit code from the user:
      CustomDialog.showPasswordSentDialog(
        email: email,
        onConfirm: (String enteredCode) async {
          await _verifyOtpAndProceed(email: email, code: enteredCode);
        },
        onResend: () async {
          // Re-hit the endpoint and re-open dialog
          await sendResetLink();
        },
      );
    } catch (e) {
      _toast("Network error. Please try again.");
    } finally {
      isLoading.value = false;
    }
  }

  /// Step 2: verify OTP against backend. If OK, navigate to set new password.
  Future<void> _verifyOtpAndProceed({
    required String email,
    required String code,
  }) async {
    try {
      isLoading.value = true;

      // Call your backend: POST /verify-otp
      final res = await ApiService.postJson(_verifyEndpoint, {
        'email': email,
        'code': code,
      });

      if (res is! Map || res['token'] == null) {
        // Backend sends 400 with {message:'Invalid or expired OTP'} on failure
        final msg = (res is Map && res['message'] is String)
            ? res['message'] as String
            : 'Invalid or expired code';
        _errorDialog("Verification failed", msg);
        return;
      }

      final token = res['token'].toString();

      // Success → go to next screen with token + email
      Get.offNamed('/setnewpassword', arguments: {
        'email': email,
        'token': token,
      });

      Get.snackbar(
        "Verified",
        "OTP verified. Please set your new password.",
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.green,
        colorText: Colors.white,
      );
    } catch (e) {
      _errorDialog("Verification failed", "Please check the code and try again.");
    } finally {
      isLoading.value = false;
    }
  }

  // --- Helpers ---
  void _toast(String msg) {
    Get.snackbar(
      "Notice",
      msg,
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: Colors.black,
      colorText: AppTheme.backgroundColor,
    );
  }

  void _errorDialog(String title, String message) {
    CustomDialog.showError(
      title: title,
      message: message,
    );
  }

  @override
  void onClose() {
    emailController.dispose();
    super.onClose();
  }
}
