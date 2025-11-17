import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:hive/hive.dart';

import '../../../../../hive_utils/hive_boxes.dart';
import '../../../../../services/api_services.dart';
import '../../../../profile/profile_controller.dart';
import '../../editprofilecontroller.dart';

/// Backend contract for "Interested in"
/// - question_id = 2
/// - answers: 72 => Male, 73 => Female
class EditInterestedInController extends GetxController {
  static const int _questionId = 2;

  final List<String> options = const ['Male', 'Female'];

  final RxString selected = ''.obs;
  final RxBool isLoading = false.obs;

  static const Map<String, int> _labelToId = {
    'Male': 72,
    'Female': 73,
  };

  static const Map<int, String> _idToLabel = {
    72: 'Male',
    73: 'Female',
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
    _hydrateSelection();
  }

  Future<void> _hydrateSelection() async {
    // 1) Nav args
    final int? argAnswerId = Get.arguments?['answer_id'] as int?;
    if (argAnswerId != null && _idToLabel.containsKey(argAnswerId)) {
      selected.value = _idToLabel[argAnswerId]!;
      return;
    }

    // 2) From EditProfileController string
    final raw = _edit.interestedIn.value.trim();
    if (raw.isNotEmpty) {
      final normalized = raw.toLowerCase();
      if (normalized == 'male') {
        selected.value = 'Male';
        return;
      }
      if (normalized == 'female') {
        selected.value = 'Female';
        return;
      }
    }

    // 3) Default
    selected.value = options.first;
  }

  void selectOption(String value) {
    if (options.contains(value)) {
      selected.value = value;
    }
  }

  /// Submit update to backend
  Future<bool> submit() async {
    if (isLoading.value) return false;

    final label = selected.value;
    final answerId = _labelToId[label];
    if (answerId == null) {
      Get.snackbar('Invalid', 'Please choose a valid option.');
      return false;
    }

    final box = Hive.box(HiveBoxes.userBox);
    final token = box.get('token') ?? box.get('auth_token');
    if (token == null || (token is String && token.trim().isEmpty)) {
      Get.snackbar('Error', 'Missing authentication token.');
      return false;
    }

    isLoading.value = true;
    try {
      final payload = {
        'answers': [
          {'question_id': _questionId, 'answer_id': answerId}
        ]
      };

      final res = await ApiService.put(
        'update-profile',
        payload,
        token: token,
        isJson: true,
      );

      if (res == null) {
        Get.snackbar('Error', 'No response from server.');
        return false;
      }
      final ok = (res['success'] == true) && ((res['code'] ?? 200) < 400);
      if (!ok) {
        Get.snackbar('Error', (res['message'] ?? 'Update failed').toString());
        return false;
      }

      _edit.interestedIn.value = label;
      await _profile.fetchProfile();

      Get.snackbar('Success', 'Updated successfully.');
      return true;
    } catch (e) {
      debugPrint('❌ EditInterestedInController submit error: $e');
      Get.snackbar('Error', 'Update failed. Please try again.');
      return false;
    } finally {
      isLoading.value = false;
    }
  }
}
