import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../../themesfolder/theme.dart';
import '../../../../pairupscreens/addevent/addevent.dart';
import 'editrelationshipcontroller.dart';

class EditRelationshipGoalScreen extends StatelessWidget {
  const EditRelationshipGoalScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(EditRelationshipGoalController());

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        backgroundColor: AppTheme.backgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context, true),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            Text("Relationship goal", style: Theme.of(context).textTheme.bodyLarge),
            const SizedBox(height: 8),
            Text(
              "Share what you're looking for on The PairUp. Be authentic, open, and let others know what kind of relationship you want to build.",
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 24),
            TextField(
              controller: controller.textController,
              maxLength: controller.maxLength,
              maxLines: 5,
              decoration: InputDecoration(
                hintText: "Describe your relationship goals...",
                filled: true,
                fillColor: AppTheme.backgroundColor,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Colors.blueAccent),
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
              ),
              inputFormatters: [SentenceCaseTextFormatter()],
            ),
            const Spacer(),
            Obx(() => SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black87,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: controller.isLoading.value ? null : controller.submit,
                child: controller.isLoading.value
                    ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                )
                    : const Text('Update', style: TextStyle(fontSize: 16, color: Colors.white)),
              ),
            )),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
