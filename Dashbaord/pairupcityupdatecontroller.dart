import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:hive/hive.dart';

import '../../../../../hive_utils/hive_boxes.dart';
import '../../../../../services/api_services.dart';

class EditPairUpLocationController extends GetxController {
  static const tagId = 'edit_pairup_location_controller';

  EditPairUpLocationController({
    this.initialLatLng,
    this.initialCity,
    this.initialState,
    this.initialCountry,
  });

  // ---- last-used (in-memory) cache so user sees the same value on revisit
  static String? _lastDisplay;
  static LatLng? _lastLatLng;
  static String? _lastCity, _lastState, _lastCountry, _lastPostal;

  final LatLng? initialLatLng;
  final String? initialCity;
  final String? initialState;
  final String? initialCountry;

  final TextEditingController locationController = TextEditingController();
  final isSaving = false.obs;

  final selectedLocation = Rxn<LatLng>();
  String? city, state, country, postalCode;
  String? lastSubmitMessage;

  // Hive keys for persisting the latest selection
  static const _kLat = 'last_lat';
  static const _kLng = 'last_lng';
  static const _kCity = 'last_city';
  static const _kState = 'last_state';
  static const _kCountry = 'last_country';
  static const _kPostal = 'last_postal';
  static const _kDisplay = 'last_location_display';

  @override
  void onInit() {
    super.onInit();
    _seedOnce();
  }

  /// Public helper: clear the visible text immediately.
  void clearLocationText() => _setText('');

  /// Pop after success (Navigator first, fallback to Get)
  void popAfterSave() {
    final ctx = Get.context;
    if (ctx != null && Navigator.of(ctx).canPop()) {
      Navigator.of(ctx).pop(true);
    } else {
      Get.back(result: true);
    }
  }

  Future<void> _seedOnce() async {
    // 1) In-memory last selection (fast)
    if ((_lastDisplay ?? '').trim().isNotEmpty) {
      _setText(_lastDisplay!);
      selectedLocation.value = _lastLatLng ?? selectedLocation.value;
      city       ??= _lastCity;
      state      ??= _lastState;
      country    ??= _lastCountry;
      postalCode ??= _lastPostal;
    }

    // 2) Constructor-provided initial values
    if (locationController.text.trim().isEmpty) {
      if (initialLatLng != null) selectedLocation.value = initialLatLng;
      city    ??= initialCity;
      state   ??= initialState;
      country ??= initialCountry;
      final disp = _composeDisplay();
      if (disp.isNotEmpty) _setText(disp);
    }

    // 3) Persisted in Hive
    await _paintFromHive(ifEmptyOnly: true);

    // 4) Backend hydration (profile)
    if (locationController.text.trim().isEmpty) {
      await _hydrateFromBackendOnce();
    }
  }

  /// Called by the UI after place selection OR reverse geocoding.
  /// If city/state/country are provided we’ll prefer composing a clean
  /// display like "City, Country", otherwise we use [displayName].
  Future<void> applyPickedPlace({
    required String displayName,
    required LatLng latLng,
    String? cityFromPicker,
    String? stateFromPicker,
    String? countryFromPicker,
    String? postalFromPicker,
  }) async {
    selectedLocation.value = latLng;
    city       = cityFromPicker    ?? city;
    state      = stateFromPicker   ?? state;
    country    = countryFromPicker ?? country;
    postalCode = postalFromPicker  ?? postalCode;

    final composed = _composeDisplay();
    final disp = composed.isNotEmpty ? composed : displayName.trim();
    _setText(disp);
  }

