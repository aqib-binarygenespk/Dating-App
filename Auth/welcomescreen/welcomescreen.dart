import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../themesfolder/theme.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/image@2x (1).jpg'),
            fit: BoxFit.cover,
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // App Logo
              Image.asset(
                'assets/mainlogo2.png',
                width: 150,
                errorBuilder: (context, error, stackTrace) {
                  return const Text(
                    'Logo not found',
                    style: TextStyle(color: Colors.red),
                  );
                },
              ),

              const SizedBox(height: 20),

              // Login with Phone Button
              ElevatedButton(
                onPressed: () => Get.toNamed('/loginPhone'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.backgroundColor,
                  minimumSize: const Size(300, 50),
                ),
                child: const Text(
                  'Login with Phone',
                  style: TextStyle(color: Colors.black, fontSize: 18),
                ),
              ),

              const SizedBox(height: 15),

              // Login with Email Button
              ElevatedButton(
                onPressed: () => Get.toNamed('/loginEmail'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.backgroundColor,
                  minimumSize: const Size(300, 50),
                ),
                child: const Text(
                  'Login with Email',
                  style: TextStyle(color: Colors.black, fontSize: 18),
                ),
              ),

              const SizedBox(height: 15),

              // Sign-up with Phone Button
              ElevatedButton(
                onPressed: () => Get.toNamed('/signupPhone'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.backgroundColor,
                  minimumSize: const Size(300, 50),
                ),
                child: const Text(
                  'Sign-up with Phone',
                  style: TextStyle(color: Colors.black, fontSize: 18),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
