import 'dart:async';
import 'dart:convert'; // for jsonDecode
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart' show WidgetsBinding;
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../../services/api_services.dart';
import '../../../themesfolder/alertmessageprofiel/alertprofile.dart';

class ProfileDetailsController extends GetxController {
  final formKey = GlobalKey<FormState>();

  // Text controllers
  final TextEditingController firstNameController = TextEditingController();
  final TextEditingController lastNameController  = TextEditingController();
  final TextEditingController emailController     = TextEditingController();
  final TextEditingController dobController       = TextEditingController();

  // Local state
  final Rx<DateTime?> selectedDate = Rx<DateTime?>(null);
  final RxString selectedGender    = ''.obs; // must be 'male' or 'female'
  final RxBool showGenderError     = false.obs;
  final RxBool isSubmitting        = false.obs;
  final RxBool isResending         = false.obs;

  // Gender options (backend constraint)
  final List<String> genderOptions = const ['male', 'female'];

  // Session info from previous step
  late final String sessionToken;
  String? phone;
  String tokenType = 'Bearer';

  // Store last successful payload for easy resend
  Map<String, dynamic>? _lastSubmittedPayload;

  // ---- Endpoints ----
  static const String _registerEndpoint    = 'register';
  static const String _verifyEmailEndpoint = 'verifyemailcode';

  // ---------- Validators ----------
  String? requiredValidator(String? value) {
    if (value == null || value.trim().isEmpty) return "This field is required";
    return null;
  }

  String? emailValidator(String? value) {
    if (value == null || value.trim().isEmpty) return "This field is required";
    if (!GetUtils.isEmail(value.trim())) return "Please enter a valid email";
    return null;
  }

  // ---------- Date helpers ----------
  // UI format now uses slashes (matches your input formatter)
  final DateFormat _uiFmtSlash = DateFormat('MM/dd/yyyy'); // UI typing/picker
  // Legacy UI format (hyphens) - still accepted when parsing
  final DateFormat _uiFmtHyphen = DateFormat('MM-dd-yyyy');
  // API format
  final DateFormat _apiFmt = DateFormat('yyyy-MM-dd');

  String _formatForUi(DateTime date)  => _uiFmtSlash.format(date);
  String _formatForApi(DateTime date) => _apiFmt.format(date);

  int _ageInYears(DateTime dob) {
    final now = DateTime.now();
    var age = now.year - dob.year;
    final hadBirthdayThisYear =
        (now.month > dob.month) || (now.month == dob.month && now.day >= dob.day);
    if (!hadBirthdayThisYear) age--;
    return age;
  }

  /// Normalize names: trim, collapse spaces, uppercase first letter only.
  String _normalizeName(String raw) {
    final trimmed = raw.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (trimmed.isEmpty) return trimmed;
    return trimmed[0].toUpperCase() + trimmed.substring(1);
  }

  /// Try to parse DOB from controller text supporting both MM/dd/yyyy and MM-dd-yyyy.
  DateTime? _parseDobFromText(String text) {
    final t = text.trim();
    if (t.isEmpty) return null;
    // Prefer slash format (current UI)
    try {
      return _uiFmtSlash.parseStrict(t);
    } catch (_) {}
    // Fallback to legacy hyphen format
    try {
      return _uiFmtHyphen.parseStrict(t);
    } catch (_) {}
    // Last resort (ISO-like)
    return DateTime.tryParse(t);
  }

