// lib/Dashbaord/chat/screen/chatscreen.dart
// NOTE: fixed keyboard behavior (no "vibration"), header hides on keyboard open,
// input bar is padded (not the whole page), and jump-to-bottom is non-animated on
// keyboard metric changes to avoid jitter. Keyboard/emoji now close on scroll like WhatsApp.

import 'dart:io';
import 'dart:async';
import 'package:dating_app/themesfolder/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';

import '../../dashboard/Dashboard.dart'; // chatNavId
import '../audio/audio_message.dart';     // AudioRecorderSheet
import '../audio/audiomessage.dart';      // AudioMessageTile
import '../chat_services.dart';           // ChatService
import '../chatcontroller.dart';          // (for my avatar & pair-suggestion meta)
import 'package:dating_app/hive_utils/hive_boxes.dart';
import 'package:dating_app/services/api_services.dart';

import '../chatmodel/chatmodel.dart' hide ChatUser;

// If you have a ProfileController, this improves avatar fallback.
import 'package:dating_app/Dashbaord/profile/profile_controller.dart';

import '../local/chat_db.dart';

enum ThreadCategory { dating, social }

// Reason label -> reason_id (update to your DB if needed)
const Map<String, int> kFlagReasonIds = {
  "Inappropriate Content": 1,
  "Harassment or Abuse": 2,
  "Fake Profile": 3,
  "Spam or Scamming": 4,
  "Offensive Behavior": 5,
  "Misleading Information": 6,
  "Safety Concerns": 7,
  "Other": 8,
};

class ChatThreadScreen extends StatefulWidget {
  final ChatUser user;
  final ThreadCategory category;

  const ChatThreadScreen({
    Key? key,
    required this.user,
    required this.category,
  }) : super(key: key);

  @override
  State<ChatThreadScreen> createState() => _ChatThreadScreenState();
}

