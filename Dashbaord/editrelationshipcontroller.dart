import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hive/hive.dart';

import '../../../../../hive_utils/hive_boxes.dart';
import '../../../../profile/profile_controller.dart';
import '../../editprofilecontroller.dart';

/// IMPORTANT: Use the SAME nested navigator id that you used to push this screen:
/// await Get.to(() => const EditRelationshipGoalScreen(), id: settingsNavId);
const int settingsNavId = 1; // If you already define this globally, remove this line and import it.

class EditRelationshipGoalController extends GetxController {
  final TextEditingController textController = TextEditingController();

  /// Backend contract: Relationship Goals is question_id = 11
  static const int relationshipGoalsQuestionId = 11;

  final int maxLength = 300;
  final isLoading = false.obs;

  EditProfileController get editController => Get.find<EditProfileController>();

  ProfileController get profileController =>
      Get.isRegistered<ProfileController>()
          ? Get.find<ProfileController>()
          : Get.put(ProfileController());

  @override
  void onInit() {
    super.onInit();

    // Prefill from EditProfileController; fallback to ProfileController-derived text
    final existing = editController.relationshipGoal.value.trim();
    if (existing.isNotEmpty) {
      textController.text = existing;
    } else {
      textController.text = _deriveFromProfile(profileController);
    }

    // Keep field in sync if EditProfileController updates while this screen is open
    ever<String>(editController.relationshipGoal, (val) {
      if (val.trim().isNotEmpty) {
        textController.text = val.trim();
      }
    });

    // If profileDetails refresh, try to fill text when empty
    ever(profileController.profileDetails, (_) {
      if (textController.text.trim().isEmpty) {
        final fromProfile = _deriveFromProfile(profileController);
        if (fromProfile.isNotEmpty) textController.text = fromProfile;
      }
    });
  }

  String _deriveFromProfile(ProfileController profile) {
    try {
      final map = profile.profileDetails.firstWhere(
            (e) => e['title'] == 'Relationship Goals',
        orElse: () => {'content': ''},
      );
      return (map['content'] ?? '').toString().trim();
    } catch (_) {
      return '';
    }
  }

  Future<void> submit() async {
    final goal = textController.text.trim();

    if (goal.isEmpty) {
      Get.snackbar("Error", "Please enter your relationship goals.");
      return;
    }
    if (goal.length > maxLength) {
      Get.snackbar("Error", "Please keep it under $maxLength characters.");
      return;
    }

    // Resilient token lookup
    final userBox = Hive.box(HiveBoxes.userBox);
    final token = userBox.get('token') ?? userBox.get('auth_token');
    if (token == null || (token is String && token.isEmpty)) {
      Get.snackbar("Error", "Missing token. Please log in again.");
      return;
    }

    isLoading.value = true;
    try {
      // Backend expects: { "question_id": 11, "answer": "<string>" }
      await editController.updateProfile([
        {"question_id": relationshipGoalsQuestionId, "answer": goal}
      ]);

      // Reflect locally so Edit Profile updates instantly
      editController.relationshipGoal.value = goal;

      // Refresh Profile screen data from server
      await profileController.fetchProfile();

      Get.snackbar("Success", "Relationship goal updated");

      // ✅ Pop the NESTED navigator and return a bool so caller refreshes
      Get.back(id: settingsNavId, result: true);
    } catch (e) {
      Get.snackbar("Error", "Update failed. Please try again.");
    } finally {
      isLoading.value = false;
    }
  }

  @override
  void onClose() {
    textController.dispose();
    super.onClose();
  }
}
