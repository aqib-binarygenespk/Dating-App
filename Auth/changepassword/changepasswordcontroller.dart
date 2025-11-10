// lib/Auth/ChangePassword/changepasswordcontroller.dart
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'package:dating_app/hive_utils/hive_boxes.dart';
import 'package:dating_app/services/api_services.dart';

import '../welcomescreen/welcomescreen.dart';

class ChangePasswordController extends GetxController {
  // Text fields
  final currentPasswordController = TextEditingController();
  final newPasswordController = TextEditingController();
  final confirmNewPasswordController = TextEditingController();

  // UI state
  final isCurrentVisible = false.obs;
  final isNewVisible = false.obs;
  final isConfirmNewVisible = false.obs;
  final isLoading = false.obs;

  void toggleCurrentVisibility() =>
      isCurrentVisible.value = !isCurrentVisible.value;
  void toggleNewVisibility() =>
      isNewVisible.value = !isNewVisible.value;
  void toggleConfirmNewVisibility() =>
      isConfirmNewVisible.value = !isConfirmNewVisible.value;

  String get _token {
    final box = Hive.box(HiveBoxes.userBox);
    final raw = box.get('auth_token') ?? box.get('token') ?? box.get('access_token');
    return (raw == null) ? '' : raw.toString().trim();
  }

  Future<void> submit(BuildContext context) async {
    final current = currentPasswordController.text.trim();
    final next = newPasswordController.text.trim();
    final confirm = confirmNewPasswordController.text.trim();

    // Local validations
    if (current.isEmpty || next.isEmpty || confirm.isEmpty) {
      _toast('Please fill all fields.');
      return;
    }
    if (next.length < 8) {
      _toast('New password must be at least 8 characters.');
      return;
    }
    if (next != confirm) {
      _toast('New passwords do not match.');
      return;
    }
    if (_token.isEmpty) {
      _toast('You are logged out. Please sign in again.');
      return;
    }

    isLoading.value = true;
    try {
      final res = await ApiService.postForm(
        'change-password',
        {
          'current_password': current,
          'password': next,
          'password_confirmation': confirm,
        },
        token: _token, // backend uses $request->user()
      );

      final ok = (res['success'] == true) || (res['status'] == true);
      if (ok) {
        _toast('Password changed successfully. Please log in again.');
        // Optionally clear local session here if you store tokens/etc.
        // Hive.box(HiveBoxes.userBox).delete('auth_token'); // example
        Get.offAll(() => const WelcomeScreen());
      } else {
        final msg = (res['message']?.toString().trim().isNotEmpty ?? false)
            ? res['message'].toString()
            : 'Failed to change password.';
        _toast(msg);
      }
    } catch (e) {
      final msg = e.toString();
      if (msg.contains('422')) {
        _toast('Validation failed. Please check your inputs.');
      } else if (msg.contains('400')) {
        // Backend examples: incorrect current password OR same as current
        if (msg.toLowerCase().contains('incorrect')) {
          _toast('Current password is incorrect.');
        } else {
          _toast('New password must be different from current password.');
        }
      } else {
        _toast('Something went wrong. Please try again.');
      }
    } finally {
      isLoading.value = false;
    }
  }

  void _toast(String message) {
    Get.snackbar(
      'Notice',
      message,
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: const Color(0xFF111111),
      colorText: const Color(0xFFFFFFFF),
      margin: const EdgeInsets.all(12),
      duration: const Duration(seconds: 3),
    );
  }

  @override
  void onClose() {
    currentPasswordController.dispose();
    newPasswordController.dispose();
    confirmNewPasswordController.dispose();
    super.onClose();
  }
}
