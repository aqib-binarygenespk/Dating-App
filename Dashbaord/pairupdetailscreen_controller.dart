import 'package:get/get.dart';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';

import '../../../../services/api_services.dart';
import '../../../../hive_utils/hive_boxes.dart';

class EventDetailsController extends GetxController {
  EventDetailsController({required Map<String, dynamic> event})
      : eventData = Map<String, dynamic>.from(event);

  final Map<String, dynamic> eventData;

  int get eventId => (eventData['id'] as num).toInt();

  final invitedUsers = <Map<String, dynamic>>[].obs;
  final suggestions = <Map<String, dynamic>>[].obs;
  final invitingUsers = <int, bool>{}.obs;

  @override
  void onInit() {
    super.onInit();
    _hydrateInvitedFromEvent();
    _hydrateSuggestionsFromEvent();
  }

  void _hydrateInvitedFromEvent() {
    final rawList = (eventData['invited_users'] ??
        eventData['invitedUsers'] ??
        eventData['invited'] ??
        []) as List<dynamic>;

    invitedUsers.assignAll(
      rawList
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList(),
    );
  }

  void _hydrateSuggestionsFromEvent() {
    final rawList = (eventData['suggestions'] ?? []) as List<dynamic>;
    suggestions.assignAll(
      rawList
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList(),
    );
  }

  bool isAlreadyInvited(int userId) {
    return invitedUsers.any((u) => (u['id'] as num).toInt() == userId);
  }

  /// Normalize a suggestion map to the shape your invited list expects
  Map<String, dynamic> _normalizeSuggestionForInvited(Map<String, dynamic> s) {
    // pick a photo from multiple possible keys
    String _pickPhoto(Map<String, dynamic> m) {
      final keys = [
        'photo_url',
        'photoUrl',
        'photo_path',
        'photoPath',
        'avatar',
        'profile_photo',
        'profilePhoto',
        'image',
        'photo',
      ];
      for (final k in keys) {
        final v = m[k];
        if (v is String && v.trim().isNotEmpty) return v.trim();
      }
      // fallback: photos: [{url|path}]
      if (m['photos'] is List && (m['photos'] as List).isNotEmpty) {
        final first = (m['photos'] as List).first;
        if (first is Map) {
          final v = (first['url'] ?? first['path'] ?? '').toString().trim();
          if (v.isNotEmpty) return v;
        } else if (first is String && first.trim().isNotEmpty) {
          return first.trim();
        }
      }
      return '';
    }

    final id = (s['id'] as num?)?.toInt();
    final first = (s['first_name'] ?? s['firstName'] ?? '').toString().trim();
    final last  = (s['last_name']  ?? s['lastName']  ?? '').toString().trim();
    final name  = (s['name'] ?? [first, last].where((x) => x.isNotEmpty).join(' ')).toString().trim();
    final photo = _pickPhoto(s);

    return {
      'id': id,
      // keep multiple keys so your UI helpers can find them
      'first_name': first,
      'last_name':  last,
      'name':       name,
      'photo_url':  photo,   // preferred by your avatar helper
      'photo_path': photo,   // also set this for compatibility
    };
    // add other fields if you show them in "Invited" later (e.g., email, location)
  }

  /// Invite a single user and move them from suggestions → invited with full data
  Future<void> inviteSuggestedUser({
    required int userId,
    Map<String, dynamic>? user, // pass the suggestion map from UI
    VoidCallback? onSuccess,
  }) async {
    if (isAlreadyInvited(userId)) {
      Get.snackbar("Already Invited", "This user is already invited.");
      return;
    }

    final box = Hive.box(HiveBoxes.userBox);
    final token = box.get('auth_token') ?? box.get('token');
    if (token == null || (token is String && token.isEmpty)) {
      Get.snackbar("Auth", "Missing token. Please log in again.");
      return;
    }

    invitingUsers[userId] = true;
    invitingUsers.refresh();

    try {
      final payload = {'event_id': eventId, 'user_ids': [userId]};
      final resp = await ApiService.postJson('events/invite-suggestions', payload, token: token);

      final msg = (resp is Map && resp['message'] is String)
          ? resp['message'] as String
          : 'Invite processed';

      // Build a rich invited object from the suggestion
      Map<String, dynamic>? src = user;
      src ??= suggestions.firstWhereOrNull(
            (s) => (s['id'] as num?)?.toInt() == userId,
      );

      final invitedEntry = src != null
          ? _normalizeSuggestionForInvited(src)
          : {'id': userId}; // worst-case fallback

      if (!isAlreadyInvited(userId)) {
        invitedUsers.add(invitedEntry);
        invitedUsers.refresh();
      }

      // Remove from suggestions so the card disappears
      suggestions.removeWhere((s) => (s['id'] as num?)?.toInt() == userId);
      suggestions.refresh();

      Get.snackbar("Success", msg);
      onSuccess?.call();
    } catch (e) {
      Get.snackbar("Error", "Failed to invite user.");
    } finally {
      invitingUsers[userId] = false;
      invitingUsers.refresh();
    }
  }

  // ---------- display helpers ----------
  String displayName(Map<String, dynamic> u) {
    final first = (u['first_name'] ?? u['firstName'] ?? '').toString().trim();
    final last  = (u['last_name']  ?? u['lastName']  ?? '').toString().trim();
    var name = [first, last].where((s) => s.isNotEmpty).join(' ').trim();
    if (name.isEmpty) {
      name = (u['name'] ?? u['username'] ?? u['email'] ?? 'User').toString();
    }
    return name;
  }

  String? photoUrl(Map<String, dynamic> u) {
    final p = (u['photo_url'] ??
        u['photoUrl'] ??
        u['avatar'] ??
        u['profile_photo'] ??
        u['photo_path'] ??
        '')
        .toString()
        .trim();
    if (p.isEmpty) return null;
    return p;
  }

  String nameFromSuggestion(Map<String, dynamic> s) {
    final first = (s['first_name'] ?? s['firstName'] ?? '').toString().trim();
    final last  = (s['last_name']  ?? s['lastName']  ?? '').toString().trim();
    final name = [first, last].where((x) => x.isNotEmpty).join(' ').trim();
    return name.isEmpty ? (s['name'] ?? 'User').toString() : name;
  }

  String ageHeightFromSuggestion(Map<String, dynamic> s) {
    final age = (s['age']?.toString() ?? '').trim();
    final height = (s['height']?.toString() ?? '').trim();
    if (age.isEmpty && height.isEmpty) return '—';
    if (age.isNotEmpty && height.isNotEmpty) return '$age, $height';
    return age.isNotEmpty ? age : height;
  }
}
