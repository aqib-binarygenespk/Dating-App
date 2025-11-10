import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../themesfolder/theme.dart';
import 'age_controller.dart';

class AgeSelection extends StatelessWidget {
  const AgeSelection({super.key});

  @override
  Widget build(BuildContext context) {
    final AgeSelectionController controller = Get.put(AgeSelectionController());

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: true,
        iconTheme: const IconThemeData(color: Colors.black, size: 28),
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 24),

            // Title
            Text(
              "Age",
              style: Theme.of(context).textTheme.displayLarge?.copyWith(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: Colors.black,
              ),
            ),

            const SizedBox(height: 50),

            // Slider with smaller size
            Obx(() => SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 2.0,  // Reduced track height
                activeTrackColor: Colors.black,
                inactiveTrackColor: Colors.black26,
                thumbColor: Colors.black,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8), // Smaller thumb
                overlayShape: SliderComponentShape.noOverlay,
                tickMarkShape: SliderTickMarkShape.noTickMark,
                trackShape: const RectangularSliderTrackShape(),
              ),
              child: Slider(
                value: controller.selectedAge.value,
                min: 18,
                max: 60,
                divisions: 42,
                onChanged: controller.updateAge,
              ),
            )),

            const SizedBox(height: 8),

            // Age label centered under thumb
            Center(
              child: Obx(() => Text(
                "${controller.selectedAge.toInt()} Years",
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.black,
                ),
              )),
            ),

            const Spacer(),

            // Next button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pushNamed(context, '/nextScreen');
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: const Text(
                  "Next",
                  style: TextStyle(fontSize: 16, color: Colors.white),
                ),
              ),
            ),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
