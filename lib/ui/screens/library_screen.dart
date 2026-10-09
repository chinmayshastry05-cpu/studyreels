import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/models/chapter.dart';
import '../../data/services/library_store.dart';
import '../widgets/reel_player.dart';

/// Saved reels organized by chapter, then topic/problem. Tapping a reel
/// opens it in the full-screen player.
class LibraryScreen extends StatelessWidget {
  const LibraryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final chapters = context.watch<LibraryStore>().chapters;
    return Scaffold(
      appBar: AppBar(title: const Text('Library')),
      body: chapters.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Your saved reels will appear here, organized by chapter and topic.\n\n'
                  'Import a lecture video to get started.',
                  textAlign: TextAlign.center,
                ),
              ),
            )
          : ListView.builder(
              itemCount: chapters.length,
              itemBuilder: (context, i) =>
                  _chapterTile(context, chapters[i]),
            ),
    );
  }

  Widget _chapterTile(BuildContext context, Chapter chapter) {
    return ExpansionTile(
      title: Text(chapter.name,
          style: const TextStyle(fontWeight: FontWeight.bold)),
      subtitle: Text(
          '${chapter.topics.length} topics · ${chapter.problems.length} problems'),
      children: [
        const Padding(
          padding: EdgeInsets.only(left: 16, top: 4),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text('TOPICS',
                style: TextStyle(
                    fontSize: 12,
                    color: Colors.white54,
                    fontWeight: FontWeight.bold)),
          ),
        ),
        ...chapter.topics.map((r) => _reelTile(context, r)),
        const Padding(
          padding: EdgeInsets.only(left: 16, top: 8),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text('PROBLEMS',
                style: TextStyle(
                    fontSize: 12,
                    color: Colors.white54,
                    fontWeight: FontWeight.bold)),
          ),
        ),
        ...chapter.problems.map((r) => _reelTile(context, r)),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _reelTile(BuildContext context, reel) {
    return ListTile(
      leading: Icon(
        reel.isProblem ? Icons.calculate : Icons.topic,
        color: reel.isProblem ? Colors.orange : Colors.blue,
      ),
      title: Text(reel.title),
      subtitle: Text(_fmt(reel.segment.startSec, reel.segment.endSec)),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => Scaffold(
            appBar: AppBar(title: Text(reel.title)),
            body: ReelPlayer(reel: reel),
          ),
        ),
      ),
    );
  }

  String _fmt(int start, int end) {
    String f(int s) =>
        '${(s ~/ 60).toString().padLeft(2, '0')}:${(s % 60).toString().padLeft(2, '0')}';
    return '${f(start)} → ${f(end)}';
  }
}
