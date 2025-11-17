import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hive/hive.dart';

import '../../../../../hive_utils/hive_boxes.dart';
import '../../../../../services/api_services.dart';
import '../../../../profile/profile_controller.dart';
import '../../editprofilecontroller.dart';

class EditPetsController extends GetxController {
  /// Backend IDs from your JSON
  static const int kPetsQuestionId = 12;
  static const Map<String, int> kLabelToAnswerId = {
    "No Pets": 1,
    "Dog Lover": 2,
    "Cat Enthusiast": 3,
    "Both Cats and Dogs": 4,
    "Small Pet Parent (Rabbits, Hamsters, etc.)": 5,
    "Exotic Animals (Birds, Reptiles, etc.)": 6,
    "Open to Pets": 7,
    "Allergic, but Love Animals": 8,
  };

  // UI
  final List<String> options = kLabelToAnswerId.keys.toList();
  final selectedOption = ''.obs;
  final isLoading = false.obs;

  // Auth
  String? _jwt; // raw token (no "Bearer ")
  String _tokenType = 'Bearer';

  // Shared controllers
  late final EditProfileController _edit;
  late final ProfileController _profile;

  @override
  void onInit() {
    super.onInit();

    _edit = Get.isRegistered<EditProfileController>()
        ? Get.find<EditProfileController>()
        : Get.put(EditProfileController());

    _profile = Get.isRegistered<ProfileController>()
        ? Get.find<ProfileController>()
        : Get.put(ProfileController());

    _bootstrapAuth();

    // Prefill from existing profile value (a single label)
    final savedLabel = _edit.pets.value.trim();
    if (options.contains(savedLabel)) {
      selectedOption.value = savedLabel;
    } else {
      selectedOption.value = options.first; // default to "No Pets"
    }
  }

  // ---------------- AUTH ----------------

  void _bootstrapAuth() {
    final args = Get.arguments ?? {};
    final fromArgs = _extractTokenFromArgs(args);

    final box = Hive.box(HiveBoxes.userBox);
    final fromHive =
        _normalizeToken(box.get('token')) ?? _normalizeToken(box.get('auth_token'));

    final chosen = fromArgs ?? fromHive;
    if (chosen != null) {
      _jwt = chosen.$1;
      _tokenType = chosen.$2;
      // persist for downstream screens
      box.put('token', _jwt);
      box.put('token_type', _tokenType);
      Get.log('[Pets] token resolved.');
    } else {
      Get.log('[Pets] token missing (args & hive).');
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

  // --------------- UI ---------------

  void selectOption(String label) => selectedOption.value = label;

  // --------------- SUBMIT ---------------

  Future<void> submit() async {
    // Ensure token (late resolve from Hive if needed)
    if (_jwt == null || _jwt!.isEmpty) {
      final box = Hive.box(HiveBoxes.userBox);
      final late =
          _normalizeToken(box.get('token')) ?? _normalizeToken(box.get('auth_token'));
      if (late != null) {
        _jwt = late.$1;
        _tokenType = late.$2;
        box.put('token', _jwt);
      }
    }
    if (_jwt == null || _jwt!.isEmpty) {
      _snack("Error", "Missing authentication.", Colors.redAccent);
      return;
    }

    final label = selectedOption.value;
    final answerId = kLabelToAnswerId[label];
    if (answerId == null) {
      _snack("Error", "Invalid selection.", Colors.redAccent);
      return;
    }

    final payload = {
      "answers": [
        {
          "question_id": kPetsQuestionId, // 12
          "answer_id": answerId,          // scalar (max_selections = 1)
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
      _edit.pets.value = label;

      // Refresh Profile from server
      await _profile.fetchProfile();

      _snack("Success", "Pets updated.", Colors.green);
      _navigateBackSuccess();
    } catch (e) {
      _snack("Error", "Update failed. Please try again.", Colors.redAccent);
    } finally {
      isLoading.value = false;
    }
  }

  // --------------- NAV & ERRORS ---------------

  void _navigateBackSuccess() {
    final ctx = Get.context;
    if (ctx != null) {
      final nested = Navigator.maybeOf(ctx);
      if (nested != null && nested.canPop()) {
        nested.pop({"updated": true, "section": "pets"});
        return;
      }
      final rootNav = Navigator.of(ctx, rootNavigator: true);
      if (rootNav.canPop()) {
        rootNav.pop({"updated": true, "section": "pets"});
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
