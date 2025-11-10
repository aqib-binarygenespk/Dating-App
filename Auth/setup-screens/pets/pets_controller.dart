// lib/controllers/pets_selection_controller.dart
import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import 'package:get/get.dart';
import 'package:hive/hive.dart';

import '../../../Dashbaord/profile/profile_controller.dart';
import '../../../Dashbaord/settingspages/profilesettings/editprofilecontroller.dart';
import '../../../hive_utils/hive_boxes.dart';
import '../../../services/api_services.dart';

class PetsSelectionController extends GetxController {
  final bool fromEdit;
  PetsSelectionController({this.fromEdit = false});

  /// UI options (kept for backward compatibility with existing views)
  final List<String> options = const [
    "No Pets",
    "Dog Lover",
    "Cat Enthusiast",
    "Both Cats and Dogs",
    "Small Pet Parent (Rabbits, Hamsters, etc.)",
    "Exotic Animals (Birds, Reptiles, etc.)",
    "Open to Pets",
    "Allergic, but Love Animals",
  ];

  /// Selected option label
  final selectedOption = ''.obs;
  final isLoading = false.obs;

  // ---- categories.json derived ----
  final _questionId = RxnInt();                       // should resolve to 12
  final Map<String, int> _answerIdByLabel = {};       // normalized label -> answer_id
  bool _metaLoaded = false;

  @override
  void onInit() {
    super.onInit();
    _loadPetsMetaFromAssets(); // fire-and-forget
  }

  void selectOption(String option) {
    selectedOption.value = option;
  }

  Future<void> submitAnswer() async {
    final box = Hive.box(HiveBoxes.userBox);
    final token = box.get('auth_token') ?? box.get('token') ?? box.get('access_token');

    if (token == null || token.toString().isEmpty) {
      Get.snackbar("Error", "Missing token. Please log in again.");
      return;
    }

    final choice = selectedOption.value.trim();
    if (choice.isEmpty) {
      Get.snackbar("Error", "Please select an option before proceeding.");
      return;
    }

    // Ensure metadata (question + answers) is loaded
    if (!_metaLoaded || _questionId.value == null || _answerIdByLabel.isEmpty) {
      await _loadPetsMetaFromAssets();
      if (!_metaLoaded || _questionId.value == null || _answerIdByLabel.isEmpty) {
        Get.snackbar("Error", "Could not load pets options. Please try again.");
        return;
      }
    }

    final int? answerId = _answerIdByLabel[_norm(choice)];
    if (answerId == null) {
      Get.snackbar("Error", "Invalid selection.");
      return;
    }

    // Cache locally (optional)
    box.put('pets', choice);

    isLoading.value = true;
    try {
      if (fromEdit) {
        // EDIT FLOW: update via profile updater
        final editController = _getOrCreate<EditProfileController>(() => EditProfileController());
        await editController.updateProfile([
          {"question_id": _questionId.value, "answer_id": answerId}
        ]);

        // Refresh
        final profileController = _getOrCreate<ProfileController>(() => ProfileController());
        await profileController.fetchProfile();

        isLoading.value = false;
        Get.snackbar("Success", "Pets updated.");
        Get.back(result: true);
      } else {
        // SETUP FLOW: backend expects { answer_id }
        final response = await ApiService.post(
          'pets',
          {'answer_id': answerId},
          token: token,
        );

        isLoading.value = false;

        if (response['success'] == true || response['status'] == true) {
          final profileController = _getOrCreate<ProfileController>(() => ProfileController());
          await profileController.fetchProfile();

          Get.snackbar("Success", response['message'] ?? "Pets saved.");
          Get.toNamed('/yourhabbit'); // continue setup flow
        } else {
          Get.snackbar("Error", response['message'] ?? "Failed to submit pets answer.");
        }
      }
    } catch (e) {
      isLoading.value = false;
      Get.snackbar("Error", "Something went wrong. Please try again.");
    }
  }

  // -------------------- helpers --------------------

