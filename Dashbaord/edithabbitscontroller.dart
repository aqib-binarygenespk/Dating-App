import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart'; // Navigator
import 'package:get/get.dart';
import 'package:hive/hive.dart';
import 'package:collection/collection.dart';

import '../../../../../hive_utils/hive_boxes.dart';
import '../../../../../services/api_services.dart';
import '../../../../profile/profile_controller.dart';
import '../../editprofilecontroller.dart';

class EditHabitsController extends GetxController {
  // Backend question IDs
  static const int smokingQ = 13;
  static const int drinkingQ = 14;
  static const int dietQ = 15;

  // State = backend answer IDs
  final smokingHabitId = 9.obs;       // Non-smoker
  final drinkingHabitId = 12.obs;     // Non-drinker
  final dietaryPreferenceId = 15.obs; // Omnivore

  final isLoading = false.obs;

  static const Map<int, String> _smokingLabels = {
    9: 'Non-smoker',
    10: 'Occasional Smoker',
    11: 'Regular Smoker',
  };
  static const Map<int, String> _drinkingLabels = {
    12: 'Non-Drinker',
    13: 'Social Drinker',
    14: 'Regular Drinker',
  };
  static const Map<int, String> _dietLabels = {
    15: 'Omnivore',
    16: 'Vegetarian',
    17: 'Vegan',
    18: 'Gluten-Free',
    19: 'Pescatarian',
    20: 'Other (with an option to specify)',
  };

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
    _hydrateFromProfile();
  }

  void _hydrateFromProfile() {
    final details = _profile.profileDetails;

    smokingHabitId.value = _idFromLabel(
      details.firstWhereOrNull((e) => e['title'] == 'Smoking Habits')?['content'],
      _smokingLabels,
      defaultId: smokingHabitId.value,
    );
    drinkingHabitId.value = _idFromLabel(
      details.firstWhereOrNull((e) => e['title'] == 'Drinking Habits')?['content'],
      _drinkingLabels,
      defaultId: drinkingHabitId.value,
    );
    dietaryPreferenceId.value = _idFromLabel(
      details.firstWhereOrNull((e) => e['title'] == 'Dietary Preferences')?['content'],
      _dietLabels,
      defaultId: dietaryPreferenceId.value,
    );
  }

  int _idFromLabel(String? label, Map<int, String> dict, {required int defaultId}) {
    if (label == null || label.isEmpty) return defaultId;
    final match = dict.entries.firstWhereOrNull(
          (e) => e.value.toLowerCase().trim() == label.toLowerCase().trim(),
    );
    return match?.key ?? defaultId;
  }

  // Update setters
  void updateSmoking(int backendId) {
    if (_smokingLabels.containsKey(backendId)) smokingHabitId.value = backendId;
  }

  void updateDrinking(int backendId) {
    if (_drinkingLabels.containsKey(backendId)) drinkingHabitId.value = backendId;
  }

  void updateDiet(int backendId) {
    if (_dietLabels.containsKey(backendId)) dietaryPreferenceId.value = backendId;
  }

  // Submit to backend
  Future<void> submit() async {
    if (isLoading.value) return;

    final box = Hive.box(HiveBoxes.userBox);
    final token = box.get('token') ?? box.get('auth_token');
    if (token == null || (token is String && token.isEmpty)) {
      Get.snackbar("Error", "Missing authentication token.");
      return;
    }

    isLoading.value = true;
    try {
      final payload = {
        "answers": [
          {"question_id": smokingQ, "answer_id": smokingHabitId.value},
          {"question_id": drinkingQ, "answer_id": drinkingHabitId.value},
          {"question_id": dietQ, "answer_id": dietaryPreferenceId.value},
        ]
      };

      final res = await ApiService.put(
        'update-profile',
        payload,
        token: token,
        isJson: true,
      );

      final ok = res != null && (res['success'] == true) && ((res['code'] ?? 200) < 400);
      if (!ok) {
        Get.snackbar("Error", (res?['message'] ?? 'Update failed.').toString());
        return;
      }

      await _profile.fetchProfile();
      Get.snackbar("Success", "Habits updated.");
      _navigateBackSuccess();
    } catch (e) {
      if (kDebugMode) print('❌ Habits update error: $e');
      Get.snackbar("Error", "Failed to update habits. Try again.");
    } finally {
      isLoading.value = false;
    }
  }

  void _navigateBackSuccess() {
    final payload = {"updated": true, "section": "habits"};
    final ctx = Get.context;

    if (ctx != null) {
      final nested = Navigator.maybeOf(ctx);
      if (nested != null && nested.canPop()) {
        nested.pop(payload);
        return;
      }
      final root = Navigator.of(ctx, rootNavigator: true);
      if (root.canPop()) {
        root.pop(payload);
        return;
      }
    }
    Get.back(result: payload);
  }

  // Helpers for UI
  static const List<int> smokingUiToBackend = [9, 10, 11];
  static const List<int> drinkingUiToBackend = [12, 13, 14];
  static const List<int> dietUiToBackend = [15, 16, 17, 18, 19, 20];

  int backendToUiSmoking(int backendId) => smokingUiToBackend.indexOf(backendId) + 1;
  int backendToUiDrinking(int backendId) => drinkingUiToBackend.indexOf(backendId) + 1;
  int backendToUiDiet(int backendId) => dietUiToBackend.indexOf(backendId) + 1;

  int uiToBackendSmoking(int uiId) => smokingUiToBackend[uiId - 1];
  int uiToBackendDrinking(int uiId) => drinkingUiToBackend[uiId - 1];
  int uiToBackendDiet(int uiId) => dietUiToBackend[uiId - 1];
}
