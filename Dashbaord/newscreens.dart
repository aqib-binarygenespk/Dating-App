// lib/modules/profile/edit/common_single_select_screens.dart
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:collection/collection.dart';

import 'package:dating_app/themesfolder/theme.dart';
import 'package:dating_app/services/api_services.dart';
import '../../../../../services/profileasnwerservices.dart';
import '../../../../profile/profile_controller.dart';

class UpdateProfileService {
  static Future<void> sendSingleAnswer({
    required int questionId,
    required int answerId,
  }) async {
    final payload = {
      'answers': [
        {'question_id': questionId, 'answer_id': answerId}
      ]
    };

    final res = await ApiService.put('update-profile', payload, isJson: true);
    if (res == null) throw Exception('No response from server');
    if ((res['success'] == false) || ((res['code'] ?? 200) >= 400)) {
      throw Exception(res['message']?.toString() ?? 'Update failed');
    }

    ProfileAnswersService.setAnswerId(questionId, answerId);

    if (Get.isRegistered<ProfileController>()) {
      await Get.find<ProfileController>().fetchProfile();
    }
  }
}

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
                : Text(
              text,
              style: TextStyle(fontSize: 16, color: Colors.white),
            ),
          ),
        ),
      ),
    );
  }
}

abstract class BaseLabelSelectController extends GetxController {
  int get questionId;
  List<String> get options;
  Map<String, int> get labelToId;

  final selected = ''.obs;
  final isHydrating = false.obs;
  final isSaving = false.obs;

  @override
  void onInit() {
    super.onInit();
    _hydrate();
  }

  Future<void> _hydrate() async {
    isHydrating.value = true;
    try {
      final int? argAnswerId = Get.arguments?['answer_id'] as int?;
      if (argAnswerId != null) {
        final match = labelToId.entries.firstWhereOrNull((e) => e.value == argAnswerId);
        if (match != null) {
          selected.value = match.key;
          return;
        }
      }

      final cached = await ProfileAnswersService.getAnswerId(questionId);
      if (cached != null) {
        final match = labelToId.entries.firstWhereOrNull((e) => e.value == cached);
        if (match != null) {
          selected.value = match.key;
          return;
        }
      }

      if (Get.isRegistered<ProfileController>()) {
        await Get.find<ProfileController>().fetchProfile();
        final cached2 = await ProfileAnswersService.getAnswerId(questionId);
        if (cached2 != null) {
          final match2 = labelToId.entries.firstWhereOrNull((e) => e.value == cached2);
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
    if (selected.value.isEmpty) return;
    final id = labelToId[selected.value];
    if (id == null) return;

    isSaving.value = true;
    try {
      await UpdateProfileService.sendSingleAnswer(
        questionId: questionId,
        answerId: id,
      );
      ScaffoldMessenger.of(Get.context!).showSnackBar(
        const SnackBar(content: Text('Saved')),
      );
      Get.back(result: true);
    } catch (e) {
      ScaffoldMessenger.of(Get.context!).showSnackBar(
        SnackBar(content: Text('Failed: $e')),
      );
    } finally {
      isSaving.value = false;
    }
  }
}

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
            text: 'Update',
            enabled: selected.value.isNotEmpty,
            loading: isSaving.value,
            onPressed: onSave,
          ),
        ],
      )),
    );
  }
}

// MAPPINGS

const _kidsMap = <String, int>{
  "Have kids": 87,
  "Don't have kids": 88,
  "Want kids": 89,
  "Open to them": 90,
  "Not sure": 91,
};

const _childrenPlansMap = <String, int>{
  "Open to kids": 90,
  "Want kids": 89,
  "Not sure": 91,
};

const _politicalMap = <String, int>{
  "Apolitical": 92,
  "Moderate": 93,
  "Liberal": 94,
  "Conservative": 95,
};

const _religionMap = <String, int>{
  "No Preference": 96,
  "Christian": 97,
  "Catholic": 98,
  "Jewish": 99,
  "Muslim": 100,
  "Unitarian / Universalist": 101,
  "Buddhist": 102,
  "Hindu": 103,
  "Agnostic": 104,
  "Atheist": 105,
  "Other": 106,
};

const _educationMap = <String, int>{
  "High school": 107,
  "Trade/tech school": 108,
  "In college": 109,
  "Undergraduate degree": 110,
  "In grad school": 111,
  "Graduate degree": 112,
};

const _zodiacMap = <String, int>{
  "Aries": 113,
  "Taurus": 114,
  "Gemini": 115,
  "Cancer": 116,
  "Leo": 117,
  "Virgo": 118,
  "Libra": 119,
  "Scorpio": 120,
  "Sagittarius": 121,
  "Capricorn": 122,
  "Aquarius": 123,
  "Pisces": 124,
};

