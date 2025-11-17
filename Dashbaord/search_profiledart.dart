// lib/features/search/Searchdetail/search_profiledart.dart
import 'package:flutter/foundation.dart';

class SearchProfile {
  final int id;
  final String name;
  final int? age;
  /// Height in total inches (nullable)
  final int? height;
  final double? distanceMiles;

  final String? aboutMe;
  final String? bondingMoments;
  final String? pets;
  final String? smokingHabits;
  final String? drinkingHabits;
  final String? dietPreferences;
  final String? loveLanguage;
  final String? attachmentStyle;
  final String? relocateForLove;

  // Extra attributes
  final String? work;
  final String? kids;
  final String? politics;
  final String? religion;
  final String? education;

  final String? instagramLink;
  final String? facebookLink;

  final List<ProfilePhoto> photos;

  /// NEW: video URL (nullable)
  final String? videoUrl;

  /// NEW: who suggested, if any. e.g. "You suggested John D to Alice K."
  final String? suggestedBy;

  /// NEW: true if this card is part of the suggested group
  final bool isSuggested;

  SearchProfile({
    required this.id,
    required this.name,
    required this.age,
    required this.height,
    required this.distanceMiles,
    required this.aboutMe,
    required this.bondingMoments,
    required this.pets,
    required this.smokingHabits,
    required this.drinkingHabits,
    required this.dietPreferences,
    required this.loveLanguage,
    required this.attachmentStyle,
    required this.relocateForLove,
    required this.work,
    required this.kids,
    required this.politics,
    required this.religion,
    required this.education,
    required this.instagramLink,
    required this.facebookLink,
    required this.photos,
    required this.videoUrl,
    required this.suggestedBy,
    required this.isSuggested,
  });

  factory SearchProfile.fromJson(Map<String, dynamic> j) {
    final rawIg = _s(j['instagram_link']) ?? _s(j['Instagram']) ?? _s(j['instagram']);
    final rawFb = _s(j['facebook_link'])  ?? _s(j['Facebook'])  ?? _s(j['facebook']);

    String? _parseBonding(dynamic v) {
      if (v == null) return null;
      if (v is String) return _s(v);
      if (v is List) {
        final answers = v
            .whereType<Map>()
            .map((e) => _s(e['answer']) ?? '')
            .where((s) => s.isNotEmpty)
            .toList();
        if (answers.isNotEmpty) {
          return answers.length <= 3 ? answers.join(', ') : '${answers.take(3).join(", ")}...';
        }
        return '${v.length} selected';
      }
      return _s(v.toString());
    }

    // NEW: suggested flags from backend
    final String? suggestedBy = _s(j['suggested_by']);
    final bool isSuggested = j['is_suggested'] == true || (suggestedBy != null && suggestedBy.isNotEmpty);

    return SearchProfile(
      id: _toInt(j['id']) ?? 0,
      name: (j['name'] ?? '').toString(),
      age: _toInt(j['age']),
      height: _parseHeight(j['height']),
      distanceMiles: _toDouble(j['distance_miles']) ?? _toDouble(j['distance']),
      aboutMe: _s(j['about_me']),
      bondingMoments: _parseBonding(j['bonding_moments']),
      pets: _s(j['pets']),
      smokingHabits: _s(j['smoking_habits']),
      drinkingHabits: _s(j['drinking_habits']),
      dietPreferences: _s(j['diet_preferences']),
      loveLanguage: _s(j['love_language']),
      attachmentStyle: _s(j['attachment_style']),
      relocateForLove: _s(j['relocate_for_love']),
      work: _s(j['work']),
      kids: _s(j['kids']),
      politics: _s(j['politics']),
      religion: _s(j['religion']),
      education: _s(j['education']),
      instagramLink: _normalizeHttpUrl(rawIg),
      facebookLink:  _normalizeHttpUrl(rawFb),
      photos: _parsePhotos(j['photos']),
      videoUrl: _s(j['video_url']),  // << NEW: parse video_url
      suggestedBy: suggestedBy,
      isSuggested: isSuggested,
    );
  }

  // ---------- helpers ----------
  static String? _s(dynamic v) {
    if (v == null) return null;
    final s = v.toString().trim();
    return s.isEmpty ? null : s;
  }

  static int? _toInt(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString());
  }

  static double? _toDouble(dynamic v) {
    if (v == null) return null;
    if (v is double) return v;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString());
  }

  static String? _normalizeHttpUrl(String? raw) {
    if (raw == null) return null;
    final s = raw.trim();
    if (s.isEmpty) return null;
    if (s.startsWith('https://') || s.startsWith('http://')) return s;
    return 'https://$s';
  }

  /// Accepts formats and returns **total inches**:
  /// - int / num (in inches)
  /// - "5'11\"" or "5'11"
  /// - "5.00" (feet.decimal)   -> 5ft 0in
  /// - "69" (string inches)
  static int? _parseHeight(dynamic raw) {
    if (raw == null) return null;
    if (raw is int) return raw;
    if (raw is num) return raw.toInt();

    final s = raw.toString().trim();
    if (s.isEmpty) return null;

    final reFeetIn = RegExp("^\\s*(\\d+)\\s*'\\s*(\\d+)?\\s*\\\"?\\s*\$");
    final m = reFeetIn.firstMatch(s);
    if (m != null) {
      final ft = int.tryParse(m.group(1)!) ?? 0;
      final inch = int.tryParse(m.group(2) ?? '0') ?? 0;
      return ft * 12 + inch.clamp(0, 11);
    }

    final d = double.tryParse(s);
    if (d != null) {
      final ft = d.floor();
      final inches = ((d - ft) * 12).round().clamp(0, 11);
      return ft * 12 + inches;
    }

    final asInt = int.tryParse(s);
    if (asInt != null) return asInt;
    return null;
  }

  static List<ProfilePhoto> _parsePhotos(dynamic v) {
    final out = <ProfilePhoto>[];
    if (v is List) {
      for (final e in v) {
        if (e is Map<String, dynamic>) {
          out.add(ProfilePhoto.fromJson(e));
        } else if (e is Map) {
          out.add(ProfilePhoto.fromJson(Map<String, dynamic>.from(e)));
        } else if (e is String) {
          out.add(ProfilePhoto(id: 0, url: _normalizeUrl(e)));
        }
      }
    }
    return out;
  }

  static String _normalizeUrl(String url) {
    final u = url.replaceAll('\\', '');
    if (u.startsWith('https://') || u.startsWith('http://')) return u;
    return 'https://pairup.binarygenes.pk/$u';
  }
}

class ProfilePhoto {
  final int id;
  final String url;

  ProfilePhoto({required this.id, required this.url});

  factory ProfilePhoto.fromJson(Map<String, dynamic> j) {
    final raw = (j['url'] ?? '').toString();
    return ProfilePhoto(
      id: SearchProfile._toInt(j['id']) ?? 0,
      url: SearchProfile._normalizeUrl(raw),
    );
  }
}
