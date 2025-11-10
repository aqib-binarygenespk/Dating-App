import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';

/// Audio message bubble (playback UI).
class AudioMessageTile extends StatefulWidget {
  final String url;
  final int? durationMs;

  const AudioMessageTile({
    Key? key,
    required this.url,
    this.durationMs,
  }) : super(key: key);

  @override
  State<AudioMessageTile> createState() => _AudioMessageTileState();
}

class _AudioMessageTileState extends State<AudioMessageTile> {
  final AudioPlayer _player = AudioPlayer();

  bool _isPlaying = false;
  bool _isLoading = false;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;

  bool _dragging = false;
  Duration _dragPos = Duration.zero;

  @override
  void initState() {
    super.initState();

    if (widget.durationMs != null) {
      _duration = Duration(milliseconds: widget.durationMs!);
    }

    _player.onPlayerStateChanged.listen((state) {
      setState(() => _isPlaying = (state == PlayerState.playing));
    });

    _player.onDurationChanged.listen((d) {
      if (d.inMilliseconds > 0) {
        setState(() => _duration = d);
      }
    });

    _player.onPositionChanged.listen((p) {
      if (!_dragging) {
        setState(() => _position = p);
      }
    });

    _player.onPlayerComplete.listen((_) {
      setState(() {
        _position = Duration.zero;
        _isPlaying = false;
      });
    });
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  Future<void> _togglePlayPause() async {
    try {
      if (_isPlaying) {
        await _player.pause();
        return;
      }
      if (_position == Duration.zero) {
        setState(() => _isLoading = true);
        await _player.setSource(UrlSource(widget.url));
      }
      await _player.resume();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not play audio')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  double get _progress {
    final total = _duration.inMilliseconds;
    if (total <= 0) return 0;
    final now = (_dragging ? _dragPos : _position).inMilliseconds;
    return (now / total).clamp(0, 1);
  }

  Future<void> _seekToProgress(double v) async {
    final targetMs = (_duration.inMilliseconds * v).round();
    final target = Duration(milliseconds: targetMs);

    setState(() {
      _dragging = false;
      _dragPos = target;
      _position = target;
    });

    try {
      await _player.seek(target);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final iconBg = Colors.black87;
    final fg = Colors.white;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        InkWell(
          onTap: _togglePlayPause,
          borderRadius: BorderRadius.circular(20),
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(20),
            ),
            child: _isLoading
                ? const Padding(
              padding: EdgeInsets.all(10),
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
                : Icon(_isPlaying ? Icons.pause : Icons.play_arrow, color: fg),
          ),
        ),
        const SizedBox(width: 10),
        SizedBox(
          width: 160,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  trackHeight: 4,
                  thumbShape:
                  const RoundSliderThumbShape(enabledThumbRadius: 6),
                ),
                child: Slider(
                  value: _progress.isNaN ? 0 : _progress,
                  onChangeStart: (_) {
                    setState(() {
                      _dragging = true;
                      _dragPos = _position;
                    });
                  },
                  onChanged: (v) {
                    setState(() {
                      _dragPos = Duration(
                        milliseconds: (_duration.inMilliseconds * v).round(),
                      );
                    });
                  },
                  onChangeEnd: _seekToProgress,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '${_fmt(_dragging ? _dragPos : _position)} / ${_fmt(_duration)}',
                style: Theme.of(context)
                    .textTheme
                    .labelSmall
                    ?.copyWith(color: Colors.black54),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
