import 'package:add_2_calendar/add_2_calendar.dart';
import 'package:dating_app/Dashbaord/pairupscreens/addevent/addevent.dart';
import 'package:dating_app/Dashbaord/pairupscreens/pairup/invitation.dart' show InvitationDetailsScreen;
import 'package:dating_app/Dashbaord/pairupscreens/pairup/pairupdetailscreen/pairupdetailscreen.dart';
import 'package:dating_app/Dashbaord/pairupscreens/pairup/pairup_controller.dart';
import 'package:dating_app/themesfolder/theme.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import '../../dashboard/Dashboard.dart';

class PairUp extends StatefulWidget {
  const PairUp({super.key});

  @override
  State<PairUp> createState() => _PairUpState();
}

class _PairUpState extends State<PairUp> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final PairUpController c = Get.put(PairUpController());

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  // Normalize image url coming from API
  String _fullUrl(String? path) {
    if (path == null || path.isEmpty) return '';
    if (path.startsWith('http')) return path.replaceAll('\\', '');
    return 'https://pairup.binarygenes.pk/${path.replaceAll('\\', '')}';
  }

  // Format time
  String _fmtUs(dynamic raw) {
    if (raw == null) return '';
    final s = raw.toString().trim();
    if (s.isEmpty) return '';
    final dt = DateTime.tryParse(s);
    if (dt == null) return s;
    return DateFormat('MMM d, yyyy • h:mm a').format(dt.toLocal());
  }
  // Parse date safely (expects ISO string from API like "2025-10-20T14:00:00Z" or local)
  DateTime? _parseDate(dynamic raw) {
    if (raw == null) return null;
    final s = raw.toString().trim();
    if (s.isEmpty) return null;
    final dt = DateTime.tryParse(s);
    return dt?.toLocal();
  }

  Future<void> _addEventToCalendar(Map<String, dynamic> e) async {
    final start = _parseDate(e['time_and_date']);
    if (start == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not parse event date/time.')),
      );
      return;
    }

    // You can change duration as needed
    final end = start.add(const Duration(hours: 2));

    final title = (e['name'] ?? '').toString().trim().isEmpty
        ? 'PairUp Event'
        : (e['name'] ?? '').toString();

    final description = (e['description'] ?? '').toString();
    final location = (e['location'] ?? '').toString();

    final event = Event(
      title: title,
      description: description.isEmpty ? null : description,
      location: location.isEmpty ? null : location,
      startDate: start,
      endDate: end,
      allDay: false,
      iosParams: const IOSParams(
        reminder: Duration(minutes: 30), // optional reminder on iOS
      ),
      androidParams: const AndroidParams(
        emailInvites: [], // optional attendees (email) for Android
      ),
    );

    try {
      final added = await Add2Calendar.addEvent2Cal(event);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(added ? 'Event opened in your calendar.' : 'Could not add the event.'),
        ),
      );
    } catch (err) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Calendar error: $err')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        elevation: 0,
        automaticallyImplyLeading: false,
        centerTitle: false,
        titleSpacing: 16,
        title: Image.asset('assets/the_pairup_logo_black.png', height: 70),
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.black,
          unselectedLabelColor: Colors.black45,
          indicatorColor: Colors.black,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold),
          tabs: const [
            Tab(text: 'My Events'),
            Tab(text: 'Invitations'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // ───────── My Events
          Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: _buildEventsList(),
          ),

          // ───────── Invitations
          Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: _buildInvitationsList(),
          ),
        ],
      ),
    );
  }

  // ===================== MY EVENTS =====================
  Widget _buildEventsList() {
    return Stack(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0),
          child: Obx(() {
            if (c.isLoading.value && c.events.isEmpty) {
              return const Center(child: CircularProgressIndicator());
            }
            if (c.events.isEmpty) {
              return const Center(child: Text("No events created yet."));
            }

            return NotificationListener<ScrollNotification>(
              onNotification: (sn) {
                if (sn.metrics.pixels >= sn.metrics.maxScrollExtent - 120 &&
                    !c.isFetchingMore &&
                    c.hasMore) {
                  c.fetchEvents(loadMore: true);
                }
                return false;
              },
              child: RefreshIndicator(
                onRefresh: () async => c.fetchEvents(),
                child: ListView.builder(
                  padding: const EdgeInsets.only(bottom: 100),
                  itemCount: c.events.length + (c.isFetchingMore ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (index >= c.events.length) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: Center(child: CircularProgressIndicator()),
                      );
                    }
                    final event = c.events[index];
                    return GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => EventDetailsScreen(event: event),
                          ),
                        );
                      },
                      child: _eventCard(event),
                    );
                  },
                ),
              ),
            );
          }),
        ),
        _createEventBar(),
      ],
    );
  }

  Widget _eventCard(Map<String, dynamic> e) {
    final imageUrl = _fullUrl(e['photo_url'] ?? e['photo_path']);

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          children: [
            Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                border: Border(
                  top: BorderSide(color: Colors.black12, width: 0.5),
                  bottom: BorderSide(color: Colors.black12, width: 0.5),
                ),
                color: Color(0xFFFFEFEF),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(40),
                    child: imageUrl.isNotEmpty
                        ? Image.network(imageUrl, height: 70, width: 70, fit: BoxFit.cover)
                        : Container(
                      height: 70,
                      width: 70,
                      color: Colors.black12,
                      child: const Icon(Icons.event, size: 30),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(height: 70, width: 1, color: Colors.black12),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          (e['name'] ?? '').toString(),
                          style: AppTheme.textTheme.titleLarge,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(_fmtUs(e['time_and_date']), style: AppTheme.textTheme.titleSmall),
                        Text((e['location'] ?? '').toString(),
                            style: AppTheme.textTheme.titleMedium),
                        Text((e['description'] ?? '').toString(),
                            style: AppTheme.textTheme.titleMedium),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              top: 6,
              right: 6,
              child: IconButton(
                icon: const Icon(Icons.more_vert, size: 20),
                onPressed: () => c.onEventOptionsTap(e),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ),
            IconButton(
              tooltip: 'Add to Calendar',
              icon: const Icon(Icons.calendar_month, size: 20),
              onPressed: () => _addEventToCalendar(e),
              splashRadius: 18,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ],
        ),
      ),
    );
  }

  // ===================== INVITATIONS =====================
  Widget _buildInvitationsList() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0),
      child: Obx(() {
        if (c.isLoadingInvites.value && c.invitations.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }
        if (c.invitations.isEmpty) {
          return const Center(child: Text("No invitations yet."));
        }

        return NotificationListener<ScrollNotification>(
          onNotification: (sn) {
            if (sn.metrics.pixels >= sn.metrics.maxScrollExtent - 120 &&
                !c.invitesFetchingMore &&
                c.invitesHasMore) {
              c.fetchInvitations(loadMore: true);
            }
            return false;
          },
          child: RefreshIndicator(
            onRefresh: () async => c.fetchInvitations(),
            child: ListView.builder(
              padding: const EdgeInsets.only(bottom: 30),
              itemCount: c.invitations.length + (c.invitesFetchingMore ? 1 : 0),
              itemBuilder: (context, index) {
                if (index >= c.invitations.length) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                final inv = c.invitations[index];
                return _invitationCard(inv);
              },
            ),
          ),
        );
      }),
    );
  }

  Widget _invitationCard(Map<String, dynamic> e) {
    final textTheme = Theme.of(context).textTheme;
    final photoUrl = _fullUrl(e['photo_url'] ?? e['photo_path']);
    final ImageProvider thumb =
    photoUrl.isNotEmpty ? NetworkImage(photoUrl) : const AssetImage('assets/event1.png');

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => DashboardScreen(
            selectedIndex: 2,
            detailScreen: InvitationDetailsScreen(event: e),
          ),
        ),
      ),
      child: Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 0,
        margin: const EdgeInsets.only(bottom: 16),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Container(
            decoration: const BoxDecoration(
              border: Border(
                top: BorderSide(color: Colors.black12, width: 0.5),
                bottom: BorderSide(color: Colors.black12, width: 0.5),
              ),
              color: Color(0xFFFFEFEF),
            ),
            padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 12.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(30),
                  child: Image(image: thumb, height: 60, width: 60, fit: BoxFit.cover),
                ),
                const SizedBox(width: 12),
                Container(height: 95, width: 1, color: Colors.black12),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text((e['name'] ?? '').toString(), style: AppTheme.textTheme.titleLarge),
                      const SizedBox(height: 2),
                      Text(_fmtUs(e['time_and_date']), style: AppTheme.textTheme.titleSmall),
                      Text((e['location'] ?? '').toString(),
                          style: AppTheme.textTheme.titleMedium),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          ElevatedButton(
                            onPressed: () async {
                              await c.respondToInvitation(eventId: e['id'] as int, accept: true);
                              await c.fetchEvents(); // ✅ Refresh “My Events”
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.black,
                              padding:
                              const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              minimumSize: const Size(70, 30),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20)),
                            ),
                            child: Text(
                              "Accept",
                              style: textTheme.labelSmall?.copyWith(
                                color: AppTheme.backgroundColor,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            onPressed: () => c.respondToInvitation(
                              eventId: e['id'] as int,
                              accept: false,
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0x29111827),
                              foregroundColor: Colors.black,
                              padding:
                              const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              minimumSize: const Size(70, 30),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20)),
                            ),
                            child: Text(
                              "Reject",
                              style: textTheme.labelSmall?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: Colors.black,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ===================== CREATE BAR =====================
  Widget _createEventBar() {
    final textTheme = Theme.of(context).textTheme;
    return Positioned(
      bottom: 20,
      left: 20,
      right: 20,
      child: Container(
        height: 47.5,
        padding: const EdgeInsets.symmetric(horizontal: 11),
        decoration: BoxDecoration(
          color: const Color(0xFFFFEFEF),
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: Colors.black26),
        ),
        child: Row(
          children: [
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                style: textTheme.bodyMedium?.copyWith(fontSize: 14),
                decoration: InputDecoration(
                  hintText: "Create Your Own PairUp Event",
                  hintStyle: textTheme.bodySmall
                      ?.copyWith(color: Colors.black, fontSize: 12),
                  border: InputBorder.none,
                  filled: true,
                  fillColor: const Color(0xFFFFEFEF),
                  contentPadding: const EdgeInsets.symmetric(vertical: 8),
                ),
                readOnly: true,
                onTap: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const DashboardScreen(
                        selectedIndex: 2,
                        detailScreen: AddEventScreen(),
                      ),
                    ),
                  );
                  c.fetchEvents();
                },
              ),
            ),
            IconButton(
              icon: const Icon(Icons.add_circle, color: Colors.black),
              onPressed: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const DashboardScreen(
                      selectedIndex: 2,
                      detailScreen: AddEventScreen(),
                    ),
                  ),
                );
                c.fetchEvents();
              },
            ),
          ],
        ),
      ),
    );
  }
}
