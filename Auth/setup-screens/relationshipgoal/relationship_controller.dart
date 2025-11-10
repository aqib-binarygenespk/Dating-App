// lib/controllers/relationship_goal_controller.dart
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hive/hive.dart';

import '../../../services/api_services.dart';
import '../../../hive_utils/hive_boxes.dart';
import '../../../Dashbaord/profile/profile_controller.dart';

class RelationshipGoalController extends GetxController {
  final bool fromEdit;
  RelationshipGoalController({this.fromEdit = false});

  /// Keep the same name to avoid breaking existing UI bindings.
  final TextEditingController controller = TextEditingController();

  final int maxLength = 300;
  final isLoading = false.obs;
  final charCount = 0.obs;

  @override
  void onInit() {
    super.onInit();

    // Prefill from locally cached value and ensure capitalized first letter
    final box = Hive.box(HiveBoxes.userBox);
    final saved = box.get('relationship_goal');
    if (saved is String && saved.trim().isNotEmpty) {
      controller.text = _ensureFirstLetterCapital(saved.trim());
      charCount.value = controller.text.length;
    }

    // Track live length (hard clamp)
    controller.addListener(() {
      charCount.value = controller.text.length;
      if (controller.text.length > maxLength) {
        controller.text = controller.text.substring(0, maxLength);
        controller.selection = TextSelection.fromPosition(
          TextPosition(offset: controller.text.length),
        );
        charCount.value = controller.text.length;
      }
    });
  }

  Future<void> submitRelationshipGoal() async {
    final token = _getToken();
    if (token == null) {
      // Get.snackbar("Error", "Missing token. Please log in again.");
      return;
    }

    String goalText = _ensureFirstLetterCapital(controller.text.trim());

    if (goalText.isEmpty) {
      Get.snackbar("Error", "Please enter your relationship goals.");
      return;
    }
    if (goalText.length > maxLength) {
      goalText = goalText.substring(0, maxLength); // backend/UI cap
      controller.text = goalText; // reflect clamp in UI
      controller.selection = TextSelection.fromPosition(
        TextPosition(offset: controller.text.length),
      );
    }

    // Cache locally (optional)
    final box = Hive.box(HiveBoxes.userBox);
    box.put('relationship_goal', goalText);

    isLoading.value = true;

    try {
      // Same endpoint for setup & edit; backend upserts by user_id
      final response = await ApiService.post(
        'relationship-goals',
        {'relationship_goals': goalText},
        token: token,
      );

      if (response['success'] == true) {
        // Refresh profile so UI reflects the new value
        final profileController =
        _getOrCreate<ProfileController>(() => ProfileController());
        await profileController.fetchProfile();

        isLoading.value = false;

        // ✅ Always go to '/yourhabbit' on success (setup or edit)
        Get.snackbar(
          "Success",
          response['message'] ??
              (fromEdit ? "Relationship goal updated" : "Relationship goal saved"),
        );
        Get.toNamed('/yourhabbit');
      } else {
        isLoading.value = false;
        Get.snackbar("Error", response['message'] ?? "Submission failed");
      }
    } catch (e) {
      isLoading.value = false;
      Get.snackbar("Error", "Something went wrong. Please try again.");
    }
  }

  @override
  void onClose() {
    controller.dispose();
    super.onClose();
  }

  // ----------------- Helpers -----------------

  String? _getToken() {
    final box = Hive.box(HiveBoxes.userBox);
    // Be resilient to different saved keys
    final t = (box.get('auth_token') ?? box.get('token') ?? box.get('access_token'));
    final s = t?.toString();
    return (s == null || s.trim().isEmpty) ? null : s.trim();
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
