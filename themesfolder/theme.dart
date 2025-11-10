import 'package:flutter/material.dart';

class AppTheme {
  // Colors from Figma
  static const Color primaryColor = Color(0xFFFFE8E8); // Soft pink accent
  static const Color actionColor = Color(0xFF111827);  // Main dark text color
  static const Color backgroundColor = Color(0xFFFFEFEF); // Light pink background

  // Poppins TextTheme customized with Figma sizes/weights
  static const TextTheme textTheme = TextTheme(
    // 💡 Large screen headers (e.g. "Login With Email")
    displayLarge: TextStyle(
      fontFamily: 'Poppins',
      fontSize: 24,
      fontWeight: FontWeight.w600,
      color: actionColor,
    ),

    // 📌 Section titles or card titles (e.g. "Age", "About Me")
    titleLarge: TextStyle(
      fontFamily: 'Poppins',
      fontSize: 14,
      fontWeight: FontWeight.w600,
      color: actionColor,
    ),

    titleMedium : TextStyle(
      fontFamily: 'Poppins',
      fontSize: 11,
      fontWeight: FontWeight.w500,
      color: actionColor,
    ),

    titleSmall:  TextStyle(
      fontFamily: 'Poppins',      // ✅ your specified font family
      fontSize: 10,               // ✅ font size 10
      fontWeight: FontWeight.w400, // ✅ weight 400
      fontStyle: FontStyle.italic, // ✅ italic style
    ),


    // 📄 Primary content text (e.g. user profile values, chat bubbles)
    bodyLarge: TextStyle(
      fontFamily: 'Poppins',
      fontSize: 20,
      fontWeight: FontWeight.w600,
      color: actionColor,
    ),

    // 🏷️ Form labels or secondary labels
    bodyMedium: TextStyle(
      fontFamily: 'Poppins',
      fontSize: 13,
      fontWeight: FontWeight.w600,
      color: actionColor,
    ),

    // 🧾 Hints, helper texts, minor metadata
    bodySmall: TextStyle(
      fontFamily: 'Poppins',
      fontWeight: FontWeight.w400,
      fontSize: 11,
      color: Colors.black,
    ),

    // 🔘 Buttons (e.g. Apply, Login, Send)
    labelLarge: TextStyle(
      fontFamily: 'Poppins',
      fontSize: 13,
      fontWeight: FontWeight.w500,
      color: Colors.white,
    ),

    labelMedium: TextStyle(
      fontFamily: 'Poppins',
      fontSize: 9,
      fontWeight: FontWeight.w400,
      color: Colors.black,
    ),
  );

  // 🌐 App-wide ThemeData
  static ThemeData get themeData {
    return ThemeData(
      fontFamily: 'Poppins',
      scaffoldBackgroundColor: backgroundColor,
      primaryColor: primaryColor,
      textTheme: textTheme,

      appBarTheme: const AppBarTheme(
        backgroundColor: backgroundColor,
        elevation: 0,
        iconTheme: IconThemeData(color: actionColor),
        titleTextStyle: TextStyle(
          fontFamily: 'Poppins',
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: actionColor,
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        hintStyle: textTheme.bodySmall,
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: actionColor,
          foregroundColor: Colors.white,
          textStyle: textTheme.labelLarge,
          minimumSize: const Size(double.infinity, 50),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),

      cardColor: backgroundColor,
    );
  }
}
