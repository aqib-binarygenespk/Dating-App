import 'package:dating_app/services/api_services.dart';

class SocialCircleService {
  /// Backend supports POST (not PUT) for /api/social-circle
  static Future<void> updateLinks({
    String? facebook,
    String? instagram,
  }) async {
    final payload = <String, dynamic>{};
    if (facebook != null && facebook.trim().isNotEmpty) {
      payload['facebook'] = facebook.trim();
    }
    if (instagram != null && instagram.trim().isNotEmpty) {
      payload['instagram'] = instagram.trim();
    }
    if (payload.isEmpty) return;

    // JSON POST; your ApiService should prepend /api/ as needed
    final res = await ApiService.postJson('social-circle', payload);

    final ok = res['success'] == true || (res['code'] ?? 200) < 400;
    if (!ok) {
      throw Exception(res['message']?.toString() ?? 'Failed to update social links');
    }
  }
}