class _ChatThreadScreenState extends State<ChatThreadScreen>
    with WidgetsBindingObserver {
  final TextEditingController _messageController = TextEditingController();
  final FocusNode _inputFocus = FocusNode();
  final ImagePicker _picker = ImagePicker();
  final ScrollController _listCtrl = ScrollController();

  bool _isEmojiPickerVisible = false;

  // ===== Chat plumbing =====
  late final ChatService _chat;
  int _meId = -1;
  late String _threadId;
  late String _categoryStr;

  bool get _idsValid => _meId > 0 && widget.user.id > 0;

  /// Selected (queued) images waiting in the composer preview row
  final List<File> _selectedImages = [];

  /// Files currently being sent (optimistic bubbles in the list)
  final List<File> _sendingFiles = [];

  // ===== SUGGESTIONS =====
  bool _allowSuggestions = true; // controlled by user setting / Hive
  bool _loadingSuggestions = false;
  List<_SuggestCandidate> _candidates = [];

  // ===== Likes (multi-like support) =====
  final Set<String> _likedKeys = <String>{};

  // Prevent double-taps on send
  bool _sendingNow = false;

  // ★ Auto-scroll helpers
  double _autoScrollThreshold = 120; // px from bottom to auto-scroll
  int _lastRenderedCount = 0;        // remember list length to decide if new items came

  // Debounce metric changes to avoid repeated jumps during keyboard animation
  Timer? _metricsDebounce;

  // ---------- NEW: Suggestion Success Notice ----------
  String? _suggestionSuccessText; // when present, show this banner (from /notifications)
  bool _loadedSuggestionSuccess = false;

  // ---------- NEW: Pair-level suggestion banner (authoritative, server-driven) ----------
  String? _pairSuggestionBanner;

  // ---------- Hive helpers for likes ----------
  void _loadLikesFromHive() {
    try {
      final box = Hive.box(HiveBoxes.userBox);
      final hiveKey = 'likes_$_threadId';
      final list = (box.get(hiveKey) as List?)?.cast<String>() ?? const <String>[];
      if (list.isNotEmpty) {
        setState(() {
          _likedKeys
            ..clear()
            ..addAll(list);
        });
      }
    } catch (e) {
      debugPrint('[likes] load error: $e');
    }
  }

  void _persistLikesToHive() {
    try {
      final box = Hive.box(HiveBoxes.userBox);
      final hiveKey = 'likes_$_threadId';
      box.put(hiveKey, _likedKeys.toList(growable: false));
    } catch (e) {
      debugPrint('[likes] save error: $e');
    }
  }
  // -------------------------------------------------

  String get _token {
    final box = Hive.box(HiveBoxes.userBox);
    final raw = box.get('auth_token') ?? box.get('token') ?? box.get('access_token');
    return raw == null ? '' : raw.toString().trim();
  }

  Future<void> _withLoader(Future<void> Function() fn) async {
    // This loader is used only for explicit actions (flag/block/expire),
    // not for typing/sending text, so it won’t appear “on speed” while chatting.
    FocusScope.of(context).unfocus();
    Get.dialog(const Center(child: CircularProgressIndicator()), barrierDismissible: false);
    try {
      await fn();
    } finally {
      if (Get.isDialogOpen ?? false) Get.back();
    }
  }

  // ---------- API calls ----------
  Future<void> _flagUser({
    required int flaggedId,
    required int reasonId,
    String? details,
  }) async {
    if (_token.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Missing authentication token. Please re-login.')),
      );
      return;
    }
    await _withLoader(() async {
      final data = <String, String>{
        'flagged_id': flaggedId.toString(),
        'reason_id': reasonId.toString(),
        if (details != null && details.trim().isNotEmpty) 'details': details.trim(),
      };
      final res = await ApiService.postForm('flag', data, token: _token);
      final ok = (res['success'] == true) || (res['status'] == true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ok ? 'User flagged successfully' : (res['message']?.toString() ?? 'Flag failed'))),
      );
    });
  }

  Future<void> _blockUser({required int blockedId, String? reason}) async {
    if (_token.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Missing authentication token. Please re-login.')),
      );
      return;
    }
    await _withLoader(() async {
      final data = <String, String>{
        'blocked_id': blockedId.toString(),
        if (reason != null && reason.trim().isNotEmpty) 'reason': reason.trim(),
      };
      final res = await ApiService.postForm('block', data, token: _token);
      final ok = (res['success'] == true) || (res['status'] == true);

      // 🔥 Nuke chat history on successful BLOCK
      if (ok) {
        try {
          await _chat.deleteThreadPermanently(_threadId);
        } catch (e) {
          debugPrint('deleteThreadPermanently (block) error: $e');
        }
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ok ? 'User blocked successfully' : (res['message']?.toString() ?? 'Block failed'))),
      );
    });
  }

  Future<void> _expireUser({required int receiverId}) async {
    if (widget.category != ThreadCategory.social) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Expire is only available in Social Circle.')),
      );
      return;
    }
    if (_token.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Missing authentication token. Please re-login.')),
      );
      return;
    }
    await _withLoader(() async {
      final data = <String, String>{'receiver_id': receiverId.toString()};
      final res = await ApiService.postForm('expire', data, token: _token);
      final ok = (res['success'] == true) || (res['status'] == true);

      if (ok) {
        // 🔥 Nuke chat history on successful EXPIRE (unfriend)
        try {
          await _chat.deleteThreadPermanently(_threadId);
        } catch (e) {
          debugPrint('deleteThreadPermanently (expire) error: $e');
        }
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Connection expired. You won’t see this in Social Circle.')),
        );
        if (Get.isOverlaysOpen == true) await Future<void>.delayed(const Duration(milliseconds: 50));
        if (Get.currentRoute.isNotEmpty) {
          Get.back(id: chatNavId, result: {'expiredUserId': receiverId});
        } else {
          Navigator.of(context).maybePop({'expiredUserId': receiverId});
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(res['message']?.toString() ?? 'Expire failed')),
        );
      }
    });
  }

  // ===== Suggestions =====
  Future<void> _fetchAvailableUsers() async {
    if (_token.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Missing authentication token. Please re-login.')),
      );
      return;
    }
    setState(() {
      _loadingSuggestions = true;
      _candidates = [];
    });
    try {
      // IMPORTANT: pass the recipientId so the backend can exclude them
      final res = await ApiService.get(
        'available-users?recipient_id=${widget.user.id}',
        token: _token,
      );

      final success = (res['success'] == true) || (res['status'] == true) || (res['code'] == 200);
      if (!success) {
        if ((res['code']?.toString() == '403') ||
            (res['message']?.toString().toLowerCase().contains('disabled') ?? false)) {
          if (mounted) setState(() => _allowSuggestions = false);
        }
        throw Exception(res['message'] ?? 'Failed to load suggestions');
      }

      // ✅ Robust parsing: API may return List OR Map with numeric keys
      final raw = res['data'];
      final List<Map<String, dynamic>> rows;
      if (raw is List) {
        rows = raw
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
      } else if (raw is Map) {
        rows = raw.values
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
      } else {
        rows = const [];
      }

      final parsed = rows.map((e) {
        return _SuggestCandidate(
          id: (e['id'] ?? 0) is int ? e['id'] as int : int.tryParse('${e['id']}') ?? 0,
          name: (e['name'] ?? '').toString(),
          photo: (e['photo'] ?? '').toString(),
        );
      }).where((u) => u.id > 0).toList();

      if (mounted) {
        setState(() {
          _candidates = parsed;
          _allowSuggestions = true;
        });
      }
    } catch (e) {
      debugPrint('available-users error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not load suggestions: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _loadingSuggestions = false);
      }
    }
  }

  Future<void> _sendSuggestion({
    required int recipientId,
    required int suggestedUserId,
    String? note,
  }) async {
    if (_token.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Missing authentication token. Please re-login.')),
      );
      return;
    }
    await _withLoader(() async {
      final res = await ApiService.postForm('suggest-profile', {
        'recipient_id': recipientId.toString(),
        'suggested_user_id': suggestedUserId.toString(),
        if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
      }, token: _token);

      final ok = (res['success'] == true) || (res['status'] == true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ok ? 'Suggestion sent!' : (res['message']?.toString() ?? 'Suggestion failed'))),
      );
    });
  }

  Future<void> _openSuggestionsDialog() async {
    await _fetchAvailableUsers();
    if (!_allowSuggestions) return;
    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: AppTheme.backgroundColor,
        title: Text('Suggest to', style: AppTheme.textTheme.bodyLarge),
        content: SizedBox(
          width: double.maxFinite,
          child: _loadingSuggestions
              ? const SizedBox(height: 120, child: Center(child: CircularProgressIndicator()))
              : (_candidates.isEmpty
              ? const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text('No users available right now.'),
          )
              : ListView.separated(
            shrinkWrap: true,
            itemCount: _candidates.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (_, i) {
              final u = _candidates[i];
              return ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(
                  radius: 22,
                  backgroundColor: Colors.black12,
                  backgroundImage: (u.photo.isNotEmpty) ? NetworkImage(u.photo) : null,
                  child: (u.photo.isEmpty)
                      ? const Icon(Icons.person, color: Colors.black54)
                      : null,
                ),
                title: Text(u.name, style: AppTheme.textTheme.bodyMedium),
                onTap: () async {
                  Navigator.of(dialogCtx).pop();
                  await _sendSuggestion(
                    recipientId: widget.user.id,
                    suggestedUserId: u.id,
                  );
                },
              );
            },
          )),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(),
            child: Text('Close', style: AppTheme.textTheme.bodySmall),
          ),
        ],
      ),
    );
  }

  // ====== MY AVATAR (robust multi-source) ======
  String _myAvatarUrlSafe() {
    // 1) ChatController
    try {
      if (Get.isRegistered<ChatController>()) {
        final url = Get.find<ChatController>().myAvatarUrl;
        if (url.isNotEmpty) return url;
      }
    } catch (_) {}

    // 2) ProfileController first image
    try {
      if (Get.isRegistered<ProfileController>()) {
        final p = Get.find<ProfileController>();
        if (p.imageUrls.isNotEmpty && p.imageUrls.first.trim().isNotEmpty) {
          return p.imageUrls.first.trim();
        }
      }
    } catch (_) {}

    // 3) Hive fallbacks
    try {
      final box = Hive.box(HiveBoxes.userBox);
      final keysToTry = [
        'profile_photo',
        'avatar',
        'photo',
        'profile_image',
        'image_url',
        'primary_photo',
      ];
      for (final k in keysToTry) {
        final v = box.get(k);
        if (v is String && v.trim().isNotEmpty) return v.trim();
      }
    } catch (_) {}

    return '';
  }

  // ---------- lifecycle ----------
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _chat = ChatService();

    final box = Hive.box(HiveBoxes.userBox);
    final v = box.get('user_id');
    _meId = (v is int) ? v : int.tryParse('$v') ?? -1;

    final as = box.get('allow_suggestions');
    if (as is bool) {
      _allowSuggestions = as;
    }

    assert(_meId > 0, '[ChatThreadScreen] meId must be > 0 (Hive user_id missing?)');
    assert(widget.user.id > 0, '[ChatThreadScreen] other user.id must be > 0 (bad mapping?)');

    _categoryStr = widget.category == ThreadCategory.social ? 'social' : 'dating';

    if (_idsValid) {
      try {
        _threadId = _chat.threadIdFor(_meId, widget.user.id);

        // include suggestion meta in thread meta (Social-only, and only if present)
        final suggestionMeta = (widget.category == ThreadCategory.social)
            ? _buildSuggestionMeta(
          meId: _meId,
          otherId: widget.user.id,
          otherName: widget.user.name.split(' · ').first,
          suggestedById: widget.user.suggestedById,
          suggestedByName: widget.user.suggestedByName,
          suggestedUserId: widget.user.suggestedUserId,
        )
            : null;

        _chat.ensureThread(
          threadId: _threadId,
          meId: _meId,
          otherId: widget.user.id,
          category: _categoryStr,
          meMeta: {'name': 'Me #$_meId'},
          otherMeta: {
            'name': widget.user.name,
            'avatar': widget.user.avatarUrl,
            if (suggestionMeta != null) 'suggestion_banner': suggestionMeta,
          },
        );

        // Load likes from Hive for this thread
        _loadLikesFromHive();

        // 🔔 Try to load "suggestion_success" notification for this pair
        _fetchSuggestionSuccessForThisThread();

        // ✅ Also load authoritative server-driven pair suggestion meta/banner
        _loadPairBanner();
      } catch (e) {
        debugPrint('[ChatThreadScreen] threadIdFor error: $e');
      }
    }

    _messageController.addListener(() => setState(() {}));

    // Hide emoji picker when keyboard opens (Android/iOS)
    _inputFocus.addListener(() {
      if (_inputFocus.hasFocus && _isEmojiPickerVisible) {
        setState(() => _isEmojiPickerVisible = false);
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _metricsDebounce?.cancel();
    _messageController.dispose();
    _inputFocus.dispose();
    _listCtrl.dispose();
    super.dispose();
  }

  // ---------- NEW: authoritative pair-suggestion banner loader ----------
  Future<void> _loadPairBanner() async {
    // needs ChatController to exist
    if (!Get.isRegistered<ChatController>()) return;
    final cc = Get.find<ChatController>();

    // Hit /friendship-suggestion-meta?other_id=... and cache in controller
    await cc.fetchPairSuggestionMeta(otherUserId: widget.user.id);

    // Resolve a user-friendly string from the cached meta
    final text = cc.suggestionBannerForPair(meId: _meId, other: widget.user);

    if (!mounted) return;
    setState(() {
      _pairSuggestionBanner = (text != null && text.trim().isNotEmpty) ? text.trim() : null;
    });
  }

  // ---------- NEW: fetch latest suggestion_success that relates to THIS pair ----------
  Future<void> _fetchSuggestionSuccessForThisThread() async {
    if (_loadedSuggestionSuccess) return;
    _loadedSuggestionSuccess = true;
    final t = _token;
    if (t.isEmpty) return;

    try {
      // Adjust endpoint name if your route differs.
      final res = await ApiService.get('notifications', token: t);

      // Expecting something like:
      // { data: [ { type: "App\\Notifications\\SuggestionSuccess",
      //             data: { type: "suggestion_success", message: "Great news! ...", suggester_id: 123 },
      //             created_at: "..." }, ... ] }
      //
      // or flattened:
      // { data: [ { type: "suggestion_success", message: "..." } ] }

      final list = (res is Map && res['data'] is List) ? (res['data'] as List) : const <dynamic>[];
      if (list.isEmpty) return;

      final otherFirstName = widget.user.name.split(' · ').first.trim();
      String? pickText;

      for (final item in list) {
        if (item is! Map) continue;

        // Try both shapes:
        String? typeStr;
        String? msgStr;

        // shape A: wrapper + data map
        final innerData = (item['data'] is Map) ? Map<String, dynamic>.from(item['data']) : null;
        if (innerData != null) {
          final innerType = (innerData['type'] ?? '').toString().trim().toLowerCase();
          if (innerType == 'suggestion_success') {
            typeStr = innerType;
            msgStr = (innerData['message'] ?? '').toString();
          }
        }

        // shape B: flattened
        if (typeStr == null) {
          final tStr = (item['type'] ?? '').toString().trim().toLowerCase();
          if (tStr == 'suggestion_success') {
            typeStr = tStr;
            msgStr = (item['message'] ?? '').toString();
          }
        }

        if (typeStr == 'suggestion_success' && (msgStr != null && msgStr.trim().isNotEmpty)) {
          // Heuristic: show only if this message mentions the other user’s first name.
          if (otherFirstName.isEmpty || msgStr!.toLowerCase().contains(otherFirstName.toLowerCase())) {
            pickText = msgStr;
            break;
          }
        }
      }

      if (pickText != null && mounted) {
        setState(() => _suggestionSuccessText = pickText);
      }
    } catch (e) {
      debugPrint('notifications (suggestion_success) fetch error: $e');
    }
  }

  // ===== Scrolling helpers =====
  void _jumpToBottom() {
    if (!_listCtrl.hasClients) return;
    try {
      _listCtrl.jumpTo(0); // reverse:true => bottom is offset 0
    } catch (_) {}
  }

  void _animateToBottom() {
    if (_listCtrl.hasClients) {
      _listCtrl.animateTo(
        0, // reverse:true bottom
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    }
  }

  bool get _isNearBottom {
    if (!_listCtrl.hasClients) return true;
    // reverse:true => bottom is offset 0
    return _listCtrl.offset < _autoScrollThreshold;
  }

  void _scrollToBottomSoon({bool animated = true}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (animated) {
        _animateToBottom();
      } else {
        _jumpToBottom();
      }
    });
  }

  // ★ Close keyboard & emoji (WhatsApp-like) when user scrolls/drags the list
  void _closeKeyboardAndEmoji() {
    if (_isEmojiPickerVisible) {
      setState(() => _isEmojiPickerVisible = false);
    }
    _inputFocus.unfocus();
    SystemChannels.textInput.invokeMethod('TextInput.hide');
  }

  // ★ When the keyboard opens/closes, keep the view at the latest message, but
  // use a non-animated jump (no jitter/vibration).
  @override
  void didChangeMetrics() {
    super.didChangeMetrics();
    _metricsDebounce?.cancel();
    _metricsDebounce = Timer(const Duration(milliseconds: 80), () {
      _scrollToBottomSoon(animated: false);
    });
  }

  // Toggle emoji picker (native keyboard stays hidden while open)
  void _toggleEmojiPicker() {
    if (_isEmojiPickerVisible) {
      setState(() => _isEmojiPickerVisible = false);
      _inputFocus.requestFocus();
      SystemChannels.textInput.invokeMethod('TextInput.show');
    } else {
      _inputFocus.unfocus();
      SystemChannels.textInput.invokeMethod('TextInput.hide');
      setState(() => _isEmojiPickerVisible = true);
      _scrollToBottomSoon(animated: false); // keep pinned without animation
    }
  }

  // =======================
  // MEDIA: gallery / camera
  // =======================

  void _openMediaSheet() {
    if (!_idsValid) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Your session is invalid. Please re-login.')),
      );
      return;
    }
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.backgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (bsCtx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Photo Library'),
              onTap: () async {
                Navigator.pop(bsCtx);
                await _pickFromGalleryMulti();
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Camera'),
              onTap: () async {
                Navigator.pop(bsCtx);
                await _takePhoto();
              },
            ),
            const SizedBox(height: 6),
          ],
        ),
      ),
    );
  }

  Future<void> _pickFromGalleryMulti() async {
    if (!_idsValid) return;
    try {
      final files = await _picker.pickMultiImage(imageQuality: 85);
      if (files.isEmpty) return;

      setState(() {
        _selectedImages.addAll(files.map((x) => File(x.path)));
      });

      _scrollToBottomSoon();
    } catch (e) {
      debugPrint('pickMultiImage error: $e');
    }
  }

  Future<void> _takePhoto() async {
    if (!_idsValid) return;
    try {
      final shot = await _picker.pickImage(source: ImageSource.camera, imageQuality: 85);
      if (shot == null) return;

      setState(() => _selectedImages.add(File(shot.path)));
      _scrollToBottomSoon();
    } catch (e) {
      debugPrint('takePhoto error: $e');
    }
  }

  /// Send images (if any), then text (if any).
  Future<void> _sendMessage() async {
    if (_sendingNow) return;
    _sendingNow = true;
    try {
      if (!_idsValid) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Your session is invalid. Please re-login.')),
        );
        return;
      }

      final List<File> imagesToSend = List<File>.from(_selectedImages);
      final String text = _messageController.text.trim();
      if (imagesToSend.isEmpty && text.isEmpty) return;

      // Clear composer immediately
      setState(() {
        _selectedImages.clear();
        _messageController.clear();
      });

      // Optimistic bubbles for each file
      for (final f in imagesToSend) {
        setState(() => _sendingFiles.add(f));
        _scrollToBottomSoon();

        try {
          await _chat.sendImage(threadId: _threadId, meId: _meId, file: f);
        } catch (e) {
          debugPrint('sendImage failed: $e');
          setState(() => _selectedImages.add(f));
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Image failed to send. Check logs or connection.')),
          );
        } finally {
          setState(() => _sendingFiles.remove(f));
        }
      }

      if (text.isNotEmpty) {
        try {
          await _chat.sendText(threadId: _threadId, meId: _meId, text: text);
        } catch (e) {
          debugPrint('sendText failed: $e');
          _messageController.text = text; // restore
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Message failed to send.')),
          );
        } finally {
          _scrollToBottomSoon();
        }
      }
    } finally {
      _sendingNow = false;
    }
  }

  /// Build a unique-ish key for a message to store "liked" state locally.
  String _msgKey(Message m, int index) {
    final txt = m.text ?? '';
    final img = m.imageUrl ?? '';
    final aud = m.audioUrl ?? '';
    return '${m.senderId}|$txt|$img|$aud|$index';
  }

  void _toggleLikeFor(Message m, int index) {
    final key = _msgKey(m, index);
    setState(() {
      if (_likedKeys.contains(key)) {
        _likedKeys.remove(key); // Unlike
      } else {
        _likedKeys.add(key); // Like
      }
    });
    _persistLikesToHive();
  }

  // ===== Suggestion banner helpers =====

  /// Returns a human string like:
  /// - "You suggested  · #otherId"
  /// - "User · #referrerId suggested You"
  /// - "User · #referrerId suggested User · #suggestedUserId"
  /// Uses names when we have them; falls back to "User · #id".
  String? _buildSuggestionMeta({
    required int meId,
    required int otherId,
    required String otherName,
    int? suggestedById,
    String? suggestedByName,
    int? suggestedUserId,
  }) {
    if (suggestedById == null) return null;

    String refName = (suggestedByName != null && suggestedByName.trim().isNotEmpty)
        ? suggestedByName.trim()
        : 'User · #$suggestedById';

    String targetLabel;
    if (suggestedUserId == null) {
      // Unknown target — just show "X suggested this match"
      return '$refName suggested this match';
    }

    if (suggestedUserId == meId) {
      targetLabel = 'You';
    } else if (suggestedUserId == otherId) {
      targetLabel = otherName;
    } else {
      targetLabel = 'User · #$suggestedUserId';
    }

    if (suggestedById == meId) {
      // I suggested <other>
      return 'You suggested $targetLabel';
    } else if (suggestedById == otherId) {
      // Other suggested me
      return '$otherName suggested $targetLabel';
    } else {
      // Third person suggested
      return '$refName suggested $targetLabel';
    }
  }

  @override
  Widget build(BuildContext context) {
    final u = widget.user;
    final title = widget.category == ThreadCategory.social ? 'Social Circle' : 'Dating';
    final keyboardOpen = MediaQuery.of(context).viewInsets.bottom > 0;
    final myAvatar = _myAvatarUrlSafe();

    // Only resolve banner text for Social threads (inline fallback)
    final bannerText = (widget.category == ThreadCategory.social)
        ? _buildSuggestionMeta(
      meId: _meId,
      otherId: u.id,
      otherName: u.name.split(' · ').first,
      suggestedById: u.suggestedById,
      suggestedByName: u.suggestedByName,
      suggestedUserId: u.suggestedUserId,
    )
        : null;

    if (!_idsValid) {
      // Guard UI if ids invalid
      return Scaffold(
        backgroundColor: AppTheme.backgroundColor,
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Image.asset('assets/the_pairup_logo_black.png', height: 70),
                ),
              ),
              SizedBox(
                height: 40,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back, color: Colors.black),
                        onPressed: () => Get.back(id: chatNavId),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                      const SizedBox(width: 5),
                      Expanded(child: Text(title, style: AppTheme.textTheme.bodyLarge)),
                    ],
                  ),
                ),
              ),
              const Divider(height: 1, color: Colors.black12),
              const Expanded(
                child: Center(child: Text('Invalid user session. Please re-login.')),
              ),
            ],
          ),
        ),
      );
    }

    // Gate: show suggestion UI in Social threads if we have any banner-worthy info:
    //  - authoritative pair banner from server, OR
    //  - embedded inline meta in user (legacy fallback), OR
    //  - a suggestion_success notification that references this pair
    final canShowSuggestionUI = widget.category == ThreadCategory.social &&
        (
            (_pairSuggestionBanner ?? '').trim().isNotEmpty ||
                (u.suggestedById != null && u.suggestedById! > 0) ||
                ((_suggestionSuccessText ?? '').trim().isNotEmpty)
        );

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      // Important: we prevent the whole scaffold from resizing to avoid the "vibration".
      resizeToAvoidBottomInset: false,
      body: SafeArea(
        child: Column(
          children: [
            // Logo
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Image.asset('assets/the_pairup_logo_black.png', height: 70),
              ),
            ),

            // Back / Title / Menu
            SizedBox(
              height: 40,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.black),
                      onPressed: () => Get.back(id: chatNavId),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                    const SizedBox(width: 5),
                    Expanded(child: Text(title, style: AppTheme.textTheme.bodyLarge)),
                    IconButton(
                      icon: const Icon(Icons.more_vert, color: Colors.black),
                      onPressed: () => _showThreadMenu(),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              ),
            ),

            const Divider(height: 1, color: Colors.black12),

            // ===== Suggestion banners (Social only; show if present, else nothing) =====
            if (!keyboardOpen && !_isEmojiPickerVisible && canShowSuggestionUI) ...[
              if ((_pairSuggestionBanner ?? '').trim().isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  child: _SuggestionBanner(text: _pairSuggestionBanner!.trim()),
                ),
                const Divider(height: 1, color: Colors.black12),
              ] else if ((_suggestionSuccessText ?? '').trim().isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  child: _SuggestionBanner(text: _suggestionSuccessText!.trim()),
                ),
                const Divider(height: 1, color: Colors.black12),
              ] else if (bannerText != null && bannerText.trim().isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  child: _SuggestionBanner(text: bannerText.trim()),
                ),
                const Divider(height: 1, color: Colors.black12),
              ],
            ],

            // Header card with profile details — disappears when keyboard OR emoji picker is open
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 150),
              switchInCurve: Curves.easeOut,
              switchOutCurve: Curves.easeOut,
              child: (keyboardOpen || _isEmojiPickerVisible)
                  ? const SizedBox.shrink(key: ValueKey('hidden'))
                  : _ChatHeader(user: u, key: const ValueKey('header')),
            ),

            const Divider(height: 1, color: Colors.black12),

            // ==========================
            // Messages area (reverse list)
            // ==========================
            Expanded(
              child: StreamBuilder<List<Message>>(
                stream: _chat.messagesStream(_threadId),
                builder: (context, snap) {
                  final firebaseMsgs = snap.data ?? const <Message>[];
                  final streamReady = snap.connectionState == ConnectionState.active ||
                      snap.connectionState == ConnectionState.done;

                  // build once with local cache if stream not ready
                  if (!streamReady) {
                    return FutureBuilder<List<Map<String, dynamic>>>(
                      future: ChatDatabase().getMessages(_threadId),
                      builder: (context, localSnap) {
                        final localMsgs = (localSnap.data ?? []).map((m) {
                          final senderId = (m['sender_id'] is int)
                              ? m['sender_id'] as int
                              : int.tryParse('${m['sender_id']}') ?? -1;

                          final tsMs = (m['timestamp'] is int)
                              ? m['timestamp'] as int
                              : int.tryParse('${m['timestamp']}') ?? 0;

                          return Message(
                            id: '',
                            senderId: senderId,
                            text: m['text'] as String?,
                            imageUrl: m['image_url'] as String?,
                            audioUrl: m['audio_url'] as String?,
                            createdAt: DateTime.fromMillisecondsSinceEpoch(tsMs),
                          );
                        }).toList();

                        final total = localMsgs.length + _sendingFiles.length;
                        if (total == 0 && localSnap.connectionState == ConnectionState.waiting) {
                          return const Center(child: CircularProgressIndicator());
                        }
                        if (total == 0) {
                          return const Center(child: Text('No messages yet'));
                        }

                        // Build reversed display list
                        final display = <_DisplayItem>[
                          ...localMsgs.map((m) => _DisplayItem.message(m)),
                          ..._sendingFiles.map((f) => _DisplayItem.optimisticFile(f)),
                        ].reversed.toList();

                        return _buildList(display, myAvatar);
                      },
                    );
                  }

                  // Cache Firebase messages to SQLite (fire-and-forget)
                  if (firebaseMsgs.isNotEmpty) {
                    for (final m in firebaseMsgs) {
                      ChatDatabase().insertMessage({
                        'thread_id': _threadId,
                        'sender_id': m.senderId,
                        'text': m.text,
                        'image_url': m.imageUrl,
                        'audio_url': m.audioUrl,
                        'timestamp': m.createdAt.millisecondsSinceEpoch,
                      });
                    }
                  }

                  // Compose display items and reverse so latest is at bottom (offset 0)
                  final display = <_DisplayItem>[
                    ...firebaseMsgs.map((m) => _DisplayItem.message(m)),
                    ..._sendingFiles.map((f) => _DisplayItem.optimisticFile(f)),
                  ].reversed.toList();

                  // ★ Auto-scroll to bottom if new content arrived and user is near bottom
                  final currentCount = display.length;
                  if (currentCount > _lastRenderedCount && _isNearBottom) {
                    // Animate only for new messages, not for keyboard changes.
                    WidgetsBinding.instance.addPostFrameCallback((_) => _animateToBottom());
                  }
                  _lastRenderedCount = currentCount;

                  if (currentCount == 0) {
                    return const Center(child: Text('No messages yet'));
                  }

                  return _buildList(display, myAvatar);
                },
              ),
            ),

            const Divider(height: 1, color: Colors.black12),

            // ===== Input area with preview row =====
            // We only pad THIS area with the keyboard inset to avoid resizing the list.
            AnimatedPadding(
              duration: const Duration(milliseconds: 120),
              curve: Curves.easeOut,
              padding: EdgeInsets.only(
                bottom: _isEmojiPickerVisible
                    ? 0 // emoji panel has its own height
                    : MediaQuery.of(context).viewInsets.bottom,
              ),
              child: _InputBar(
                controller: _messageController,
                focusNode: _inputFocus,
                onEmojiTap: _toggleEmojiPicker,
                onPhotoTap: _openMediaSheet,
                onSend: _sendMessage,
                onMicTap: () {
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: false,
                    backgroundColor: Colors.white,
                    shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                    ),
                    builder: (_) => AudioRecorderSheet(
                      onSend: (file, duration) async {
                        try {
                          await _chat.sendAudio(
                            threadId: _threadId,
                            meId: _meId,
                            file: file,
                            duration: duration,
                          );
                        } catch (e) {
                          debugPrint('sendAudio failed: $e');
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Audio failed to send.')),
                            );
                          }
                        }
                      },
                    ),
                  );
                },
                selectedImages: _selectedImages,
                onRemoveImageAt: (index) => setState(() => _selectedImages.removeAt(index)),
              ),
            ),

            // ===== Emoji picker (over the keyboard area) =====
            Offstage(
              offstage: !_isEmojiPickerVisible,
              child: SizedBox(
                height: 300,
                child: EmojiPicker(
                  onEmojiSelected: (category, emoji) {
                    final text = _messageController.text;
                    final sel = _messageController.selection;
                    final caret = sel.start >= 0 ? sel.start : text.length;
                    final newText = text.replaceRange(caret, caret, emoji.emoji);
                    _messageController.text = newText;
                    final pos = caret + emoji.emoji.length;
                    _messageController.selection = TextSelection.fromPosition(TextPosition(offset: pos));
                    _scrollToBottomSoon(animated: false); // keep pinned without animation
                  },
                  onBackspacePressed: () {
                    final text = _messageController.text;
                    if (text.isEmpty) return;
                    final sel = _messageController.selection;
                    int caret = sel.start >= 0 ? sel.start : text.length;
                    if (caret == 0) return;
                    final newText = text.replaceRange(caret - 1, caret, '');
                    _messageController.text = newText;
                    _messageController.selection =
                        TextSelection.fromPosition(TextPosition(offset: caret - 1));
                  },
                  config: const Config(
                    emojiViewConfig: EmojiViewConfig(emojiSizeMax: 28),
                    categoryViewConfig: CategoryViewConfig(),
                    bottomActionBarConfig: BottomActionBarConfig(),
                    searchViewConfig: SearchViewConfig(),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ★ Render the reversed list in one place
  Widget _buildList(List<_DisplayItem> display, String myAvatar) {
    // Wrap with GestureDetector and NotificationListener to close keyboard/emoji on drag/scroll.
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onPanDown: (_) => _closeKeyboardAndEmoji(),
      onTap: _closeKeyboardAndEmoji, // also close on simple taps in the list area
      child: NotificationListener<ScrollNotification>(
        onNotification: (n) {
          if (n is UserScrollNotification || n is ScrollStartNotification) {
            _closeKeyboardAndEmoji();
          }
          return false; // don't stop the notification from bubbling
        },
        child: ListView.builder(
          controller: _listCtrl,
          reverse: true, // ★ newest at the visual bottom (offset 0)
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          physics: const ClampingScrollPhysics(),
          itemCount: display.length,
          itemBuilder: (context, i) {
            final item = display[i];
            if (item.isMessage) {
              final m = item.message!;
              final isMe = m.senderId == _meId;
              final avatar = isMe ? myAvatar : widget.user.avatarUrl;

              // For liked state key, use visual index i (stable within this build)
              final key = _msgKey(m, i);
              final isLiked = _likedKeys.contains(key);

              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => _showMessageActions(
                  canHeart: !isMe,
                  isLiked: isLiked,
                  messageText: m.text ?? '',
                  onToggleLike: () => _toggleLikeFor(m, i),
                ),
                onLongPress: () => _showMessageActions(
                  canHeart: !isMe,
                  isLiked: isLiked,
                  messageText: m.text ?? '',
                  onToggleLike: () => _toggleLikeFor(m, i),
                ),
                child: _Bubble(
                  isMe: isMe,
                  avatarUrl: avatar,
                  text: m.text,
                  imageFile: null,
                  imageUrl: m.imageUrl,
                  audioUrl: m.audioUrl,
                  audioDurationMs: m.audioDurationMs,
                  showHeart: (!isMe && isLiked),
                  uploading: false,
                ),
              );
            } else {
              // optimistic file bubble
              final f = item.file!;
              return _Bubble(
                isMe: true,
                avatarUrl: myAvatar,
                text: null,
                imageFile: f,
                imageUrl: null,
                audioUrl: null,
                audioDurationMs: null,
                showHeart: false,
                uploading: true,
              );
            }
          },
        ),
      ),
    );
  }

  // ===== Sheets / Actions (CLOSE FIRST, then act) =====
  void _showThreadMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.backgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetCtx) => _MenuSheet(
        showSuggestions: _allowSuggestions,
        onSuggestions: () {
          Navigator.of(sheetCtx).pop();
          _openSuggestionsDialog();
        },
        onExpire: () {
          Navigator.of(sheetCtx).pop();
          _showExpireSheet();
        },
        onBlock: () {
          Navigator.of(sheetCtx).pop();
          _showBlockSheet();
        },
        onFlag: () {
          Navigator.of(sheetCtx).pop();
          _showFlagSheet();
        },
      ),
    );
  }

  void _showMessageActions({
    required String messageText,
    required VoidCallback onToggleLike,
    required bool canHeart,
    required bool isLiked,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.backgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetCtx) => _ActionsSheet(
        canHeart: canHeart,
        isLiked: isLiked,
        onToggleLike: () {
          if (canHeart) {
            Navigator.of(sheetCtx).pop();
            onToggleLike(); // Like / Unlike
          }
        },
        onCopy: () async {
          await Clipboard.setData(ClipboardData(text: messageText));
          Navigator.of(sheetCtx).pop();
          ScaffoldMessenger.of(context)
              .showSnackBar(const SnackBar(content: Text('Message copied to clipboard')));
        },
        onFlag: () {
          Navigator.of(sheetCtx).pop();
          _showFlagSheet();
        },
      ),
    );
  }

  void _showFlagSheet() {
    String selected = '';
    final reasonCtrl = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.backgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetCtx) => StatefulBuilder(
        builder: (ctx, setState) => SingleChildScrollView(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              for (final opt in kFlagReasonIds.keys) ...[
                TextButton(
                  onPressed: () => setState(() => selected = opt),
                  child: Text(
                    opt,
                    style: AppTheme.textTheme.bodyMedium?.copyWith(
                      fontWeight: selected == opt ? FontWeight.bold : FontWeight.normal,
                      decoration: selected == opt ? TextDecoration.underline : TextDecoration.none,
                    ),
                  ),
                ),
                const Divider(color: Color(0xFFC9C9C9), thickness: 0.5, indent: 40, endIndent: 40),
              ],
              if (selected == 'Other')
                TextField(
                  controller: reasonCtrl,
                  maxLines: 2,
                  decoration: InputDecoration(
                    hintText: "Write reason (optional)",
                    hintStyle: AppTheme.textTheme.bodyMedium?.copyWith(
                      color: const Color(0xFF111827).withOpacity(0.5),
                    ),
                    filled: true,
                    fillColor: AppTheme.backgroundColor,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  style: AppTheme.textTheme.bodyMedium?.copyWith(color: Colors.black),
                ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () async {
                  if (selected.isEmpty) {
                    ScaffoldMessenger.of(context)
                        .showSnackBar(const SnackBar(content: Text('Please select a reason')));
                    return;
                  }
                  final reasonId = kFlagReasonIds[selected]!;
                  Navigator.of(sheetCtx).pop();
                  await _flagUser(flaggedId: widget.user.id, reasonId: reasonId, details: reasonCtrl.text);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black,
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: Text("Submit",
                    style: AppTheme.textTheme.labelLarge?.copyWith(color: AppTheme.backgroundColor)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showBlockSheet() {
    final reasonCtrl = TextEditingController();
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.backgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetCtx) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text("Block?", style: Theme.of(context).textTheme.titleLarge, textAlign: TextAlign.center),
            const Divider(color: Colors.grey, thickness: 0.5, indent: 40, endIndent: 40),
            Text("Are you sure you want to block\nthis match?",
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(color: Colors.black)),
            const SizedBox(height: 12),
            TextField(
              controller: reasonCtrl,
              maxLines: 2,
              decoration: InputDecoration(
                hintText: "Reason (optional)",
                hintStyle: AppTheme.textTheme.bodyMedium?.copyWith(
                  color: const Color(0xFF111827).withOpacity(0.5),
                ),
                filled: true,
                fillColor: AppTheme.backgroundColor,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              style: AppTheme.textTheme.bodyMedium?.copyWith(color: Colors.black),
            ),
            const Divider(color: Colors.grey, thickness: 0.5, indent: 40, endIndent: 40),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(sheetCtx).pop(),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.black, width: 2),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                    child: const Text("Cancel", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () async {
                      Navigator.of(sheetCtx).pop();
                      await _blockUser(blockedId: widget.user.id, reason: reasonCtrl.text);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                    child: Text("Block",
                        style: Theme.of(context)
                            .textTheme
                            .labelLarge
                            ?.copyWith(color: AppTheme.backgroundColor, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _showExpireSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.backgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetCtx) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text("Expire?", style: Theme.of(context).textTheme.titleLarge, textAlign: TextAlign.center),
            const Divider(color: Colors.grey, thickness: 0.5, indent: 40, endIndent: 40),
            Text(
              "Are you sure you want to expire this Social Circle connection?",
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(color: Colors.black),
            ),
            const Divider(color: Colors.grey, thickness: 0.5, indent: 40, endIndent: 40),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(sheetCtx).pop(),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.black, width: 2),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                    child: const Text("Cancel",
                        style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () async {
                      Navigator.of(sheetCtx).pop();
                      await _expireUser(receiverId: widget.user.id);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                    child: Text("Expire",
                        style: Theme.of(context)
                            .textTheme
                            .labelLarge
                            ?.copyWith(color: AppTheme.backgroundColor, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

// ---------- Suggestion banner widget (used for both meta + success notice) ----------
class _SuggestionBanner extends StatelessWidget {
  final String text;
  const _SuggestionBanner({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFBFD7FF)),
      ),
      child: Row(
        children: [
          const Icon(Icons.lightbulb_outline, size: 18, color: Colors.black87),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: AppTheme.textTheme.labelMedium?.copyWith(color: Colors.black87),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------- Header card ----------
class _ChatHeader extends StatelessWidget {
  final ChatUser user;
  const _ChatHeader({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    final ageHeight = [
      if (user.age > 0) '${user.age}',
      if (user.height.isNotEmpty) user.height,
    ].join(', ');

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Card(
        color: const Color(0xFFF7DBDD),
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Transform.translate(
                offset: const Offset(0, 10),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(40),
                  child: user.avatarUrl.isNotEmpty
                      ? Image.network(user.avatarUrl, width: 85, height: 90, fit: BoxFit.cover)
                      : Container(width: 85, height: 90, color: Colors.black12, child: const Icon(Icons.person)),
                ),
              ),
              const SizedBox(width: 10),
              Container(height: 110, width: 1, color: Colors.black45),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(user.name.split(' · ').first, style: AppTheme.textTheme.titleLarge),
                    const SizedBox(height: 4),
                    if (ageHeight.isNotEmpty) Text(ageHeight, style: AppTheme.textTheme.titleSmall),
                    const SizedBox(height: 4),
                    if (user.location.isNotEmpty) Text(user.location, style: AppTheme.textTheme.titleMedium),
                    const SizedBox(height: 4),
                    if (user.bio.isNotEmpty)
                      Text(user.bio,
                          style: AppTheme.textTheme.labelMedium, maxLines: 2, overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------- Message bubble ----------
class _Bubble extends StatelessWidget {
  final bool isMe;
  final String avatarUrl;
  final String? text;
  final File? imageFile; // local optimistic
  final String? imageUrl; // remote
  final String? audioUrl; // 🔊 remote audio
  final int? audioDurationMs; // 🔊 remote audio duration (ms)
  final bool showHeart;
  final bool uploading; // show spinner overlay for optimistic

  const _Bubble({
    required this.isMe,
    required this.avatarUrl,
    this.text,
    this.imageFile,
    this.imageUrl,
    this.audioUrl,
    this.audioDurationMs,
    this.showHeart = false,
    this.uploading = false,
  });

  @override
  Widget build(BuildContext context) {
    final avatar = ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: avatarUrl.isNotEmpty
          ? Image.network(avatarUrl, width: 32, height: 32, fit: BoxFit.cover)
          : Container(width: 32, height: 32, color: Colors.black12, child: const Icon(Icons.person, size: 18)),
    );

    Widget content;
    bool isImage = false;
    bool isAudio = false;

    if (imageFile != null) {
      isImage = true;
      content = Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: Image.file(imageFile!, width: 180, fit: BoxFit.cover),
          ),
          if (uploading)
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Center(
                    child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2))),
              ),
            ),
        ],
      );
    } else if (imageUrl != null && imageUrl!.isNotEmpty) {
      isImage = true;
      content = ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: Image.network(imageUrl!, width: 180, fit: BoxFit.cover),
      );
    } else if (audioUrl != null && audioUrl!.isNotEmpty) {
      isAudio = true;
      content = Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
        child: AudioMessageTile(url: audioUrl!, durationMs: audioDurationMs),
      );
    } else {
      content = Text(
        text ?? "",
        style: Theme.of(context).textTheme.labelMedium?.copyWith(color: Colors.black),
      );
    }

    final bubbleCore = Container(
      margin: EdgeInsets.only(right: isMe ? 40 : 0),
      padding: (isImage || isAudio) ? const EdgeInsets.all(8) : const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: isMe ? Colors.white60 : const Color(0xFFF7DBDD),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0x1A111827), width: 1),
      ),
      child: content,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!isMe) ...[avatar, const SizedBox(width: 8)],
          Flexible(
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                bubbleCore,
                if (showHeart)
                  const Positioned(
                    right: -10,
                    bottom: -8,
                    child: Icon(Icons.favorite, size: 18, color: Colors.red),
                  ),
                if (isMe)
                  Positioned(
                    right: 0,
                    top: -2,
                    child: avatar,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------- Input bar (with image previews + mic) ----------
class _InputBar extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode? focusNode; // tiny addition to hook keyboard/emoji toggle
  final VoidCallback onEmojiTap;
  final VoidCallback onPhotoTap;
  final VoidCallback onSend;
  final VoidCallback onMicTap; // 🔊

  final List<File> selectedImages;
  final void Function(int index) onRemoveImageAt;

  const _InputBar({
    required this.controller,
    this.focusNode,
    required this.onEmojiTap,
    required this.onPhotoTap,
    required this.onSend,
    required this.onMicTap,
    required this.selectedImages,
    required this.onRemoveImageAt,
  });

  @override
  Widget build(BuildContext context) {
    final hasText = controller.text.isNotEmpty;
    final hasImages = selectedImages.isNotEmpty;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (hasImages)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.only(left: 16, right: 16, top: 8),
            child: SizedBox(
              height: 110,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: selectedImages.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, i) {
                  final f = selectedImages[i];
                  return Stack(
                    clipBehavior: Clip.none,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.file(f, width: 100, height: 100, fit: BoxFit.cover),
                      ),
                      Positioned(
                        top: -8,
                        right: -8,
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () => onRemoveImageAt(i),
                            child: Container(
                              decoration: const BoxDecoration(color: Colors.black87, shape: BoxShape.circle),
                              padding: const EdgeInsets.all(4),
                              child: const Icon(Icons.close, size: 16, color: Colors.white),
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: const BoxDecoration(
            color: AppTheme.backgroundColor,
            boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, -2))],
          ),
          child: Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: AppTheme.backgroundColor,
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(color: const Color(0xFFC9C9C9), width: 0.5),
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.emoji_emotions_outlined, color: Colors.black),
                        onPressed: onEmojiTap,
                      ),
                      Expanded(
                        child: TextField(
                          controller: controller,
                          focusNode: focusNode,
                          style: Theme.of(context).textTheme.bodySmall,
                          decoration: const InputDecoration(
                            hintText: "Write Your Message",
                            fillColor: AppTheme.backgroundColor,
                            hintStyle: TextStyle(color: Colors.black45),
                            border: InputBorder.none,
                          ),
                          minLines: 1,
                          maxLines: 4,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.photo_library_outlined, color: Colors.black),
                        onPressed: onPhotoTap,
                      ),
                      Container(
                        decoration: const BoxDecoration(color: Colors.black, shape: BoxShape.circle),
                        child: IconButton(
                          icon: Icon((hasText || hasImages) ? Icons.send : Icons.mic, color: Colors.white),
                          onPressed: (hasText || hasImages) ? onSend : onMicTap,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ---------- Bottom sheets (menus) ----------
class _MenuSheet extends StatelessWidget {
  final bool showSuggestions;
  final VoidCallback onSuggestions;
  final VoidCallback onExpire;
  final VoidCallback onBlock;
  final VoidCallback onFlag;
  const _MenuSheet({
    required this.showSuggestions,
    required this.onSuggestions,
    required this.onExpire,
    required this.onBlock,
    required this.onFlag,
  });

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      const SizedBox(height: 12),
      if (showSuggestions) ...[
        TextButton.icon(
          onPressed: onSuggestions,
          icon: const Icon(Icons.bubble_chart_outlined, color: Color(0xFF111827)),
          label: Text("Suggestions",
              style: AppTheme.textTheme.labelLarge?.copyWith(color: const Color(0xFF111827))),
        ),
        const Divider(color: Colors.grey, thickness: 0.5, indent: 40, endIndent: 40),
      ],
      TextButton.icon(
        onPressed: onExpire,
        icon: const Icon(Icons.timer_off_rounded, color: Color(0xFF111827)),
        label: Text("Expire", style: AppTheme.textTheme.labelLarge?.copyWith(color: const Color(0xFF111827))),
      ),
      const Divider(color: Colors.grey, thickness: 0.5, indent: 40, endIndent: 40),
      TextButton.icon(
        onPressed: onBlock,
        icon: const Icon(Icons.block, color: Color(0xFF111827)),
        label: Text("Block", style: AppTheme.textTheme.labelLarge?.copyWith(color: const Color(0xFF111827))),
      ),
      const Divider(color: Colors.grey, thickness: 0.5, indent: 40, endIndent: 40),
      TextButton.icon(
        onPressed: onFlag,
        icon: const Icon(Icons.flag_outlined, color: Color(0xFF111827)),
        label: Text("Flag", style: AppTheme.textTheme.labelLarge?.copyWith(color: const Color(0xFF111827))),
      ),
      const SizedBox(height: 16),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: ElevatedButton(
          onPressed: () => Navigator.of(context).pop(),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.black,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            minimumSize: const Size(double.infinity, 50),
          ),
          child: Text("Cancel", style: AppTheme.textTheme.labelLarge?.copyWith(color: AppTheme.backgroundColor)),
        ),
      ),
      const SizedBox(height: 8),
    ],
  );
}

class _ActionsSheet extends StatelessWidget {
  final VoidCallback onToggleLike;
  final VoidCallback onCopy;
  final VoidCallback onFlag;
  final bool canHeart;
  final bool isLiked;
  const _ActionsSheet({
    required this.onToggleLike,
    required this.onCopy,
    required this.onFlag,
    required this.canHeart,
    required this.isLiked,
  });

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      const SizedBox(height: 12),
      if (canHeart) ...[
        TextButton.icon(
          onPressed: onToggleLike,
          icon: Icon(isLiked ? Icons.favorite : Icons.favorite_border, color: const Color(0xFF111827)),
          label: Text(isLiked ? "Unlike" : "Like",
              style: AppTheme.textTheme.labelLarge?.copyWith(color: const Color(0xFF111827))),
        ),
        const Divider(color: Colors.grey, thickness: 0.5, indent: 40, endIndent: 40),
      ],
      TextButton.icon(
        onPressed: onCopy,
        icon: const Icon(Icons.copy, color: const Color(0xFF111827)),
        label: Text("Copy", style: AppTheme.textTheme.labelLarge?.copyWith(color: const Color(0xFF111827))),
      ),
      const Divider(color: Colors.grey, thickness: 0.5, indent: 40, endIndent: 40),
      TextButton.icon(
        onPressed: onFlag,
        icon: const Icon(Icons.flag_outlined, color: const Color(0xFF111827)),
        label: Text("Flag", style: AppTheme.textTheme.labelLarge?.copyWith(color: const Color(0xFF111827))),
      ),
      const SizedBox(height: 16),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: ElevatedButton(
          onPressed: () => Navigator.of(context).pop(),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.black,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            minimumSize: const Size(double.infinity, 50),
          ),
          child: const Text("Cancel", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        ),
      ),
      const SizedBox(height: 8),
    ],
  );
}

// ====== display item model for reversed list ======
class _DisplayItem {
  final Message? message;
  final File? file;

  bool get isMessage => message != null;

  _DisplayItem.message(this.message) : file = null;
  _DisplayItem.optimisticFile(this.file) : message = null;
}

// ====== local model for suggestion candidates ======
class _SuggestCandidate {
  final int id;
  final String name;
  final String photo;

  _SuggestCandidate({
    required this.id,
    required this.name,
    required this.photo,
  });
}
