import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../../themesfolder/theme.dart';
import '../../../../dashboard/Dashboard.dart'; // <-- if this exports settingsNavId, keep it
import '../../../../pairupscreens/addevent/addevent.dart';
import 'editaboutmecontroller.dart' hide settingsNavId;

class EditAboutMeScreen extends StatelessWidget {
  const EditAboutMeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(EditAboutMeController());

    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {
        if (!didPop) {
          Get.back(id: settingsNavId, result: false);
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
        body: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("About Me", style: Theme.of(context).textTheme.bodyLarge),
              const SizedBox(height: 8),
              Text(
                "Write something to let others know about your personality, interests, and values.",
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 20),
              TextField(
                controller: controller.aboutMeController,
                maxLines: 5,
                maxLength: controller.maxLength,
                decoration: InputDecoration(
                  hintText: "Write about yourself...",
                  filled: true,
                  fillColor: AppTheme.backgroundColor,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Colors.black),
                  ),
                  contentPadding:
                  const EdgeInsets.symmetric(vertical: 16, horizontal: 16),

                ),
                inputFormatters: [SentenceCaseTextFormatter()],
              ),
              const Spacer(),
              Obx(
                    () => SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: controller.isLoading.value
                        ? null
                        : () async {
                      final ok = await controller.submitAboutMe();
                      if (ok) {
                        Get.back(id: settingsNavId, result: true);
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black87,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: controller.isLoading.value
                        ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                        : const Text(
                      'Update',
                      style: TextStyle(fontSize: 16, color: Colors.white),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
