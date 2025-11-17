// lib/main.dart
import 'package:flutter/material.dart';

void main() => runApp(FlutterChatApp());

class FlutterChatApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Chat Dashboard',
      theme: ThemeData(
        brightness: Brightness.light,
        primaryColor: AppColors.primary,
        colorScheme:
        ColorScheme.fromSwatch().copyWith(secondary: AppColors.accent),
        scaffoldBackgroundColor: AppColors.bg,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: ChatDashboard(),
      debugShowCheckedModeBanner: false,
    );
  }
}

// ----- Color palette (easy to change) -----
class AppColors {
  static const Color primary = Color(0xFF4F46E5); // indigo-600
  static const Color primaryLight = Color(0xFF6366F1); // indigo-500
  static const Color accent = Color(0xFF06B6D4); // cyan-500
  static const Color success = Color(0xFF16A34A); // green-600
  static const Color bg = Color(0xFFF6F7FB); // light background
  static const Color card = Colors.white;
  static const Color muted = Color(0xFF6B7280);
}

// ---------- Models ----------
class Friend {
  final int id;
  final String name;
  final String lastMessage;
  final int unread;
  Friend(
      {required this.id,
        required this.name,
        this.lastMessage = '',
        this.unread = 0});
}

class Message {
  final String id;
  final String from;
  final String text;
  final DateTime time;
  final Map<String, int> reactions = {};
  final Set<String> reactedByMe = {};
  String? repliedToId; // id of message being replied to
  String? repliedToText; // text snapshot of replied message
  String? repliedToFrom; // sender of replied message

  Message({
    required this.id,
    required this.from,
    required this.text,
    DateTime? time,
    this.repliedToId,
    this.repliedToText,
    this.repliedToFrom,
  }) : time = time ?? DateTime.now();

  void toggleReaction(String emoji) {
    if (reactedByMe.contains(emoji)) {
      reactedByMe.remove(emoji);
      reactions[emoji] = (reactions[emoji] ?? 1) - 1;
      if (reactions[emoji]! <= 0) reactions.remove(emoji);
    } else {
      reactedByMe.add(emoji);
      reactions[emoji] = (reactions[emoji] ?? 0) + 1;
    }
  }
}

class GroupChat {
  final String id;
  final String name;
  final List<String> members;
  final List<Message> messages;
  GroupChat(
      {required this.id,
        required this.name,
        required this.members,
        List<Message>? messages})
      : messages = messages ?? [];
}

// Quick reactions and emoji set
const List<String> commonReactions = ['👍', '❤️', '😂', '😮', '😢'];
const List<String> fullEmojiSet = [
  '😀',
  '😁',
  '😂',
  '🤣',
  '😊',
  '😍',
  '😘',
  '😜',
  '🤩',
  '🤔',
  '🤷',
  '🙌',
  '🙏',
  '👍',
  '👎',
  '👏',
  '🔥',
  '🎉',
  '❤️',
  '😢',
  '😮',
  '😴'
];

// --- Dashboard
class ChatDashboard extends StatefulWidget {
  @override
  _ChatDashboardState createState() => _ChatDashboardState();
}

class _ChatDashboardState extends State<ChatDashboard> {
  int _selectedIndex = 0; // 0: Friends, 1: Groups

  final List<Friend> _friends = [
    Friend(id: 1, name: 'Sara Khan', lastMessage: 'See you at 6!', unread: 2),
    Friend(id: 2, name: 'Bilal Ahmed', lastMessage: 'Sent the files.', unread: 0),
    Friend(id: 3, name: 'Maya Rizvi', lastMessage: 'Nice photo!', unread: 5),
    Friend(id: 4, name: 'Omar Ali', lastMessage: 'On my way.', unread: 0),
  ];

  late List<Message> _threadMessages;
  late List<GroupChat> _groups;