  /// Submit to backend as QID 5 with a JSON answer object
  Future<bool> submitEdit() async {
    final token = _readToken();
    if (token == null) {
      lastSubmitMessage = 'Missing token. Please log in again.';
      Get.snackbar('Error', lastSubmitMessage!);
      return false;
    }

    final pos = selectedLocation.value;

    final answer = <String, dynamic>{
      if (pos != null) "latitude": pos.latitude,
      if (pos != null) "longitude": pos.longitude,
      if (city != null) "city": city,
      if (state != null) "state": state,
      if (country != null) "country": country,
      if (postalCode != null) "postal_code": postalCode,
    };

    if (answer.isEmpty) {
      lastSubmitMessage = 'Please pick a location first.';
      Get.snackbar('Error', lastSubmitMessage!);
      return false;
    }

    final payload = {
      "answers": [
        {"question_id": 5, "answer": answer}
      ]
    };

    debugPrint('🛰️ submitEdit payload: ${jsonEncode(payload)}');

    isSaving.value = true;
    try {
      final resp = await ApiService.putJson('update-profile', payload, token: token);
      debugPrint('↩️ submitEdit resp: $resp');

      final ok = (resp['success'] == true || resp['status'] == true);
      lastSubmitMessage = (resp['message'] ?? 'Profile updated successfully.').toString();

      if (!ok) {
        Get.snackbar('Error', lastSubmitMessage!);
        return false;
      }

      _applyFromUpdate(resp);

      final disp = _composeDisplay();
      if (disp.isNotEmpty) {
        _setText(disp);
        _saveStatic(disp);
        await _saveHive(disp);
      }

      Get.snackbar('Updated', lastSubmitMessage!);
      await Future.delayed(const Duration(milliseconds: 150));
      popAfterSave();
      return true;
    } catch (e) {
      lastSubmitMessage = 'Something went wrong.';
      Get.snackbar('Error', lastSubmitMessage!);
      debugPrint('❌ Location update error: $e');
      return false;
    } finally {
      isSaving.value = false;
    }
  }

  void _applyFromUpdate(Map<String, dynamic> resp) {
    final data = resp['data'] as Map<String, dynamic>?;
    final loc = (data?['location'] as Map<String, dynamic>?) ?? data ?? const <String, dynamic>{};

    city       = _asStr(loc['city'])    ?? city;
    state      = _asStr(loc['state'])   ?? state;
    country    = _asStr(loc['country']) ?? country;
    postalCode = _asStr(loc['postal_code']) ?? _asStr(loc['postalCode']) ?? postalCode;

    final lat = _asNum(loc['latitude']);
    final lng = _asNum(loc['longitude']);
    if (lat != null && lng != null) {
      selectedLocation.value = LatLng(lat.toDouble(), lng.toDouble());
    }
  }

  // ───────── hydrations ─────────

  Future<void> _paintFromHive({required bool ifEmptyOnly}) async {
    try {
      if (!Hive.isBoxOpen(HiveBoxes.userBox)) {
        await Hive.openBox(HiveBoxes.userBox);
      }
      final box = Hive.box(HiveBoxes.userBox);

      final disp = box.get(_kDisplay) as String?;
      final latAny = box.get(_kLat);
      final lngAny = box.get(_kLng);
      if (latAny is num && lngAny is num) {
        selectedLocation.value = LatLng(latAny.toDouble(), lngAny.toDouble());
      }
      city       ??= (box.get(_kCity) as String?)?.trim();
      state      ??= (box.get(_kState) as String?)?.trim();
      country    ??= (box.get(_kCountry) as String?)?.trim();
      postalCode ??= (box.get(_kPostal) as String?)?.trim();

      final paint = (disp ?? _composeDisplay()).trim();
      if (paint.isNotEmpty && (!ifEmptyOnly || locationController.text.trim().isEmpty)) {
        _setText(paint);
      }
    } catch (_) {}
  }

