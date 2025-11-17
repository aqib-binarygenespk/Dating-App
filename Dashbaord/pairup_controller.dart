import 'package:dating_app/Dashbaord/pairupscreens/pairup/pairupdetailscreen/pairupdetailscreen.dart';
import 'package:dating_app/themesfolder/theme.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hive/hive.dart';

import '../../../services/api_services.dart';
import '../../../hive_utils/hive_boxes.dart';
import 'edit/edit.dart';
import 'invitation.dart';

class PairUpController extends GetxController {
  // ─── Search (optional) ───────────────────────────────────────────────────────
  var searchQuery = ''.obs;
  void updateSearch(String q) => searchQuery.value = q;

  // ─── My Events list ──────────────────────────────────────────────────────────
  final events = <Map<String, dynamic>>[].obs;
  final isLoading = false.obs;
  int currentPage = 1;
  bool hasMore = true;
  final int perPage = 10;
  bool isFetchingMore = false;

  // ─── Invitations list ────────────────────────────────────────────────────────
  final invitations = <Map<String, dynamic>>[].obs;
  final isLoadingInvites = false.obs;
  int invitesPage = 1;
  bool invitesHasMore = true;
  bool invitesFetchingMore = false;

  // Cache: userId → name
  final userIdToName = <int, String>{}.obs;

  // Optional: search results when inviting
  final searchResults = <Map<String, dynamic>>[].obs;

  @override
  void onInit() {
    super.onInit();
    fetchEvents();
    fetchInvitations();
  }

  // ─────────────────────  NAV / SHEET  ─────────────────────────────────────────
  void onEventTap(Map<String, dynamic> event) {
    Get.to(() => EventDetailsScreen(event: event));
  }

  void onInvitationTap(Map<String, dynamic> event) {
    Get.to(() => InvitationDetailsScreen(event: event));
  }

