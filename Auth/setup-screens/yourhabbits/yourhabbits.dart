// lib/Auth/setup-screens/yourhabbits/get_to_know_your_habits_screen.dart
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../themesfolder/theme.dart';

// NOTE: keep this import path matching your project structure
import 'package:dating_app/Auth/setup-screens/yourhabbits/yourhabbits_controller.dart';

class GetToKnowYourHabitsScreen extends StatelessWidget {
  final bool fromEdit;
  const GetToKnowYourHabitsScreen({super.key, this.fromEdit = false});

  @override
  Widget build(BuildContext context) {
    final HabitsController controller = Get.put(HabitsController(fromEdit: fromEdit));

    Widget buildRadioGroup({
      required String title,
      required List<Map<String, String>> options, // [{key:'1', label:'...'}, ...]
      required RxString groupValue,              // selected key
      required void Function(String) onChanged,  // setter
    }) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          ...options.map((opt) {
            final value = opt['key']!;
            final label = opt['label']!;
            return Obx(() {
              final bool isSelected = groupValue.value == value;
              return RadioListTile<String>(
                value: value,
                groupValue: groupValue.value,
                onChanged: (v) {
                  if (v != null) onChanged(v);
                },
                activeColor: Colors.black,
                contentPadding: EdgeInsets.zero,
                dense: true,
                visualDensity: const VisualDensity(horizontal: -2, vertical: -1),
                title: Text(
                  label,
                  // ✅ Pets-style: selected black, unselected grey (no bolding)
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: isSelected ? Colors.black : Colors.grey.shade700,
                  ),
                ),
              );
            });
          }).toList(),
          const SizedBox(height: 20),
        ],
      );
    }

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context, true),
        ),
      ),
      body: Obx(
            () => Stack(
          children: [
            SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Let's Get to Know Your Habits",
                      style: Theme.of(context).textTheme.bodyLarge),
                  const SizedBox(height: 8),
                  Text(
                    "These details help us match you with someone whose habits align with yours.",
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 20),

                  // 1) Smoking
                  buildRadioGroup(
                    title: "1. Smoking Habits:",
                    options: controller.smokingOptions,
                    groupValue: controller.smokingKey,
                    onChanged: controller.selectSmoking,
                  ),

                  // 2) Drinking
                  buildRadioGroup(
                    title: "2. Drinking Habits:",
                    options: controller.drinkingOptions,
                    groupValue: controller.drinkingKey,
                    onChanged: controller.selectDrinking,
                  ),

                  // 3) Diet
                  buildRadioGroup(
                    title: "3. Dietary Preferences:",
                    options: controller.dietOptions,
                    groupValue: controller.dietKey,
                    onChanged: controller.selectDiet,
                  ),

                  // 4) Workout
                  buildRadioGroup(
                    title: "4. Workout Frequency:",
                    options: controller.workoutOptions,
                    groupValue: controller.workoutKey,
                    onChanged: controller.selectWorkout,
                  ),

                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed:
                      controller.isLoading.value ? null : controller.submitHabits,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        "Next",
                        style: Theme.of(context)
                            .textTheme
                            .labelLarge
                            ?.copyWith(color: Colors.white),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
            if (controller.isLoading.value)
              const Center(child: CircularProgressIndicator()),
          ],
        ),
      ),
    );
  }
}
