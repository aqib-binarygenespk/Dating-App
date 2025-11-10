import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hive/hive.dart';
import '../../../hive_utils/hive_boxes.dart';
import '../../../services/api_services.dart';
import '../Loginwithemail/loginwithemail.dart';

class ActivateCodeController extends GetxController {
  final String? phone;
  ActivateCodeController(this.phone);

  var boxControllers = List.generate(4, (_) => TextEditingController()).obs;
  var isVerifying = false.obs;
  var maskedNumber = ''.obs;
  var timerSeconds = 60.obs;
  Timer? _timer;

  @override
  void onInit() {
    super.onInit();
    maskedNumber.value = _maskNumber(phone ?? "");
    _startTimer();
  }

  String _maskNumber(String number) {
    if (number.length < 4) return number;
    return number.replaceRange(3, number.length - 2, '*' * (number.length - 5));
  }

  void _startTimer() {
    _timer?.cancel();
    timerSeconds.value = 60;
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (timerSeconds.value > 0) {
        timerSeconds.value--;
      } else {
        _timer?.cancel();
      }
    });
  }

  Future<void> resendCode() async {
    if (phone == null || phone!.isEmpty) {
      Get.snackbar("Error", "Invalid phone number");
      return;
    }
    final token = Hive.box(HiveBoxes.userBox).get('auth_token');
    if (token == null) {
      Get.snackbar("Error", "Missing token");
      return;
    }
    try {
      final res = await ApiService.post(
        "reactive/send-code",
        {"phone_number": phone},
        token: token,
      );
      if (res['success'] == true) {
        Get.snackbar("Success", "Code resent successfully");
        _startTimer();
      } else {
        Get.snackbar("Error", res['message'] ?? "Failed to resend code");
      }
    } catch (e) {
      Get.snackbar("Error", "Resend failed: $e");
    }
  }

  Future<void> verifyAndActivate() async {
    final code = boxControllers.map((c) => c.text).join();
    if (code.length != 4) {
      Get.snackbar("Error", "Please enter the 4-digit code.");
      return;
    }

    final token = Hive.box(HiveBoxes.userBox).get('auth_token');
    if (token == null) {
      Get.snackbar("Error", "Missing token");
      return;
    }

    isVerifying.value = true;

    try {
      final res = await ApiService.post(
        "reactive/verify-code",
        {"code": code},
        token: token,
      );

      if (res['success'] == true) {
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
                    Icon(Icons.check_circle_outline,
                        color: Colors.green, size: 56),
                    const SizedBox(height: 12),
                    const Text(
                      "Account Activated",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      "Your account has been activated successfully!",
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 15, color: Colors.black54),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          Get.offAll(() => LoginWithEmailScreen());
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.black,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: const Text(
                          "OK",
                          style: TextStyle(color: Colors.white, fontSize: 16),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          barrierDismissible: false,
        );
      } else {
        Get.snackbar("Error", res['message'] ?? "Verification failed");
      }
    } catch (e) {
      Get.snackbar("Error", "Verification failed: $e");
    } finally {
      isVerifying.value = false;
    }
  }

  @override
  void onClose() {
    for (var c in boxControllers) {
      c.dispose();
    }
    _timer?.cancel();
    super.onClose();
  }
}
