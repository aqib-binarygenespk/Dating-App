import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import 'package:get/get.dart';
import 'package:hive/hive.dart';

import '../../../Dashbaord/dashboard/Dashboard.dart';
import '../../../services/api_services.dart';
import '../../../hive_utils/hive_boxes.dart';
import '../../../Dashbaord/profile/profile_controller.dart';
import '../../../Dashbaord/settingspages/profilesettings/editprofilecontroller.dart';

class RelocateLoveController extends GetxController {
  final bool fromEdit;
  RelocateLoveController({this.fromEdit = false});

  // === UI model (unchanged) ==================================================
  final List<Map<String, String>> options = const [
    {"key": "1", "label": "Yes, I'm Open to Relocating"},
    {"key": "2", "label": "Maybe, Under the Right Circumstances"},
    {"key": "3", "label": "No, I'd Prefer to Stay Put"},
  ];

  // Single selected backend key ("1" | "2" | "3")
  final selectedKey = ''.obs;

  // Back-compat for existing screen (label-driven)
  List<String> get relocateOptions => options.map((e) => e['label']!).toList();
  final selectedRelocateOptions = <String>[].obs;

  void toggleOption(String optionLabel) {
    if (selectedRelocateOptions.contains(optionLabel)) {
      selectedRelocateOptions.clear();
      selectedKey.value = '';
    } else {
      selectedRelocateOptions.value = [optionLabel];
      final key = options.firstWhere((e) => e['label'] == optionLabel)['key']!;
      selectedKey.value = key;
    }
  }

  Future<void> submitRelocateChoice() async => submit();

  // Shared state
  final isLoading = false.obs;

  // === categories.json-derived ==============================================
  int? _questionId; // should resolve to 18
  final Map<String, int> _keyToAnswerId = {};   // "1".."3" -> real answer_id
  final Map<String, int> _labelToAnswerId = {}; // normalized label -> real answer_id
  bool _metaLoaded = false;

  @override
  void onInit() {
    super.onInit();
    _loadMetaFromAssets(); // async fire-and-forget
  }

  // === Submit ================================================================
  Future<void> submit() async {
    final box = Hive.box(HiveBoxes.userBox);
    final token = box.get('auth_token') ?? box.get('token') ?? box.get('access_token');

    if (token == null && !fromEdit) {
      // For setup flow we rely on token; for edit, EditProfileController will attach auth internally if needed.
      Get.snackbar("Error", "Missing token. Please login again.");
      return;
    }
    if (selectedKey.value.isEmpty) {
      Get.snackbar("Error", "Please select an option.");
      return;
    }

    // Ensure mapping is ready
    if (!_metaLoaded) {
      await _loadMetaFromAssets();
      if (!_metaLoaded) {
        Get.snackbar("Error", "Could not load relocate options. Please try again.");
        return;
      }
    }

    // Resolve real integer answer_id
    int? answerId = _keyToAnswerId[selectedKey.value];
    if (answerId == null) {
      final label = options.firstWhereOrNull((e) => e['key'] == selectedKey.value)?['label'] ?? '';
      if (label.isNotEmpty) {
        answerId = _labelToAnswerId[_norm(label)];
      }
    }
    if (answerId == null || _questionId == null) {
      Get.snackbar("Error", "Invalid selection.");
      return;
    }

    // Optional: cache human label locally
    final label = options.firstWhere((e) => e["key"] == selectedKey.value)["label"]!;
    box.put('relocate', label);

    isLoading.value = true;
    try {
      if (fromEdit) {
        // EDIT: update profile with {question_id, answer_id}
        final edit = _getOrCreate<EditProfileController>(() => EditProfileController());
        await edit.updateProfile([
          {"question_id": _questionId, "answer_id": answerId}
        ]);

        final profile = _getOrCreate<ProfileController>(() => ProfileController());
        await profile.fetchProfile();

        isLoading.value = false;
        Get.snackbar("Success", "Relocation preference updated.");
        // 🔁 Navigate to Dashboard on success (requested)
        Get.offAll(() => const DashboardScreen());
      } else {
        // SETUP: backend expects { answer_id: <int> }
        final res = await ApiService.post(
          'relocate-for-love',
          {'answer_id': answerId},
          token: token,
        );

        isLoading.value = false;

        if (res['success'] == true) {
          final profile = _getOrCreate<ProfileController>(() => ProfileController());
          await profile.fetchProfile();

          Get.snackbar("Success", res['message'] ?? "Relocation preference saved.");
          Get.offAll(() => const DashboardScreen());
        } else {
          Get.snackbar("Error", res['message'] ?? "Failed to submit.");
        }
      }
    } catch (e) {
      isLoading.value = false;
      Get.snackbar("Error", "Something went wrong. Please try again.");
    }
  }

