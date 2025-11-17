import 'package:get/get.dart';
import 'package:hive/hive.dart';

import '../../../../../hive_utils/hive_boxes.dart';
import '../../../../profile/profile_controller.dart';
import '../../editprofilecontroller.dart';

/// IMPORTANT: Use the SAME nested navigator id that you use to push this screen:
/// Get.to(() => const EditAttachmentStyleScreen(), id: settingsNavId);
const int settingsNavId = 1; // If defined elsewhere globally, remove this and import the shared const.

class EditAttachmentStyleController extends GetxController {
  /// UI options (order MUST match _answerIds for stable mapping)
  final List<String> options = const [
    'Secure',
    'Anxious',
    'Avoidant',
    'Disorganized',
  ];

  /// Backend contract per JSON:
  /// question_id = 17; answer ids = [57,58,59,60] in SAME order as [options]
  static const int attachmentStyleQuestionId = 17;
  static const List<int> _answerIds = [57, 58, 59, 60];

  final selectedOption = ''.obs;
  final isLoading = false.obs;

  EditProfileController get editProfileController => Get.find<EditProfileController>();

  ProfileController get profileController =>
      Get.isRegistered<ProfileController>() ? Get.find<ProfileController>() : Get.put(ProfileController());

  @override
  void onInit() {
    super.onInit();

    // Preselect from EditProfileController value (already hydrated from /profile)
    final current = (editProfileController.attachmentStyle.value).trim();
    if (current.isNotEmpty) {
      final idx = options.indexWhere((opt) => opt.toLowerCase().trim() == current.toLowerCase());
      selectedOption.value = idx >= 0 ? options[idx] : '';
    } else {
      selectedOption.value = '';
    }
  }

  void selectOption(String? value) {
    if (value != null) selectedOption.value = value;
  }

  /// Map current selection -> backend answer_id (57..60)
  int? _selectedAnswerId() {
    final idx = options.indexOf(selectedOption.value.trim());
    if (idx < 0 || idx >= _answerIds.length) return null;
    return _answerIds[idx];
  }

  Future<void> submit() async {
    if (isLoading.value) return;

    final answerId = _selectedAnswerId();
    if (answerId == null) {
      Get.snackbar("Error", "Please select an attachment style.");
      return;
    }

    // Token sanity (kept here only to ensure user is logged in)
    final box = Hive.box(HiveBoxes.userBox);
    final token = box.get('token') ?? box.get('auth_token');
    if (token == null || (token is String && token.isEmpty)) {
      Get.snackbar("Error", "Missing authentication token.");
      return;
    }

    isLoading.value = true;
    try {
      // ✅ Use the SAME abstraction as your other edit screens
      await editProfileController.updateProfile([
        {"question_id": attachmentStyleQuestionId, "answer_id": answerId}
      ]);

      // Update local reactive state immediately
      final picked = selectedOption.value.trim();
      editProfileController.attachmentStyle.value = picked;

      // Refresh profile from server (safety)
      await profileController.fetchProfile();

      Get.snackbar("Success", "Attachment style updated.");

      // Pop the nested navigator and signal success
      Get.back(id: settingsNavId, result: true);
    } catch (e) {
      Get.snackbar("Error", "Something went wrong. Please try again.");
    } finally {
      isLoading.value = false;
    }
  }
}
