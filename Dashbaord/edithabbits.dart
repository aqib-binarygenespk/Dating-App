import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../../themesfolder/theme.dart';
import '../../../../dashboard/Dashboard.dart'; // exports `settingsNavId`
import 'edithabbitscontroller.dart';

class EditHabitsScreen extends StatelessWidget {
  const EditHabitsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = Get.put(EditHabitsController());

    // ---------- Labels ----------
    const smokingLabels = <int, String>{
      1: 'Non-smoker',
      2: 'Occasional Smoker',
      3: 'Regular Smoker',
    };
    const drinkingLabels = <int, String>{
      1: 'Non-Drinker',
      2: 'Social Drinker',
      3: 'Regular Drinker',
    };
    const dietLabels = <int, String>{
      1: 'Omnivore',
      2: 'Vegetarian',
      3: 'Vegan',
      4: 'Gluten-Free',
      5: 'Pescatarian',
      6: 'Other (with an option to specify)',
    };

    // ---------- UI ↔ Backend mapping helpers ----------
    int _smokingUi() => c.backendToUiSmoking(c.smokingHabitId.value);
    int _drinkingUi() => c.backendToUiDrinking(c.drinkingHabitId.value);
    int _dietUi() => c.backendToUiDiet(c.dietaryPreferenceId.value);

    void _onSmoking(int uiId) => c.updateSmoking(c.uiToBackendSmoking(uiId));
    void _onDrinking(int uiId) => c.updateDrinking(c.uiToBackendDrinking(uiId));
    void _onDiet(int uiId) => c.updateDiet(c.uiToBackendDiet(uiId));

    // ---------- Radio group builder with selected=black / unselected=grey ----------
    Widget buildRadioGroup({
      required String title,
      required Map<int, String> options,
      required int Function() getUiValue,
      required void Function(int) onChangedUi,
    }) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AppTheme.textTheme.bodyLarge),
          const SizedBox(height: 8),
          ...options.entries.map(
                (e) => Obx(
                  () {
                final isSelected = getUiValue() == e.key;
                return RadioListTile<int>(
                  title: Text(
                    e.value,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: isSelected ? Colors.black : Colors.grey.shade700,
                    ),
                  ),
                  value: e.key,
                  groupValue: getUiValue(),
                  onChanged: (val) {
                    if (val != null) onChangedUi(val);
                  },
                  activeColor: Colors.black,
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  visualDensity: const VisualDensity(horizontal: -2, vertical: -1),
                );
              },
            ),
          ),
          const SizedBox(height: 20),
        ],
      );
    }

    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {
        if (!didPop) {
          Get.back(id: settingsNavId, result: false); // nested navigator pop
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
        body: Obx(
              () => Stack(
            children: [
              SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Edit Your Habits", style: Theme.of(context).textTheme.bodyLarge),
                    const SizedBox(height: 10),
                    Text(
                      "Update your lifestyle preferences to help us find the best match for you.",
                      style: AppTheme.textTheme.bodySmall?.copyWith(color: Colors.black54),
                    ),
                    const SizedBox(height: 20),

                    // Smoking
                    buildRadioGroup(
                      title: "Smoking Habits:",
                      options: smokingLabels,
                      getUiValue: _smokingUi,
                      onChangedUi: _onSmoking,
                    ),

                    // Drinking
                    buildRadioGroup(
                      title: "Drinking Habits:",
                      options: drinkingLabels,
                      getUiValue: _drinkingUi,
                      onChangedUi: _onDrinking,
                    ),

                    // Diet
                    buildRadioGroup(
                      title: "Dietary Preferences:",
                      options: dietLabels,
                      getUiValue: _dietUi,
                      onChangedUi: _onDiet,
                    ),

                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: c.isLoading.value ? null : c.submit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          c.isLoading.value ? "Saving..." : "Update",
                          style: Theme.of(context).textTheme.labelLarge?.copyWith(color: Colors.white),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),

              if (c.isLoading.value) const Center(child: CircularProgressIndicator()),
            ],
          ),
        ),
      ),
    );
  }
}
