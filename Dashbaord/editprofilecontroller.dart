// lib/Dashbaord/settingspages/profilesettings/editprofile/editprofilecontroller.dart
import 'dart:convert';
import 'package:get/get.dart';
import 'package:hive/hive.dart';

import '../../../hive_utils/hive_boxes.dart';
import '../../../services/api_services.dart';
import '../../profile/profile_controller.dart';
import 'package:flutter/material.dart';

class EditProfileController extends GetxController {
  // Existing profile fields
  var name = ''.obs;
  var age = ''.obs;
  var gender = ''.obs;
  var height = ''.obs;
  var interestedIn = ''.obs;
  var getToKnowMePrompt = ''.obs;
  var aboutMe = ''.obs;
  var relationshipGoal = ''.obs;
  var pets = ''.obs;
  var relocateForLove = ''.obs;
  var attachmentStyle = ''.obs;
  var loveLanguage = ''.obs;

  // ✅ Habit fields
  var smoking = ''.obs;
  var drinking = ''.obs;
  var diet = ''.obs;

  // ✅ NEW fields for the screens we added
  var zodiac = ''.obs;            // Q37
  var education = ''.obs;         // Q36
  var religion = ''.obs;          // Q35
  var politicalViews = ''.obs;    // Q34
  var childrenPlan = ''.obs;      // Q33 (want/open/not sure)
  var haveKids = ''.obs;          // Q33 (have/don't have)
  var workout = ''.obs;           // TODO: update when backend adds questionId

  var isLoading = false.obs;

  final ProfileController profileController = Get.find<ProfileController>();

  // ------------ Label maps for answer_id -> text ------------
  static const Map<int, String> _politicalMap = {
    1: 'Apolitical', 2: 'Moderate', 3: 'Liberal', 4: 'Conservative',
  };
  static const Map<int, String> _religionMap = {
    1: 'No Preference', 2: 'Christian', 3: 'Catholic', 4: 'Jewish', 5: 'Muslim',
    6: 'Unitarian / Universalist', 7: 'Buddhist', 8: 'Hindu', 9: 'Agnostic',
    10: 'Atheist', 11: 'Other',
  };
  static const Map<int, String> _educationMap = {
    1: 'High school', 2: 'Trade/tech school', 3: 'In college',
    4: 'Undergraduate degree', 5: 'In grad school', 6: 'Graduate degree',
  };
  static const Map<int, String> _zodiacMap = {
    1: 'Aries', 2: 'Taurus', 3: 'Gemini', 4: 'Cancer', 5: 'Leo', 6: 'Virgo',
    7: 'Libra', 8: 'Scorpio', 9: 'Sagittarius', 10: 'Capricorn',
    11: 'Aquarius', 12: 'Pisces',
  };
  static const Map<int, String> _kidsMap = {
    1: 'Have kids',
    2: "Don't have kids",
    3: 'Want kids',
    4: 'Open to them',
    5: 'Not sure',
  };
  static const Map<int, String> _loveMap = {
    1: 'Words of Affirmation',
    2: 'Acts of Service',
    3: 'Receiving Gifts',
    4: 'Quality Time',
    5: 'Physical Touch',
  };

  static const int workoutQuestionId = -1; // replace later

  @override
  void onInit() {
    super.onInit();
    fetchProfile();
  }

