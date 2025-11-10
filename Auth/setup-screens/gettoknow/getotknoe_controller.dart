import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import 'package:get/get.dart';
import 'package:hive/hive.dart';

import '../../../Dashbaord/profile/profile_controller.dart';
import '../../../hive_utils/hive_boxes.dart';
import '../../../services/api_services.dart';


class GetToKnowMeController extends GetxController {
  final bool fromEdit;
  GetToKnowMeController({this.fromEdit = false});

  // ----- UI state -----
  final RxInt selectedIndex = (-1).obs; // 0..7
  final RxBool isLoading = false.obs;
  final RxString responseMessage = ''.obs;
  final RxBool isSuccess = false.obs;

  // UI text (order must match backend display_order)
  final List<String> prompts = const [
    "Why do you think meeting in a group is better than a one-on-one first hangout?",
    "What’s your favorite way to spend a weekend with friends?",
    "How do you make new people feel welcome when hanging out in a group?",
    "What’s a shared activity you think is perfect for a first meetup?",
    "Describe your ideal group outing or hangout.",
    "What’s your go-to game or activity for breaking the ice with new friends?",
    "If you could plan the ultimate friend + date night, what would it look like?",
    "What’s a fun fact about you that people might not guess?",
  ];

  // ----- categories.json derived -----
  static const int _expectedQuestionId = 6;

  // Fallback backend IDs if categories.json missing/misconfigured
  static const List<int> _fallbackAnswerIds = [64, 65, 66, 67, 68, 69, 70, 71];

  final _questionId = RxnInt();
  List<Map<String, dynamic>> _answerOptions = <Map<String, dynamic>>[];
  bool _metaLoaded = false;
  bool _usedFallback = false;

  @override
  void onInit() {
    super.onInit();
    _loadMetaFromAssets(); // fire-and-forget; submit will await if needed
  }

  void selectPrompt(int? index) {
    if (index != null && index >= 0 && index < prompts.length) {
      selectedIndex.value = index;
    }
  }

  Future<void> submitPrompt() async {
    if (selectedIndex.value < 0) {
      responseMessage.value = "Please select a prompt to continue.";
      isSuccess.value = false;
      return;
    }

    final token = _getToken();
    if (token == null || token.isEmpty) {
      responseMessage.value = "Missing token. Please log in again.";
      isSuccess.value = false;
      return;
    }

    isLoading.value = true;
    responseMessage.value = "";

    // Ensure meta ready; if not, (re)load
    if (!_metaLoaded || _answerOptions.isEmpty) {
      await _loadMetaFromAssets();
    }

    final int? answerId = _answerIdForSelectedIndex(selectedIndex.value);
    if (answerId == null) {
      isLoading.value = false;
      isSuccess.value = false;
      responseMessage.value =
      'Could not resolve the selected prompt to an answer_id. Please try again.';
      return;
    }

    try {
      // Setup flow endpoint expects only { answer_id }
      final resp = await ApiService.post(
        "get-to-know-me",
        {"answer_id": answerId},
        token: token,
        isJson: true,
      );

      isLoading.value = false;

      final success = (resp['success'] == true) || (resp['success']?.toString() == 'true');
      if (success) {
        isSuccess.value = true;
        responseMessage.value = resp['message'] ?? " ";

        final profileController = _getOrCreate<ProfileController>(() => ProfileController());
        await profileController.fetchProfile();

        if (fromEdit) {
          Get.snackbar("Success", "Get To Know Me updated");
          Get.back(result: true);
        } else {
          Get.snackbar("Success", responseMessage.value);
          // continue setup flow
          await Future.delayed(const Duration(milliseconds: 600));
          Get.toNamed('/recordvideo');
        }
      } else {
        isSuccess.value = false;
        responseMessage.value = resp['message'] ?? "Submission failed.";
      }
    } catch (e) {
      isLoading.value = false;
      isSuccess.value = false;
      responseMessage.value = "An unexpected error occurred.";
      Get.log('[GetToKnowMeController] submitPrompt error: $e');
    }
  }

  // ---------------- helpers ----------------

