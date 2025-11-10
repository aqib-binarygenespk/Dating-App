// lib/controllers/attachment_style_controller.dart
import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import 'package:get/get.dart';
import 'package:hive/hive.dart';

import '../../../services/api_services.dart';
import '../../../hive_utils/hive_boxes.dart';
import '../../../Dashbaord/profile/profile_controller.dart';
import '../../../Dashbaord/settingspages/profilesettings/editprofilecontroller.dart';

class AttachmentStyleController extends GetxController {
  final bool fromEdit;
  AttachmentStyleController({this.fromEdit = false});

  /// UI options (kept as-is so your widgets don’t break)
  final List<Map<String, String>> options = const [
    {"key": "1", "label": "Secure"},
    {"key": "2", "label": "Anxious"},
    {"key": "3", "label": "Avoidant"},
    {"key": "4", "label": "Disorganized"},
  ];

  /// store just the UI key "1".."4"
  final selectedKey = ''.obs;
  final isLoading = false.obs;

  void select(String key) => selectedKey.value = key;

  // -------- categories.json derived --------
  int? _questionId; // should resolve to 17
  final Map<String, int> _keyToAnswerId = {};     // "1".."4" -> real answer_id
  final Map<String, int> _labelToAnswerId = {};   // normalized label -> real answer_id
  bool _metaLoaded = false;

  @override
  void onInit() {
    super.onInit();
    _loadMetaFromAssets(); // async fire-and-forget
  }

  Future<void> submit() async {
    final box = Hive.box(HiveBoxes.userBox);
    final token = box.get('auth_token') ?? box.get('token') ?? box.get('access_token');

    if (token == null) {
      Get.snackbar("Error", "Missing token. Please login again.");
      return;
    }
    if (selectedKey.value.isEmpty) {
      Get.snackbar("Error", "Please select an attachment style.");
      return;
    }

    // ensure mapping is available
    if (!_metaLoaded) {
      await _loadMetaFromAssets();
      if (!_metaLoaded) {
        Get.snackbar("Error", "Could not load attachment styles. Please try again.");
        return;
      }
    }

    // Resolve answer_id from UI key; fallback by label if needed
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

    // Optional: cache human-readable label locally
    final label = options.firstWhere((e) => e["key"] == selectedKey.value)["label"]!;
    box.put('attachment_style', label);

    isLoading.value = true;
    try {
      if (fromEdit) {
        // EDIT: profile updater expects array of {question_id, answer_id}
        final edit = _getOrCreate<EditProfileController>(() => EditProfileController());
        await edit.updateProfile([
          {"question_id": _questionId, "answer_id": answerId}
        ]);

        final profile = _getOrCreate<ProfileController>(() => ProfileController());
        await profile.fetchProfile();

        isLoading.value = false;
        Get.snackbar("Success", "Attachment style updated.");
        Get.back(result: true);
      } else {
        // SETUP: backend expects { answer_id: <int> }
        final res = await ApiService.post(
          'attachment-style',
          {'answer_id': answerId},
          token: token,
        );

        isLoading.value = false;

        if (res['success'] == true) {
          Get.snackbar("Success", res['message'] ?? "Attachment style saved.");
          Get.toNamed('/relocate');
        } else {
          Get.snackbar("Error", res['message'] ?? "Failed to save attachment style.");
        }
      }
    } catch (e) {
      isLoading.value = false;
      Get.snackbar("Error", "Something went wrong. Please try again.");
    }
  }

  // -------------------- JSON meta loader --------------------
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

      // 1) find category by title (be tolerant)
      for (final raw in categories) {
        if (raw is! Map) continue;
        final cat = Map<String, dynamic>.from(raw as Map);
        final t = _norm((cat['title'] ?? '').toString());
        if (t == 'attachmentstyle' || t == 'attachment style' || t == 'attachment') {
          category = cat;
          break;
        }
      }

      // 2) find question id == 17 (inside category if found; otherwise anywhere)
      bool _pickQ(Map<String, dynamic> c) {
        final List<dynamic> qs = (c['questions'] as List?) ?? const [];
        for (final qr in qs) {
          if (qr is! Map) continue;
          final q = Map<String, dynamic>.from(qr as Map);
          final qidDyn = q['id'] ?? q['question_id'];
          final qid = qidDyn is int ? qidDyn : int.tryParse('$qidDyn');
          if (qid == 17) {
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
        Get.log('[AttachmentStyleController] question_id=17 not found in categories.json');
        return;
      }

      // Extract question_id
      final qidDyn = question!['id'] ?? question!['question_id'];
      final qid = qidDyn is int ? qidDyn : int.tryParse('$qidDyn');
      _questionId = qid;

      // Sort answers by display_order and map "1".."4" -> real answer_id
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
        final key = '${i + 1}'; // "1".."4" by display order

        _keyToAnswerId[key] = id;
        if (label.isNotEmpty) {
          _labelToAnswerId[_norm(label)] = id;
        }
      }

      _metaLoaded = _questionId != null && _keyToAnswerId.isNotEmpty;
    } catch (e) {
      Get.log('[AttachmentStyleController] Failed to load categories.json: $e');
    }
  }

  // -------------------- helpers --------------------
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
