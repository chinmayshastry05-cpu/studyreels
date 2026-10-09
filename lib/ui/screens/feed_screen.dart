import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/services/library_store.dart';
import '../widgets/reel_player.dart';

/// TikTok-style vertical swipe feed of reels. Only the visible page plays.
class FeedScreen extends StatefulWidget {
  const FeedScreen({super.key});

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> {
  int _active = 0;

  @override
  Widget build(BuildContext context) {
    final reels = context.watch<LibraryStore>().reels;
    return Scaffold(
      appBar: AppBar(title: const Text('StudyReels')),
      body: reels.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'No reels yet.\n\nImport a lecture video from the Import tab — '
                  'it will be transcribed and split into topic/problem reels '
                  'entirely on your phone.',
                  textAlign: TextAlign.center,
                ),
              ),
            )
          : PageView.builder(
              scrollDirection: Axis.vertical,
              itemCount: reels.length,
              onPageChanged: (i) => setState(() => _active = i),
              itemBuilder: (context, i) => Container(
                color: Colors.black,
                child: ReelPlayer(
                  reel: reels[i],
                  active: i == _active,
                ),
              ),
            ),
    );
  }
}
