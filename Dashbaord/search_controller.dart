// lib/features/search/search_controller.dart
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hive/hive.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'package:dating_app/hive_utils/hive_boxes.dart';
import '../../Auth/setup-screens/location/mapselection.dart';
import '../../services/api_services.dart';
import 'Searchdetail/search_profiledart.dart';

class CustomSearchController extends GetxController {
  // ---------- reactive state ----------
  final profiles = <SearchProfile>[].obs;
  final selectedProfile = Rxn<SearchProfile>();
  final isLoading = false.obs;
  final isLoadingMore = false.obs;
  final hasMore = true.obs;

  // ❤️ like cache so the heart reacts instantly
  final likedIds = <int>{}.obs;
  bool isLiked(int id) => likedIds.contains(id);

  // Profiles hidden from Search list for this session
  final hiddenIds = <int>{}.obs;
  bool isHidden(int id) => likedIds.contains(id) || hiddenIds.contains(id);

  final Map<int, _RemovedEntry> _removed = {};
  final Map<int, Timer> _hideTimers = {};

  // ---------- paging ----------
  int _page = 1;
  static const _perPage = 10;

  // ---------- filter state ----------
  static const double _ageMinDefault = 18;
  static const double _ageMaxDefault = 70;

  static const double _heightMinDefault = 4.0;
  static const double _heightMaxDefault = 6.10;

  final searchingFor = 'Dating'.obs;             // "Dating" / "Social Circle"
  final selectedLocationLabel = 'San Diego'.obs; // chip label
  LatLng? selectedLatLng;

  final ageStart = _ageMinDefault.obs, ageEnd = _ageMaxDefault.obs;
  final heightStart = _heightMinDefault.obs, heightEnd = _heightMaxDefault.obs;

  // ===== Distance (discrete steps) =====
  // Steps: 0, 1..15, then 20,30,40,...1000
  static final List<int> distanceSteps = <int>[
    0,
    ...List<int>.generate(15, (i) => i + 1),
    ...List<int>.generate(((1000 - 20) ~/ 10) + 1, (i) => 20 + i * 10),
  ];

  static const double _distanceMaxDefault = 1000.0;
  final distanceMax = _distanceMaxDefault.obs; // kept for chips/API
  final distanceIndex = 0.obs; // index into distanceSteps

  final bool _sendSearchingForToBackend = true;

  Map<String, String?> get chips {
    final map = <String, String?>{};
    map['searchingFor'] = searchingFor.value;

    if (_ageChanged) {
      map['ageRange'] = '${ageStart.value.round()} - ${ageEnd.value.round()}';
    }
    if (_heightChanged) {
      map['heightRange'] =
      "${_feetInchesString(heightStart.value)} - ${_feetInchesString(heightEnd.value)}";
    }
    if (selectedLatLng != null ||
        (selectedLocationLabel.value.isNotEmpty &&
            selectedLocationLabel.value != 'San Diego')) {
      map['location'] = selectedLocationLabel.value;
      map['distanceRange'] = '0 - ${distanceMax.value.round()} Miles';
    }
    return map;
  }

  Map<String, String?> get appliedFilters => chips;

  bool get _ageChanged =>
      ageStart.value != _ageMinDefault || ageEnd.value != _ageMaxDefault;
  bool get _heightChanged =>
      heightStart.value != _heightMinDefault || heightEnd.value != _heightMaxDefault;

  @override
  void onInit() {
    super.onInit();
    // Align distance index to default
    distanceIndex.value = _indexForDistance(distanceMax.value.round());
    fetchProfiles(reset: true);
  }

  @override
  void onClose() {
    for (final t in _hideTimers.values) {
      t.cancel();
    }
    _hideTimers.clear();
    super.onClose();
  }

  void selectProfile(SearchProfile p) => selectedProfile.value = p;

