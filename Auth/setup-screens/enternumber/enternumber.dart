import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl_phone_field/intl_phone_field.dart';
import '../../../themesfolder/theme.dart';
import 'enternumber_controller.dart';


class LoginWithPhoneScreen extends StatelessWidget {
  const LoginWithPhoneScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final LoginWithPhoneController controller = Get.put(LoginWithPhoneController());

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Login with Phone',
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: false,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "If you signed up with your phone number, please enter it to login",
              style: TextStyle(
                fontSize: 16,
                color: Colors.black54,
              ),
            ),
            const SizedBox(height: 20),
            IntlPhoneField(
              decoration: InputDecoration(
                hintText: "Enter Phone Number",
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12.0),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(
                  vertical: 15.0,
                  horizontal: 10.0,
                ),
              ),
              initialCountryCode: 'US',
              onChanged: (phone) {
                controller.updatePhoneNumber(phone.completeNumber);
              },
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                controller.sendCode();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12.0),
                ),
                minimumSize: const Size(double.infinity, 50),
              ),
              child: const Text(
                "Send Code",
                style: TextStyle(color: Colors.white),
              ),
            ),
            const SizedBox(height: 20),
            Obx(() => Text(
              "Current Phone: ${controller.phoneNumber.value}",
              style: const TextStyle(fontSize: 14, color: Colors.black),
            )),
          ],
        ),
      ),
    );
  }
}
