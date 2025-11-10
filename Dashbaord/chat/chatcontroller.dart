// lib/Dashbaord/chat/chatcontroller.dart
import 'package:get/get.dart';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'package:dating_app/services/api_services.dart';
import 'package:dating_app/hive_utils/hive_boxes.dart';
import 'chat_services.dart'; // to clear chat on expire
import 'chatmodel/chatmodel.dart';

/// ---------- Shared helpers (top-level) ----------
int? asInt(dynamic v) {
  if (v == null) return null;
  if (v is int) return v;
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v);
  return null;
}

String firstNameFromDisplayName(String full) {
  final base = (full.split('·').first).trim();
  final parts = base.split(' ');
  return parts.isEmpty ? base : parts.first.trim();
}

/// ---------- Models ----------
class ChatUser {
  final int id;
  final String name; // includes " · #id" for testing
  final int age;
  final String height;
  final String location;
  final String avatarUrl;
  final String bio;

  /// Unread flags
  final bool hasUnread;
  final int unreadCount;

  /// Suggestion meta (legacy/inline from list APIs)
  /// referral_id is the *suggester_id* (who introduced).
  final int? suggestedById;
  final String? suggestedByName;
  final int? suggestedUserId;

  ChatUser({
    required this.id,
    required this.name,
    required this.age,
    required this.height,
    required this.location,
    required this.avatarUrl,
    required this.bio,
    this.hasUnread = false,
    this.unreadCount = 0,
    this.suggestedById,
    this.suggestedByName,
    this.suggestedUserId,
  });

  ChatUser copyWith({
    String? name,
    int? age,
    String? height,
    String? location,
    String? avatarUrl,
    String? bio,
    bool? hasUnread,
    int? unreadCount,
    int? suggestedById,
    String? suggestedByName,
    int? suggestedUserId,
  }) {
    return ChatUser(
      id: id,
      name: name ?? this.name,
      age: age ?? this.age,
      height: height ?? this.height,
      location: location ?? this.location,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      bio: bio ?? this.bio,
      hasUnread: hasUnread ?? this.hasUnread,
      unreadCount: unreadCount ?? this.unreadCount,
      suggestedById: suggestedById ?? this.suggestedById,
      suggestedByName: suggestedByName ?? this.suggestedByName,
      suggestedUserId: suggestedUserId ?? this.suggestedUserId,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'age': age,
    'height': height,
    'location': location,
    'avatar_url': avatarUrl,
    'bio': bio,
    'has_unread': hasUnread,
    'unread_count': unreadCount,
    'suggested_by_id': suggestedById,
    'suggested_by_name': suggestedByName,
    'suggested_user_id': suggestedUserId,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is ChatUser && id == other.id);

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() =>
      'ChatUser(id: $id, name: $name, unread=$hasUnread/$unreadCount, avatar: $avatarUrl, suggestedBy=$suggestedById/$suggestedByName suggestedUser=$suggestedUserId)';
}

/// Simple view model for inbound suggestions (“X suggested Y to you”)
class SuggestionItem {
  final int id;
  final String message; // “Tamara S. suggested Alia A. to you”
  final String suggesterName; // “Tamara S.”
  final int suggestedUserId;
  final String suggestedUserName;
  final int? suggestedUserAge;
  final String suggestedUserPhoto;
  final String? suggestedUserCity;
  final String? note;
  final String createdAt; // keep as string; UI can parse if needed

  SuggestionItem({
    required this.id,
    required this.message,
    required this.suggesterName,
    required this.suggestedUserId,
    required this.suggestedUserName,
    required this.suggestedUserAge,
    required this.suggestedUserPhoto,
    required this.suggestedUserCity,
    required this.note,
    required this.createdAt,
  });

