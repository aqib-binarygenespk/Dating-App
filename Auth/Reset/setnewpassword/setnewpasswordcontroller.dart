// lib/Auth/Reset/setnewpassword/setnewpasswordcontroller.dart
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:dating_app/services/api_services.dart'; // same ApiService you use elsewhere
import 'package:dating_app/themesfolder/theme.dart';

class SetNewPasswordController extends GetxController {
  final newPasswordController = TextEditingController();
  final confirmPasswordController = TextEditingController();

  final isPasswordVisible = false.obs;
  final isConfirmPasswordVisible = false.obs;
  final isLoading = false.obs;

  // Passed from previous screen: { 'email': ..., 'token': ... }
  late final String token;
  late final String email;

  static const _endpointPrefix = 'update-password'; // /update-password/{token}

  @override
  void onInit() {
    super.onInit();
    final args = Get.arguments ?? {};
    token = (args['token'] ?? '').toString();
    email = (args['email'] ?? '').toString();

    if (token.isEmpty) {
      // Fail fast if navigation didn’t pass the token
      _showErrorDialog(
        title: 'Missing token',
        message:
        'A reset token was not provided. Please restart the reset flow.',
        onOk: () => Get.back(),
      );
    }
  }

  // === UI toggles ===
  void togglePasswordVisibility() =>
      isPasswordVisible.value = !isPasswordVisible.value;

  void toggleConfirmPasswordVisibility() =>
      isConfirmPasswordVisible.value = !isConfirmPasswordVisible.value;

  // === Main action ===
  Future<void> updatePassword(BuildContext context) async {
    final newPassword = newPasswordController.text.trim();
    final confirmPassword = confirmPasswordController.text.trim();

    // Client-side validations
    if (newPassword.isEmpty || confirmPassword.isEmpty) {
      _showErrorDialog(
        title: 'Missing Fields',
        message: 'Please fill in both password fields.',
      );
      return;
    }
    if (newPassword.length < 8) {
      _showErrorDialog(
        title: 'Weak Password',
        message: 'Password must be at least 8 characters long.',
      );
      return;
    }
    if (newPassword != confirmPassword) {
      _showErrorDialog(
        title: 'Password Mismatch',
        message: 'Both passwords must match.',
      );
      return;
    }
    if (token.isEmpty) {
      _showErrorDialog(
        title: 'Invalid token',
        message:
        'Reset token missing. Please request a new password reset link.',
      );
      return;
    }

    try {
      isLoading.value = true;

      // POST /update-password/{token}
      final res = await ApiService.postJson(
        '$_endpointPrefix/$token',
        {
          'password': newPassword,
          'password_confirmation': confirmPassword,
        },
      );

      // Expecting { message: 'Password updated successfully now login' } with 200
      final isOk = res is Map && (res['message'] is String);
      if (!isOk) {
        final msg = (res is Map && res['error'] is String)
            ? res['error'] as String
            : (res is Map && res['message'] is String)
            ? res['message'] as String
            : 'Unable to update password. Please try again.';
        _showErrorDialog(title: 'Update Failed', message: msg);
        return;
      }

      // Success UI + navigate to Login
      Get.snackbar(
        'Success',
        'Password updated successfully. You can login now.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.green,
        colorText: AppTheme.backgroundColor,
      );

      // Replace route name with your actual login route if different
      Get.offAllNamed('/login');
    } catch (e) {
      _showErrorDialog(
        title: 'Network Error',
        message: 'Please check your connection and try again.',
      );
    } finally {
      isLoading.value = false;
    }
  }

  // === Helpers ===
  void _showErrorDialog({
    required String title,
    required String message,
    VoidCallback? onOk,
  }) {
    showDialog(
      context: Get.context!,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: onOk ?? () => Navigator.of(Get.context!).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  void onClose() {
    newPasswordController.dispose();
    confirmPasswordController.dispose();
    super.onClose();
  }
}
