import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:dating_app/themesfolder/theme.dart';
import '../dashboard/Dashboard.dart';
import 'chatcontroller.dart';
import 'chatthread/chatthread.dart';

const _unselected = Color(0xFF111827);

/// ✅ Cleans display names by removing any numeric/ID suffixes like `#42`, `· #77`, `(ID: 5)` etc.
String _displayName(String raw) {
  if (raw.trim().isEmpty) return 'User';
  var s = raw.trim();

  // Remove " · #123", " - #123", " | #123"
  s = s.replaceAll(RegExp(r'\s*[·\-\|]\s*#?\d+\s*$'), '');

  // Remove "(ID: 123)" or "(ID 123)" at the end
  s = s.replaceAll(RegExp(r'\s*\(\s*ID[: ]?\s*[\w\-]+\s*\)\s*$', caseSensitive: false), '');

  // Remove "[ID: 123]" or "[ID 123]" at the end
  s = s.replaceAll(RegExp(r'\s*\[\s*ID[: ]?\s*[\w\-]+\s*\]\s*$', caseSensitive: false), '');

  // Remove simple trailing "#123"
  s = s.replaceAll(RegExp(r'\s*#\d+\s*$'), '');

  // Remove trailing lone digits like "John 87"
  s = s.replaceAll(RegExp(r'\s+\d+\s*$'), '');

  // Trim any remaining separators
  s = s.replaceAll(RegExp(r'[·\-\|]+$'), '').trim();

  return s.isEmpty ? 'User' : s;
}

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> with TickerProviderStateMixin {
  late TabController _mainTabs; // Dating / Social Circle
  final ChatController c = Get.isRegistered<ChatController>()
      ? Get.find<ChatController>()
      : Get.put(ChatController(), permanent: true);

  @override
  void initState() {
    super.initState();
    _mainTabs = TabController(length: 2, vsync: this);

    _mainTabs.addListener(() {
      if (_mainTabs.index == 0) {
        c.fetchDating();
      } else {
        c.fetchSocial();
        c.fetchSubscription();
      }
      setState(() {});
    });

    ever<ChatUser?>(c.matchedUser, (user) {
      if (user == null) return;
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        await _showMatchedDialog(user);
        if (c.matchedUser.value == user) {
          c.matchedUser.value = null;
        }
      });
    });
  }

  @override
  void dispose() {
    _mainTabs.dispose();
    super.dispose();
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
        toolbarHeight: 64,
        title: SizedBox(
          height: 70,
          child: Image.asset(
            'assets/the_pairup_logo_black.png',
            fit: BoxFit.contain,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(49),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TabBar(
                controller: _mainTabs,
                labelColor: Colors.black,
                unselectedLabelColor: _unselected,
                labelStyle: AppTheme.textTheme.titleLarge,
                unselectedLabelStyle:
                AppTheme.textTheme.titleLarge?.copyWith(color: _unselected),
                indicator: const UnderlineTabIndicator(
                  borderSide: BorderSide(color: Colors.black, width: 3),
                  insets: EdgeInsets.zero,
                ),
                indicatorSize: TabBarIndicatorSize.label,
                tabs: const [
                  Tab(text: 'Dating'),
                  Tab(text: 'Social Circle'),
                ],
              ),
              const Divider(height: 1, color: Colors.black12),
            ],
          ),
        ),
      ),
      body: TabBarView(
        controller: _mainTabs,
        children: const [
          _DatingPane(),
          _SocialPane(),
        ],
      ),
    );
  }

  Future<void> _showMatchedDialog(ChatUser user) {
    final displayName = _displayName(user.name);

    Future.delayed(const Duration(seconds: 5), () {
      if (Get.isDialogOpen == true) Get.back();
    });

    return showGeneralDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.45),
      barrierLabel: 'match',
      barrierDismissible: true,
      transitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (_, __, ___) {
        return Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18.0),
            child: _MatchCardMinimal(
              user: user,
              title: 'You matched with $displayName',
            ),
          ),
        );
      },
      transitionBuilder: (_, anim, __, child) {
        final curved = CurvedAnimation(parent: anim, curve: Curves.easeOutCubic);
        return FadeTransition(
          opacity: curved,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.98, end: 1.0).animate(curved),
            child: child,
          ),
        );
      },
    );
  }
}

// ------------------ DATING ------------------
class _DatingPane extends StatefulWidget {
  const _DatingPane();

