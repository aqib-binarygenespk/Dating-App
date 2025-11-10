import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl_phone_field/intl_phone_field.dart';
import '../../../themesfolder/theme.dart';
import 'activatecodeui.dart';
import 'activatecontroller.dart';


class ActivateNumberScreen extends StatelessWidget {
  const ActivateNumberScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final ActivateNumberController controller =
    Get.put(ActivateNumberController());

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
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Activate my Account",
                style: Theme.of(context).textTheme.bodyLarge),
            const SizedBox(height: 8),
            Text(
              "Please enter your phone number to receive an activation code.",
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(color: Colors.black54),
            ),
            const SizedBox(height: 24),
            IntlPhoneField(
              initialCountryCode: 'US',
              decoration: InputDecoration(
                filled: true,
                fillColor: AppTheme.backgroundColor,
                hintText: "03xxxxxxxxx",
                hintStyle: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: Colors.grey),
                labelText: "Phone Number",
                labelStyle: const TextStyle(fontWeight: FontWeight.w500),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Colors.black26),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Colors.black87),
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
              onChanged: (phone) =>
                  controller.updatePhoneNumber(phone.completeNumber),
            ),
            const SizedBox(height: 20),
            Obx(() => ElevatedButton(
              onPressed: controller.isSending.value
                  ? null
                  : () async {
                final ok = await controller.sendCode();
                if (ok) {
                  Get.to(() => const ActivateCodeScreen(),
                      arguments: {
                        'phone': controller.phoneNumber.value
                      });
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF111827),
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: Text(
                controller.isSending.value
                    ? "Sending..."
                    : "Send Activation Code",
                style: const TextStyle(color: Colors.white),
              ),
            )),
          ],
        ),
      ),
    );
  }
}
