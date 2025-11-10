import 'package:get/get.dart';

class LoginWithPhoneController extends GetxController {
  var phoneNumber = ''.obs;

  void updatePhoneNumber(String number) {
    phoneNumber.value = number;
    print('Phone updated: $number');
  }

  void sendCode() {
    if (phoneNumber.value.isEmpty) {
      print('Please enter a phone number');
    } else {
      print('Sending code to: ${phoneNumber.value}');
      // Add API call or next navigation logic here.
    }
  }
}
