import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';

import '../../data/services/library_store.dart';
import '../../data/services/model_store.dart';
import '../../data/services/reel_pipeline.dart';
import '../../data/services/video_import_service.dart';

/// Import a lecture video, then run the full on-device pipeline:
/// transcribe -> chunk -> segment into topic/problem reels -> save to library.
/// YouTube import via yt-dlp is planned later.
class ImportScreen extends StatefulWidget {
  final VoidCallback onDone;

  const ImportScreen({super.key, required this.onDone});

  @override
  State<ImportScreen> createState() => _ImportScreenState();
}

class _ImportScreenState extends State<ImportScreen> {
  final _chapterController = TextEditingController();
  final _importer = VideoImportService();
  String? _videoPath;
  bool _running = false;
  String _stage = '';
  String? _error;

  @override
  void dispose() {
    _chapterController.dispose();
    super.dispose();
  }

  Future<void> _pick() async {
    final path = await _importer.pickLocalVideo();
    if (!mounted) return;
    setState(() {
      _videoPath = path;
      _error = null;
    });
  }

  Future<void> _run() async {
    final videoPath = _videoPath;
    final chapterName = _chapterController.text.trim();
    if (videoPath == null) {
      setState(() => _error = 'Pick a video file first.');
      return;
    }
    if (chapterName.isEmpty) {
      setState(() => _error = 'Enter a chapter/topic name first.');
      return;
    }
    setState(() {
      _running = true;
      _error = null;
      _stage = 'Starting…';
    });
    try {
      final docs = await getApplicationDocumentsDirectory();
      final whisperDir = ModelStore.expectedWhisperPath(docs.path);
      if (!await ModelStore.isWhisperPresent(docs.path)) {
        throw const PipelineException(
            'Whisper model missing. Run scripts/download_transcriber.sh then '
            './scripts/push_model.sh <bundle-dir> whisper-base');
      }
      final template = await rootBundle
          .loadString('assets/prompts/segmentation_prompt.md');
      final pipeline = ReelPipeline(
        library: context.read<LibraryStore>(),
        whisperModelDir: whisperDir,
        llmModelDir: ModelStore.expectedModelPath(docs.path),
        promptTemplate: template,
      );
      final chapter = await pipeline.run(
        videoPath: videoPath,
        chapterName: chapterName,
        onProgress: (s) => mounted ? setState(() => _stage = s) : null,
      );
      if (!mounted) return;
      setState(() {
        _running = false;
        _stage = '';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(
                'Saved ${chapter.reels.length} reels to "${chapter.name}"')),
      );
      widget.onDone();
    } on PipelineException catch (e) {
      if (mounted) {
        setState(() {
          _running = false;
          _error = e.message;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _running = false;
          _error = e.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Import lecture')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _chapterController,
              enabled: !_running,
              decoration: const InputDecoration(
                labelText: 'Chapter / topic name',
                hintText: 'e.g. Physics · Rotational Mechanics',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              icon: const Icon(Icons.file_open),
              label: Text(_videoPath == null
                  ? 'Pick a video file'
                  : 'Picked: ${_short(_videoPath!)}'),
              onPressed: _running ? null : _pick,
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              icon: const Icon(Icons.auto_awesome),
              label: const Text('Transcribe & make reels'),
              onPressed: _running ? null : _run,
            ),
            if (_running) ...[
              const SizedBox(height: 24),
              const Center(child: CircularProgressIndicator()),
              const SizedBox(height: 12),
              Text(_stage, textAlign: TextAlign.center),
              const SizedBox(height: 8),
              const Text(
                'On-device: transcription can take several minutes for a long lecture. Keep the app open.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white54, fontSize: 12),
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 16),
              Text(_error!,
                  style: const TextStyle(color: Colors.redAccent)),
            ],
            const Spacer(),
            const Text(
              'Pipeline (all on-device, no internet):\n'
              '1. Extract audio from the video\n'
              '2. Transcribe with whisper-base (background isolate)\n'
              '3. Split into 1.2K–2K token chunks\n'
              '4. Tiny LLM finds topic/problem boundaries\n'
              '5. Reels saved to your library by chapter',
              style: TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  String _short(String path) {
    final parts = path.split('/');
    return parts.length > 2
        ? '…/${parts.sublist(parts.length - 2).join('/')}'
        : path;
  }
}