  factory SuggestionItem.fromMap(Map<String, dynamic> m) {
    final su = (m['suggested_user'] ?? {}) as Map<String, dynamic>;
    return SuggestionItem(
      id: asInt(m['id']) ?? 0,
      message: (m['message'] ?? '').toString(),
      suggesterName: (m['suggester_name'] ?? '').toString(),
      suggestedUserId: asInt(su['id']) ?? 0,
      suggestedUserName: (su['name'] ?? '').toString(),
      suggestedUserAge: asInt(su['age']),
      suggestedUserPhoto: (su['photo'] ?? '').toString(),
      suggestedUserCity: (su['city'] ?? '').toString().isEmpty
          ? null
          : (su['city'] ?? '').toString(),
      note: (m['note'] ?? '').toString().isEmpty
          ? null
          : (m['note'] ?? '').toString(),
      createdAt: (m['created_at'] ?? '').toString(),
    );
  }
}

/// Lightweight model for “available users” (used by Suggest flow)
class AvailableUser {
  final int id;
  final String name;
  final String photo; // absolute URL or empty

  AvailableUser({required this.id, required this.name, required this.photo});

  factory AvailableUser.fromMap(Map<String, dynamic> m) {
    final id = asInt(m['id']) ?? 0;
    final name = (m['name'] ?? 'User · #$id').toString();
    final photoRaw = m['photo'];
    final photo = photoRaw == null ? '' : photoRaw.toString();
    return AvailableUser(id: id, name: name, photo: photo);
  }
}

// --- Flat “suggestion message” from /chat/suggestion-messages
class SuggestionMessage {
  final int id;
  final String message;
  final String createdAt;

  SuggestionMessage({
    required this.id,
    required this.message,
    required this.createdAt,
  });

  factory SuggestionMessage.fromMap(Map<String, dynamic> m) => SuggestionMessage(
    id: (m['id'] is int) ? m['id'] as int : int.tryParse('${m['id']}') ?? 0,
    message: (m['message'] ?? '').toString(),
    createdAt: (m['created_at'] ?? '').toString(),
  );
}

/// --- NEW: Pair-level meta from /friendship-suggestion-meta?other_id=...
class PairSuggestionMeta {
  final int id;
  final int suggesterId;
  final String suggesterName; // "Tamara S."
  final int recipientId;
  final int suggestedUserId;
  final String createdAt;

  PairSuggestionMeta({
    required this.id,
    required this.suggesterId,
    required this.suggesterName,
    required this.recipientId,
    required this.suggestedUserId,
    required this.createdAt,
  });

  factory PairSuggestionMeta.fromMap(Map<String, dynamic> m) => PairSuggestionMeta(
    id: asInt(m['id']) ?? 0,
    suggesterId: asInt(m['suggester_id']) ?? 0,
    suggesterName: (m['suggester_name'] ?? '').toString(),
    recipientId: asInt(m['recipient_id']) ?? 0,
    suggestedUserId: asInt(m['suggested_user_id']) ?? 0,
    createdAt: (m['created_at'] ?? '').toString(),
  );
}

class ChatController extends GetxController {
  // Premium flag (server-driven)
  final isPremiumUser = false.obs;

  // Lists
  final matches = <ChatUser>[].obs; // dating
  final likesYou = <ChatUser>[].obs; // dating (inbound)
  final friends = <ChatUser>[].obs; // social
  final requests = <ChatUser>[].obs; // social (inbound)

  /// Suggestions inbox (“X suggested Y to you”)
  final suggestionsInbox = <SuggestionItem>[].obs;

  /// Available users for Suggest flow
  final availableUsers = <AvailableUser>[].obs;

  /// Raw “suggestion messages”
  final suggestionMessages = <SuggestionMessage>[].obs;
  final isLoadingSuggestionMessages = false.obs;
  final errorSuggestionMessages = RxnString();

  /// NEW: Pair-level meta cache keyed by other user id
  final pairSuggestionMeta = <int, PairSuggestionMeta>{}.obs;

  // Loading / action flags
  final isLoadingDating = false.obs;
  final isLoadingSocial = false.obs;
  final isLoadingSuggestions = false.obs;
  final isLoadingAvailableUsers = false.obs;
  final isActing = false.obs;

  // Errors (optional)
  final errorDating = RxnString();
  final errorSocial = RxnString();
  final errorSuggestions = RxnString();
  final errorAvailableUsers = RxnString();

  // when a match happens (Like Back or Accept), we show a toast
  final Rxn<ChatUser> matchedUser = Rxn<ChatUser>();

  // ---------- BADGE STATE ----------
  final totalNavBadge = 0.obs; // use this for the bottom "Chat" dot
  int get likesBadge => likesYou.length;
  int get requestsBadge => requests.length;
  int get suggestionsBadge => suggestionsInbox.length;

