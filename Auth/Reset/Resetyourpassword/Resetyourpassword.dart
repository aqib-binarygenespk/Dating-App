import 'package:dating_app/Auth/Reset/Resetyourpassword/resetpasswordcontroller.dart';
import 'package:dating_app/themesfolder/textfields.dart';
import 'package:dating_app/themesfolder/theme.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';


class Resetyourpassword extends StatelessWidget {
  const Resetyourpassword({super.key});

  @override
  Widget build(BuildContext context) {
    // Inject controller
    final ctrl = Get.put(ResetPasswordController());

    final RxString emailError = ''.obs;

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Get.back(),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Obx(() => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Reset your password",
              style: AppTheme.textTheme.bodyLarge,
            ),
            const SizedBox(height: 10),
            Text(
              "What email address is associated to your account?",
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(fontWeight: FontWeight.w300),
            ),
            const SizedBox(height: 30),

            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 3.0, vertical: 3),
              child: Text("Email",
                  style: TextStyle(fontWeight: FontWeight.w500)),
            ),

            TextField(
              controller: ctrl.emailController,
              onChanged: (_) => emailError.value = '',
              keyboardType: TextInputType.emailAddress,
              style: Theme.of(context).textTheme.bodySmall,
              decoration: InputDecoration(
                filled: true,
                fillColor: AppTheme.backgroundColor,
                hintText: "Enter your email",
                hintStyle: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: Colors.grey),
                errorText:
                emailError.value.isNotEmpty ? emailError.value : null,
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(
                    color: emailError.value.isNotEmpty
                        ? Colors.red
                        : Colors.black26,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(
                    color: emailError.value.isNotEmpty
                        ? Colors.red
                        : Colors.black87,
                  ),
                ),
                errorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Colors.red),
                ),
                focusedErrorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Colors.red),
                ),
              ),
            ),
            const SizedBox(height: 30),

            // Button
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: ctrl.isLoading.value
                    ? null
                    : () {
                  final email = ctrl.emailController.text.trim();
                  if (email.isEmpty || !GetUtils.isEmail(email)) {
                    emailError.value = "Please enter a valid email.";
                  } else {
                    emailError.value = '';
                    ctrl.sendResetLink();
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black,
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: ctrl.isLoading.value
                    ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor:
                    AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
                    : const Text(
                  "Send Login link",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.backgroundColor,
                  ),
                ),
              ),
            ),
          ],
        )),
      ),
    );
  }
}