  @override
  State<_DatingPane> createState() => _DatingPaneState();
}

class _DatingPaneState extends State<_DatingPane> with TickerProviderStateMixin {
  late TabController _inner;

  @override
  void initState() {
    super.initState();
    _inner = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _inner.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = Get.find<ChatController>();
    return Column(
      children: [
        Obx(() {
          return _PillTabBar(
            controller: _inner,
            tabs: [
              _TabWithBadge(
                label: 'Matches',
                showDot: c.datingHasUnread && c.matches.any((u) => u.hasUnread),
              ),
              _TabWithBadge(
                label: 'Likes You',
                count: c.likesBadge,
              ),
            ],
            onTap: (_) => c.fetchDating(),
          );
        }),
        Expanded(
          child: TabBarView(
            controller: _inner,
            children: [
              // Matches
              Obx(() {
                if (c.isLoadingDating.value) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (c.matches.isEmpty) {
                  return RefreshIndicator(
                    onRefresh: () => c.fetchDating(),
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.only(top: 80),
                      children: const [_EmptyState('No matches yet')],
                    ),
                  );
                }
                return RefreshIndicator(
                  onRefresh: () => c.fetchDating(),
                  child: ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                    itemCount: c.matches.length,
                    itemBuilder: (_, i) => UserCard.datingMatch(
                      user: c.matches[i],
                      showUnreadBadge: c.matches[i].hasUnread,
                      unreadCount: c.matches[i].unreadCount,
                      onTap: () => Get.to(
                            () => ChatThreadScreen(
                          user: c.matches[i],
                          category: ThreadCategory.dating,
                        ),
                        id: chatNavId,
                      ),
                    ),
                  ),
                );
              }),
              // Likes You
              Obx(() {
                if (c.isLoadingDating.value) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (c.likesYou.isEmpty) {
                  return RefreshIndicator(
                    onRefresh: () => c.fetchDating(),
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.only(top: 80),
                      children: const [_EmptyState('No one liked you yet')],
                    ),
                  );
                }
                return RefreshIndicator(
                  onRefresh: () => c.fetchDating(),
                  child: ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                    itemCount: c.likesYou.length,
                    itemBuilder: (_, i) => UserCard.likesYou(
                      user: c.likesYou[i],
                      onLikeBack: () => c.likeBack(c.likesYou[i]),
                      onIgnore: () => c.ignore(c.likesYou[i]),
                      onTap: () => Get.to(
                            () => ChatThreadScreen(
                          user: c.likesYou[i],
                          category: ThreadCategory.dating,
                        ),
                        id: chatNavId,
                      ),
                    ),
                  ),
                );
              }),
            ],
          ),
        ),
      ],
    );
  }
}

// ------------------ SOCIAL CIRCLE ------------------

class _SocialPane extends StatefulWidget {
  const _SocialPane();

  @override
  State<_SocialPane> createState() => _SocialPaneState();
}

class _SocialPaneState extends State<_SocialPane> with TickerProviderStateMixin {
  late TabController _inner;

