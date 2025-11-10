import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../themesfolder/theme.dart';
import 'deletecodecontroller.dart';

class DeleteCodeScreen extends StatelessWidget {
  const DeleteCodeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final DeleteCodeController controller =
    Get.put(DeleteCodeController(Get.arguments?['phone'] as String?));

    Widget _buildCodeBox(int index) {
      return Container(
        width: 60,
        height: 60,
        decoration: BoxDecoration(
          color: AppTheme.backgroundColor,
          borderRadius: BorderRadius.circular(12),
          boxShadow: const [
            BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 2)),
          ],
        ),
        child: Center(
          child: TextField(
            controller: controller.boxControllers[index],
            textAlign: TextAlign.center,
            keyboardType: TextInputType.number,
            maxLength: 1,
            cursorColor: Colors.black,
            style: Theme.of(context)
                .textTheme
                .displayLarge
                ?.copyWith(fontSize: 22, color: Colors.black),
            decoration: const InputDecoration(
              filled: true,
              fillColor: Colors.transparent,
              border: InputBorder.none,
              counterText: '',
            ),
            onChanged: (value) {
              if (value.isNotEmpty &&
                  index < controller.boxControllers.length - 1) {
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
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Enter Deletion Code",
                style: Theme.of(context).textTheme.bodyLarge),
            const SizedBox(height: 8),
            Obx(() => Text(
              "Enter the code we sent to ${controller.maskedNumber.value}",
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(color: Colors.black),
            )),
            const SizedBox(height: 26),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: List.generate(4, (i) => _buildCodeBox(i)),
            ),
            const SizedBox(height: 26),
            Obx(() => ElevatedButton(
              onPressed: controller.isVerifying.value
                  ? null
                  : () => controller.verifyAndDelete(),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF111827),
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                controller.isVerifying.value ? "Verifying..." : "Verify & Delete",
                style: const TextStyle(color: Colors.white),
              ),
            )),
            const SizedBox(height: 16),
            Obx(() => Text(
              controller.timerSeconds.value > 0
                  ? "Resend Code in 00:${controller.timerSeconds.value.toString().padLeft(2, '0')}"
                  : "You can resend the code now",
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            )),
            const SizedBox(height: 8),
            Obx(() => TextButton(
              onPressed: controller.timerSeconds.value == 0
                  ? controller.resendCode
                  : null,
              child: Text(
                controller.isResending.value ? "Resending..." : "Resend Code",
              ),
            )),
            const SizedBox(height: 8),
            Text(
              "Deleting your account is permanent and will remove your data.",
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(color: Colors.black54),
            ),
          ],
        ),
      ),
    );
  }
}
