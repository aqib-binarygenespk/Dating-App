// lib/Dashboard/settingspages/profilesettings/editprofile/photos/editphotocontroller.dart
import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:hive/hive.dart';

import '../../../../../hive_utils/hive_boxes.dart';
import '../../../../../services/api_services.dart';
import '../../../../profile/profile_controller.dart';

class EditUploadPhotosController extends GetxController {
  /// Local picks this session (6 slots, nullable)
  final RxList<XFile?> images = List<XFile?>.generate(6, (_) => null).obs;

  /// Existing image URLs from profile (ordered, nullable)
  final RxList<String?> imageUrls = List<String?>.generate(6, (_) => null).obs;

  /// Stable keys for grid children (keeps drag/reorder animations stable)
  final RxList<Key> slotKeys = List<Key>.generate(6, (_) => UniqueKey()).obs;

  final RxBool canUpload = false.obs;
  final RxBool isLoading = false.obs;

  final ImagePicker picker = ImagePicker();

  /// Must match backend categories.json
  static const int photoQuestionId = 8;

  /// API endpoints (without /api/ prefix if your ApiService adds it)
  static const String uploadPhotosEndpoint = 'upload-photos';   // POST /api/upload-photos
  static const String updateProfileEndpoint = 'update-profile'; // PUT  /api/update-profile

  /// If your backend serves files at a different host/origin, set it here.
  /// Example: 'https://pairup.binarygenes.pk/'
  static const String filesBaseUrl = ''; // <-- put your absolute base here if needed

  @override
  void onInit() {
    super.onInit();
    _hydrateFromProfile();
    ever(images, (_) => _recomputeCanUpload());
    ever(imageUrls, (_) => _recomputeCanUpload());
  }

  void _recomputeCanUpload() {
    bool anyFilled = false;
    for (int i = 0; i < 6; i++) {
      final hasLocal = images[i] != null;
      final hasRemote = (imageUrls[i] ?? '').isNotEmpty;
      if (hasLocal || hasRemote) {
        anyFilled = true;
        break;
      }
    }
    canUpload.value = anyFilled;
  }

  Future<void> _hydrateFromProfile() async {
    final profile = Get.isRegistered<ProfileController>()
        ? Get.find<ProfileController>()
        : Get.put(ProfileController());

    if (profile.imageUrls.isEmpty) {
      await profile.fetchProfile();
    }

    for (int i = 0; i < 6; i++) {
      final url = (i < profile.imageUrls.length) ? profile.imageUrls[i] : null;
      imageUrls[i] = _absUrlOrNull(url);
    }

    // Clear local picks on load
    for (int i = 0; i < images.length; i++) {
      images[i] = null;
    }
    _recomputeCanUpload();
  }

