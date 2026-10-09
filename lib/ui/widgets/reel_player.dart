import 'dart:io';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../../data/models/reel.dart';
import '../../data/models/transcript.dart';

/// Plays the ORIGINAL video file, looping the reel's [start, end] range —
/// reels are never re-rendered clips. Shows transcript captions as an
/// overlay and the reel title/chapter below.
///
/// [active] should be true only for the currently visible page so a single
/// reel plays at a time.
class ReelPlayer extends StatefulWidget {
  final Reel reel;
  final bool active;

  const ReelPlayer({super.key, required this.reel, this.active = true});

  @override
  State<ReelPlayer> createState() => _ReelPlayerState();
}

class _ReelPlayerState extends State<ReelPlayer> {
  late final VideoPlayerController _controller;
  bool _ready = false;
  String? _error;

  double get _startSec => widget.reel.segment.startSec.toDouble();
  double get _endSec => widget.reel.segment.endSec.toDouble();

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.file(File(widget.reel.videoPath));
    _controller.addListener(_onTick);
    _controller.initialize().then((_) {
      if (!mounted) return;
      setState(() => _ready = true);
      _controller.seekTo(Duration(milliseconds: (_startSec * 1000).toInt()));
      if (widget.active) _controller.play();
    }).catchError((Object e) {
      if (mounted) setState(() => _error = e.toString());
    });
  }

  @override
  void didUpdateWidget(ReelPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active != oldWidget.active && _ready) {
      if (widget.active) {
        _controller.play();
      } else {
        _controller.pause();
      }
    }
  }

  String? _lastCaption;
  bool _lastPlaying = true;

  void _onTick() {
    if (!_ready || !mounted) return;
    final value = _controller.value;
    final pos = value.position;
    // Loop the segment: past the end (or before the start) -> back to start.
    if (pos.inMilliseconds >= (_endSec * 1000).toInt() ||
        pos.inMilliseconds < (_startSec * 1000).toInt() - 500) {
      _controller.seekTo(Duration(milliseconds: (_startSec * 1000).toInt()));
    }
    // Rebuild only when the visible caption or play state changes.
    final caption = widget.reel.captionOverride ??
        captionAt(widget.reel.captions, pos.inMilliseconds / 1000.0)?.text;
    if (caption != _lastCaption || value.isPlaying != _lastPlaying) {
      _lastCaption = caption;
      _lastPlaying = value.isPlaying;
      setState(() {});
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_onTick);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return _fallback('Could not play video\n$_error');
    }
    if (!_ready) {
      return const Center(child: CircularProgressIndicator());
    }
    final posSec =
        _controller.value.position.inMilliseconds / 1000.0;
    final caption = widget.reel.captionOverride ??
        captionAt(widget.reel.captions, posSec)?.text;

    return GestureDetector(
      onTap: () {
        setState(() {
          _controller.value.isPlaying
              ? _controller.pause()
              : _controller.play();
        });
      },
      child: Stack(
        fit: StackFit.expand,
        children: [
          Center(
            child: AspectRatio(
              aspectRatio: _controller.value.aspectRatio,
              child: VideoPlayer(_controller),
            ),
          ),
          if (!_controller.value.isPlaying)
            const Center(
              child: Icon(Icons.play_arrow,
                  size: 72, color: Colors.white70),
            ),
          // Caption overlay.
          if (caption != null && caption.isNotEmpty)
            Positioned(
              left: 16,
              right: 16,
              bottom: 120,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.black87,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  caption,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 16),
                ),
              ),
            ),
          // Title / chapter overlay.
          Positioned(
            left: 16,
            right: 16,
            bottom: 32,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: widget.reel.isProblem
                        ? Colors.orange
                        : Colors.blue,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    widget.reel.isProblem ? 'PROBLEM' : 'TOPIC',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  widget.reel.title,
                  style: const TextStyle(
                      fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  widget.reel.chapter,
                  style: const TextStyle(color: Colors.white70),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _fallback(String message) {
    return Container(
      color: Colors.black,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(message, textAlign: TextAlign.center),
        ),
      ),
    );
  }
}
