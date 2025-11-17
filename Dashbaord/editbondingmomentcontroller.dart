import 'dart:convert';
import 'package:get/get.dart';
import 'package:hive/hive.dart';

import '../../../../../hive_utils/hive_boxes.dart';
import '../../../../../services/api_services.dart';
import '../../../../profile/profile_controller.dart';
import '../../editprofilecontroller.dart';

/// Use the SAME nested navigator id you used to push this screen:
/// await Get.to(() => const EditBondingMomentsScreen(), id: settingsNavId);
const int settingsNavId = 1; // If defined elsewhere, delete this and import it.

class EditBondingMomentsController extends GetxController {
  /// JSON order mapping (matches your categories.json exactly):
  /// 0..13 => [9,19,20,21,22,23,24,25,26,27,28,29,30,31]
  final List<int?> qidMap = const [
    9,   // 0  Friday night in... | Exploring restaurants...
    19,  // 1  Running a marathon... | Grabbing brunch...
    20,  // 2  Cozy movie marathon | Outdoor movie night...
    21,  // 3  Camper adventures | Glamping experiences
    22,  // 4  Downtown apartment | Big house in suburbs
    23,  // 5  Poolside | Ocean dip
    24,  // 6  Cooking at home | Dining out
    25,  // 7  Wine tasting | Local breweries
    26,  // 8  Road trip | Airport lounge
    27,  // 9  Fall asleep w/ TV | Blissful silence
    28,  // 10 Campfire | Room service
    29,  // 11 Live music | Music at home
    30,  // 12 Cocktails | Mocktails
    31,  // 13 Dog play date | Kid play date
  ];

  late final Map<int, int> _qidToRow = {
    for (int i = 0; i < qidMap.length; i++) if (qidMap[i] != null) qidMap[i]!: i,
  };

  /// Only render rows that map to backend questions
  late final List<int> visibleRowIndices =
  List<int>.generate(qidMap.length, (i) => i).where((i) => qidMap[i] != null).toList();

  /// UI options (same order/length as qidMap)
  final List<List<String>> bondingOptions = const [
    ['Friday night in with a homemade meal', 'Exploring restaurants and bars'],              // 0 -> 9
    ['Running a marathon on a Sunday', 'Grabbing brunch with your boo'],                    // 1 -> 19
    ['Cozy movie marathon', 'Outdoor movie night under the stars'],                         // 2 -> 20
    ['Camper adventures', 'Glamping experiences'],                                          // 3 -> 21
    ['Living in a downtown apartment', 'Living in a big house in the suburbs'],             // 4 -> 22
    ['On a sunny day, lounging poolside', 'On a sunny day, taking a dip in the ocean'],     // 5 -> 23
    ['Cooking at home together', 'Dining out for a culinary adventure'],                    // 6 -> 24
    ['Wine tasting tour', 'Visiting local breweries for beer tasting'],                     // 7 -> 25
    ['Road trip explorations', 'Relaxing in an airport lounge'],                            // 8 -> 26
    ['Fall asleep cuddling with a TV on', 'Fall asleep cuddling in blissful silence'],      // 9 -> 27
    ['Cooking over a campfire', 'Enjoying the luxury of room service'],                     // 10 -> 28
    ['Live music in the open air', 'Enjoying music at home'],                               // 11 -> 29
    ['Connecting over cocktails', 'Connecting over mocktails'],                             // 12 -> 30
    ['Taking your dog on a play date', 'Organizing a kid play date'],                       // 13 -> 31
  ];

  /// key = rowIndex (0..13), value = selected option text or null
  final selectedOptions = <int, String?>{}.obs;

  int get selectedCount =>
      selectedOptions.values.where((v) => v?.trim().isNotEmpty ?? false).length;

  final isLoading = false.obs;
  bool _prefillInProgress = false;

  // ---- Local cache (Hive) so we can show the last submitted picks immediately
  static const _cacheKey = 'bonding_moments_cache'; // Map<String userKey, Map<qid,int aId>>
  String get _userKey {
    final box = Hive.box(HiveBoxes.userBox);
    return (box.get('user_id')?.toString() ??
        box.get('token')?.toString() ??
        box.get('auth_token')?.toString() ??
        'default');
  }

