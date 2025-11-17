import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../../themesfolder/theme.dart';
import '../../../../dashboard/Dashboard.dart'; // <-- must export settingsNavId
import 'editbondingmomentcontroller.dart' hide settingsNavId;

class EditBondingMomentsScreen extends StatefulWidget {
  const EditBondingMomentsScreen({super.key});

  @override
  State<EditBondingMomentsScreen> createState() => _EditBondingMomentsScreenState();
}

class _EditBondingMomentsScreenState extends State<EditBondingMomentsScreen> {
  late final EditBondingMomentsController controller;

  @override
  void initState() {
    super.initState();
    controller = Get.put(EditBondingMomentsController());
    controller.refreshFromServer();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          Get.back(id: settingsNavId, result: false);
        }
      },
      child: Scaffold(
        backgroundColor: AppTheme.backgroundColor,
        appBar: AppBar(
          centerTitle: false,
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.black),
            onPressed: () => Get.back(id: settingsNavId, result: false),
          ),
          title: Text(
            'Edit Bonding Moments',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
        ),

        body: Obx(() {
          if (controller.isLoading.value && controller.bondingOptions.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }
          if (controller.visibleRowIndices.isEmpty || controller.bondingOptions.isEmpty) {
            return const Center(child: Text('No options found.'));
          }

          final int selectedCount = controller.selectedOptions.values
              .where((v) => (v?.trim().isNotEmpty ?? false))
              .length;

          return Column(
            children: [
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  itemCount: controller.visibleRowIndices.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (_, visibleIdx) {
                    final rowIndex = controller.visibleRowIndices[visibleIdx];
                    final row = controller.bondingOptions[rowIndex];

                    final String leftText  = ((row.isNotEmpty ? row[0] : null)  ?? '').trim();
                    final String rightText = ((row.length > 1  ? row[1] : null) ?? '').trim();

                    return Row(
                      children: [
                        Expanded(
                          child: Obx(() {
                            final selectedValue = controller.selectedOptions[rowIndex];
                            return _ChoiceTile(
                              label: leftText,
                              isSelected: (selectedValue ?? '') == leftText && leftText.isNotEmpty,
                              onTap: leftText.isEmpty
                                  ? null
                                  : () => controller.toggleSelection(rowIndex, leftText),
                            );
                          }),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Obx(() {
                            final selectedValue = controller.selectedOptions[rowIndex];
                            return _ChoiceTile(
                              label: rightText,
                              isSelected: (selectedValue ?? '') == rightText && rightText.isNotEmpty,
                              onTap: rightText.isEmpty
                                  ? null
                                  : () => controller.toggleSelection(rowIndex, rightText),
                            );
                          }),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          );
        }),

        bottomNavigationBar: Obx(() {
          final int selectedCount = controller.selectedOptions.values
              .where((v) => (v?.trim().isNotEmpty ?? false))
              .length;
          final bool canSubmit = !controller.isLoading.value && selectedCount >= 3;

          return Container(
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: AppTheme.primaryColor, width: 2)),
            ),
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            child: SizedBox(
              height: 56,
              width: double.infinity,
              child: ElevatedButton(
                onPressed: canSubmit ? controller.submitUpdate : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: controller.isLoading.value
                    ? const SizedBox(
                  height: 22,
                  width: 22,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
                    : Text(
                  canSubmit ? 'Update' : 'update',
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

class _ChoiceTile extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback? onTap;

  const _ChoiceTile({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final disabled = label.isEmpty || onTap == null;
    final bg = AppTheme.backgroundColor;
    final Color borderColor = isSelected ? Colors.black : Colors.black12;

    // ✅ selected = black, unselected = grey; no bolding
    final textStyle = Theme.of(context).textTheme.titleMedium!.copyWith(
      color: isSelected ? Colors.black : Colors.grey.shade700,
    );

    final tile = Container(
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
    );

    if (disabled) return Opacity(opacity: 0.5, child: tile);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: tile,
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
