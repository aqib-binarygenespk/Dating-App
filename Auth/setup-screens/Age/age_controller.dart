import 'package:get/get.dart';

class AgeSelectionController extends GetxController {
  var selectedAge = 18.0.obs;

  void updateAge(double age) {
    selectedAge.value = age;
  }
}
