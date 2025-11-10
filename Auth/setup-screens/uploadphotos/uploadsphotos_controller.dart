// lib/Dashboard/settingspages/profilesettings/editprofile/photos/upload_photos_controller.dart
import 'dart:io';
import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:hive/hive.dart';

import '../../../../../hive_utils/hive_boxes.dart';
import '../../../../../services/api_services.dart';
// NOTE: Fix this import path if your folder name differs (e.g., "Dashboard" vs "Dashbaord")
import '../../../Dashbaord/profile/profile_controller.dart';

/// Upload + (optional) reorder controller
/// - Only shows ONE snackbar: "Photos uploaded" (success)
/// - Hides ALL other errors (incl. "missing authentication token")
class UploadPhotosController extends GetxController {
  UploadPhotosController({
    this.fromEdit = false,
    this.finalizeOrder = true, // keep your existing flow
  });

  final bool fromEdit;
  final bool finalizeOrder;

  final RxList<XFile?> images = List<XFile?>.generate(6, (_) => null).obs;
  final RxList<String?> imageUrls = List<String?>.generate(6, (_) => null).obs;
  final RxSet<int> dirtyIndexes = <int>{}.obs;
  final RxList<Key> slotKeys = List<Key>.generate(6, (_) => UniqueKey()).obs;

  final RxBool isLoading = false.obs;
  final RxBool canUpload = false.obs;

  final ImagePicker picker = ImagePicker();
  static const int photoQuestionId = 8;

  @override
  void onInit() {
    super.onInit();
    _hydrateFromProfile();
    ever<List<XFile?>>(images, (_) => _recomputeCanUpload());
    ever<List<String?>>(imageUrls, (_) => _recomputeCanUpload());
  }

  // ---------------------------------------------------------------------------
  // Token helper (silent if missing)
  // ---------------------------------------------------------------------------

  String? _readToken() {
    try {
      final box = Hive.box(HiveBoxes.userBox);
      final t = (box.get('token') ?? box.get('auth_token') ?? box.get('bearer_token'))?.toString();
      if (t == null || t.trim().isEmpty) return null;
      return t.trim();
    } catch (_) {
      return null; // 🔇 silent
    }
  }

  // ---------------------------------------------------------------------------
  // Init / State
  // ---------------------------------------------------------------------------

  Future<void> _hydrateFromProfile() async {
    final profile = _getOrCreate<ProfileController>(() => ProfileController());

    if (profile.imageUrls.isEmpty) {
      // silent fetch
      try { await profile.fetchProfile(); } catch (_) {}
    }

    for (int i = 0; i < 6; i++) {
      final url = (i < profile.imageUrls.length && profile.imageUrls[i].isNotEmpty)
          ? profile.imageUrls[i]
          : null;
      imageUrls[i] = url;
      images[i] = null;
    }
    dirtyIndexes.clear();
    _recomputeCanUpload();
  }

  void _recomputeCanUpload() {
    final anyLocal = images.any((x) => x != null);
    if (finalizeOrder) {
      canUpload.value = anyLocal || _hasOrderChangedComparedToServer;
    } else {
      canUpload.value = anyLocal;
    }
  }

  bool get _hasOrderChangedComparedToServer {
    final profile = Get.isRegistered<ProfileController>() ? Get.find<ProfileController>() : null;
    if (profile == null || profile.imageUrls.isEmpty) return false;

    final uiOrder = imageUrls.whereType<String>().where((e) => e.isNotEmpty).toList();
    final serverOrder = profile.imageUrls.where((e) => e.isNotEmpty).toList();
    return !_listsEqual(uiOrder, serverOrder);
  }

  // ---------------------------------------------------------------------------
  // Picking / Removing
  // ---------------------------------------------------------------------------

