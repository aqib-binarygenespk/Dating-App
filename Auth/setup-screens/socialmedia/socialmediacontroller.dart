import 'dart:math';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../../services/social_circleservice.dart';
import '../../../Dashbaord/profile/profile_controller.dart';

class SocialCircleSetupController extends GetxController {
  final facebookCtrl = TextEditingController();
  final instagramCtrl = TextEditingController();

  // Keep as Rx if you also use them elsewhere, but UI will rebuild via GetBuilder('btn')
  final isLoading = false.obs;
  final canSubmit = false.obs;

  // random handle generator
  final _rng = Random();
  static const _adjs = ['sunny','cosmic','urban','wild','chill','golden','cozy','vivid','swift','lucky'];
  static const _nouns = ['explorer','panda','tiger','vibes','galaxy','wanderer','artist','ninja','coder','phoenix'];

  String _handle() {
    final a = _adjs[_rng.nextInt(_adjs.length)];
    final n = _nouns[_rng.nextInt(_nouns.length)];
    final num = 100 + _rng.nextInt(899);
    return '$a\_$n$num';
  }

  void fillRandomFacebook() {
    facebookCtrl.text = 'https://facebook.com/${_handle()}';
    _recomputeSubmit();
  }

  void fillRandomInstagram() {
    instagramCtrl.text = 'https://instagram.com/${_handle()}';
    _recomputeSubmit();
  }

  void _recomputeSubmit() {
    final next = facebookCtrl.text.trim().isNotEmpty || instagramCtrl.text.trim().isNotEmpty;
    if (next != canSubmit.value) {
      canSubmit.value = next;
      update(['btn']); // 🔔 rebuild button only
    }
  }

  @override
  void onInit() {
    super.onInit();
    // optional test prefills — comment out if you don’t want them during setup
    // fillRandomFacebook();
    // fillRandomInstagram();

    facebookCtrl.addListener(_recomputeSubmit);
    instagramCtrl.addListener(_recomputeSubmit);
    _recomputeSubmit();
  }

  @override
  void onClose() {
    facebookCtrl.dispose();
    instagramCtrl.dispose();
    super.onClose();
  }

  Future<void> submit() async {
    if (!canSubmit.value || isLoading.value) return;

    isLoading.value = true;
    update(['btn']); // show "Updating…" & disable

    try {
      await SocialCircleService.updateLinks(
        facebook: facebookCtrl.text.trim().isEmpty ? null : facebookCtrl.text.trim(),
        instagram: instagramCtrl.text.trim().isEmpty ? null : instagramCtrl.text.trim(),
      );

      if (Get.isRegistered<ProfileController>()) {
        await Get.find<ProfileController>().fetchProfile();
      }

      Get.snackbar('Saved', 'Social links added');
      // Continue setup flow here if needed, e.g.:
      // Get.to(() => NextSetupScreen());
    } catch (e) {
      Get.snackbar('Error', e.toString());
    } finally {
      isLoading.value = false;
      update(['btn']); // restore button
    }
  }
}
