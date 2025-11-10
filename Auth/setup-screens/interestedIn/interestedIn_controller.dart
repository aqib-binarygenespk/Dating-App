import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import 'package:get/get.dart';
import 'package:hive/hive.dart';

import '../../../Dashbaord/settingspages/profilesettings/editprofilecontroller.dart';
import '../../../services/api_services.dart';
import '../../../hive_utils/hive_boxes.dart';
import '../../../Dashbaord/profile/profile_controller.dart';

class InterestedInController extends GetxController {
  final bool fromEdit;
  InterestedInController({this.fromEdit = false});

  // UI state
  final selectedInterest = 'male'.obs; // persisted in Hive as 'interested_in'
  final isLoading = false.obs;

  // categories.json derived
  final _questionId = RxnInt();
  List<Map<String, dynamic>> _answerOptions = <Map<String, dynamic>>[];
  bool _metaLoaded = false;

  @override
  void onInit() {
    super.onInit();
    _loadInterestedInMetaFromAssets(); // async fire-and-forget

    // Seed from Hive if present (e.g., 'male' / 'female')
    final box = Hive.box(HiveBoxes.userBox);
    final local = (box.get('interested_in') ?? '').toString().trim();
    if (local.isNotEmpty) {
      selectedInterest.value = local.toLowerCase();
    }
  }

  void updateInterest(String value) {
    selectedInterest.value = value.toLowerCase();
  }

  Future<void> submitInterest() async {
    isLoading.value = true;

    final token = _getToken();
    if (token == null) {
      isLoading.value = false;
      Get.snackbar("Error", "Missing token. Please log in again.");
      return;
    }

    // Make sure meta is ready (for answer_id + qid)
    if (!_metaLoaded || _questionId.value == null || _answerOptions.isEmpty) {
      await _loadInterestedInMetaFromAssets();
    }

    final int? qid = _questionId.value;
    final int? answerId = _resolveAnswerId(selectedInterest.value) ?? _firstAnswerId();

    // Persist locally for other screens
    final box = Hive.box(HiveBoxes.userBox);
    box.put('interested_in', selectedInterest.value);

    if (fromEdit) {
      // ---------------- EDIT FLOW ----------------
      if (qid == null || answerId == null) {
        isLoading.value = false;
        Get.snackbar("Error", 'Could not resolve "Interested in" selection. Please try again.');
        return;
      }

      try {
        final editController = _getOrCreate<EditProfileController>(() => EditProfileController());
        await editController.updateProfile([
          {"question_id": qid, "answer_id": answerId}
        ]);

        // Refresh profile
        final profileController = _getOrCreate<ProfileController>(() => ProfileController());
        await profileController.fetchProfile();

        isLoading.value = false;
        Get.snackbar("Success", "Interest updated");
        Get.back(result: true);
      } catch (e) {
        isLoading.value = false;
        Get.snackbar("Error", "Update failed. Please try again.");
      }
    } else {
      // ---------------- SETUP FLOW ----------------
      // IMPORTANT: API expects `interested_in` (string). We'll also include `answer_id` if we have it.
      try {
        final Map<String, dynamic> payload = {
          "interested_in": selectedInterest.value, // <-- fixes 422
        };
        if (answerId != null) {
          payload["answer_id"] = answerId; // optional; harmless if API ignores
        }

        final response = await ApiService.post(
          'interested-in',
          payload,
          token: token,
        );

        isLoading.value = false;

        if (response['success'] == true) {
          Get.snackbar("Success", response['message'] ?? "Interest saved");
          Get.toNamed('/location');
        } else if ((response['code'] ?? 0) == 422) {
          final msg = (response['message'] ?? "Validation Error.").toString();
          Get.snackbar("Error", msg);
        } else if ((response['code'] ?? 0) == 401) {
          Get.snackbar("Unauthorized", "Your session has expired. Please log in again.");
        } else {
          Get.snackbar("Error", response['message'] ?? "Failed to save preference");
        }
      } catch (e) {
        isLoading.value = false;
        Get.snackbar("Error", "Something went wrong. Try again.");
      }
    }
  }

  // ---------------- helpers ----------------

  Future<void> _loadInterestedInMetaFromAssets() async {
    if (_metaLoaded) return;

    try {
      final jsonStr = await rootBundle.loadString('assets/categories.json');
      final dynamic data = json.decode(jsonStr);

      final List<dynamic> categories = data is List
          ? List<dynamic>.from(data)
          : (data is Map && data['categories'] is List
          ? List<dynamic>.from(data['categories'])
          : const <dynamic>[]);

      Map<String, dynamic>? interestedCat;

      for (final raw in categories) {
        if (raw is! Map) continue;
        final cat = Map<String, dynamic>.from(raw as Map);
        final title = (cat['title'] ?? '').toString();
        final t = _norm(title);
        if (t == 'interestedin' || t == 'interested-in' || t == 'interested in') {
          interestedCat = cat;
          break;
        }
      }

      if (interestedCat == null) {
        Get.log('[InterestedInController] "Interested in" category not found.');
        return;
      }

      final List<dynamic> questionsDyn = (interestedCat['questions'] as List?) ?? const [];
      if (questionsDyn.isEmpty || questionsDyn.first is! Map) {
        Get.log('[InterestedInController] "Interested in" has no questions.');
        return;
      }

      final Map<String, dynamic> q = Map<String, dynamic>.from(questionsDyn.first as Map);
      final dynamic qidDynamic = q['id'] ?? q['question_id'];
      _questionId.value = qidDynamic is int ? qidDynamic : int.tryParse('$qidDynamic');

      final List<dynamic> answersDyn = (q['answers'] as List?) ?? const [];
      _answerOptions = answersDyn
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();

      // If current selection doesn't map, default to the first answer's value
      if (_resolveAnswerId(selectedInterest.value) == null && _answerOptions.isNotEmpty) {
        final first = _answerOptions.first;
        final fallback = (first['value'] ?? first['label'] ?? '').toString();
        if (fallback.isNotEmpty) {
          selectedInterest.value = fallback.toLowerCase();
        }
      }

      _metaLoaded = true;
    } catch (e) {
      Get.log('[InterestedInController] Failed to load categories.json: $e');
    }
  }

  int? _resolveAnswerId(String choice) {
    final c = _norm(choice);
    // Common synonyms
    final alias = <String, String>{
      'm': 'male',
      'man': 'male',
      'men': 'male',
      'f': 'female',
      'woman': 'female',
      'women': 'female',
    };
    final normalized = alias[c] ?? c;

    for (final a in _answerOptions) {
      final value = _norm((a['value'] ?? '').toString());
      final label = _norm((a['label'] ?? '').toString());
      if (value == normalized || label == normalized) {
        final idDyn = a['id'];
        return idDyn is int ? idDyn : int.tryParse('$idDyn');
      }
    }
    return null;
  }

  int? _firstAnswerId() {
    if (_answerOptions.isEmpty) return null;
    final idDyn = _answerOptions.first['id'];
    return idDyn is int ? idDyn : int.tryParse('$idDyn');
  }

  String? _getToken() {
    final box = Hive.box(HiveBoxes.userBox);
    return box.get('auth_token') ?? box.get('token') ?? box.get('access_token');
  }

  T _getOrCreate<T>(T Function() create) {
    try {
      return Get.find<T>();
    } catch (_) {
      return Get.put<T>(create());
    }
  }

  String _norm(String s) => s
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'\s+'), ' ')
      .replaceAll(' ', '')
      .replaceAll('_', '')
      .replaceAll('-', '');
}
