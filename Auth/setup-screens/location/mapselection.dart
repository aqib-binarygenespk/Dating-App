import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter_google_places_sdk/flutter_google_places_sdk.dart' as fplaces;
import 'package:geocoding/geocoding.dart' as geo;

const kGmsApiKey = 'AIzaSyB6xUP7b7yWdGYisgwZP-rgj-VMLxqQG4o';

class MapSelectionScreen extends StatefulWidget {
  final LatLng? initialTarget;
  const MapSelectionScreen({super.key, this.initialTarget});

  @override
  State<MapSelectionScreen> createState() => _MapSelectionScreenState();
}

class _MapSelectionScreenState extends State<MapSelectionScreen> {
  GoogleMapController? _map;
  final Set<Marker> _markers = {};
  final _searchCtrl = TextEditingController();
  final _focusNode = FocusNode();
  Timer? _debounce;

  late final fplaces.FlutterGooglePlacesSdk _places;
  List<fplaces.AutocompletePrediction> _suggestions = [];
  bool _loading = false;

  static const _fallback = CameraPosition(
    target: LatLng(40.7580, -73.9855),
    zoom: 12,
  );

  @override
  void initState() {
    super.initState();
    _places = fplaces.FlutterGooglePlacesSdk(kGmsApiKey);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _move(LatLng target, {double zoom = 16}) {
    _map?.animateCamera(
      CameraUpdate.newCameraPosition(CameraPosition(target: target, zoom: zoom)),
    );
  }

  void _setMarker(LatLng p, {String id = 'pin', String? title}) {
    setState(() {
      _markers
        ..removeWhere((m) => m.markerId.value == id)
        ..add(Marker(
          markerId: MarkerId(id),
          position: p,
          infoWindow: title == null ? const InfoWindow() : InfoWindow(title: title),
        ));
    });
  }

  void _onMapCreated(GoogleMapController c) {
    _map = c;
    final initial = widget.initialTarget;
    if (initial != null) {
      _move(initial, zoom: 16);
      _setMarker(initial, title: 'Selected');
    }
  }

  void _onMapTap(LatLng p) {
    _setMarker(p, title: 'Pinned');
  }

  // Autocomplete in map screen
  void _onSearchChanged(String text) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () async {
      final q = text.trim();
      if (q.isEmpty) {
        setState(() => _suggestions = []);
        return;
      }
      setState(() => _loading = true);
      try {
        final resp = await _places.findAutocompletePredictions(q);
        setState(() => _suggestions = resp.predictions);
      } catch (_) {
        setState(() => _suggestions = []);
      } finally {
        if (mounted) setState(() => _loading = false);
      }
    });
  }

  Future<void> _selectSuggestion(fplaces.AutocompletePrediction p) async {
    _focusNode.unfocus();
    setState(() => _suggestions = []);
    try {
      final detail = await _places.fetchPlace(
        p.placeId!,
        fields: const [fplaces.PlaceField.Location, fplaces.PlaceField.Name],
      );
      final ll = detail.place?.latLng;
      final name = detail.place?.name ?? p.primaryText ?? p.fullText ?? '';
      if (ll == null) return;
      final target = LatLng(ll.lat, ll.lng);
      _searchCtrl.text = name;
      _move(target, zoom: 16);
      _setMarker(target, title: name);
    } catch (_) {}
  }

  Future<void> _submitTextSearch() async {
    final raw = _searchCtrl.text.trim();
    if (raw.isEmpty) return;
    try {
      final results = await geo.locationFromAddress(raw);
      if (results.isEmpty) return;
      final first = results.first;
      final target = LatLng(first.latitude, first.longitude);
      _move(target);
      _setMarker(target, title: raw);
      setState(() => _suggestions = []);
      _focusNode.unfocus();
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Choose on map')),
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: widget.initialTarget == null
                ? _fallback
                : CameraPosition(target: widget.initialTarget!, zoom: 16),
            onMapCreated: _onMapCreated,
            onTap: _onMapTap,
            markers: _markers,
            myLocationEnabled: false,
            myLocationButtonEnabled: false,
            compassEnabled: true,
          ),

          // search bar
          Positioned(
            left: 12, right: 12, top: 12,
            child: Material(
              elevation: 4,
              borderRadius: BorderRadius.circular(12),
              child: TextField(
                controller: _searchCtrl,
                focusNode: _focusNode,
                onChanged: _onSearchChanged,
                onSubmitted: (_) => _submitTextSearch(),
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: 'Search street, city, or place',
                  contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: Colors.white,
                  suffixIcon: _loading
                      ? const Padding(
                    padding: EdgeInsets.all(12.0),
                    child: SizedBox(
                      width: 18, height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                      : IconButton(
                    icon: const Icon(Icons.search),
                    onPressed: _submitTextSearch,
                  ),
                ),
              ),
            ),
          ),

          if (_suggestions.isNotEmpty)
            Positioned(
              left: 12, right: 12, top: 64,
              child: Material(
                elevation: 6,
                borderRadius: BorderRadius.circular(12),
                color: Colors.white,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 300),
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: _suggestions.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, i) {
                      final p = _suggestions[i];
                      final title = p.primaryText ?? p.fullText ?? '';
                      final sub = p.secondaryText ?? '';
                      return ListTile(
                        dense: true,
                        leading: const Icon(Icons.place_outlined),
                        title: Text(title,
                            maxLines: 1, overflow: TextOverflow.ellipsis),
                        subtitle: sub.isEmpty
                            ? null
                            : Text(sub,
                            maxLines: 1, overflow: TextOverflow.ellipsis),
                        onTap: () => _selectSuggestion(p),
                      );
                    },
                  ),
                ),
              ),
            ),
        ],
      ),

      // confirm
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          // return the marker location if any, otherwise current camera center
          LatLng? chosen;
          if (_markers.isNotEmpty) {
            chosen = _markers.first.position;
          } else if (_map != null) {
            // read current camera target
            // ignore: invalid_use_of_visible_for_testing_member, invalid_use_of_protected_member
            final posFuture = _map!.getVisibleRegion(); // not exactly center; ok fallback
            // Simpler: just pop null if no pin
          }
          if (chosen == null && _markers.isEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Tap the map or pick a place first')),
            );
            return;
          }
          Navigator.pop(context, chosen ?? _markers.first.position);
        },
        icon: const Icon(Icons.check),
        label: const Text('Use this location'),
      ),
    );
  }
}
