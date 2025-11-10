class HiveBoxes {
  static const String userBox = 'userBox';
  static const String chatBox = 'chatBox';
  static const String settingsBox = 'settingsBox';
}

/// Common keys stored inside boxes
class HiveKeys {
  /// Canonical token key (store RAW JWT, no "Bearer ")
  static const String authToken = 'auth_token';

  /// Legacy key some codebases used; we migrate from this if found
  static const String legacyToken = 'token';
}