  @override
  void initState() {
    super.initState();
    _threadMessages = [
      Message(
        id: 'm1',
        from: 'Sara',
        text: 'Hey! Are you free today?',
        time: DateTime.now().subtract(Duration(hours: 3)),
      ),
      Message(
        id: 'm2',
        from: 'You',
        text: 'Yes — free after 4pm.',
        time: DateTime.now().subtract(Duration(hours: 2, minutes: 50)),
      ),
      Message(
        id: 'm3',
        from: 'Sara',
        text: 'Great — coffee?',
        time: DateTime.now().subtract(Duration(hours: 2, minutes: 48)),
      ),
    ];

    _groups = [
      GroupChat(
        id: 'g1',
        name: 'Project Team',
        members: ['Ali', 'Sara', 'Bilal', 'Maya'],
        messages: [
          Message(
            id: 'gm1',
            from: 'Ali',
            text: 'Draft ready for review.',
            time: DateTime.now().subtract(Duration(days: 1)),
          ),
          Message(
            id: 'gm2',
            from: 'Maya',
            text: 'I left comments.',
            time: DateTime.now().subtract(Duration(days: 1, hours: 2)),
          ),
        ],
      ),
      GroupChat(
        id: 'g2',
        name: 'Weekend Squad',
        members: ['Sara', 'Bilal'],
        messages: [
          Message(
            id: 'gm3',
            from: 'Bilal',
            text: 'Movie at 8?',
            time: DateTime.now().subtract(Duration(hours: 5)),
          ),
        ],
      ),
    ];
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  void _openThread(Friend friend) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChatThreadScreen(
          friend: friend,
          messages: _threadMessages,
          onSend: (Message msg) {
            setState(() {
              _threadMessages.add(msg);
            });
          },
          onUpdateMessage: (String id, Message updated) {
            setState(() {
              final i = _threadMessages.indexWhere((m) => m.id == id);
              if (i >= 0) _threadMessages[i] = updated;
            });
          },
        ),
      ),
    );
  }

  void _openGroup(GroupChat group) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => GroupChatScreen(
          group: group,
          onSend: (Message msg) {
            setState(() {
              group.messages.add(msg);
            });
          },
          onUpdateMessage: (String id, Message updated) {
            setState(() {
              final i = group.messages.indexWhere((m) => m.id == id);
              if (i >= 0) group.messages[i] = updated;
            });
          },
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      padding: EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 8,
              offset: Offset(0, 3))
        ],
      ),
      child: Row(
        children: [
          Icon(Icons.search, color: AppColors.muted),
          SizedBox(width: 10),
          Expanded(
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search friends or groups',
                border: InputBorder.none,
                isDense: true,
              ),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildFriendsScreen() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Text(
            'Friends',
            style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: AppColors.muted),
          ),
        ),
        _buildSearchBar(),
        Expanded(
          child: ListView.separated(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            itemCount: _friends.length,
            separatorBuilder: (_, __) => SizedBox(height: 8),
            itemBuilder: (context, index) {
              final f = _friends[index];
              return Material(
                elevation: 0,
                color: AppColors.card,
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  onTap: () => _openThread(f),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    decoration:
                    BoxDecoration(borderRadius: BorderRadius.circular(12)),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 26,
                          backgroundColor: _avatarColor(f.id),
                          child: Text(
                            f.name
                                .split(' ')
                                .map((p) => p.isNotEmpty ? p[0] : '')
                                .take(2)
                                .join(),
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold),
                          ),
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      f.name,
                                      style: TextStyle(
                                          fontWeight: FontWeight.w600),
                                    ),
                                  ),
                                  if (f.unread > 0)
                                    Container(
                                      padding: EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: Colors.redAccent,
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Text(
                                        '${f.unread}',
                                        style: TextStyle(
                                            color: Colors.white, fontSize: 12),
                                      ),
                                    ),
                                ],
                              ),
                              SizedBox(height: 6),
                              Text(
                                f.lastMessage,
                                style: TextStyle(
                                    color: AppColors.muted, fontSize: 13),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        )
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildGroupsScreen() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Text(
            'Groups',
            style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: AppColors.muted),
          ),
        ),
        _buildSearchBar(),
        Expanded(
          child: ListView.separated(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            itemCount: _groups.length,
            separatorBuilder: (_, __) => SizedBox(height: 8),
            itemBuilder: (context, index) {
              final g = _groups[index];
              final membersSubtitle = g.members.join(', ');
              return Material(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  onTap: () => _openGroup(g),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 26,
                          backgroundColor: _avatarColor(index + 10),
                          child: Text(
                            g.name
                                .split(' ')
                                .map((p) => p.isNotEmpty ? p[0] : '')
                                .take(2)
                                .join(),
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold),
                          ),
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                g.name,
                                style: TextStyle(
                                    fontWeight: FontWeight.w600),
                              ),
                              SizedBox(height: 6),
                              Text(
                                membersSubtitle,
                                style: TextStyle(
                                    color: AppColors.muted, fontSize: 13),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        Icon(Icons.chevron_right, color: AppColors.muted),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Color _avatarColor(int seed) {
    final palette = [
      Color(0xFFEF4444),
      Color(0xFFFB923C),
      Color(0xFFF59E0B),
      Color(0xFF10B981),
      Color(0xFF06B6D4),
      Color(0xFF6366F1)
    ];
    return palette[seed % palette.length];
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> _screens = [
      _buildFriendsScreen(),
      _buildGroupsScreen(),
    ];

    return Scaffold(
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(92),
        child: Container(
          decoration: BoxDecoration(
            gradient:
            LinearGradient(colors: [AppColors.primary, AppColors.primaryLight]),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(0.12),
                  blurRadius: 12,
                  offset: Offset(0, 4))
            ],
          ),
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding:
              const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: Colors.white.withOpacity(0.2),
                    child: Icon(Icons.person, color: Colors.white),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('Welcome back,',
                            style: TextStyle(
                                color: Colors.white70, fontSize: 13)),
                        SizedBox(height: 4),
                        Text('Ali',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () {},
                    icon: Icon(Icons.notifications_none,
                        color: Colors.white.withOpacity(0.9)),
                  )
                ],
              ),
            ),
          ),
        ),
      ),
      body: _screens[_selectedIndex],
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.06), blurRadius: 8)
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: _selectedIndex,
          onTap: _onItemTapped,
          selectedItemColor: AppColors.primary,
          unselectedItemColor: AppColors.muted,
          items: const [
            BottomNavigationBarItem(
                icon: Icon(Icons.people), label: 'Friends'),
            BottomNavigationBarItem(
                icon: Icon(Icons.group), label: 'Groups'),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor:
        _selectedIndex == 0 ? AppColors.primary : AppColors.success,
        onPressed: () {
          if (_selectedIndex == 0) {
            // new friend dialog
            showDialog(
              context: context,
              builder: (context) {
                String name = '';
                return AlertDialog(
                  title: Text('Start new chat'),
                  content: TextField(
                    onChanged: (v) => name = v,
                    decoration: InputDecoration(hintText: 'Friend name'),
                  ),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text('Cancel')),
                    ElevatedButton(
                      onPressed: () {
                        if (name.trim().isEmpty) return;
                        setState(() {
                          _friends.add(Friend(
                              id: _friends.length + 1,
                              name: name.trim(),
                              lastMessage: '',
                              unread: 0));
                        });
                        Navigator.pop(context);
                      },
                      child: Text('Create'),
                    )
                  ],
                );
              },
            );
          } else {
            // new group dialog
            showDialog(
              context: context,
              builder: (context) {
                String name = '';
                String membersText = '';
                return AlertDialog(
                  title: Text('Create new group'),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                          onChanged: (v) => name = v,
                          decoration:
                          InputDecoration(hintText: 'Group name')),
                      SizedBox(height: 8),
                      TextField(
                        onChanged: (v) => membersText = v,
                        decoration: InputDecoration(
                            hintText: 'Members (comma separated)'),
                      ),
                    ],
                  ),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text('Cancel')),
                    ElevatedButton(
                      onPressed: () {
                        if (name.trim().isEmpty) return;
                        final members = membersText
                            .split(',')
                            .map((s) => s.trim())
                            .where((s) => s.isNotEmpty)
                            .toList();
                        setState(() {
                          _groups.add(
                            GroupChat(
                              id: 'g${_groups.length + 1}',
                              name: name.trim(),
                              members: members,
                            ),
                          );
                        });
                        Navigator.pop(context);
                      },
                      child: Text('Create'),
                    )
                  ],
                );
              },
            );
          }
        },
        child: Icon(_selectedIndex == 0 ? Icons.add : Icons.group_add),
      ),
    );
  }
}

