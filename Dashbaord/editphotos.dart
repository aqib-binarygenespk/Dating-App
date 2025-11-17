// lib/Dashboard/settingspages/profilesettings/editprofile/photos/editphotos.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:dotted_border/dotted_border.dart';

import '../../../../../themesfolder/theme.dart';
import 'editphotocontroller.dart';

class EditUploadPhotosScreen extends StatelessWidget {
  const EditUploadPhotosScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(EditUploadPhotosController());

    Widget imageTile(int index) {
      final content = Obx(
            () => DottedBorder(
          color: Colors.black45,
          strokeWidth: 1.5,
          dashPattern: const [6, 3],
          borderType: BorderType.RRect,
          radius: const Radius.circular(12),
          child: Container(
            width: double.infinity,
            height: 170,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppTheme.backgroundColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: _buildTileContent(context, controller, index),
          ),
        ),
      );

      // Drag one tile onto another → swap
      return DragTarget<int>(
        builder: (context, candidate, rejected) {
          final isActive = candidate.isNotEmpty;
          return Stack(
            children: [
              LongPressDraggable<int>(
                data: index,
                feedback: _dragFeedback(context, controller, index),
                // show faded original while dragging
                childWhenDragging: Opacity(opacity: 0.25, child: content),
                child: GestureDetector(
                  onTap: () => controller.pickImage(index),
                  child: content,
                ),
              ),
              const Positioned(
                right: 8,
                top: 8,
                child: Icon(Icons.compare_arrows, size: 18, color: Colors.black38),
              ),
              if (isActive)
                Positioned.fill(
                  child: IgnorePointer(
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(width: 2, color: Colors.black26),
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
        onWillAccept: (from) => from != index,
        onAccept: (from) => controller.swapSlots(from, index),
      );
    }

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context, true),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Edit Your Photos', style: Theme.of(context).textTheme.bodyLarge),
            const SizedBox(height: 8),
            Text(
              "Long-press a photo and drop it on another to swap. Tap a photo to replace it from gallery.",
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 20),
            Expanded(
              child: Obx(
                    () => GridView.builder(
                  padding: const EdgeInsets.all(5),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 1,
                  ),
                  itemCount: controller.images.length, // 6
                  itemBuilder: (context, index) => KeyedSubtree(
                    key: controller.slotKeys[index],
                    child: imageTile(index),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Obx(
                  () => SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: (controller.canUpload.value && !controller.isLoading.value)
                      ? controller.uploadPhotos
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black87,
                    disabledBackgroundColor: Colors.black26,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: controller.isLoading.value
                      ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                  )
                      : const Text("Update", style: TextStyle(fontSize: 16, color: Colors.white)),
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  // Snapshot under finger while dragging
  Widget _dragFeedback(
      BuildContext context,
      EditUploadPhotosController controller,
      int index,
      ) {
    final picked = controller.images[index];
    final url = controller.imageUrls[index];

    Widget child;
    if (picked != null) {
      child = Image.file(File(picked.path), fit: BoxFit.cover);
    } else if (url != null && url.isNotEmpty) {
      child = Image.network(url, fit: BoxFit.cover);
    } else {
      child = Container(
        color: AppTheme.backgroundColor,
        alignment: Alignment.center,
        child: const Icon(Icons.photo, size: 40),
      );
    }

    return Material(
      elevation: 8,
      borderRadius: BorderRadius.circular(12),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(width: 160, height: 160, child: child),
      ),
    );
  }

  Widget _buildTileContent(
      BuildContext context,
      EditUploadPhotosController controller,
      int index,
      ) {
    final picked = controller.images[index];
    if (picked != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.file(
          File(picked.path),
          width: double.infinity,
          height: double.infinity,
          fit: BoxFit.cover,
        ),
      );
    }

    final url = controller.imageUrls[index];
    if (url != null && url.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.network(
          url,
          width: double.infinity,
          height: double.infinity,
          fit: BoxFit.cover,
          loadingBuilder: (context, child, progress) {
            if (progress == null) return child;
            return const Center(child: CircularProgressIndicator(strokeWidth: 2));
          },
          errorBuilder: (context, _, __) => _placeholder(context),
        ),
      );
    }

    return _placeholder(context);
  }

  Widget _placeholder(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Image.asset('assets/image (7).png', width: 50, height: 50, fit: BoxFit.contain),
        const SizedBox(height: 8),
        Text("Upload Image", style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}