  EditProfileController get _editController =>
      Get.isRegistered<EditProfileController>()
          ? Get.find<EditProfileController>()
          : Get.put(EditProfileController());

  ProfileController get _profileController =>
      Get.isRegistered<ProfileController>()
          ? Get.find<ProfileController>()
          : Get.put(ProfileController());

  @override
  void onInit() {
    super.onInit();
    refreshFromServer();
  }

  @override
  void onClose() {
    _prefillInProgress = false;
    super.onClose();
  }

  Future<void> refreshFromServer() async {
    if (_prefillInProgress) return;
    _prefillInProgress = true;

    _prefillFromCache();
    await _prefillSelectionsFromApi();

    _prefillInProgress = false;
  }

  void _prefillFromCache() {
    try {
      final box = Hive.box(HiveBoxes.userBox);
      final raw = box.get(_cacheKey);
      if (raw is Map && raw[_userKey] is Map) {
        final map = Map<String, dynamic>.from(raw[_userKey] as Map);
        map.forEach((k, v) {
          final qId = int.tryParse(k);
          final aId = _toAnswerId(v);
          if (qId == null || !_qidToRow.containsKey(qId) || !_validA(aId)) return;
          final row = _qidToRow[qId]!;
          selectedOptions[row] = bondingOptions[row][aId! - 1];
        });
        selectedOptions.refresh();
      }
    } catch (_) {/* ignore */}
  }

  Future<void> _prefillSelectionsFromApi() async {
    final token = Hive.box(HiveBoxes.userBox).get('auth_token') ??
        Hive.box(HiveBoxes.userBox).get('token');
    if (token == null || (token is String && token.isEmpty)) return;

    try {
      final resp = await ApiService.get('profile', token: token);
      final root = (resp['data'] ?? resp) as Map<String, dynamic>;

      final picks = <int, int>{}; // qId -> aId(1/2)

      if (root['bonding_moments'] is List) {
        for (final e in (root['bonding_moments'] as List)) {
          if (e is! Map) continue;
          final qId = _asInt(e['question_id'] ?? e['qid']);
          if (qId == null || !_qidToRow.containsKey(qId)) continue;
          final row = _qidToRow[qId]!;

          // Prefer label match
          final label = _extractLabelForRow(row, e);
          if (label != null) {
            final idx = bondingOptions[row].indexOf(label);
            if (idx != -1) {
              picks[qId] = idx + 1;
              continue;
            }
          }

          final aId = _toAnswerId(e['answer_id'] ?? e['answer'] ?? e['side']);
          if (_validA(aId)) picks[qId] = aId!;
        }
      }

      // Fallback: search user_answers / answers
      if (picks.isEmpty) {
        final ua = _extractPairsFromUserAnswers(root); // qId->aId
        picks.addAll(ua);
      }

      if (picks.isNotEmpty) {
        selectedOptions.clear();
        picks.forEach((qId, aId) {
          final row = _qidToRow[qId]!;
          selectedOptions[row] = bondingOptions[row][aId - 1];
        });
        selectedOptions.refresh();
        _writeCache(picks);
      }
    } catch (_) {
      // ignore; keep cache/UI
    }
  }

  void _writeCache(Map<int, int> picks) {
    try {
      final box = Hive.box(HiveBoxes.userBox);
      final raw =
          (box.get(_cacheKey) as Map?)?.map((k, v) => MapEntry(k.toString(), v)) ?? {};
      final userMap = <String, int>{
        for (final e in picks.entries) e.key.toString(): e.value
      };
      raw[_userKey] = userMap;
      box.put(_cacheKey, raw);
    } catch (_) {/* ignore */}
  }

  // ─── UI actions ───

  void toggleSelection(int rowIndex, String option) {
    final current = selectedOptions[rowIndex];
    if (current == option) {
      selectedOptions[rowIndex] = null; // deselect
    } else {
      // No max cap: user can pick as many rows as they want
      selectedOptions[rowIndex] = option;
    }
    selectedOptions.refresh();
  }

