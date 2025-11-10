import 'package:cloud_firestore/cloud_firestore.dart';

class Message {
  final String id;                 // Firestore doc id
  final int senderId;              // user_id of sender
  final DateTime createdAt;        // always a DateTime in app
  final String? text;
  final String? imageUrl;
  final String? audioUrl;
  final int? audioDurationMs;

  Message({
    required this.id,
    required this.senderId,
    required this.createdAt,
    this.text,
    this.imageUrl,
    this.audioUrl,
    this.audioDurationMs,
  });

  // ✅ Add these for compatibility with chatthread.dart
  int get createdAtMs => createdAt.millisecondsSinceEpoch;
  String get remoteId => id; // if callers expect nullable, String works where String? is allowed

  factory Message.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    final ts = data['createdAt'];
    final DateTime created = switch (ts) {
      Timestamp t => t.toDate(),
      DateTime d => d,
      _ => DateTime.fromMillisecondsSinceEpoch(0),
    };
    return Message(
      id: doc.id,
      senderId: (data['senderId'] is int)
          ? data['senderId'] as int
          : int.tryParse('${data['senderId']}') ?? 0,
      createdAt: created,
      text: data['text'] as String?,
      imageUrl: data['imageUrl'] as String?,
      audioUrl: data['audioUrl'] as String?,
      audioDurationMs: (data['audioDurationMs'] as num?)?.toInt(),
    );
  }

  Map<String, dynamic> toCreateMap() => {
    'senderId': senderId,
    'createdAt': FieldValue.serverTimestamp(),
    if (text != null) 'text': text,
    if (imageUrl != null) 'imageUrl': imageUrl,
    if (audioUrl != null) 'audioUrl': audioUrl,
    if (audioDurationMs != null) 'audioDurationMs': audioDurationMs,
  };

  bool get isImage => (imageUrl != null && imageUrl!.isNotEmpty);
  bool get isAudio => (audioUrl != null && audioUrl!.isNotEmpty);
}