  void onEventOptionsTap(Map<String, dynamic> event) {
    Get.bottomSheet(
      Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
          color: AppTheme.backgroundColor,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.edit),
              title: Text('Edit', style: AppTheme.textTheme.titleLarge),
              onTap: () {
                Get.back();
                Get.to(() => EditEventScreen(event: event));
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete),
              title: Text('Delete', style: AppTheme.textTheme.titleLarge),
              onTap: () {
                Get.back();
                final id = (event['id'] is int)
                    ? event['id'] as int
                    : int.tryParse(event['id'].toString()) ?? -1;
                if (id > 0) deleteEvent(id);
              },
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────  MY EVENTS  ───────────────────────────────────────────
  Future<void> fetchEvents({bool loadMore = false}) async {
    if (isFetchingMore || (loadMore && !hasMore)) return;

    final token = Hive.box(HiveBoxes.userBox).get('auth_token');
    if (token == null) return;

    if (!loadMore) {
      currentPage = 1;
      hasMore = true;
      isLoading.value = true;
    } else {
      isFetchingMore = true;
    }

    try {
      final resp = await ApiService.get(
        'events/my?page=$currentPage&per_page=$perPage',
        token: token,
      );

      // Accept either a list or a paginator-like {data:[...]}
      final raw = (resp['data'] is List)
          ? resp['data']
          : (resp['data']?['data'] ?? resp['data'] ?? []);

      final newEvents = List<Map<String, dynamic>>
          .from(raw)
          .map(_normalizeEvent)
          .toList();

      if (loadMore) {
        events.addAll(newEvents);
      } else {
        events.value = newEvents;
      }

      if (newEvents.length < perPage) {
        hasMore = false;
      } else {
        currentPage++;
      }

      // cache invited names
      for (final e in newEvents) {
        final invited = e['invited_users'];
        if (invited is List) {
          for (final u in invited) {
            final id = _asInt(u['id']);
            if (id != null) {
              final name =
              "${u['first_name'] ?? ''} ${u['last_name'] ?? ''}".trim();
              if (name.isNotEmpty) userIdToName[id] = name;
            }
          }
        }
      }
    } catch (e) {
      debugPrint("❌ fetchEvents error: $e");
      if (!loadMore) events.clear();
    } finally {
      isLoading.value = false;
      isFetchingMore = false;
    }
  }

  Future<void> deleteEvent(int eventId) async {
    final token = Hive.box(HiveBoxes.userBox).get('auth_token');
    if (token == null) return;

    try {
      final res = await ApiService.delete('delete-event/$eventId', token: token);
      if (res['success'] == true) {
        events.removeWhere((e) => _asInt(e['id']) == eventId);
        Get.snackbar('Success', 'Event deleted successfully.');
      } else {
        Get.snackbar(
          'Error',
          res['message']?.toString() ?? 'Failed to delete event.',
        );
      }
    } catch (e) {
      debugPrint('❌ deleteEvent error: $e');
      Get.snackbar('Error', 'Could not delete event.');
    }
  }

  // ─────────────────────  INVITATIONS  ─────────────────────────────────────────
  Future<void> fetchInvitations({bool loadMore = false}) async {
    if (invitesFetchingMore || (loadMore && !invitesHasMore)) return;

    final token = Hive.box(HiveBoxes.userBox).get('auth_token');
    if (token == null) return;

    if (!loadMore) {
      invitesPage = 1;
      invitesHasMore = true;
      isLoadingInvites.value = true;
    } else {
      invitesFetchingMore = true;
    }

    try {
      final resp = await ApiService.get(
        'events/invitations?page=$invitesPage&per_page=$perPage',
        token: token,
      );

      // ✅ Backend shape: { data: { events: [...] }, message: ... }
      final raw = resp['data']?['events'] ?? [];

      final newInvites = List<Map<String, dynamic>>
          .from(raw)
          .map(_normalizeInvitation)
          .toList();

      if (loadMore) {
        invitations.addAll(newInvites);
      } else {
        invitations.value = newInvites;
      }

      // No explicit total from backend, infer hasMore by page size
      if (newInvites.length < perPage) {
        invitesHasMore = false;
      } else {
        invitesPage++;
      }
    } catch (e) {
      debugPrint("❌ fetchInvitations error: $e");
      if (!loadMore) invitations.clear();
    } finally {
      isLoadingInvites.value = false;
      invitesFetchingMore = false;
    }
  }

  /// Accept / Reject an invitation.
  /// Backend: POST /events/{event_id}/respond  with { response: 'accept' | 'reject' }
  Future<void> respondToInvitation({
    required int eventId,
    required bool accept,
  }) async {
    final token = Hive.box(HiveBoxes.userBox).get('auth_token');
    if (token == null) {
      Get.snackbar('Auth', 'Please log in again.');
      return;
    }

    try {
      final res = await ApiService.postForm(
        'events/$eventId/respond',
        {
          'response': accept ? 'accept' : 'reject', // ✅ matches validator
        },
        token: token,
      );

      // Backend returns sendResponse(status, 'Invite Accepted/Rejected')
      final ok = (res['success'] == true || res['status'] == true);
      final msg = res['message']?.toString() ??
          (accept ? 'Invite Accepted' : 'Invite Rejected');

      if (ok) {
        invitations.removeWhere((e) => _asInt(e['id']) == eventId);
        Get.snackbar('Invitation', msg);
      } else {
        Get.snackbar('Invitation', msg);
      }
    } catch (e) {
      debugPrint('❌ respondToInvitation error: $e');
      Get.snackbar('Invitation', 'Could not send response.');
    }
  }

  // ─────────────────────  Helpers  ─────────────────────────────────────────────
  Map<String, dynamic> _normalizeEvent(Map<String, dynamic> e) {
    final m = Map<String, dynamic>.from(e);

    // photo normalization
    final raw = (m['photo_url'] ?? m['photo_path'] ?? '').toString();
    m['photo_url'] = _fullUrl(raw);

    // invited users photos normalization
    final invited = m['invited_users'];
    if (invited is List) {
      m['invited_users'] = invited.map((u0) {
        final u = Map<String, dynamic>.from(u0 as Map);
        final p =
        (u['profile_photo'] ?? u['profile_photo_url'] ?? '').toString();
        u['profile_photo_url'] = p; // ensure UI key exists
        return u;
      }).toList();
    }

    return m;
  }

  Map<String, dynamic> _normalizeInvitation(Map<String, dynamic> e) {
    // Invitation item has: id, name, description, time_and_date, location,
    // photo_path (nullable), invited_users: [{id, first_name, last_name, profile_photo}]
    final m = Map<String, dynamic>.from(e);

    // normalize event photo
    final raw = (m['photo_url'] ?? m['photo_path'] ?? '').toString();
    m['photo_url'] = _fullUrl(raw);

    // invited users normalization
    final invited = m['invited_users'];
    if (invited is List) {
      m['invited_users'] = invited.map((u0) {
        final u = Map<String, dynamic>.from(u0 as Map);
        final p =
        (u['profile_photo'] ?? u['profile_photo_url'] ?? '').toString();
        u['profile_photo_url'] = p;
        return u;
      }).toList();
    }

    return m;
  }

  String _fullUrl(String raw) {
    if (raw.isEmpty) return '';
    final fixed = raw.replaceAll('\\', '');
    if (fixed.startsWith('http')) return fixed;
    return 'http://pairup.binarygenes.pk/$fixed';
  }

  int? _asInt(dynamic v) {
    if (v is int) return v;
    if (v is String) return int.tryParse(v);
    return null;
  }

  String getNameById(int id) => userIdToName[id] ?? "User #$id";

  Future<void> searchUsers(String query) async {
    if (query.trim().isEmpty) {
      searchResults.clear();
      return;
    }
    final token = Hive.box(HiveBoxes.userBox).get('auth_token');
    if (token == null) return;

    try {
      final resp = await ApiService.get('search-users?q=$query', token: token);
      if (resp['data'] is List) {
        searchResults.value = List<Map<String, dynamic>>.from(resp['data']);
      } else {
        searchResults.clear();
      }
    } catch (e) {
      debugPrint("❌ searchUsers error: $e");
      searchResults.clear();
    }
  }
}
