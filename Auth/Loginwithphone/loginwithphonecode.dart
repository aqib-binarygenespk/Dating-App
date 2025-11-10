import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../themesfolder/theme.dart';
import 'loginwithphonecodecontroller.dart';

class LoginWithPhoneCodeScreen extends StatelessWidget {
  const LoginWithPhoneCodeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Create controller here so Get.find() is not required.
    final LoginWithPhoneCodeController controller =
    Get.put(LoginWithPhoneCodeController());

    Widget codeBox(int index) {
      return Container(
        width: 60,
        height: 60,
        decoration: BoxDecoration(
          color: AppTheme.backgroundColor,
          borderRadius: BorderRadius.circular(8),
          boxShadow: const [
            BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 2)),
          ],
        ),
        child: Center(
          child: TextField(
            controller: controller.controllers[index],
            textAlign: TextAlign.center,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            maxLength: 1,
            obscureText: true,
            cursorColor: Colors.black,
            style: Theme.of(context)
                .textTheme
                .displayLarge
                ?.copyWith(fontSize: 24, color: Colors.black),
            decoration: const InputDecoration(
              filled: true,
              border: InputBorder.none,
              counterText: '',
            ),
            onChanged: (value) {
              if (value.isNotEmpty && index < controller.controllers.length - 1) {
                FocusScope.of(context).nextFocus();
              } else if (value.isEmpty && index > 0) {
                FocusScope.of(context).previousFocus();
              }
            },
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Get.back(),
        ),
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Enter Your Code", style: Theme.of(context).textTheme.bodyLarge),
            const SizedBox(height: 8),
            Obx(
                  () => Text(
                "Enter the verification code we sent to ${controller.maskedNumber.value}",
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(color: Colors.black),
              ),
            ),
            const SizedBox(height: 30),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: List.generate(4, (i) => codeBox(i)),
            ),

            const SizedBox(height: 30),

            Obx(
                  () => SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: controller.isVerifying.value
                      ? null
                      : controller.verifyAndProceed,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF111827),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: controller.isVerifying.value
                      ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                      : const Text("Verify"),
                ),
              ),
            ),

            const SizedBox(height: 16),

            Obx(
                  () => Text(
                "Resend Code in 00:${controller.timerSeconds.value.toString().padLeft(2, '0')}",
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
            ),

            const SizedBox(height: 8),

            Obx(
                  () => Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: controller.isTimeUp.value && !controller.isSending.value
                      ? controller.resend
                      : null,
                  child: controller.isSending.value
                      ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                      : const Text("Resend Code"),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
