// lib/controllers/habits_controller.dart
import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import 'package:get/get.dart';
import 'package:hive/hive.dart';

import '../../../Dashbaord/dashboard/Dashboard.dart';
import '../../../services/api_services.dart';
import '../../../hive_utils/hive_boxes.dart';
import '../../../Dashbaord/profile/profile_controller.dart';
import '../../../Dashbaord/settingspages/profilesettings/editprofilecontroller.dart';

class HabitsController extends GetxController {
  final bool fromEdit;
  HabitsController({this.fromEdit = false});

  // -------- UI selections --------
  final smokingKey = ''.obs;   // "1" | "2" | "3"
  final drinkingKey = ''.obs;  // "1" | "2" | "3"
  final dietKey = ''.obs;      // "1".."6"
  final workoutKey = ''.obs;   // "1".."3"

  final isLoading = false.obs;

  // Optional labels for local cache
  final List<Map<String, String>> smokingOptions = const [
    {"key": "1", "label": "Non-smoker"},
    {"key": "2", "label": "Occasional Smoker"},
    {"key": "3", "label": "Regular Smoker"},
  ];

  final List<Map<String, String>> drinkingOptions = const [
    {"key": "1", "label": "Non-Drinker"},
    {"key": "2", "label": "Social Drinker"},
    {"key": "3", "label": "Regular Drinker"},
  ];

  final List<Map<String, String>> dietOptions = const [
    {"key": "1", "label": "Omnivore"},
    {"key": "2", "label": "Vegetarian"},
    {"key": "3", "label": "Vegan"},
    {"key": "4", "label": "Gluten-Free"},
    {"key": "5", "label": "Pescatarian"},
    {"key": "6", "label": "Other (with an option to specify)"},
  ];

  final List<Map<String, String>> workoutOptions = const [
    {"key": "1", "label": "Active"},
    {"key": "2", "label": "Sometimes"},
    {"key": "3", "label": "Almost Never"},
  ];

  // Quick setters for UI
  void selectSmoking(String key) => smokingKey.value = key;
  void selectDrinking(String key) => drinkingKey.value = key;
  void selectDiet(String key) => dietKey.value = key;
  void selectWorkout(String key) => workoutKey.value = key;

  // -------- categories.json derived --------
  int? _qidSmoking;
  int? _qidDrinking;
  int? _qidDiet;
  int? _qidWorkout;

  final Map<String, int> _smokingKeyToId = {};
  final Map<String, int> _drinkingKeyToId = {};
  final Map<String, int> _dietKeyToId = {};
  final Map<String, int> _workoutKeyToId = {};

  bool _metaLoaded = false;

  @override
  void onInit() {
    super.onInit();
    _loadHabitsMetaFromAssets(); // async
  }

  Future<void> submitHabits() async {
    // ✅ Robust token read (covers bearer_token) + normalize to auth_token
    final token = _getTokenAndNormalize();
    if (token == null && !fromEdit) {
      // Don't spam user after previous steps; just fail gracefully
      Get.snackbar("Error", "Session expired. Please sign in again.");
      return;
    }

    if (smokingKey.value.isEmpty ||
        drinkingKey.value.isEmpty ||
        dietKey.value.isEmpty ||
        workoutKey.value.isEmpty) {
      Get.snackbar("Error", "Please complete all selections.");
      return;
    }

    if (!_metaLoaded) {
      await _loadHabitsMetaFromAssets();
      if (!_metaLoaded) {
        Get.snackbar("Error", "Could not load habits options. Please try again.");
        return;
      }
    }

    final int? smokingAns = _smokingKeyToId[smokingKey.value];
    final int? drinkingAns = _drinkingKeyToId[drinkingKey.value];
    final int? dietAns = _dietKeyToId[dietKey.value];
    final int? workoutAns = _workoutKeyToId[workoutKey.value];

    if (_qidSmoking == null || smokingAns == null ||
        _qidDrinking == null || drinkingAns == null ||
        _qidDiet == null || dietAns == null ||
        _qidWorkout == null || workoutAns == null) {
      Get.snackbar("Error", "Invalid selection mapping. Please try again.");
      return;
    }

    // Optional: cache labels locally
    final box = Hive.box(HiveBoxes.userBox);
    String labelFrom(List<Map<String, String>> opts, String key) =>
        opts.firstWhere((e) => e["key"] == key)["label"]!;
    box
      ..put('smoking_habit', labelFrom(smokingOptions, smokingKey.value))
      ..put('drinking_habit', labelFrom(drinkingOptions, drinkingKey.value))
      ..put('dietary_preference', labelFrom(dietOptions, dietKey.value))
      ..put('workout_frequency', labelFrom(workoutOptions, workoutKey.value));

    final answers = [
      {"question_id": _qidSmoking, "answer_id": smokingAns},
      {"question_id": _qidDrinking, "answer_id": drinkingAns},
      {"question_id": _qidDiet, "answer_id": dietAns},
      {"question_id": _qidWorkout, "answer_id": workoutAns},
    ];

    isLoading.value = true;

    try {
      if (fromEdit) {
        // EDIT flow (EditProfileController handles auth internally in your stack)
        final edit = _getOrCreate<EditProfileController>(() => EditProfileController());
        await edit.updateProfile(answers);

        final profile = _getOrCreate<ProfileController>(() => ProfileController());
        await profile.fetchProfile();

        isLoading.value = false;
        Get.snackbar("Success", "Habits updated.");
        Get.offAll(() => const DashboardScreen());
      } else {
        // SETUP flow
        final res = await ApiService.postJson('habits', {"answers": answers}, token: token);

        isLoading.value = false;

        if (res['success'] == true) {
          final profile = _getOrCreate<ProfileController>(() => ProfileController());
          await profile.fetchProfile();

          Get.snackbar("Success", res['message'] ?? "Habits saved.");
          Get.offAll(() => const DashboardScreen());
        } else {
          Get.snackbar("Error", res['message'] ?? "Failed to save habits.");
        }
      }
    } catch (e) {
      isLoading.value = false;
      Get.snackbar("Error", "Something went wrong. Please try again.");
    }
  }