  Future<void> fetchProfile() async {
    isLoading.value = true;
    try {
      final box = Hive.box(HiveBoxes.userBox);
      final token = box.get('auth_token');

      if (token == null || token.toString().isEmpty) {
        Get.snackbar("Error", "Missing token.");
        return;
      }

      final response = await ApiService.get('profile', token: token);
      if ((response['success'] == true || response['status'] == true) && response['data'] != null) {
        final data = response['data'];

        name.value = data['name'] ?? '';
        age.value = data['age']?.toString() ?? '';
        gender.value = _prettyGender(data['gender'] ?? '');
        height.value = data['height']?.toString() ?? '';
        interestedIn.value = data['interested_in'] ?? '';
        getToKnowMePrompt.value = data['get_to_know_me']?.toString() ?? '';
        aboutMe.value = data['about_me'] ?? '';
        relationshipGoal.value = data['relationship_goal'] ?? '';
        pets.value = data['pets'] ?? '';
        relocateForLove.value = data['relocate_for_love'] ?? '';
        attachmentStyle.value = data['attachment_style'] ?? '';

        smoking.value = data['smoking_habits'] ?? '';
        drinking.value = data['drinking_habits'] ?? '';
        diet.value = data['diet_preferences'] ?? '';

        // ✅ Love Languages
        final loveLangRaw = data['love_language'];
        if (loveLangRaw is List) {
          loveLanguage.value = loveLangRaw.whereType<String>().join(', ');
        } else if (loveLangRaw is String) {
          loveLanguage.value = loveLangRaw;
        } else {
          final ids = _extractAnswerIdsFromUserAnswers(data, 16);
          if (ids.isNotEmpty) {
            loveLanguage.value = ids
                .map((id) => _loveMap[id] ?? '')
                .where((e) => e.isNotEmpty)
                .join(', ');
          } else {
            loveLanguage.value = '';
          }
        }

        zodiac.value = data['zodiac'] ?? _extractLabeledFromAnswers(data, 37, _zodiacMap);
        education.value = data['education'] ?? _extractLabeledFromAnswers(data, 36, _educationMap);
        religion.value = data['religion'] ?? _extractLabeledFromAnswers(data, 35, _religionMap);
        politicalViews.value = data['political_views'] ?? _extractLabeledFromAnswers(data, 34, _politicalMap);

        final kidsLabel = _extractLabeledFromAnswers(data, 33, _kidsMap);
        if (kidsLabel == 'Have kids' || kidsLabel == "Don't have kids") {
          haveKids.value = kidsLabel;
          childrenPlan.value = '';
        } else {
          childrenPlan.value = kidsLabel;
          haveKids.value = '';
        }

        workout.value = workoutQuestionId > 0
            ? _extractAnswerFromUserAnswers(data, workoutQuestionId)
            : '';

      } else {
        Get.snackbar("Error", "Failed to load profile.");
      }
    } catch (e) {
      debugPrint('❌ fetchProfile error: $e');
      Get.snackbar("Error", "Something went wrong.");
    } finally {
      isLoading.value = false;
    }
  }

  /// ✅ Update **gender** using top-level { "gender": "male|female|other" }
  /// Backend validator: 'nullable|in:male,female,other'
  Future<void> updateGender(String displayValue) async {
    final box = Hive.box(HiveBoxes.userBox);
    final token = box.get('auth_token');

    if (token == null || token.toString().isEmpty) {
      Get.snackbar("Error", "Missing token.");
      return;
    }

    final lower = (displayValue.trim().toLowerCase());
    if (!['male', 'female', 'other'].contains(lower)) {
      Get.snackbar('Invalid', 'Please select Male, Female, or Other');
      return;
    }

    try {
      isLoading.value = true;

      final payload = {'gender': lower};
      final response = await ApiService.put(
        'update-profile',
        payload,
        token: token,
        isJson: true,
      );

      final ok = (response['success'] == true || response['status'] == true);
      if (ok) {
        // Prefer server echo if present
        final updated = response['data']?['gender'] ?? lower;
        gender.value = _prettyGender(updated);
        Get.snackbar('Updated', 'Gender updated successfully');
        // Re-fetch to keep local caches consistent (e.g., ProfileController)
        await profileController.fetchProfile();
        await fetchProfile();
      } else {
        Get.snackbar('Error', response['message']?.toString() ?? 'Failed to update gender.');
      }
    } catch (e) {
      debugPrint('❌ updateGender error: $e');
      Get.snackbar('Error', 'Could not update gender.');
    } finally {
      isLoading.value = false;
    }
  }

