import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hive/hive.dart';
import '../../hive_utils/hive_boxes.dart';
import '../../services/api_services.dart';

void showLogoutConfirm(BuildContext context) {
  const heading = Color(0xFF111827);
  const body = Color(0xFF6B7280);
  const stroke = Color(0xFFE5E7EB);
  const bubble = Color(0xFFFFEEF1); // soft pink like the design

  final width = MediaQuery.of(context).size.width;
  final cardWidth = width > 360 ? 320.0 : width * 0.86;

  Get.dialog(
    Center(
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: cardWidth,
          padding: const EdgeInsets.fromLTRB(20, 22, 20, 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: stroke, width: 1),
            boxShadow: const [
              BoxShadow(
                color: Color(0x1A000000),
                blurRadius: 24,
                offset: Offset(0, 12),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Badge
              Container(
                width: 64,
                height: 64,
                decoration: const BoxDecoration(
                  color: bubble,
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: Icon(Icons.logout_rounded, size: 30, color: heading),
                ),
              ),
              const SizedBox(height: 14),

              // Title
              const Text(
                'Are You Sure?',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: heading,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.2,
                ),
              ),
              const SizedBox(height: 8),

              // Description
              const Text(
                'This action will sign you out and take you to the welcome screen.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: body,
                  fontSize: 14,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 20),

              // Actions
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Get.back(),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: stroke, width: 1),
                        foregroundColor: heading,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () async {
                        Get.back(); // close confirm dialog
                        await _performLogout();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: heading,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: const Text('Confirm Logout'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ),
    barrierDismissible: false,
    barrierColor: Colors.black.withOpacity(0.35),
  );
}

Future<void> _performLogout() async {
  // Optional: small loading overlay
  Get.dialog(const Center(child: CircularProgressIndicator()), barrierDismissible: false);

  final box = Hive.box(HiveBoxes.userBox);
  final token = box.get('auth_token')?.toString();

  try {
    if (token != null && token.isNotEmpty) {
      // Your Postman screenshot shows POST /api/logout with Bearer token
      await ApiService.post('logout', const {}, token: token, isJson: true);
    }
  } catch (_) {
    // swallow; we still clear locally
  } finally {
    await box.clear();

    if (Get.isDialogOpen == true) Get.back(); // close loader

    // Navigate to welcome / landing
    Get.offAllNamed('/Welcome');

    // Optional toast
    Get.snackbar('Logged out', 'You have been logged out.');
  }
}
