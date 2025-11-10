// lib/controllers/about_me_controller.dart
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hive/hive.dart';
import '../../../services/api_services.dart';
import '../../../hive_utils/hive_boxes.dart';
import '../../../Dashbaord/profile/profile_controller.dart';

class AboutMeController extends GetxController {
  final bool fromEdit;
  AboutMeController({this.fromEdit = false});

  final TextEditingController aboutMeController = TextEditingController();
  final int maxLength = 300;
  final isLoading = false.obs;
  final charCount = 0.obs;

  @override
  void onInit() {
    super.onInit();

    // Prefill from locally saved value if available (non-breaking)
    final box = Hive.box(HiveBoxes.userBox);
    final saved = box.get('about_me');
    if (saved is String && saved.trim().isNotEmpty) {
      aboutMeController.text = _ensureFirstLetterCapital(saved.trim());
      charCount.value = aboutMeController.text.length;
    }

    aboutMeController.addListener(() {
      charCount.value = aboutMeController.text.length;
    });
  }

  void onTextChanged(String value) {
    // Optional: live validation or formatting could go here
  }

  Future<void> submitAboutMe() async {
    final token = _getToken();
    if (token == null) {
      Get.snackbar("Error", "Missing token. Please log in again.");
      return;
    }

    String bio = aboutMeController.text.trim();
    bio = _ensureFirstLetterCapital(bio);

    if (bio.isEmpty) {
      Get.snackbar("Error", "Please enter something about yourself.");
      return;
    }

    if (bio.length > maxLength) {
      bio = bio.substring(0, maxLength);
      aboutMeController.text = bio; // reflect clamp in UI
      aboutMeController.selection = TextSelection.fromPosition(
        TextPosition(offset: aboutMeController.text.length),
      );
    }

    // Save locally (optional)
    final box = Hive.box(HiveBoxes.userBox);
    box.put('about_me', bio);

    isLoading.value = true;

    try {
      // Same endpoint for setup & edit (kept as in your code)
      final response = await ApiService.post(
        'about-me',
        {'bio': bio},
        token: token,
      );

      if (response['success'] == true) {
        // Refresh profile everywhere
        final profileController =
        _getOrCreate<ProfileController>(() => ProfileController());
        await profileController.fetchProfile();

        isLoading.value = false;

        if (fromEdit) {
          Get.snackbar("Success", response['message'] ?? "About Me updated");
          Get.back(result: true);
        } else {
          Get.snackbar("Success", response['message'] ?? "About Me saved");
          Get.toNamed('/Relationshipgoal'); // continue setup flow
        }
      } else {
        isLoading.value = false;
        Get.snackbar("Error", response['message'] ?? "Update failed");
      }
    } catch (e) {
      isLoading.value = false;
      Get.snackbar("Error", "Submission failed. Try again.");
    }
  }

  @override
  void onClose() {
    aboutMeController.dispose();
    super.onClose();
  }

  // ----------------- Helpers -----------------

  String? _getToken() {
    final box = Hive.box(HiveBoxes.userBox);
    return box.get('auth_token') ?? box.get('token') ?? box.get('access_token');
  }

  T _getOrCreate<T>(T Function() create) {
    try {
      return Get.find<T>();
    } catch (_) {
      return Get.put<T>(create());
    }
  }

  String _ensureFirstLetterCapital(String input) {
    if (input.isEmpty) return input;
    final first = input[0].toUpperCase();
    final rest = input.length > 1 ? input.substring(1) : '';
    return '$first$rest';
  }
}
