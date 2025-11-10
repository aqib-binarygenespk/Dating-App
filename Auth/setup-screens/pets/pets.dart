import 'package:dating_app/Auth/setup-screens/pets/pets_controller.dart';
import 'package:dating_app/themesfolder/theme.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class PetsSelectionScreen extends StatelessWidget {
  final bool fromEdit;

  const PetsSelectionScreen({super.key, this.fromEdit = false}); // ✅ Accept fromEdit

  @override
  Widget build(BuildContext context) {
    final PetsSelectionController controller = Get.put(
      PetsSelectionController(fromEdit: fromEdit), // ✅ Inject controller with flag
    );

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context, true), // ✅ Return result for ProfileScreen refresh
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 16),
            Text("Pets", style: Theme.of(context).textTheme.bodyLarge),
            const SizedBox(height: 24),

            Expanded(
              child: ListView.builder(
                itemCount: controller.options.length,
                itemBuilder: (context, index) {
                  final option = controller.options[index];
                  return Obx(() {
                    final isSelected = controller.selectedOption.value == option;
                    return RadioListTile(
                      title: Text(
                        option,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: isSelected ? Colors.black : Colors.grey.shade700,
                        ),
                      ),
                      value: option,
                      groupValue: controller.selectedOption.value,
                      activeColor: Colors.black,
                      onChanged: (value) {
                        controller.selectOption(value.toString());
                      },
                    );
                  });
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
                onPressed: controller.selectedOption.value.isEmpty
                    ? null
                    : controller.submitAnswer,
                child: Text(
                  'Next',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(color: Colors.white),
                ),
              ),
            )),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