  bool get datingHasUnread =>
      matches.any((u) => u.hasUnread) || likesYou.isNotEmpty;
  bool get socialHasUnread =>
      friends.any((u) => u.hasUnread) || requests.isNotEmpty;

  void _recomputeBadge() {
    final total = (matches.where((u) => u.hasUnread).length) +
        (friends.where((u) => u.hasUnread).length) +
        likesYou.length +
        requests.length +
        suggestionsInbox.length; // include suggestions
    totalNavBadge.value = total;
  }

  // ---------- Convenience ----------
  bool get canUseSocial => isPremiumUser.value; // UI can read this to enable/disable taps
  bool get isSocialReadOnly => !isPremiumUser.value; // inverse

  bool _requirePremium(String actionName) {
    if (isPremiumUser.value) return true;
    final msg = 'Subscription required to $actionName';
    errorSocial.value = msg;
    debugPrint('[GATE] $msg');
    return false;
  }

  // ---------- Auth ----------
  String? get _token =>
      Hive.box(HiveBoxes.userBox).get('auth_token') as String?;
  int? get _meId {
    final v = Hive.box(HiveBoxes.userBox).get('user_id');
    if (v is int) return v;
    if (v is String) return int.tryParse(v);
    return null;
  }

  /// Logged-in user's avatar URL (used for "sent" bubbles).
  String get myAvatarUrl {
    final box = Hive.box(HiveBoxes.userBox);
    final candidates = [
      box.get('profile_image'),
      box.get('photo'),
      box.get('avatar_url'),
      box.get('avatar'),
    ].whereType<String>().where((s) => s.trim().isNotEmpty);

    for (final v in candidates) {
      final url = _imageUrl(v);
      if (url.isNotEmpty) return url;
    }
    return '';
  }

  @override
  void onInit() {
    super.onInit();
    final t = _token;
    if (t != null && t.isNotEmpty) {
      _fetchAll(t);
      fetchSubscription(token: t);
      fetchMySuggestions(token: t);
      fetchSuggestionMessages(token: t);
    }

    // Recompute badges whenever lists change
    ever<List<ChatUser>>(matches, (_) => _recomputeBadge());
    ever<List<ChatUser>>(likesYou, (_) => _recomputeBadge());
    ever<List<ChatUser>>(friends, (_) => _recomputeBadge());
    ever<List<ChatUser>>(requests, (_) => _recomputeBadge());
    ever<List<SuggestionItem>>(suggestionsInbox, (_) => _recomputeBadge());

    // Re-fetch when auth token or user id changes
    final box = Hive.box(HiveBoxes.userBox);
    box.watch(key: 'auth_token').listen((e) {
      final newToken = e.value?.toString();
      if (newToken != null && newToken.isNotEmpty) {
        _fetchAll(newToken);
        fetchSubscription(token: newToken);
        fetchMySuggestions(token: newToken);
        fetchSuggestionMessages(token: newToken);
      }
    });
    box.watch(key: 'user_id').listen((_) {
      final t2 = _token;
      if (t2 != null && t2.isNotEmpty) {
        _fetchAll(t2);
        fetchSubscription(token: t2);
        fetchMySuggestions(token: t2);
        fetchSuggestionMessages(token: t2);
      }
    });
  }

  void _fetchAll(String token) {
    fetchDating(token: token);
    fetchSocial(token: token);
  }

  // Public refreshers
  Future<void> refreshAll() async {
    final t = _token;
    if (t == null || t.isEmpty) return;
    await Future.wait([
      fetchDating(token: t),
      fetchSocial(token: t),
      fetchSubscription(token: t),
      fetchMySuggestions(token: t),
      fetchSuggestionMessages(token: t),
    ]);
  }

  Future<void> reloadDating() => fetchDating();
  Future<void> reloadLikesYou() => fetchDating();
  Future<void> reloadSocial() async {
    await Future.wait([fetchSocial(), fetchSubscription()]);
  }

  Future<void> reloadRequests() async {
    await Future.wait([fetchSocial(), fetchSubscription()]);
  }

  Future<void> reloadSuggestions() => fetchMySuggestions();