  Future<void> _loadPetsMetaFromAssets() async {
    if (_metaLoaded && _questionId.value != null && _answerIdByLabel.isNotEmpty) return;

    try {
      final jsonStr = await rootBundle.loadString('assets/categories.json');
      final dynamic data = json.decode(jsonStr);

      // categories may be a top-level list or under { "categories": [...] }
      final List<dynamic> categories = data is List
          ? List<dynamic>.from(data)
          : (data is Map && data['categories'] is List
          ? List<dynamic>.from(data['categories'])
          : const <dynamic>[]);

      Map<String, dynamic>? petsCategory;
      Map<String, dynamic>? petsQuestion;

      // 1) Try to find by category title
      for (final raw in categories) {
        if (raw is! Map) continue;
        final cat = Map<String, dynamic>.from(raw as Map);
        final title = (cat['title'] ?? '').toString();
        final t = _norm(title);
        if (t == 'pets' ||
            t == 'petspreferences' ||
            t == 'petspreference' ||
            t == 'pets&animals' ||
            t == 'petsandanimals') {
          petsCategory = cat;
          break;
        }
      }

      // 2) If category not found, fallback: find any question with id == 12
      if (petsCategory == null) {
        for (final raw in categories) {
          if (raw is! Map) continue;
          final cat = Map<String, dynamic>.from(raw as Map);
          final List<dynamic> qList = (cat['questions'] as List?) ?? const [];
          for (final qRaw in qList) {
            if (qRaw is! Map) continue;
            final q = Map<String, dynamic>.from(qRaw as Map);
            final qidDyn = q['id'] ?? q['question_id'];
            final qid = qidDyn is int ? qidDyn : int.tryParse('$qidDyn');
            if (qid == 12) {
              petsCategory = cat;
              petsQuestion = q;
              break;
            }
          }
          if (petsQuestion != null) break;
        }
      }

      // 3) If we found the category but not the question, fetch first question with id == 12 within it
      if (petsCategory != null && petsQuestion == null) {
        final List<dynamic> qList = (petsCategory['questions'] as List?) ?? const [];
        for (final qRaw in qList) {
          if (qRaw is! Map) continue;
          final q = Map<String, dynamic>.from(qRaw as Map);
          final qidDyn = q['id'] ?? q['question_id'];
          final qid = qidDyn is int ? qidDyn : int.tryParse('$qidDyn');
          if (qid == 12) {
            petsQuestion = q;
            break;
          }
        }
        // As a last resort: if the Pets category has a single question, use it
        if (petsQuestion == null && qList.length == 1 && qList.first is Map) {
          petsQuestion = Map<String, dynamic>.from(qList.first as Map);
        }
      }

      if (petsQuestion == null) {
        Get.log('[PetsSelectionController] Could not locate Pets question (id=12) in categories.json');
        return;
      }

      // Resolve question id
      final qidDyn = petsQuestion['id'] ?? petsQuestion['question_id'];
      final qid = qidDyn is int ? qidDyn : int.tryParse('$qidDyn');
      _questionId.value = qid;

      // Answers (sort by display_order if present)
      final List<dynamic> answersDyn = (petsQuestion['answers'] as List?) ?? const [];
      answersDyn.sort((a, b) {
        final ma = (a is Map) ? a : const {};
        final mb = (b is Map) ? b : const {};
        final da = int.tryParse('${ma['display_order'] ?? 0}') ?? 0;
        final db = int.tryParse('${mb['display_order'] ?? 0}') ?? 0;
        return da.compareTo(db);
      });

      _answerIdByLabel.clear();
      for (final a in answersDyn.whereType<Map>()) {
        final ans = Map<String, dynamic>.from(a as Map);
        final label = (ans['label'] ?? ans['value'] ?? '').toString();
        final idDyn = ans['id'];
        final id = idDyn is int ? idDyn : int.tryParse('$idDyn');
        if (label.isEmpty || id == null) continue;
        _answerIdByLabel[_norm(label)] = id;
      }

      _metaLoaded = true;
    } catch (e) {
      Get.log('[PetsSelectionController] Failed to load categories.json: $e');
    }
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
