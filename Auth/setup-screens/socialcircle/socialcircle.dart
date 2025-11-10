import 'package:dating_app/Auth/setup-screens/socialcircle/socialcirclecontroller.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:dating_app/themesfolder/theme.dart';

import '../../../themesfolder/Socialmedia.dart';


class SocialCircleSetupScreen extends StatelessWidget {
  const SocialCircleSetupScreen({super.key});

  InputDecoration _dec(String hint, IconData icon, {Widget? suffix}) {
    return InputDecoration(
      hintText: hint,
      prefixIcon: Icon(icon),
      suffixIcon: suffix,
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFEAEAEA)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFEAEAEA)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Colors.black, width: 1.4),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = Get.put(SocialCircleSetupController());
    final text = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: const SocialHeaderBar(title: 'Social Connections'),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
        child: Obx(() => SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Connect your Facebook',
                  style: text.labelLarge?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              TextField(
                controller: c.facebookCtrl,
                keyboardType: TextInputType.url,
                decoration: _dec(
                  'https://facebook.com/your.profile (optional)',
                  Icons.facebook_rounded,
                  suffix: IconButton(
                    tooltip: 'Random',
                    onPressed: c.fillRandomFacebook,
                    icon: const Icon(Icons.shuffle),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Text('Connect your Instagram',
                  style: text.labelLarge?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              TextField(
                controller: c.instagramCtrl,
                keyboardType: TextInputType.url,
                decoration: _dec(
                  'https://instagram.com/your.handle (optional)',
                  Icons.camera_alt_outlined,
                  suffix: IconButton(
                    tooltip: 'Random',
                    onPressed: c.fillRandomInstagram,
                    icon: const Icon(Icons.shuffle),
                  ),
                ),
              ),
            ],
          ),
        )),
      ),
      bottomNavigationBar: Obx(
            () => SocialBottomButton(
          text: c.isLoading.value ? 'Updating…' : 'Update',
          enabled: !c.isLoading.value && c.canSubmit.value,
          onPressed: c.submit,
        ),
      ),
    );
  }
}
