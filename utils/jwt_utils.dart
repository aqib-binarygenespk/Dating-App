// lib/utils/jwt_utils.dart
import 'dart:convert';

class JwtUtils {
  /// Returns the numeric user id from a standard JWT "sub" claim, or null.
  static int? tryExtractUserId(String? jwt) {
    if (jwt == null || jwt.isEmpty) return null;
    final parts = jwt.split('.');
    if (parts.length != 3) return null;
    try {
      final payload = _decodeBase64Url(parts[1]);
      final map = json.decode(payload);
      final sub = map['sub'];
      if (sub == null) return null;
      if (sub is int) return sub > 0 ? sub : null;
      final parsed = int.tryParse(sub.toString());
      return (parsed != null && parsed > 0) ? parsed : null;
    } catch (_) {
      return null;
    }
  }

  static String _decodeBase64Url(String input) {
    // Add padding if missing
    String s = input.replaceAll('-', '+').replaceAll('_', '/');
    while (s.length % 4 != 0) {
      s += '=';
    }
    return utf8.decode(base64.decode(s));
  }
}