const _workoutMap = <String, int>{
  "Active": 21,
  "Sometimes": 22,
  "Almost never": 23,
};

// SCREENS + CONTROLLERS

class _ZodiacController extends BaseLabelSelectController {
  @override
  int get questionId => 37;

  @override
  List<String> get options => _zodiacMap.keys.toList(growable: false);

  @override
  Map<String, int> get labelToId => _zodiacMap;
}

class ZodiacSignScreen extends StatelessWidget {
  const ZodiacSignScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final c = Get.put(_ZodiacController());
    return _SingleSelectScaffold(
      title: "What's your zodiac sign?",
      options: c.options,
      selected: c.selected,
      isHydrating: c.isHydrating,
      isSaving: c.isSaving,
      onTap: c.selectOption,
      onSave: c.submit,
    );
  }
}

class _EducationController extends BaseLabelSelectController {
  @override
  int get questionId => 36;

  @override
  List<String> get options => _educationMap.keys.toList(growable: false);

  @override
  Map<String, int> get labelToId => _educationMap;
}

class EducationScreen extends StatelessWidget {
  const EducationScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final c = Get.put(_EducationController());
    return _SingleSelectScaffold(
      title: "What's your education?",
      options: c.options,
      selected: c.selected,
      isHydrating: c.isHydrating,
      isSaving: c.isSaving,
      onTap: c.selectOption,
      onSave: c.submit,
    );
  }
}

class _ReligionController extends BaseLabelSelectController {
  @override
  int get questionId => 35;

  @override
  List<String> get options => _religionMap.keys.toList(growable: false);

  @override
  Map<String, int> get labelToId => _religionMap;
}

class ReligionScreen extends StatelessWidget {
  const ReligionScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final c = Get.put(_ReligionController());
    return _SingleSelectScaffold(
      title: "Religion",
      options: c.options,
      selected: c.selected,
      isHydrating: c.isHydrating,
      isSaving: c.isSaving,
      onTap: c.selectOption,
      onSave: c.submit,
    );
  }
}

class _PoliticalViewsController extends BaseLabelSelectController {
  @override
  int get questionId => 34;

  @override
  List<String> get options => _politicalMap.keys.toList(growable: false);

  @override
  Map<String, int> get labelToId => _politicalMap;
}

class PoliticalViewsScreen extends StatelessWidget {
  const PoliticalViewsScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final c = Get.put(_PoliticalViewsController());
    return _SingleSelectScaffold(
      title: "What are your political views?",
      blurb:
      "This is sensitive information that'll be on your profile. "
          "It helps you find people, and people find you. It's totally optional.",
      options: c.options,
      selected: c.selected,
      isHydrating: c.isHydrating,
      isSaving: c.isSaving,
      onTap: c.selectOption,
      onSave: c.submit,
    );
  }
}

class _KidsController extends BaseLabelSelectController {
  @override
  int get questionId => 33;

  @override
  List<String> get options => _kidsMap.keys.toList(growable: false);

  @override
  Map<String, int> get labelToId => _kidsMap;
}

class KidsScreen extends StatelessWidget {
  const KidsScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final c = Get.put(_KidsController());
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

class _ChildrenPlansController extends BaseLabelSelectController {
  @override
  int get questionId => 33;

  @override
  List<String> get options => _childrenPlansMap.keys.toList(growable: false);

  @override
  Map<String, int> get labelToId => _childrenPlansMap;
}

class ChildrenPlansScreen extends StatelessWidget {
  const ChildrenPlansScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final c = Get.put(_ChildrenPlansController());
    return _SingleSelectScaffold(
      title: "What are your ideal plans for children?",
      options: c.options,
      selected: c.selected,
      isHydrating: c.isHydrating,
      isSaving: c.isSaving,
      onTap: c.selectOption,
      onSave: c.submit,
    );
  }
}

class _WorkoutController extends BaseLabelSelectController {
  @override
  int get questionId => 32;

  @override
  List<String> get options => _workoutMap.keys.toList(growable: false);

  @override
  Map<String, int> get labelToId => _workoutMap;
}

class WorkoutScreen extends StatelessWidget {
  const WorkoutScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final c = Get.put(_WorkoutController());
    return _SingleSelectScaffold(
      title: "Do you work out?",
      options: c.options,
      selected: c.selected,
      isHydrating: c.isHydrating,
      isSaving: c.isSaving,
      onTap: c.selectOption,
      onSave: c.submit,
    );
  }
}
