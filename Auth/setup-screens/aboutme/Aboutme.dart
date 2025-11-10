// lib/screens/about_me/about_me_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import '../../../themesfolder/theme.dart';
import 'aboutme_controller.dart';

class AboutMeScreen extends StatelessWidget {
  final bool fromEdit;

  const AboutMeScreen({Key? key, this.fromEdit = false}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final AboutMeController controller =
    Get.put(AboutMeController(fromEdit: fromEdit));

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        backgroundColor: AppTheme.backgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context, true),
        ),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            padding: EdgeInsets.only(
              left: 24,
              right: 24,
              bottom: MediaQuery.of(context).viewInsets.bottom + 24,
              top: 0,
            ),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: IntrinsicHeight(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 16),
                    Text("About Me", style: Theme.of(context).textTheme.bodyLarge),
                    const SizedBox(height: 8),
                    Text(
                      "Share a little about yourself! Highlight your interests, what makes "
                          "you unique, and what you're looking for on The PairUp. Try to make "
                          "it friendly and engaging—it's your chance to make a great first impression!",
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 24),
                    Obx(
                          () => TextField(
                        controller: controller.aboutMeController,
                        maxLength: controller.maxLength,
                        maxLengthEnforcement: MaxLengthEnforcement.enforced,
                        maxLines: 5,
                        keyboardType: TextInputType.multiline,
                        textInputAction: TextInputAction.newline,
                        // ✅ Suggest capital letter on keyboards
                        textCapitalization: TextCapitalization.sentences,
                        // ✅ Enforce first character capital even if keyboard doesn’t
                        inputFormatters: const [CapitalizeFirstLetterFormatter()],
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
                            borderSide: const BorderSide(color: Colors.blueAccent),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 16,
                            horizontal: 16,
                          ),
                          counterText:
                          "${controller.charCount.value}/${controller.maxLength}",
                        ),

                        onChanged: controller.onTextChanged,


                      ),
                    ),
                    const Spacer(),
                    Obx(
                          () => SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: controller.isLoading.value
                              ? null
                              : controller.submitAboutMe,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.black87,
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
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                              : Text(
                            fromEdit ? 'Save' : 'Next',
                            style: const TextStyle(
                                fontSize: 16, color: Colors.white),
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
        },
      ),
    );
  }
}

/// A simple formatter that forces the very first character to uppercase,
/// while preserving the rest of the text and the cursor position.
class CapitalizeFirstLetterFormatter extends TextInputFormatter {
  const CapitalizeFirstLetterFormatter();

  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    final text = newValue.text;
    if (text.isEmpty) return newValue;

    final first = text[0].toUpperCase();
    final rest = text.length > 1 ? text.substring(1) : '';
    final transformed = '$first$rest';

    // If nothing changed, keep as-is
    if (transformed == text) return newValue;

    // Keep the cursor near where the user was typing
    final baseOffset = newValue.selection.baseOffset;
    final extentOffset = newValue.selection.extentOffset;
    return newValue.copyWith(
      text: transformed,
      selection: TextSelection(
        baseOffset: baseOffset,
        extentOffset: extentOffset,
      ),
      composing: TextRange.empty,
    );
  }
}
