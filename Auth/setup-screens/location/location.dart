import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter_google_places_sdk/flutter_google_places_sdk.dart' as fplaces;

import '../../../themesfolder/theme.dart';
import 'location_controller.dart';
import 'mapselection.dart'; // Your existing map picker screen

/// TODO: move this key to secure storage / env for production builds.
const kGmsApiKey = 'AIzaSyB6xUP7b7yWdGYisgwZP-rgj-VMLxqQG4o';

class PairUpLocationScreen extends StatefulWidget {
  const PairUpLocationScreen({super.key});

  @override
  State<PairUpLocationScreen> createState() => _PairUpLocationScreenState();
}

class _PairUpLocationScreenState extends State<PairUpLocationScreen> {
  late final PairUpLocationController controller;
  late final fplaces.FlutterGooglePlacesSdk _places;

  final _focusNode = FocusNode();
  final _layerLink = LayerLink();
  Timer? _debounce;
  List<fplaces.AutocompletePrediction> _suggestions = [];
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    controller = Get.put(PairUpLocationController());
    _places = fplaces.FlutterGooglePlacesSdk(kGmsApiKey);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _focusNode.dispose();
    super.dispose();
  }

  void _onSearchChanged(String text) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () async {
      final q = text.trim();
      if (q.isEmpty) {
        if (mounted) setState(() => _suggestions = []);
        return;
      }
      if (mounted) setState(() => _loading = true);
      try {
        final resp = await _places.findAutocompletePredictions(q);
        if (mounted) setState(() => _suggestions = resp.predictions);
      } catch (_) {
        if (mounted) setState(() => _suggestions = []);
      } finally {
        if (mounted) setState(() => _loading = false);
      }
    });
  }

  Future<void> _pickFromMap({LatLng? initialTarget}) async {
    final result = await Navigator.push<LatLng>(
      context,
      MaterialPageRoute(
        builder: (_) => MapSelectionScreen(initialTarget: initialTarget),
      ),
    );
    if (result != null) {
      await controller.updateLocation(result);
    }
  }

  Future<void> _selectSuggestion(fplaces.AutocompletePrediction p) async {
    _focusNode.unfocus();
    setState(() => _suggestions = []);
    try {
      final detail = await _places.fetchPlace(
        p.placeId!,
        fields: const [fplaces.PlaceField.Location, fplaces.PlaceField.Name],
      );
      final place = detail.place;
      final ll = place?.latLng;
      final name = place?.name ?? p.primaryText ?? p.fullText ?? '';
      if (ll == null) {
        Get.snackbar('No coordinates', 'This place has no coordinates');
        return;
      }
      final target = LatLng(ll.lat, ll.lng);
      controller.locationController.text = name;
      await controller.updateLocation(target);

      // Let user adjust the marker if they wish
      await _pickFromMap(initialTarget: target);
    } catch (e) {
      Get.snackbar('Error', 'Failed to fetch place details');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        automaticallyImplyLeading: true,
        backgroundColor: AppTheme.backgroundColor,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.only(right: 20.0, left: 20.0, bottom: 20),
        child: SafeArea(
          child: Obx(
                () => Stack(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 24),
                    Text('Your PairUp Location', style: theme.textTheme.titleLarge),
                    const SizedBox(height: 24),

                    Text(
                      'Location',
                      style: theme.textTheme.labelLarge?.copyWith(color: Colors.black),
                    ),
                    const SizedBox(height: 8),

                    // Search field with anchored dropdown
                    CompositedTransformTarget(
                      link: _layerLink,
                      child: Material(
                        elevation: 0,
                        borderRadius: BorderRadius.circular(12),
                        color: Colors.transparent,
                        child: TextField(
                          controller: controller.locationController,
                          focusNode: _focusNode,
                          onChanged: _onSearchChanged,
                          style: theme.textTheme.bodyMedium,
                          cursorColor: Colors.black,
                          decoration: InputDecoration(
                            hintText: 'Search or write a location',
                            hintStyle: theme.textTheme.bodyMedium?.copyWith(color: theme.hintColor),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12.0),
                              borderSide: const BorderSide(color: Colors.black12),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12.0),
                              borderSide: const BorderSide(color: Colors.black, width: 1.5),
                            ),
                            filled: true,
                            fillColor: AppTheme.backgroundColor,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            suffixIcon: _loading
                                ? const Padding(
                              padding: EdgeInsets.all(12.0),
                              child: SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                            )
                                : IconButton(
                              icon: const Icon(Icons.map_outlined),
                              tooltip: 'Choose on map',
                              color: Colors.black,
                              onPressed: () => _pickFromMap(
                                initialTarget: controller.selectedLocation.value,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 8),

                    // Choose on map row
                    InkWell(
                      borderRadius: BorderRadius.circular(10),
                      onTap: () => _pickFromMap(
                        initialTarget: controller.selectedLocation.value,
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6.0),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.location_on_rounded, color: Colors.black),
                            const SizedBox(width: 6),
                            Text(
                              "choose on a map",
                              style: theme.textTheme.bodySmall?.copyWith(color: Colors.black),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const Spacer(),

                    // Next button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: controller.isSaving.value
                            ? null
                            : () async {
                          final ok = await controller.submitLocation();
                          if (ok && mounted) {
                            // go to upload photos screen
                            Get.toNamed('/uploadphoto');
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.black,
                          foregroundColor: AppTheme.backgroundColor,
                          padding: const EdgeInsets.symmetric(vertical: 14.0),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
                          elevation: 0,
                        ),
                        child: controller.isSaving.value
                            ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                            : Text(
                          'next',
                          style: theme.textTheme.labelLarge?.copyWith(
                            color: AppTheme.backgroundColor,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),

                // Suggestions dropdown
                if (_focusNode.hasFocus && _suggestions.isNotEmpty)
                  CompositedTransformFollower(
                    link: _layerLink,
                    showWhenUnlinked: false,
                    offset: const Offset(0, 60), // under the text field
                    child: Material(
                      elevation: 8,
                      borderRadius: BorderRadius.circular(14),
                      color: AppTheme.backgroundColor,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 320, minWidth: 200),
                        child: ListView.separated(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          shrinkWrap: true,
                          itemCount: _suggestions.length,
                          separatorBuilder: (_, __) => const Divider(
                            height: 1,
                            color: Colors.black12,
                            indent: 16,
                            endIndent: 16,
                          ),
                          itemBuilder: (context, i) {
                            final p = _suggestions[i];
                            final title = p.primaryText ?? p.fullText ?? '';
                            final sub = p.secondaryText ?? '';

                            return InkWell(
                              onTap: () => _selectSuggestion(p),
                              borderRadius: BorderRadius.circular(10),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 10.0),
                                child: Row(
                                  children: [
                                    const Icon(Icons.place_outlined, color: Colors.black),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            title,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: theme.textTheme.bodyMedium,
                                          ),
                                          if (sub.isNotEmpty)
                                            Text(
                                              sub,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: theme.textTheme.bodySmall?.copyWith(color: Colors.black54),
                                            ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
