import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../services/api_services.dart';
import '../setup-screens/enteryourcode/enteryourcode.dart';

class SignUpPhoneController extends GetxController {
  final TextEditingController phoneController = TextEditingController();
  final isLoading = false.obs;

  /// Must be E.164 (e.g., +15551234567). We'll sanitize before sending.
  String internationalPhone = '';
  final String flowType = 'sign up';

  @override
  void onClose() {
    phoneController.dispose();
    super.onClose();
  }

  void _safeSnack(String title, String msg, {Color? bg}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (Get.isSnackbarOpen == true) Get.closeCurrentSnackbar();
      Get.snackbar(
        title,
        msg,
        backgroundColor: bg ?? Colors.black87,
        colorText: Colors.white,
        margin: const EdgeInsets.all(12),
        snackPosition: SnackPosition.TOP,
      );
    });
  }

  String _normalizeToE164(String input) {
    input = input.trim();
    if (input.isEmpty) return input;
    final buf = StringBuffer();
    bool plusKept = false;
    for (int i = 0; i < input.length; i++) {
      final ch = input[i];
      if (ch == '+' && !plusKept) {
        buf.write('+');
        plusKept = true;
      } else if (ch.codeUnitAt(0) >= 48 && ch.codeUnitAt(0) <= 57) {
        buf.write(ch);
      }
    }
    return buf.toString();
  }

  bool _looksLikeE164(String phone) {
    final reg = RegExp(r'^\+[1-9]\d{1,14}$');
    return reg.hasMatch(phone);
  }

  Future<void> sendCode() async {
    final phone = _normalizeToE164(internationalPhone);

    if (phone.isEmpty || !_looksLikeE164(phone)) {
      _safeSnack("Invalid Phone", "Use a valid E.164 number (e.g., +15551234567)",
          bg: Colors.redAccent);
      return;
    }
    if (isLoading.value) return;

    isLoading.value = true;
    try {
      // Always request a fresh session — avoids 409 “Registration in progress”.
      final resp = await ApiService.postJson('sendcode', {
        "phone_number": phone,
        "restart": true, // <— key change
      });

      final success = resp['success'] == true;
      final message = (resp['message'] ?? '').toString();
      final token = (resp['token'] ?? '').toString();

      if (token.isNotEmpty) {
        Get.to(() => const VerificationCodeScreen(), arguments: {
          'phone': phone,
          'type': flowType,
          'token': token, // session_id for verify step
        });

        _safeSnack(
          success ? "Success" : "Notice",
          message.isNotEmpty
              ? message
              : success
              ? "OTP sent successfully"
              : "Proceed to enter your code.",
          bg: success ? Colors.green : Colors.orange,
        );
      } else {
        _safeSnack("Error",
            message.isNotEmpty ? message : "Failed to start verification session.",
            bg: Colors.redAccent);
      }
    } catch (e) {
      // If your ApiService throws on non-2xx, you’ll land here—
      // show a generic error; ApiService can also surface body if you prefer.
      _safeSnack("Error", "API Error: $e", bg: Colors.redAccent);
    } finally {
      isLoading.value = false;
    }
  }
}