  Future<void> pickLocation(BuildContext context) async {
    final LatLng? chosen = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => MapSelectionScreen(initialTarget: selectedLatLng)),
    );
    if (chosen != null) {
      selectedLatLng = chosen;
      selectedLocationLabel.value =
      '(${chosen.latitude.toStringAsFixed(4)}, ${chosen.longitude.toStringAsFixed(4)})';
      update();
    }
  }

  Future<void> applyFiltersAndSearch() async => fetchProfiles(reset: true);

  // ===== Distance helpers =====
  void setDistanceByIndex(int idx) {
    final clamped = idx.clamp(0, distanceSteps.length - 1);
    distanceIndex.value = clamped;
    distanceMax.value = distanceSteps[clamped].toDouble();
    update();
  }

  int _indexForDistance(int miles) {
    final i = distanceSteps.indexWhere((v) => v >= miles);
    return (i == -1) ? distanceSteps.length - 1 : i;
  }

  void _removeFromListAndCache(int id) {
    final idx = profiles.indexWhere((p) => p.id == id);
    if (idx != -1) {
      _removed[id] = _RemovedEntry(profiles[idx], idx);
      profiles.removeAt(idx);
    }
  }

  void _restoreFromCache(int id) {
    final entry = _removed.remove(id);
    if (entry != null) {
      final insertAt = entry.index.clamp(0, profiles.length);
      profiles.insert(insertAt, entry.profile);
    }
  }

  void hideImmediately(int id, {bool permanently = true}) {
    _removeFromListAndCache(id);
    if (permanently) hiddenIds.add(id);
  }

  void _scheduleHideAfterLike(int id, {Duration delay = const Duration(seconds: 3)}) {
    _hideTimers[id]?.cancel();
    _hideTimers[id] = Timer(delay, () {
      if (likedIds.contains(id) && !hiddenIds.contains(id)) {
        _removeFromListAndCache(id);
        hiddenIds.add(id);
      }
      _hideTimers.remove(id);
    });
  }

  void _cancelHideTimer(int id) {
    _hideTimers[id]?.cancel();
    _hideTimers.remove(id);
  }

  // ========== LIKE ==========
  Future<void> likeUser(int receiverId) async {
    final token = _readTokenFromHive();
    if (token == null || token.isEmpty) {
      Get.snackbar('Auth', 'Please log in again.');
      return;
    }

    final type = _mapSearchingFor(searchingFor.value); // 'dating' | 'social_circle'
    final payload = {
      'receiver_id': receiverId.toString(),
      'type': type,
    };

    likedIds.add(receiverId);
    _scheduleHideAfterLike(receiverId);

    try {
      final res = await ApiService.post('like', payload, token: token);
      if (res is Map && res['success'] != true) {
        _cancelHideTimer(receiverId);
        likedIds.remove(receiverId);
        if (hiddenIds.remove(receiverId)) _restoreFromCache(receiverId);
        Get.snackbar('Like', (res['message'] ?? 'Failed to like').toString());
      } else {
        Get.snackbar('Like', type == 'social_circle' ? 'Request sent' : 'Liked');
      }
    } catch (e) {
      _cancelHideTimer(receiverId);
      likedIds.remove(receiverId);
      if (hiddenIds.remove(receiverId)) _restoreFromCache(receiverId);
      debugPrint('❌ likeUser error: $e');
      Get.snackbar('Like', 'Could not send like. Please try again.');
    }
  }

  // ========== DISMISS ==========
  Future<void> dismissUser(int receiverId) async {
    final token = _readTokenFromHive();
    if (token == null || token.isEmpty) {
      Get.snackbar('Auth', 'Please log in again.');
      return;
    }

    _cancelHideTimer(receiverId);
    likedIds.remove(receiverId);
    _removeFromListAndCache(receiverId);
    hiddenIds.add(receiverId);
    _removed.remove(receiverId);

    final type = _mapSearchingFor(searchingFor.value);
    final payload = {'receiver_id': receiverId.toString(), 'type': type};

    try {
      await ApiService.post('not-interested', payload, token: token);
    } catch (e) {
      debugPrint('❌ dismissUser error: $e');
      Get.snackbar('Network', 'Saved locally. Will try again next time.');
    }
  }

  // ========== FAVORITE ==========
  Future<void> favoriteUser(int profileId, {bool favorite = true}) async {
    final token = _readTokenFromHive();
    if (token == null || token.isEmpty) {
      Get.snackbar('Auth', 'Please log in again.');
      return;
    }

    final payload = {'profile_id': profileId.toString(), 'favorite': favorite ? '1' : '0'};
    _removeFromListAndCache(profileId);

    try {
      final res = await ApiService.post('favorite', payload, token: token);
      if (res is Map && res['success'] != true) {
        _restoreFromCache(profileId);
        Get.snackbar('Favorite', (res['message'] ?? 'Failed to favorite').toString());
      } else {
        hiddenIds.add(profileId);
        _removed.remove(profileId);
        Get.snackbar('Favorite', favorite ? 'Added to favorites' : 'Removed from favorites');
      }
    } catch (e) {
      _restoreFromCache(profileId);
      debugPrint('❌ favoriteUser error: $e');
      Get.snackbar('Favorite', 'Could not update favorite. Please try again.');
    }
  }

  // ========== FETCH ==========
  Future<void> fetchProfiles({bool reset = false}) async {
    if (isLoading.value || isLoadingMore.value) return;

    final token = _readTokenFromHive();
    if (token == null || token.isEmpty) {
      isLoading.value = false;
      isLoadingMore.value = false;
      profiles.clear();
      hasMore.value = false;
      Get.snackbar('Authentication required', 'Please log in again.');
      return;
    }

    if (reset) {
      _page = 1;
      hasMore.value = true;
      isLoading.value = true;
      profiles.clear();
    } else {
      if (!hasMore.value) return;
      isLoadingMore.value = true;
    }

    try {
      final params = <String, String>{
        'page': _page.toString(),
        'per_page': '$_perPage',
      };

      if (_sendSearchingForToBackend) {
        params['searching_for'] = _mapSearchingFor(searchingFor.value);
      }
      if (_ageChanged) {
        params['min_age'] = ageStart.value.round().toString();
        params['max_age'] = ageEnd.value.round().toString();
      }
      if (_heightChanged) {
        params['min_height'] = _feetDecimalToInches(heightStart.value).toString();
        params['max_height'] = _feetDecimalToInches(heightEnd.value).toString();
      }
      if (selectedLatLng != null) {
        params['latitude'] = selectedLatLng!.latitude.toString();
        params['longitude'] = selectedLatLng!.longitude.toString();
        params['distance'] = distanceMax.value.round().toString(); // still sends miles
      }

      final qs = Uri(queryParameters: params).query;
      final endpoint = 'search?$qs';
      final resp = await ApiService.get(endpoint, token: token);

      if (resp is Map && resp['success'] == false) {
        final code = (resp['code'] as num?)?.toInt();
        final msg = resp['message']?.toString() ?? 'Request failed';
        Get.snackbar(code == 401 ? 'Session expired' : 'Search error',
            code == 401 ? 'Please log in again.' : msg);
        hasMore.value = false;
        isLoading.value = false;
        isLoadingMore.value = false;
        return;
      }

      final data = (resp is Map && resp.containsKey('data')) ? resp['data'] : resp;
      final listDynamic = (data is Map && data.containsKey('profiles'))
          ? data['profiles']
          : (data is Map && data.containsKey('data'))
          ? data['data']
          : data;

      if (listDynamic is! Iterable) {
        if (listDynamic is String) {
          final decoded = jsonDecode(listDynamic);
          if (decoded is Iterable) {
            _appendResults(decoded);
          } else {
            throw Exception('Unexpected response shape (string not list)');
          }
        } else {
          throw Exception('Unexpected response shape: $listDynamic');
        }
      } else {
        _appendResults(listDynamic);
      }

      Map<String, dynamic>? pg;
      if (data is Map && data['pagination'] is Map) {
        pg = Map<String, dynamic>.from(data['pagination']);
      }
      final current = (pg?['current_page'] ?? _page) as int;
      final last = (pg?['last_page'] ?? current) as int;
      hasMore.value = current < last;
      if (hasMore.value) _page = current + 1;
    } catch (e) {
      debugPrint('❌ Search error: $e');
      Get.snackbar('Search', 'Failed to load profiles');
      hasMore.value = false;
    } finally {
      isLoading.value = false;
      isLoadingMore.value = false;
    }
  }

  void _appendResults(Iterable list) {
    final fetched = list.map((e) {
      if (e is Map<String, dynamic>) return SearchProfile.fromJson(e);
      if (e is Map) return SearchProfile.fromJson(Map<String, dynamic>.from(e));
      return SearchProfile.fromJson({});
    })
    // skip anything hidden/liked already
        .where((p) => !isHidden(p.id))
        .toList();

    // IMPORTANT: keep server order (suggested first). We only de-dupe.
    final existingIds = profiles.map((p) => p.id).toSet();
    profiles.addAll(fetched.where((p) => !existingIds.contains(p.id)));
  }

  // ---------- helpers ----------
  String? _readTokenFromHive() {
    try {
      if (Hive.isBoxOpen(HiveBoxes.userBox)) {
        final t = Hive.box(HiveBoxes.userBox).get('auth_token');
        return t?.toString();
      }
    } catch (e) {
      debugPrint('Hive token read error: $e');
    }
    return null;
  }

  String _mapSearchingFor(String uiValue) {
    final v = uiValue.trim().toLowerCase();
    if (v.contains('social')) return 'social_circle';
    return 'dating';
  }

  int _feetDecimalToInches(double v) {
    final feet = v.floor();
    final inches = ((v - feet) * 10).round().clamp(0, 11);
    return feet * 12 + inches;
  }

  String _feetInchesString(double v) {
    final feet = v.floor();
    final inches = ((v - feet) * 10).round().clamp(0, 11);
    return "$feet'$inches\"";
  }
}

class _RemovedEntry {
  final SearchProfile profile;
  final int index;
  _RemovedEntry(this.profile, this.index);
}
