import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';

import '../../data/models/chapter.dart';
import '../../data/services/library_store.dart';
import '../../data/services/model_store.dart';
import '../../data/services/reel_pipeline.dart';
import '../../data/services/video_import_service.dart';
import '../widgets/fx.dart';

/// One tap: pick a lecture video, the on-device AI does the rest -
/// transcribes, finds topics & worked problems, names the chapter, cuts the
/// reels and files them in the library. No typing needed.
typedef PipelineRunner = Future<Chapter> Function({
  required String videoPath,
  required void Function(String stage) onProgress,
});

class ImportScreen extends StatefulWidget {
  final VoidCallback onDone;

  /// Injectable for tests/screenshots; defaults to the real pipeline.
  final PipelineRunner? runner;

  /// Injectable for tests; defaults to the real video import service.
  final VideoImportService? importer;

  const ImportScreen({super.key, required this.onDone, this.runner, this.importer});

  @override
  State<ImportScreen> createState() => _ImportScreenState();
}

class _ImportScreenState extends State<ImportScreen>
    with WidgetsBindingObserver {
  late final VideoImportService _importer;
  String? _videoPath;
  bool _running = false;
  String _stage = '';
  String? _error;
  String _version = '';

  @override
  void initState() {
    super.initState();
    _importer = widget.importer ?? VideoImportService();
    WidgetsBinding.instance.addObserver(this);
    // Tests and odd devices have no plugin channel: leave the footer
    // hidden rather than crash the screen.
    PackageInfo.fromPlatform().then((info) {
      if (!mounted) return;
      setState(() {
        _version = 'v${info.version} (${info.buildNumber})'
            '${kDebugMode ? ' debug' : ''}';
      });
    }).catchError((_) {});
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Returning from the system picker: if Android destroyed the
    // MainActivity while the picker was open, the picked file sits in
    // the plugin cache and the original pick future never completes.
    // Recover it so Done -> import starts, with no second tap.
    if (state == AppLifecycleState.resumed) {
      _recoverAfterResume();
    }
  }

  /// One recovery attempt per resume, retried a few times: the plugin
  /// writes its cache on a background executor, so the picked path may
  /// land just after resume fires.
  Future<void> _recoverAfterResume() async {
    for (var attempt = 0; attempt < 3; attempt++) {
      if (!mounted || _running) return;
      final path = await _importer.recoverLostVideo();
      if (path != null) {
        await _runPipeline(path);
        return;
      }
      if (attempt < 2) {
        await Future.delayed(const Duration(milliseconds: 300));
      }
    }
  }

  Future<Chapter> _defaultRunner({
    required String videoPath,
    required void Function(String stage) onProgress,
  }) async {
    final docs = await getApplicationDocumentsDirectory();
    final whisperDir = ModelStore.expectedWhisperPath(docs.path);
    if (!await ModelStore.isWhisperPresent(docs.path)) {
      throw const PipelineException(
          'Speech model missing. Restart the app - the startup screen will '
          'offer to re-download it.');
    }
    final template = await rootBundle
        .loadString('assets/prompts/segmentation_prompt.md');
    final pipeline = ReelPipeline(
      library: context.read<LibraryStore>(),
      whisperModelDir: whisperDir,
      llmModelDir: ModelStore.expectedModelPath(docs.path),
      promptTemplate: template,
    );
    return pipeline.run(videoPath: videoPath, onProgress: onProgress);
  }

  Future<void> _pickAndRun() async {
    // A pick lost to MainActivity destruction may already sit in the
    // plugin cache (e.g. the user tapped Pick again after Done did
    // nothing): use it without opening the picker a second time.
    final recovered = await _importer.recoverLostVideo();
    if (recovered != null) {
      await _runPipeline(recovered);
      return;
    }
    final path = await _importer.pickLocalVideo();
    if (!mounted) return;
    if (path == null) {
      // The pick future completed with nothing: the result may still
      // have landed in the plugin cache after the pick returned.
      final lost = await _importer.recoverLostVideo();
      if (lost != null) {
        await _runPipeline(lost);
      }
      return;
    }
    await _runPipeline(path);
  }

  Future<void> _runPipeline(String path) async {
    if (!mounted || _running) return;
    setState(() {
      _videoPath = path;
      _error = null;
      _running = true;
      _stage = 'Starting…';
    });
    try {
      final runner = widget.runner ?? _defaultRunner;
      final chapter = await runner(
        videoPath: path,
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
      _fail(e.message);
    } catch (e) {
      _fail(e.toString());
    }
  }

  void _fail(String message) {
    if (!mounted) return;
    setState(() {
      _running = false;
      _error = message;
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Import')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: [
          if (!_running) ...[
            GlowCard(
              margin: EdgeInsets.zero,
              padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
              onTap: _pickAndRun,
              child: Column(children: [
                const GoldIconBadge(Icons.video_file_outlined, size: 64),
                const SizedBox(height: 16),
                Text(
                  _videoPath == null && _error == null
                      ? 'Pick a lecture video'
                      : 'Pick another video',
                  style: const TextStyle(
                      fontSize: 20, fontWeight: FontWeight.w800),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 6),
                Text(
                  'AI finds the topics, cuts the reels\nand files them - automatically',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 14, height: 1.4, color: cs.onSurfaceVariant),
                ),
              ]),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              _ErrorCard(
                  message: _error!, file: _videoPath, onRetry: _pickAndRun),
            ],
          ],
          if (_running) ...[
            GlowCard(
              animate: true,
              margin: EdgeInsets.zero,
              padding: const EdgeInsets.all(20),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(children: [
                      const GoldIconBadge(Icons.auto_awesome, size: 44),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _short(_videoPath ?? ''),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ]),
                    const SizedBox(height: 18),
                    const BeamProgress(),
                    const SizedBox(height: 12),
                    Text(_stage,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    Text(
                      'Runs fully on-device. Long lectures can take several minutes - keep the app open.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 12.5, color: cs.onSurfaceVariant),
                    ),
                  ]),
            ),
          ],
          const SizedBox(height: 20),
          if (_version.isNotEmpty)
            Text(_version,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
        ],
      ),
    );
  }

  String _short(String path) {
    final parts = path.split('/');
    return parts.isEmpty ? path : parts.last;
  }
}

class _ErrorCard extends StatelessWidget {
  final String message;
  final String? file;
  final VoidCallback onRetry;
  const _ErrorCard(
      {required this.message, required this.file, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.error.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: cs.error.withValues(alpha: 0.35)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.error_outline, color: cs.error, size: 20),
          const SizedBox(width: 8),
          Text('Import failed',
              style: TextStyle(
                  fontWeight: FontWeight.w800, color: cs.error)),
        ]),
        if (file != null) ...[
          const SizedBox(height: 6),
          Text(file!.split('/').last,
              style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
        ],
        const SizedBox(height: 6),
        Text(message, style: TextStyle(fontSize: 13, color: cs.error)),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.gold,
              side: BorderSide(color: AppColors.gold.withValues(alpha: 0.6)),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
            onPressed: onRetry,
            icon: const Icon(Icons.refresh, size: 18),
            label: const Text('Try again'),
          ),
        ),
      ]),
    );
  }
}
