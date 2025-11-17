import 'package:dating_app/Dashbaord/settingspages/profilesettings/editprofile/updatesocialmedia/updatesocialmediacontroller.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:dating_app/themesfolder/theme.dart';
import '../../../../../themesfolder/Socialmedia.dart'; // your SocialHeaderBar + SocialBottomButton



class SocialCircleUpdateScreen extends StatelessWidget {
  const SocialCircleUpdateScreen({super.key});

  InputDecoration _dec(String hint, IconData icon, {Widget? suffix}) {
    return InputDecoration(
      hintText: hint,
      prefixIcon: Icon(icon),
      suffixIcon: suffix,
      filled: true,
      fillColor: AppTheme.backgroundColor,
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
    final c = Get.put(SocialCircleUpdateController());
    final text = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: const SocialHeaderBar(title: 'Social Connections'),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
        // ❌ Obx removed here (no Rx used inside the body tree)
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Connect your Facebook',
                  style: text.bodyMedium?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              TextField(
                controller: c.facebookCtrl,
                keyboardType: TextInputType.url,
                decoration: _dec(
                  'https://facebook.com/your.profile (optional)',
                  Icons.facebook_rounded,
                  suffix: IconButton(
                    tooltip: 'Random',
                    onPressed: c.randomFacebook,
                    icon: const Icon(Icons.shuffle),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Text('Connect your Instagram',
                  style: text.bodyMedium?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              TextField(
                controller: c.instagramCtrl,
                keyboardType: TextInputType.url,
                decoration: _dec(
                  'https://instagram.com/your.handle (optional)',
                  Icons.camera_alt_outlined,
                  suffix: IconButton(
                    tooltip: 'Random',
                    onPressed: c.randomInstagram,
                    icon: const Icon(Icons.shuffle),
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
      // ✅ Keep Obx here; it observes isLoading & canSubmit
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