  // ---------- Subscription ----------
  Future<void> fetchSubscription({String? token}) async {
    final t = token ?? _token;
    if (t == null || t.isEmpty) return;
    try {
      final r = await ApiService.get('current-subscription', token: t);
      debugPrint('current-subscription => $r');

      bool parseSubscribed(dynamic v) {
        if (v is bool) return v;
        if (v is num) return v != 0;
        if (v is String) {
          final s = v.trim().toLowerCase();
          return s == 'true' || s == '1' || s == 'yes' || s == 'y';
        }
        return false;
      }
      final sub = (r is Map) ? parseSubscribed(r['subscribed']) : false;
      isPremiumUser.value = sub;
      debugPrint('isPremiumUser => ${isPremiumUser.value}');
    } catch (e) {
      debugPrint('fetchSubscription error: $e');
    }
  }
  // ---------- Dating ----------
  Future<void> fetchDating({String? token}) async {
    if (isLoadingDating.value) return;
    final t = token ?? _token;
    if (t == null || t.isEmpty) return;

    isLoadingDating.value = true;
    errorDating.value = null;

    try {
      final rMatches = await ApiService.get('matches', token: t);
      debugPrint('matches => $rMatches');
      final rLikes = await ApiService.get('likes-you', token: t);
      debugPrint('likes   => $rLikes');

      final me = _meId;

      final matched = _okList(rMatches)
          ? (rMatches['data'] as List)
          .map((e) => _toUser(Map<String, dynamic>.from(e), me))
          .where((u) => u.id != 0)
          .toList()
          : <ChatUser>[];

      final liked = _okList(rLikes)
          ? (rLikes['data'] as List)
          .map((e) => _toUser(Map<String, dynamic>.from(e), me))
          .where((u) => u.id != 0)
          .toList()
          : <ChatUser>[];

      matches.assignAll(matched);
      likesYou.assignAll(liked);
    } catch (e, st) {
      debugPrint('fetchDating error: $e\n$st');
      matches.clear();
      likesYou.clear();
      errorDating.value = 'Failed to load dating lists';
    } finally {
      isLoadingDating.value = false;
      _recomputeBadge();
    }
  }

  // ---------- Social ----------
  Future<void> fetchSocial({String? token}) async {
    if (isLoadingSocial.value) return;
    final t = token ?? _token;
    if (t == null || t.isEmpty) return;

    isLoadingSocial.value = true;
    errorSocial.value = null;

    try {
      final rFriends = await ApiService.get('friends', token: t);
      debugPrint('friends  => $rFriends');
      final rRequests = await ApiService.get('friend-requests', token: t);
      debugPrint('requests => $rRequests');

      final me = _meId;

      final frs = _okList(rFriends)
          ? (rFriends['data'] as List)
          .map((e) => _toUser(Map<String, dynamic>.from(e), me))
          .where((u) => u.id != 0)
          .toList()
          : <ChatUser>[];

      final req = _okList(rRequests)
          ? (rRequests['data'] as List)
          .map((e) => _toUser(Map<String, dynamic>.from(e), me))
          .where((u) => u.id != 0)
          .toList()
          : <ChatUser>[];

      friends.assignAll(frs);
      requests.assignAll(req);
    } catch (e, st) {
      debugPrint('fetchSocial error: $e\n$st');
      friends.clear();
      requests.clear();
      errorSocial.value = 'Failed to load friends/requests';
    } finally {
      isLoadingSocial.value = false;
      _recomputeBadge();
    }
  }

  // ---------- Suggestions Inbox ----------
  Future<void> fetchMySuggestions({String? token}) async {
    if (isLoadingSuggestions.value) return;
    final t = token ?? _token;
    if (t == null || t.isEmpty) return;

    isLoadingSuggestions.value = true;
    errorSuggestions.value = null;
    try {
      final r = await ApiService.get('my-suggestions', token: t);
      debugPrint('my-suggestions => $r');

      final ok = r is Map &&
          r['data'] is List &&
          ((r['success'] == true) ||
              (r['status'] == true) ||
              (r['code'] == 200));

      final list = ok ? (r['data'] as List) : const <dynamic>[];

      final parsed = list
          .whereType<Map>()
          .map((e) => SuggestionItem.fromMap(Map<String, dynamic>.from(e)))
          .toList();

      suggestionsInbox.assignAll(parsed);
    } catch (e, st) {
      debugPrint('fetchMySuggestions error: $e\n$st');
      suggestionsInbox.clear();
      errorSuggestions.value = 'Failed to load suggestions';
    } finally {
      isLoadingSuggestions.value = false;
      _recomputeBadge();
    }
  }

