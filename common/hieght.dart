// A tiny utility to normalize height values for your Slider (36"–84")
class HeightParser {
  /// Parse many formats into inches:
  ///   - "5.7" (feet, one decimal)
  ///   - "6.00" (feet, two decimals)
  ///   - "6.10" (feet.inches, 10 inches)
  ///   - "72" (plain inches)
  ///   - "152", "152.4", "152 cm", "152.4cm" (centimeters)
  /// Falls back to 60" and ALWAYS clamps 36"–84".
  static double parseToInches(String raw) {
    if (raw.isEmpty) return 60.0;

    final s = raw.trim().toLowerCase();
    final cleaned = s.replaceAll('\"', '').replaceAll('in', '').replaceAll('inch', '').replaceAll('inches', '').trim();

    // If ends with cm, parse centimeters explicitly
    if (cleaned.endsWith('cm')) {
      final n = double.tryParse(cleaned.replaceAll('cm', '').trim());
      return _clampInches(n != null ? n / 2.54 : 60.0);
    }

    // Case A: feet.inches literal (e.g., 6.10, 5.09)
    final m = RegExp(r'^(\d+)\.(\d{1,2})$').firstMatch(cleaned);
    if (m != null) {
      final feet = int.tryParse(m.group(1)!);
      final inchPart = int.tryParse(m.group(2)!);
      if (feet != null && inchPart != null) {
        return _clampInches((feet * 12 + inchPart).toDouble());
      }
    }

    // Case B: numeric; decide whether feet, inches, or centimeters
    final n = double.tryParse(cleaned);
    if (n != null) {
      if (n >= 100) {
        // Likely centimeters
        return _clampInches((n / 2.54).roundToDouble());
      }
      // If it's in a plausible inches band already, accept as inches
      if (n >= 36 && n <= 96) {
        return _clampInches(n.roundToDouble());
      }
      // Otherwise treat as feet
      return _clampInches((n * 12).roundToDouble());
    }

    // Fallback
    return 60.0;
  }

  /// Format inches to "F. I" display like: 5' 9"
  static String inchesToFeetInchesLabel(double inches) {
    final total = inches.round();
    final feet = total ~/ 12;
    final inchPart = total % 12;
    return "$feet' $inchPart\"";
  }

  /// Format inches to "F.i" string (one decimal) for your API, e.g. 5.7
  static String inchesToFeetDotOne(double inches) {
    final feet = inches / 12.0;
    return feet.toStringAsFixed(1);
  }

  static double _clampInches(double v) => v.clamp(36.0, 84.0);
}