  @override
  void initState() {
    super.initState();
    _inner = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _inner.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = Get.find<ChatController>();
    return Column(
      children: [
        Obx(() {
          final isPremium = c.isPremiumUser.value;
          final hasUnreadFriends = c.friends.any((u) => u.hasUnread);
          return _PillTabBar(
            controller: _inner,
            tabs: [
              _TabWithBadge(
                label: 'Friends',
                showDot: hasUnreadFriends,
              ),
              _TabWithBadge(
                label: 'Requests',
                count: c.requestsBadge,
              ),
            ],
            onTap: (_) {
              c.fetchSocial();
              c.fetchSubscription();
            },
          );
        }),
        Expanded(
          child: Obx(() {
            final isPremium = c.isPremiumUser.value;
            final blurInfo = !isPremium; // blur + disable when not premium

            return TabBarView(
              controller: _inner,
              children: [
                // Friends
                Obx(() {
                  if (c.isLoadingSocial.value) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (c.friends.isEmpty) {
                    return RefreshIndicator(
                      onRefresh: () async {
                        await c.fetchSubscription();
                        await c.fetchSocial();
                      },
                      child: ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.only(top: 80),
                        children: const [_EmptyState('No friends yet')],
                      ),
                    );
                  }
                  return RefreshIndicator(
                    onRefresh: () async {
                      await c.fetchSubscription();
                      await c.fetchSocial();
                    },
                    child: ListView.builder(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                      itemCount: c.friends.length,
                      itemBuilder: (_, i) => UserCard.socialFriend(
                        user: c.friends[i],
                        blurInfo: blurInfo,
                        showUnreadBadge: c.friends[i].hasUnread,
                        unreadCount: c.friends[i].unreadCount,
                        onTap: blurInfo
                            ? null
                            : () => Get.to(
                              () => ChatThreadScreen(
                            user: c.friends[i],
                            category: ThreadCategory.social,
                          ),
                          id: chatNavId,
                        ),
                      ),
                    ),
                  );
                }),
                // Requests
                Obx(() {
                  if (c.isLoadingSocial.value) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (c.requests.isEmpty) {
                    return RefreshIndicator(
                      onRefresh: () async {
                        await c.fetchSubscription();
                        await c.fetchSocial();
                      },
                      child: ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.only(top: 80),
                        children: const [_EmptyState('No requests')],
                      ),
                    );
                  }
                  return RefreshIndicator(
                    onRefresh: () async {
                      await c.fetchSubscription();
                      await c.fetchSocial();
                    },
                    child: ListView.builder(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                      itemCount: c.requests.length,
                      itemBuilder: (_, i) => UserCard.socialRequest(
                        user: c.requests[i],
                        onAccept: () => c.acceptRequest(c.requests[i]),
                        onDeny: () => c.denyRequest(c.requests[i]),
                        onTap: null, // request card doesn't open chat
                        blurInfo: !c.isPremiumUser.value,
                      ),
                    ),
                  );
                }),
              ],
            );
          }),
        ),
      ],
    );
  }
}

// ------------------ REUSABLE: TAB WITH BADGE ------------------

class _TabWithBadge extends StatelessWidget {
  final String label;
  final int? count; // if provided and > 0, show numeric badge
  final bool showDot; // show small red dot

  const _TabWithBadge({
    required this.label,
    this.count,
    this.showDot = false,
  });

  @override
  Widget build(BuildContext context) {
    final showCount = (count ?? 0) > 0;
    final show = showCount || showDot;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6.0),
          child: Tab(text: label),
        ),
        if (show)
          Positioned(
            right: -4,
            top: -2,
            child: _Badge(
              count: showCount ? count!.clamp(0, 999) : null,
            ),
          ),
      ],
    );
  }
}

class _Badge extends StatelessWidget {
  final int? count;
  const _Badge({this.count});

  @override
  Widget build(BuildContext context) {
    final hasNumber = count != null && count! > 0;
    final text = hasNumber ? (count! > 99 ? '99+' : '$count') : '';
    final diameter = hasNumber ? 18.0 : 10.0;

    return Container(
      height: diameter,
      constraints: BoxConstraints(minWidth: diameter),
      padding: EdgeInsets.symmetric(horizontal: hasNumber ? 5 : 0),
      decoration: BoxDecoration(
        color: Colors.red,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white, width: 1.5),
      ),
      alignment: Alignment.center,
      child: hasNumber
          ? Text(
        text,
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      )
          : const SizedBox.shrink(),
    );
  }
}

// ------------------ REUSABLE CARD & TAB DECOR ------------------

class UserCard extends StatelessWidget {
  final ChatUser user;
  final List<Widget> trailingButtons;
  final VoidCallback? onTap;
  final bool blurInfo; // blur all info (except avatar) and disable interactions

  // 🔴 per-card notification badge (for unread chat)
  final bool showUnreadBadge;
  final int unreadCount;

  const UserCard._({
    required this.user,
    required this.trailingButtons,
    this.onTap,
    this.blurInfo = false,
    this.showUnreadBadge = false,
    this.unreadCount = 0,
    Key? key,
  }) : super(key: key);

  factory UserCard.datingMatch({
    required ChatUser user,
    VoidCallback? onTap,
    bool showUnreadBadge = false,
    int unreadCount = 0,
  }) =>
      UserCard._(
        user: user,
        trailingButtons: const [],
        onTap: onTap,
        showUnreadBadge: showUnreadBadge,
        unreadCount: unreadCount,
      );

  factory UserCard.likesYou({
    required ChatUser user,
    required VoidCallback onLikeBack,
    required VoidCallback onIgnore,
    VoidCallback? onTap,
  }) =>
      UserCard._(
        user: user,
        trailingButtons: [
          _pillButton("Like Back", onLikeBack, primary: true),
          const SizedBox(width: 8),
          _pillButton("Ignore", onIgnore),
        ],
        onTap: onTap,
        showUnreadBadge: false,
        unreadCount: 0,
      );