  // ---------- Suggestion Messages (/chat/suggestion-messages) ----------
  Future<void> fetchSuggestionMessages({String? token}) async {
    if (isLoadingSuggestionMessages.value) return;
    final t = token ?? _token;
    if (t == null || t.isEmpty) return;

    isLoadingSuggestionMessages.value = true;
    errorSuggestionMessages.value = null;
    try {
      final r = await ApiService.get('chat/suggestion-messages', token: t);
      debugPrint('chat/suggestion-messages => $r');

      final ok = r is Map &&
          r['data'] is List &&
          ((r['success'] == true) || (r['status'] == true) || (r['code'] == 200));

      final list = ok ? (r['data'] as List) : const <dynamic>[];

      final parsed = list
          .whereType<Map>()
          .map((e) => SuggestionMessage.fromMap(Map<String, dynamic>.from(e)))
          .toList();

      suggestionMessages.assignAll(parsed);
    } catch (e, st) {
      debugPrint('fetchSuggestionMessages error: $e\n$st');
      suggestionMessages.clear();
      errorSuggestionMessages.value = 'Failed to load suggestion messages';
    } finally {
      isLoadingSuggestionMessages.value = false;
      _recomputeBadge();
    }
  }

  // ---------- Pair Suggestion Meta (/friendship-suggestion-meta) ----------
  Future<PairSuggestionMeta?> fetchPairSuggestionMeta({
    required int otherUserId,
    String? token,
  }) async {
    final t = token ?? _token;
    if (t == null || t.isEmpty) return null;
    try {
      final r = await ApiService.get('friendship-suggestion-meta?other_id=$otherUserId', token: t);
      debugPrint('friendship-suggestion-meta($otherUserId) => $r');

      final ok = r is Map &&
          ((r['success'] == true) || (r['status'] == true) || (r['code'] == 200));

      if (!ok || r['data'] == null) {
        pairSuggestionMeta.remove(otherUserId);
        return null;
      }

      final data = Map<String, dynamic>.from(r['data'] as Map);
      final meta = PairSuggestionMeta.fromMap(data);
      pairSuggestionMeta[otherUserId] = meta;
      return meta;
    } catch (e) {
      debugPrint('fetchPairSuggestionMeta error: $e');
      return null;
    }
  }

  /// Returns the banner text to display in ChatThread for this pair.
  /// - If there is no suggestion relation, returns null.
  /// Logic covers:
  ///   * Me suggested Other
  ///   * Other suggested Me
  ///   * Third person suggested Me or Other
  String? suggestionBannerForPair({
    required int meId,
    required ChatUser other,
  }) {
    final meta = pairSuggestionMeta[other.id];
    if (meta == null) return null;

    final otherFirst = firstNameFromDisplayName(other.name);
    final suggester = meta.suggesterName.isNotEmpty ? meta.suggesterName : 'Someone';

    // Meta tells: "suggester suggested suggestedUserId to recipientId" (pair-wise)
    final suggestedIsOther = meta.suggestedUserId == other.id;
    final suggestedIsMe = meta.suggestedUserId == meId;

    // If suggester is me / other / third person:
    if (meta.suggesterId == meId) {
      // I suggested someone
      final targetLabel = suggestedIsOther ? otherFirst : 'this match';
      return 'You suggested $targetLabel';
    }
    if (meta.suggesterId == other.id) {
      // Other suggested someone
      final targetLabel = suggestedIsMe ? 'You' : 'this match';
      return '$otherFirst suggested $targetLabel';
    }

    // Third-person suggester
    if (suggestedIsOther) return '$suggester suggested $otherFirst';
    if (suggestedIsMe) return '$suggester suggested You';
    return '$suggester suggested this match';
  }

