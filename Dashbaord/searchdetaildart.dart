import 'package:dating_app/Dashbaord/search/Searchdetail/search_profiledart.dart';
import 'package:dating_app/themesfolder/theme.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';

import '../../dashboard/Dashboard.dart';
import '../search_controller.dart';

class DetailProfileScreen extends StatefulWidget {
  final SearchProfile profile;
  const DetailProfileScreen({Key? key, required this.profile}) : super(key: key);

  @override
  State<DetailProfileScreen> createState() => _DetailProfileScreenState();
}

class _DetailProfileScreenState extends State<DetailProfileScreen> {
  final ScrollController _scrollController = ScrollController();
  final PageController _pageController = PageController();
  int _currentPage = 0;

  late final CustomSearchController _searchC;
  bool _isAlive = true;

  @override
  void initState() {
    super.initState();
    _searchC = Get.find<CustomSearchController>(); // provided by SearchScreen
  }

  @override
  void dispose() {
    _isAlive = false;
    _scrollController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  Future<bool> _handleBack() async {
    if (mounted && Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
      return true;
    }

    if (Get.key.currentState?.canPop() == true) {
      Get.back();
      return true;
    }

    // ✅ Fallback: go to Dashboard with Search tab selected
    Get.offAll(() => const DashboardScreen(selectedIndex: 1));
    return false; // we handled it
  }


  // --- Social link opener ----------------------------------------------------
  Future<void> _openExternalUrl(String? url) async {
    if (url == null || url.trim().isEmpty) {
      Get.snackbar('Social link', 'No link available.');
      return;
    }
    final uri = Uri.tryParse(url);
    if (uri == null) {
      Get.snackbar('Social link', 'Invalid URL.');
      return;
    }
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok) {
      Get.snackbar('Social link', 'Could not open the link.');
    }
  }

  @override
  Widget build(BuildContext context) {
    // Build media list: index 0 is video (or "no video"), then the images
    final imageUrls = widget.profile.photos.map((e) => e.url).toList();
    final hasVideo = (widget.profile.videoUrl != null &&
        widget.profile.videoUrl!.trim().isNotEmpty);

    final totalItems = 1 + imageUrls.length; // 1 = video/placeholder

    final receiverId = widget.profile.id;
    final facebookUrl = widget.profile.facebookLink;
    final instagramUrl = widget.profile.instagramLink;

    return WillPopScope(
      onWillPop: _handleBack,
      child: Scaffold(
        backgroundColor: AppTheme.backgroundColor,
        body: Column(
          children: [
            // Logo header
            Padding(
              padding: const EdgeInsets.fromLTRB(15, 10, 15, 0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Image.asset('assets/the_pairup_logo_black.png', height: 80),
              ),
            ),

            // Top bar with back, title, socials, like
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.black),
                    onPressed: () => _handleBack(),
                  ),
                  const SizedBox(width: 5),
                  Expanded(
                    child: Text('Dating Profile', style: AppTheme.textTheme.bodyLarge),
                  ),

                  // Facebook
                  GestureDetector(
                    onTap: facebookUrl == null ? null : () => _openExternalUrl(facebookUrl),
                    child: Opacity(
                      opacity: facebookUrl == null ? 0.35 : 1,
                      child: Image.asset('assets/facebooklogo.png', height: 24, width: 24),
                    ),
                  ),
                  const SizedBox(width: 10),

                  // Instagram
                  GestureDetector(
                    onTap: instagramUrl == null ? null : () => _openExternalUrl(instagramUrl),
                    child: Opacity(
                      opacity: instagramUrl == null ? 0.35 : 1,
                      child: Image.asset('assets/instalogo.png', height: 24, width: 24),
                    ),
                  ),
                  const SizedBox(width: 10),

                  // ♥ Like — red while liked; controller hides after 3s
                  GestureDetector(
                    onTap: () => _searchC.likeUser(receiverId),
                    child: Obx(() {
                      final liked = _searchC.isLiked(receiverId);
                      return Icon(
                        liked ? Icons.favorite : Icons.favorite_border,
                        color: liked ? Colors.red : Colors.black,
                      );
                    }),
                  ),
                ],
              ),
            ),
            const Divider(thickness: 1, height: 1, color: Colors.black12),

