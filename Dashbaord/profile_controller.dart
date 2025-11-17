import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hive/hive.dart';

import 'package:dating_app/hive_utils/hive_boxes.dart';
import 'package:dating_app/services/api_services.dart';

class ProfileController extends GetxController {
  final userName = ''.obs;
  final ageHeight = ''.obs;

  /// Backend returns absolute URL for video. Keep separate from images.
  final videoUrl = ''.obs;

  /// If you still need a primary image somewhere else, keep this; otherwise unused.
  final profileImage = ''.obs;

  final imageUrls = <String>[].obs;

  final profileDetails = <Map<String, String>>[].obs;
  final isFavorite = false.obs;

  @override
  void onInit() {
    super.onInit();
    fetchProfile();
  }

  void toggleFavorite() => isFavorite.value = !isFavorite.value;

  void _showSnack(String title, String message) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (Get.overlayContext != null) {
        Get.snackbar(title, message);
      } else {
        Future.microtask(() {
          if (Get.overlayContext != null) Get.snackbar(title, message);
        });
      }
    });
  }

  Future<void> fetchProfile() async {
    final token = Hive.box(HiveBoxes.userBox).get('auth_token');
    if (token == null) {
      _showSnack("Error", "Missing authentication token.");
      return;
    }

    try {
      final response = await ApiService.get('profile', token: token);

      if (response['success'] == true && response['data'] != null) {
        final data = response['data'];

        userName.value = (data['name'] ?? '').toString();
        final age = data['age']?.toString() ?? '';
        final height = data['height']?.toString() ?? '';
        ageHeight.value = "$age${height.isNotEmpty ? ', $height ft' : ''}";

        // ► Store video URL separately; fall back to empty string if not provided
        final rawVideo = (data['video_url'] ?? '').toString().trim();
        videoUrl.value = rawVideo.isNotEmpty ? _normalizeUrl(rawVideo) : '';

        // Keep for compatibility if you were using this elsewhere
        profileImage.value =
        (rawVideo.isNotEmpty ? videoUrl.value : 'assets/default_profile.png');

        // Photos
        final photosUrls = <String>[];
        if (data['photos'] is List) {
          for (final p in (data['photos'] as List)) {
            if (p is Map && p['url'] != null) {
              photosUrls.add(p['url'].toString());
            } else if (p is String) {
              photosUrls.add(p);
            }
          }
        } else if (data['images'] is List) {
          photosUrls.addAll(
            List<String>.from((data['images'] as List).map((e) => e.toString())),
          );
        }
        imageUrls.value = photosUrls.map(_normalizeUrl).toList();

        // prefer server strings; fallback to user_answers when missing
        final uaList = (data['user_answers'] as List?) ?? const [];
        String _prefer(dynamic v, String Function() fb) {
          final s = v?.toString().trim();
          return (s != null && s.isNotEmpty) ? s : fb();
        }

        final kidsTxt = _prefer(
          data['kids'],
              () => _answerTextFromUA(uaList, 33, fallbackLabels: _kidsLabels),
        );
        final politicsTxt = _prefer(
          data['politics'],
              () => _answerTextFromUA(uaList, 34, fallbackLabels: _politicsLabels),
        );
        final religionTxt = _prefer(
          data['religion'],
              () => _answerTextFromUA(uaList, 35, fallbackLabels: _religionLabels),
        );
        final educationTxt = _prefer(
          data['education'],
              () => _answerTextFromUA(uaList, 36, fallbackLabels: _educationLabels),
        );
        final zodiacTxt = _prefer(
          data['zodiac_sign'],
              () => _answerTextFromUA(uaList, 37, fallbackLabels: _zodiacLabels),
        );

        final loveLangFormatted = _prefer(
          data['love_language'],
              () => _formatLoveLanguages(data['love_language']),
        );
        final bondingFormatted = _computeBondingMoments(data);

        profileDetails.value = [
          _detail('About Me', data['about_me']),
          _detail('Bonding Moments', bondingFormatted),
          _detail('Relationship Goals', data['relationship_goals']),
          _detail('Kids', kidsTxt),
          _detail('Pets', data['pets']),
          _detail('Smoking Habits', data['smoking_habits']),
          _detail('Drinking Habits', data['drinking_habits']),
          _detail('Dietary Preferences', data['diet_preferences']),
          _detail('Love Languages', loveLangFormatted),
          _detail('Attachment Style', data['attachment_style']),
          _detail('Relocate for Love', data['relocate_for_love']),
          _detail('Politics', politicsTxt),
          _detail('Religion', religionTxt),
          _detail('Education', educationTxt),
          _detail('Zodiac Sign', zodiacTxt),
        ];
      } else {
        _showSnack("Error",
            (response['message'] ?? "Failed to fetch profile.").toString());
      }
    } catch (e) {
      _showSnack("Error", "Something went wrong while fetching profile.");
      debugPrint('fetchProfile error: $e');
    }
  }

  Map<String, String> _detail(String title, dynamic content) {
    final text = content?.toString().trim();
    return {
      'title': title,
      'content': (text == null || text.isEmpty) ? 'Not provided' : text
    };
  }

  String _answerTextFromUA(List uaList, int qid, {List<String>? fallbackLabels}) {
    for (final e in uaList) {
      if (e is! Map) continue;
      final q = int.tryParse(e['question_id']?.toString() ?? '');
      if (q != qid) continue;

      final ansText = (e['answer'] ?? e['answer_text'])?.toString().trim();
      if (ansText != null && ansText.isNotEmpty) return ansText;

      final aid = int.tryParse(e['answer_id']?.toString() ?? '');
      if (aid != null &&
          fallbackLabels != null &&
          aid >= 1 &&
          aid <= fallbackLabels.length) {
        return fallbackLabels[aid - 1];
      }
      break;
    }
    return 'Not provided';
  }

  static const _politicsLabels = ['Apolitical', 'Moderate', 'Liberal', 'Conservative'];
  static const _religionLabels = [
    'No Preference',
    'Christian',
    'Catholic',
    'Jewish',
    'Muslim',
    'Unitarian / Universalist',
    'Buddhist',
    'Hindu',
    'Agnostic',
    'Atheist',
    'Other'
  ];
  static const _educationLabels = [
    'High school',
    'Trade/tech school',
    'In college',
    'Undergraduate degree',
    'In grad school',
    'Graduate degree'
  ];
  static const _zodiacLabels = [
    'Aries',
    'Taurus',
    'Gemini',
    'Cancer',
    'Leo',
    'Virgo',
    'Libra',
    'Scorpio',
    'Sagittarius',
    'Capricorn',
    'Aquarius',
    'Pisces'
  ];
  static const _kidsLabels = [
    'Have kids',
    "Don't have kids",
    'Want kids',
    'Open to them',
    'Not sure'
  ];

  String _formatLoveLanguages(dynamic raw) {
    if (raw is List) return raw.whereType<String>().join(', ');
    if (raw is String) {
      try {
        final parsed = raw.trim();
        if (parsed.startsWith('[') && parsed.endsWith(']')) {
          final List<dynamic> decoded = jsonDecode(parsed);
          return decoded.whereType<String>().join(', ');
        } else {
          return _formatCommaList(parsed);
        }
      } catch (_) {
        return _formatCommaList(raw);
      }
    }
    return 'Not provided';
  }

  String _formatCommaList(String raw) =>
      (raw
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList()
        ..removeWhere((e) => e.isEmpty))
          .join(', ')
          .trim()
          .isEmpty
          ? 'Not provided'
          : raw;

  String _computeBondingMoments(dynamic data) {
    if (data is Map && data['bonding_moments'] is List) {
      final List bm = data['bonding_moments'];
      final pairs = <Map<String, int>>[];

      for (final e in bm) {
        if (e is! Map) continue;
        int? qIdx;
        final qStr = e['question']?.toString() ?? '';
        final match = RegExp(r'\((\d+)\)').firstMatch(qStr);
        if (match != null) qIdx = int.tryParse(match.group(1)!);
        qIdx ??= _safeInt(e['question_id']);
        if (qIdx == null || qIdx < 1 || qIdx > 14) continue;

        final aId = _safeInt(e['answer_id']);
        int? opt;
        if (e['answer'] is String && (e['answer'] as String).trim().isNotEmpty) {
          final ans = (e['answer'] as String).trim().toLowerCase();
          if (ans == 'left') opt = 1;
          if (ans == 'right') opt = 2;
        }
        opt ??= (aId != null ? ((aId % 2 == 0) ? 2 : 1) : 1);
        pairs.add({'q': qIdx, 'a': opt});
      }

      final txt = _formatBondingPairs(pairs);
      if (txt.isNotEmpty) return txt;
    }
    return 'Not provided';
  }

  int? _safeInt(dynamic v) => v is int ? v : int.tryParse(v.toString());

  String _formatBondingPairs(List<Map<String, int>> pairs) {
    const bondingMap = {
      1: ['Friday night in with a homemade meal', 'Exploring restaurants and bars'],
      2: ['Running a marathon on a Sunday', 'Grabbing brunch with your boo'],
      3: ['Cozy movie marathon', 'Outdoor movie night under the stars'],
      4: ['Camper adventures', 'Glamping experiences'],
      5: ['Living in a downtown apartment', 'Living in a big house in the suburbs'],
      6: ['On a sunny day, lounging poolside', 'On a sunny day, taking a dip in the ocean'],
      7: ['Cooking at home together', 'Dining out for a culinary adventure'],
      8: ['Wine tasting tour', 'Visiting local breweries for beer tasting'],
      9: ['Road trip explorations', 'Relaxing in an airport lounge'],
      10: ['Fall asleep cuddling with a TV on', 'Fall asleep cuddling in blissful silence'],
      11: ['Cooking over a campfire', 'Enjoying the luxury of room service'],
      12: ['Live music in the open air', 'Enjoying music at home'],
      13: ['Connecting over cocktails', 'Connecting over mocktails'],
      14: ['Taking your dog on a play date', 'Organizing a kid play date'],
    };
    final selected = <String>[];
    for (final p in pairs) {
      final opts = bondingMap[p['q']];
      final idx = (p['a'] ?? 1) - 1;
      if (opts != null && idx >= 0 && idx < opts.length) selected.add(opts[idx]);
    }
    if (selected.isEmpty) return '';
    return selected.take(3).join(', ') + (selected.length > 3 ? ' ...' : '');
  }

  String _normalizeUrl(String url) {
    if (url.startsWith("http")) return url.replaceAll('\\', '');
    return "https://pairup.binarygenes.pk/$url".replaceAll('\\', '');
  }
}
