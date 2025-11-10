import 'dart:math';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../../services/social_circleservice.dart';
import '../../../../profile/profile_controller.dart';

class SocialCircleUpdateController extends GetxController {
  final facebookCtrl = TextEditingController();
  final instagramCtrl = TextEditingController();

  final isLoading = false.obs;
  final canSubmit = false.obs; // now computed from inputs

  // random generator (for quick testing on update too)
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

  void randomFacebook() {
    facebookCtrl.text = 'https://facebook.com/${_handle()}';
    _recomputeSubmit();
  }

  void randomInstagram() {
    instagramCtrl.text = 'https://instagram.com/${_handle()}';
    _recomputeSubmit();
  }

  void _recomputeSubmit() {
    final f = facebookCtrl.text.trim();
    final i = instagramCtrl.text.trim();
    // allow submit if at least one is filled (or both cleared to update as empty if you prefer)
    canSubmit.value = f.isNotEmpty || i.isNotEmpty;
  }

  @override
  void onInit() {
    super.onInit();

    // Prefill from route args if provided
    final args = Get.arguments is Map ? Get.arguments as Map : {};
    final fb = (args['facebook'] ?? '').toString();
    final ig = (args['instagram'] ?? '').toString();
    if (fb.isNotEmpty) facebookCtrl.text = fb;
    if (ig.isNotEmpty) instagramCtrl.text = ig;

    // compute initial state
    _recomputeSubmit();

    // listeners to keep button state in sync
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

      // refresh profile immediately so user sees new links without re-login
      if (Get.isRegistered<ProfileController>()) {
        await Get.find<ProfileController>().fetchProfile();
      }

      // close this screen with a "true" result
      if (Get.context != null) {
        Navigator.of(Get.context!).maybePop(true);
      } else {
        Get.back(result: true);
      }
    } finally {
      isLoading.value = false;
    }
  }
}