            // Body
            Expanded(
              child: Scrollbar(
                controller: _scrollController,
                thickness: 8.0,
                radius: const Radius.circular(8.0),
                thumbVisibility: true,
                child: SingleChildScrollView(
                  controller: _scrollController,
                  padding: const EdgeInsets.only(left: 16, right: 16, top: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ► Video-first Carousel (index 0 is video/placeholder, then images)
                      SizedBox(
                        height: 320, // taller so contain images look larger
                        child: PageView.builder(
                          controller: _pageController,
                          onPageChanged: (index) {
                            if (!_isAlive) return;
                            setState(() => _currentPage = index);
                          },
                          itemCount: totalItems,
                          itemBuilder: (context, index) {
                            // Index 0: video (or placeholder)
                            if (index == 0) {
                              if (hasVideo) {
                                return _VideoCard(
                                  url: widget.profile.videoUrl!.trim(),
                                  onOpen: () => _showVideoDialog(
                                    context,
                                    widget.profile.videoUrl!.trim(),
                                  ),
                                );
                              } else {
                                // Grey "No video" panel
                                return Container(
                                  margin: const EdgeInsets.symmetric(horizontal: 8),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(16.0),
                                    color: Colors.grey[300],
                                  ),
                                  child: const Center(
                                    child: Text(
                                      'No video',
                                      style: TextStyle(
                                        color: Colors.black54,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                );
                              }
                            }

                            // Images (shifted by 1)
                            final imgIndex = index - 1;
                            final url = imageUrls[imgIndex];

                            // ✅ Full image without cropping (contain) + inline pinch-zoom
                            return Container(
                              margin: const EdgeInsets.symmetric(horizontal: 8),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(16.0),
                                color: Colors.black12, // subtle letterbox bg
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(16.0),
                                child: AspectRatio(
                                  aspectRatio: 3 / 4, // portrait-friendly; adjust if needed
                                  child: InteractiveViewer(
                                    minScale: 1.0,
                                    maxScale: 4.0,
                                    child: Image.network(
                                      url,
                                      fit: BoxFit.contain,   // ⬅️ no cropping
                                      width: double.infinity,
                                      height: double.infinity,
                                      errorBuilder: (context, _, __) =>
                                      const Center(child: Icon(Icons.broken_image, size: 40)),
                                      loadingBuilder: (context, child, progress) {
                                        if (progress == null) return child;
                                        return const Center(child: CircularProgressIndicator());
                                      },
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 8),
                      Center(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: List.generate(totalItems, (index) {
                            final active = _currentPage == index;
                            return AnimatedContainer(
                              duration: const Duration(milliseconds: 300),
                              margin: const EdgeInsets.symmetric(horizontal: 4.0),
                              height: 10,
                              width: active ? 12 : 8,
                              decoration: BoxDecoration(
                                color: active ? Colors.black : Colors.grey,
                                borderRadius: BorderRadius.circular(8.0),
                              ),
                            );
                          }),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Name, age, distance
                      Text(widget.profile.name, style: AppTheme.textTheme.bodyLarge),
                      Text(
                        '${widget.profile.age ?? 'N/A'} years old'
                            '${widget.profile.distanceMiles == null ? '' : ' • ${widget.profile.distanceMiles!.toStringAsFixed(1)} mi'}',
                        style: AppTheme.textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 16),

                      _section('About Me', widget.profile.aboutMe),
                      _divider(),
                      _section('Bonding Moments', widget.profile.bondingMoments),
                      _divider(),
                      _section('Kids', widget.profile.kids),
                      _divider(),
                      _section('Pets', widget.profile.pets),
                      _divider(),
                      _section('Smoking Habits', widget.profile.smokingHabits),
                      _divider(),
                      _section('Drinking Habits', widget.profile.drinkingHabits),
                      _divider(),
                      _section('Dietary Preferences', widget.profile.dietPreferences),
                      _divider(),
                      _section('Love Languages', widget.profile.loveLanguage),
                      _divider(),
                      _section('Attachment Style', widget.profile.attachmentStyle),
                      _divider(),
                      _section('Relocate for Love', widget.profile.relocateForLove),
                      _divider(),
                      _section('Work', widget.profile.work),
                      _divider(),
                      _section('Politics', widget.profile.politics),
                      _divider(),
                      _section('Religion', widget.profile.religion),
                      _divider(),
                      _section('Education', widget.profile.education),

                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Fullscreen video dialog: autoplay, tap to toggle play/pause, X to close
  void _showVideoDialog(BuildContext context, String url) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => _FullscreenVideoDialog(videoUrl: url),
    );
  }

  Widget _section(String title, String? content) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8.0),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: AppTheme.textTheme.bodyMedium),
        const SizedBox(height: 4),
        Text(
          (content == null || content.isEmpty) ? 'N/A' : content,
          style: AppTheme.textTheme.bodySmall,
        ),
      ],
    ),
  );

  Widget _divider() => const Divider(color: Colors.grey, thickness: 0.5);
}

/// Card shown in the carousel for the video (first item)
class _VideoCard extends StatelessWidget {
  final String url;
  final VoidCallback onOpen;

  const _VideoCard({Key? key, required this.url, required this.onOpen})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onOpen,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16.0),
          color: Colors.black,
        ),
        child: Stack(
          children: [
            // Overlay
            Container(
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.35), // <- no withOpacity
                borderRadius: BorderRadius.circular(16.0),
              ),
            ),
            const Center(
              child: Icon(
                Icons.play_circle_fill_rounded,
                size: 64,
                color: Colors.white,
              ),
            ),
            Positioned(
              left: 12,
              top: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.85), // <- no withOpacity
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.videocam, size: 16),
                    SizedBox(width: 4),
                    Text('Video', style: TextStyle(fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Fullscreen video player dialog with close (X) button.
/// Autoplays on open. Tap video area to toggle play/pause.
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
    // Use networkUrl + Uri.parse (modern API)
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
    // Dispose to reclaim resources (per package docs)
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
          // Close button (X)
          Positioned(
            top: 20,
            right: 16,
            child: GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.85), // <- no withOpacity
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
