import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_thumbnail/video_thumbnail.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;

import '../../../../../hive_utils/hive_service.dart';
import '../../../../profile/profile_controller.dart';

/// Controller to handle *edit* video flow (RECORD ONLY):
/// 1) record (camera, up to 15s) + thumbnail
/// 2) upload file -> get `video_url`
/// 3) PUT /api/update-profile with answers: [{question_id, answer}]
class EditVideoController extends GetxController {
  // ---- UI/state ----
  final videoFile = Rx<File?>(null);
  final thumbnailPath = Rx<String?>(null);
  final uploadedVideoUrl = RxString('');
  final isLoading = false.obs;

  // If you want to show hint that a video exists already (no network fetch)
  final String? existingVideoUrl;

  // REQUIRED: the categories.json question id for your `video_upload` item
  final int videoQuestionId;

  EditVideoController({
    required this.videoQuestionId,
    this.existingVideoUrl,
  });

  // ---- Config ----
  static const _uploadUrl = 'https://pairup.binarygenes.pk/api/save-answers';
  static const _updateProfileUrl = 'https://pairup.binarygenes.pk/api/update-profile';

  static const _maxFileBytes = 200 * 1024 * 1024; // 200 MB
  static const _maxDuration = Duration(seconds: 15);

  /// Record a video (up to 15s) from camera
  Future<void> recordVideoFromCamera() async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickVideo(
        source: ImageSource.camera,
        maxDuration: _maxDuration,
      );
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
      Get.snackbar("Camera Error", "Could not record video: $e");
      debugPrint("🎥 recordVideoFromCamera error: $e");
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

  // --------------------------- EDIT / UPDATE ----------------------------

  /// 2-step update:
  /// 1) Upload file (multipart) -> receive `data.video_url`
  /// 2) PUT /update-profile with answers: [{ question_id, answer: video_url }]
  Future<void> updateVideoOnProfile() async {
    final file = videoFile.value;
    if (file == null) {
      Get.snackbar("No Video", "Please record a video first.");
      return;
    }

    isLoading.value = true;

    try {
      final token = await _getNormalizedToken();
      if (token == null) {
        // No snackbar; silently logout
        isLoading.value = false;
        await _logoutAndGoToWelcomeSilently();
        return;
      }

      // ---- Step 1: upload file to get URL ----
      final videoUrl = await _uploadVideoFile(token, file);
      if (videoUrl == null || videoUrl.isEmpty) {
        isLoading.value = false;
        Get.snackbar("Upload Failed", "Could not get uploaded video URL.");
        return;
      }
      uploadedVideoUrl.value = videoUrl;

      // ---- Step 2: update profile with that URL ----
      final ok = await _putUpdateProfile(token, videoUrl);
      isLoading.value = false;

      if (ok) {
        Get.snackbar("Success", "Video updated successfully.");

        if (Get.isRegistered<ProfileController>()) {
          try {
            final profileController = Get.find<ProfileController>();
            await profileController.fetchProfile();
          } catch (_) {}
        }

        await Future.delayed(const Duration(milliseconds: 350));
        Get.back(); // return to previous (e.g., Edit Profile)
      } else {
        Get.snackbar("Update Failed", "Server did not accept the update.");
      }
    } catch (e) {
      isLoading.value = false;
      Get.snackbar("Error", "Something went wrong: $e");
      debugPrint("❌ Exception in updateVideoOnProfile: $e");
    }
  }

  // --------------------------- Network helpers ----------------------------

  /// Uploads the selected video to `/api/save-answers` as multipart field `video_url`.
  /// Returns the uploaded file URL (string) from response.data.video_url
  Future<String?> _uploadVideoFile(String token, File file) async {
    final uri = Uri.parse(_uploadUrl);
    final request = http.MultipartRequest('POST', uri)
      ..headers.addAll(_authHeaders(token))
      ..files.add(await http.MultipartFile.fromPath('video_url', file.path));

    final streamed = await request.send();
    final responseBody = await streamed.stream.bytesToString();
    debugPrint("📦 Upload response ${streamed.statusCode}: $responseBody");

    if (streamed.statusCode == 200) {
      try {
        final decoded = json.decode(responseBody) as Map<String, dynamic>;
        final data = (decoded['data'] as Map?) ?? {};
        final url = data['video_url']?.toString() ?? '';
        return url;
      } catch (e) {
        debugPrint("⚠️ Could not parse upload response: $e");
        return null;
      }
    } else if (streamed.statusCode == 401) {
      await _logoutAndGoToWelcomeSilently();
      return null;
    } else {
      try {
        final j = json.decode(responseBody);
        final msg = (j['message'] ?? j['error'] ?? 'Upload failed').toString();
        Get.snackbar("Upload Failed", msg);
      } catch (_) {
        Get.snackbar("Upload Failed",
            "Status ${streamed.statusCode}. Please try again.");
      }
      return null;
    }
  }

  Future<bool> _putUpdateProfile(String token, String videoUrl) async {
    final uri = Uri.parse(_updateProfileUrl);
    final body = json.encode({
      "answers": [
        {
          "question_id": videoQuestionId,
          "answer": videoUrl,
        }
      ]
    });

    final resp = await http.put(
      uri,
      headers: {
        ..._authHeaders(token),
        'Content-Type': 'application/json',
      },
      body: body,
    );

    debugPrint("🛠️ update-profile ${resp.statusCode}: ${resp.body}");

    if (resp.statusCode == 200) {
      return true;
    } else if (resp.statusCode == 401) {
      await _logoutAndGoToWelcomeSilently();
      return false;
    } else {
      String msg = "Update failed (status ${resp.statusCode}).";
      try {
        final j = json.decode(resp.body);
        msg = (j['message'] ?? j['error'] ?? msg).toString();
      } catch (_) {}
      Get.snackbar("Update Failed", msg);
      return false;
    }
  }

  // ------------------------- Auth helpers -------------------------

  Future<String?> _getNormalizedToken() async {
    final raw = await HiveService.getToken();
    if (raw == null) return null;
    final t = raw.trim();
    if (t.isEmpty) return null;
    return t.startsWith('Bearer ') ? t.substring(7).trim() : t;
    // If your backend requires 'Bearer ' prefix, keep full token instead:
    // return raw;
  }

  Map<String, String> _authHeaders(String token) => <String, String>{
    'Authorization': 'Bearer $token',
    'Accept': 'application/json',
  };

  /// Navigate to welcome with NO snackbar.
  Future<void> _logoutAndGoToWelcomeSilently() async {
    await HiveService.clearBox('userBox');
    await Future.delayed(const Duration(milliseconds: 200));
    Get.offAllNamed('/welcome');
  }
}
