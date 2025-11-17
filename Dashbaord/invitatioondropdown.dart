// lib/Dashbaord/pairupscreens/pairup/addevent/invitatioondropdown.dart
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:dating_app/themesfolder/theme.dart';

import 'addevent_controller.dart';

class InviteDropdownField extends StatefulWidget {
  const InviteDropdownField({
    super.key,
    required this.controller,
    this.maxSelect = 5,
  });

  final AddEventController controller;
  final int maxSelect;

  @override
  State<InviteDropdownField> createState() => _InviteDropdownFieldState();
}

class _InviteDropdownFieldState extends State<InviteDropdownField> {
  final TextEditingController _text = TextEditingController();
  final FocusNode _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _focus.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _text.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _text,
          focusNode: _focus,
          onChanged: widget.controller.onInviteInputChanged,
          decoration: InputDecoration(
            hintText: "Search by name...",
            hintStyle: tt.bodySmall?.copyWith(color: Colors.black45),
            filled: true,
            fillColor: const Color(0xFFFFEFEF),
            contentPadding:
            const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide:
              const BorderSide(color: Color(0xFFD9D9D9), width: 1),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide:
              const BorderSide(color: Color(0xFFD9D9D9), width: 1),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide:
              const BorderSide(color: Color(0xFFD9D9D9), width: 1),
            ),
          ),
          style: tt.bodyMedium,
        ),

        // Suggestions / states
        Obx(() {
          // Touch Rxs first
          final isSearching = widget.controller.isSearching.value;
          final results = widget.controller.searchResults;
          final hasFocus = _focus.hasFocus;
          final queryNotEmpty = _text.text.trim().isNotEmpty;

          if (!hasFocus || !queryNotEmpty) return const SizedBox.shrink();

          // Container framing for dropdown + states
          return Container(
            margin: const EdgeInsets.only(top: 6),
            decoration: BoxDecoration(
              color: AppTheme.backgroundColor,
              border:
              Border.all(color: const Color(0xFFD9D9D9), width: 1),
              borderRadius: BorderRadius.circular(8),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 6,
                  offset: Offset(0, 2),
                )
              ],
            ),
            constraints: const BoxConstraints(maxHeight: 260),
            child: isSearching
                ? _buildStateTile("Searching…", trailing: const SizedBox(
                width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)))
                : results.isEmpty
                ? _buildStateTile("No close friends matched")
                : ListView.separated(
              shrinkWrap: true,
              itemCount: results.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, i) {
                final u = results[i];

                final first = (u['first_name'] ?? u['firstName'] ?? '').toString();
                final last  = (u['last_name']  ?? u['lastName']  ?? '').toString();
                String name = "$first $last".trim();
                if (name.isEmpty) {
                  name = (u['name'] ?? u['username'] ?? u['email'] ?? 'User').toString();
                }

                final photo = (u['photo_url'] ?? '').toString();

                return ListTile(
                  leading: CircleAvatar(
                    radius: 18,
                    backgroundImage: photo.isNotEmpty
                        ? NetworkImage(photo)
                        : const AssetImage('assets/dp1.png') as ImageProvider,
                  ),
                  title: Text(name),
                  onTap: () {
                    widget.controller.addUser(
                      id: (u['id'] as num).toInt(),
                      name: name,
                    );
                    widget.controller.searchResults.clear();
                    _text.clear();
                    _focus.unfocus();
                  },
                );
              },
            ),
          );
        }),

        const SizedBox(height: 10),

        // Selected chips
        Obx(() {
          final items = widget.controller.invitedPeople;
          if (items.isEmpty) return const SizedBox.shrink();

          return Wrap(
            spacing: 6,
            runSpacing: -6,
            children: items.map((p) {
              return Chip(
                label: Text(p['name'], style: tt.labelSmall),
                deleteIcon: const Icon(Icons.close, size: 16),
                onDeleted: () => widget.controller.removeUser(p),
                backgroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: const BorderSide(color: Colors.black26),
                ),
              );
            }).toList(),
          );
        }),
      ],
    );
  }

  Widget _buildStateTile(String text, {Widget? trailing}) {
    return ListTile(
      dense: true,
      title: Text(text),
      trailing: trailing,
    );
  }
}
