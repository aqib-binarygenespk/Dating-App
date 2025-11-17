import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hive/hive.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../services/api_services.dart';
import '../../../../hive_utils/hive_boxes.dart';
import '../../dashboard/Dashboard.dart';
import '../pairup/pairup_controller.dart';

class AddEventController extends GetxController {
  // Text inputs
  final nameController = TextEditingController();
  final locationController = TextEditingController();
  final descriptionController = TextEditingController();

  /// Selected invitees: [{id, name}]
  final invitedPeople = <Map<String, dynamic>>[].obs;

  /// Backend results for the dropdown
  final searchResults = <Map<String, dynamic>>[].obs;

  final selectedDateTime = Rxn<DateTime>();
  final selectedImage = Rxn<File>();
  final isLoading = false.obs;

  // invite search UX
  final isSearching = false.obs;

  // --- debounce for typing ---
  Timer? _searchDebounce;

  /// Reset the whole form so a new event starts empty.
  void resetForm() {
    nameController.clear();
    locationController.clear();
    descriptionController.clear();

    invitedPeople.clear();
    searchResults.clear();

    selectedDateTime.value = null;
    selectedImage.value = null;

    isLoading.value = false;
    isSearching.value = false;

    _searchDebounce?.cancel();
    _searchDebounce = null;
  }

  /// Call this from the invite input's onChanged
  void onInviteInputChanged(String value) {
    _searchDebounce?.cancel();
    final q = value.trim();
    if (q.isEmpty) {
      searchResults.clear();
      isSearching.value = false;
      return;
    }
    _searchDebounce = Timer(const Duration(milliseconds: 300), () {
      searchUsers(q);
    });
  }

  /// Add a user picked from search list
  void addUser({required int id, required String name}) {
    if (invitedPeople.length >= 5) {
      Get.snackbar('Limit', 'You can invite up to 5 people.');
      return;
    }
    final exists = invitedPeople.any((e) => e['id'] == id);
    if (!exists) invitedPeople.add({'id': id, 'name': name});
  }

  void removeUser(Map<String, dynamic> person) => invitedPeople.remove(person);

  /// Hit /search-users?q=... (accepted social_circle friends, backend caps at 10)
  Future<void> searchUsers(String query) async {
    final box = Hive.box(HiveBoxes.userBox);
    final token = box.get('auth_token') ?? box.get('token');
    if (token == null || (token is String && token.isEmpty)) {
      // surface the issue early during dev
      Get.snackbar("Auth", "Token missing. Please login again.");
      searchResults.clear();
      isSearching.value = false;
      return;
    }

    try {
      isSearching.value = true;
      final encoded = Uri.encodeQueryComponent(query);
      final resp = await ApiService.get('search-users?q=$encoded', token: token);

      // Expected from your backend:
      // { success: bool, message: string, data: List<{ id, first_name, last_name, photo_url }> }
      final data = resp is Map<String, dynamic> ? resp['data'] : null;

      if (data is List) {
        // ensure it's a list of map
        final raw = data
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();

        final selectedIds = invitedPeople.map((e) => e['id']).toSet();
        searchResults.value = raw.where((u) => !selectedIds.contains(u['id'])).toList();
      } else {
        // 404 or unexpected -> just clear
        searchResults.clear();
      }
    } catch (_) {
      searchResults.clear();
    } finally {
      isSearching.value = false;
    }
  }

  /// Image picker
  Future<void> pickImage(ImageSource source) async {
    final picked = await ImagePicker().pickImage(source: source);
    if (picked != null) selectedImage.value = File(picked.path);
  }

  /// Date & time picker
  Future<void> selectDateTime(BuildContext context) async {
    final d = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );
    if (d == null) return;

    final t = await showTimePicker(context: context, initialTime: TimeOfDay.now());
    if (t == null) return;

    selectedDateTime.value = DateTime(d.year, d.month, d.day, t.hour, t.minute);
  }

  /// Submit event
  Future<void> submitEvent() async {
    final box = Hive.box(HiveBoxes.userBox);
    final token = box.get('auth_token') ?? box.get('token');
    if (token == null || (token is String && token.isEmpty)) {
      Get.snackbar("Error", "Missing token. Please login again.");
      return;
    }
    if (nameController.text.isEmpty ||
        locationController.text.isEmpty ||
        selectedDateTime.value == null ||
        selectedImage.value == null) {
      Get.snackbar("Validation", "Please fill all required fields.");
      return;
    }

    isLoading.value = true;
    try {
      // invited_users[0]=12, invited_users[1]=34, ...
      final invitedUserFields = <String, String>{};
      for (var i = 0; i < invitedPeople.length; i++) {
        invitedUserFields['invited_users[$i]'] = invitedPeople[i]['id'].toString();
      }

      final resp = await ApiService.postMultipart(
        endpoint: 'events',
        fields: {
          'name': nameController.text,
          'location': locationController.text,
          'description': descriptionController.text,
          'time_and_date': selectedDateTime.value!.toIso8601String(),
          ...invitedUserFields,
        },
        files: [selectedImage.value!],
        fileField: 'photo_path',
        token: token,
      );

      if (resp['success'] == true || resp['status'] == true) {
        // refresh events list if controller is present
        if (Get.isRegistered<PairUpController>()) {
          await Get.find<PairUpController>().fetchEvents();
        }
        Get.snackbar("Success", "Event created successfully");

        // Optional: also clear the form right after a successful create
        resetForm();

        Get.off(() => const DashboardScreen(selectedIndex: 2));
      } else {
        if (resp['errors'] is Map) {
          final errors = resp['errors'] as Map;
          final messages = errors.values.expand((v) => v).join('\n');
          Get.snackbar("Validation Error", messages);
        } else {
          Get.snackbar("Error", resp['message']?.toString() ?? "Failed to create event.");
        }
      }
    } catch (e) {
      Get.snackbar("Error", "Failed to submit event.");
    } finally {
      isLoading.value = false;
    }
  }

  @override
  void onClose() {
    _searchDebounce?.cancel();
    nameController.dispose();
    locationController.dispose();
    descriptionController.dispose();
    super.onClose();
  }
}
