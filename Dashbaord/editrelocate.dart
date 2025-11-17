import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../../themesfolder/theme.dart';
import 'editrelocatecontroller.dart';

class EditRelocateLoveScreen extends StatelessWidget {
  const EditRelocateLoveScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(EditRelocateLoveController());

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context, true), // return result for refresh
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
                const SizedBox(height: 16),
                Text('Relocate for Love',
                    style: Theme.of(context).textTheme.bodyLarge),
                const SizedBox(height: 10),
                Text(
                  "Update your relocation preference. Let others know how open you are to moving for a relationship.",
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 20),

                // Options — RadioListTile (matches Pets)
                Expanded(
                  child: ListView.builder(
                    itemCount: controller.options.length,
                    itemBuilder: (context, index) {
                      final option = controller.options[index];
                      return Obx(() {
                        final isSelected =
                            controller.selected.value == option;
                        return RadioListTile<String>(
                          contentPadding: EdgeInsets.zero, // remove side padding
                          dense: true, // makes it more compact vertically
                          visualDensity: const VisualDensity(
                            horizontal: 0,
                            vertical: -3, // reduce vertical spacing (-1 to -4 for tighter)
                          ),
                          title: Text(
                            option,
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: isSelected ? Colors.black : Colors.grey.shade700,
                            ),
                          ),
                          value: option,
                          groupValue: controller.selected.value,
                          activeColor: Colors.black,
                          onChanged: controller.isLoading.value
                              ? null
                              : (value) => controller.selectOption(value ?? ''),
                        )
                        ;
                      });
                    },
                  ),
                ),

                const SizedBox(height: 16),
                // Update button — same sizing and text style as Pets
                SizedBox(
                  width: double.infinity,
                  child: Obx(
                        () => ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: controller.selected.value.isNotEmpty &&
                            !controller.isLoading.value
                            ? Colors.black
                            : Colors.black12,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: controller.selected.value.isNotEmpty &&
                            !controller.isLoading.value
                            ? 2
                            : 0,
                      ),
                      onPressed: controller.selected.value.isNotEmpty &&
                          !controller.isLoading.value
                          ? controller.submit
                          : null,
                      child: controller.isLoading.value
                          ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                          : Text(
                        'Update',
                        style: Theme.of(context)
                            .textTheme
                            .labelLarge
                            ?.copyWith(color: Colors.white),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),

          // Optional global loading overlay (kept from your original)
          if (controller.isLoading.value)
            const Center(child: CircularProgressIndicator()),
        ],
      )),
    );
  }
}
