import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:hive/hive.dart';

import '../../../../../hive_utils/hive_boxes.dart';
import '../../../../profile/profile_controller.dart';
import '../../editprofilecontroller.dart';
// If you have this cache service, uncomment both usage points below.
// import '../../../../../services/profileasnwerservices.dart';

/// Backend contract:
/// - QID = 6  ("Choose a prompt to answer in your video.")
/// - answer_ids = 64..71 (order-aligned with UI prompts)
class EditGetToKnowMeController extends GetxController {
  static const int promptQuestionId = 6;
  static const List<int> _defaultPromptAnswerIds = [64, 65, 66, 67, 68, 69, 70, 71];

  /// Reactive mapping (so you can swap from a runtime catalog if needed)
  final RxList<int> promptAnswerIds = RxList<int>(_defaultPromptAnswerIds);

  final RxInt selectedIndex = (-1).obs; // 0..7
  final RxBool isLoading = false.obs;
  final RxString responseMessage = ''.obs;
  final RxBool isSuccess = false.obs;

  /// UI text (MUST stay index-aligned with answer IDs)
  final List<String> prompts = const [
    "Why do you think meeting in a group is better than a one-on-one first hangout?",
    "What’s your favorite way to spend a weekend with friends?",
    "How do you make new people feel welcome when hanging out in a group?",
    "What’s a shared activity you think is perfect for a first meetup?",
    "Describe your ideal group outing or hangout.",
    "What’s your go-to game or activity for breaking the ice with new friends?",
    "If you could plan the ultimate friend + date night, what would it look like?",
    "What’s a fun fact about you that people might not guess?",
  ];

  EditProfileController get _edit =>
      Get.isRegistered<EditProfileController>()
          ? Get.find<EditProfileController>()
          : Get.put(EditProfileController());

  ProfileController get _profile =>
      Get.isRegistered<ProfileController>()
          ? Get.find<ProfileController>()
          : Get.put(ProfileController());

  @override
  void onInit() {
    super.onInit();
    _hydrateSelection();
  }

  /// Optional: replace IDs at runtime from your questions catalog
  void loadPromptIdsFromCatalog(List<dynamic> questions) {
    try {
      final q6 = questions.cast<Map<String, dynamic>>().firstWhere(
            (q) => (q['id'] == 6 || q['id'] == promptQuestionId),
        orElse: () => {},
      );
      if (q6.isEmpty || q6['answers'] == null) return;

      final answers = (q6['answers'] as List).cast<Map<String, dynamic>>();
      answers.sort((a, b) => (a['display_order'] as int).compareTo(b['display_order'] as int));

      final ids = answers.map<int>((e) => (e['id'] as num).toInt()).toList();
      if (ids.length == 8) {
        promptAnswerIds.assignAll(ids);
        _reloadSelectionAgainstNewIds();
      }
    } catch (_) {/* keep defaults */}
  }

  void selectPrompt(int? index) {
    if (index != null && index >= 0 && index < prompts.length) {
      selectedIndex.value = index;
    }
  }

  /// Robust hydration path:
  /// 1) Nav args: {'answer_id': 64..71}
  /// 2) (Optional) ProfileAnswersService cache
  /// 3) EditProfileController.getToKnowMePrompt (string) → try as answer_id then legacy index(1..8)
  /// 4) Cold start (e.g. just after login): fetchProfile() and retry a few times
  Future<void> _hydrateSelection() async {
    // 1) Navigation args
    final int? argAnswerId = Get.arguments?['answer_id'] as int?;
    if (argAnswerId != null) {
      final idx = promptAnswerIds.indexOf(argAnswerId);
      if (idx >= 0) {
        selectedIndex.value = idx;
        return;
      }
    }

    // 2) Optional cache fast path
    // try {
    //   final savedId = await ProfileAnswersService.getAnswerId(promptQuestionId);
    //   if (savedId != null) {
    //     final idx = promptAnswerIds.indexOf(savedId);
    //     if (idx >= 0) {
    //       selectedIndex.value = idx;
    //       return;
    //     }
    //   }
    // } catch (_) {}

    // 3) From EditProfileController
    if (_trySelectFromEditController()) return;

    // 4) Cold start → nudge profile and retry quickly
    const attempts = 4;
    for (int i = 0; i < attempts && selectedIndex.value < 0; i++) {
      await _profile.fetchProfile();
      await Future.delayed(const Duration(milliseconds: 250));
      if (_trySelectFromEditController()) break;

      // Optional cache retry
      // try {
      //   final savedId = await ProfileAnswersService.getAnswerId(promptQuestionId);
      //   if (savedId != null) {
      //     final idx = promptAnswerIds.indexOf(savedId);
      //     if (idx >= 0) {
      //       selectedIndex.value = idx;
      //       break;
      //     }
      //   }
      // } catch (_) {}
    }
  }

  bool _trySelectFromEditController() {
    final stored = _edit.getToKnowMePrompt.value.trim();
    if (stored.isEmpty) return false;

    final parsed = int.tryParse(stored);
    if (parsed == null) return false;

    // Case A: stored was real answer_id (64..71)
    final idxByAnswerId = promptAnswerIds.indexOf(parsed);
    if (idxByAnswerId != -1) {
      selectedIndex.value = idxByAnswerId;
      return true;
    }

    // Case B: stored was legacy index (1..8)
    if (parsed >= 1 && parsed <= 8) {
      selectedIndex.value = parsed - 1; // 0..7
      return true;
    }
    return false;
  }

  void _reloadSelectionAgainstNewIds() {
    final stored = _edit.getToKnowMePrompt.value.trim();
    final parsed = int.tryParse(stored);
    if (parsed == null) return;

    final idx = promptAnswerIds.indexOf(parsed);
    if (idx != -1) selectedIndex.value = idx;
  }

  /// Submit the new prompt. Returns true on success.
  Future<bool> submitPrompt() async {
    if (selectedIndex.value < 0 || selectedIndex.value >= prompts.length) {
      responseMessage.value = "Please select a prompt.";
      isSuccess.value = false;
      return false;
    }

    final box = Hive.box(HiveBoxes.userBox);
    final token = box.get('token') ?? box.get('auth_token');
    if (token == null || (token is String && token.isEmpty)) {
      responseMessage.value = "Missing token. Please log in again.";
      isSuccess.value = false;
      return false;
    }

    isLoading.value = true;
    final answerId = promptAnswerIds[selectedIndex.value];

    try {
      // Use your existing EditProfileController update (hits PUT /update-profile)
      await _edit.updateProfile([
        {"question_id": promptQuestionId, "answer_id": answerId}
      ]);

      // Persist the REAL answer_id string so we can always map back reliably
      _edit.getToKnowMePrompt.value = answerId.toString();

      // Refresh profile so the rest of UI reflects latest state
      await _profile.fetchProfile();

      isLoading.value = false;
      isSuccess.value = true;
      if (!Get.isOverlaysOpen) {
        Get.snackbar("Success", "Prompt updated.", snackPosition: SnackPosition.BOTTOM);
      }
      return true;
    } catch (e) {
      isLoading.value = false;
      isSuccess.value = false;
      responseMessage.value = "Failed to update.";
      if (!Get.isOverlaysOpen) {
        Get.snackbar("Error", "Update failed. Please try again.", snackPosition: SnackPosition.BOTTOM);
      }
      if (kDebugMode) {
        print('❌ submitPrompt error: $e');
      }
      return false;
    }
  }
}
