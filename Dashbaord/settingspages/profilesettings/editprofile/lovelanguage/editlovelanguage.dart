import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../../themesfolder/theme.dart';
import '../../../../dashboard/Dashboard.dart';
import 'editlovelangaugecontroller.dart';

class EditLoveLanguagesScreen extends StatelessWidget {
  const EditLoveLanguagesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(EditLoveLanguagesController());

    return PopScope(
        canPop: false,
        onPopInvoked: (didPop) {
          if (!didPop) {
            // ✅ Always close via nested navigator
            Get.back(id: settingsNavId, result: false);
          }
        },child:  Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Get.back(id: settingsNavId, result: false),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Obx(() => Stack(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Edit Love Languages', style: Theme.of(context).textTheme.bodyLarge),
                const SizedBox(height: 20),
                Text(
                  "Select up to two love languages that describe how you give or receive love.",
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 24),

                /// Option List
                Column(
                  children: controller.loveLanguages.map((language) {
                    final isSelected = controller.selectedLanguages.contains(language);

                    return GestureDetector(
                      onTap: () => controller.toggleLanguage(language),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8.0),
                        child: Row(
                          children: [
                            Container(
                              margin: const EdgeInsets.only(right: 12),
                              width: 24,
                              height: 24,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: isSelected ? Colors.black : Colors.grey.shade500,
                                  width: 2,
                                ),
                                color: isSelected ? Colors.black : Colors.transparent,
                              ),
                              child: isSelected
                                  ? const Icon(Icons.check, size: 16, color: Colors.white)
                                  : null,
                            ),
                            Text(
                              language,
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: isSelected ? Colors.black : Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),

                const SizedBox(height: 32),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: controller.selectedLanguages.isEmpty
                        ? null
                        : controller.submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: controller.isLoading.value
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text("Update", style: TextStyle(color: Colors.white)),
                  ),
                ),
              ],
            ),
          ),
          if (controller.isLoading.value)
            const Center(child: CircularProgressIndicator()),
        ],
      )),
    ));
  }
}