  // ================= Actions =============
  Future<void> like(ChatUser user) async {
    final t = _token;
    final me = _meId;
    if (t == null || t.isEmpty || me == null) return;
    if (isActing.value) return;
    isActing.value = true;
    try {
      final res = await ApiService.postForm('like', {
        'receiver_id': user.id.toString(),
        'type': 'dating',
      }, token: t);
      debugPrint('like => $res');
      fetchDating();
    } catch (e) {
      debugPrint('like error: $e');
    } finally {
      isActing.value = false;
    }
  }

  Future<void> likeBack(ChatUser user) async {
    final t = _token;
    if (t == null || t.isEmpty) return;
    if (isActing.value) return;
    isActing.value = true;

    likesYou.removeWhere((u) => u.id == user.id);
    matches.insert(0, user);

    try {
      final res = await ApiService.postForm('like-back', {
        'sender_id': user.id.toString(), // original liker
      }, token: t);
      debugPrint('like-back => $res');
      if (res['success'] == true ||
          res['status'] == true ||
          res['code'] == 200) {
        triggerMatched(user);
      } else {
        matches.removeWhere((u) => u.id == user.id);
        likesYou.add(user);
      }
      fetchDating();
    } catch (e) {
      matches.removeWhere((u) => u.id == user.id);
      likesYou.add(user);
      debugPrint('likeBack error: $e');
      fetchDating();
    } finally {
      isActing.value = false;
    }
  }

  Future<void> ignore(ChatUser user) async {
    final t = _token;
    if (t == null || t.isEmpty) return;
    if (isActing.value) return;
    isActing.value = true;
    likesYou.removeWhere((u) => u.id == user.id);
    try {
      final res = await ApiService.postForm('ignore', {
        'sender_id': user.id.toString(), // liker
      }, token: t);
      debugPrint('ignore => $res');
      if (res['success'] != true &&
          res['status'] != true &&
          res['code'] != 200) {
        likesYou.add(user);
      }
      fetchDating();
    } catch (e) {
      likesYou.add(user);
      debugPrint('ignore error: $e');
      fetchDating();
    } finally {
      isActing.value = false;
    }
  }

  Future<bool> acceptRequest(ChatUser user) async {
    if (!_requirePremium('accept requests')) return false;
    final t = _token;
    if (t == null || t.isEmpty) return false;
    if (isActing.value) return false;
    isActing.value = true;

    requests.removeWhere((u) => u.id == user.id);
    friends.insert(0, user);

    try {
      final res = await ApiService.postForm('accept', {
        'sender_id': user.id.toString(), // requester
      }, token: t);
      debugPrint('accept => $res');
      if (res['success'] == true ||
          res['status'] == true ||
          res['code'] == 200) {
        triggerMatched(user);
        await fetchSocial();
        return true;
      } else {
        friends.removeWhere((u) => u.id == user.id);
        requests.add(user);
        await fetchSocial();
        return false;
      }
    } catch (e) {
      friends.removeWhere((u) => u.id == user.id);
      requests.add(user);
      debugPrint('acceptRequest error: $e');
      await fetchSocial();
      return false;
    } finally {
      isActing.value = false;
    }
  }

  Future<bool> denyRequest(ChatUser user) async {
    if (!_requirePremium('deny requests')) return false;
    final t = _token;
    if (t == null || t.isEmpty) return false;
    if (isActing.value) return false;
    isActing.value = true;

    requests.removeWhere((u) => u.id == user.id);
    try {
      final res = await ApiService.postForm('deny', {
        'sender_id': user.id.toString(),
      }, token: t);
      debugPrint('deny => $res');
      if (res['success'] != true &&
          res['status'] != true &&
          res['code'] != 200) {
        requests.add(user);
      }
      await fetchSocial();
      return true;
    } catch (e) {
      requests.add(user);
      debugPrint('denyRequest error: $e');
      await fetchSocial();
      return false;
    } finally {
      isActing.value = false;
    }
  }

