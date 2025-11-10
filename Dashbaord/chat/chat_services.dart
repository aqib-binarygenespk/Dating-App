// lib/Dashbaord/chat/chat_services.dart
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

import 'package:dating_app/firebase_options.dart';
import 'chatmodel/chatmodel.dart';
import 'local/chat_db.dart';

class ChatService {
  final _db = FirebaseFirestore.instance;

  static Future<void>? _initOnce;
  static bool _didLogBucket = false;

  // --- STORAGE (force the correct bucket) ---
  // NOTE: kept exactly as you had it.
  FirebaseStorage get _storage {
    const correctBucket = 'gs://the-pair-up-467520.firebasestorage.app';
    return FirebaseStorage.instanceFor(bucket: correctBucket);
  }

  FirebaseStorage get storage => _storage;

  String _coerceToGsUrl(String? input) {
    final s = (input ?? '').trim();
    if (s.isEmpty) return 'gs://the-pair-up-467520.firebasestorage.app';
    if (s.startsWith('gs://')) return s;

    if (s.startsWith('http://') || s.startsWith('https://')) {
      final uri = Uri.tryParse(s);
      if (uri != null) {
        final idx = uri.pathSegments.indexWhere((seg) => seg == 'b');
        if (idx != -1 && idx + 1 < uri.pathSegments.length) {
          final bucket = uri.pathSegments[idx + 1];
          return 'gs://${_normalizeBucketHost(bucket)}';
        }
        final h = uri.host;
        if (h.endsWith('.firebasestorage.app')) return 'gs://$h';
        return 'gs://${_normalizeBucketHost(h)}';
      }
    }

    final hostish = s.replaceAll(RegExp(r'^https?://'), '').split('/').first;
    return 'gs://${_normalizeBucketHost(hostish)}';
  }

  String _normalizeBucketHost(String hostish) {
    var h = hostish.trim();
    if (h.startsWith('gs://')) h = h.substring(5);
    if (h.endsWith('.firebasestorage.app')) return h;
    if (h.endsWith('.appspot.com')) return h;
    if (!h.contains('.')) return '$h.firebasestorage.app';
    return h;
  }

  // --- INIT / HEALTH ---
  Future<void> _ensureFirebaseReady() => _initOnce ??= _init();

  static Future<void> _init() async {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    }

    final auth = FirebaseAuth.instance;
    if (auth.currentUser == null) {
      try {
        await auth.signInAnonymously();
      } catch (e) {
        debugPrint('Anonymous sign-in failed: $e');
      }
    }

