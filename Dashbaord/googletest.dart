import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as gmap;
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart' as geo;
import 'package:flutter_google_places_sdk/flutter_google_places_sdk.dart' as fplaces;

class MapsLocationSearchScreen extends StatefulWidget {
  const MapsLocationSearchScreen({super.key});
  @override
  State<MapsLocationSearchScreen> createState() => _MapsLocationSearchScreenState();
}

class _MapsLocationSearchScreenState extends State<MapsLocationSearchScreen> {
  gmap.GoogleMapController? _map;
  final Set<gmap.Marker> _markers = {};
  bool _hasLocationPermission = false;
  Position? _currentPosition;
  gmap.MapType _mapType = gmap.MapType.normal;

  fplaces.FlutterGooglePlacesSdk? _places;
  final _searchCtrl = TextEditingController();
  final _focusNode = FocusNode();
  Timer? _debounce;
  List<fplaces.AutocompletePrediction> _suggestions = [];
  bool _loadingSuggestions = false;

  static const _fallback = gmap.CameraPosition(
    target: gmap.LatLng(40.7580, -73.9855), // Times Square
    zoom: 12,
  );

  @override
  void initState() {
    super.initState();
    _initNativeApiKeyThenPlaces();
    _initLocation();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  // ===== Key loader (from iOS Info.plist via MethodChannel) =====
  Future<void> _initNativeApiKeyThenPlaces() async {
    String key = '';
    if (Platform.isIOS) {
      try {
        const ch = MethodChannel('gms_config');
        key = await ch.invokeMethod<String>('getApiKey') ?? '';
      } catch (_) {}
    }
    // Android: if you want, you can keep a --dart-define or Manifest meta-data reader; for now rely on native setup
    // If the plugin requires a key string, pass what we have (on iOS, this will be the Info.plist key).
    setState(() {
      _places = fplaces.FlutterGooglePlacesSdk(key);
    });
  }

  String _t(Object? s) => (s is String ? s : '').trim();

  Future<void> _initLocation() async {
    final ok = await _ensureLocationPermission();
    setState(() => _hasLocationPermission = ok);
    if (!ok) return;
    try {
      final pos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.best);
      setState(() => _currentPosition = pos);
      final here = gmap.LatLng(pos.latitude, pos.longitude);
      _moveCamera(here, zoom: 15);
      _setMarker(here, id: 'me', title: 'You are here');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to get location: $e')));
    }
  }

