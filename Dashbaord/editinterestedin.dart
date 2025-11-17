import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../../themesfolder/theme.dart';
import '../../../../dashboard/Dashboard.dart'; // <-- for settingsNavId
import 'editinterestedincontroller.dart';

class EditInterestedInScreen extends StatelessWidget {
  const EditInterestedInScreen({super.key});

  Future<bool> _handleSystemBack() async {
    // ✅ Ensure we pop the nested navigator that this screen was pushed on
    Get.back(id: settingsNavId, result: false);
    return false; // prevent default pop; we handled it
  }

  @override
  Widget build(BuildContext context) {
    final EditInterestedInController controller =
    Get.put(EditInterestedInController());

    return WillPopScope(
      onWillPop: _handleSystemBack, // handles Android back / iOS swipe
      child: Scaffold(
        backgroundColor: AppTheme.backgroundColor,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.black),
            // ✅ Pop the same nested navigator this page was pushed onto
            onPressed: () => Get.back(id: settingsNavId, result: false),
          ),
          title: Text('Interested In', style: AppTheme.textTheme.bodyLarge),
          centerTitle: false,
        ),
        body: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 12),

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
                child: Obx(
                      () => DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: controller.selected.value, // 'Male' | 'Female' | etc.
                      onChanged: (String? newValue) {
                        if (newValue != null) {
                          controller.selectOption(newValue);
                        }
                      },
                      items: controller.options
                          .map(
                            (opt) => DropdownMenuItem<String>(
                          value: opt,
                          child: Padding(
                            padding:
                            const EdgeInsets.symmetric(vertical: 8.0),
                            child: Text(opt),
                          ),
                        ),
                      )
                          .toList(),
                      isExpanded: true,
                      dropdownColor: AppTheme.backgroundColor,
                      icon: const Icon(Icons.arrow_drop_down, color: Colors.black),
                      alignment: Alignment.centerLeft,
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),

              const Spacer(),

              SizedBox(
                width: double.infinity,
                child: Obx(
                      () => ElevatedButton(
                    onPressed: controller.isLoading.value ? null : () async {
                      final ok = await controller.submit();
                      // If your controller.submit() does not already pop,
                      // you can pop here on success:
                      if (ok == true) {
                        Get.back(id: settingsNavId, result: true);
                      }
                    },
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
                      style: TextStyle(fontSize: 16, color: Colors.white),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
