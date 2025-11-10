import 'package:flutter/material.dart';
import 'package:animate_do/animate_do.dart';
import 'dart:async';
import 'package:dating_app/themesfolder/theme.dart';
import 'package:dating_app/Auth/welcomescreen/welcomescreen.dart';
import 'package:hive/hive.dart';
import 'package:dating_app/hive_utils/hive_boxes.dart';
import 'package:dating_app/Dashbaord/dashboard/Dashboard.dart';
import 'package:dating_app/hive_utils/hive_service.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();

    // Small splash delay, then route based on token presence
    Timer(const Duration(seconds: 3), _routeNext);
  }

  Future<void> _routeNext() async {
    // Try Hive first
    String? token;
    try {
      final box = Hive.box(HiveBoxes.userBox);
      token = (box.get('auth_token') ??
          box.get('token') ??
          box.get('access_token'))
          ?.toString();
    } catch (_) {}

    // Try HiveService helper as well (your ApiService relies on it)
    try {
      token ??= await HiveService.getToken();
    } catch (_) {}

    final hasToken = token != null && token.trim().isNotEmpty;

    if (!mounted) return;
    if (hasToken) {
      // User stays logged in across app restarts
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const DashboardScreen()),
      );
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const WelcomeScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            FadeInDown(
              duration: const Duration(milliseconds: 19000),
              child: Image.asset(
                'assets/splash_logo.png', // 🖼 Make sure this image matches your dark logo (transparent background)
                height: 160,
                fit: BoxFit.contain,
              ),
            ),
            const SizedBox(height: 10),
            FadeInUp(
              duration: const Duration(milliseconds: 1600),
              child: const Text(
                'Finding your perfect match...',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 12,
                  fontWeight: FontWeight.w400,
                  color: Colors.black54,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