  Future<void> _hydrateFromBackendOnce() async {
    try {
      final token = _readToken();
      if (token == null) return;

      final resp = await ApiService.get('profile', token: token);
      final root = (resp['data'] ?? resp) as Map<String, dynamic>;

      Map<String, dynamic>? loc =
          root['location'] as Map<String, dynamic>? ??
              (root['profile']?['location'] as Map<String, dynamic>?) ??
              (root['profile'] as Map<String, dynamic>?);

      if (loc == null) {
        final ua = root['user_answers'] as List<dynamic>?;
        if (ua != null) {
          for (final raw in ua) {
            final m = (raw as Map).map((k, v) => MapEntry(k.toString(), v));
            final qid = m['question_id'] ?? m['questionId'];
            if (qid == 5 || qid == '5') {
              dynamic ans = m['answer'] ?? m['value'] ?? m['answer_json'];
              if (ans is String) { try { ans = jsonDecode(ans); } catch (_) {} }
              if (ans is Map) loc = Map<String, dynamic>.from(ans);
              break;
            }
          }
        }
      }

      if (loc != null) {
        city       = _asStr(loc['city'])    ?? city;
        state      = _asStr(loc['state'])   ?? state;
        country    = _asStr(loc['country']) ?? country;
        postalCode = _asStr(loc['postal_code']) ?? _asStr(loc['postalCode']) ?? postalCode;

        final lat = _asNum(loc['latitude']);
        final lng = _asNum(loc['longitude']);
        if (lat != null && lng != null) {
          selectedLocation.value = LatLng(lat.toDouble(), lng.toDouble());
        }

        final disp = _composeDisplay();
        if (disp.isNotEmpty && locationController.text.trim().isEmpty) {
          _setText(disp);
          _saveStatic(disp);
          await _saveHive(disp);
        }
      }
    } catch (_) {}
  }

  // ───────── internals ─────────

  void _setText(String text) {
    final t = text.trim();
    locationController.value = locationController.value.copyWith(
      text: t,
      selection: TextSelection.collapsed(offset: t.length),
      composing: TextRange.empty,
    );
  }

  /// Prefer "City, Country", fallback to "State, Country", else empty.
  String _composeDisplay() {
    final c  = (city ?? '').trim();
    final s  = (state ?? '').trim();
    final co = (country ?? '').trim();

    if (c.isNotEmpty && co.isNotEmpty) return '$c, $co';
    if (c.isNotEmpty && s.isNotEmpty)  return '$c, $s';
    if (s.isNotEmpty && co.isNotEmpty) return '$s, $co';
    if (c.isNotEmpty) return c;
    if (co.isNotEmpty) return co;
    if (s.isNotEmpty) return s;
    return '';
  }

  void _saveStatic(String disp) {
    _lastDisplay = disp;
    _lastLatLng  = selectedLocation.value;
    _lastCity    = city;
    _lastState   = state;
    _lastCountry = country;
    _lastPostal  = postalCode;
  }

  Future<void> _saveHive(String disp) async {
    try {
      if (!Hive.isBoxOpen(HiveBoxes.userBox)) {
        await Hive.openBox(HiveBoxes.userBox);
      }
      final box = Hive.box(HiveBoxes.userBox);
      final pos = selectedLocation.value;
      if (pos != null) {
        await box.put(_kLat, pos.latitude);
        await box.put(_kLng, pos.longitude);
      }
      if ((city ?? '').isNotEmpty)       await box.put(_kCity, city);
      if ((state ?? '').isNotEmpty)      await box.put(_kState, state);
      if ((country ?? '').isNotEmpty)    await box.put(_kCountry, country);
      if ((postalCode ?? '').isNotEmpty) await box.put(_kPostal, postalCode);
      await box.put(_kDisplay, disp);
    } catch (_) {}
  }

  String? _readToken() {
    final box = Hive.box(HiveBoxes.userBox);
    final t1 = box.get('auth_token');
    final t2 = box.get('token');
    final token = (t1 is String && t1.trim().isNotEmpty) ? t1 : (t2 is String ? t2 : null);
    return (token != null && token.trim().isNotEmpty) ? token : null;
  }

  String? _asStr(dynamic v) {
    if (v == null) return null;
    final s = v.toString().trim();
    return s.isEmpty ? null : s;
  }

  num? _asNum(dynamic v) => v is num ? v : (v is String ? num.tryParse(v) : null);
}
