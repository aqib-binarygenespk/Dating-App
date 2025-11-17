import 'package:flutter/widgets.dart'; // Navigator
import 'package:get/get.dart';
import 'package:hive/hive.dart';
import 'package:collection/collection.dart';

import '../../../../../hive_utils/hive_boxes.dart';
import '../../../../../services/api_services.dart';
import '../../../../profile/profile_controller.dart';
import '../../editprofilecontroller.dart';
import '../../profilesettings.dart'; // optional hard fallback nav

class EditRelocateLoveController extends GetxController {
  /// Backend contract (per JSON)
  /// question_id = 18
  /// answers:
  ///   61 -> "Yes, I'm Open to Relocating"
  ///   62 -> "Maybe, Under the Right Circumstances"
  ///   63 -> "No, I'd Prefer to Stay Put"
  static const int relocateQuestionId = 18;

  static const Map<int, String> _idToLabel = {
    61: "Yes, I'm Open to Relocating",
    62: "Maybe, Under the Right Circumstances",
    63: "No, I'd Prefer to Stay Put",
  };

  static const Map<String, int> _labelToId = {
    "Yes, I'm Open to Relocating": 61,
    "Maybe, Under the Right Circumstances": 62,
    "No, I'd Prefer to Stay Put": 63,
  };

  /// Expose labels for UI (your screen uses this)
  final List<String> options = const [
    "Yes, I'm Open to Relocating",
    "Maybe, Under the Right Circumstances",
    "No, I'd Prefer to Stay Put",
  ];

  /// Your UI binds to this string directly (do not change UI)
  final selected = ''.obs;
  final isLoading = false.obs;

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
    _hydrateFromExisting();
  }

  /// Prefill from EditProfileController and/or ProfileController
  void _hydrateFromExisting() {
    // 1) Prefer value from edit controller, if present
    final fromEdit = _edit.relocateForLove.value.trim();
    if (fromEdit.isNotEmpty && options.contains(fromEdit)) {
      selected.value = fromEdit;
      return;
    }

    // 2) Try profile details (title/content pairs)
    final details = _profile.profileDetails;
    final content = details.firstWhereOrNull((e) {
      final t = (e['title'] ?? '').toString().trim().toLowerCase();
      return t == 'relocate for love' || t == 'relocation' || t == 'relocation preference';
    })?['content']?.toString().trim();

    if (content != null && options.contains(content)) {
      selected.value = content;
      return;
    }

    // 3) Default: first option
    if (selected.value.isEmpty && options.isNotEmpty) {
      selected.value = options.first;
    }
  }

  /// Called by your UI
  void selectOption(String value) {
    if (options.contains(value)) {
      selected.value = value;
    }
  }

  String get selectedLabel => selected.value;

  Future<void> submit() async {
    if (isLoading.value) return;

    // Token (support both keys)
    final box = Hive.box(HiveBoxes.userBox);
    final token = box.get('token') ?? box.get('auth_token');
    if (token == null || (token is String && token.isEmpty)) {
      Get.snackbar("Error", "Missing authentication token.");
      return;
    }

    final label = selected.value.trim();
    final answerId = _labelToId[label];
    if (answerId == null) {
      Get.snackbar("Error", "Invalid selection.");
      return;
    }

    isLoading.value = true;
    try {
      final payload = {
        "answers": [
          {"question_id": relocateQuestionId, "answer_id": answerId}
        ]
      };

      final res = await ApiService.put(
        'update-profile',
        payload,
        token: token,
        isJson: true,
      );

      if (res == null) {
        Get.snackbar("Error", "No response from server.");
        return;
      }
      final ok = (res['success'] == true) && ((res['code'] ?? 200) < 400);
      if (!ok) {
        Get.snackbar("Error", (res['message'] ?? 'Update failed.').toString());
        return;
      }

      // Reflect immediately into edit controller
      _edit.relocateForLove.value = label;

      // Refresh global profile
      await _profile.fetchProfile();

      Get.snackbar("Success", "Relocation preference updated.");
      _navigateBackSuccess();
    } catch (e) {
      Get.snackbar("Error", "Something went wrong.");
      // ignore: avoid_print
      print("❌ EditRelocateLoveController error: $e");
    } finally {
      isLoading.value = false;
    }
  }

  void _navigateBackSuccess() {
    final payload = {"updated": true, "section": "relocate_for_love"};
    final ctx = Get.context;

    if (ctx != null) {
      final nested = Navigator.maybeOf(ctx);
      if (nested != null && nested.canPop()) {
        nested.pop(payload);
        return;
      }
      final rootNav = Navigator.of(ctx, rootNavigator: true);
      if (rootNav.canPop()) {
        rootNav.pop(payload);
        return;
      }
    }
    // Fallback
    Get.back(result: payload);
    // Or hard fallback if needed:
    // Get.offAll(() => const EditProfileScreen(), arguments: payload);
  }
}
