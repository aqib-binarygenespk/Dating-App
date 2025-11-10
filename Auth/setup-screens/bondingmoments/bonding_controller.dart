import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import 'package:get/get.dart';
import 'package:hive/hive.dart';

import '../../../Dashbaord/profile/profile_controller.dart';
import '../../../Dashbaord/settingspages/profilesettings/editprofilecontroller.dart';
import '../../../hive_utils/hive_boxes.dart';
import '../../../services/api_services.dart';

class BondingRow {
  final int questionId;
  final Choice left;
  final Choice right;
  BondingRow({required this.questionId, required this.left, required this.right});
}

class Choice {
  final int id;
  final String label;
  const Choice({required this.id, required this.label});
}

class BondingMomentsController extends GetxController {
  BondingMomentsController({this.fromEdit = false});
  final bool fromEdit;

  final rows = <BondingRow>[].obs;
  final isLoading = true.obs;

  /// rowIndex -> side (0=left, 1=right)
  final RxMap<int, int> selectedByRow = <int, int>{}.obs;

  bool get canSubmit => !isLoading.value && selectedByRow.length >= 3;

  bool isSelected(int rowIndex, int side) => selectedByRow[rowIndex] == side;

  void toggleRow(int rowIndex, int side) {
    final existing = selectedByRow[rowIndex];
    if (existing == side) {
      selectedByRow.remove(rowIndex); // unselect
    } else {
      selectedByRow[rowIndex] = side; // select or switch
    }
    selectedByRow.refresh();
  }

  @override
  void onInit() {
    super.onInit();
    selectedByRow.clear();
    _loadFromAssets();
  }

  @override
  void onClose() {
    selectedByRow.clear();
    super.onClose();
  }

  Future<void> _loadFromAssets() async {
    try {
      isLoading.value = true;

      final jsonStr = await rootBundle.loadString('assets/categories.json');
      final dynamic data = json.decode(jsonStr);

      final bonding = _extractBondingCategory(data);
      if (bonding == null) {
        rows.clear();
        return;
      }

      final List qs = (bonding['questions'] as List?) ?? const [];
      final parsed = <BondingRow>[];

      for (final q in qs) {
        if (q is! Map) continue;

        final qid = (q['id'] is int) ? q['id'] as int : int.tryParse('${q['id']}');
        if (qid == null) continue;

        final answers = (q['answers'] as List?) ?? const [];
        if (answers.length < 2) continue;

        // order by display_order
        answers.sort((a, b) {
          final ao = int.tryParse('${(a as Map)['display_order'] ?? 0}') ?? 0;
          final bo = int.tryParse('${(b as Map)['display_order'] ?? 0}') ?? 0;
          return ao.compareTo(bo);
        });

        final a0 = answers[0] as Map;
        final a1 = answers[1] as Map;

        final left = Choice(
          id: (a0['id'] is int) ? a0['id'] as int : int.tryParse('${a0['id']}') ?? -1,
          label: (a0['label'] ?? a0['value'] ?? '').toString(),
        );
        final right = Choice(
          id: (a1['id'] is int) ? a1['id'] as int : int.tryParse('${a1['id']}') ?? -1,
          label: (a1['label'] ?? a1['value'] ?? '').toString(),
        );
        if (left.id < 0 || right.id < 0) continue;

        parsed.add(BondingRow(questionId: qid, left: left, right: right));
      }

      rows.assignAll(parsed);
    } catch (_) {
      rows.clear();
    } finally {
      isLoading.value = false;
    }
  }

  Map<String, dynamic>? _extractBondingCategory(dynamic data) {
    if (data is Map && data['title'] == 'Bonding Moments') {
      return Map<String, dynamic>.from(data);
    }
    if (data is Map && data['categories'] is List) {
      for (final raw in data['categories']) {
        if (raw is! Map) continue;
        final t = (raw['title'] ?? '').toString().toLowerCase().replaceAll(' ', '');
        if (t == 'bondingmoments') return Map<String, dynamic>.from(raw);
      }
    }
    if (data is List) {
      for (final raw in data) {
        if (raw is! Map) continue;
        final t = (raw['title'] ?? '').toString().toLowerCase().replaceAll(' ', '');
        if (t == 'bondingmoments') return Map<String, dynamic>.from(raw);
      }
    }
    return null;
  }

  Future<void> submit() async {
    // Require MIN 3 selections
    if (selectedByRow.length < 3) {
      Get.snackbar('Select at least 3', 'Please choose at least three options to continue.');
      return;
    }

    final answers = <Map<String, dynamic>>[];
    selectedByRow.forEach((rowIndex, side) {
      if (rowIndex >= 0 && rowIndex < rows.length) {
        final r = rows[rowIndex];
        final answerId = side == 0 ? r.left.id : r.right.id;
        answers.add({"question_id": r.questionId, "answer_id": answerId});
      }
    });

    final box = Hive.box(HiveBoxes.userBox);
    final token = (box.get('token') ?? box.get('auth_token') ?? box.get('access_token'))?.toString();
    if (token == null || token.trim().isEmpty) {
      // Not logged in yet? Allow navigation to next step without API, or handle auth flow as needed.
      return;
    }

    try {
      isLoading.value = true;

      if (fromEdit) {
        final edit = _getOrCreate<EditProfileController>(() => EditProfileController());
        await edit.updateProfile(answers);

        final profile = _getOrCreate<ProfileController>(() => ProfileController());
        await profile.fetchProfile();

        isLoading.value = false;
        Get.snackbar('Success', 'Bonding moments updated');
        Get.back(result: true);
      } else {
        final resp = await ApiService.postJson('bonding-moments', {"answers": answers}, token: token);
        isLoading.value = false;

        if (resp['success'] == true) {
          Get.snackbar('Success', resp['message'] ?? 'Saved');
          Get.toNamed('/aboutme');
        } else {
          Get.snackbar('Error', (resp['message'] ?? 'Submission failed').toString());
        }
      }
    } catch (e) {
      isLoading.value = false;
      Get.snackbar('Error', 'Something went wrong.');
    }
  }

  T _getOrCreate<T>(T Function() create) {
    try {
      return Get.find<T>();
    } catch (_) {
      return Get.put<T>(create());
    }
  }
}
