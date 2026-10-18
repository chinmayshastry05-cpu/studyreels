import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/services/library_store.dart';
import '../widgets/fx.dart';
import '../widgets/reel_player.dart';

/// Vertical swipe feed of reels. Only the visible page plays.
class FeedScreen extends StatefulWidget {
  final VoidCallback? onImportTap;
  const FeedScreen({super.key, this.onImportTap});

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> {
  int _active = 0;

  @override
  Widget build(BuildContext context) {
    final reels = context.watch<LibraryStore>().reels;
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Reels')),
      body: reels.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const GoldIconBadge(Icons.play_circle_outline, size: 72),
                  const SizedBox(height: 20),
                  const Text('No reels yet',
                      style: TextStyle(
                          fontSize: 22, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 8),
                  Text(
                    'Import a lecture and it becomes a scrollable\nfeed of topic & problem reels.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 14, height: 1.5, color: cs.onSurfaceVariant),
                  ),
                  const SizedBox(height: 24),
                  if (widget.onImportTap != null)
                    SizedBox(
                      width: 240,
                      child: GoldButton(
                        label: 'Import a lecture',
                        icon: Icons.add,
                        onPressed: widget.onImportTap,
                      ),
                    ),
                ]),
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
