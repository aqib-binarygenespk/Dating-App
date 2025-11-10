import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hive/hive.dart';

import '../../../../../hive_utils/hive_boxes.dart';
import '../../../../../services/api_services.dart';
import '../../../../profile/profile_controller.dart';
import '../../editprofilecontroller.dart';

/// Love Languages (from assets JSON you shared)
const int kLoveLanguagesQuestionId = 16;
const Map<String, int> kLoveLanguageLabelToId = {
  'Words of Affirmation': 24,
  'Acts of Service': 25,
  'Receiving Gifts': 26,
  'Quality Time': 27,
  'Physical Touch': 28,
};

class EditLoveLanguagesController extends GetxController {
  // UI state
  final List<String> loveLanguages = kLoveLanguageLabelToId.keys.toList();
  final selectedLanguages = <String>[].obs; // max 2
  final isLoading = false.obs;

  // Auth
  String? _jwt;            // raw token (no "Bearer ")
  String _tokenType = 'Bearer';

  // Shared controllers
  late final EditProfileController editProfileController;
  late final ProfileController profileController;

  @override
  void onInit() {
    super.onInit();

    // Wire controllers
    editProfileController = Get.isRegistered<EditProfileController>()
        ? Get.find<EditProfileController>()
        : Get.put(EditProfileController());

    profileController = Get.isRegistered<ProfileController>()
        ? Get.find<ProfileController>()
        : Get.put(ProfileController());

    // Resolve & persist token
    _bootstrapAuth();

    // Pre-fill from EditProfileController (e.g., "Quality Time, Physical Touch")
    final existing = editProfileController.loveLanguage.value.trim();
    if (existing.isNotEmpty) {
      final values = existing
          .split(',')
          .map((e) => e.trim())
          .where((e) => loveLanguages.contains(e))
          .toList();
      selectedLanguages.assignAll(values.take(2));
    }
  }

  // -------------------- AUTH --------------------

  void _bootstrapAuth() {
    final args = Get.arguments ?? {};
    final fromArgsToken = _extractTokenFromArgs(args);

    final box = Hive.box(HiveBoxes.userBox);
    final fromHiveToken =
        _normalizeToken(box.get('token')) ?? _normalizeToken(box.get('auth_token'));

    final chosen = fromArgsToken ?? fromHiveToken;
    if (chosen != null) {
      _jwt = chosen.$1;
      _tokenType = chosen.$2;
      // Persist so other screens stay in sync
      box.put('token', _jwt);
      box.put('token_type', _tokenType);
      Get.log('[LoveLang] Auth OK. type=$_tokenType, token=${_jwt?.substring(0, (_jwt?.length ?? 0) > 10 ? 10 : (_jwt?.length ?? 0))}...');
    } else {
      Get.log('[LoveLang] Auth missing in args & Hive.');
    }
  }

  (String, String)? _extractTokenFromArgs(Map args) {
    for (final k in ['jwt', 'token', 'auth_token', 'Authorization', 'authorization']) {
      final v = (args[k] as String?)?.trim();
      final norm = _normalizeToken(v);
      if (norm != null) return norm;
    }
    return null;
  }

  /// "Bearer abc" -> ("abc","Bearer"), "abc" -> ("abc","Bearer")
  (String, String)? _normalizeToken(Object? raw) {
    if (raw == null) return null;
    final s = raw.toString().trim();
    if (s.isEmpty) return null;
    if (s.toLowerCase().startsWith('bearer ')) {
      return (s.substring(7).trim(), 'Bearer');
    }
    return (s, 'Bearer');
  }

  // -------------------- UI --------------------

  String get selectedPreview => selectedLanguages.join(', ');
  bool get canSubmit => selectedLanguages.isNotEmpty && selectedLanguages.length <= 2;

  void toggleLanguage(String lang) {
    if (selectedLanguages.contains(lang)) {
      selectedLanguages.remove(lang);
      return;
    }
    if (selectedLanguages.length >= 2) {
      _snack("Limit", "You can select up to 2 love languages.", Colors.orange);
      return;
    }
    selectedLanguages.add(lang);
  }