  Future<void> pickImage(int index) async {
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 75,
    );
    if (picked != null) {
      images[index] = picked;
      _recomputeCanUpload();
    }
  }

  /// Optional: clear a single slot
  void clearSlot(int index) {
    images[index] = null;
    imageUrls[index] = null;
    _recomputeCanUpload();
  }

  /// KEEP: drag/swap functionality unchanged
  void swapSlots(int a, int b) {
    if (a == b) return;

    final tmpImg = images[a];
    images[a] = images[b];
    images[b] = tmpImg;

    final tmpUrl = imageUrls[a];
    imageUrls[a] = imageUrls[b];
    imageUrls[b] = tmpUrl;

    final tmpKey = slotKeys[a];
    slotKeys[a] = slotKeys[b];
    slotKeys[b] = tmpKey;

    _recomputeCanUpload();
  }

  /// Make absolute URLs for Image.network if backend returns relative paths
  String? _absUrlOrNull(String? url) {
    if (url == null || url.isEmpty) return null;
    if (url.startsWith('http://') || url.startsWith('https://')) return url;
    if (filesBaseUrl.isEmpty) return url; // fallback: assume already absolute
    final trimmedBase = filesBaseUrl.endsWith('/')
        ? filesBaseUrl.substring(0, filesBaseUrl.length - 1)
        : filesBaseUrl;
    final trimmedUrl = url.startsWith('/') ? url.substring(1) : url;
    return '$trimmedBase/$trimmedUrl';
  }

  /// Upload many files to `upload-photos` (field: photos[]) and return absolute URLs in order
  Future<List<String>> _uploadManyFiles(List<File> files) async {
    if (files.isEmpty) return <String>[];

    final token = Hive.box(HiveBoxes.userBox).get('auth_token');
    final resp = await ApiService.postMultipart(
      endpoint: uploadPhotosEndpoint,
      files: files,
      fileField: 'photos[]',
      token: token,
    );

    if (resp is Map && resp['success'] == true) {
      // Accept multiple response shapes:
      // 1) {"photos": ["storage/photo/..jpg", ...]}
      if (resp['photos'] is List) {
        final list = List<String>.from(resp['photos'])
            .map(_absUrlOrNull)
            .whereType<String>()
            .toList();
        if (list.isNotEmpty) return list;
      }
      // 2) {"urls": ["https://...", ...]}
      if (resp['urls'] is List) {
        return List<String>.from(resp['urls']);
      }
      // 3) {"data":{"urls":[...]}}
      if (resp['data'] is Map && resp['data']['urls'] is List) {
        return List<String>.from(resp['data']['urls']);
      }
      // 4) {"data":[{"url":"..."}, ...]}
      if (resp['data'] is List) {
        final list = (resp['data'] as List)
            .map((e) => e is Map && e['url'] is String ? e['url'] as String : null)
            .whereType<String>()
            .map(_absUrlOrNull)
            .whereType<String>()
            .toList();
        if (list.isNotEmpty) return list;
      }
    }

    throw Exception(
      (resp is Map && resp['message'] is String)
          ? resp['message']
          : 'Upload failed',
    );
  }

  /// Upload new files (if any), merge into current order, and PUT to /api/update-profile
  Future<void> uploadPhotos() async {
    final token = Hive.box(HiveBoxes.userBox).get('auth_token');
    if (token == null) {
      Get.snackbar("Error", "Missing auth token.");
      return;
    }
    if (!canUpload.value) {
      Get.snackbar("Add Photos", "Please add at least one photo before updating.");
      return;
    }

    isLoading.value = true;
    try {
      // 1) Collect local files (slot order)
      final List<int> localIdx = [];
      final List<File> localFiles = [];
      for (int i = 0; i < 6; i++) {
        final local = images[i];
        if (local != null) {
          localIdx.add(i);
          localFiles.add(File(local.path));
        }
      }

      // 2) Upload locals
      List<String> uploaded = [];
      if (localFiles.isNotEmpty) {
        uploaded = await _uploadManyFiles(localFiles);
        if (uploaded.length != localFiles.length) {
          throw Exception('Upload response count mismatch.');
        }
      }

      // 3) Merge uploaded back into their original slots
      final List<String?> merged = List<String?>.from(imageUrls);
      int u = 0;
      for (final i in localIdx) {
        final newUrl = uploaded[u++];
        merged[i] = newUrl;
        imageUrls[i] = newUrl; // update cache for preview
      }

      // 4) Build final ordered URLs (skip empty)
      final List<String> finalUrls = [];
      for (int i = 0; i < 6; i++) {
        final url = (merged[i] ?? '').trim();
        if (url.isNotEmpty) finalUrls.add(url);
      }
      if (finalUrls.isEmpty) {
        throw Exception('No photos available to save.');
      }

      // 5) Backend expects answers[ { question_id, photos: [...] } ]
      final Map<String, dynamic> body = {
        "answers": [
          {
            "question_id": photoQuestionId,
            "photos": finalUrls,
          }
        ]
      };

      // 6) PUT (your route rejects POST with 405)
      final resp = await ApiService.put(
        updateProfileEndpoint,
        body,
        token: token,
        isJson: true,
      );

      if (resp is Map && resp['success'] == true) {
        Get.snackbar("Success", (resp['message'] ?? "Photos updated.") as String);

        // Refresh Profile so new order/urls appear
        final profile = Get.isRegistered<ProfileController>()
            ? Get.find<ProfileController>()
            : Get.put(ProfileController());
        await profile.fetchProfile();

        // Clear local picks after success
        for (int i = 0; i < images.length; i++) {
          images[i] = null;
        }

        // Close with success
        if (Get.context != null && Navigator.of(Get.context!).canPop()) {
          Navigator.of(Get.context!).pop(true);
        } else {
          Get.back(result: true);
        }
      } else {
        Get.snackbar(
          "Error",
          (resp is Map && resp['message'] is String)
              ? resp['message']
              : "Update failed.",
        );
      }
    } catch (e) {
      Get.snackbar("Error", e.toString());
    } finally {
      isLoading.value = false;
    }
  }
}
