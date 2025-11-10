import 'package:flutter/material.dart';
import 'package:get/get.dart';

class CustomDialog {
  /// Simple error dialog (centered)
  static void showError({
    required String title,
    required String message,
    VoidCallback? onOk,
  }) {
    Get.dialog(
      Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 48),
              const SizedBox(height: 12),
              Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: () {
                    Get.back();
                    if (onOk != null) onOk();
                  },
                  child: const Text("Ok", style: TextStyle(color: Colors.white)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// TOP-ALIGNED OTP dialog:
  /// - Shows at the top
  /// - Takes an OTP from the user
  /// - If it matches [expectedCode], closes and calls [onVerified]
  /// - If not, shows an inline error
  /// - "Resend" calls [onResend]
  static void showOtpTop({
    required String email,
    required String expectedCode,
    required VoidCallback onVerified,
    required VoidCallback onResend,
  }) {
    final TextEditingController codeController = TextEditingController();
    final FocusNode focusNode = FocusNode();

    Get.dialog(
      Dialog(
        alignment: Alignment.topCenter, // <— sits at the top
        insetPadding: const EdgeInsets.fromLTRB(16, 24, 16, 0), // top spacing
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: StatefulBuilder(
            builder: (context, setState) {
              String errorText = '';

              Future<void> _submit() async {
                final code = codeController.text.trim();
                if (code.isEmpty) {
                  setState(() => errorText = 'Please enter the OTP code.');
                  return;
                }
                if (code != expectedCode) {
                  setState(() => errorText = 'Invalid code. Please try again.');
                  return;
                }
                // OK — close and continue
                Get.back();
                onVerified();
              }

              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Text(
                      "OTP",
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "We sent a verification code to:",
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    email,
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    focusNode: focusNode,
                    keyboardType: TextInputType.number,
                    controller: codeController,
                    // Don't obscure OTP; users need to see what they typed.
                    obscureText: false,
                    maxLength: expectedCode.length, // usually 4
                    decoration: InputDecoration(
                      counterText: '',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      hintText: "Enter OTP",
                      errorText: errorText.isEmpty ? null : errorText,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    ),
                    onSubmitted: (_) => _submit(),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.black,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      onPressed: _submit,
                      child: const Text("Confirm", style: TextStyle(color: Colors.white)),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Center(
                    child: TextButton(
                      onPressed: () {
                        Get.back(); // close this dialog before resending
                        onResend();
                      },
                      child: const Text(
                        "Didn't get it? Resend",
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
      barrierDismissible: false,
    );

    // Focus field automatically once dialog opens
    Future.delayed(const Duration(milliseconds: 150), () {
      if (focusNode.canRequestFocus) {
        focusNode.requestFocus();
      }
    });
  }

  /// (Optional) Centered version if you prefer your previous layout but want built-in confirm callback
  static void showPasswordSentDialog({
    required String email,
    required Function(String code) onConfirm,
    required VoidCallback onResend,
  }) {
    final TextEditingController codeController = TextEditingController();

    Get.dialog(
      Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: StatefulBuilder(
            builder: (context, setState) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 12),
                  const Text(
                    "OTP",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    "Please enter the OTP\nwe sent to your email address.",
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    keyboardType: TextInputType.number,
                    controller: codeController,
                    obscureText: false,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      hintText: "Enter OTP",
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.black,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      onPressed: () {
                        final code = codeController.text.trim();
                        if (code.isNotEmpty) {
                          Get.back();
                          onConfirm(code);
                        }
                      },
                      child: const Text("Confirm",
                          style: TextStyle(color: Colors.white)),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextButton(
                    onPressed: () {
                      Get.back();
                      onResend();
                    },
                    child: const Text(
                      "Didn't get it? Resend",
                      style: TextStyle(fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