  // -------- Load & map from assets/categories.json --------
  Future<void> _loadHabitsMetaFromAssets() async {
    if (_metaLoaded) return;

    try {
      final jsonStr = await rootBundle.loadString('assets/categories.json');
      final dynamic data = json.decode(jsonStr);

      final List<dynamic> categories = data is List
          ? List<dynamic>.from(data)
          : (data is Map && data['categories'] is List
          ? List<dynamic>.from(data['categories'])
          : const <dynamic>[]);

      Map<String, dynamic>? habitsCategory;

      // Find category by title (tolerant)
      for (final raw in categories) {
        if (raw is! Map) continue;
        final cat = Map<String, dynamic>.from(raw as Map);
        final t = _norm((cat['title'] ?? '').toString());
        if (t == 'habits' ||
            t == 'yourhabits' ||
            t == 'lifestylehabits' ||
            t == 'yourhabbits' ||
            t == 'habbits') {
          habitsCategory = cat;
          break;
        }
      }

      if (habitsCategory == null) {
        for (final raw in categories) {
          if (raw is! Map) continue;
          final cat = Map<String, dynamic>.from(raw as Map);
          if (_tryExtractQuestions(cat)) {
            _metaLoaded = true;
            return;
          }
        }
      } else {
        if (_tryExtractQuestions(habitsCategory)) {
          _metaLoaded = true;
          return;
        }
      }
    } catch (e) {
      Get.log('[HabitsController] Failed to load categories.json: $e');
    }
  }