  Future<void> _loadMetaFromAssets() async {
    if (_metaLoaded) return;

    try {
      final jsonStr = await rootBundle.loadString('assets/categories.json');
      final dynamic data = json.decode(jsonStr);

      // categories can be a top-level list or under { "categories": [...] }
      final List<dynamic> categories = data is List
          ? List<dynamic>.from(data)
          : (data is Map && data['categories'] is List
          ? List<dynamic>.from(data['categories'])
          : const <dynamic>[]);

      Map<String, dynamic>? targetCategory;

      // Accept "Get To Know Me", "Get-To-Know-Me", and "Get to Know Me Clip"
      for (final raw in categories) {
        if (raw is! Map) continue;
        final cat = Map<String, dynamic>.from(raw as Map);
        final title = (cat['title'] ?? '').toString();
        final t = _norm(title);
        if (t == 'gettoknowme' ||
            t == 'get-to-know-me' ||
            t == 'gett0knowme' || // defensive
            t == 'gettoknowmeclip' ||
            t == 'get-to-know-me-clip' ||
            t == 'gett o know me clip' || // defensive spacing
            t == 'get to know me clip') {
          targetCategory = cat;
          break;
        }
      }

      if (targetCategory == null) {
        Get.log('[GetToKnowMeController] Category not found; using fallback IDs.');
        _applyFallback();
        return;
      }

      final List<dynamic> questionsDyn = (targetCategory['questions'] as List?) ?? const [];
      if (questionsDyn.isEmpty || questionsDyn.first is! Map) {
        Get.log('[GetToKnowMeController] Target category has no questions; using fallback IDs.');
        _applyFallback();
        return;
      }

      final Map<String, dynamic> q = Map<String, dynamic>.from(questionsDyn.first as Map);
      final dynamic qidDynamic = q['id'] ?? q['question_id'];
      _questionId.value = qidDynamic is int ? qidDynamic : int.tryParse('$qidDynamic');

      // Not critical for setup endpoint, but log if mismatch
      if (_questionId.value != null && _questionId.value != _expectedQuestionId) {
        Get.log('[GetToKnowMeController] Warning: expected question_id=$_expectedQuestionId, got ${_questionId.value}');
      }

      final List<dynamic> answersDyn = (q['answers'] as List?) ?? const [];
      var opts = answersDyn
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();

      if (opts.isEmpty) {
        Get.log('[GetToKnowMeController] No answers found; using fallback IDs.');
        _applyFallback();
        return;
      }

      // Sort by display_order to align with UI order
      opts.sort((a, b) {
        final ad = (a['display_order'] is int)
            ? a['display_order'] as int
            : int.tryParse('${a['display_order']}') ?? 0;
        final bd = (b['display_order'] is int)
            ? b['display_order'] as int
            : int.tryParse('${b['display_order']}') ?? 0;
        return ad.compareTo(bd);
      });

      _answerOptions = opts;
      _metaLoaded = true;
      _usedFallback = false;
    } catch (e) {
      Get.log('[GetToKnowMeController] Failed to load categories.json ($e); using fallback IDs.');
      _applyFallback();
    }
  }

  void _applyFallback() {
    _answerOptions = List.generate(_fallbackAnswerIds.length, (i) {
      return {
        "id": _fallbackAnswerIds[i],
        "label": prompts[i],
        "value": _norm(prompts[i]),
        "display_order": i + 1,
      };
    });
    _metaLoaded = true;
    _usedFallback = true;
  }

  /// Resolve the answer_id by selected index; fallback to text match if sizes differ.
  int? _answerIdForSelectedIndex(int index) {
    // 1) index-based (preferred when JSON answers align with UI order)
    if (index >= 0 && index < _answerOptions.length) {
      final idDyn = _answerOptions[index]['id'];
      final id = (idDyn is int) ? idDyn : int.tryParse('$idDyn');
      if (id != null) return id;
    }

    // 2) text-based fallback (match prompt text to label/value)
    if (index >= 0 && index < prompts.length && _answerOptions.isNotEmpty) {
      final selectedText = _norm(prompts[index]);
      for (final a in _answerOptions) {
        final label = _norm((a['label'] ?? '').toString());
        final value = _norm((a['value'] ?? '').toString());
        if (label == selectedText || value == selectedText) {
          final idDyn = a['id'];
          final id = (idDyn is int) ? idDyn : int.tryParse('$idDyn');
          if (id != null) return id;
        }
      }
    }
    return null;
  }

  String _getToken() {
    final box = Hive.box(HiveBoxes.userBox);
    final dynamic tok = box.get('auth_token') ?? box.get('token') ?? box.get('access_token');
    return (tok is String) ? tok : (tok?.toString() ?? '');
  }

  T _getOrCreate<T>(T Function() create) {
    try {
      return Get.find<T>();
    } catch (_) {
      return Get.put<T>(create());
    }
  }

  String _norm(String s) {
    // normalize text heavily: lower, remove whitespace, hyphens/underscores, punctuation (incl. curly quotes)
    final lower = s.trim().toLowerCase();
    final removedPunct = lower.replaceAll(RegExp(r"[^\p{L}\p{N}]+", unicode: true), "");
    return removedPunct;
  }
}
