// lib/utils/phone_fmt.dart
class PhoneFmt {
  /// Returns E.164-like phone: +[country][national], or null if invalid.
  /// Uses an existing account phone (E.164) to infer country code when possible.
  static String? canonical(String input, {String? accountPhone}) {
    final raw = input.trim();
    if (raw.isEmpty) return null;

    final acctCC = _extractCountryCode(accountPhone);

    if (raw.startsWith('+')) {
      final digits = raw.replaceAll(RegExp(r'[^\d+]'), '');
      return _looksLikeE164(digits) ? digits : null;
    }

    if (raw.startsWith('00')) {
      final d = raw.replaceFirst('00', '+').replaceAll(RegExp(r'[^\d+]'), '');
      return _looksLikeE164(d) ? d : null;
    }

    final justDigits = raw.replaceAll(RegExp(r'\D'), '');
    if (justDigits.isEmpty) return null;

    if (acctCC == null) return null; // require user to enter +CC... if we can't infer

    final national = justDigits.replaceFirst(RegExp(r'^0+'), '');
    final candidate = '+$acctCC$national';
    return _looksLikeE164(candidate) ? candidate : null;
  }

  static bool _looksLikeE164(String s) =>
      RegExp(r'^\+[1-9]\d{1,14}$').hasMatch(s); // backend regex

  static String? _extractCountryCode(String? acct) {
    if (acct == null || acct.isEmpty) return null;
    final m = RegExp(r'^\+([1-9]\d{1,3})').firstMatch(acct.replaceAll(' ', ''));
    return m?.group(1);
  }
}
