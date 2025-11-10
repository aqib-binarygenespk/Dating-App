import 'package:get/get.dart';
import 'package:hive/hive.dart';
import '../../../hive_utils/hive_boxes.dart';
import '../../../services/api_services.dart';

class DeleteNumberController extends GetxController {
  final RxString phoneNumber = ''.obs;
  final RxBool isSending = false.obs;

  void updatePhoneNumber(String completeNumber) {
    phoneNumber.value = completeNumber; // E.164 from IntlPhoneField
  }

  bool _looksLikeE164(String s) {
    // Same as backend validator
    final re = RegExp(r'^\+[1-9]\d{1,14}$');
    return re.hasMatch(s);
  }

  Future<bool> sendCode() async {
    final phone = phoneNumber.value.trim();
    if (phone.isEmpty) {
      Get.snackbar('Error', 'Please enter your phone number.');
      return false;
    }
    if (!_looksLikeE164(phone)) {
      Get.snackbar('Error', 'Phone must be in international format, e.g. +15551234567');
      return false;
    }

    if (!Hive.isBoxOpen(HiveBoxes.userBox)) {
      await Hive.openBox(HiveBoxes.userBox);
    }
    final box = Hive.box(HiveBoxes.userBox);
    final String? token = box.get('auth_token')?.toString();

    if (token == null || token.isEmpty) {
      Get.snackbar('Error', 'Missing auth token. Please log in again.');
      return false;
    }

    isSending.value = true;
    try {
      // POSitional signature: postJson(String endpoint, Map body, {String? token})
      final res = await ApiService.postJson(
        'delete-otp',
        {'phone_number': phone},
        token: token,
      );

      isSending.value = false;

      if (res is Map && res['success'] == true) {
        Get.snackbar('Success', (res['message'] ?? 'Code sent successfully').toString());
        return true;
      } else {
        final msg = (res is Map ? res['message'] : null) ?? 'Failed to send code';
        Get.snackbar('Error', msg.toString());
        return false;
      }
    } catch (e) {
      isSending.value = false;
      Get.snackbar('Error', 'Failed to send code: $e');
      return false;
    }
  }
}
