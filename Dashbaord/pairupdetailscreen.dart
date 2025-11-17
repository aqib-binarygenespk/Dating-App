import 'package:dating_app/Dashbaord/pairupscreens/pairup/pairupdetailscreen/pairupdetailscreen_controller.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:dating_app/themesfolder/theme.dart';

class EventDetailsScreen extends StatefulWidget {
  final Map<String, dynamic> event;
  const EventDetailsScreen({super.key, required this.event});

  @override
  State<EventDetailsScreen> createState() => _EventDetailsScreenState();
}

class _EventDetailsScreenState extends State<EventDetailsScreen> {
  late final EventDetailsController c;

  @override
  void initState() {
    super.initState();
    c = Get.put(EventDetailsController(event: widget.event));
  }

  /// Make absolute URL if backend gives a relative one.
  String _fullImageUrl(String? path) {
    if (path == null || path.isEmpty) return '';
    final p = path.replaceAll('\\', '');
    if (p.startsWith('http://') || p.startsWith('https://')) return p;
    return 'http://pairup.binarygenes.pk/$p';
  }

  ImageProvider _avatarProvider(String? maybeUrl) {
    final url = _fullImageUrl(maybeUrl);
    if (url.isEmpty) {
      return const AssetImage('assets/dp1.png');
    }
    return NetworkImage(url);
  }

  /// Tries common keys to find a user's profile image URL.
  /// Also handles `photos: [{url|path: ...}]`.
  ImageProvider _suggestionImageProvider(Map<String, dynamic> s) {
    String? pickFirstNonEmpty(List<String> keys) {
      for (final k in keys) {
        final v = s[k];
        if (v is String && v.trim().isNotEmpty) return v.trim();
      }
      return null;
    }

    // direct keys first
    String? url = pickFirstNonEmpty([
      'photo_url',
      'photoPath',
      'photo_path',
      'photo',
      'image',
      'avatar',
      'profile_photo',
      'profilePhoto',
    ]);

    // nested: photos array
    if ((url == null || url.isEmpty) && s['photos'] is List && (s['photos'] as List).isNotEmpty) {
      final first = (s['photos'] as List).first;
      if (first is Map) {
        url = (first['url'] ?? first['path'] ?? '').toString();
      } else if (first is String) {
        url = first;
      }
    }

    final full = _fullImageUrl(url);
    if (full.isEmpty) return const AssetImage('assets/dp1.png');
    return NetworkImage(full);
  }