  factory UserCard.socialFriend({
    required ChatUser user,
    VoidCallback? onTap,
    bool blurInfo = false,
    bool showUnreadBadge = false,
    int unreadCount = 0,
  }) =>
      UserCard._(
        user: user,
        trailingButtons: const [],
        onTap: onTap,
        blurInfo: blurInfo,
        showUnreadBadge: showUnreadBadge,
        unreadCount: unreadCount,
      );

  factory UserCard.socialRequest({
    required ChatUser user,
    required VoidCallback onAccept,
    required VoidCallback onDeny,
    VoidCallback? onTap,
    bool blurInfo = false,
  }) =>
      UserCard._(
        user: user,
        trailingButtons: [
          _pillButton("Accept", onAccept, primary: true, enabled: !blurInfo),
          const SizedBox(width: 8),
          _pillButton("Deny", onDeny, enabled: !blurInfo),
        ],
        onTap: onTap,
        blurInfo: blurInfo,
        showUnreadBadge: false,
        unreadCount: 0,
      );

  static Widget _pillButton(
      String label,
      VoidCallback onTap, {
        bool primary = false,
        bool enabled = true,
      }) {
    return ElevatedButton(
      onPressed: enabled ? onTap : null,
      style: ElevatedButton.styleFrom(
        backgroundColor: primary ? Colors.black : const Color(0x29111827),
        foregroundColor: primary ? Colors.white : Colors.black,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        minimumSize: const Size(70, 30),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      child: Text(
        label,
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ageHeight = [
      if (user.age > 0) '${user.age} yrs',
      if (user.height.isNotEmpty) user.height,
    ].join(', ');

    final safeName = _displayName(user.name);

    final infoContent = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(safeName, style: AppTheme.textTheme.titleLarge),
        const SizedBox(height: 2),
        if (ageHeight.isNotEmpty)
          Text(ageHeight, style: AppTheme.textTheme.titleSmall),
        if (user.location.isNotEmpty)
          Text(user.location, style: AppTheme.textTheme.titleMedium),
        if (user.bio.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              user.bio,
              style: AppTheme.textTheme.bodySmall,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
      ],
    );

    // Build blurred info area (overlay uses AppTheme.backgroundColor)
    Widget infoArea;
    if (blurInfo) {
      infoArea = Stack(
        children: [
          Opacity(
            opacity: 0.9,
            child: ImageFiltered(
              imageFilter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
              child: infoContent,
            ),
          ),
          Positioned.fill(
            child: Container(
              color: AppTheme.backgroundColor.withOpacity(0.35),
            ),
          ),
        ],
      );
    } else {
      infoArea = infoContent;
    }

    // Buttons (dim + disabled when blurred handled in factory)
    Widget trailing = Row(children: trailingButtons);
    if (blurInfo && trailingButtons.isNotEmpty) {
      trailing = Opacity(opacity: 0.55, child: trailing);
    }

    final effectiveOnTap = blurInfo ? null : onTap;

    // Badge for unread chats on the card
    final hasNumber = unreadCount > 0;
    final showBadge = showUnreadBadge;

    return AbsorbPointer(
      absorbing: blurInfo,
      child: InkWell(
        onTap: effectiveOnTap,
        borderRadius: BorderRadius.circular(12),
        child: Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 0,
          margin: const EdgeInsets.only(bottom: 12),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  decoration: const BoxDecoration(
                    border: Border(
                      top: BorderSide(color: Colors.black12, width: 0.5),
                      bottom: BorderSide(color: Colors.black12, width: 0.5),
                    ),
                    color: Color(0xFFFFEFEF),
                  ),
                  padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Avatar stays CLEAR even when gated
                      ClipRRect(
                        borderRadius: BorderRadius.circular(30),
                        child: (user.avatarUrl.isNotEmpty)
                            ? Image.network(
                          user.avatarUrl,
                          height: 60,
                          width: 60,
                          fit: BoxFit.cover,
                        )
                            : Container(
                          height: 60,
                          width: 60,
                          color: Colors.black12,
                          child: const Icon(Icons.person, size: 30),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Container(height: 60, width: 1, color: Colors.black12),
                      const SizedBox(width: 16),
                      Expanded(child: infoArea),
                      if (trailingButtons.isNotEmpty) trailing,
                    ],
                  ),
                ),

                if (showBadge)
                  Positioned(
                    right: 8,
                    top: 8,
                    child: _Badge(count: hasNumber ? unreadCount : null),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String msg;
  const _EmptyState(this.msg);

  @override
  Widget build(BuildContext context) =>
      Center(child: Text(msg, style: AppTheme.textTheme.bodyLarge));
}

class _PillTabBar extends StatelessWidget {
  final TabController controller;
  final List<Widget> tabs;
  final ValueChanged<int>? onTap;

  const _PillTabBar({
    required this.controller,
    required this.tabs,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      child: TabBar(
        controller: controller,
        labelColor: Colors.black,
        unselectedLabelColor: _unselected,
        labelStyle:
        AppTheme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
        unselectedLabelStyle:
        AppTheme.textTheme.bodySmall?.copyWith(color: _unselected),
        indicator: _PillIndicator(
          height: 30,
          radius: 999,
          color: AppTheme.backgroundColor,
          horizontalPadding: 14,
          verticalOffset: 0,
          borderColor: Colors.black,
          borderWidth: 1,
        ),
        indicatorSize: TabBarIndicatorSize.label,
        labelPadding: const EdgeInsets.symmetric(horizontal: 26, vertical: 8),
        overlayColor: WidgetStateProperty.all(Colors.transparent),
        tabs: tabs,
        onTap: onTap,
      ),
    );
  }
}

class _PillIndicator extends Decoration {
  final double height;
  final double radius;
  final Color color;
  final double horizontalPadding;
  final double verticalOffset;
  final Color? borderColor;
  final double borderWidth;

  const _PillIndicator({
    required this.height,
    required this.radius,
    required this.color,
    this.horizontalPadding = 0,
    this.verticalOffset = 0,
    this.borderColor,
    this.borderWidth = 0,
  });

  @override
  BoxPainter createBoxPainter([VoidCallback? onChanged]) => _PillPainter(
    height,
    radius,
    color,
    horizontalPadding,
    verticalOffset,
    borderColor,
    borderWidth,
  );
}

class _PillPainter extends BoxPainter {
  final double height;
  final double radius;
  final Color color;
  final double horizontalPadding;
  final double verticalOffset;
  final Color? borderColor;
  final double borderWidth;

  _PillPainter(
      this.height,
      this.radius,
      this.color,
      this.horizontalPadding,
      this.verticalOffset,
      this.borderColor,
      this.borderWidth,
      );

  @override
  void paint(Canvas canvas, Offset offset, ImageConfiguration cfg) {
    if (cfg.size == null) return;
    final size = cfg.size!;
    final width = size.width + (horizontalPadding * 2);
    final centerX = offset.dx + size.width / 2;
    final centerY = offset.dy + size.height / 2 + verticalOffset;

    final rect = Rect.fromCenter(
      center: Offset(centerX, centerY),
      width: width,
      height: height,
    );
    final rrect = RRect.fromRectAndRadius(rect, Radius.circular(radius));

    final fill = Paint()
      ..style = PaintingStyle.fill
      ..color = color
      ..isAntiAlias = true;
    canvas.drawRRect(rrect, fill);

    if (borderColor != null && borderWidth > 0) {
      final stroke = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = borderWidth
        ..color = borderColor!
        ..isAntiAlias = true;
      canvas.drawRRect(rrect, stroke);
    }
  }
}

class _MatchCardMinimal extends StatelessWidget {
  final ChatUser user;
  final String title;

  const _MatchCardMinimal({
    required this.user,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: user.avatarUrl.isNotEmpty
                ? Image.network(
              user.avatarUrl,
              width: double.infinity,
              height: 360,
              fit: BoxFit.cover,
            )
                : Container(
              width: double.infinity,
              height: 360,
              color: Colors.black12,
              alignment: Alignment.center,
              child: const Icon(Icons.person, size: 72, color: Colors.black45),
            ),
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: -12,
            child: Container(
              decoration: BoxDecoration(
                color: AppTheme.backgroundColor,
                borderRadius: BorderRadius.circular(18),
                boxShadow: const [
                  BoxShadow(
                    blurRadius: 18,
                    spreadRadius: 2,
                    offset: Offset(0, 12),
                    color: Color(0x22000000),
                  )
                ],
                border: Border.all(color: Colors.black12),
              ),
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
              child: Text(
                title,
                textAlign: TextAlign.center,
                style: AppTheme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: Colors.black,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