  /// Extract 4 habit questions and map "1..N" -> real answer_id by display_order.
  bool _tryExtractQuestions(Map<String, dynamic> category) {
    final List<dynamic> qList = (category['questions'] as List?) ?? const [];
    if (qList.isEmpty) return false;

    Map<String, dynamic>? qSmoking;
    Map<String, dynamic>? qDrinking;
    Map<String, dynamic>? qDiet;
    Map<String, dynamic>? qWorkout;

    for (final qRaw in qList) {
      if (qRaw is! Map) continue;
      final q = Map<String, dynamic>.from(qRaw as Map);
      final heading = _norm((q['heading'] ?? q['title'] ?? '').toString());

      if (qSmoking == null && (heading.contains('smok') || heading.contains('cig'))) {
        qSmoking = q; continue;
      }
      if (qDrinking == null && (heading.contains('drink') || heading.contains('alcohol'))) {
        qDrinking = q; continue;
      }
      if (qDiet == null && (heading.contains('diet') || heading.contains('food') || heading.contains('eat'))) {
        qDiet = q; continue;
      }
      if (qWorkout == null && (heading.contains('workout') || heading.contains('exercise') || heading.contains('activity') || heading.contains('fitness'))) {
        qWorkout = q; continue;
      }
    }

    // Fallback by answer counts if needed
    if (qSmoking == null || qDrinking == null || qDiet == null || qWorkout == null) {
      for (final qRaw in qList) {
        if (qRaw is! Map) continue;
        final q = Map<String, dynamic>.from(qRaw as Map);
        final answers = (q['answers'] as List?) ?? const [];
        if (qSmoking == null && answers.length == 3 && _looksLikeSmoking(answers)) qSmoking = q;
        else if (qDrinking == null && answers.length == 3 && _looksLikeDrinking(answers)) qDrinking = q;
        else if (qDiet == null && answers.length == 6) qDiet = q;
        else if (qWorkout == null && answers.length == 3 && _looksLikeWorkout(answers)) qWorkout = q;
      }
    }

    if (qSmoking == null || qDrinking == null || qDiet == null || qWorkout == null) return false;

    void mapQuestion(Map<String, dynamic> q,
        void Function(int qid, Map<String, int> keyToId) assign) {
      final qidDyn = q['id'] ?? q['question_id'];
      final qid = qidDyn is int ? qidDyn : int.tryParse('$qidDyn');
      if (qid == null) return;

      final answersDyn = (q['answers'] as List?) ?? const [];
      answersDyn.sort((a, b) {
        final ma = (a is Map) ? a : const {};
        final mb = (b is Map) ? b : const {};
        final da = int.tryParse('${ma['display_order'] ?? 0}') ?? 0;
        final db = int.tryParse('${mb['display_order'] ?? 0}') ?? 0;
        return da.compareTo(db);
      });

      final keyToId = <String, int>{};
      for (int i = 0; i < answersDyn.length; i++) {
        final m = Map<String, dynamic>.from(answersDyn[i] as Map);
        final idDyn = m['id'];
        final id = idDyn is int ? idDyn : int.tryParse('$idDyn');
        if (id == null) continue;
        final key = '${i + 1}'; // "1".."N"
        keyToId[key] = id;
      }
      assign(qid, keyToId);
    }

    mapQuestion(qSmoking, (qid, map) { _qidSmoking = qid; _smokingKeyToId..clear()..addAll(map); });
    mapQuestion(qDrinking, (qid, map) { _qidDrinking = qid; _drinkingKeyToId..clear()..addAll(map); });
    mapQuestion(qDiet,     (qid, map) { _qidDiet = qid;     _dietKeyToId..clear()..addAll(map); });
    mapQuestion(qWorkout,  (qid, map) { _qidWorkout = qid;  _workoutKeyToId..clear()..addAll(map); });

    return _qidSmoking != null &&
        _qidDrinking != null &&
        _qidDiet != null &&
        _qidWorkout != null &&
        _smokingKeyToId.isNotEmpty &&
        _drinkingKeyToId.isNotEmpty &&
        _dietKeyToId.isNotEmpty &&
        _workoutKeyToId.isNotEmpty;
  }

  bool _looksLikeSmoking(List answers) {
    final s = answers.map((e) => _norm('${(e as Map)['label'] ?? (e as Map)['value'] ?? ''}')).join(' ');
    return s.contains('smok') || s.contains('non') || s.contains('regular');
  }

  bool _looksLikeDrinking(List answers) {
    final s = answers.map((e) => _norm('${(e as Map)['label'] ?? (e as Map)['value'] ?? ''}')).join(' ');
    return s.contains('drink') || s.contains('social') || s.contains('non');
  }

  bool _looksLikeWorkout(List answers) {
    final s = answers.map((e) => _norm('${(e as Map)['label'] ?? (e as Map)['value'] ?? ''}')).join(' ');
    return s.contains('active') || s.contains('workout') || s.contains('exercise') || s.contains('never');
  }

  String _norm(String s) => s
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'\s+'), ' ')
      .replaceAll(' ', '')
      .replaceAll('_', '')
      .replaceAll('-', '');

  // ---------- Token helper (robust + normalization) ----------
  String? _getTokenAndNormalize() {
    final box = Hive.box(HiveBoxes.userBox);
    final raw = (box.get('auth_token') ??
        box.get('token') ??
        box.get('access_token') ??
        box.get('bearer_token'))
        ?.toString();

    if (raw == null) return null;
    final t = raw.trim();
    if (t.isEmpty) return null;

    // Normalize so downstream screens/controllers always find it
    box.put('auth_token', t);
    return t;
  }

  T _getOrCreate<T>(T Function() create) {
    try { return Get.find<T>(); } catch (_) { return Get.put<T>(create()); }
  }
}
