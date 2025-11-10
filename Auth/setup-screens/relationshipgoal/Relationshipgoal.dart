// UI (keep your existing location/filename)
// Adds: textCapitalization + CapitalizeFirstLetterFormatter to enforce leading capital
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:hive/hive.dart';
import '../../../Dashbaord/settingspages/profilesettings/editprofilecontroller.dart';
import '../../../services/api_services.dart';
import '../../../hive_utils/hive_boxes.dart';
import '../../../themesfolder/theme.dart';

class Relationshipgoal extends StatefulWidget {
  final bool fromEdit;

  const Relationshipgoal({super.key, this.fromEdit = false});

  @override
  State<Relationshipgoal> createState() => _RelationshipgoalState();
}

class _RelationshipgoalState extends State<Relationshipgoal> {
  final TextEditingController _controller = TextEditingController();
  final int _maxLength = 300;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // Prefill from Hive, ensuring first char capital
    final box = Hive.box(HiveBoxes.userBox);
    final saved = box.get('relationship_goal');
    if (saved is String && saved.trim().isNotEmpty) {
      _controller.text = _ensureFirstLetterCapital(saved.trim());
    }
  }

  Future<void> _submitGoal() async {
    final token = Hive.box(HiveBoxes.userBox).get('auth_token') ??
        Hive.box(HiveBoxes.userBox).get('token') ??
        Hive.box(HiveBoxes.userBox).get('access_token');

    final box = Hive.box(HiveBoxes.userBox);
    String text = _controller.text.trim();
    text = _ensureFirstLetterCapital(text);

    if (token == null) {
      Get.snackbar("Error", "Missing token. Please log in again.");
      return;
    }

    if (text.isEmpty) {
      Get.snackbar("Error", "Please enter your relationship goals.");
      return;
    }

    if (text.length > _maxLength) {
      text = text.substring(0, _maxLength);
      _controller.text = text;
      _controller.selection = TextSelection.fromPosition(
        TextPosition(offset: _controller.text.length),
      );
    }

    setState(() {
      _isLoading = true;
    });

    // Save locally
    box.put('relationship_goal', text);

    if (widget.fromEdit) {
      try {
        final controller = Get.put(EditProfileController());
        await controller.updateProfile([
          {"question_id": 4, "answer": text}
        ]);
        Get.back(result: true);
      } catch (e) {
        Get.snackbar("Error", "Update failed. Please try again.");
      } finally {
        setState(() => _isLoading = false);
      }
    } else {
      try {
        final response = await ApiService.post(
          'relationship-goals',
          {'relationship_goals': text},
          token: token,
        );

        if (response['success'] == true) {
          Get.snackbar("Success", response['message'] ?? "Goals saved");
          Get.toNamed('/yourhabbit');
        } else {
          Get.snackbar("Error", response['message'] ?? "Submission failed");
        }
      } catch (e) {
        Get.snackbar("Error", "Something went wrong.");
      } finally {
        setState(() => _isLoading = false);
      }
    }
  }

  String _ensureFirstLetterCapital(String input) {
    if (input.isEmpty) return input;
    final first = input[0].toUpperCase();
    final rest = input.length > 1 ? input.substring(1) : '';
    return '$first$rest';
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      resizeToAvoidBottomInset: true, // ✅ Important
      appBar: AppBar(
        backgroundColor: AppTheme.backgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context, true),
        ),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            padding: EdgeInsets.only(
              left: 24,
              right: 24,
              bottom: MediaQuery.of(context).viewInsets.bottom + 24,
              top: 0,
            ),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: IntrinsicHeight(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 16),
                    Text("Relationship goal",
                        style: Theme.of(context).textTheme.bodyLarge),
                    const SizedBox(height: 8),
                    Text(
                      "Share what you're looking for on The PairUp. Be authentic, open, and let others know what kind of relationship you want to build.",
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 24),
                    TextField(
                      controller: _controller,
                      maxLength: _maxLength,
                      maxLengthEnforcement: MaxLengthEnforcement.enforced,
                      maxLines: 5,
                      keyboardType: TextInputType.multiline,
                      textInputAction: TextInputAction.newline,
                      // ✅ Suggest capital letter on keyboards
                      textCapitalization: TextCapitalization.sentences,
                      // ✅ Enforce first character uppercase regardless of keyboard
                      inputFormatters: const [CapitalizeFirstLetterFormatter()],
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
                        contentPadding:
                        const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                      ),
                      onChanged: (text) => setState(() {}),
                    ),
                    const Spacer(),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.black87,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: _isLoading ? null : _submitGoal,
                        child: _isLoading
                            ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                            : Text(
                          widget.fromEdit ? 'Save' : 'Next',
                          style: const TextStyle(
                              fontSize: 16, color: Colors.white),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Formatter that forces the very first character to uppercase,
/// preserving cursor position for a natural typing feel.
class CapitalizeFirstLetterFormatter extends TextInputFormatter {
  const CapitalizeFirstLetterFormatter();

  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    final text = newValue.text;
    if (text.isEmpty) return newValue;

    final first = text[0].toUpperCase();
    final rest = text.length > 1 ? text.substring(1) : '';
    final transformed = '$first$rest';

    if (transformed == text) return newValue;

    return newValue.copyWith(
      text: transformed,
      selection: TextSelection(
        baseOffset: newValue.selection.baseOffset,
        extentOffset: newValue.selection.extentOffset,
      ),
      composing: TextRange.empty,
    );
  }
}
