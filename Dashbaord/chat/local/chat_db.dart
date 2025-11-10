// lib/Dashbaord/chat/local/chat_db.dart
import 'dart:io';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' show join;

class ChatDatabase {
  static final ChatDatabase _instance = ChatDatabase._internal();
  factory ChatDatabase() => _instance;
  ChatDatabase._internal();

  Database? _db;

  // ========================== PUBLIC API ==========================

  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _initDB('pairup_chat.db');
    return _db!;
  }

  Future<void> insertMessage(Map<String, dynamic> data) async {
    final db = await database;
    await db.insert('messages', data, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Map<String, dynamic>>> getMessages(String threadId) async {
    final db = await database;
    return db.query(
      'messages',
      where: 'thread_id = ? AND (deleted_at IS NULL)',
      whereArgs: [threadId],
      orderBy: 'timestamp ASC',
    );
  }

  Future<void> deleteMessages(String threadId) async {
    final db = await database;
    await db.delete('messages', where: 'thread_id = ?', whereArgs: [threadId]);
  }

  Future<void> clearAll() async {
    final db = await database;
    await db.delete('messages');
    await db.delete('message_media');
    await db.delete('message_reactions');
    await db.delete('recent_emojis');
    // keep emoji_catalog (so you don’t have to re-seed)
  }

  // -------- Optional helpers for richer local features --------

  Future<int> insertMedia({
    required int messageId,
    required String kind, // 'image' | 'audio' | 'video' | 'file'
    required String pathOrUrl,
    String? mimeType,
    int? sizeBytes,
    int? width,
    int? height,
    double? durationSec,
    String? thumbnailPath,
  }) async {
    final db = await database;
    return db.insert('message_media', {
      'message_id': messageId,
      'kind': kind,
      'path': pathOrUrl,
      'mime_type': mimeType,
      'size_bytes': sizeBytes,
      'width': width,
      'height': height,
      'duration_sec': durationSec,
      'thumbnail_path': thumbnailPath,
      'created_at': DateTime.now().millisecondsSinceEpoch,
    });
  }

  Future<List<Map<String, dynamic>>> getMediaForMessage(int messageId) async {
    final db = await database;
    return db.query(
      'message_media',
      where: 'message_id = ?',
      whereArgs: [messageId],
      orderBy: 'id ASC',
    );
  }

  Future<void> addOrToggleReaction({
    required int messageId,
    required String userId, // Firebase UID (or any unique user key)
    required String emoji,  // unicode, e.g. "👍"
  }) async {
    final db = await database;

    final existing = await db.query(
      'message_reactions',
      where: 'message_id = ? AND user_id = ? AND emoji = ?',
      whereArgs: [messageId, userId, emoji],
      limit: 1,
    );

    if (existing.isNotEmpty) {
      await db.delete(
        'message_reactions',
        where: 'message_id = ? AND user_id = ? AND emoji = ?',
        whereArgs: [messageId, userId, emoji],
      );
      return;
    }

    await db.insert(
      'message_reactions',
      {
        'message_id': messageId,
        'user_id': userId,
        'emoji': emoji,
        'created_at': DateTime.now().millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }

  Future<void> removeReaction({
    required int messageId,
    required String userId,
    required String emoji,
  }) async {
    final db = await database;
    await db.delete(
      'message_reactions',
      where: 'message_id = ? AND user_id = ? AND emoji = ?',
      whereArgs: [messageId, userId, emoji],
    );
  }

  Future<List<Map<String, dynamic>>> getReactions(int messageId) async {
    final db = await database;
    return db.query(
      'message_reactions',
      where: 'message_id = ?',
      whereArgs: [messageId],
      orderBy: 'created_at',
    );
  }

  Future<void> upsertEmojiCatalog(List<Map<String, dynamic>> emojis) async {
    // each item: {'unicode': '👍', 'short_name': 'thumbs_up'}
    final db = await database;
    final batch = db.batch();
    for (final e in emojis) {
      batch.insert(
        'emoji_catalog',
        {
          'unicode': e['unicode'],
          'short_name': e['short_name'],
        },
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    }
    await batch.commit(noResult: true);
  }

  Future<void> bumpRecentEmoji(String unicode) async {
    final db = await database;

    await db.insert(
      'emoji_catalog',
      {'unicode': unicode, 'short_name': unicode},
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );

    final row = await db.query('emoji_catalog', where: 'unicode = ?', whereArgs: [unicode], limit: 1);
    if (row.isEmpty) return;
    final emojiId = row.first['id'] as int;

    final existing = await db.query('recent_emojis', where: 'emoji_id = ?', whereArgs: [emojiId], limit: 1);

    if (existing.isEmpty) {
      await db.insert('recent_emojis', {
        'emoji_id': emojiId,
        'usage_count': 1,
        'last_used_at': DateTime.now().millisecondsSinceEpoch,
      });
    } else {
      await db.update(
        'recent_emojis',
        {
          'usage_count': (existing.first['usage_count'] as int) + 1,
          'last_used_at': DateTime.now().millisecondsSinceEpoch,
        },
        where: 'emoji_id = ?',
        whereArgs: [emojiId],
      );
    }
  }

  Future<List<Map<String, dynamic>>> getRecentEmojis({int limit = 24}) async {
    final db = await database;
    return db.query('recent_emojis', orderBy: 'last_used_at DESC', limit: limit);
  }

  // ====================== OPEN & MIGRATIONS ======================

  Future<Database> _initDB(String fileName) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, fileName);

    // If you ever hit persistent open issues on iOS/macOS due to older WAL attempts,
    // you can enable this cleanup (safe when DB is closed):
    // if (!Platform.isAndroid) {
    //   await _cleanupWalShm(path);
    // }

    return openDatabase(
      path,
      version: 3, // v1 base, v2 adds edited_at/deleted_at, v3 adds media/reactions/emoji
      onConfigure: (db) async {
        // Keep this — foreign key constraints
        await db.execute('PRAGMA foreign_keys = ON;');

        // WAL gives perf on Android; on iOS/macOS it can fail. Never crash here.
        if (Platform.isAndroid) {
          try {
            // rawQuery returns the effective mode (e.g. [{journal_mode: wal}])
            await db.rawQuery('PRAGMA journal_mode = WAL');
          } catch (_) {
            // ignore — default journaling is fine
          }
        }
      },
      onCreate: (db, version) async {
        await _createV1(db);
        if (version >= 2) await _migrateV1toV2(db);
        if (version >= 3) await _migrateV2toV3(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) await _migrateV1toV2(db);
        if (oldVersion < 3) await _migrateV2toV3(db);
      },
    );
  }

  Future<void> _createV1(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS messages (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        thread_id TEXT,
        sender_id INTEGER,
        text TEXT,
        image_url TEXT,
        audio_url TEXT,
        timestamp INTEGER
      )
    ''');

    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_messages_thread_ts ON messages(thread_id, timestamp)',
    );
  }

  // v2: add non-breaking columns for soft-delete + edited timestamps
  Future<void> _migrateV1toV2(Database db) async {
    await db.execute('ALTER TABLE messages ADD COLUMN edited_at INTEGER NULL');  // ms epoch
    await db.execute('ALTER TABLE messages ADD COLUMN deleted_at INTEGER NULL'); // ms epoch
  }

  // v3: richer local data (media, reactions, emoji recents)
  Future<void> _migrateV2toV3(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS message_media (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        message_id INTEGER NOT NULL,
        kind TEXT NOT NULL,                   -- image | audio | video | file
        path TEXT NOT NULL,                   -- local path or remote URL
        mime_type TEXT,
        size_bytes INTEGER,
        width INTEGER,
        height INTEGER,
        duration_sec REAL,
        thumbnail_path TEXT,
        created_at INTEGER NOT NULL,
        FOREIGN KEY (message_id) REFERENCES messages(id) ON DELETE CASCADE
      )
    ''');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_media_message ON message_media(message_id)');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS message_reactions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        message_id INTEGER NOT NULL,
        user_id TEXT NOT NULL,               -- firebase uid (or internal id)
        emoji TEXT NOT NULL,                 -- store unicode directly
        created_at INTEGER NOT NULL,
        FOREIGN KEY (message_id) REFERENCES messages(id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE UNIQUE INDEX IF NOT EXISTS uq_reaction_msg_user_emoji
      ON message_reactions(message_id, user_id, emoji)
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS emoji_catalog (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        unicode TEXT NOT NULL UNIQUE,
        short_name TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS recent_emojis (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        emoji_id INTEGER NOT NULL UNIQUE,
        usage_count INTEGER NOT NULL DEFAULT 1,
        last_used_at INTEGER NOT NULL,
        FOREIGN KEY (emoji_id) REFERENCES emoji_catalog(id) ON DELETE CASCADE
      )
    ''');
  }

  // -------- Optional cleanup for stale WAL/SHM (use only if needed) --------
  Future<void> _cleanupWalShm(String path) async {
    try {
      final wal = File('$path-wal');
      final shm = File('$path-shm');
      if (await wal.exists()) await wal.delete();
      if (await shm.exists()) await shm.delete();
    } catch (_) {/* ignore */}
  }
}