  String _displayName(Map<String, dynamic> u) {
    return c.displayName(u);
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    final eventImageUrl =
    _fullImageUrl(widget.event['photo_url'] ?? widget.event['photo_path']);

    final location = (widget.event['location'] ?? '').toString();
    final description = (widget.event['description'] ?? '').toString();
    final timeAndDate = (widget.event['time_and_date'] ?? '').toString();

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            /// 🔷 Header
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(15, 0, 15, 0),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Image.asset(
                      'assets/the_pairup_logo_black.png',
                      height: 70,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back, color: Colors.black),
                        onPressed: () => Navigator.pop(context),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          (widget.event['name'] ?? 'Event').toString(),
                          style: textTheme.bodyLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(thickness: 1, height: 1, color: Colors.black12),
              ],
            ),

            /// 🔷 Scrollable Details
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _infoBox("Location", location),
                    const SizedBox(height: 15),
                    _infoBox("Description", description),
                    const SizedBox(height: 15),
                    _infoBox("Time And Date", timeAndDate),
                    const SizedBox(height: 15),

                    _buildLabel("The PairUp Photo"),
                    const SizedBox(height: 8),
                    Container(
                      height: 160,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        image: DecorationImage(
                          image: eventImageUrl.isNotEmpty
                              ? NetworkImage(eventImageUrl)
                              : const AssetImage('assets/event1.png') as ImageProvider,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),

                    const SizedBox(height: 25),

                    // 🔷 Invited People
                    _buildLabel("Invited People"),
                    const SizedBox(height: 10),
                    Obx(() {
                      final invited = c.invitedUsers;
                      if (invited.isEmpty) {
                        return Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: AppTheme.backgroundColor,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.black12),
                          ),
                          child: Text(
                            "No one’s been invited yet.",
                            style: AppTheme.textTheme.bodySmall?.copyWith(color: Colors.black54),
                          ),
                        );
                      }
                      return Wrap(
                        spacing: 14,
                        runSpacing: 14,
                        children: invited.map((u) {
                          final name = _displayName(u);
                          final photoUrl = (u['photo_url'] ?? u['photo_path'] ?? '').toString();
                          return Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              CircleAvatar(
                                radius: 24,
                                backgroundImage: _avatarProvider(photoUrl),
                              ),
                              const SizedBox(height: 6),
                              SizedBox(
                                width: 86,
                                child: Text(
                                  name,
                                  textAlign: TextAlign.center,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppTheme.textTheme.bodySmall?.copyWith(fontSize: 10),
                                ),
                              ),
                            ],
                          );
                        }).toList(),
                      );
                    }),

                    const SizedBox(height: 20),

                    // 🔷 Suggested People (invite with correct payload)
                    _buildLabel("Suggested People"),
                    const SizedBox(height: 12),
                    Obx(() {
                      final suggestions = c.suggestions;
                      final hasSuggestions = suggestions.isNotEmpty;

                      return SizedBox(
                        height: 190,
                        child: ListView.separated(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          scrollDirection: Axis.horizontal,
                          itemCount: hasSuggestions ? suggestions.length : 3,
                          separatorBuilder: (_, __) => const SizedBox(width: 10),
                          itemBuilder: (_, i) {
                            if (!hasSuggestions) {
                              // fallback demo cards
                              final names = ["Sara M", "Dennis T", "Mubarak K"];
                              final cities = ["San Diego, CA", "San Diego, CA", "San Diego, CA"];
                              final pics = ["assets/dp1.png", "assets/dp2.png", "assets/dp3.png"];
                              return _suggestedCard(
                                name: names[i],
                                ageHeight: "29, 5'9\"",
                                location: cities[i],
                                image: const AssetImage('assets/dp1.png'),
                                trailing: _inviteButtonFake(),
                              );
                            }

                            final s = suggestions[i];
                            final userId = (s['id'] as num).toInt();
                            final loading = c.invitingUsers[userId] == true;
                            final already = c.isAlreadyInvited(userId);

                            return _suggestedCard(
                              name: c.nameFromSuggestion(s),
                              ageHeight: c.ageHeightFromSuggestion(s),
                              location: (s['location'] ?? '').toString(),
                              image: _suggestionImageProvider(s),
                              trailing: SizedBox(
                                width: double.infinity,
                                height: 28,
                                child: ElevatedButton(
                                  onPressed: (loading || already)
                                      ? null
                                      : () => c.inviteSuggestedUser(userId: userId),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.black,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    textStyle: const TextStyle(fontSize: 10),
                                    padding: EdgeInsets.zero,
                                  ),
                                  child: loading
                                      ? const SizedBox(
                                    height: 14, width: 14,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2, color: Colors.white,
                                    ),
                                  )
                                      : Text(already ? "Invited" : "Invite"),
                                ),
                              ),
                            );
                          },
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _inviteButtonFake() {
    return SizedBox(
      width: double.infinity,
      height: 28,
      child: ElevatedButton(
        onPressed: null,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.black12,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          textStyle: const TextStyle(fontSize: 10),
          padding: EdgeInsets.zero,
        ),
        child: const Text("Invite"),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Text(
      text,
      style: AppTheme.textTheme.labelLarge?.copyWith(color: Colors.black),
    );
  }

  Widget _infoBox(String label, String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: AppTheme.backgroundColor,
        border: const Border(bottom: BorderSide(color: Colors.black12, width: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: AppTheme.textTheme.labelLarge?.copyWith(color: Colors.black)),
          const SizedBox(height: 8),
          Text(text, style: AppTheme.textTheme.bodySmall?.copyWith(color: Colors.black54)),
        ],
      ),
    );
  }

  /// Generic card for suggestions; `trailing` is the Invite button widget.
  Widget _suggestedCard({
    required String name,
    required String ageHeight,
    required String location,
    required ImageProvider image,
    required Widget trailing,
  }) {
    return ConstrainedBox(
      constraints: const BoxConstraints.tightFor(width: 130),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        decoration: BoxDecoration(
          color: AppTheme.backgroundColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.black12),
        ),
        child: Column(
          children: [
            CircleAvatar(radius: 24, backgroundImage: image),
            const SizedBox(height: 8),
            Text(
              name,
              style: AppTheme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w600,
                fontSize: 11,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              ageHeight,
              style: AppTheme.textTheme.bodySmall?.copyWith(fontSize: 9, color: Colors.black54),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
            Text(
              location,
              style: AppTheme.textTheme.bodySmall?.copyWith(fontSize: 9, color: Colors.black54),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
            const Spacer(),
            SizedBox(width: double.infinity, height: 28, child: trailing),
          ],
        ),
      ),
    );
  }
}
