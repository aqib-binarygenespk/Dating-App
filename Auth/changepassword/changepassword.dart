// lib/Auth/ChangePassword/changepassword.dart
import 'package:dating_app/themesfolder/theme.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:dating_app/themesfolder/textfields.dart';

import 'changepasswordcontroller.dart';

class ChangePasswordScreen extends StatelessWidget {
  const ChangePasswordScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(ChangePasswordController());

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Obx(
                () => SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Change password", style: AppTheme.textTheme.bodyLarge),
                  const SizedBox(height: 10),
                  Text(
                    "Please confirm your current password and set a new one.",
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(fontWeight: FontWeight.w300),
                  ),
                  const SizedBox(height: 30),

                  // Current Password
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 3.0, vertical: 3),
                    child: Text("Current Password", style: TextStyle(fontWeight: FontWeight.w500)),
                  ),
                  CustomTextField(
                    controller: controller.currentPasswordController,
                    hintText: "Enter your current password",
                    obscureText: !controller.isCurrentVisible.value,
                    suffixIcon: IconButton(
                      icon: Icon(
                        controller.isCurrentVisible.value
                            ? Icons.visibility
                            : Icons.visibility_off,
                      ),
                      onPressed: controller.toggleCurrentVisibility,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // New Password
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 3.0, vertical: 3),
                    child: Text("New Password", style: TextStyle(fontWeight: FontWeight.w500)),
                  ),
                  CustomTextField(
                    controller: controller.newPasswordController,
                    hintText: "Enter your new password",
                    obscureText: !controller.isNewVisible.value,
                    suffixIcon: IconButton(
                      icon: Icon(
                        controller.isNewVisible.value
                            ? Icons.visibility
                            : Icons.visibility_off,
                      ),
                      onPressed: controller.toggleNewVisibility,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Confirm New Password
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 3.0, vertical: 3),
                    child: Text("Confirm New Password", style: TextStyle(fontWeight: FontWeight.w500)),
                  ),
                  CustomTextField(
                    controller: controller.confirmNewPasswordController,
                    hintText: "Re-enter your new password",
                    obscureText: !controller.isConfirmNewVisible.value,
                    suffixIcon: IconButton(
                      icon: Icon(
                        controller.isConfirmNewVisible.value
                            ? Icons.visibility
                            : Icons.visibility_off,
                      ),
                      onPressed: controller.toggleConfirmNewVisibility,
                    ),
                  ),
                  const SizedBox(height: 30),

                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: controller.isLoading.value
                          ? null
                          : () => controller.submit(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.black,
                        disabledBackgroundColor: Colors.black54,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: controller.isLoading.value
                          ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            AppTheme.backgroundColor,
                          ),
                        ),
                      )
                          : const Text(
                        "Update Password",
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: AppTheme.backgroundColor,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
