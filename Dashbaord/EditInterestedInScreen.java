import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../../themesfolder/theme.dart';
import 'editinterestedincontroller.dart';

class EditInterestedInScreen extends StatelessWidget {
  const EditInterestedInScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final EditInterestedInController controller =
        Get.put(EditInterestedInController());

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Get.back(result: false),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Interested In',
                style: Theme.of(context).textTheme.bodyLarge),
            const SizedBox(height: 20),

            // Dropdown
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: AppTheme.backgroundColor,
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Obx(() {
                final current = controller.selectedInterest.value;
                return DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: (current.isNotEmpty &&
                            ['male', 'female'].contains(current))
                        ? current
                        : 'male', // safe fallback
                    onChanged: (String? newValue) {
                      if (newValue != null) {
                        controller.updateInterest(newValue);
                      }
                    },
                    items: const [
                      DropdownMenuItem(
                        value: 'male',
                        child: Padding(
                          padding: EdgeInsets.symmetric(vertical: 8.0),
                          child: Text("Male"),
                        ),
                      ),
                      DropdownMenuItem(
                        value: 'female',
                        child: Padding(
                          padding: EdgeInsets.symmetric(vertical: 8.0),
                          child: Text("Female"),
                        ),
                      ),
                    ],
                    isExpanded: true,
                    dropdownColor: AppTheme.backgroundColor,
                    icon: const Icon(Icons.arrow_drop_down,
                        color: Colors.black),
                    alignment: Alignment.centerLeft,
                    borderRadius: BorderRadius.circular(12),
                  ),
                );
              }),
            ),

            const Spacer(),

            // Submit button
            SizedBox(
              width: double.infinity,
              child: Obx(() => ElevatedButton(
                    onPressed: controller.isLoading.value
                        ? null
                        : controller.submitInterest,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF111827),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
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
                            style: TextStyle(
                                fontSize: 16, color: Colors.white),
                          ),
                  )),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