  Future<bool> expireSocialConnection(int receiverId) async {
    if (!_requirePremium('remove friends')) return false;
    final t = _token;
    if (t == null || t.isEmpty) return false;
    final me = _meId;
    if (me == null) return false;
    if (isActing.value) return false;
    isActing.value = true;

    final removed = friends.firstWhereOrNull((u) => u.id == receiverId);
    friends.removeWhere((u) => u.id == receiverId);

    try {
      final res = await ApiService.postForm('expire', {'receiver_id': '$receiverId'}, token: t);
      debugPrint('expire => $res');

      final ok = (res['success'] == true) ||
          (res['status'] == true) ||
          (res['code'] == 200);
      if (!ok) {
        if (removed != null) friends.insert(0, removed);
        return false;
      }

      // 🔥 Hard-delete chat history for this pair
      final service = ChatService();
      final threadId = service.threadIdFor(me, receiverId);
      await service.clearThreadHistory(threadId: threadId);

      await fetchSocial(token: t);
      return true;
    } catch (e) {
      debugPrint('expire error: $e');
      if (removed != null) friends.insert(0, removed);
      return false;
    } finally {
      isActing.value = false;
    }
  }

  void handleChatThreadResult(dynamic result) async {
    if (result is Map && result['expiredUserId'] != null) {
      final id = result['expiredUserId'] as int;
      friends.removeWhere((u) => u.id == id);
      await fetchSocial();
    }
  }

  void triggerMatched(ChatUser user) {
    matchedUser.value = user;
    Future.delayed(const Duration(seconds: 3), () {
      if (matchedUser.value == user) {
        matchedUser.value = null;
      }
    });
  }

  // ---------- Helpers ----------
  bool _okList(dynamic r) =>
      r is Map &&
          r['data'] is List &&
          ((r['success'] == true) ||
              (r['status'] == true) ||
              (r['code'] == 200));

