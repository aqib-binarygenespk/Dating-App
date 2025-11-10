import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:geocoding/geocoding.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:hive/hive.dart';

import '../../../services/api_services.dart';      // ApiService.postJson(...)
import '../../../hive_utils/hive_boxes.dart';      // HiveBoxes.userBox

class PairUpLocationController extends GetxController {
  final TextEditingController locationController = TextEditingController();

  /// Selected marker/latlng
  final Rxn<LatLng> selectedLocation = Rxn<LatLng>();

  /// Reverse-geocoded fields (optional for backend)
  final Rxn<String> country = Rxn<String>();
  final Rxn<String> city = Rxn<String>();
  final Rxn<String> state = Rxn<String>();
  final Rxn<String> postalCode = Rxn<String>();

  /// UI state
  final RxBool isSaving = false.obs;

  Future<void> updateLocation(LatLng position) async {
    selectedLocation.value = position;
    await _fillAddressFromLatLng(position);
  }

  Future<void> _fillAddressFromLatLng(LatLng position) async {
    try {
      final placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      if (placemarks.isNotEmpty) {
        final p = placemarks.first;

        final resolvedCity = (p.locality?.isNotEmpty ?? false)
            ? p.locality
            : (p.subAdministrativeArea?.isNotEmpty ?? false)
            ? p.subAdministrativeArea
            : (p.administrativeArea?.isNotEmpty ?? false)
            ? p.administrativeArea
            : null;

        city.value = resolvedCity;
        country.value = (p.country?.isNotEmpty ?? false) ? p.country : null;
        state.value = (p.administrativeArea?.isNotEmpty ?? false) ? p.administrativeArea : null;
        postalCode.value = (p.postalCode?.isNotEmpty ?? false) ? p.postalCode : null;

        final display = [
          if (resolvedCity != null) resolvedCity,
          if (country.value != null) country.value,
        ].join(', ');
        if (display.isNotEmpty) {
          locationController.text = display;
        }
      }
    } catch (e) {
      log("Reverse geocoding failed: $e");
    }
  }

  /// Sends current location to backend: POST /api/location
  /// Returns true if success.
  Future<bool> submitLocation() async {
    final pos = selectedLocation.value;
    if (pos == null) {
      Get.snackbar('Location required', 'Please choose a location first.');
      return false;
    }

    final box = Hive.box(HiveBoxes.userBox);

    // Support both common key names ('token' and 'auth_token') to match earlier code.
    final token = (box.get('token') ?? box.get('auth_token'))?.toString();

    if (token == null || token.trim().isEmpty) {
      Get.snackbar("Error", "Missing token. Please log in again.");
      return false;
    }

    final body = {
      'latitude': pos.latitude,
      'longitude': pos.longitude,
      'country': country.value,
      'city': city.value,
      'state': state.value,
      'postal_code': postalCode.value,
    };

    isSaving.value = true;
    try {
      // Your ApiService should prefix base URL and add headers incl. Bearer token.
      // Endpoint matches your Laravel controller method: POST /api/location
      final resp = await ApiService.postJson('location', body, token: token);

      final ok = (resp['success'] == true || resp['status'] == true);
      if (ok) {
        Get.snackbar('Success', (resp['message'] ?? 'Location updated successfully.').toString());
        return true;
      } else {
        final msg = (resp['message'] ?? 'Failed to update location.').toString();
        Get.snackbar('Error', msg);
        return false;
      }
    } catch (e) {
      Get.snackbar('Error', 'Could not update location.');
      log('submitLocation error: $e');
      return false;
    } finally {
      isSaving.value = false;
    }
  }

  @override
  void onClose() {
    locationController.dispose();
    super.onClose();
  }
}