  Future<void> pickImage(int index) async {
    try {
      final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 75);
      if (picked != null) {
        images[index] = picked;
        imageUrls[index] = null; // show local until uploaded
        dirtyIndexes.add(index);
        _recomputeCanUpload();
      }
    } catch (_) {
      // 🔇 no snackbar
    }
  }

  void removeImage(int index) {
    images[index] = null;
    imageUrls[index] = null;
    dirtyIndexes.add(index);
    _recomputeCanUpload();
  }

  // ---------------------------------------------------------------------------
  // Reorder (press-and-drag support)
  // ---------------------------------------------------------------------------

  void reorder(int oldIndex, int newIndex) {
    if (oldIndex == newIndex) return;
    newIndex = newIndex.clamp(0, images.length - 1);
    _move<XFile?>(images, oldIndex, newIndex);
    _move<String?>(imageUrls, oldIndex, newIndex);
    _move<Key>(slotKeys, oldIndex, newIndex);
    _recomputeCanUpload();
  }

  void swapSlots(int a, int b) {
    if (a == b) return;
    final tmpImg = images[a]; images[a] = images[b]; images[b] = tmpImg;
    final tmpUrl = imageUrls[a]; imageUrls[a] = imageUrls[b]; imageUrls[b] = tmpUrl;
    final tmpKey = slotKeys[a]; slotKeys[a] = slotKeys[b]; slotKeys[b] = tmpKey;
    _recomputeCanUpload();
  }

  // ---------------------------------------------------------------------------
  // Submit (Upload + optional finalize)
  // ONLY success snackbar; all errors silent
  // ---------------------------------------------------------------------------

  Future<void> uploadPhotos() async {
    final token = _readToken();
    if (token == null) {
      // 🔇 absolutely silent (prevents "missing authentication" popping anywhere)
      return;
    }

    final nothingToDo =
        dirtyIndexes.isEmpty && (!finalizeOrder || !_hasOrderChangedComparedToServer);
    if (nothingToDo) return; // 🔇

    isLoading.value = true;
    bool uploadedSomething = false;
    bool orderFinalized = false;

    try {
      // 1) Upload only changed files
      uploadedSomething = await _uploadDirtyFilesIndexed(token);

      // 2) Refresh if uploaded
      if (uploadedSomething) {
        try {
          await _refreshFromServer();
        } catch (_) {}
      }

      // 3) Finalize order (silent if fails)
      if (finalizeOrder && _hasOrderChangedComparedToServer) {
        try {
          orderFinalized = await _ensureServerOrderMatchesUI(token);
        } catch (_) {
          orderFinalized = false; // 🔇 swallow auth/other errors
        }
      }

      // ✅ Only show snackbar when photos were uploaded successfully
      if (uploadedSomething) {
        _showSuccessSnackBar();
      }

      // clear local picks if anything changed
      if (uploadedSomething || orderFinalized) {
        for (int i = 0; i < 6; i++) {
          images[i] = null;
        }
        dirtyIndexes.clear();
      }

      // navigate as before
      if (uploadedSomething || orderFinalized) {
        if (fromEdit) {
          if (Get.context != null && Navigator.of(Get.context!).canPop()) {
            Navigator.of(Get.context!).pop(true);
          } else {
            Get.back(result: true);
          }
        } else {
          Get.toNamed('/bonding');
        }
      }
    } catch (_) {
      // 🔇 silent
    } finally {
      isLoading.value = false;
    }
  }

  // ---------------------------------------------------------------------------
  // Internals (silent)
  // ---------------------------------------------------------------------------

  Future<bool> _uploadDirtyFilesIndexed(String token) async {
    if (dirtyIndexes.isEmpty) return false;

    final sorted = dirtyIndexes.toList()..sort();
    final Map<String, File> filesByField = {};
    for (final i in sorted) {
      final xf = images[i];
      if (xf != null) {
        filesByField['photos[$i]'] = File(xf.path);
      }
    }
    if (filesByField.isEmpty) return false;

    try {
      final resp = await ApiService.postMultipartIndexed(
        endpoint: 'upload-photos',
        filesByField: filesByField,
        token: token,
      );
      final success = (resp['success'] == true) || (resp['status'] == true);
      return success == true;
    } catch (_) {
      return false; // 🔇
    }
  }

  Future<void> _refreshFromServer() async {
    final profile = _getOrCreate<ProfileController>(() => ProfileController());
    await profile.fetchProfile();
    final serverUrls = List<String>.from(profile.imageUrls);
    for (int i = 0; i < 6; i++) {
      final sUrl = (i < serverUrls.length && serverUrls[i].isNotEmpty) ? serverUrls[i] : null;
      imageUrls[i] = imageUrls[i] ?? sUrl;
    }
  }

  Future<bool> _ensureServerOrderMatchesUI(String token) async {
    final List<String> finalUrls = [];
    for (int i = 0; i < 6; i++) {
      final url = imageUrls[i];
      if (url != null && url.isNotEmpty) finalUrls.add(url);
    }

    final profile = _getOrCreate<ProfileController>(() => ProfileController());
    final serverOrder = List<String>.from(profile.imageUrls.where((e) => e.isNotEmpty));
    final sameOrder = _listsEqual(finalUrls, serverOrder);
    if (sameOrder) return false;

    final body = {
      "answers": {
        "photo_upload": {
          "question_id": photoQuestionId,
          "photos": finalUrls,
        }
      }
    };

    try {
      final resp = await ApiService.put(
        'update-profile',
        body,
        token: token,
        isJson: true,
      );
      final ok = (resp['success'] == true) || (resp['status'] == true);
      if (!ok) return false;

      await profile.fetchProfile();
      for (int i = 0; i < 6; i++) {
        imageUrls[i] = (i < profile.imageUrls.length && profile.imageUrls[i].isNotEmpty)
            ? profile.imageUrls[i]
            : null;
      }
      return true;
    } catch (_) {
      return false; // 🔇
    }
  }

  // ---------------------------------------------------------------------------
  // Utils
  // ---------------------------------------------------------------------------

  void _showSuccessSnackBar() {
    // ✅ The ONLY snackbar we ever show
    try {
      Get.snackbar(
        'Success',
        'Photos uploaded',
        snackPosition: SnackPosition.BOTTOM,
        margin: const EdgeInsets.all(12),
        duration: const Duration(seconds: 2),
      );
    } catch (_) {
      // ignore if no context
    }
  }

  bool _listsEqual(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  void _move<T>(List<T> list, int oldIndex, int newIndex) {
    final item = list.removeAt(oldIndex);
    list.insert(newIndex, item);
  }

  T _getOrCreate<T>(T Function() create) {
    try {
      return Get.find<T>();
    } catch (_) {
      return Get.put<T>(create());
    }
  }
}
