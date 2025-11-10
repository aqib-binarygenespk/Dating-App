// lib/services/profile_answers_service.dart
import 'package:hive/hive.dart';
import 'package:dating_app/hive_utils/hive_boxes.dart';
import 'package:dating_app/services/api_services.dart';

/// Caches { question_id: answer_id } from /profile (user_answers)
class ProfileAnswersService {
  static Map<int, int>? _cache;

  /// Internal loader with optional cache-bust
  static Future<Map<int, int>> _load({bool bustCache = false}) async {
    if (!bustCache && _cache != null) return _cache!;

    final token = Hive.box(HiveBoxes.userBox).get('auth_token');

    // 🔥 Bust any CDN/app cache by appending a timestamp query
    final ts = DateTime.now().millisecondsSinceEpoch;
    final res = await ApiService.get('profile?cb=$ts', token: token);

    final map = <int, int>{};
    final ua = res['data']?['user_answers'] as List? ?? const [];

    for (final raw in ua) {
      final qidStr = raw['question_id']?.toString();
      final aidStr = raw['answer_id']?.toString();
      final qid = int.tryParse(qidStr ?? '');
      final aid = int.tryParse(aidStr ?? '');
      if (qid != null && aid != null) map[qid] = aid;
    }

    _cache = map;
    return map;
  }

  /// Public: force a fresh pull from server (use after updates)
  static Future<void> refreshFromServer() async {
    await _load(bustCache: true);
  }

  static Future<int?> getAnswerId(int questionId) async {
    final map = await _load();
    return map[questionId];
  }

  /// Keep local cache in sync for instant UI preselects
  static void setAnswerId(int questionId, int answerId) {
    (_cache ??= <int, int>{})[questionId] = answerId;
  }

  static void invalidate() => _cache = null;
}
