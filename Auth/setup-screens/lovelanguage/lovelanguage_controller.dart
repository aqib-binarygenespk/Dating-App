// lib/controllers/love_languages_controller.dart
import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import 'package:get/get.dart';
import 'package:hive/hive.dart';

import '../../../services/api_services.dart';
import '../../../hive_utils/hive_boxes.dart';
import '../../../Dashbaord/profile/profile_controller.dart';

class LoveLanguagesController extends GetxController {
  final bool fromEdit;
  LoveLanguagesController({this.fromEdit = false});

  /// UI labels (kept for compatibility; we’ll map these to real answer_ids from JSON)
  final List<String> loveLanguages = const [
    'Words of Affirmation',
    'Acts of Service',
    'Receiving Gifts',
    'Quality Time',
    'Physical Touch',
  ];

  final selectedLanguages = <String>[].obs;
  final isLoading = false.obs;

  // -------- categories.json derived --------
  final _questionId = 16.obs; // backend uses fixed question_id = 16
  final Map<String, int> _answerIdByLabel = {};   // normalized label -> answer_id
  final List<int> _orderedAnswerIds = <int>[];    // fallback map by UI order
  bool _metaLoaded = false;

  @override
  void onInit() {
    super.onInit();
    _loadMeta(); // async fire-and-forget
  }

  // Toggle with max 2 selections
  void toggleLanguage(String language) {
    if (selectedLanguages.contains(language)) {
      selectedLanguages.remove(language);
    } else if (selectedLanguages.length < 2) {
      selectedLanguages.add(language);
    } else {
      Get.snackbar("Limit", "You can select up to 2 love languages.");
    }
  }

  Future<void> submitLoveLanguage() async {
    final token = _getToken();
    if (token == null) {
      Get.snackbar("Error", "Missing token. Please login again.");
      return;
    }

    if (selectedLanguages.isEmpty) {
      Get.snackbar("Error", "Please select at least one love language.");
      return;
    }

    // Ensure JSON mapping is ready
    if (!_metaLoaded) {
      await _loadMeta();
      if (!_metaLoaded) {
        Get.snackbar("Error", "Could not load love languages. Please try again.");
        return;
      }
    }

    // Map labels -> integer answer_ids (prefer label match; fallback by UI index)
    final answerIds = <int>[];
    for (final label in selectedLanguages) {
      final norm = _norm(label);
      int? id = _answerIdByLabel[norm];

      if (id == null) {
        // Fallback: position in UI list → id from JSON order
        final idx = loveLanguages.indexOf(label);
        if (idx >= 0 && idx < _orderedAnswerIds.length) {
          id = _orderedAnswerIds[idx];
        }
      }
      if (id == null) {
        Get.snackbar("Error", 'Invalid selection: "$label".');
        return;
      }
      answerIds.add(id);
    }

    // Cache locally (optional)
    final box = Hive.box(HiveBoxes.userBox);
    box.put('love_languages', selectedLanguages.toList());

    final payload = {'answers': answerIds};

    isLoading.value = true;
    try {
      final response = await ApiService.postJson(
        'love-languages',
        payload,
        token: token,
      );

      isLoading.value = false;

      if (response['success'] == true) {
        final profileController = _getOrCreate<ProfileController>(() => ProfileController());
        await profileController.fetchProfile();

        if (fromEdit) {
          Get.snackbar("Success", response['message'] ?? "Love languages updated.");
          Get.back(result: true);
        } else {
          Get.snackbar("Success", response['message'] ?? "Love languages saved.");
          Get.toNamed('/attachment');
        }
      } else {
        Get.snackbar("Error", response['message'] ?? "Failed to save.");
      }
    } catch (e) {
      isLoading.value = false;
      Get.snackbar("Error", "Something went wrong. Please try again.");
    }
  }

  // -------------------- JSON meta loader --------------------

  Future<void> _loadMeta() async {
    if (_metaLoaded) return;

    try {
      final jsonStr = await rootBundle.loadString('assets/categories.json');
      final dynamic data = json.decode(jsonStr);

      final List<dynamic> categories = data is List
          ? List<dynamic>.from(data)
          : (data is Map && data['categories'] is List
          ? List<dynamic>.from(data['categories'])
          : const <dynamic>[]);

      Map<String, dynamic>? targetCategory;
      Map<String, dynamic>? loveQ;

      // 1) find category by title
      for (final raw in categories) {
        if (raw is! Map) continue;
        final cat = Map<String, dynamic>.from(raw as Map);
        final t = _norm((cat['title'] ?? '').toString());
        if (t == 'lovelanguages' || t == 'love languages' || t == 'love-language') {
          targetCategory = cat;
          break;
        }
      }

      // 2) find question id == 16 (within category if found; else anywhere)
      List<dynamic> searchQuestions(Map<String, dynamic> m) =>
          (m['questions'] as List?) ?? const [];
      if (targetCategory != null) {
        for (final qr in searchQuestions(targetCategory)) {
          if (qr is! Map) continue;
          final q = Map<String, dynamic>.from(qr as Map);
          final qidDyn = q['id'] ?? q['question_id'];
          final qid = qidDyn is int ? qidDyn : int.tryParse('$qidDyn');
          if (qid == 16) {
            loveQ = q;
            break;
          }
        }
      }
      if (loveQ == null) {
        // scan all categories as fallback
        for (final raw in categories) {
          if (raw is! Map) continue;
          final cat = Map<String, dynamic>.from(raw as Map);
          for (final qr in searchQuestions(cat)) {
            if (qr is! Map) continue;
            final q = Map<String, dynamic>.from(qr as Map);
            final qidDyn = q['id'] ?? q['question_id'];
            final qid = qidDyn is int ? qidDyn : int.tryParse('$qidDyn');
            if (qid == 16) {
              loveQ = q;
              break;
            }
          }
          if (loveQ != null) break;
        }
      }

      if (loveQ == null) {
        Get.log('[LoveLanguagesController] question_id=16 not found in categories.json');
        return;
      }

      // answers: sort by display_order for consistent left→right order
      final List<dynamic> answersDyn = (loveQ['answers'] as List?) ?? const [];
      answersDyn.sort((a, b) {
        final ma = (a is Map) ? a : const {};
        final mb = (b is Map) ? b : const {};
        final da = int.tryParse('${ma['display_order'] ?? 0}') ?? 0;
        final db = int.tryParse('${mb['display_order'] ?? 0}') ?? 0;
        return da.compareTo(db);
      });

      _answerIdByLabel.clear();
      _orderedAnswerIds.clear();

      for (final a in answersDyn.whereType<Map>()) {
        final map = Map<String, dynamic>.from(a as Map);
        final label = (map['label'] ?? map['value'] ?? '').toString();
        final idDyn = map['id'];
        final id = idDyn is int ? idDyn : int.tryParse('$idDyn');
        if (label.isEmpty || id == null) continue;

        _answerIdByLabel[_norm(label)] = id;
        _orderedAnswerIds.add(id);
      }

      _metaLoaded = _answerIdByLabel.isNotEmpty && _orderedAnswerIds.isNotEmpty;
    } catch (e) {
      Get.log('[LoveLanguagesController] Failed to load categories.json: $e');
    }
  }

  // -------------------- helpers --------------------

  String? _getToken() {
    final box = Hive.box(HiveBoxes.userBox);
    return box.get('auth_token') ?? box.get('token') ?? box.get('access_token');
  }

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
