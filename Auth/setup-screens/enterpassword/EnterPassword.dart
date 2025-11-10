import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:dating_app/themesfolder/textfields.dart';
import '../../../themesfolder/theme.dart';
import 'enterpasword_controller.dart';

class EnterPassword extends StatelessWidget {
  const EnterPassword({super.key});

  @override
  Widget build(BuildContext context) {
    final EnterPasswordController controller = Get.put(EnterPasswordController());

    // ✅ Get email from arguments or previous screen
    controller.email = Get.arguments?['email'] ?? '';

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Enter a password", style: Theme.of(context).textTheme.bodyLarge),
            const SizedBox(height: 10),
            Text("Create a password to finish signing up.",
                style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 32),

            Text("New Password", style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),

            Obx(() => CustomTextField(
              hintText: "Enter your new password",
              obscureText: !controller.isPasswordVisible.value,
              controller: controller.passwordController,
              suffixIcon: IconButton(
                icon: Icon(
                  controller.isPasswordVisible.value
                      ? Icons.visibility
                      : Icons.visibility_off,
                  color: Colors.black54,
                ),
                onPressed: controller.togglePasswordVisibility,
              ),
            )),

            const SizedBox(height: 24),

            Text("Confirm New Password", style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),

            Obx(() => CustomTextField(
              hintText: "Re-enter your password",
              obscureText: !controller.isConfirmPasswordVisible.value,
              controller: controller.confirmPasswordController,
              suffixIcon: IconButton(
                icon: Icon(
                  controller.isConfirmPasswordVisible.value
                      ? Icons.visibility
                      : Icons.visibility_off,
                  color: Colors.black54,
                ),
                onPressed: controller.toggleConfirmPasswordVisibility,
              ),
            )),

            const SizedBox(height: 32),

            Obx(() => ElevatedButton(
              onPressed: controller.isLoading.value ? null : controller.submitPassword,
              child: controller.isLoading.value
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text("Submit"),
            )),
          ],
        ),
      ),
    );
  }
}
