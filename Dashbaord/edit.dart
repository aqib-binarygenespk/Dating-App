import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:dating_app/themesfolder/theme.dart';
import 'editcontroller.dart';

class EditEventScreen extends StatelessWidget {
  final Map<String, dynamic> event;
  const EditEventScreen({super.key, required this.event});

  @override
  Widget build(BuildContext context) {
    final EditEventController c = Get.put(EditEventController(event: event));
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        elevation: 0,
        title: Text("Update A PairUp Event", style: AppTheme.textTheme.bodyLarge),
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
              controller: c.nameController,
              style: textTheme.bodyMedium,
              decoration: _decoration("Tap to Enter The Name", textTheme),
            ),
            const SizedBox(height: 15),

            _label("Location*", textTheme),
            TextField(
              controller: c.locationController,
              style: textTheme.bodyMedium,
              decoration: _decoration("Enter event location", textTheme),
            ),
            const SizedBox(height: 15),

            _label("Description", textTheme),
            TextField(
              controller: c.descriptionController,
              style: textTheme.bodyMedium,
              maxLines: null,
              decoration: _decoration("Enter event description", textTheme),
            ),
            const SizedBox(height: 15),

            _label("Time And Date*", textTheme),
            GestureDetector(
              onTap: () => c.selectDateTime(context),
              child: Obx(() => Container(
                padding: const EdgeInsets.all(15),
                decoration: _boxDecoration(),
                child: Text(
                  c.fmt(c.selectedDateTime.value),
                  style: textTheme.bodySmall?.copyWith(color: Colors.black54),
                ),
              )),
            ),
            const SizedBox(height: 15),

            _label("Event Photo", textTheme),
            GestureDetector(
              onTap: () => _pickImage(context, c),
              child: Obx(() {
                final file = c.selectedImage.value;
                final url = c.photoUrl.value;
                return Container(
                  height: 160,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: AppTheme.backgroundColor,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFD9D9D9), width: 1),
                  ),
                  child: file != null
                      ? ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.file(file, fit: BoxFit.cover),
                  )
                      : (url.isNotEmpty
                      ? ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(url, fit: BoxFit.cover),
                  )
                      : const Icon(Icons.add_a_photo, size: 50, color: Colors.black54)),
                );
              }),
            ),
            const SizedBox(height: 30),

            SizedBox(
              height: 44,
              width: double.infinity,
              child: Obx(() => ElevatedButton(
                onPressed: c.isLoading.value ? null : () => c.updateEvent(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: c.isLoading.value
                    ? const SizedBox(
                  height: 20, width: 20,
                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                )
                    : const Text(
                  "Update",
                  style: TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.backgroundColor),
                ),
              )),
            ),
          ],
        ),
      ),
    );
  }

  Widget _label(String text, TextTheme textTheme) =>
      Text(text, style: textTheme.labelLarge?.copyWith(color: Colors.black));

  InputDecoration _decoration(String hint, TextTheme textTheme) => InputDecoration(
    hintText: hint,
    hintStyle: textTheme.bodySmall?.copyWith(color: Colors.black45),
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
    filled: true,
    fillColor: const Color(0xFFFFEFEF),
    contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
  );

  BoxDecoration _boxDecoration() => BoxDecoration(
    color: const Color(0xFFFFEFEF),
    borderRadius: BorderRadius.circular(8),
    border: Border.all(color: const Color(0xFFD9D9D9), width: 1),
  );

  void _pickImage(BuildContext context, EditEventController c) {
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Wrap(
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
      ),
    );
  }
}
