import 'package:get/get.dart';
import 'package:hive/hive.dart';
import '../../../hive_utils/hive_boxes.dart';
import '../../../services/api_services.dart';

class ActivateNumberController extends GetxController {
  var phoneNumber = ''.obs;
  var isSending = false.obs;

  void updatePhoneNumber(String number) {
    phoneNumber.value = number;
  }

  Future<bool> sendCode() async {
    if (phoneNumber.value.isEmpty) {
      Get.snackbar("Error", "Please enter your phone number.");
      return false;
    }

    isSending.value = true;
    try {
      final token = Hive.box(HiveBoxes.userBox).get('auth_token');
      if (token == null) {
        Get.snackbar("Error", "You must be logged in to request a code.");
        isSending.value = false;
        return false;
      }

      final res = await ApiService.post(
        "reactive/send-code",
        {"phone_number": phoneNumber.value},
        token: token,
      );

      if (res['success'] == true) {
        Get.snackbar("Success", "Activation code sent successfully.");
        return true;
      } else {
        Get.snackbar("Error", res['message'] ?? "Failed to send code.");
        return false;
      }
    } catch (e) {
      Get.snackbar("Error", "Failed to send code: $e");
      return false;
    } finally {
      isSending.value = false;
    }
  }
}
