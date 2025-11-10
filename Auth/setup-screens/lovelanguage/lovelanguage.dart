import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../themesfolder/theme.dart';
import 'lovelanguage_controller.dart';

class LoveLanguagesScreen extends StatelessWidget {
  const LoveLanguagesScreen({super.key}); // ❌ Removed fromEdit

  @override
  Widget build(BuildContext context) {
    final LoveLanguagesController controller = Get.put(LoveLanguagesController());

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context, true),
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
                Text(
                  'Love Languages',
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                const SizedBox(height: 20),
                Text(
                  "Understanding how you connect with others is important! Please select up to two love languages that resonate with you. This will help us match you with compatible partners who appreciate and express love in ways that matter to you.",
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 24),

                /// Love Language Options
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
                                color: controller.selectedLanguages.isEmpty
                                    ? Colors.black
                                    : (isSelected ? Colors.black : Colors.grey.shade600),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),

                const SizedBox(height: 32),

                /// Next Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: controller.selectedLanguages.isNotEmpty
                        ? () => controller.submitLoveLanguage()
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      'Next',
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          /// Loader
          if (controller.isLoading.value)
            const Center(child: CircularProgressIndicator()),
        ],
      )),
    );
  }
}