    try {
      const correctBucket = 'gs://the-pair-up-467520.firebasestorage.app';
      final st = FirebaseStorage.instanceFor(bucket: correctBucket);
      if (!_didLogBucket) {
        debugPrint('Using storage bucket: $correctBucket');
        _didLogBucket = true;
      }
      await st.ref().list(ListOptions(maxResults: 1)).catchError((_) => null);
    } catch (e) {
      debugPrint('Storage configuration error: $e');
    }
  }

  Future<void> storageWriteProbe() async {
    await _ensureFirebaseReady();
    final r = storage.ref('_health/write_probe${DateTime.now().millisecondsSinceEpoch}.txt');
    try {
      await r.putString('ok', metadata: SettableMetadata(contentType: 'text/plain'));
      debugPrint('🟢 WRITE probe OK: bucket=${r.bucket} path=${r.fullPath}');
    } on FirebaseException catch (e) {
      debugPrint('🔴 WRITE probe FAIL: bucket=${r.bucket} path=${r.fullPath} code=${e.code} msg=${e.message}');
    }
  }

  Future<void> storageHealthcheck() async {
    await _ensureFirebaseReady();
    final ref = _storage.ref('_health/ping.txt');

    try {
      await ref.putString('ok', metadata: SettableMetadata(contentType: 'text/plain'));
      debugPrint('📦 Health upload OK (bucket=${ref.bucket}, path=${ref.fullPath})');

      var delay = const Duration(milliseconds: 150);
      for (var i = 0; i < 6; i++) {
        try {
          final meta = await ref.getMetadata();
          debugPrint('ℹ️  Health metadata OK: size=${meta.size} updated=${meta.updated}');
          break;
        } on FirebaseException catch (e) {
          if (e.code != 'object-not-found') rethrow;
          await Future<void>.delayed(delay);
          delay *= 2;
          if (i == 5) rethrow;
        }
      }

      final url = await _getUrlWithBackoff(ref);
      debugPrint('🟢 Storage healthcheck OK (url=$url)');
    } on FirebaseException catch (e, st) {
      final hint = switch (e.code) {
        'unauthorized' || 'permission-denied' =>
        'Hint: allow read on /_health/** (rules) and verify App Check for Storage.',
        'unauthenticated' => 'Hint: anonymous sign-in failed before upload.',
        _ => 'Hint: Check Storage Rules and App Check enforcement.',
      };
      debugPrint('🔴 Storage healthcheck FAILED '
          '(bucket=${ref.bucket}, path=${ref.fullPath}) '
          'code=${e.code} message=${e.message} — $hint\n$st');
    }
  }

  Future<void> storageDualPing() async {
    await _ensureFirebaseReady();
    final primary = _storage;
    final fallback = FirebaseStorage.instance;

    Future<void> ping(String label, FirebaseStorage s) async {
      final r = s.ref('health/ping${DateTime.now().millisecondsSinceEpoch}.txt');
      try {
        await r.putString('ok', metadata: SettableMetadata(contentType: 'text/plain'));
        debugPrint('📦 $label upload OK: bucket=${r.bucket} path=${r.fullPath}');
        final url = await _getUrlWithBackoff(r);
        debugPrint('🟢 $label URL OK: $url');
      } on FirebaseException catch (e) {
        final msg = (e.code == 'unauthorized' || e.code == 'permission-denied')
            ? 'Likely rules/App Check blocking read — check Storage Rules / enforcement.'
            : e.message;
        debugPrint('🔴 $label FAIL: bucket=${r.bucket} path=${r.fullPath} code=${e.code} msg=$msg');
      }
    }

    await ping('primary(gs://)', primary);
    await ping('default(instance)', fallback);
  }

  // --- THREAD IDS / REFS ---
  String threadIdFor(int a, int b) {
    final lo = a <= b ? a : b;
    final hi = a <= b ? b : a;
    return 'u${lo}_u${hi}';
  }

  (int, int)? parseThreadIds(String threadId) {
    try {
      final parts = threadId.split('_');
      if (parts.length != 2) return null;
      int parse(String s) {
        if (!s.startsWith('u')) throw ArgumentError('bad');
        return int.parse(s.substring(1));
      }
      final a = parse(parts[0]);
      final b = parse(parts[1]);
      return (a <= b) ? (a, b) : (b, a);
    } catch (_) {
      return null;
    }
  }

  DocumentReference<Map<String, dynamic>> _threadRef(String threadId) =>
      _db.collection('threads').doc(threadId);

  CollectionReference<Map<String, dynamic>> _msgs(String threadId) =>
      _threadRef(threadId).collection('messages');

  // --- CREATE / STREAM ---
  Future<void> ensureThread({
    required String threadId,
    required int meId,
    required int otherId,
    required String category,
    Map<String, dynamic>? meMeta,
    Map<String, dynamic>? otherMeta,
  }) async {
    await _ensureFirebaseReady();
    final doc = await _threadRef(threadId).get();
    if (!doc.exists) {
      await _threadRef(threadId).set({
        'participants': [meId, otherId],
        'category': category,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'lastMessage': null,
        'participantMeta': {
          '$meId': meMeta ?? {},
          '$otherId': otherMeta ?? {},
        },
      });
    }
  }

  Stream<List<Message>> messagesStream(String threadId, {int limit = 200}) async* {
    await _ensureFirebaseReady();
    yield* _msgs(threadId)
        .orderBy('createdAt', descending: false)
        .limit(limit)
        .snapshots()
        .map((snap) => snap.docs.map((d) => Message.fromDoc(d)).toList());
  }

  // --- SENDERS (with best-effort local cache) ---
  Future<void> sendText({
    required String threadId,
    required int meId,
    required String text,
  }) async {
    await _ensureFirebaseReady();
    final now = FieldValue.serverTimestamp();

    final added = await _msgs(threadId).add({
      'senderId': meId,
      'text': text,
      'imageUrl': null,
      'audioUrl': null,
      'audioDurationMs': null,
      'createdAt': now,
      'type': 'text',
    });

    // Local cache should never break the send
    try {
      await ChatDatabase().insertMessage({
        'thread_id': threadId,
        'sender_id': meId,
        'text': text,
        'image_url': null,
        'audio_url': null,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      });
    } catch (e, st) {
      debugPrint('[sendText] local cache failed (ignored): $e\n$st');
    }

    Future<void> upd() => _threadRef(threadId).update({
      'lastMessage': {
        'id': added.id,
        'text': text,
        'senderId': meId,
        'type': 'text',
      },
      'updatedAt': now,
    });

    try {
      await upd();
    } on FirebaseException catch (e) {
      if (e.code == 'not-found') {
        final ids = parseThreadIds(threadId);
        if (ids != null) {
          final (a, b) = ids;
          final otherId = (meId == a) ? b : a;
          await ensureThread(threadId: threadId, meId: meId, otherId: otherId, category: 'dating');
          await upd();
        } else {
          rethrow;
        }
      } else {
        rethrow;
      }
    }
  }

  Future<String> _getUrlWithBackoff(Reference r) async {
    var delay = const Duration(milliseconds: 150);
    for (var i = 0; i < 6; i++) {
      try {
        return await r.getDownloadURL();
      } on FirebaseException catch (e) {
        if (e.code != 'object-not-found') rethrow;
        if (i < 5) {
          await Future<void>.delayed(delay);
          delay *= 2;
        }
      }
    }
    return await r.getDownloadURL();
  }

  Future<void> sendImage({
    required String threadId,
    required int meId,
    required File file,
  }) async {
    await _ensureFirebaseReady();

    final exists = await file.exists();
    final size = exists ? await file.length() : -1;
    if (!exists || size <= 0) {
      throw Exception("Picked file does not exist or is empty: ${file.path}");
    }

    final ext = p.extension(file.path).toLowerCase();
    final contentType = switch (ext) {
      '.png' => 'image/png',
      '.webp' => 'image/webp',
      '.heic' => 'image/heic',
      _ => 'image/jpeg',
    };

    final safeThreadId = threadId.replaceAll('/', '_');
    final fileName = '${DateTime.now().millisecondsSinceEpoch}_${meId}${ext.isEmpty ? ".jpg" : ext}';
    final path = 'threads/$safeThreadId/$fileName';

    TaskSnapshot snap;
    Reference usedRef;

    final primaryRef = _storage.ref(path);

    try {
      snap = await primaryRef.putFile(file, SettableMetadata(contentType: contentType));
      usedRef = snap.ref;
    } on FirebaseException {
      const correctBucket = 'gs://the-pair-up-467520.firebasestorage.app';
      final fallbackRef = FirebaseStorage.instanceFor(bucket: correctBucket).ref(path);

      try {
        snap = await fallbackRef.putFile(file, SettableMetadata(contentType: contentType));
        usedRef = snap.ref;
      } on FirebaseException {
        final bytes = await file.readAsBytes();
        const correctBucket2 = 'gs://the-pair-up-467520.firebasestorage.app';
        final dataRef = FirebaseStorage.instanceFor(bucket: correctBucket2).ref(path);
        snap = await dataRef.putData(bytes, SettableMetadata(contentType: contentType));
        usedRef = snap.ref;
      }
    }

    final url = await _getUrlWithBackoff(usedRef);
    final now = FieldValue.serverTimestamp();

    final added = await _msgs(threadId).add({
      'senderId': meId,
      'text': null,
      'imageUrl': url,
      'audioUrl': null,
      'audioDurationMs': null,
      'createdAt': now,
      'type': 'image',
    });

    // Local cache best-effort
    try {
      await ChatDatabase().insertMessage({
        'thread_id': threadId,
        'sender_id': meId,
        'text': null,
        'image_url': url,
        'audio_url': null,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      });
    } catch (e, st) {
      debugPrint('[sendImage] local cache failed (ignored): $e\n$st');
    }

    Future<void> upd() => _threadRef(threadId).update({
      'lastMessage': {
        'id': added.id,
        'imageUrl': url,
        'senderId': meId,
        'type': 'image',
      },
      'updatedAt': now,
    });

    try {
      await upd();
    } on FirebaseException catch (e) {
      if (e.code == 'not-found') {
        final ids = parseThreadIds(threadId);
        if (ids != null) {
          final (a, b) = ids;
          final otherId = (meId == a) ? b : a;
          await ensureThread(threadId: threadId, meId: meId, otherId: otherId, category: 'dating');
          await upd();
        } else {
          rethrow;
        }
      } else {
        rethrow;
      }
    }
  }

  Future<void> sendAudio({
    required String threadId,
    required int meId,
    required File file,
    required Duration duration,
  }) async {
    await _ensureFirebaseReady();

    final safeThreadId = threadId.replaceAll('/', '_');
    final fileName = 'aud_${DateTime.now().millisecondsSinceEpoch}_$meId.m4a';
    final path = 'threads/$safeThreadId/$fileName';

    final ref = _storage.ref(path);
    debugPrint("🪣 [sendAudio] Using bucket: ${ref.bucket}  (gs://${ref.bucket})");
    debugPrint("📤 [sendAudio] Path:         $path");

    late final TaskSnapshot snap;
    try {
      snap = await ref.putFile(file, SettableMetadata(contentType: 'audio/mp4'));
      debugPrint("✅ [sendAudio] Upload complete: ${snap.totalBytes} bytes, state=${snap.state}");
    } on FirebaseException catch (e) {
      debugPrint("❌ [sendAudio] putFile error: code=${e.code}, message=${e.message}");
      rethrow;
    }

    final url = await _getUrlWithBackoff(snap.ref);
    debugPrint("🔗 [sendAudio] URL: $url");

    final now = FieldValue.serverTimestamp();

    final added = await _msgs(threadId).add({
      'senderId': meId,
      'text': null,
      'imageUrl': null,
      'audioUrl': url,
      'audioDurationMs': duration.inMilliseconds,
      'createdAt': now,
      'type': 'audio',
    });

    // Local cache best-effort (no audio_duration_ms column in SQLite)
    try {
      await ChatDatabase().insertMessage({
        'thread_id': threadId,
        'sender_id': meId,
        'text': null,
        'image_url': null,
        'audio_url': url,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      });
    } catch (e, st) {
      debugPrint('[sendAudio] local cache failed (ignored): $e\n$st');
    }

    Future<void> upd() => _threadRef(threadId).update({
      'lastMessage': {
        'id': added.id,
        'audioUrl': url,
        'audioDurationMs': duration.inMilliseconds,
        'senderId': meId,
        'type': 'audio',
      },
      'updatedAt': now,
    });

    try {
      await upd();
    } on FirebaseException catch (e) {
      if (e.code == 'not-found') {
        final ids = parseThreadIds(threadId);
        if (ids != null) {
          final (a, b) = ids;
          final otherId = (meId == a) ? b : a;
          await ensureThread(threadId: threadId, meId: meId, otherId: otherId, category: 'dating');
          await upd();
        } else {
          rethrow;
        }
      } else {
        rethrow;
      }
    }
  }

  // =========================
  // HARD DELETE CHAT HISTORY
  // =========================
  /// Deletes all messages and resets parent thread’s lastMessage.
  Future<void> clearThreadHistory({required String threadId}) async {
    await _ensureFirebaseReady();

    const batchSize = 400; // safe margin under 500
    final msgsCol = _msgs(threadId);

    while (true) {
      final snap = await msgsCol.limit(batchSize).get();
      if (snap.docs.isEmpty) break;

      final batch = _db.batch();
      for (final d in snap.docs) {
        batch.delete(d.reference);
      }
      await batch.commit();

      if (snap.docs.length < batchSize) break;
    }

    try {
      await _threadRef(threadId).update({
        'lastMessage': null,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('[clearThreadHistory] thread update skipped: $e');
    }
  }

  // ============================================
  // PERMANENT DELETE (messages + thread + files)
  // ============================================
  Future<void> deleteThreadPermanently(String threadId) async {
    await _ensureFirebaseReady();
    final safeThreadId = threadId.replaceAll('/', '_');

    // (1) Delete messages
    await clearThreadHistory(threadId: threadId);

    // (2) Delete any Storage uploads for this thread
    await _deleteStorageFolderRecursively('threads/$safeThreadId');

    // (3) Delete the thread doc itself
    try {
      await _threadRef(threadId).delete();
    } on FirebaseException catch (e) {
      if (e.code != 'not-found') {
        debugPrint('[deleteThreadPermanently] delete thread doc failed: ${e.code} ${e.message}');
        rethrow;
      }
    } catch (e) {
      debugPrint('[deleteThreadPermanently] delete thread doc failed: $e');
      rethrow;
    }
  }

  // --- Storage recursive delete helper ---
  Future<void> _deleteStorageFolderRecursively(String prefix) async {
    try {
      final root = _storage.ref(prefix);

      Future<void> recurse(Reference dir) async {
        ListResult list;
        try {
          list = await dir.listAll();
        } on FirebaseException catch (e) {
          if (e.code == 'object-not-found' || e.code == 'unauthorized' || e.code == 'permission-denied') {
            return;
          }
          rethrow;
        }

        // delete files at this level
        for (final item in list.items) {
          try {
            await item.delete();
          } catch (e) {
            debugPrint('[storage delete] item ${item.fullPath} -> $e');
          }
        }

        // recurse into subfolders
        for (final sub in list.prefixes) {
          await recurse(sub);
        }

        // try to delete the folder marker (noop in Storage but harmless)
        try {
          await dir.delete();
        } catch (_) {}
      }

      await recurse(root);
    } catch (e) {
      debugPrint('[deleteStorageFolderRecursively] $prefix -> $e');
    }
  }

  // =========================
  // OPTIONAL: Reactions API
  // =========================
  Future<void> toggleReaction({
    required String threadId,
    required String messageId,
    required String myUid,
    required String emoji, // unicode e.g. "❤️"
  }) async {
    await _ensureFirebaseReady();

    final ref = _msgs(threadId).doc(messageId).collection('reactions').doc(myUid);

    final snap = await ref.get();
    if (snap.exists && (snap.data()?['emoji'] == emoji)) {
      await ref.delete();
    } else {
      await ref.set({
        'emoji': emoji,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }

    // (Optional) record in local recent emojis if your ChatDatabase supports it
    try {
      await ChatDatabase().bumpRecentEmoji(emoji);
    } catch (_) {
      // safe to ignore
    }
  }

  Future<void> removeReaction({
    required String threadId,
    required String messageId,
    required String myUid,
    required String emoji,
  }) async {
    await _ensureFirebaseReady();
    await _msgs(threadId).doc(messageId).collection('reactions').doc(myUid).delete();
  }
}
