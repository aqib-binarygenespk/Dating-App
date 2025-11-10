import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../../themesfolder/theme.dart';
import '../socialcircle/socialcirclecontroller.dart';

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
      appBar: AppBar(
        title: const Text('Social Connections'),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.black,
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Connect your Facebook', style: text.labelLarge?.copyWith(fontWeight: FontWeight.w700)),
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
              Text('Connect your Instagram', style: text.labelLarge?.copyWith(fontWeight: FontWeight.w700)),
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
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: GetBuilder<SocialCircleSetupController>(
          id: 'btn', // only this area rebuilds
          builder: (x) {
            final loading = x.isLoading.value;
            final enabled = x.canSubmit.value && !loading;
            return SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: enabled ? x.submit : null,
                style: ElevatedButton.styleFrom(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: Text(loading ? 'Updating…' : 'Save & Continue'),
              ),
            );
          },
        ),
      ),
    );
  }
}
