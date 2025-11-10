// lib/Auth/setup-screens/relocate/relocate_screen.dart
import 'package:dating_app/Auth/setup-screens/relocate/relocate_controller.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../themesfolder/theme.dart';

class RelocateLoveScreen extends StatelessWidget {
  final bool fromEdit;

  const RelocateLoveScreen({super.key, this.fromEdit = false});

  @override
  Widget build(BuildContext context) {
    // Explicit type to avoid inference issues
    final RelocateLoveController controller =
    Get.put(RelocateLoveController(fromEdit: fromEdit));

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context, true), // keep returning true
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Obx(() => Stack(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: SingleChildScrollView( // prevent overflow on small screens
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Relocate Love',
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 20),
                  Text(
                    "Are you open to relocating for love? Select one option that best describes your willingness to move.",
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 24),

                  // Options list (single-select using your controller API)
                  Column(
                    children: controller.relocateOptions.map((option) {
                      final bool isSelected = controller
                          .selectedRelocateOptions
                          .contains(option);

                      return GestureDetector(
                        onTap: () => controller.toggleOption(option),
                        child: Padding(
                          padding:
                          const EdgeInsets.symmetric(vertical: 8.0),
                          child: Row(
                            children: [
                              Container(
                                margin: const EdgeInsets.only(right: 12),
                                width: 24,
                                height: 24,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: isSelected
                                        ? Colors.black
                                        : Colors.grey.shade500,
                                    width: 2,
                                  ),
                                  color: isSelected
                                      ? Colors.black
                                      : Colors.transparent,
                                ),
                                child: isSelected
                                    ? const Icon(Icons.check,
                                    size: 16, color: Colors.white)
                                    : null,
                              ),
                              Expanded(
                                child: Text(
                                  option,
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodyMedium
                                      ?.copyWith(
                                    color: isSelected
                                        ? Colors.black
                                        : Colors.grey.shade600,
                                  ),
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
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.black87,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: controller.selectedRelocateOptions.isNotEmpty &&
                          !controller.isLoading.value
                          ? controller.submitRelocateChoice
                          : null,
                      child: Text(
                        'Next',
                        style: Theme.of(context)
                            .textTheme
                            .labelLarge
                            ?.copyWith(color: Colors.white),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),

          if (controller.isLoading.value)
            const Center(child: CircularProgressIndicator()),
        ],
      )),
    );
  }
}
