// lib/modules/setup/kids/kids_setup_screen.dart
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:collection/collection.dart';

import 'package:dating_app/themesfolder/theme.dart';
import 'package:dating_app/services/api_services.dart';
import '../../../../../services/profileasnwerservices.dart';
// Use the correct import for your app. If your ProfileController lives under Dashboard,
// keep the following line; otherwise switch to '../../../../profile/profile_controller.dart'.
import '../../../Dashbaord/profile/profile_controller.dart';

/// ------------------------------------------------------------
/// Service – POST /kids with { answer_id }
/// ------------------------------------------------------------
class SetupKidsService {
  static Future<void> send({required int answerId}) async {
    final payload = {'answer_id': answerId};
    final res = await ApiService.post('kids', payload, isJson: true);

    if (res == null) throw Exception('No response from server');
    if ((res['success'] == false) || ((res['code'] ?? 200) >= 400)) {
      throw Exception(res['message']?.toString() ?? 'Save failed');
    }

    // Keep local cache in sync for instant preselects on revisit
    ProfileAnswersService.setAnswerId(33, answerId);

    // Hard-refresh the profile so the main screen updates immediately
    if (Get.isRegistered<ProfileController>()) {
      await Get.find<ProfileController>().fetchProfile();
    }
  }
}

/// ------------------------------------------------------------
/// Shared UI pieces (identical look to settings UIs)
/// ------------------------------------------------------------
class _HeaderBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  const _HeaderBar({required this.title, Key? key}) : super(key: key);

  @override
  Size get preferredSize => const Size.fromHeight(56);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: Colors.black),
        onPressed: () => Navigator.pop(context, true),
      ),
      title: Text(title, style: Theme.of(context).textTheme.bodyLarge),
      centerTitle: false,
    );
  }
}

class _RadioOptionTile extends StatelessWidget {
  final String label;
  final String groupValue;
  final ValueChanged<String?> onChanged;

