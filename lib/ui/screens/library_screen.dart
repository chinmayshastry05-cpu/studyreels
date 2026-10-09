import 'package:flutter/material.dart';

/// Saved reels organized by chapter/topic. Phase 1: placeholder content;
/// backed by LibraryStore once import + segmentation are wired.
class LibraryScreen extends StatelessWidget {
  const LibraryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Library')),
      body: const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Your saved reels will appear here, organized by chapter and topic.\n\n'
            'Import a lecture video to get started.',
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}