  // ---------- Lifecycle ----------
  @override
  void onInit() {
    super.onInit();
    final args = Get.arguments ?? {};
    sessionToken = (args['token'] as String?)?.trim() ?? '';
    phone        = (args['phone'] as String?)?.trim();
    tokenType    = (args['token_type'] as String?)?.trim().isNotEmpty == true
        ? (args['token_type'] as String).trim()
        : 'Bearer';

    if (sessionToken.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Get.back();
        _safeSnack("Error", "Missing registration session. Please restart.",
            bg: Colors.redAccent);
      });
    }
  }

  @override
  void onClose() {
    firstNameController.dispose();
    lastNameController.dispose();
    emailController.dispose();
    dobController.dispose();
    super.onClose();
  }

  // ---------- UI helpers ----------
  void _safeSnack(String title, String msg, {Color? bg}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (Get.isSnackbarOpen == true) Get.closeCurrentSnackbar();
      Get.snackbar(
        title,
        msg,
        backgroundColor: bg ?? Colors.black87,
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
        margin: const EdgeInsets.all(12),
      );
    });
  }

  Future<void> pickDate(BuildContext context) async {
    final now = DateTime.now();
    final initial = selectedDate.value ?? DateTime(now.year - 20, now.month, now.day);

    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(1900),
      lastDate: DateTime(now.year, now.month, now.day),
      helpText: 'Select Date of Birth',
    );

    if (picked != null) {
      selectedDate.value = picked;
      // Set in MM/dd/yyyy to match the on-type formatter
      dobController.text = _formatForUi(picked);
    }
  }

  // ---------- Build payload ----------
  Map<String, dynamic>? _buildPayload({bool validateForm = true}) {
    if (validateForm && !(formKey.currentState?.validate() ?? false)) {
      return null;
    }

    final gender = selectedGender.value.trim().toLowerCase();
    if (validateForm && (gender.isEmpty || !genderOptions.contains(gender))) {
      showGenderError.value = true;
      _safeSnack("Missing Info", "Please select your gender", bg: Colors.orange);
      return null;
    } else {
      showGenderError.value = false;
    }

    // Parse DOB from either selectedDate or typed text (slashes or hyphens)
    DateTime? dob = selectedDate.value ?? _parseDobFromText(dobController.text);
    if (validateForm && dob == null) {
      _safeSnack("Missing Info", "Please select your date of birth", bg: Colors.orange);
      return null;
    }

    // ---- Age restriction (client-side) ----
    if (validateForm && dob != null && _ageInYears(dob) < 18) {
      CustomDialog.showError(
        title: "Age restriction",
        message: "Not quite time yet—PairUp is for 18+. Come back when you’re ready to pair up for real.",
      );
      return null;
    }

    // Normalize names just before sending
    final firstName = _normalizeName(firstNameController.text);
    final lastName  = _normalizeName(lastNameController.text);

    return {
      "token":      sessionToken,
      "first_name": firstName,
      "last_name":  lastName,
      "email":      emailController.text.trim().toLowerCase(),
      "gender":     gender,
      "dob":        _formatForApi(dob ?? DateTime.now()),
    };
  }

  // ---------- Submit Profile ----------
  Future<void> submitProfileInformation() async {
    final payload = _buildPayload(validateForm: true);
    if (payload == null) return;

    try {
      isSubmitting.value = true;

      final response = await ApiService.postJson(_registerEndpoint, payload);

      if (response is Map && response['success'] == true) {
        _lastSubmittedPayload = payload;
        _safeSnack(
          "Success",
          (response['message'] ?? 'Profile saved and email OTP sent').toString(),
          bg: Colors.green,
        );

        showEmailVerificationDialog(payload['email'] as String);
      } else {
        _handleSubmitError(response);
      }
    } catch (e) {
      // Some ApiService implementations throw the raw body on non-2xx.
      // Try to parse it into JSON to extract a message.
      bool handled = false;
      if (e is String) {
        try {
          final m = jsonDecode(e);
          if (m is Map) {
            _handleSubmitError(m);
            handled = true;
          }
        } catch (_) {/* ignore */}
      }
      if (!handled) {
        CustomDialog.showError(
          title: "Something went wrong",
          message: "Please try again.\n$e",
        );
      }
    } finally {
      isSubmitting.value = false;
    }
  }

  void _handleSubmitError(dynamic response) {
    String title = "Error";
    String errorMessage = "Unknown error";

    if (response is Map) {
      // Prefer plain message if present
      final msg = (response['message'] ?? '').toString().trim();
      if (msg.isNotEmpty) {
        final lower = msg.toLowerCase();
        if (lower.contains('18')) {
          title = "Age restriction";
        } else if (lower.contains('invalid session')) {
          title = "Session Error";
        }
        errorMessage = msg;
      }

      // If backend also sends `errors`, include them safely
      final rawErrors = response['errors'];
      if (rawErrors is Map && rawErrors.isNotEmpty) {
        final errors = Map<String, dynamic>.from(
          rawErrors.map((k, v) => MapEntry(k.toString(), v)),
        );

        // Special-case DOB if present
        if (errors.containsKey('dob')) {
          title = "Age restriction";
        }

        final details = errors.entries.map((e) {
          final v = e.value;
          if (v is List) return "${e.key}: ${v.map((x) => x.toString()).join(', ')}";
          return "${e.key}: ${v.toString()}";
        }).join("\n");

        if (details.isNotEmpty) {
          errorMessage = errorMessage == "Unknown error"
              ? details
              : "$errorMessage\n$details";
        }
      }
    } else if (response is String && response.trim().isNotEmpty) {
      // Raw string response fallback
      errorMessage = response.trim();
      if (errorMessage.toLowerCase().contains('18')) {
        title = "Age restriction";
      }
    }

    CustomDialog.showError(title: title, message: errorMessage);
  }

  // ---------- Email OTP Dialog / Actions ----------
  void showEmailVerificationDialog(String email) {
    CustomDialog.showPasswordSentDialog(
      email: email,
      onConfirm: (code) => _verifyEmailOtp(code),
      onResend: _resendEmailOtp,
    );
  }

  Future<void> _resendEmailOtp() async {
    if (isResending.value) return;

    final payload = _lastSubmittedPayload ?? _buildPayload(validateForm: false);
    if (payload == null) {
      _safeSnack("Error", "Missing profile details to resend code.", bg: Colors.redAccent);
      return;
    }

    try {
      isResending.value = true;

      final res = await ApiService.postJson(_registerEndpoint, payload);

      if (res is Map && res['success'] == true) {
        _safeSnack("Code Sent", "Verification code resent to your email", bg: Colors.green);
      } else {
        final msg = (res is Map ? (res['message'] ?? 'Failed to resend code') : 'Failed to resend code').toString();
        _safeSnack("Error", msg, bg: Colors.redAccent);
      }
    } catch (e) {
      _safeSnack("Error", "Failed to resend code: $e", bg: Colors.redAccent);
    } finally {
      isResending.value = false;
    }
  }

  Future<void> _verifyEmailOtp(String code) async {
    final trimmed = code.trim();
    if (trimmed.length != 4) {
      CustomDialog.showError(
        title: "Invalid Code",
        message: "Please enter the 4-digit code.",
      );
      return;
    }

    try {
      final resp = await ApiService.postJson(_verifyEmailEndpoint, {
        "token": sessionToken,
        "otp_code": trimmed,
      });

      if (resp is Map && resp['success'] == true) {
        _safeSnack(
          "Verified",
          (resp['message'] ?? 'Email verified successfully').toString(),
          bg: Colors.green,
        );

        Get.toNamed('/EnterPassword', arguments: {
          'token': sessionToken,
          'email': emailController.text.trim().toLowerCase(),
          'phone': phone,
          'token_type': tokenType,
        });
      } else {
        final msg = (resp is Map ? (resp['message'] ?? 'Verification failed') : 'Verification failed').toString();
        final lower = msg.toLowerCase();

        if (lower.contains('invalid session')) {
          CustomDialog.showError(title: "Session Error", message: "Your session is invalid or expired. Restart registration.");
        } else if (lower.contains('invalid otp')) {
          CustomDialog.showError(title: "Invalid Code", message: "The code you entered is incorrect.");
        } else if (lower.contains('otp has expired')) {
          CustomDialog.showError(title: "Code Expired", message: "Please request a new code.");
        } else {
          CustomDialog.showError(title: "Error", message: msg);
        }
      }
    } catch (e) {
      // Try to parse thrown body
      bool handled = false;
      if (e is String) {
        try {
          final m = jsonDecode(e);
          if (m is Map) {
            _handleSubmitError(m);
            handled = true;
          }
        } catch (_) {/* ignore */}
      }
      if (!handled) {
        CustomDialog.showError(
          title: "Error",
          message: "API Error: ${e.toString()}",
        );
      }
    }
  }
}
