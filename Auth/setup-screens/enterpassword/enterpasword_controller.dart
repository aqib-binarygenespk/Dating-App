import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hive/hive.dart';
import '../../../services/api_services.dart';
import '../../../hive_utils/hive_boxes.dart';

class EnterPasswordController extends GetxController {
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController confirmPasswordController = TextEditingController();

  final isPasswordVisible = false.obs;
  final isConfirmPasswordVisible = false.obs;
  final isLoading = false.obs;

  String? email; // optional (for display/next steps)
  String? token; // REQUIRED: registration session_id (uuid)

  @override
  void onInit() {
    super.onInit();
    final args = Get.arguments ?? {};
    email = (args['email'] as String?)?.trim();
    token = (args['token'] as String?)?.trim();
  }

  void togglePasswordVisibility() => isPasswordVisible.value = !isPasswordVisible.value;
  void toggleConfirmPasswordVisibility() => isConfirmPasswordVisible.value = !isConfirmPasswordVisible.value;

  Future<void> submitPassword() async {
    final password = passwordController.text.trim();
    final confirmPassword = confirmPasswordController.text.trim();

    if (password.isEmpty || confirmPassword.isEmpty) {
      _snack("Error", "Both password fields are required", Colors.red);
      return;
    }
    if (password.length < 8) {
      _snack("Error", "Password must be at least 8 characters", Colors.red);
      return;
    }
    if (password != confirmPassword) {
      _snack("Error", "Passwords do not match", Colors.red);
      return;
    }
    if (token == null || token!.isEmpty) {
      _snack("Error", "Missing session token. Please restart registration.", Colors.red);
      return;
    }

    isLoading.value = true;

    final payload = {
      "token": token,                          // required|uuid (registration session)
      "password": password,                    // required|min:8
      "password_confirmation": confirmPassword // required|same:password
    };

    try {
      final resp = await ApiService.postJson("set-password", payload);
      isLoading.value = false;

      if (resp is Map && (resp['success'] == true || resp['status'] == true)) {
        _snack("Success", (resp['message'] ?? "Password set successfully").toString(), Colors.green);

        // IMPORTANT: Persist the NEW auth token for the **newly created user**
        final box = Hive.box(HiveBoxes.userBox);

        // Clear any stale/semi-legacy keys that could cause cross-user bleed
        await box.delete('auth_token'); // legacy
        await box.delete('token');      // wipe old if present

        final String? jwt = (resp['token'] ?? '').toString().trim().isNotEmpty
            ? (resp['token'] as String)
            : null;

        if (jwt != null) {
          await box.put('token', jwt);
        }

        // Pass the fresh token forward explicitly as well
        Get.offAllNamed(
          "/height",
          arguments: {
            'jwt': jwt,                             // will be preferred by Height controller
            'firebase_uid': resp['firebase_uid'],
            'email': email,
          },
        );
      } else {
        _showBackendError(resp);
      }
    } catch (e) {
      isLoading.value = false;
      _snack("Error", "API Error: $e", Colors.red);
    }
  }

  void _showBackendError(dynamic resp) {
    String title = "Failed";
    String message = "Failed to set password";

    if (resp is Map) {
      if (resp['errors'] is Map) {
        title = "Validation failed";
        final errors = resp['errors'] as Map<String, dynamic>;
        final lines = <String>[];
        for (final entry in errors.entries) {
          final v = entry.value;
          if (v is List) {
            lines.add("${entry.key}: ${v.join(', ')}");
          } else {
            lines.add("${entry.key}: $v");
          }
        }
        final details = lines.join("\n");
        message = "${resp['message'] ?? 'Validation failed'}${details.isNotEmpty ? '\n$details' : ''}";
      } else {
        final msg = (resp['message'] ?? '').toString();
        if (msg.isNotEmpty) message = msg;
        if (msg.toLowerCase().contains('invalid session') ||
            msg.toLowerCase().contains('verification incomplete')) {
          title = "Session Error";
        }
      }
    }

    _snack(title, message, Colors.redAccent);
  }

  void _snack(String title, String msg, Color bg) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (Get.isSnackbarOpen == true) Get.closeCurrentSnackbar();
      Get.snackbar(title, msg, backgroundColor: bg, colorText: Colors.white, snackPosition: SnackPosition.BOTTOM, margin: const EdgeInsets.all(12));
    });
  }

  @override
  void onClose() {
    passwordController.dispose();
    confirmPasswordController.dispose();
    super.onClose();
  }
}