  ChatUser _toUser(Map<String, dynamic> data, int? me) {
    // Expected shape:
    //   user: {...}, profile: {...},
    //   referral_id (suggester_id), referrer/suggester object optional,
    //   suggested_user_id optional, unread flags...
    final u = (data['user'] is Map)
        ? Map<String, dynamic>.from(data['user'])
        : <String, dynamic>{};
    final p = (data['profile'] is Map)
        ? Map<String, dynamic>.from(data['profile'])
        : <String, dynamic>{};

    final id = asInt(u['id'] ?? data['id']) ?? 0;

    final nameRaw = (u['name'] ??
        data['name'] ??
        [
          (u['first_name'] ?? data['first_name'] ?? '').toString().trim(),
          (u['last_name'] ?? data['last_name'] ?? '').toString().trim(),
        ].where((s) => s.isNotEmpty).join(' '))
        .toString()
        .trim();
    final name = ((nameRaw.isEmpty ? 'User' : nameRaw) + ' · #$id').trim();

    int age = 0;
    final ageRaw = u['age'] ?? data['age'];
    if (ageRaw is num) {
      age = ageRaw.toInt();
    } else if (ageRaw is String && int.tryParse(ageRaw) != null) {
      age = int.parse(ageRaw);
    }

    final height =
    (p['height'] ?? data['height'] ?? u['height'] ?? '').toString().trim();
    final bio = (p['bio'] ?? data['about_me'] ?? data['bio'] ?? u['bio'] ?? '')
        .toString()
        .trim();
    final city = (p['city'] ?? data['city'] ?? '').toString().trim();
    final state = (p['state'] ?? data['state'] ?? '').toString().trim();
    final location = [city, state].where((s) => s.isNotEmpty).join(', ');

    final avatarUrl = _pickBestPhoto(u, data);

    bool hasUnread = false;
    int unreadCount = 0;
    dynamic unreadRaw = data['unread'] ??
        data['has_unread'] ??
        data['is_unread'] ??
        data['unread_count'];
    if (unreadRaw is bool) {
      hasUnread = unreadRaw;
    } else if (unreadRaw is num) {
      unreadCount = unreadRaw.toInt();
      hasUnread = unreadCount > 0;
    } else if (unreadRaw is String) {
      final s = unreadRaw.toLowerCase().trim();
      if (int.tryParse(s) != null) {
        unreadCount = int.parse(s);
        hasUnread = unreadCount > 0;
      } else {
        hasUnread = (s == 'true' || s == '1' || s == 'yes' || s == 'y');
        unreadCount = hasUnread ? 1 : 0;
      }
    }

    // Suggestion meta (normalize 0 -> null)
    final suggestedByIdRaw =
    asInt(data['referral_id'] ?? data['referrer_id'] ?? data['suggester_id']);
    final int? suggestedById =
    (suggestedByIdRaw != null && suggestedByIdRaw > 0)
        ? suggestedByIdRaw
        : null;

    String? suggestedByName;

    // Embedded object?
    final refObj = (data['referrer'] is Map)
        ? Map<String, dynamic>.from(data['referrer'])
        : (data['suggester'] is Map)
        ? Map<String, dynamic>.from(data['suggester'])
        : null;
    if (refObj != null) {
      final rn = (refObj['name'] ??
          [
            (refObj['first_name'] ?? '').toString().trim(),
            (refObj['last_name'] ?? '').toString().trim()
          ].where((s) => s.isNotEmpty).join(' '))
          .toString()
          .trim();
      if (rn.isNotEmpty) suggestedByName = rn;
    }

    // Name-only fallbacks (no refObj)
    if (suggestedByName == null || suggestedByName.isEmpty) {
      final rn2 =
      (data['referrer_name'] ?? data['suggester_name'] ?? '').toString().trim();
      if (rn2.isNotEmpty) suggestedByName = rn2;
    }

    final suggestedUserIdRaw = asInt(data['suggested_user_id']);
    final int? suggestedUserId =
    (suggestedUserIdRaw != null && suggestedUserIdRaw > 0)
        ? suggestedUserIdRaw
        : null;

    // Special case: derive otherId if only sender/receiver present
    if (id == 0 && (data['sender_id'] != null || data['receiver_id'] != null)) {
      final senderId = asInt(data['sender_id']);
      final receiverId = asInt(data['receiver_id']);
      int otherId = 0;
      if (senderId != null && receiverId != null) {
        if (me != null) {
          otherId =
          senderId == me ? receiverId! : (receiverId == me ? senderId : senderId);
        } else {
          otherId = senderId!;
        }
      } else {
        otherId = asInt(data['id']) ?? 0;
      }
      return ChatUser(
        id: otherId,
        name: otherId == 0 ? 'Unknown' : 'User · #$otherId',
        age: 0,
        height: '',
        location: location.isEmpty ? 'Unknown' : location,
        avatarUrl: avatarUrl,
        bio: '',
        hasUnread: hasUnread,
        unreadCount: unreadCount,
        suggestedById: suggestedById,
        suggestedByName: suggestedByName,
        suggestedUserId: suggestedUserId,
      );
    }

    return ChatUser(
      id: id,
      name: name,
      age: age,
      height: height,
      location: location.isEmpty ? 'Unknown' : location,
      avatarUrl: avatarUrl,
      bio: bio,
      hasUnread: hasUnread,
      unreadCount: unreadCount,
      suggestedById: suggestedById,
      suggestedByName: suggestedByName,
      suggestedUserId: suggestedUserId,
    );
  }

  String _pickBestPhoto(Map<String, dynamic> user, Map<String, dynamic> root) {
    final photo = (user['photo'] ?? root['photo'])?.toString();
    if (photo != null && photo.isNotEmpty) return _imageUrl(photo);

    String? fromArrayUrl(Map<String, dynamic> m) {
      final list = m['photos'];
      if (list is List && list.isNotEmpty) {
        final first = list.first;
        if (first is Map && first['url'] != null) return first['url'].toString();
        if (first is String) return first;
      }
      return null;
    }

    final urlFromUser = fromArrayUrl(user);
    if (urlFromUser != null && urlFromUser.isNotEmpty) {
      return _imageUrl(urlFromUser);
    }

    final urlFromRoot = fromArrayUrl(root);
    if (urlFromRoot != null && urlFromRoot.isNotEmpty) {
      return _imageUrl(urlFromRoot);
    }

    return '';
  }

  String _imageUrl(String? pathOrUrl) {
    if (pathOrUrl == null || pathOrUrl.isEmpty) return '';
    if (pathOrUrl.startsWith('http')) return pathOrUrl;
    const base = 'https://pairup.binarygenes.pk';
    if (pathOrUrl.startsWith('/')) return '$base$pathOrUrl';
    return '$base/$pathOrUrl';
  }
}
