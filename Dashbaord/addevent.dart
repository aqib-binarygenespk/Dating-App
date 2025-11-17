import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/services.dart';
import 'package:dating_app/themesfolder/theme.dart';

import 'addevent_controller.dart';
import 'invitatioondropdown.dart';

/// Custom formatter to capitalize only the first character
class SentenceCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue,
      TextEditingValue newValue,
      ) {
    String text = newValue.text;
    if (text.isNotEmpty) {
      text = text[0].toUpperCase() + text.substring(1);
    }
    return newValue.copyWith(
      text: text,
      selection: newValue.selection,
    );
  }
}

class AddEventScreen extends StatefulWidget {
  const AddEventScreen({super.key});

  @override
  State<AddEventScreen> createState() => _AddEventScreenState();
}

class _AddEventScreenState extends State<AddEventScreen> {
  late final AddEventController controller;

  @override
  void initState() {
    super.initState();
    controller = Get.put(AddEventController());
    // Always start with a clean form when opening this screen
    controller.resetForm();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        elevation: 0,
        title: Text("Create A PairUp Event", style: AppTheme.textTheme.bodyLarge),
        centerTitle: false,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Get.back(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _label("Name of the PairUp Event*", textTheme),
            TextField(
              controller: controller.nameController,
              style: textTheme.bodyMedium,
              decoration: _decoration("Tap to Enter The Name", textTheme),
              inputFormatters: [SentenceCaseTextFormatter()], // Only first letter uppercase
            ),
            const SizedBox(height: 15),

            _label("Location*", textTheme),
            TextField(
              controller: controller.locationController,
              style: textTheme.bodyMedium,
              decoration: _decoration("Enter event location", textTheme),
              inputFormatters: [SentenceCaseTextFormatter()], // Only first letter uppercase
            ),
            const SizedBox(height: 15),

            _label("Description", textTheme),
            TextField(
              controller: controller.descriptionController,
              style: textTheme.bodyMedium,
              maxLines: null,
              decoration: _decoration("Enter event description", textTheme),
              inputFormatters: [SentenceCaseTextFormatter()],
              // description stays normal
            ),
            const SizedBox(height: 15),

            _label("Time And Date*", textTheme),
            GestureDetector(
              onTap: () => controller.selectDateTime(context),
              child: Obx(
                    () => Container(
                  padding: const EdgeInsets.all(15),
                  decoration: _box(),
                  child: Text(
                    controller.selectedDateTime.value != null
                        ? DateFormat('MMM d, yyyy – hh:mm a').format(
                      controller.selectedDateTime.value!,
                    )
                        : "Select a date and time",
                    style: textTheme.bodySmall?.copyWith(color: Colors.black54),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 15),

            _label("Event Photo", textTheme),
            GestureDetector(
              onTap: () => _pickImage(context, controller),
              child: Obx(
                    () => Container(
                  height: 160,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: AppTheme.backgroundColor,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFD9D9D9), width: 1),
                  ),
                  child: controller.selectedImage.value == null
                      ? const Icon(Icons.add_a_photo, size: 50, color: Colors.black54)
                      : ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.file(
                      controller.selectedImage.value!,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 15),

            _label("Invite People", textTheme),
            const SizedBox(height: 6),
            InviteDropdownField(controller: controller, maxSelect: 5),

            const SizedBox(height: 30),

            SizedBox(
              height: 40,
              width: double.infinity,
              child: Obx(
                    () => ElevatedButton(
                  onPressed: controller.isLoading.value ? null : controller.submitEvent,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: controller.isLoading.value
                      ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                      : const Text(
                    "Save",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.backgroundColor,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _label(String text, TextTheme tt) =>
      Text(text, style: tt.labelLarge?.copyWith(color: Colors.black));

  InputDecoration _decoration(String hint, TextTheme tt) => InputDecoration(
    hintText: hint,
    hintStyle: tt.bodySmall?.copyWith(color: Colors.black45),
    filled: true,
    fillColor: const Color(0xFFFFEFEF),
    contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: const BorderSide(color: Color(0xFFD9D9D9), width: 1),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: const BorderSide(color: Color(0xFFD9D9D9), width: 1),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: const BorderSide(color: Color(0xFFD9D9D9), width: 1),
    ),
  );

  BoxDecoration _box() => BoxDecoration(
    color: const Color(0xFFFFEFEF),
    borderRadius: BorderRadius.circular(8),
    border: Border.all(color: const Color(0xFFD9D9D9), width: 1),
  );

  void _pickImage(BuildContext context, AddEventController c) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Wrap(
        children: [
          ListTile(
            leading: const Icon(Icons.photo_library),
            title: const Text('Choose from Gallery'),
            onTap: () {
              Get.back();
              c.pickImage(ImageSource.gallery);
            },
          ),
          ListTile(
            leading: const Icon(Icons.camera_alt),
            title: const Text('Take a Picture'),
            onTap: () {
              Get.back();
              c.pickImage(ImageSource.camera);
            },
          ),
        ],
      ),
    );
  }
}