// ---------- Chat Thread Screen (1:1) with reply-on-swipe ----------
class ChatThreadScreen extends StatefulWidget {
  final Friend friend;
  final List<Message> messages;
  final void Function(Message) onSend;
  final void Function(String, Message) onUpdateMessage;

  ChatThreadScreen({
    required this.friend,
    required this.messages,
    required this.onSend,
    required this.onUpdateMessage,
  });

  @override
  _ChatThreadScreenState createState() => _ChatThreadScreenState();
}

class _ChatThreadScreenState extends State<ChatThreadScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scroll = ScrollController();
  bool _isComposing = false;
  bool _isRecording = false;

  // reply target
  Message? _replyTarget;

  static const double inputBoxHeight = 56.0;
  static const double bottomExtraSpacing = 12.0;

  @override
  void initState() {
    super.initState();
    _controller.addListener(() {
      setState(() {
        _isComposing = _controller.text.trim().isNotEmpty;
      });
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _scroll.dispose();
    super.dispose();
  }

  // Reaction popup
  Future<void> _showReactionDialog(Message m) async {
    final picked = await showDialog<String>(
      context: context,
      barrierColor: Colors.transparent,
      builder: (ctx) {
        return Center(
          child: Material(
            color: Colors.transparent,
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.85),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: commonReactions
                    .map(
                      (e) => InkWell(
                    onTap: () => Navigator.of(ctx).pop(e),
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8),
                      child: Text(e, style: TextStyle(fontSize: 28)),
                    ),
                  ),
                )
                    .toList(),
              ),
            ),
          ),
        );
      },
    );

    if (picked != null) {
      setState(() {
        m.toggleReaction(picked);
        widget.onUpdateMessage(m.id, m);
      });
    }
  }

  void _showEmojiPicker() {
    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(12))),
      builder: (ctx) {
        return Container(
          padding: EdgeInsets.all(12),
          height: 260,
          child: GridView.builder(
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 8,
              crossAxisSpacing: 6,
              mainAxisSpacing: 6,
            ),
            itemCount: fullEmojiSet.length,
            itemBuilder: (c, i) {
              final e = fullEmojiSet[i];
              return InkWell(
                onTap: () {
                  _controller.text = _controller.text + e;
                  _controller.selection = TextSelection.fromPosition(
                    TextPosition(offset: _controller.text.length),
                  );
                  Navigator.pop(c);
                },
                child: Center(
                  child: Text(e, style: TextStyle(fontSize: 22)),
                ),
              );
            },
          ),
        );
      },
    );
  }

  void _startRecording() {
    setState(() => _isRecording = true);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Recording started (placeholder)'),
        duration: Duration(seconds: 1),
      ),
    );
  }

  void _stopRecording() {
    setState(() => _isRecording = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Recording saved (placeholder)'),
        duration: Duration(seconds: 1),
      ),
    );
  }

  void _sendMessage() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    final id = DateTime.now().millisecondsSinceEpoch.toString();
    final msg = Message(
      id: id,
      from: 'You',
      text: text,
      repliedToId: _replyTarget?.id,
      repliedToText: _replyTarget?.text,
      repliedToFrom: _replyTarget?.from,
    );
    widget.onSend(msg);
    setState(() {
      widget.messages.add(msg);
      _controller.clear();
      _replyTarget = null;
      _isComposing = false;
    });
    Future.delayed(Duration(milliseconds: 120), () {
      if (_scroll.hasClients) {
        _scroll.jumpTo(_scroll.position.maxScrollExtent + 80);
      }
    });
  }

  // when a message is swiped right, set reply target and don't dismiss
  Future<bool> _handleSwipeToReply(String id) async {
    final m = widget.messages.firstWhere(
          (x) => x.id == id,
      orElse: () => Message(id: '0', from: '', text: ''),
    );
    if (m.id == '0') return false;
    setState(() {
      _replyTarget = m;
    });
    // keep message in list (do not dismiss)
    return false;
  }

  // cancel reply
  void _cancelReply() {
    setState(() => _replyTarget = null);
  }

  Widget _buildReplyPreview() {
    if (_replyTarget == null) return SizedBox.shrink();
    final r = _replyTarget!;
    return Container(
      margin: EdgeInsets.only(bottom: 8),
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.03), blurRadius: 6)
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  r.from,
                  style: TextStyle(fontSize: 12, color: AppColors.muted),
                ),
                SizedBox(height: 4),
                Text(
                  r.text,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          IconButton(icon: Icon(Icons.close), onPressed: _cancelReply),
        ],
      ),
    );
  }

  Widget _messageTile(Message m) {
    final isMe = m.from == 'You';
    return Dismissible(
      key: ValueKey(m.id),
      direction: DismissDirection.startToEnd, // swipe right
      confirmDismiss: (_) => _handleSwipeToReply(m.id),
      child: Container(
        margin: EdgeInsets.symmetric(vertical: 8),
        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.78,
          ),
          child: Column(
            crossAxisAlignment:
            isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              GestureDetector(
                onLongPress: () => _showReactionDialog(m),
                child: Container(
                  padding:
                  EdgeInsets.symmetric(vertical: 10, horizontal: 14),
                  decoration: BoxDecoration(
                    color: isMe
                        ? AppColors.primary.withOpacity(0.12)
                        : Colors.white,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(12),
                      topRight: Radius.circular(12),
                      bottomLeft: Radius.circular(isMe ? 12 : 0),
                      bottomRight: Radius.circular(isMe ? 0 : 12),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 6,
                        offset: Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // show replied preview inside message if present
                      if (m.repliedToText != null)
                        Container(
                          margin: EdgeInsets.only(bottom: 8),
                          padding: EdgeInsets.symmetric(
                              horizontal: 10, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                m.repliedToFrom ?? '',
                                style: TextStyle(
                                    fontSize: 12, color: AppColors.muted),
                              ),
                              SizedBox(height: 4),
                              Text(
                                m.repliedToText ?? '',
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(fontSize: 13),
                              ),
                            ],
                          ),
                        ),
                      Text(m.text, style: TextStyle(fontSize: 15)),
                    ],
                  ),
                ),
              ),
              // reaction chips
              if (m.reactions.isNotEmpty)
                Container(
                  margin: EdgeInsets.only(top: 6),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: m.reactions.entries.map((e) {
                        final emoji = e.key;
                        final count = e.value;
                        final reacted = m.reactedByMe.contains(emoji);
                        return Container(
                          margin: EdgeInsets.only(right: 6),
                          padding: EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: reacted
                                ? AppColors.primary.withOpacity(0.12)
                                : Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Row(
                            children: [
                              Text(emoji),
                              SizedBox(width: 6),
                              Text(
                                '$count',
                                style: TextStyle(
                                    fontSize: 12, color: AppColors.muted),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
              SizedBox(height: 6),
              Text(
                '${m.from} • ${_formatTime(m.time)}',
                style:
                TextStyle(fontSize: 11, color: AppColors.muted),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatTime(DateTime t) {
    final now = DateTime.now();
    if (now.difference(t).inDays == 0) {
      return '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
    }
    return '${t.month}/${t.day} ${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
  }

  Color _avatarColor(int id) {
    final palette = [
      Color(0xFFEF4444),
      Color(0xFFFB923C),
      Color(0xFFF59E0B),
      Color(0xFF10B981),
      Color(0xFF06B6D4),
      Color(0xFF6366F1)
    ];
    return palette[id % palette.length];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            CircleAvatar(
              child:
              Text(widget.friend.name[0], style: TextStyle(color: Colors.white)),
              backgroundColor: _avatarColor(widget.friend.id),
            ),
            SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.friend.name),
                Text(
                  'Direct message',
                  style: TextStyle(fontSize: 12),
                ),
              ],
            ),
          ],
        ),
        backgroundColor: AppColors.primary,
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scroll,
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 16),
              itemCount: widget.messages.length,
              itemBuilder: (ctx, i) {
                final m = widget.messages[i];
                return _messageTile(m);
              },
            ),
          ),

          // reply preview (above input)
          if (_replyTarget != null)
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 12),
              child: _buildReplyPreview(),
            ),

          // input area
          SafeArea(
            child: Padding(
              padding: EdgeInsets.only(
                left: 12,
                right: 12,
                top: 6,
                bottom: bottomExtraSpacing,
              ),
              child: Row(
                children: [
                  // text box
                  Expanded(
                    child: Container(
                      height: inputBoxHeight,
                      padding: EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                              color: Colors.black.withOpacity(0.03),
                              blurRadius: 6)
                        ],
                      ),
                      child: Row(
                        children: [
                          IconButton(
                            icon: Icon(Icons.emoji_emotions_outlined,
                                color: AppColors.muted),
                            onPressed: _showEmojiPicker,
                          ),
                          Expanded(
                            child: TextField(
                              controller: _controller,
                              decoration: InputDecoration(
                                hintText: 'Type a message',
                                border: InputBorder.none,
                              ),
                              maxLines: null,
                            ),
                          ),
                          if (_isRecording)
                            Container(
                              padding: EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.redAccent.withOpacity(0.08),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.mic,
                                      color: Colors.redAccent, size: 16),
                                  SizedBox(width: 6),
                                  Text(
                                    'Recording',
                                    style: TextStyle(
                                        color: Colors.redAccent,
                                        fontSize: 12),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(width: 10),
                  // mic/send button
                  Container(
                    height: inputBoxHeight,
                    width: inputBoxHeight,
                    decoration: BoxDecoration(
                      color: _isComposing
                          ? AppColors.primary
                          : (_isRecording ? Colors.redAccent : AppColors.primary),
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                            color: Colors.black.withOpacity(0.06),
                            blurRadius: 6)
                      ],
                    ),
                    child: IconButton(
                      icon: Icon(
                        _isComposing
                            ? Icons.send
                            : (_isRecording ? Icons.stop : Icons.mic),
                        color: Colors.white,
                      ),
                      onPressed: () {
                        if (_isComposing) {
                          _sendMessage();
                        } else {
                          if (_isRecording) {
                            _stopRecording();
                          } else {
                            _startRecording();
                          }
                        }
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------- Group Chat Screen (same reply-on-swipe) ----------
class GroupChatScreen extends StatefulWidget {
  final GroupChat group;
  final void Function(Message) onSend;
  final void Function(String, Message) onUpdateMessage;

  GroupChatScreen({
    required this.group,
    required this.onSend,
    required this.onUpdateMessage,
  });

  @override
  _GroupChatScreenState createState() => _GroupChatScreenState();
}

class _GroupChatScreenState extends State<GroupChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scroll = ScrollController();
  bool _isComposing = false;
  bool _isRecording = false;
  Message? _replyTarget;

  static const double inputBoxHeight = 56.0;
  static const double bottomExtraSpacing = 12.0;

  @override
  void initState() {
    super.initState();
    _controller.addListener(
            () => setState(() => _isComposing = _controller.text.trim().isNotEmpty));
  }

  @override
  void dispose() {
    _controller.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _showReactionDialog(Message m) async {
    final picked = await showDialog<String>(
      context: context,
      barrierColor: Colors.transparent,
      builder: (ctx) {
        return Center(
          child: Material(
            color: Colors.transparent,
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.85),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: commonReactions
                    .map(
                      (e) => InkWell(
                    onTap: () => Navigator.of(ctx).pop(e),
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8),
                      child: Text(e, style: TextStyle(fontSize: 28)),
                    ),
                  ),
                )
                    .toList(),
              ),
            ),
          ),
        );
      },
    );
    if (picked != null) {
      setState(() {
        m.toggleReaction(picked);
        widget.onUpdateMessage(m.id, m);
      });
    }
  }

  void _showEmojiPicker() {
    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(12))),
      builder: (ctx) {
        return Container(
          padding: EdgeInsets.all(12),
          height: 260,
          child: GridView.builder(
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 8,
              crossAxisSpacing: 6,
              mainAxisSpacing: 6,
            ),
            itemCount: fullEmojiSet.length,
            itemBuilder: (c, i) {
              final e = fullEmojiSet[i];
              return InkWell(
                onTap: () {
                  _controller.text = _controller.text + e;
                  _controller.selection = TextSelection.fromPosition(
                    TextPosition(offset: _controller.text.length),
                  );
                  Navigator.pop(c);
                },
                child: Center(
                  child: Text(e, style: TextStyle(fontSize: 22)),
                ),
              );
            },
          ),
        );
      },
    );
  }

  void _startRecording() {
    setState(() => _isRecording = true);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Recording started (placeholder)'),
        duration: Duration(seconds: 1),
      ),
    );
  }

  void _stopRecording() {
    setState(() => _isRecording = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Recording stopped (placeholder)'),
        duration: Duration(seconds: 1),
      ),
    );
  }

  void _sendMessage() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    final id = DateTime.now().millisecondsSinceEpoch.toString();
    final msg = Message(
      id: id,
      from: 'You',
      text: text,
      repliedToId: _replyTarget?.id,
      repliedToText: _replyTarget?.text,
      repliedToFrom: _replyTarget?.from,
    );
    widget.onSend(msg);
    setState(() {
      widget.group.messages.add(msg);
      _controller.clear();
      _replyTarget = null;
      _isComposing = false;
    });
    Future.delayed(Duration(milliseconds: 120), () {
      if (_scroll.hasClients) {
        _scroll.jumpTo(_scroll.position.maxScrollExtent + 80);
      }
    });
  }

  Widget _buildReplyPreview() {
    if (_replyTarget == null) return SizedBox.shrink();
    final r = _replyTarget!;
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.03), blurRadius: 6)
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  r.from,
                  style: TextStyle(fontSize: 12, color: AppColors.muted),
                ),
                SizedBox(height: 4),
                Text(
                  r.text,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.close),
            onPressed: () => setState(() => _replyTarget = null),
          ),
        ],
      ),
    );
  }

  Widget _messageTile(Message m) {
    final isMe = m.from == 'You';
    return Dismissible(
      key: ValueKey(m.id),
      direction: DismissDirection.startToEnd,
      confirmDismiss: (_) async {
        // set reply target and do not dismiss
        setState(() => _replyTarget = m);
        return false;
      },
      child: Container(
        margin: EdgeInsets.symmetric(vertical: 8),
        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.78,
          ),
          child: Column(
            crossAxisAlignment:
            isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              GestureDetector(
                onLongPress: () => _showReactionDialog(m),
                child: Column(
                  crossAxisAlignment: isMe
                      ? CrossAxisAlignment.end
                      : CrossAxisAlignment.start,
                  children: [
                    if (m.repliedToText != null)
                      Container(
                        margin: EdgeInsets.only(bottom: 6),
                        padding: EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '${m.repliedToFrom ?? ''}: ${m.repliedToText}',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    Container(
                      padding: EdgeInsets.symmetric(
                          vertical: 10, horizontal: 14),
                      decoration: BoxDecoration(
                        color: isMe
                            ? AppColors.success.withOpacity(0.12)
                            : Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                              color: Colors.black.withOpacity(0.04),
                              blurRadius: 6)
                        ],
                      ),
                      child: Text(m.text),
                    ),
                  ],
                ),
              ),
              if (m.reactions.isNotEmpty)
                Container(
                  margin: EdgeInsets.only(top: 6),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: m.reactions.entries
                          .map(
                            (e) => Container(
                          margin: EdgeInsets.only(right: 6),
                          padding: EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: m.reactedByMe.contains(e.key)
                                ? AppColors.success.withOpacity(0.12)
                                : Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(e.key),
                              SizedBox(width: 6),
                              Text(
                                '${e.value}',
                                style: TextStyle(color: AppColors.muted),
                              ),
                            ],
                          ),
                        ),
                      )
                          .toList(),
                    ),
                  ),
                ),
              SizedBox(height: 6),
              Text(
                '${m.from} • ${_formatTime(m.time)}',
                style:
                TextStyle(fontSize: 11, color: AppColors.muted),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatTime(DateTime t) {
    final now = DateTime.now();
    if (now.difference(t).inDays == 0) {
      return '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
    }
    return '${t.month}/${t.day} ${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.group.name),
            Text(
              '${widget.group.members.length} members',
              style: TextStyle(fontSize: 12),
            ),
          ],
        ),
        backgroundColor: AppColors.success,
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scroll,
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 16),
              itemCount: widget.group.messages.length,
              itemBuilder: (ctx, i) => _messageTile(widget.group.messages[i]),
            ),
          ),
          if (_replyTarget != null) _buildReplyPreview(),
          SafeArea(
            child: Padding(
              padding: EdgeInsets.only(
                left: 12,
                right: 12,
                top: 6,
                bottom: bottomExtraSpacing,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      height: inputBoxHeight,
                      padding: EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                              color: Colors.black.withOpacity(0.03),
                              blurRadius: 6)
                        ],
                      ),
                      child: Row(
                        children: [
                          IconButton(
                            icon: Icon(Icons.emoji_emotions_outlined,
                                color: AppColors.muted),
                            onPressed: _showEmojiPicker,
                          ),
                          Expanded(
                            child: TextField(
                              controller: _controller,
                              decoration: InputDecoration(
                                hintText: 'Write a message to the group',
                                border: InputBorder.none,
                              ),
                              maxLines: null,
                            ),
                          ),
                          if (_isRecording)
                            Container(
                              padding: EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.redAccent.withOpacity(0.08),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.mic,
                                      color: Colors.redAccent, size: 16),
                                  SizedBox(width: 6),
                                  Text(
                                    'Recording',
                                    style: TextStyle(
                                        color: Colors.redAccent,
                                        fontSize: 12),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(width: 10),
                  Container(
                    height: inputBoxHeight,
                    width: inputBoxHeight,
                    decoration: BoxDecoration(
                      color: _isComposing
                          ? AppColors.success
                          : (_isRecording ? Colors.redAccent : AppColors.success),
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                            color: Colors.black.withOpacity(0.06),
                            blurRadius: 6)
                      ],
                    ),
                    child: IconButton(
                      icon: Icon(
                        _isComposing
                            ? Icons.send
                            : (_isRecording ? Icons.stop : Icons.mic),
                        color: Colors.white,
                      ),
                      onPressed: () {
                        if (_isComposing) {
                          _sendMessage();
                        } else {
                          if (_isRecording) {
                            _stopRecording();
                          } else {
                            _startRecording();
                          }
                        }
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