  const _RadioOptionTile({
    required this.label,
    required this.groupValue,
    required this.onChanged,
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final bool isSelected = groupValue == label;

    return RadioListTile<String>(
      contentPadding: const EdgeInsets.symmetric(horizontal: 0, vertical: 0),
      dense: true,
      value: label,
      groupValue: groupValue,
      activeColor: Colors.black,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: const VisualDensity(horizontal: -2, vertical: -2),
      onChanged: onChanged,
      title: Text(
        label,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: isSelected ? Colors.black : Colors.grey.shade700,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _BottomButton extends StatelessWidget {
  final String text;
  final bool enabled;
  final bool loading;
  final VoidCallback? onPressed;

  const _BottomButton({
    required this.text,
    required this.enabled,
    required this.loading,
    required this.onPressed,
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
        child: SizedBox(
          height: 54,
          width: double.infinity,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: enabled ? Colors.black : Colors.black12,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              elevation: enabled ? 2 : 0,
            ),
            onPressed: enabled && !loading ? onPressed : null,
            child: loading
                ? const SizedBox(
              height: 22,
              width: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
                : const Text(
              'Next',
              style: TextStyle(fontSize: 16, color: Colors.white),
            ),
          ),
        ),
      ),
    );
  }
}

/// ------------------------------------------------------------
/// Kids mappings (same ids & labels as settings)
/// ------------------------------------------------------------
const _kidsMap = <String, int>{
  "Have kids": 87,
  "Don't have kids": 88,
  "Want kids": 89,
  "Open to them": 90,
  "Not sure": 91,
};

/// ------------------------------------------------------------
/// Controller – mirrors BaseLabelSelectController behavior,
/// but submits via POST /kids and navigates forward.
/// ------------------------------------------------------------
class SetupKidsController extends GetxController {
  final selected = ''.obs;
  final isHydrating = false.obs;
  final isSaving = false.obs;

  List<String> get options => _kidsMap.keys.toList(growable: false);

  @override
  void onInit() {
    super.onInit();
    _hydrate();
  }

  Future<void> _hydrate() async {
    isHydrating.value = true;
    try {
      // 1) Prefer explicit arg
      final int? argAnswerId = Get.arguments?['answer_id'] as int?;
      if (argAnswerId != null) {
        final match = _kidsMap.entries.firstWhereOrNull((e) => e.value == argAnswerId);
        if (match != null) {
          selected.value = match.key;
          return;
        }
      }

      // 2) Local cache
      final cached = await ProfileAnswersService.getAnswerId(33);
      if (cached != null) {
        final match = _kidsMap.entries.firstWhereOrNull((e) => e.value == cached);
        if (match != null) {
          selected.value = match.key;
          return;
        }
      }

      // 3) Fallback: refresh profile, then read cache again
      if (Get.isRegistered<ProfileController>()) {
        await Get.find<ProfileController>().fetchProfile();
        final cached2 = await ProfileAnswersService.getAnswerId(33);
        if (cached2 != null) {
          final match2 = _kidsMap.entries.firstWhereOrNull((e) => e.value == cached2);
          if (match2 != null) {
            selected.value = match2.key;
            return;
          }
        }
      }
    } finally {
      isHydrating.value = false;
    }
  }

  void selectOption(String label) {
    if (options.contains(label)) selected.value = label;
  }

  Future<void> submit() async {
    if (selected.value.isEmpty) throw Exception('Please select an option');
    final id = _kidsMap[selected.value];
    if (id == null) throw Exception('Invalid selection');

    isSaving.value = true;
    try {
      await SetupKidsService.send(answerId: id);
      ScaffoldMessenger.of(Get.context!).showSnackBar(
        const SnackBar(content: Text('Saved')),
      );
      // match your setup flow: go to /pets
      Get.toNamed('/yourhabbit');
    } catch (e) {
      ScaffoldMessenger.of(Get.context!).showSnackBar(
        SnackBar(content: Text('Failed: $e')),
      );
    } finally {
      isSaving.value = false;
    }
  }
}

/// ------------------------------------------------------------
/// Scaffold – identical layout to your settings screens
/// ------------------------------------------------------------
class _SingleSelectScaffold extends StatelessWidget {
  final String title;
  final String? blurb;
  final List<String> options;
  final RxString selected;
  final RxBool isHydrating;
  final RxBool isSaving;
  final void Function(String) onTap;
  final VoidCallback onSave;

  const _SingleSelectScaffold({
    required this.title,
    this.blurb,
    required this.options,
    required this.selected,
    required this.isHydrating,
    required this.isSaving,
    required this.onTap,
    required this.onSave,
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: _HeaderBar(title: title),
      body: Obx(() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (blurb != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 12),
              child: Text(
                blurb!,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.black54,
                  height: 1.35,
                ),
              ),
            ),
          if (isHydrating.value)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: LinearProgressIndicator(minHeight: 2),
            ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: ListView.builder(
                physics: const BouncingScrollPhysics(),
                itemCount: options.length,
                itemBuilder: (_, i) {
                  final label = options[i];
                  return _RadioOptionTile(
                    label: label,
                    groupValue: selected.value,
                    onChanged: (val) => onTap(label),
                  );
                },
              ),
            ),
          ),
          _BottomButton(
            text: 'Next',
            enabled: selected.value.isNotEmpty,
            loading: isSaving.value,
            onPressed: onSave,
          ),
        ],
      )),
    );
  }
}

/// ------------------------------------------------------------
/// Screen – uses the same visual components as settings
/// ------------------------------------------------------------
class KidsSetupScreen extends StatelessWidget {
  const KidsSetupScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final c = Get.put(SetupKidsController());
    return _SingleSelectScaffold(
      title: "Kids",
      options: c.options,
      selected: c.selected,
      isHydrating: c.isHydrating,
      isSaving: c.isSaving,
      onTap: c.selectOption,
      onSave: c.submit,
    );
  }
}
