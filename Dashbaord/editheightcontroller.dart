import 'package:flutter/cupertino.dart';
import 'package:get/get.dart';
import '../../../../profile/profile_controller.dart';
import '../../editprofilecontroller.dart';

class EditHeightController extends GetxController {
  // Default ~5'0"
  final heightInInches = 60.0.obs;
  final isLoading = false.obs;

  String get heightInFeetAndInches {
    final feet = (heightInInches.value ~/ 12);
    final inches = (heightInInches.value % 12).toInt();
    return "$feet' $inches\"";
  }

  @override
  void onInit() {
    super.onInit();
    _loadLatestHeight();
  }

  Future<void> _loadLatestHeight() async {
    final editController = Get.find<EditProfileController>();

    // ✅ Use cached value first
    if (editController.height.value.isNotEmpty) {
      _parseAndSetHeight(editController.height.value);
    }

    // 🔄 Refresh in background
    try {
      await editController.fetchProfile();
      if (editController.height.value.isNotEmpty) {
        _parseAndSetHeight(editController.height.value);
      }
    } catch (_) {
      // ignore silently
    }
  }

  // ---------- ONLY THIS PART CHANGED (normalize + clamp) ----------
  void _parseAndSetHeight(String raw) {
    final s = raw.trim().toLowerCase();

    // Case A: explicit centimeters like "152" / "182 cm"
    if (s.endsWith('cm')) {
      final n = double.tryParse(s.replaceAll('cm', '').trim());
      _setSafe((n ?? 152) / 2.54);
      return;
    }

    // Case B: feet.inches (e.g., 6.10 meaning 6'10")
    final m = RegExp(r'^(\d+)\.(\d{1,2})$').firstMatch(s);
    if (m != null) {
      final feet = int.tryParse(m.group(1)!);
      final inchPart = int.tryParse(m.group(2)!);
      if (feet != null && inchPart != null) {
        _setSafe((feet * 12 + inchPart).toDouble());
        return;
      }
    }

    // Case C: numeric string (feet / inches / centimeters)
    final n = double.tryParse(s);
    if (n != null) {
      if (n >= 100) {                 // very likely centimeters
        _setSafe((n / 2.54).roundToDouble());
        return;
      }
      if (n >= 36 && n <= 96) {       // looks like inches
        _setSafe(n);
        return;
      }
      // otherwise treat as decimal feet ("5.7" etc.)
      _setSafe((n * 12).roundToDouble());
      return;
    }

    // Fallback
    _setSafe(60.0);
  }

  // always keep slider value within 36–84 inches
  void _setSafe(double value) {
    heightInInches.value = value.clamp(36.0, 84.0);
  }
  // ---------- END CHANGE ----------

  void updateHeight(double value) {
    _setSafe(value); // clamp user drag too
  }

  Future<void> saveHeight() async {
    isLoading.value = true;

    // Format as feet.inches with two-digit inches
    final total = heightInInches.value.round();
    final feet = total ~/ 12;
    final inches = total % 12;
    final heightStr = "$feet.${inches.toString().padLeft(2, '0')}"; // e.g., 6.09, 6.10

    try {
      final editController = Get.find<EditProfileController>();

      await editController.updateProfile([
        {"question_id": 1, "answer": heightStr}
      ]);

      // ✅ Update cache
      editController.height.value = heightStr;

      // ✅ Refresh profile screen
      final profileController = Get.isRegistered<ProfileController>()
          ? Get.find<ProfileController>()
          : Get.put(ProfileController());
      await profileController.fetchProfile();

      Get.snackbar("Success", "Height updated successfully.");
      Get.back(result: true);
    } catch (e) {
      Get.snackbar("Error", "Update failed. Please try again.");
    } finally {
      isLoading.value = false;
    }
  }
}
