import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hive/hive.dart';
import '../../../hive_utils/hive_boxes.dart';
import '../../../services/api_services.dart';

class DeleteCodeController extends GetxController {
  DeleteCodeController(String? phone) {
    _init(phone);
  }

  final List<TextEditingController> boxControllers =
  List.generate(4, (_) => TextEditingController());

  final RxInt timerSeconds = 300.obs; // 5 minutes to match backend expiry
  final RxBool isVerifying = false.obs;
  final RxBool isResending = false.obs;
  final RxString maskedNumber = ''.obs;

  String? _rawPhone;
  Timer? _timer;

  void _init(String? phone) {
    _rawPhone = phone;
    maskedNumber.value = _maskPhone(phone);
    _startTimer();
  }

  String _maskPhone(String? phone) {
    if (phone == null || phone.isEmpty) return '';
    final last = phone.length >= 4 ? phone.substring(phone.length - 4) : phone;
    return '${phone.substring(0, 3)} **** ** $last';
  }

  void _startTimer() {
    _timer?.cancel();
    timerSeconds.value = 300;
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (timerSeconds.value <= 0) {
        t.cancel();
      } else {
        timerSeconds.value--;
      }
    });
  }

  String _collectCode() => boxControllers.map((c) => c.text.trim()).join();

  Future<void> verifyAndDelete() async {
    final code = _collectCode();
    if (code.length != 4) {
      Get.snackbar('Error', 'Please enter the 4-digit code.');
      return;
    }

    if (!Hive.isBoxOpen(HiveBoxes.userBox)) {
      await Hive.openBox(HiveBoxes.userBox);
    }
    final box = Hive.box(HiveBoxes.userBox);
    final String? token = box.get('auth_token')?.toString();

    if (token == null || token.isEmpty) {
      Get.snackbar('Error', 'Missing auth token. Please log in again.');
      return;
    }

    isVerifying.value = true;
    try {
      // POSitional signature again
      final res = await ApiService.postJson(
        'delete/verify-otp',
        {'code': int.tryParse(code) ?? code},
        token: token,
      );

      isVerifying.value = false;

      if (res is Map && res['success'] == true) {
        Get.snackbar('Success', (res['message'] ?? 'Account deleted successfully').toString());

        // Clear local session and navigate to login/welcome
        await box.delete('auth_token');
        Get.offAllNamed('/login');
      } else {
        final msg = (res is Map ? res['message'] : null) ?? 'Invalid or expired code';
        Get.snackbar('Error', msg.toString());
      }
    } catch (e) {
      isVerifying.value = false;
      Get.snackbar('Error', 'Verification failed: $e');
    }
  }

  Future<void> resendCode() async {
    if (_rawPhone == null || _rawPhone!.isEmpty) return;
    if (timerSeconds.value > 0) return; // guard; UI also disables

    if (!Hive.isBoxOpen(HiveBoxes.userBox)) {
      await Hive.openBox(HiveBoxes.userBox);
    }
    final box = Hive.box(HiveBoxes.userBox);
    final String? token = box.get('auth_token')?.toString();

    if (token == null || token.isEmpty) {
      Get.snackbar('Error', 'Missing auth token. Please log in again.');
      return;
    }

    isResending.value = true;
    try {
      final res = await ApiService.postJson(
        'delete-otp',
        {'phone_number': _rawPhone},
        token: token,
      );

      isResending.value = false;

      if (res is Map && res['success'] == true) {
        Get.snackbar('Success', 'Code resent');
        _startTimer();
      } else {
        final msg = (res is Map ? res['message'] : null) ?? 'Failed to resend code';
        Get.snackbar('Error', msg.toString());
      }
    } catch (e) {
      isResending.value = false;
      Get.snackbar('Error', 'Failed to resend: $e');
    }
  }

  @override
  void onClose() {
    _timer?.cancel();
    for (final c in boxControllers) {
      c.dispose();
    }
    super.onClose();
  }
}
