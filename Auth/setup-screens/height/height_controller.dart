import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import 'package:get/get.dart';
import 'package:hive/hive.dart';

import '../../../Dashbaord/settingspages/profilesettings/editprofilecontroller.dart';
import '../../../services/api_services.dart';
import '../../../hive_utils/hive_boxes.dart';
import '../../../Dashbaord/profile/profile_controller.dart';

class HeightSelectionController extends GetxController {
  final bool fromEdit;

  HeightSelectionController({this.fromEdit = false});

  // State
  final heightInInches = 60.0.obs; // default 5'0"
  final isLoading = false.obs;

  // Resolved from assets/categories.json
  final _heightQuestionId = RxnInt();

  String get heightInFeetAndInches {
    final int feet = (heightInInches.value ~/ 12).toInt();
    final int inches = (heightInInches.value % 12).toInt();
    return "$feet' $inches\"";
  }

  @override
  void onInit() {
    super.onInit();
    _loadHeightQuestionIdFromAssets();

    // Preload existing value (edit vs setup)
    if (fromEdit) {
      final editController = Get.find<EditProfileController>();
      if (editController.height.value.isNotEmpty) {
        heightInInches.value = _parseHeightToInchesSafe(editController.height.value);
      }
      // optional refresh without changing flow
      editController.fetchProfile().then((_) {
        if (editController.height.value.isNotEmpty) {
          heightInInches.value = _parseHeightToInchesSafe(editController.height.value);
        }
      }).ignore();
    } else {
      final box = Hive.box(HiveBoxes.userBox);
      final heightValue = box.get('height')?.toString() ?? '';
      if (heightValue.isNotEmpty) {
        heightInInches.value = _parseHeightToInchesSafe(heightValue);
      }
    }
  }

  /// Normalize any stored format into slider-safe inches (36..84).
  double _parseHeightToInchesSafe(String raw) {
    final s = raw.trim().toLowerCase();

    // "182 cm" / "152" (cm)
    if (s.endsWith('cm')) {
      final n = double.tryParse(s.replaceAll('cm', '').trim());
      return _clamp((n ?? 152) / 2.54);
    }

    // Feet.inches literal like "6.10", "5.09"
    final m = RegExp(r'^(\d+)\.(\d{1,2})$').firstMatch(s);
    if (m != null) {
      final feet = int.tryParse(m.group(1)!);
      final inchPart = int.tryParse(m.group(2)!);
      if (feet != null && inchPart != null) {
        return _clamp((feet * 12 + inchPart).toDouble());
      }
    }

    // Plain numeric: decide unit
    final n = double.tryParse(s);
    if (n != null) {
      if (n >= 100) {
        // likely centimeters
        return _clamp((n / 2.54).roundToDouble());
      }
      if (n >= 36 && n <= 96) {
        // looks like inches
        return _clamp(n);
      }
      // treat as decimal feet (e.g., "5.7")
      return _clamp((n * 12).roundToDouble());
    }

    // Fallback
    return 60.0;
  }

  double _clamp(double v) => v.clamp(36.0, 84.0);

  void updateHeight(double value) {
    heightInInches.value = _clamp(value);
  }

  Future<void> sendHeightToServer() async {
    isLoading.value = true;

    final box = Hive.box(HiveBoxes.userBox);
    final String? token = box.get('token');
    await box.delete('auth_token'); // cleanup legacy key

    if (!fromEdit && token == null) {
      isLoading.value = false;
      Get.snackbar("Error", "Missing authentication.");
      return;
    }

    // Convert slider inches to the SAME string format edit expects: feet.twoDigitInches
    // e.g., 5'9" -> "5.09", 6'0" -> "6.00", 6'10" -> "6.10"
    final totalInches = heightInInches.value.round();
    final feet = totalInches ~/ 12;
    final inches = totalInches % 12;
    final heightStrFeetDotInches = "$feet.${inches.toString().padLeft(2, '0')}";

    if (fromEdit) {
      // Edit flow: use categories.json-derived question_id + answer
      final qid = _heightQuestionId.value;
      if (qid == null) {
        isLoading.value = false;
        Get.snackbar(
          "Error",
          'Could not resolve "height" question from categories.json.',
        );
        return;
      }

      try {
        final controller = Get.find<EditProfileController>();
        await controller.updateProfile([
          {"question_id": qid, "answer": heightStrFeetDotInches}
        ]);

        // Refresh profile and return
        final profileController = Get.isRegistered<ProfileController>()
            ? Get.find<ProfileController>()
            : Get.put(ProfileController());
        await profileController.fetchProfile();

        isLoading.value = false;
        Get.snackbar("Success", "Height updated.");
        Get.back(result: true);
      } catch (e) {
        isLoading.value = false;
        Get.snackbar("Error", "Update failed. Try again.");
      }
    } else {
      // Setup flow: store the SAME format locally and send it to API
      box.put('height', heightStrFeetDotInches);

      try {
        final response = await ApiService.post(
          "height",
          {"height": heightStrFeetDotInches},
          token: token,
          isJson: true,
        );

        isLoading.value = false;

        if (response['success'] == true) {
          Get.snackbar("Success", response['message'] ?? "Height saved.");
          Get.toNamed('/interestedin');
        } else {
          Get.snackbar("Error", response['message'] ?? "Failed to save height.");
        }
      } catch (e) {
        isLoading.value = false;
        Get.snackbar("Error", "Network error. Try again.");
      }
    }
  }

  /// Parse assets/categories.json, find the "height" category's first question id.
  Future<void> _loadHeightQuestionIdFromAssets() async {
    try {
      final jsonStr = await rootBundle.loadString('assets/categories.json');
      final data = json.decode(jsonStr);

      // Expecting a top-level list OR an object with "categories" -> list
      final List categories = data is List
          ? data
          : (data is Map && data['categories'] is List ? data['categories'] : <dynamic>[]);

      int? foundId;

      for (final cat in categories) {
        final title = (cat['title'] ?? '').toString();
        if (title.toLowerCase().trim() == 'height') {
          final questions = (cat['questions'] is List) ? cat['questions'] as List : const [];
          if (questions.isNotEmpty) {
            final q = questions.first;
            // Try common keys: 'id' or 'question_id'
            if (q is Map) {
              if (q['id'] is int) {
                foundId = q['id'] as int;
              } else if (q['question_id'] is int) {
                foundId = q['question_id'] as int;
              } else if (q['id'] is String) {
                foundId = int.tryParse(q['id']);
              } else if (q['question_id'] is String) {
                foundId = int.tryParse(q['question_id']);
              }
            }
          }
          break;
        }
      }

      if (foundId == null) {
        Get.log('[HeightSelectionController] No question_id found for "height" in categories.json');
      }
      _heightQuestionId.value = foundId;
    } catch (e) {
      Get.log('[HeightSelectionController] Failed to load categories.json: $e');
    }
  }
}