  Future<bool> _ensureLocationPermission() async {
    final enabled = await Geolocator.isLocationServiceEnabled();
    if (!enabled) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Location services are disabled.')));
      return false;
    }
    var p = await Geolocator.checkPermission();
    if (p == LocationPermission.denied) p = await Geolocator.requestPermission();
    if (p == LocationPermission.denied || p == LocationPermission.deniedForever) return false;
    return true;
  }

  void _moveCamera(gmap.LatLng target, {double zoom = 16}) {
    _map?.animateCamera(gmap.CameraUpdate.newCameraPosition(gmap.CameraPosition(target: target, zoom: zoom)));
  }

  void _setMarker(gmap.LatLng pos, {required String id, String? title}) {
    setState(() {
      _markers
        ..removeWhere((m) => m.markerId.value == id)
        ..add(gmap.Marker(
          markerId: gmap.MarkerId(id),
          position: pos,
          infoWindow: title == null ? const gmap.InfoWindow() : gmap.InfoWindow(title: title),
        ));
    });
  }

  Future<void> _goToMyLocation() async {
    if (!_hasLocationPermission) {
      final ok = await _ensureLocationPermission();
      setState(() => _hasLocationPermission = ok);
      if (!ok) return;
    }
    final pos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.best);
    setState(() => _currentPosition = pos);
    final target = gmap.LatLng(pos.latitude, pos.longitude);
    _moveCamera(target);
    _setMarker(target, id: 'me', title: 'You are here');
  }

  // ===== Autocomplete (global) =====
  void _onSearchChanged(String text) {
    if (_places == null) return;
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () async {
      final q = text.trim();
      if (q.isEmpty) {
        if (mounted) setState(() => _suggestions = []);
        return;
      }
      if (mounted) setState(() => _loadingSuggestions = true);
      try {
        final resp = await _places!.findAutocompletePredictions(q);
        // ignore: avoid_print
        print('Autocomplete predictions: ${resp.predictions.length}');
        if (mounted) setState(() => _suggestions = resp.predictions);
      } catch (e) {
        // ignore: avoid_print
        print('Autocomplete failed: $e');
        if (mounted) {
          setState(() => _suggestions = []);
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Autocomplete failed: $e')));
        }
      } finally {
        if (mounted) setState(() => _loadingSuggestions = false);
      }
    });
  }

  Future<void> _submitTextSearch() async {
    final raw = _searchCtrl.text.trim();
    if (raw.isEmpty) return;

    // 1) Try Places first
    try {
      if (_places != null) {
        final a = await _places!.findAutocompletePredictions(raw);
        if (a.predictions.isNotEmpty) {
          await _selectSuggestion(a.predictions.first);
          return;
        }
      }
    } catch (_) {}

    // 2) Fallback: geocoder (no country suffix)
    try {
      final results = await geo.locationFromAddress(raw);
      if (results.isNotEmpty) {
        final first = results.first;
        final target = gmap.LatLng(first.latitude, first.longitude);
        _moveCamera(target, zoom: 16);
        _setMarker(target, id: 'text', title: raw);
        if (mounted) {
          setState(() => _suggestions = []);
          _focusNode.unfocus();
        }
        return;
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Text search failed: $e')));
      }
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No results. Try a fuller address (street, city, country).')),
      );
    }
  }

  Future<void> _selectSuggestion(fplaces.AutocompletePrediction p) async {
    _focusNode.unfocus();
    setState(() => _suggestions = []);
    try {
      final detail = await _places!.fetchPlace(
        p.placeId!,
        fields: [fplaces.PlaceField.Location, fplaces.PlaceField.Name],
      );
      final place = detail.place;
      final sdkLatLng = place?.latLng;
      if (sdkLatLng == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No coordinates for this place')));
        }
        return;
      }
      final target = gmap.LatLng(sdkLatLng.lat, sdkLatLng.lng);
      _moveCamera(target, zoom: 16);
      _setMarker(target, id: 'place', title: place?.name ?? _t(p.primaryText));
    } catch (e) {
      // ignore: avoid_print
      print('Place details failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Place details failed: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final locText = _currentPosition == null
        ? 'Current: unknown'
        : 'Current: ${_currentPosition!.latitude.toStringAsFixed(6)}, ${_currentPosition!.longitude.toStringAsFixed(6)}';

    final showPanel = _loadingSuggestions || _suggestions.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Location + Search'),
        actions: [
          IconButton(
            tooltip: 'Toggle map type',
            icon: const Icon(Icons.layers_outlined),
            onPressed: () => setState(() {
              _mapType = _mapType == gmap.MapType.normal ? gmap.MapType.satellite : gmap.MapType.normal;
            }),
          ),
        ],
      ),
      body: Stack(
        children: [
          gmap.GoogleMap(
            initialCameraPosition: _fallback,
            myLocationEnabled: _hasLocationPermission,
            myLocationButtonEnabled: false,
            mapType: _mapType,
            onMapCreated: (c) {
              _map = c;
              if (_currentPosition != null) {
                final here = gmap.LatLng(_currentPosition!.latitude, _currentPosition!.longitude);
                _moveCamera(here, zoom: 15);
                _setMarker(here, id: 'me', title: 'You are here');
              }
            },
            markers: _markers,
          ),

          // Search box
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
                  hintText: 'Search street, city, or place (worldwide)',
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  filled: true, fillColor: Colors.white,
                  suffixIcon: _loadingSuggestions
                      ? const Padding(
                    padding: EdgeInsets.all(12.0),
                    child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
                  )
                      : IconButton(icon: const Icon(Icons.search), onPressed: _submitTextSearch),
                ),
              ),
            ),
          ),

          // Autocomplete dropdown panel
          if (showPanel)
            Positioned(
              left: 12, right: 12, top: 64,
              child: Material(
                elevation: 6,
                borderRadius: BorderRadius.circular(12),
                color: Colors.white,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 300),
                  child: _loadingSuggestions
                      ? const Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                  )
                      : (_suggestions.isEmpty
                      ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: Text('No suggestions'),
                  )
                      : ListView.separated(
                    shrinkWrap: true,
                    itemCount: _suggestions.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, i) {
                      final p = _suggestions[i];
                      final title = _t(p.primaryText).isEmpty ? _t(p.fullText) : _t(p.primaryText);
                      final subtitle = _t(p.secondaryText);
                      return ListTile(
                        dense: true,
                        leading: const Icon(Icons.place_outlined),
                        title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
                        subtitle: subtitle.isEmpty ? null : Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis),
                        onTap: () => _selectSuggestion(p),
                      );
                    },
                  )),
                ),
              ),
            ),

          // Location chip
          Positioned(
            left: 12, right: 12, bottom: 100,
            child: Material(
              elevation: 2,
              borderRadius: BorderRadius.circular(12),
              color: Colors.white,
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Text(locText, style: const TextStyle(fontSize: 13)),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _goToMyLocation,
        icon: const Icon(Icons.my_location),
        label: const Text('My Location'),
      ),
    );
  }
}
