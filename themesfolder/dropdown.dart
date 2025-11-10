import 'package:flutter/material.dart';

class CustomDropdown extends StatelessWidget {
  final List<String> options;
  final String? selectedValue;
  final String hintText;
  final ValueChanged<String?>? onChanged;
  final Color? fillColor;
  final String? Function(String?)? validator;

  const CustomDropdown({
    super.key,
    required this.options,
    this.selectedValue,
    required this.hintText,
    this.onChanged,
    this.fillColor,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return FormField<String>(
      initialValue: selectedValue,
      validator: validator,
      builder: (FormFieldState<String> state) {
        final hasError = state.hasError;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InputDecorator(
              decoration: InputDecoration(
                filled: true,
                fillColor: fillColor ?? Colors.white,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                hintText: hintText,
                hintStyle: const TextStyle(
                  color: Colors.grey,
                  fontSize: 14,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(
                    color: hasError ? const Color(0xFFEF4444) : Colors.black26,
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(
                    color: hasError ? const Color(0xFFEF4444) : Colors.black26,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(
                    color: hasError ? const Color(0xFFEF4444) : Colors.black87,
                  ),
                ),
                errorStyle: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w400,
                  color: Color(0xFFEF4444),
                ),
              ),
              isEmpty: selectedValue == null || selectedValue!.isEmpty,
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  isExpanded: true,
                  value: selectedValue?.isNotEmpty == true ? selectedValue : null,
                  icon: const Icon(Icons.keyboard_arrow_down),
                  dropdownColor: fillColor ?? Colors.white,
                  style: const TextStyle(fontSize: 14, color: Colors.black),
                  hint: Text(
                    hintText,
                    style: const TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                  items: options
                      .map((String value) => DropdownMenuItem<String>(
                    value: value,
                    child: Text(
                      value,
                      style: const TextStyle(fontSize: 14),
                    ),
                  ))
                      .toList(),
                  onChanged: (newValue) {
                    onChanged?.call(newValue);
                    state.didChange(newValue);
                  },
                ),
              ),
            ),
            if (hasError)
              Padding(
                padding: const EdgeInsets.only(top: 6, left: 4),
                child: Text(
                  state.errorText!,
                  style: const TextStyle(
                    color: Color(0xFFEF4444),
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