  // === Load meta from assets/categories.json =================================
  Future<void> _loadMetaFromAssets() async {
    if (_metaLoaded) return;

    try {
      final jsonStr = await rootBundle.loadString('assets/categories.json');
      final dynamic data = json.decode(jsonStr);

      final List<dynamic> categories = data is List
          ? List<dynamic>.from(data)
          : (data is Map && data['categories'] is List
          ? List<dynamic>.from(data['categories'])
          : const <dynamic>[]);

      Map<String, dynamic>? category;
      Map<String, dynamic>? question;

      // 1) find category by title (tolerant)
      for (final raw in categories) {
        if (raw is! Map) continue;
        final cat = Map<String, dynamic>.from(raw as Map);
        final t = _norm((cat['title'] ?? '').toString());
        if (t == 'relocateforlove' || t == 'relocate' || t == 'relocation' || t == 'moveforlove') {
          category = cat;
          break;
        }
      }

      // 2) find question id == 18 (inside category if found; else anywhere)
      bool _pickQ(Map<String, dynamic> c) {
        final List<dynamic> qs = (c['questions'] as List?) ?? const [];
        for (final qr in qs) {
          if (qr is! Map) continue;
          final q = Map<String, dynamic>.from(qr as Map);
          final qidDyn = q['id'] ?? q['question_id'];
          final qid = qidDyn is int ? qidDyn : int.tryParse('$qidDyn');
          if (qid == 18) {
            question = q;
            return true;
          }
        }
        return false;
      }

      if (category != null) _pickQ(category);
      if (question == null) {
        for (final raw in categories) {
          if (raw is! Map) continue;
          if (_pickQ(Map<String, dynamic>.from(raw as Map))) break;
        }
      }

      if (question == null) {
        Get.log('[RelocateLoveController] question_id=18 not found in categories.json');
        return;
      }

      // Extract question_id
      final qidDyn = question!['id'] ?? question!['question_id'];
      final qid = qidDyn is int ? qidDyn : int.tryParse('$qidDyn');
      _questionId = qid;

      // Sort answers by display_order and map "1".."3" -> real answer_id
      final List<dynamic> answers = (question!['answers'] as List?) ?? const [];
      answers.sort((a, b) {
        final ma = (a is Map) ? a : const {};
        final mb = (b is Map) ? b : const {};
        final da = int.tryParse('${ma['display_order'] ?? 0}') ?? 0;
        final db = int.tryParse('${mb['display_order'] ?? 0}') ?? 0;
        return da.compareTo(db);
      });

      _keyToAnswerId.clear();
      _labelToAnswerId.clear();

      for (int i = 0; i < answers.length; i++) {
        final m = Map<String, dynamic>.from(answers[i] as Map);
        final idDyn = m['id'];
        final id = idDyn is int ? idDyn : int.tryParse('$idDyn');
        if (id == null) continue;

        final label = (m['label'] ?? m['value'] ?? '').toString();
        final key = '${i + 1}'; // "1".."3" in display order

        _keyToAnswerId[key] = id;
        if (label.isNotEmpty) _labelToAnswerId[_norm(label)] = id;
      }

      _metaLoaded = _questionId != null && _keyToAnswerId.isNotEmpty;
    } catch (e) {
      Get.log('[RelocateLoveController] Failed to load categories.json: $e');
    }
  }

  // === helpers ===============================================================
  String _norm(String s) => s
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'\s+'), ' ')
      .replaceAll(' ', '')
      .replaceAll('_', '')
      .replaceAll('-', '');

  T _getOrCreate<T>(T Function() create) {
    try {
      return Get.find<T>();
    } catch (_) {
      return Get.put<T>(create());
    }
  }
}
