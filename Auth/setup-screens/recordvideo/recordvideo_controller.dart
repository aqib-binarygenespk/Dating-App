import 'dart:convert';
import 'dart:io';

import 'package:dating_app/Auth/welcomescreen/welcomescreen.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_thumbnail/video_thumbnail.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;

import '../../../hive_utils/hive_service.dart';

class RecordVideoController extends GetxController {
  // ---- UI/state ----
  final videoFile = Rx<File?>(null);
  final thumbnailPath = Rx<String?>(null);
  final uploadedVideoUrl = RxString('');
  final isLoading = false.obs;

  // ---- Config ----
  static const _uploadUrl = 'https://pairup.binarygenes.pk/api/save-answers';
  static const _maxFileBytes = 200 * 1024 * 1024; // 200 MB
  static const _maxDuration = Duration(seconds: 15);

  /// Record a video (up to 15s) from camera
  Future<void> recordVideoFromCamera() async {
    try {
      final picker = ImagePicker();
      final pickedFile =
      await picker.pickVideo(source: ImageSource.camera, maxDuration: _maxDuration);
      if (pickedFile == null) return;

      final file = File(pickedFile.path);
      final length = await file.length();
      if (length > _maxFileBytes) {
        // keep this UX since it's not auth-related
        Get.snackbar("Too Large", "Video file exceeds 200 MB limit.");
        return;
      }

      videoFile.value = file;
      await _generateThumbnail(file.path);
    } catch (e) {
      // keep this UX since it's not auth-related
      Get.snackbar("Camera Error", "Could not record video: $e");
      debugPrint("🎥 recordVideoFromCamera error: $e");
    }
  }

  /// Pick a video from gallery
  Future<void> pickVideoFromGallery() async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickVideo(source: ImageSource.gallery);
      if (pickedFile == null) return;

      final file = File(pickedFile.path);
      final length = await file.length();
      if (length > _maxFileBytes) {
        Get.snackbar("Too Large", "Video file exceeds 200 MB limit.");
        return;
      }

      videoFile.value = file;
      await _generateThumbnail(file.path);
    } catch (e) {
      Get.snackbar("Picker Error", "Could not pick video: $e");
      debugPrint("🖼️ pickVideoFromGallery error: $e");
    }
  }

  /// Generate a thumbnail for preview
  Future<void> _generateThumbnail(String videoPath) async {
    try {
      final dir = await getTemporaryDirectory();
      final thumb = await VideoThumbnail.thumbnailFile(
        video: videoPath,
        thumbnailPath: dir.path,
        imageFormat: ImageFormat.JPEG,
        quality: 75,
      );
      thumbnailPath.value = thumb;
    } catch (e) {
      Get.snackbar("Thumbnail Error", "Could not generate thumbnail: $e");
      debugPrint("🖼️ _generateThumbnail error: $e");
    }
  }

  /// Clear selected video & thumbnail
  void clearVideo() {
    videoFile.value = null;
    thumbnailPath.value = null;
    uploadedVideoUrl.value = '';
  }

  // --------------------------- Upload ----------------------------

  /// Uploads the selected video to `/api/save-answers` as multipart field `video_url`
  Future<void> uploadVideoFile() async {
    final file = videoFile.value;
    if (file == null) {
      Get.snackbar("No Video", "Please record or select a video first.");
      return;
    }

    isLoading.value = true;

    try {
      final token = await _getNormalizedToken();

      if (token == null) {
        // ⛔️ No snackbar here — just send user to Welcome silently.
        isLoading.value = false;
        await _logoutAndGoToWelcomeSilently();
        return;
      }

      final uri = Uri.parse(_uploadUrl);
      final request = http.MultipartRequest('POST', uri)
        ..headers.addAll(_authHeaders(token))
        ..files.add(await http.MultipartFile.fromPath('video_url', file.path));

      final streamed = await request.send();
      final responseBody = await streamed.stream.bytesToString();
      debugPrint("📦 Response ${streamed.statusCode}: $responseBody");

      isLoading.value = false;

      if (streamed.statusCode == 200) {
        try {
          final decoded = json.decode(responseBody) as Map<String, dynamic>;
          final data = (decoded['data'] as Map?) ?? {};
          final url = data['video_url']?.toString() ?? '';
          uploadedVideoUrl.value = url;
        } catch (_) {}
        Get.snackbar("Success", "Video uploaded successfully.");

        await Future.delayed(const Duration(milliseconds: 350));
        Get.toNamed('/uploadphoto');
      } else if (streamed.statusCode == 401) {
        // ⛔️ No snackbar here either
        await _logoutAndGoToWelcomeSilently();
      } else if (streamed.statusCode == 422) {
        String msg = "Validation failed.";
        try {
          final j = json.decode(responseBody);
          msg = (j['message'] ?? j['error'] ?? msg).toString();
        } catch (_) {}
        Get.snackbar("Upload Failed", msg);
      } else {
        String msg = "Upload failed (status ${streamed.statusCode}).";
        try {
          final j = json.decode(responseBody);
          msg = (j['message'] ?? j['error'] ?? msg).toString();
        } catch (_) {}
        Get.snackbar("Upload Failed", msg);
      }
    } catch (e) {
      isLoading.value = false;
      Get.snackbar("Error", "Something went wrong: $e");
      debugPrint("❌ Exception in uploadVideoFile: $e");
    }
  }

  // ------------------------- Auth helpers -------------------------

  /// Reads token from Hive, normalizes it (strip any 'Bearer ')
  Future<String?> _getNormalizedToken() async {
    final raw = await HiveService.getToken();
    if (raw == null) return null;
    final t = raw.trim();
    if (t.isEmpty) return null;
    return t.startsWith('Bearer ') ? t.substring(7).trim() : t;
  }

  Map<String, String> _authHeaders(String token) => <String, String>{
    'Authorization': 'Bearer $token',
    'Accept': 'application/json',
  };

  /// Navigate to welcome with NO snackbar.
  Future<void> _logoutAndGoToWelcomeSilently() async {
    await HiveService.clearBox('userBox');
    await Future.delayed(const Duration(milliseconds: 200));
    Get.offAll(() => const WelcomeScreen());
  }
}
