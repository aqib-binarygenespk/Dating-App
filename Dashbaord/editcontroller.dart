import 'dart:io';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:hive/hive.dart';
import 'package:intl/intl.dart';
import '../../../../hive_utils/hive_boxes.dart';
import '../../../../services/api_services.dart';
import '../../../dashboard/Dashboard.dart';
import 'package:flutter/material.dart';

import '../pairup_controller.dart';

class EditEventController extends GetxController {
  final Map<String, dynamic> event;

  EditEventController({required this.event}) {
    nameController.text = event['name'] ?? '';
    locationController.text = event['location'] ?? '';
    descriptionController.text = event['description'] ?? '';
    photoUrl.value = (event['photo_url'] ?? event['photo_path'] ?? '') as String;

    // Parse time_and_date (ISO or local); keep null if it can’t parse
    if (event['time_and_date'] != null && event['time_and_date'].toString().trim().isNotEmpty) {
      selectedDateTime.value = DateTime.tryParse(event['time_and_date'].toString())?.toLocal();
    }
  }

  final TextEditingController nameController = TextEditingController();
  final TextEditingController locationController = TextEditingController();
  final TextEditingController descriptionController = TextEditingController();

  final Rx<DateTime?> selectedDateTime = Rx<DateTime?>(null);
  final Rx<File?> selectedImage = Rx<File?>(null);
  final RxString photoUrl = ''.obs;
  final RxBool isLoading = false.obs;

  // Image picker
  Future<void> pickImage(ImageSource source) async {
    final pickedFile = await ImagePicker().pickImage(source: source, imageQuality: 85);
    if (pickedFile != null) {
      selectedImage.value = File(pickedFile.path);
      photoUrl.value = ''; // Clear old URL preview when new image is chosen
    }
  }

  // Date & Time
  Future<void> selectDateTime(BuildContext context) async {
    final now = DateTime.now();
    final initial = selectedDateTime.value ?? now;
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: DateTime(2101),
    );
    if (pickedDate == null) return;

    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );
    if (pickedTime == null) return;

    selectedDateTime.value = DateTime(
      pickedDate.year,
      pickedDate.month,
      pickedDate.day,
      pickedTime.hour,
      pickedTime.minute,
    );
  }

  // Submit update
  Future<void> updateEvent() async {
    isLoading.value = true;

    try {
      final id = event['id'];
      final token = Hive.box(HiveBoxes.userBox).get('auth_token');
      if (token == null || token.toString().isEmpty) {
        Get.snackbar("Error", "Authentication token missing");
        isLoading.value = false;
        return;
      }

      if (nameController.text.trim().isEmpty ||
          locationController.text.trim().isEmpty ||
          selectedDateTime.value == null) {
        Get.snackbar("Error", "Please fill all required fields");
        isLoading.value = false;
        return;
      }

      // Prepare fields
      final Map<String, String> fields = {
        'name': nameController.text.trim(),
        'location': locationController.text.trim(),
        'description': descriptionController.text.trim(),
        // Send UTC ISO 8601 string to match your backend (it validates `date`)
        'time_and_date': selectedDateTime.value!.toUtc().toIso8601String(),
        // Laravel method override for multipart
        '_method': 'put',
      };

      // invited_users from existing event (if any) to keep them intact (server syncWithoutDetaching)
      final List<dynamic> invitedUsers = event['invited_users'] ?? [];
      for (int i = 0; i < invitedUsers.length; i++) {
        final uid = invitedUsers[i] is Map
            ? invitedUsers[i]['id'].toString()
            : invitedUsers[i].toString();
        fields['invited_users[$i]'] = uid;
      }

      // Multipart
      final response = await ApiService.postMultipart(
        endpoint: 'update-event/$id',
        files: selectedImage.value != null ? [selectedImage.value!] : [],
        fileField: 'photo_path',
        fields: fields,
        token: token,
      );

      if (response['success'] == true) {
        Get.snackbar("Success", "Event updated successfully");

        // Refresh PairUp list
        if (Get.isRegistered<PairUpController>()) {
          await Get.find<PairUpController>().fetchEvents();
        }

        // Navigate back to Dashboard PairUp tab (keep bottom nav)
        Get.off(() => const DashboardScreen(selectedIndex: 2));
      } else {
        Get.snackbar("Error", response['message'] ?? 'Update failed');
      }
    } catch (e) {
      Get.snackbar("Error", "Something went wrong: $e");
    } finally {
      isLoading.value = false;
    }
  }

  String fmt(DateTime? dt) {
    if (dt == null) return 'Select a date and time';
    return DateFormat('MMM d, yyyy – hh:mm a').format(dt);
  }
}