  Future<void> submitUpdate() async {
    final picks = selectedOptions.entries
        .where((e) => (e.value?.trim().isNotEmpty ?? false))
        .toList();

    // MIN 3, allow more
    if (picks.length < 3) {
      Get.snackbar('Incomplete', 'Please select at least 3 bonding moments.');
      return;
    }

    final answers = <Map<String, dynamic>>[];
    final cacheMap = <int, int>{};

    for (final e in picks) {
      final row = e.key;
      final label = e.value!.trim();
      final sideIdx = bondingOptions[row].indexOf(label); // 0/1
      if (sideIdx < 0) continue;

      final qid = qidMap[row]!;
      final ansId = sideIdx + 1; // 1 or 2
      answers.add({"question_id": qid, "answer_id": ansId});
      cacheMap[qid] = ansId;
    }

    if (answers.isEmpty) {
      Get.snackbar('Error', 'Please make a valid selection.');
      return;
    }

    isLoading.value = true;
    try {
      await _editController.updateProfile(answers);
      _writeCache(cacheMap);

      if (Get.isRegistered<ProfileController>()) {
        await _profileController.fetchProfile(); // <-- refresh profile on success
      }

      Get.snackbar('Success', 'Bonding moments updated.');
      Get.back(id: settingsNavId, result: true);
    } catch (e) {
      Get.snackbar('Error', 'Update failed. Please try again.');
    } finally {
      isLoading.value = false;
    }
  }

  // ─── helpers ───

  bool _validA(int? a) => a != null && (a == 1 || a == 2);

  int? _toAnswerId(dynamic v) {
    if (v == null) return null;
    if (v is int) return (v == 1 || v == 2) ? v : null;
    final s = v.toString().trim().toLowerCase();
    if (s == '1' || s == 'left') return 1;
    if (s == '2' || s == 'right') return 2;
    return null;
  }

  String? _extractLabelForRow(int row, Map obj) {
    final candidates = <dynamic>[
      obj['answer_label'],
      obj['answer_text'],
      obj['answerTitle'],
      obj['label'],
      obj['value'],
    ];
    final ans = obj['answer'];
    if (ans is String && ans.trim().isNotEmpty) {
      final lc = ans.trim().toLowerCase();
      if (lc != 'left' && lc != 'right' && lc != '1' && lc != '2') {
        candidates.add(ans);
      }
    }
    for (final c in candidates) {
      if (c == null) continue;
      final s = c.toString().trim();
      if (s.isEmpty) continue;
      final idx = bondingOptions[row].indexOf(s);
      if (idx != -1) return s;
    }
    return null;
  }

  Map<int, int> _extractPairsFromUserAnswers(Map<String, dynamic> root) {
    final out = <int, int>{};
    dynamic ua = root['user_answers'] ?? root['answers'];
    List list = [];
    if (ua is List) list = ua;
    if (ua is String) {
      try {
        final d = jsonDecode(ua);
        if (d is List) list = d;
      } catch (_) {}
    }
    for (final item in list) {
      if (item is! Map) continue;
      final qId = int.tryParse('${item['question_id'] ?? item['questionId'] ?? ''}');
      if (qId == null || !_qidToRow.containsKey(qId)) continue;

      final row = _qidToRow[qId]!;
      final label = _extractLabelForRow(row, item);
      if (label != null) {
        final idx = bondingOptions[row].indexOf(label);
        if (idx != -1) {
          out[qId] = idx + 1;
          continue;
        }
      }
      int? aId = _toAnswerId(
          item['answer_id'] ?? item['answerId'] ?? item['value'] ?? item['selected']);
      if (aId == null && item['answer'] is String) {
        final idx = bondingOptions[row].indexOf((item['answer'] as String).trim());
        if (idx >= 0) aId = idx + 1;
      }
      if (_validA(aId)) out[qId] = aId!;
    }
    return out;
  }

  int? _asInt(dynamic v) => v is int ? v : int.tryParse(v?.toString() ?? '');
}
