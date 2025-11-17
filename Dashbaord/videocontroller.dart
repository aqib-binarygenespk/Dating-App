import 'dart:io';
import 'package:dating_app/Dashbaord/settingspages/profilesettings/editprofile/recordvideo/recordvideoupdate.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../../themesfolder/theme.dart';
import 'videocontroller.dart';

class EditVideoScreen extends StatefulWidget {
  /// (Optional) If you want to show something when no local video is selected yet.
  /// Typically your current profile video URL. Only used for display hints, not downloaded.
  final String? existingVideoUrl;

  /// Pass the question id that maps to your `video_upload` question in categories.json
  /// ⚠️ REQUIRED for update-profile call to know which question to update.
  final int videoQuestionId;

  const EditVideoScreen({
    super.key,
    required this.videoQuestionId,
    this.existingVideoUrl,
  });

  @override
  State<EditVideoScreen> createState() => _EditVideoScreenState();
}

class _EditVideoScreenState extends State<EditVideoScreen> {
  late final EditVideoController controller;

  @override
  void initState() {
    super.initState();
    controller = Get.put(EditVideoController(
      videoQuestionId: widget.videoQuestionId,
      existingVideoUrl: widget.existingVideoUrl,
    ));

    // Kill any stray snackbars from previous screens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (Get.isSnackbarOpen == true) {
        Get.closeAllSnackbars();
      }
    });
  }

  void _recordNow() {
    FocusScope.of(context).unfocus();
    controller.recordVideoFromCamera();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          tooltip: 'Back',
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Get.back(),
        ),
        actions: [
          Obx(() => IconButton(
            tooltip: 'Remove selected video',
            onPressed:
            controller.videoFile.value == null ? null : controller.clearVideo,
            icon: Icon(
              Icons.close,
              color: controller.videoFile.value == null
                  ? Colors.black26
                  : Colors.black,
            ),
          )),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Edit Your Video', style: textTheme.bodyLarge),
            const SizedBox(height: 20),

            // Tap to record / preview thumbnail
            Obx(() {
              final hasLocal = controller.videoFile.value != null;
              return GestureDetector(
                onTap: _recordNow, // RECORD ONLY
                child: Center(
                  child: Container(
                    height: 180,
                    width: 200,
                    decoration: BoxDecoration(
                      color: AppTheme.backgroundColor,
                      border: Border.all(color: Colors.black, width: 1.5),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: hasLocal
                        ? ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Image.file(
                        File(controller.thumbnailPath.value ??
                            controller.videoFile.value!.path),
                        fit: BoxFit.cover,
                        width: double.infinity,
                        height: 180,
                      ),
                    )
                        : Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Image.asset('assets/video.png', width: 40, height: 60),
                        const SizedBox(height: 10),
                        Text(
                          controller.existingVideoUrl?.isNotEmpty == true
                              ? 'Tap to record a new 15s video'
                              : 'Tap to record a 15s video',
                          style: textTheme.bodySmall,
                          textAlign: TextAlign.center,
                        ),
                        if (controller.existingVideoUrl?.isNotEmpty == true) ...[
                          const SizedBox(height: 8),
                          Text(
                            'A video already exists on your profile.',
                            style: textTheme.labelSmall?.copyWith(
                              color: Colors.black54,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              );
            }),

            const Spacer(),

            // Update CTA
            Obx(() => SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: controller.isLoading.value
                    ? null
                    : controller.updateVideoOnProfile,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF111827),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: controller.isLoading.value
                    ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(color: Colors.white),
                )
                    : const Text(
                  "Update",
                  style: TextStyle(fontSize: 16, color: Colors.white),
                ),
              ),
            )),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
