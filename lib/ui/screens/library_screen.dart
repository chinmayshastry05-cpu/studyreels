import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/models/chapter.dart';
import '../../data/models/reel.dart';
import '../../data/services/library_store.dart';
import '../widgets/fx.dart';
import '../widgets/reel_player.dart';

/// Saved reels organized by chapter, then topic/problem. Tapping a reel
/// opens it in the full-screen player.
class LibraryScreen extends StatelessWidget {
  final VoidCallback? onImportTap;
  const LibraryScreen({super.key, this.onImportTap});

  @override
  Widget build(BuildContext context) {
    final chapters = context.watch<LibraryStore>().chapters;
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Library')),
      body: chapters.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const GoldIconBadge(Icons.video_library_outlined, size: 72),
                  const SizedBox(height: 20),
                  const Text('Your library is empty',
                      style: TextStyle(
                          fontSize: 22, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 8),
                  Text(
                    'Saved reels land here, organized\nby chapter and topic.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 14, height: 1.5, color: cs.onSurfaceVariant),
                  ),
                  const SizedBox(height: 24),
                  if (onImportTap != null)
                    SizedBox(
                      width: 240,
                      child: GoldButton(
                        label: 'Import a lecture',
                        icon: Icons.add,
                        onPressed: onImportTap,
                      ),
                    ),
                ]),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.only(top: 4, bottom: 24),
              itemCount: chapters.length,
              itemBuilder: (context, i) =>
                  _chapterTile(context, chapters[i]),
            ),
    );
  }

  Widget _chapterTile(BuildContext context, Chapter chapter) {
    final cs = Theme.of(context).colorScheme;
    return GlowCard(
      padding: EdgeInsets.zero,
      child: ExpansionTile(
        shape: const Border(),
        collapsedShape: const Border(),
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        childrenPadding: const EdgeInsets.only(bottom: 10),
        title: Text(chapter.name,
            style:
                const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
              '${chapter.topics.length} topics · ${chapter.problems.length} problems',
              style: TextStyle(fontSize: 12.5, color: cs.onSurfaceVariant)),
        ),
        children: [
          if (chapter.topics.isNotEmpty)
            _sectionLabel(context, 'TOPICS'),
          ...chapter.topics.map((r) => _reelTile(context, r)),
          if (chapter.problems.isNotEmpty)
            _sectionLabel(context, 'PROBLEMS'),
          ...chapter.problems.map((r) => _reelTile(context, r)),
        ],
      ),
    );
  }

  Widget _sectionLabel(BuildContext context, String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 20, top: 6, bottom: 2),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(text,
            style: TextStyle(
                fontSize: 11,
                letterSpacing: 1.1,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w800)),
      ),
    );
  }

  Widget _reelTile(BuildContext context, Reel reel) {
    final isProblem = reel.isProblem;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: isProblem
              ? Colors.transparent
              : AppColors.gold.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: AppColors.gold
                  .withValues(alpha: isProblem ? 0.55 : 0.25)),
        ),
        child: Icon(
          isProblem ? Icons.functions : Icons.menu_book_outlined,
          size: 20,
          color: AppColors.gold,
        ),
      ),
      title: Text(reel.title,
          style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600)),
      subtitle: Text(_fmt(reel.segment.startSec, reel.segment.endSec),
          style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).colorScheme.onSurfaceVariant)),
      trailing: const Icon(Icons.play_circle_outline,
          color: AppColors.gold, size: 22),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => Scaffold(
            backgroundColor: Colors.black,
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
