import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../../themesfolder/theme.dart';
import '../../../../dashboard/Dashboard.dart'; // for settingsNavId
import 'editgettoknowcontroller.dart';

class EditGetToKnowMeScreen extends StatelessWidget {
  const EditGetToKnowMeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(EditGetToKnowMeController());

    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {
        if (!didPop) {
          Get.back(id: settingsNavId, result: false);
        }
      },
      child: Scaffold(
        backgroundColor: AppTheme.backgroundColor,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.black),
            onPressed: () => Get.back(id: settingsNavId, result: false),
          ),
        ),
        body: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Get to know me", style: Theme.of(context).textTheme.bodyLarge),
              const SizedBox(height: 8),
              Text(
                "Choose a fun question to help others know you better. Your selection will be saved and shown on your profile.",
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 20),

              // LIST
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


              // Inline response message (optional)
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

              // Update button
              SizedBox(
                width: double.infinity,
                child: Obx(
                      () => ElevatedButton(
                    onPressed: controller.isLoading.value
                        ? null
                        : () async {
                      final ok = await controller.submitPrompt();
                      if (ok) {
                        Get.back(id: settingsNavId, result: true);
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: controller.isLoading.value
                        ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
                        : const Text("Update"),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
