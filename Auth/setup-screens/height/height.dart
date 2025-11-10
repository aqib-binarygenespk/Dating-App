import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../themesfolder/theme.dart';
import 'height_controller.dart';

class HeightSelection extends StatelessWidget {
  final bool fromEdit;

  const HeightSelection({super.key, this.fromEdit = false});

  @override
  Widget build(BuildContext context) {
    final HeightSelectionController controller =
    Get.put(HeightSelectionController(fromEdit: fromEdit));

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: true,
        iconTheme: const IconThemeData(color: Colors.black, size: 28),
      ),
      body: Obx(() => AbsorbPointer(
        absorbing: controller.isLoading.value,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 24),

              Text(
                "Height",
                style: Theme.of(context).textTheme.bodyLarge,
              ),

              const SizedBox(height: 50),

              SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  trackHeight: 2.0,
                  activeTrackColor: Colors.black,
                  inactiveTrackColor: Colors.black26,
                  thumbColor: Colors.black,
                  thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10),
                  overlayShape: SliderComponentShape.noOverlay,
                ),
                child: Slider(
                  value: controller.heightInInches.value,
                  min: 36,
                  max: 84,
                  divisions: 48,
                  onChanged: controller.isLoading.value
                      ? null
                      : controller.updateHeight,
                ),
              ),

              const SizedBox(height: 8),

              Center(
                child: Text(
                  controller.heightInFeetAndInches,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.black,
                  ),
                ),
              ),

              const Spacer(),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: controller.isLoading.value
                      ? null
                      : controller.sendHeightToServer,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: controller.isLoading.value
                      ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                      : Text(fromEdit ? "Save" : "Next"),
                ),
              ),

              const SizedBox(height: 20),
            ],
          ),
        ),
      )),
    );
  }
}
