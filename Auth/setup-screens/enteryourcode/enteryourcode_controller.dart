import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart' show FrameCallback, WidgetsBinding;
import 'package:get/get.dart';
import '../../../services/api_services.dart';

class VerificationCodeController extends GetxController {
  // --- UI state ---
  final timerSeconds = 0.obs;
  final isTimeUp = true.obs;
  final isVerifying = false.obs;
  final isSending = false.obs;

  final maskedNumber = 'xxxx'.obs;
  final enteredOtp = ''.obs;

  final List<TextEditingController> controllers =
  List.generate(4, (_) => TextEditingController());

  Timer? _timer;

  // From previous screen
  late final String phoneNumber;   // REQUIRED (+E.164)
  late final String flowType;      // e.g. "sign up"
  String sessionToken = '';        // REQUIRED (uuid from sendcode)
  String tokenType = 'Bearer';     // optional

  // Endpoints
  static const String _verifyEndpoint = 'verify';     // expects { token, otp_code } OR per your backend, token in body
  static const String _sendCodeEndpoint = 'sendcode'; // expects { phone_number, restart }

  void _safeSnack(String title, String msg, {Color? bg}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (Get.isSnackbarOpen == true) Get.closeCurrentSnackbar();
      Get.snackbar(
        title,
        msg,
        backgroundColor: bg ?? Colors.black87,
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
        margin: const EdgeInsets.all(12),
      );
    });
  }

  @override
  void onInit() {
    super.onInit();

    final args = Get.arguments ?? {};
    phoneNumber  = (args['phone'] as String?)?.trim() ?? '';
    flowType     = (args['type'] as String?) ?? 'sign up';
    sessionToken = (args['token'] as String?)?.trim() ?? '';
    tokenType    = ((args['token_type'] as String?)?.trim().isNotEmpty ?? false)
        ? (args['token_type'] as String).trim()
        : 'Bearer';

    if (phoneNumber.isEmpty || !phoneNumber.startsWith('+') || sessionToken.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback(() {
        Get.back();
        _safeSnack('Error', 'Missing phone or session token. Please try again.',
            bg: Colors.redAccent);
      } as FrameCallback);
      return;
    }

    maskedNumber.value = phoneNumber.length > 6
        ? phoneNumber.replaceRange(4, phoneNumber.length - 2, 'xxxx')
        : phoneNumber;

    for (final c in controllers) {
      c.addListener(() {
        enteredOtp.value = controllers.map((e) => e.text.trim()).join();
      });
    }

    _startTimer(60); // 60s front-end cooldown
  }

  // Timer
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

  // Resend OTP (always restart session to get a fresh token)
  Future<void> resend() async {
    if (!isTimeUp.value || isSending.value) return;

    try {
      isSending.value = true;

      final resp = await ApiService.postJson(_sendCodeEndpoint, {
        "phone_number": phoneNumber,
        "restart": true,
      });

      if (resp is Map && resp['success'] == true) {
        final newToken = (resp['token'] ?? '').toString();
        if (newToken.isNotEmpty) {
          sessionToken = newToken; // IMPORTANT: keep the latest token
        }
        _startTimer(60);

        final msg = (resp['message'] ?? 'OTP re-sent successfully').toString();
        _safeSnack('Info', msg);
      } else {
        final msg = (resp is Map
            ? (resp['message'] ?? 'Failed to resend code')
            : 'Failed to resend code')
            .toString();
        _safeSnack('Notice', msg, bg: Colors.orange);
      }
    } catch (e) {
      _safeSnack('Error', 'Resend failed: $e', bg: Colors.redAccent);
    } finally {
      isSending.value = false;
    }
  }

  // Verify OTP
  Future<void> verifyAndProceed() async {
    final code = enteredOtp.value;
    if (code.length != 4) {
      _safeSnack('Oops', 'Enter the 4-digit code', bg: Colors.redAccent);
      return;
    }

    // DEV backdoor (remove in production)
    if (code == '0000') {
      _goNext();
      return;
    }

    try {
      isVerifying.value = true;

      // Your backend wants token IN BODY:
      final resp = await ApiService.postJson(_verifyEndpoint, {
        "token": sessionToken,
        "otp_code": code,
      });

      if (resp is Map && resp['success'] == true) {
        _safeSnack('Success',
            (resp['message'] ?? 'Phone verified successfully').toString(),
            bg: Colors.green);
        _goNext();
        return;
      }

      final msg = (resp is Map ? (resp['message'] ?? 'Verification failed') : 'Verification failed').toString();
      final lower = msg.toLowerCase();

      if (lower.contains('invalid or expired session')) {
        _safeSnack('Session Error',
            'Your session is invalid or expired. Please restart registration.',
            bg: Colors.orange);
      } else if (lower.contains('invalid otp')) {
        _safeSnack('Invalid Code', 'The OTP you entered is incorrect.',
            bg: Colors.redAccent);
      } else if (lower.contains('otp has expired')) {
        _safeSnack('Expired', 'Your OTP has expired. Tap Resend to get a new code.',
            bg: Colors.orange);
      } else if (lower.contains('invalid input')) {
        _safeSnack('Invalid Input', 'Please enter a valid 4-digit code.',
            bg: Colors.orange);
      } else {
        _safeSnack('Error', msg, bg: Colors.redAccent);
      }
    } catch (e) {
      _safeSnack('Error', e.toString(), bg: Colors.redAccent);
    } finally {
      isVerifying.value = false;
    }
  }

  void _goNext() {
    // IMPORTANT: pass token forward
    Get.offAllNamed('/ProfileDetails', arguments: {
      'phone': phoneNumber,
      'token': sessionToken,     // <-- this was missing
      'token_type': tokenType,   // optional
    });
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
