import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../themesfolder/theme.dart';
import 'LoginWithEmailController.dart';

class LoginWithEmailScreen extends StatefulWidget {
  @override
  State<LoginWithEmailScreen> createState() => _LoginWithEmailScreenState();
}

class _LoginWithEmailScreenState extends State<LoginWithEmailScreen> {
  final LoginWithEmailController controller = Get.put(LoginWithEmailController());
  final RxBool _obscurePassword = true.obs;

  @override
  Widget build(BuildContext context) {
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
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Login With Email", style: AppTheme.textTheme.bodyLarge),
            const SizedBox(height: 30),

            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 3.0, vertical: 3),
              child: Text("Email", style: TextStyle(fontWeight: FontWeight.w500)),
            ),
            Obx(() => TextField(
              onChanged: (value) => controller.email.value = value,
              keyboardType: TextInputType.emailAddress,
              style: Theme.of(context).textTheme.bodySmall,
              decoration: InputDecoration(
                filled: true,
                fillColor: AppTheme.backgroundColor,
                hintText: "Enter your email",
                hintStyle: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey),
                errorText: controller.emailError.value.isNotEmpty
                    ? controller.emailError.value
                    : null,
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(
                    color: controller.emailError.value.isNotEmpty ? Colors.red : Colors.black26,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(
                    color: controller.emailError.value.isNotEmpty ? Colors.red : Colors.black87,
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
            )),
            const SizedBox(height: 20),

            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 3.0, vertical: 3),
              child: Text("Password", style: TextStyle(fontWeight: FontWeight.w500)),
            ),
            Obx(() => TextField(
              obscureText: _obscurePassword.value,
              onChanged: (value) => controller.password.value = value,
              style: Theme.of(context).textTheme.bodySmall,
              decoration: InputDecoration(
                filled: true,
                fillColor: AppTheme.backgroundColor,
                hintText: "Enter your password",
                hintStyle: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey),
                errorText: controller.passwordError.value.isNotEmpty
                    ? controller.passwordError.value
                    : null,
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscurePassword.value ? Icons.visibility_off : Icons.visibility,
                    color: Colors.grey,
                  ),
                  onPressed: () => _obscurePassword.value = !_obscurePassword.value,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(
                    color: controller.passwordError.value.isNotEmpty ? Colors.red : Colors.black26,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(
                    color: controller.passwordError.value.isNotEmpty ? Colors.red : Colors.black87,
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
            )),
            const SizedBox(height: 6),

            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => Get.toNamed('/reset-password'),
                child: const Text("Forgot Password?", style: TextStyle(color: Colors.black87)),
              ),
            ),
            const SizedBox(height: 10),

            // === Button with inline loader only ===
            Obx(
                  () => SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: controller.isLoading.value ? null : () => controller.login(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: controller.isLoading.value
                      ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                      : const Text(
                    "Login",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.backgroundColor,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
