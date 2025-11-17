import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../../themesfolder/theme.dart';
import '../../../../dashboard/Dashboard.dart'; // for settingsNavId
import 'editattachmentcontroller.dart' hide settingsNavId;

const _kQuizUrl =
    'https://www.attachedthebook.com/wordpress/compatibility-quiz/?step=1';

class EditAttachmentStyleScreen extends StatelessWidget {
  const EditAttachmentStyleScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(EditAttachmentStyleController());

    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {
        if (!didPop) {
          // ✅ Always close via nested navigator
          Get.back(id: settingsNavId, result: false);
        }
      },
      child: Scaffold(
        backgroundColor: AppTheme.backgroundColor,
        appBar: AppBar(
          backgroundColor: AppTheme.backgroundColor,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.black),
            // ✅ Force nested navigator
            onPressed: () => Get.back(id: settingsNavId, result: false),
          ),
        ),
        body: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),
              Text(
                "Attachment Style",
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: 8),
              Text(
                "Understanding your attachment style can provide insight into how you connect with others emotionally. Choose the style that best represents you.",
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 24),

              Expanded(
                child: ListView(
                  children: [
                    ...controller.options.map(
                          (option) => Obx(
                            () => RadioListTile<String>(
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
                          onChanged: (value) {
                            if (value != null) controller.selectOption(value);
                          },
                          activeColor: Colors.black,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    const _QuizBlock(),
                  ],
                ),
              ),

              Obx(
                    () => SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: controller.isLoading.value ? null : controller.submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: controller.isLoading.value
                        ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                        : const Text(
                      "Update",
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

class _QuizBlock extends StatelessWidget {
  const _QuizBlock();

  Future<void> _launchQuiz() async {
    final uri = Uri.parse(_kQuizUrl);
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok) {
      Get.snackbar(
        'Couldn’t open',
        'Please try again in your browser',
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final textStyle = Theme.of(context).textTheme.bodySmall;

    return Container(
      margin: const EdgeInsets.only(top: 6, bottom: 16),
      decoration: BoxDecoration(
        color: AppTheme.backgroundColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFFFEFEF).withOpacity(0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Take a quick 3-minute quiz to discover your attachment style and learn more about yourself!",
            style: textStyle,
          ),
          const SizedBox(height: 8),
          InkWell(
            onTap: _launchQuiz,
            borderRadius: BorderRadius.circular(8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.link, size: 18),
                const SizedBox(width: 6),
                Text(
                  "Start The Quiz",
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    decoration: TextDecoration.underline,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