  /// ✅ Normalized updateProfile (for non-gender fields)
  /// Accepts either:
  /// - a raw list of maps (for single–selects etc.)
  /// - or a wrapped map with "answers" (for multi–selects like Love Languages)
  /// ❗ Do NOT use this for gender.
  Future<void> updateProfile(dynamic payload) async {
    try {
      final box = Hive.box(HiveBoxes.userBox);
      final token = box.get('auth_token');

      if (token == null || token.toString().isEmpty) {
        Get.snackbar("Error", "Missing token.");
        return;
      }

      Map<String, dynamic> body;
      if (payload is List<Map<String, dynamic>>) {
        body = {"answers": payload};
      } else if (payload is Map<String, dynamic>) {
        body = payload;
      } else {
        throw ArgumentError("Invalid payload type for updateProfile");
      }

      // Guard: if caller accidentally passes gender here, route correctly.
      if (body.containsKey('gender')) {
        await updateGender(body['gender'].toString());
        return;
      }

      final response = await ApiService.put(
        'update-profile',
        body,
        token: token,
        isJson: true,
      );

      if (response['success'] == true || response['status'] == true) {
        await profileController.fetchProfile();
        await fetchProfile();
        Get.snackbar("Success", "Profile updated.");
      } else {
        Get.snackbar("Error", response['message'] ?? "Update failed.");
      }
    } catch (e) {
      debugPrint('❌ updateProfile error: $e');
      Get.snackbar("Error", "Something went wrong during update.");
    }
  }

  // ---------------- Helpers ----------------
  String _prettyGender(String raw) {
    final v = (raw).toString().trim().toLowerCase();
    if (v.isEmpty) return '';
    if (v == 'male') return 'Male';
    if (v == 'female') return 'Female';
    // Fallback: capitalize first letter
    return v[0].toUpperCase() + v.substring(1);
  }

  String _extractLabeledFromAnswers(dynamic data, int qid, Map<int, String> map) {
    final id = _extractAnswerIdFromUserAnswers(data, qid);
    if (id != null) return map[id] ?? '';
    return _extractAnswerFromUserAnswers(data, qid);
  }

  String _extractAnswerFromUserAnswers(dynamic data, int qid) {
    if (data is! Map) return '';
    dynamic ua = data['user_answers'];
    List<dynamic> list = [];
    if (ua is List) {
      list = ua;
    } else if (ua is String) {
      try {
        final decoded = jsonDecode(ua);
        if (decoded is List) list = decoded;
      } catch (_) {}
    }
    for (final item in list) {
      if (item is! Map) continue;
      final qId = item['question_id'] ?? item['questionId'];
      if (qId?.toString() == qid.toString()) {
        final v = item['answer'] ?? item['value'] ?? item['text'] ?? '';
        return v.toString().trim();
      }
    }
    return '';
  }

  int? _extractAnswerIdFromUserAnswers(dynamic data, int qid) {
    if (data is! Map) return null;
    dynamic ua = data['user_answers'];
    List<dynamic> list = [];
    if (ua is List) {
      list = ua;
    } else if (ua is String) {
      try {
        final decoded = jsonDecode(ua);
        if (decoded is List) list = decoded;
      } catch (_) {}
    }
    for (final item in list) {
      if (item is! Map) continue;
      final qId = item['question_id'] ?? item['questionId'];
      if (qId?.toString() == qid.toString()) {
        final v = item['answer_id'] ?? item['id'];
        if (v is int) return v;
        if (v is String) {
          final parsed = int.tryParse(v);
          if (parsed != null) return parsed;
        }
      }
    }
    return null;
  }

  List<int> _extractAnswerIdsFromUserAnswers(dynamic data, int qid) {
    if (data is! Map) return [];
    dynamic ua = data['user_answers'];
    List<dynamic> list = [];
    if (ua is List) {
      list = ua;
    } else if (ua is String) {
      try {
        final decoded = jsonDecode(ua);
        if (decoded is List) list = decoded;
      } catch (_) {}
    }
    final ids = <int>[];
    for (final item in list) {
      if (item is! Map) continue;
      final qId = item['question_id'] ?? item['questionId'];
      if (qId?.toString() == qid.toString()) {
        final v = item['answer_id'];
        if (v is int) {
          ids.add(v);
        } else if (v is String) {
          final p = int.tryParse(v);
          if (p != null) ids.add(p);
        } else if (v is List) {
          for (final e in v) {
            if (e is int) ids.add(e);
            if (e is String) {
              final p = int.tryParse(e);
              if (p != null) ids.add(p);
            }
          }
        }
      }
    }
    return ids;
  }
}
