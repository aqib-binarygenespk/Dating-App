
import 'package:dating_app/Auth/setup-screens/socialcirclephoto/socialcirclephoto_controller.dart';
import 'package:dotted_border/dotted_border.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../themesfolder/theme.dart';

class SocialCirclePhotoScreen extends StatelessWidget {
  const SocialCirclePhotoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final SocialCirclePhotoController controller = Get.put(SocialCirclePhotoController());

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Social Circle Photo',
              style: Theme.of(context).textTheme.displayLarge,
            ),
            const SizedBox(height: 8),
            Text(
              "This photo will be used exclusively for Social Circle chats and friend requests.",
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 50),

            /// ⬛ Image Upload
            GestureDetector(
              onTap: () => controller.pickImage(),
              child: Obx(() => DottedBorder(
                color: Colors.black26,
                strokeWidth: 1,
                dashPattern: [8, 4],
                borderType: BorderType.RRect,
                radius: const Radius.circular(12),
                child: Container(
                  height: 300,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    color: Colors.white,
                  ),
                  child: controller.selectedImage.value == null
                      ? Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Image.asset(
                        'assets/image (7).png',
                        width: 50,
                        height: 50,
                        fit: BoxFit.contain,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        "Upload Image",
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.black54,
                        ),
                      ),
                    ],
                  )
                      : ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.file(
                      controller.selectedImage.value!,
                      fit: BoxFit.cover,
                      width: double.infinity,
                      height: double.infinity,
                    ),
                  ),
                ),
              )),
            ),

            const Spacer(),

            /// ⬛ Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pushNamed(context, '/bonding');
                },
                child: Text("Next", style: Theme.of(context).textTheme.labelLarge),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
