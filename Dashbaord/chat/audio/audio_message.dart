import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

class AudioRecorderSheet extends StatefulWidget {
  /// When the user taps “Send”, you get (file, duration)
  final Future<void> Function(File file, Duration duration) onSend;

  const AudioRecorderSheet({Key? key, required this.onSend}) : super(key: key);

  @override
  State<AudioRecorderSheet> createState() => _AudioRecorderSheetState();
}

class _AudioRecorderSheetState extends State<AudioRecorderSheet> {
  final _rec = AudioRecorder();
  bool _recording = false;
  bool _hasPermission = false;
  Stopwatch _watch = Stopwatch();
  Timer? _ticker;
  Duration _elapsed = Duration.zero;
  String? _filePath; // last recorded path

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final ok = await _rec.hasPermission();
    setState(() => _hasPermission = ok);
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _rec.dispose();
    super.dispose();
  }

  Future<String> _makeTempPath() async {
    final dir = await getTemporaryDirectory();
    final name = 'aud_${DateTime.now().millisecondsSinceEpoch}.m4a';
    return '${dir.path}/$name';
  }

  Future<void> _start() async {
    if (!_hasPermission) {
      final ok = await _rec.hasPermission();
      if (!ok) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Microphone permission denied')),
          );
        }
        return;
      }
    }
    final path = await _makeTempPath();
    await _rec.start(
      const RecordConfig(
        encoder: AudioEncoder.aacLc,
        bitRate: 128000,
        sampleRate: 44100,
      ),
      path: path,
    );
    setState(() {
      _filePath = path;
      _recording = true;
      _elapsed = Duration.zero;
      _watch = Stopwatch()..start();
      _ticker?.cancel();
      _ticker = Timer.periodic(const Duration(milliseconds: 200), (_) {
        setState(() => _elapsed = _watch.elapsed);
      });
    });
  }

  Future<void> _stop({bool discard = false}) async {
    if (!_recording) return;
    _watch.stop();
    _ticker?.cancel();

    final path = await _rec.stop();
    setState(() => _recording = false);

    if (discard) {
      if (path != null) File(path).delete().ignore();
      setState(() => _filePath = null);
      return;
    }

    final fp = path ?? _filePath;
    if (fp == null || !(await File(fp).exists())) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Recording failed')),
        );
      }
      return;
    }
    // minimum length guard (optional)
    if (_elapsed.inMilliseconds < 400) {
      File(fp).delete().ignore();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Hold to record a bit longer')),
        );
      }
      setState(() => _filePath = null);
      return;
    }

    await widget.onSend(File(fp), _elapsed);
    if (mounted) Navigator.pop(context); // close the sheet
  }

  String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              height: 4,
              width: 40,
              decoration: BoxDecoration(
                color: Colors.black26,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            Text('Voice Message', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            Text(
              _fmt(_elapsed),
              style: Theme.of(context).textTheme.displaySmall?.copyWith(fontSize: 32),
            ),
            const SizedBox(height: 16),
            if (_recording)
              const LinearProgressIndicator(minHeight: 4)
            else
              const SizedBox(height: 4),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Cancel / discard
                IconButton(
                  onPressed: _recording
                      ? () => _stop(discard: true)
                      : () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                  tooltip: 'Cancel',
                ),
                const SizedBox(width: 24),
                // Big mic / stop button
                GestureDetector(
                  onTap: _recording ? () => _stop() : _start,
                  child: Container(
                    width: 80,
                    height: 80,
                    decoration: const BoxDecoration(
                      color: Colors.black,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _recording ? Icons.stop : Icons.mic,
                      color: Colors.white,
                      size: 36,
                    ),
                  ),
                ),
                const SizedBox(width: 24),
                // Send (only if recorded + not actively recording)
                IconButton(
                  onPressed:
                  (!_recording && _filePath != null) ? () => _stop() : null,
                  icon: const Icon(Icons.send),
                  tooltip: 'Send',
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              _recording ? 'Tap to stop & send' : 'Tap mic to record',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}
