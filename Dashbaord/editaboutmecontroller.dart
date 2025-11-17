import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hive/hive.dart';

import '../../../../../hive_utils/hive_boxes.dart';
import '../../../../profile/profile_controller.dart';
import '../../editprofilecontroller.dart';
// If settingsNavId is exported from Dashboard.dart, import it there and delete the next line.
// import '../../../../dashboard/Dashboard.dart';

/// If you DON'T export settingsNavId elsewhere, keep this value consistent here.
const int settingsNavId = 1;

/// Backend contract: About Me is question_id = 10 (string payload)
class EditAboutMeController extends GetxController {
  final TextEditingController aboutMeController = TextEditingController();

  static const int aboutMeQuestionId = 10;
  final int maxLength = 300;

  final isLoading = false.obs;

  EditProfileController get editController =>
      Get.isRegistered<EditProfileController>()
          ? Get.find<EditProfileController>()
          : Get.put(EditProfileController());

  ProfileController get profileController =>
      Get.isRegistered<ProfileController>()
          ? Get.find<ProfileController>()
          : Get.put(ProfileController());

  @override
  void onInit() {
    super.onInit();
    _hydrate();
  }

  /// Prefill from EditProfileController; if empty (fresh login), fetch profile and retry briefly.
  Future<void> _hydrate() async {
    // 1) Fast path
    final cur = editController.aboutMe.value.trim();
    if (cur.isNotEmpty) {
      aboutMeController.text = cur;
      return;
    }

    // 2) Cold start → nudge profile & retry
    const attempts = 4; // ~1s total
    for (int i = 0; i < attempts; i++) {
      await profileController.fetchProfile();
      await Future.delayed(const Duration(milliseconds: 250));
      final updated = editController.aboutMe.value.trim();
      if (updated.isNotEmpty) {
        aboutMeController.text = updated;
        break;
      }
    }
  }

  Future<bool> submitAboutMe() async {
    if (isLoading.value) return false;

    final bio = aboutMeController.text.trim();
    if (bio.isEmpty) {
      Get.snackbar("Error", "Please enter something about yourself.");
      return false;
    }
    if (bio.length > maxLength) {
      Get.snackbar("Error", "Max length is $maxLength characters.");
      return false;
    }

    // Token check (defensive; editController.updateProfile usually handles auth)
    final userBox = Hive.box(HiveBoxes.userBox);
    final token = userBox.get('token') ?? userBox.get('auth_token');
    if (token == null || (token is String && token.isEmpty)) {
      Get.snackbar("Error", "Missing token. Please log in again.");
      return false;
    }

    isLoading.value = true;
    try {
      // PUT /update-profile with a string answer
      await editController.updateProfile([
        {"question_id": aboutMeQuestionId, "answer": bio}
      ]);

      // Refresh local state & profile
      editController.aboutMe.value = bio;
      await profileController.fetchProfile();

      if (!Get.isOverlaysOpen) {
        Get.snackbar("Success", "About Me updated");
      }
      return true;
    } catch (e) {
      if (kDebugMode) {
        print('❌ EditAboutMe submit error: $e');
      }
      if (!Get.isOverlaysOpen) {
        Get.snackbar("Error", "Update failed. Please try again.");
      }
      return false;
    } finally {
      isLoading.value = false;
    }
  }

  @override
  void onClose() {
    aboutMeController.dispose();
    super.onClose();
  }
}