  void clearSelection() => selectedLanguages.clear();

  // -------------------- SUBMIT --------------------

  Future<void> submit() async {
    if (!canSubmit) {
      _snack("Error", "Please select up to two love languages.", Colors.redAccent);
      return;
    }

    // Ensure token (late resolve from Hive if needed)
    if (_jwt == null || _jwt!.isEmpty) {
      final box = Hive.box(HiveBoxes.userBox);
      final late = _normalizeToken(box.get('token')) ?? _normalizeToken(box.get('auth_token'));
      if (late != null) {
        _jwt = late.$1;
        _tokenType = late.$2;
        box.put('token', _jwt);
      }
    }
    if (_jwt == null || _jwt!.isEmpty) {
      _snack("Error", "Missing authentication.", Colors.redAccent);
      Get.log('[LoveLang] Submit aborted: token missing.');
      return;
    }

    // Map labels -> correct backend IDs (24..28) from your JSON
    final ids = <int>[];
    for (final label in selectedLanguages) {
      final aid = kLoveLanguageLabelToId[label];
      if (aid == null) {
        _snack("Error", 'Unknown option "$label".', Colors.redAccent);
        return;
      }
      ids.add(aid);
    }

    final payload = {
      "answers": [
        {
          "question_id": kLoveLanguagesQuestionId, // 16
          "answer_id": ids,                        // e.g. [27,28]
        }
      ]
    };

    isLoading.value = true;
    try {
      final resp = await ApiService.put(
        "update-profile",
        payload,
        token: _jwt,   // ApiService should add "Authorization: Bearer <jwt>"
        isJson: true,
      );

      final ok = (resp is Map && (resp['success'] == true || resp['status'] == true));
      if (!ok) {
        _showBackendError(resp);
        return;
      }

      // Local immediate reflection
      editProfileController.loveLanguage.value = selectedPreview;

      // Refresh Profile from server so UI reflects DB
      await profileController.fetchProfile();

      _snack("Success", "Love languages updated.", Colors.green);
      _navigateBackSuccess();
    } catch (e) {
      _snack("Error", "Update failed: $e", Colors.redAccent);
    } finally {
      isLoading.value = false;
    }
  }

  // -------------------- NAV & ERRORS --------------------

  void _navigateBackSuccess() {
    final ctx = Get.context;
    if (ctx != null) {
      final nav = Navigator.maybeOf(ctx);
      if (nav != null && nav.canPop()) {
        nav.pop({"updated": true, "section": "love_language"});
        return;
      }
      final root = Navigator.of(ctx, rootNavigator: true);
      if (root.canPop()) {
        root.pop({"updated": true, "section": "love_language"});
        return;
      }
    }
    Get.back(result: true);
  }

  void _showBackendError(dynamic resp) {
    String title = "Failed";
    String message = "Could not update profile.";
    if (resp is Map) {
      final msg = (resp['message'] ?? '').toString();
      if (msg.isNotEmpty) message = msg;
      if (resp['errors'] is Map) {
        title = "Validation failed";
        final errors = resp['errors'] as Map<String, dynamic>;
        final lines = <String>[];
        errors.forEach((k, v) {
          if (v is List) {
            lines.add("$k: ${v.join(', ')}");
          } else {
            lines.add("$k: $v");
          }
        });
        if (lines.isNotEmpty) {
          message = "${message.isNotEmpty ? "$message\n" : ""}${lines.join('\n')}";
        }
      } else if (msg.toLowerCase().contains('unauth') || msg.toLowerCase().contains('token')) {
        title = "Authentication";
      }
    }
    _snack(title, message, Colors.redAccent);
  }

  void _snack(String title, String msg, Color bg) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (Get.isSnackbarOpen == true) Get.closeCurrentSnackbar();
      Get.snackbar(
        title,
        msg,
        backgroundColor: bg,
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
        margin: const EdgeInsets.all(12),
      );
    });
  }
}
