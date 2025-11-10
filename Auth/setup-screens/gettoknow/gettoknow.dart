import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../themesfolder/theme.dart';
import 'getotknoe_controller.dart';

class GetToKnowMeScreen extends StatelessWidget {
  const GetToKnowMeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final bool fromEdit = Get.arguments?['fromEdit'] ?? false;
    final controller = Get.put(GetToKnowMeController(fromEdit: fromEdit));

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
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text("Get to Know Me", style: Theme.of(context).textTheme.bodyLarge),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text(
                "Share a bit about yourself with a live, recorded video\nfrom your device’s camera. Choose one of our fun\nprompt questions to answer and let your personality\nshine! This helps create a genuine connection right\nfrom the start.",
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: ListView.builder(
                itemCount: controller.prompts.length,
                itemBuilder: (_, index) {
                  return Obx(() => RadioListTile<int>(
                    title: Text(
                      controller.prompts[index],
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: controller.selectedIndex.value == index
                            ? Colors.black
                            : Colors.grey,
                      ),
                    ),
                    value: index,
                    groupValue: controller.selectedIndex.value,
                    onChanged: controller.selectPrompt,
                    activeColor: Colors.black,
                  ));
                },
              ),
            ),
            Obx(() => controller.responseMessage.isNotEmpty
                ? Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                controller.responseMessage.value,
                style: TextStyle(
                  color: controller.isSuccess.value ? Colors.green : Colors.red,
                  fontWeight: FontWeight.w500,
                ),
              ),
            )
                : const SizedBox.shrink()),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed:
                controller.isLoading.value ? null : controller.submitPrompt,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: Obx(() => controller.isLoading.value
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text("Submit")),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
