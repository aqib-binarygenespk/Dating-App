import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../themesfolder/theme.dart';
import 'bonding_controller.dart';

class BondingMomentsScreen extends StatelessWidget {
  const BondingMomentsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final args = Get.arguments;
    final bool fromEdit = (args is Map && args['fromEdit'] == true);

    // Ensure a fresh controller every time you open this screen
    if (Get.isRegistered<BondingMomentsController>()) {
      Get.delete<BondingMomentsController>();
    }
    final controller = Get.put(BondingMomentsController(fromEdit: fromEdit));

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Bonding Moments',
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            fontSize: 24,
            fontWeight: FontWeight.w700,
          ),
        ),
        centerTitle: false,
      ),
      body: Obx(() {
        if (controller.isLoading.value) {
          return const Center(child: CircularProgressIndicator());
        }
        if (controller.rows.isEmpty) {
          return const Center(child: Text('No options found.'));
        }

        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          itemCount: controller.rows.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, i) {
            final row = controller.rows[i];
            return Row(
              children: [
                Expanded(
                  child: Obx(() => _ChoiceTile(
                    label: row.left.label,
                    isSelected: controller.isSelected(i, 0),
                    onTap: () => controller.toggleRow(i, 0),
                  )),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Obx(() => _ChoiceTile(
                    label: row.right.label,
                    isSelected: controller.isSelected(i, 1),
                    onTap: () => controller.toggleRow(i, 1),
                  )),
                ),
              ],
            );
          },
        );
      }),
      bottomNavigationBar: Obx(() {
        final canSubmit = controller.canSubmit;
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          child: SizedBox(
            height: 56,
            width: double.infinity,
            child: ElevatedButton(
              onPressed: canSubmit ? () => controller.submit() : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: Text(
                canSubmit ? 'Next' : 'Next',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        );
      }),
    );
  }
}

class _ChoiceTile extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _ChoiceTile({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bg = AppTheme.backgroundColor;
    final Color borderColor = isSelected ? Colors.black : Colors.black12;

    // selected = black, unselected = grey, no bold
    final textStyle = Theme.of(context).textTheme.titleMedium!.copyWith(
      color: isSelected ? Colors.black : Colors.grey.shade700,
    );

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor, width: isSelected ? 2 : 1),
          boxShadow: const [
            BoxShadow(
              blurRadius: 6,
              spreadRadius: 0,
              offset: Offset(0, 2),
              color: Color(0x10000000),
            ),
          ],
        ),
        child: Row(
          children: [
            _RadioCircle(selected: isSelected),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: textStyle,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RadioCircle extends StatelessWidget {
  final bool selected;
  const _RadioCircle({required this.selected});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Colors.black, width: 2),
        color: Colors.transparent,
      ),
      child: selected
          ? Center(
        child: Container(
          width: 12,
          height: 12,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.black,
          ),
        ),
      )
          : null,
    );
  }
}
