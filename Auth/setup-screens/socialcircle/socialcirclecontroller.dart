import 'dart:math';
import 'package:flutter/material.dart';
import 'package:get/get.dart';


import '../../../Dashbaord/profile/profile_controller.dart';
import '../../../services/social_circleservice.dart';

class SocialCircleSetupController extends GetxController {
  final facebookCtrl = TextEditingController();
  final instagramCtrl = TextEditingController();

  final isLoading = false.obs;
  final canSubmit = false.obs;

  // ── random handle generator
  final _rng = Random();
  static const _adjs = [
    'sunny','cosmic','urban','wild','chill','golden','cozy','vivid','swift','lucky'
  ];
  static const _nouns = [
    'explorer','panda','tiger','vibes','galaxy','wanderer','artist','ninja','coder','phoenix'
  ];

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
    final f = facebookCtrl.text.trim();
    final i = instagramCtrl.text.trim();
    canSubmit.value = f.isNotEmpty || i.isNotEmpty;
  }

  @override
  void onInit() {
    super.onInit();
    // Prefill with random links for quick testing
    fillRandomFacebook();
    fillRandomInstagram();

    facebookCtrl.addListener(_recomputeSubmit);
    instagramCtrl.addListener(_recomputeSubmit);
  }

  @override
  void onClose() {
    facebookCtrl.dispose();
    instagramCtrl.dispose();
    super.onClose();
  }

  Future<void> submit() async {
    if (!canSubmit.value) return;
    isLoading.value = true;
    try {
      await SocialCircleService.updateLinks(
        facebook: facebookCtrl.text.trim().isEmpty ? null : facebookCtrl.text.trim(),
        instagram: instagramCtrl.text.trim().isEmpty ? null : instagramCtrl.text.trim(),
      );

      // refresh profile immediately
      if (Get.isRegistered<ProfileController>()) {
        await Get.find<ProfileController>().fetchProfile();
      }
    } finally {
      isLoading.value = false;
    }
  }
}
