import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import 'personaldetails_controller.dart';
import '../../../themesfolder/theme.dart';
import 'package:dating_app/themesfolder/textfields.dart';

/// --- Reusable formatters ---

/// Capitalizes the first non-space character.
class FirstLetterUpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue,
      TextEditingValue newValue,
      ) {
    final text = newValue.text;
    if (text.isEmpty) return newValue;

    final firstNonSpace = text.split('').indexWhere((c) => c.trim().isNotEmpty);
    if (firstNonSpace == -1) return newValue;

    final chars = text.split('');
    chars[firstNonSpace] = chars[firstNonSpace].toUpperCase();

    return newValue.copyWith(
      text: chars.join(''),
      selection: newValue.selection,
      composing: TextRange.empty,
    );
  }
}

/// Formats date input as MM/dd/yyyy
class DobSlashFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue,
      TextEditingValue newValue,
      ) {
    final digitsOnly = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    final clipped = digitsOnly.length > 8 ? digitsOnly.substring(0, 8) : digitsOnly;

    String formatted = '';
    for (int i = 0; i < clipped.length; i++) {
      if (i == 2 || i == 4) formatted += '/';
      formatted += clipped[i];
    }

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

class ProfileDetails extends StatelessWidget {
  const ProfileDetails({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(ProfileDetailsController());

    OutlineInputBorder _inputBorder(Color color, double width) =>
        OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: color, width: width),
        );

    Widget _buildGenderField() {
      return Obx(() {
        final selected = controller.selectedGender.value.isEmpty
            ? null
            : controller.selectedGender.value;

        return DropdownButtonFormField<String>(
          initialValue: selected,
          isExpanded: true,
          items: controller.genderOptions
              .map(
                (g) => DropdownMenuItem<String>(
              value: g,
              child: Text(g, style: const TextStyle(color: Colors.black87)),
            ),
          )
              .toList(),
          onChanged: (val) {
            controller.selectedGender.value = val ?? '';
            controller.showGenderError.value =
                controller.selectedGender.value.isEmpty;
          },
          validator: (val) {
            if (val == null || val.isEmpty) return 'This field is required';
            return null;
          },
          decoration: InputDecoration(
            hintText: 'Select gender',
            hintStyle: TextStyle(color: Colors.grey[600], fontSize: 14),
            filled: true,
            fillColor: AppTheme.backgroundColor,
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
            enabledBorder: _inputBorder(const Color(0xFFE8BDBD), 1.2),
            focusedBorder: _inputBorder(const Color(0xFFE8BDBD), 1.6),
            errorBorder: _inputBorder(Colors.redAccent, 1.4),
            focusedErrorBorder: _inputBorder(Colors.redAccent, 1.6),
          ),
          dropdownColor: AppTheme.backgroundColor,
        );
      });
    }

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      // ✅ Ensure Scaffold re-layouts when keyboard appears
      resizeToAvoidBottomInset: true,

      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          "Profile Details",
          style: Theme.of(context)
              .textTheme
              .bodyLarge
              ?.copyWith(fontWeight: FontWeight.w600),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
      ),

      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: controller.formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // First Name
              Text("First Name", style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              CustomTextField(
                hintText: "Enter your first name",
                keyboardType: TextInputType.name,
                controller: controller.firstNameController,
                fillColor: AppTheme.backgroundColor,
                validator: controller.requiredValidator,
                textCapitalization: TextCapitalization.words,
                inputFormatters: [FirstLetterUpperCaseTextFormatter()],
              ),
              const SizedBox(height: 16),

              // Last Name
              Text("Last Name", style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              CustomTextField(
                hintText: "Enter your last name",
                keyboardType: TextInputType.name,
                controller: controller.lastNameController,
                fillColor: AppTheme.backgroundColor,
                validator: controller.requiredValidator,
                textCapitalization: TextCapitalization.words,
                inputFormatters: [FirstLetterUpperCaseTextFormatter()],
              ),
              const SizedBox(height: 16),

              // Email
              Text("Email", style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              CustomTextField(
                hintText: "Enter your email",
                keyboardType: TextInputType.emailAddress,
                controller: controller.emailController,
                fillColor: AppTheme.backgroundColor,
                validator: controller.emailValidator,
              ),
              const SizedBox(height: 16),

              // Gender
              Text("Gender", style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              _buildGenderField(),
              const SizedBox(height: 16),

              // DOB
              Text("Date of Birth", style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              TextFormField(
                controller: controller.dobController,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  DobSlashFormatter(),
                ],
                style: const TextStyle(
                  color: Colors.black87,
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                ),
                decoration: InputDecoration(
                  hintText: "MM/dd/yyyy",
                  hintStyle: TextStyle(color: Colors.grey[600], fontSize: 14),
                  filled: true,
                  fillColor: AppTheme.backgroundColor,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
                  enabledBorder: _inputBorder(const Color(0xFFE8BDBD), 1.2),
                  focusedBorder: _inputBorder(const Color(0xFFE8BDBD), 1.6),
                  errorBorder: _inputBorder(Colors.redAccent, 1.4),
                  focusedErrorBorder: _inputBorder(Colors.redAccent, 1.6),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.calendar_today_outlined, color: Colors.black54),
                    onPressed: () => controller.pickDate(context),
                  ),
                ),
                validator: (val) {
                  if (val == null || val.isEmpty) return 'This field is required';
                  final regex = RegExp(r'^\d{2}/\d{2}/\d{4}$');
                  if (!regex.hasMatch(val)) return 'Enter a valid date (MM/dd/yyyy)';
                  try {
                    final parts = val.split('/');
                    final mm = int.parse(parts[0]);
                    final dd = int.parse(parts[1]);
                    final yyyy = int.parse(parts[2]);
                    if (mm < 1 || mm > 12) return 'Invalid month';
                    if (dd < 1 || dd > 31) return 'Invalid day';
                    final parsed = DateTime(yyyy, mm, dd);
                    if (parsed.month != mm || parsed.day != dd || parsed.year != yyyy) {
                      return 'Invalid date';
                    }
                  } catch (_) {
                    return 'Invalid date';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),

      // ✅ Bottom button that moves with the keyboard
      bottomNavigationBar: AnimatedPadding(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom, // keyboard height
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  controller.showGenderError.value =
                      controller.selectedGender.value.isEmpty;
                  if ((controller.formKey.currentState?.validate() ?? false) &&
                      controller.selectedGender.value.isNotEmpty) {
                    controller.submitProfileInformation();
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF111827),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: const Text("Next", style: TextStyle(fontSize: 16)),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
