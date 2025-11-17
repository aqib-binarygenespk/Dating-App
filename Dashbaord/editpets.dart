import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../../themesfolder/theme.dart';
import '../../../../dashboard/Dashboard.dart';
import 'editpetscontroller.dart';

class EditPetsScreen extends StatelessWidget {
  const EditPetsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(EditPetsController());

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
            const SizedBox(height: 16),
            Text("Pets", style: Theme.of(context).textTheme.bodyLarge),
            const SizedBox(height: 8),
            Text(
              "Let others know your pet preferences. Select the option that best represents you.",
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 24),
            Expanded(
              child: ListView.builder(
                itemCount: controller.options.length,
                itemBuilder: (context, index) {
                  final option = controller.options[index];
                  return Obx(() => RadioListTile<String>(
                    title: Text(
                      option,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: controller.selectedOption.value == option
                            ? Colors.black
                            : Colors.grey.shade700,
                      ),
                    ),
                    value: option,
                    groupValue: controller.selectedOption.value,
                    activeColor: Colors.black,
                    onChanged: (value) =>
                        controller.selectOption(value ?? ''),
                  ));
                },
              ),
            ),
            const SizedBox(height: 16),
            Obx(() => SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: controller.isLoading.value
                    ? null
                    : controller.submit,
                child: controller.isLoading.value
                    ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                )
                    : const Text(
                  'Update',
                  style: TextStyle(fontSize: 16, color: Colors.white),
                ),
              ),
            )),
            const SizedBox(height: 16),
          ],
        ),
      ),
    ));
  }
}
