import 'package:dating_app/Dashbaord/pairupscreens/pairup/pairup_controller.dart';
import 'package:dating_app/themesfolder/theme.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class InvitationDetailsScreen extends StatelessWidget {
  final Map<String, dynamic> event;

  const InvitationDetailsScreen({super.key, required this.event});

  // Simple date formatter
  String _fmtDate(String? s) {
    if (s == null || s.isEmpty) return '';
    final dt = DateTime.tryParse(s);
    if (dt == null) return s;
    final local = dt.toLocal();
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${months[local.month - 1]} ${local.day}, ${local.year} • '
        '${(local.hour % 12 == 0 ? 12 : local.hour % 12)}:'
        '${local.minute.toString().padLeft(2, '0')} '
        '${local.hour >= 12 ? 'PM' : 'AM'}';
  }

  /// Helper to extract the "Invited By" name safely.
  String _getInvitedByName() {
    // First priority: direct name field
    if (event['creator_name'] != null && event['creator_name'].toString().isNotEmpty) {
      return event['creator_name'].toString();
    }
    if (event['invited_by'] != null && event['invited_by'].toString().isNotEmpty) {
      return event['invited_by'].toString();
    }

    // Second: check if event has 'created_by' and invited users contain matching ID
    final createdBy = event['created_by'];
    if (createdBy != null && event['invited_users'] is List) {
      final invited = event['invited_users'] as List;
      for (final u in invited) {
        if (u is Map && u['id'].toString() == createdBy.toString()) {
          final first = u['first_name'] ?? '';
          final last = u['last_name'] ?? '';
          final name = '$first $last'.trim();
          if (name.isNotEmpty) return name;
        }
      }
    }

    // Fallback
    return 'N/A';
  }

  @override
  Widget build(BuildContext context) {
    final c = Get.find<PairUpController>();
    final textTheme = Theme.of(context).textTheme;
    final invitedUsers = (event['invited_users'] is List)
        ? event['invited_users'] as List
        : const [];

    final photoUrl = (event['photo_url'] ?? '').toString();
    final ImageProvider headerImage =
    photoUrl.isNotEmpty ? NetworkImage(photoUrl) : const AssetImage('assets/event1.png');

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            // Header/logo + title
            Padding(
              padding: const EdgeInsets.fromLTRB(15, 0, 15, 0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Image.asset('assets/the_pairup_logo_black.png', height: 70),
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
                      (event['name'] ?? 'Event Title').toString(),
                      style: textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            const Divider(thickness: 1, height: 1, color: Colors.black12),

            // Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _infoBox("Invited By", _getInvitedByName()),
                    const SizedBox(height: 15),
                    _infoBox("Description", (event['description'] ?? '').toString()),
                    const SizedBox(height: 15),
                    _infoBox("Time And Date", _fmtDate(event['time_and_date']?.toString())),
                    const SizedBox(height: 15),
                    _infoBox("Location", (event['location'] ?? '').toString()),
                    const SizedBox(height: 15),

                    _label("The PairUp Photo"),
                    Container(
                      height: 160,
                      width: double.infinity,
                      margin: const EdgeInsets.only(top: 8),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        image: DecorationImage(image: headerImage, fit: BoxFit.cover),
                      ),
                    ),

                    const SizedBox(height: 20),
                    _label("Invited People"),
                    const SizedBox(height: 10),
                    invitedUsers.isEmpty
                        ? const Text("No invited users found.")
                        : Wrap(
                      spacing: 10,
                      runSpacing: 8,
                      children: invitedUsers.map((u) {
                        final name =
                        "${u['first_name'] ?? ''} ${u['last_name'] ?? ''}".trim();
                        final img = (u['profile_photo_url'] ?? '').toString();
                        return _InviteChip(
                          name: name.isEmpty ? 'User' : name,
                          imageUrl: img,
                        );
                      }).toList(),
                    ),

                    const SizedBox(height: 30),

                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () => c.respondToInvitation(
                              eventId: event['id'] is int
                                  ? event['id']
                                  : int.tryParse(event['id'].toString()) ?? 0,
                              accept: true,
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.black,
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              minimumSize: const Size.fromHeight(40),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                            ),
                            child: Text(
                              "Accept",
                              style: textTheme.labelMedium?.copyWith(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () => c.respondToInvitation(
                              eventId: event['id'] is int
                                  ? event['id']
                                  : int.tryParse(event['id'].toString()) ?? 0,
                              accept: false,
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0x29111827),
                              foregroundColor: Colors.black,
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              minimumSize: const Size.fromHeight(40),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                            ),
                            child: Text(
                              "Reject",
                              style: textTheme.labelMedium?.copyWith(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 30),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _label(String text) => Text(
    text,
    style: AppTheme.textTheme.labelLarge?.copyWith(color: Colors.black),
  );

  Widget _infoBox(String label, String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: const BoxDecoration(
        color: Color(0xFFFFEFEF),
        border: Border(bottom: BorderSide(color: Colors.black12, width: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _label(label),
          const SizedBox(height: 8),
          Text(
            text,
            style: AppTheme.textTheme.bodySmall?.copyWith(color: Colors.black54),
          ),
        ],
      ),
    );
  }
}

class _InviteChip extends StatelessWidget {
  final String name;
  final String imageUrl;
  const _InviteChip({required this.name, required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    final ImageProvider img =
    imageUrl.isNotEmpty ? NetworkImage(imageUrl) : const AssetImage('assets/dp1.png');
    return Chip(
      label: Text(
        name,
        style: AppTheme.textTheme.bodySmall?.copyWith(fontSize: 12),
      ),
      avatar: CircleAvatar(radius: 10, backgroundImage: img),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: Colors.black26),
      ),
      backgroundColor: const Color(0xFFFFEFEF),
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }
}
