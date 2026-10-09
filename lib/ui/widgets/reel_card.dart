import 'package:flutter/material.dart';

import '../../data/models/reel.dart';

/// One full-screen reel card. The video player itself is a phase-1
/// placeholder: it will play the ORIGINAL file at the segment's
/// start/end timestamps with overlay captions (no re-rendered clips).
class ReelCard extends StatelessWidget {
  final Reel reel;

  const ReelCard({super.key, required this.reel});

  String _fmt(int s) {
    final m = s ~/ 60;
    final r = s % 60;
    return '${m.toString().padLeft(2, '0')}:${r.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black,
      child: Stack(
        children: [
          const Center(
            child: Icon(
              Icons.play_circle_outline,
              size: 72,
              color: Colors.white54,
            ),
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: 32,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: reel.isProblem ? Colors.orange : Colors.blue,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    reel.isProblem ? 'PROBLEM' : 'TOPIC',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  reel.title,
                  style: const TextStyle(
                      fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  '${reel.chapter} · ${_fmt(reel.segment.startSec)} → ${_fmt(reel.segment.endSec)}',
                  style: const TextStyle(color: Colors.white70),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Player placeholder — plays the original file at segment timestamps.',
                  style: TextStyle(color: Colors.white54, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
