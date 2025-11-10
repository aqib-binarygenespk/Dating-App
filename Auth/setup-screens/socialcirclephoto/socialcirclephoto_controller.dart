import 'dart:io';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';

class SocialCirclePhotoController extends GetxController {
  final Rx<File?> selectedImage = Rx<File?>(null);
  final ImagePicker _picker = ImagePicker();

  /// Pick image from gallery
  Future<void> pickImage() async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );

      if (pickedFile != null) {
        selectedImage.value = File(pickedFile.path);
      } else {
        Get.snackbar("No Image", "No image was selected.");
      }
    } catch (e) {
      Get.snackbar("Error", "Failed to pick image: ${e.toString()}");
    }
  }

  /// Optionally clear the image
  void clearImage() {
    selectedImage.value = null;
  }
}
