import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../themesfolder/theme.dart';
import 'interestedIn_controller.dart';

class InterestedInScreen extends StatelessWidget {
  final bool fromEdit;

  const InterestedInScreen({super.key, this.fromEdit = false}); // ✅ Add fromEdit

  @override
  Widget build(BuildContext context) {
    final InterestedInController controller = Get.put(InterestedInController(fromEdit: fromEdit)); // ✅ Pass fromEdit

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context, true), // ✅ Return result: true to refresh Profile
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Interested In',
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ],
            ),
            const SizedBox(height: 20),
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
              child: Obx(() => DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: controller.selectedInterest.value,
                  onChanged: (String? newValue) {
                    if (newValue != null) {
                      controller.updateInterest(newValue);
                    }
                  },
                  items: <String>['male', 'female']
                      .map<DropdownMenuItem<String>>((String value) {
                    return DropdownMenuItem<String>(
                      value: value,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8.0),
                        child: Text(value),
                      ),
                    );
                  }).toList(),
                  isExpanded: true,
                  dropdownColor: AppTheme.backgroundColor,
                  icon: const Icon(Icons.arrow_drop_down, color: Colors.black),
                  alignment: Alignment.centerLeft,
                  borderRadius: BorderRadius.circular(12),
                ),
              )),
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: Obx(() => ElevatedButton(
                onPressed: controller.isLoading.value
                    ? null
                    : () => controller.submitInterest(),
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
                  'Next',
                  style: TextStyle(fontSize: 16, color: Colors.white),
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
