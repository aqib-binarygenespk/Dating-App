import 'dart:io';
import 'package:dating_app/Auth/setup-screens/recordvideo/recordvideo_controller.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../themesfolder/theme.dart';

class RecordVideoScreen extends StatefulWidget {
  const RecordVideoScreen({super.key});

  @override
  State<RecordVideoScreen> createState() => _RecordVideoScreenState();
}

class _RecordVideoScreenState extends State<RecordVideoScreen> {
  late final RecordVideoController controller;

  @override
  void initState() {
    super.initState();
    controller = Get.put(RecordVideoController());

    // ⛔️ Kill any snackbars that were triggered by previous screens/controllers.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (Get.isSnackbarOpen == true) {
        Get.closeAllSnackbars();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Get.back(),
        ),
        actions: [
          Obx(() => IconButton(
            tooltip: 'Remove video',
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
            Text('Record Your Video', style: Theme.of(context).textTheme.bodyLarge),
            const SizedBox(height: 20),

            // Tap to record / preview thumbnail
            Obx(() => GestureDetector(
              onTap: controller.recordVideoFromCamera,
              child: Center(
                child: Container(
                  height: 180,
                  width: 200,
                  decoration: BoxDecoration(
                    color: AppTheme.backgroundColor,
                    border: Border.all(color: Colors.black, width: 1.5),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: controller.videoFile.value == null
                      ? Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Image.asset('assets/video.png', width: 40, height: 60),
                      const SizedBox(height: 10),
                      Text('Record Video',
                          style: Theme.of(context).textTheme.bodySmall),
                    ],
                  )
                      : ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Image.file(
                      File(controller.thumbnailPath.value ??
                          controller.videoFile.value!.path),
                      fit: BoxFit.cover,
                      width: double.infinity,
                      height: 180,
                    ),
                  ),
                ),
              ),
            )),

            const Spacer(),

            // Upload CTA
            Obx(() => SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: controller.isLoading.value
                    ? null
                    : controller.uploadVideoFile,
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
                    : const Text("Upload",
                    style: TextStyle(fontSize: 16, color: Colors.white)),
              ),
            )),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
