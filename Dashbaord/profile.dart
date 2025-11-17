import 'package:dating_app/Dashbaord/profile/profile_controller.dart';
import 'package:dating_app/themesfolder/theme.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:video_player/video_player.dart';

class ProfileScreen extends StatefulWidget {
  ProfileScreen({Key? key}) : super(key: key);

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final ProfileController controller = Get.find<ProfileController>();
  final PageController _pageController = PageController();
  final RxInt _currentPage = 0.obs;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: Obx(() {
        final paddedImages = List<String>.from(controller.imageUrls);
        while (paddedImages.length < 6) {
          paddedImages.add('');
        }

        final hasVideo = controller.videoUrl.value.isNotEmpty;
        final totalItems = (hasVideo ? 1 : 0) + paddedImages.length;

        return SafeArea(
          child: Column(
            children: [
              // Logo Header
              Padding(
                padding: const EdgeInsets.fromLTRB(15, 0, 15, 0),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Image.asset(
                    'assets/the_pairup_logo_black.png',
                    height: 80,
                  ),
                ),
              ),

              const Divider(thickness: 0.5, height: 0.7, color: Colors.black12),

              // Title
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                child: Row(
                  children: [
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 7.0),
                        child: Text(
                          'Dating Profile',
                          style: AppTheme.textTheme.bodyLarge,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Main Content
              Expanded(
                child: controller.profileDetails.isEmpty
                    ? const Center(child: CircularProgressIndicator())
                    : SingleChildScrollView(
                  child: Column(
                    children: [
                      // ► Video-first Carousel (video + six images)
                      Column(
                        children: [
                          SizedBox(
                            height: 300,
                            child: PageView.builder(
                              controller: _pageController,
                              itemCount: totalItems,
                              onPageChanged: (index) {
                                _currentPage.value = index;
                              },
                              itemBuilder: (context, index) {
                                if (hasVideo && index == 0) {
                                  return _VideoPreviewCard(
                                    url: controller.videoUrl.value,
                                    onOpen: () => _showVideoDialog(
                                      context,
                                      controller.videoUrl.value,
                                    ),
                                  );
                                }

                                // Map index → image
                                final imgIndex = hasVideo ? index - 1 : index;
                                final imageUrl = paddedImages[imgIndex];

                                return ClipRRect(
                                  borderRadius: BorderRadius.circular(16),
                                  child: Container(
                                    margin: const EdgeInsets.symmetric(horizontal: 8),
                                    color: imageUrl.isEmpty ? Colors.grey[300] : null,
                                    child: imageUrl.isNotEmpty
                                        ? Image.network(
                                      imageUrl,
                                      fit: BoxFit.cover,
                                      width: double.infinity,
                                      height: double.infinity,
                                      errorBuilder: (ctx, _, __) =>
                                      const Center(child: Icon(Icons.broken_image, size: 40)),
                                      loadingBuilder: (ctx, child, progress) {
                                        if (progress == null) return child;
                                        return const Center(child: CircularProgressIndicator());
                                      },
                                    )
                                        : const Center(
                                      child: Icon(Icons.image_not_supported,
                                          size: 40, color: Colors.grey),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                          const SizedBox(height: 8),
                          Obx(() {
                            return Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: List.generate(totalItems, (index) {
                                return AnimatedContainer(
                                  duration: const Duration(milliseconds: 300),
                                  margin: const EdgeInsets.symmetric(horizontal: 4),
                                  height: 8,
                                  width: _currentPage.value == index ? 12 : 8,
                                  decoration: BoxDecoration(
                                    color: _currentPage.value == index
                                        ? Colors.black
                                        : Colors.grey,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                );
                              }),
                            );
                          }),
                        ],
                      ),

                      const SizedBox(height: 16),

                      // User Info
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              controller.userName.value,
                              style: const TextStyle(
                                  fontSize: 24, fontWeight: FontWeight.bold),
                            ),
                            Text(
                              controller.ageHeight.value,
                              style: const TextStyle(color: Colors.black54),
                            ),
                            const SizedBox(height: 16),

                            // Profile Sections
                            ...controller.profileDetails.map((section) {
                              final isBonding = section['title'] == 'Bonding Moments';
                              final content = isBonding
                                  ? _shortenBonding(section['content']!)
                                  : section['content']!;
                              return Column(
                                children: [
                                  buildProfileSection(
                                    context,
                                    section['title']!,
                                    content,
                                  ),
                                  const Divider(
                                    color: Colors.grey,
                                    thickness: 0.5,
                                  ),
                                ],
                              );
                            }).toList(),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      }),
    );
  }

  Widget buildProfileSection(BuildContext context, String title, String content) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AppTheme.textTheme.bodyMedium),
          const SizedBox(height: 4),
          Text(content, style: AppTheme.textTheme.bodySmall),
        ],
      ),
    );
  }

  String _shortenBonding(String content) {
    final parts = content.split(', ');
    if (parts.length <= 3) return content;
    return '${parts.take(3).join(', ')} ...';
  }

  /// Fullscreen video dialog
  void _showVideoDialog(BuildContext context, String url) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => _FullscreenVideoDialog(videoUrl: url),
    );
  }
}

/// --- VIDEO PREVIEW CARD (first frame only, tap to play fullscreen) ---
class _VideoPreviewCard extends StatefulWidget {
  final String url;
  final VoidCallback onOpen;

  const _VideoPreviewCard({
    Key? key,
    required this.url,
    required this.onOpen,
  }) : super(key: key);

  @override
  State<_VideoPreviewCard> createState() => _VideoPreviewCardState();
}

class _VideoPreviewCardState extends State<_VideoPreviewCard>
    with AutomaticKeepAliveClientMixin {
  late VideoPlayerController _controller;
  bool _init = false;
  bool _error = false;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.url))
      ..initialize().then((_) {
        if (!mounted) return;
        _controller.setVolume(0);
        setState(() => _init = true);
      }).catchError((_) {
        if (!mounted) return;
        setState(() => _error = true);
      });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return GestureDetector(
      onTap: widget.onOpen,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 8),
          color: Colors.black,
          child: Stack(
            children: [
              if (_error)
                const Center(child: Icon(Icons.videocam_off, color: Colors.white70, size: 42))
              else if (_init)
                Center(
                  child: AspectRatio(
                    aspectRatio: _controller.value.aspectRatio == 0.0
                        ? 16 / 9
                        : _controller.value.aspectRatio,
                    child: VideoPlayer(_controller),
                  ),
                )
              else
                const Center(child: CircularProgressIndicator()),
              Container(color: Colors.black.withOpacity(0.15)),
              const Center(
                child: Icon(Icons.play_circle_fill_rounded, size: 64, color: Colors.white),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Fullscreen video player dialog
class _FullscreenVideoDialog extends StatefulWidget {
  final String videoUrl;

  const _FullscreenVideoDialog({Key? key, required this.videoUrl})
      : super(key: key);

  @override
  State<_FullscreenVideoDialog> createState() => _FullscreenVideoDialogState();
}

class _FullscreenVideoDialogState extends State<_FullscreenVideoDialog> {
  late VideoPlayerController _controller;
  bool _ready = false;
  bool _error = false;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl))
      ..initialize().then((_) {
        if (!mounted) return;
        setState(() => _ready = true);
        _controller.play();
      }).catchError((_) {
        if (!mounted) return;
        setState(() => _error = true);
      });
  }

  @override
  void dispose() {
    _controller.pause();
    _controller.dispose();
    super.dispose();
  }

  void _toggle() {
    if (!_controller.value.isInitialized) return;
    if (_controller.value.isPlaying) {
      _controller.pause();
    } else {
      _controller.play();
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.black,
      insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 24),
      child: Stack(
        children: [
          Center(
            child: _error
                ? const Text('Unable to play video', style: TextStyle(color: Colors.white))
                : (!_ready
                ? const CircularProgressIndicator()
                : GestureDetector(
              onTap: _toggle,
              child: AspectRatio(
                aspectRatio: _controller.value.aspectRatio == 0.0
                    ? 16 / 9
                    : _controller.value.aspectRatio,
                child: VideoPlayer(_controller),
              ),
            )),
          ),
          Positioned(
            top: 20,
            right: 16,
            child: GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.85),
                ),
                padding: const EdgeInsets.all(6),
                child: const Icon(Icons.close, color: Colors.black),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
