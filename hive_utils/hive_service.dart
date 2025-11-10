import 'package:hive/hive.dart';
import 'hive_boxes.dart';

class HiveService {
  // ------------------------------
  // Box open helper (avoids re-opening)
  // ------------------------------
  static Future<Box> openBox(String boxName) async {
    if (Hive.isBoxOpen(boxName)) return Hive.box(boxName);
    return await Hive.openBox(boxName);
  }

  // ------------------------------
  // Generic KV helpers (compatible with your current API)
  // ------------------------------
  static Future<void> saveData(String boxName, String key, dynamic value) async {
    final box = await openBox(boxName);
    await box.put(key, value);
  }

  static Future<dynamic> getData(String boxName, String key) async {
    final box = await openBox(boxName);
    return box.get(key);
  }

  static Future<void> deleteData(String boxName, String key) async {
    final box = await openBox(boxName);
    await box.delete(key);
  }

  static Future<void> clearBox(String boxName) async {
    final box = await openBox(boxName);
    await box.clear();
  }

  static Future<bool> containsKey(String boxName, String key) async {
    final box = await openBox(boxName);
    return box.containsKey(key);
  }

  // ------------------------------
  // TOKEN HELPERS (use these in controllers/services)
  // ------------------------------

  /// Save RAW JWT (no "Bearer ") under the canonical key.
  static Future<void> setToken(String token) async {
    final box = await openBox(HiveBoxes.userBox);
    var t = token.trim();
    if (t.startsWith('Bearer ')) t = t.substring(7).trim(); // strip any prefix
    await box.put(HiveKeys.authToken, t);

    // Optional: clean legacy key to avoid confusion
    if (box.containsKey(HiveKeys.legacyToken)) {
      await box.delete(HiveKeys.legacyToken);
    }
  }

  /// Get RAW JWT (no "Bearer ") from canonical key.
  /// Falls back to legacy key ('token') and migrates it forward.
  static Future<String?> getToken() async {
    final box = await openBox(HiveBoxes.userBox);

    String? raw = box.get(HiveKeys.authToken) as String?;
    if (raw == null || raw.toString().trim().isEmpty) {
      // Try legacy then migrate
      final legacy = box.get(HiveKeys.legacyToken);
      if (legacy != null) {
        var t = legacy.toString().trim();
        if (t.startsWith('Bearer ')) t = t.substring(7).trim();
        if (t.isNotEmpty) {
          await box.put(HiveKeys.authToken, t);
          await box.delete(HiveKeys.legacyToken);
          raw = t;
        }
      }
    }

    if (raw == null) return null;
    var t = raw.toString().trim();
    if (t.startsWith('Bearer ')) t = t.substring(7).trim(); // normalize if stored with prefix
    return t.isEmpty ? null : t;
  }

  /// Standard auth headers (prevents double "Bearer")
  static Future<Map<String, String>?> getAuthHeaders() async {
    final token = await getToken();
    if (token == null) return null;
    return {
      'Authorization': 'Bearer $token',
      'Accept': 'application/json',
    };
  }

  /// Remove only token keys (keep other userBox data)
  static Future<void> clearToken() async {
    final box = await openBox(HiveBoxes.userBox);
    if (box.containsKey(HiveKeys.authToken)) await box.delete(HiveKeys.authToken);
    if (box.containsKey(HiveKeys.legacyToken)) await box.delete(HiveKeys.legacyToken);
  }

  /// Full sign-out: wipes entire userBox
  static Future<void> clearSession() async {
    await clearBox(HiveBoxes.userBox);
  }
}
