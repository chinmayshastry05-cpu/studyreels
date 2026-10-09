import 'package:flutter/material.dart';

import '../../data/models/reel.dart';
import '../../data/models/segment.dart';
import '../widgets/reel_card.dart';

/// TikTok-style vertical swipe feed of reels.
class FeedScreen extends StatelessWidget {
  const FeedScreen({super.key});

  List<Reel> _demoReels() => const [
        Reel(
          id: 'demo-1',
          videoPath: '/sdcard/StudyReels/demo_lecture.mp4',
          chapter: 'Physics · Rotational Mechanics',
          segment: Segment(
            type: SegmentType.topic,
            title: 'Moment of inertia basics',
            startSec: 62,
            endSec: 210,
          ),
        ),
        Reel(
          id: 'demo-2',
          videoPath: '/sdcard/StudyReels/demo_lecture.mp4',
          chapter: 'Physics · Rotational Mechanics',
          segment: Segment(
            type: SegmentType.problem,
            title: 'Problem: rolling without slipping',
            startSec: 215,
            endSec: 340,
          ),
        ),
      ];

  @override
  Widget build(BuildContext context) {
    final reels = _demoReels();
    return Scaffold(
      appBar: AppBar(title: const Text('StudyReels')),
      body: PageView.builder(
        scrollDirection: Axis.vertical,
        itemCount: reels.length,
        itemBuilder: (context, i) => ReelCard(reel: reels[i]),
      ),
    );
  }
}
