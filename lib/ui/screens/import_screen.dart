import 'package:flutter/material.dart';

import '../../data/services/video_import_service.dart';

/// Import a lecture video: local file now (stub), YouTube via yt-dlp later.
class ImportScreen extends StatelessWidget {
  const ImportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final importer = VideoImportService();
    return Scaffold(
      appBar: AppBar(title: const Text('Import lecture')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ElevatedButton.icon(
              icon: const Icon(Icons.file_open),
              label: const Text('Pick a video file'),
              onPressed: () async {
                final path = await importer.pickLocalVideo();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(path == null
                          ? 'File picker is not wired yet (phase 1 stub).'
                          : 'Picked: $path'),
                    ),
                  );
                }
              },
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              icon: const Icon(Icons.youtube_searched_for),
              label: const Text('Import from YouTube (planned)'),
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                        'YouTube import via yt-dlp is planned after phase 1.'),
                  ),
                );
              },
            ),
            const SizedBox(height: 24),
            const Text(
              'Pipeline (all on-device):\n'
              '1. Import video\n'
              '2. Transcribe (whisper.cpp — phase 2)\n'
              '3. Segment into topic/problem reels with the tiny LLM\n'
              '4. Swipe through reels; everything stays on your phone.',
              style: TextStyle(color: Colors.white70),
            ),
          ],
        ),
      ),
    );
  }
}
