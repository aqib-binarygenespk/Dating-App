import 'package:flutter/material.dart';

class SocialHeaderBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  const SocialHeaderBar({required this.title, super.key});

  @override
  Size get preferredSize => const Size.fromHeight(64);

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.black),
        onPressed: () => Navigator.pop(context),
      ),
      title: Text(
        title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: text.bodyLarge?.copyWith(
          color: Colors.black,
          fontWeight: FontWeight.w800,
        ),
      ),
      centerTitle: false,
    );
  }
}

class SocialBottomButton extends StatelessWidget {
  final String text;
  final bool enabled;
  final Future<void> Function() onPressed;
  const SocialBottomButton({
    super.key,
    required this.text,
    required this.enabled,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
        child: SizedBox(
          height: 54,
          width: double.infinity,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: enabled ? Colors.black : Colors.black12,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              elevation: enabled ? 2 : 0,
            ),
            onPressed: enabled
                ? () async {
              try {
                await onPressed();
                if (context.mounted) {
                  ScaffoldMessenger.of(context)
                      .showSnackBar(const SnackBar(content: Text('Updated')));
                }
                if (context.mounted) Navigator.pop(context, true);
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context)
                      .showSnackBar(SnackBar(content: Text('Failed: $e')));
                }
              }
            }
                : null,
            child: Text(
              text,
              style: t.titleSmall?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
