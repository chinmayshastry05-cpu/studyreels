import 'dart:async';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import '../../data/services/model_downloader.dart';
import '../../data/services/system_bridge.dart';
import '../widgets/fx.dart';

/// Shown on startup when the on-device model bundles are not installed.
/// One-time download under an Android foreground service with a progress
/// notification, so it keeps going when the app is backgrounded or the
/// screen is off. Resumable: a killed download continues from its .part
/// file the next time the app opens.
class ModelMissingScreen extends StatefulWidget {
  final String expectedPath;
  final VoidCallback onRecheck;

  const ModelMissingScreen({
    super.key,
    required this.expectedPath,
    required this.onRecheck,
  });

  @override
  State<ModelMissingScreen> createState() => _ModelMissingScreenState();
}

class _ModelMissingScreenState extends State<ModelMissingScreen> {
  bool _busy = false;
  DownloadPhase _phase = DownloadPhase.downloading;
  String _label = '';
  int _received = 0;
  int _total = totalDownloadBytes;
  String? _error;

  // speed / ETA
  final Stopwatch _clock = Stopwatch();
  int _speedMark = 0;
  int _speedMarkMs = 0;
  double _bps = 0;
  int _lastNotifMs = 0;

  static String _mb(int bytes) => (bytes / (1024 * 1024)).toStringAsFixed(0);

  @override
  void initState() {
    super.initState();
    _resumeIfPartial();
  }

  /// A download that was interrupted (app killed) resumes automatically.
  Future<void> _resumeIfPartial() async {
    try {
      final docs = await getApplicationDocumentsDirectory();
      final left = await ModelDownloader(docs.path).remainingBytes();
      if (left < totalDownloadBytes && left > 0 && mounted && !_busy) {
        _download();
      }
    } catch (_) {}
  }

  String _fmtEta(double secs) {
    if (secs.isNaN || secs.isInfinite || secs < 0) return '--:--';
    final s = secs.round();
    return '${(s ~/ 60).toString().padLeft(2, '0')}:${(s % 60).toString().padLeft(2, '0')}';
  }

  void _onProgress(DownloadPhase phase, String label, int received, int total) {
    if (!mounted) return;
    final ms = _clock.elapsedMilliseconds;
    if (phase == DownloadPhase.downloading && ms - _speedMarkMs >= 1000) {
      final inst = (received - _speedMark) * 1000 / (ms - _speedMarkMs);
      _bps = _bps == 0 ? inst : _bps * 0.7 + inst * 0.3;
      _speedMark = received;
      _speedMarkMs = ms;
    }
    setState(() {
      _phase = phase;
      _label = label;
      _received = received;
      _total = total;
    });
    if (ms - _lastNotifMs >= 1000) {
      _lastNotifMs = ms;
      final pct = total > 0 ? (received * 100 ~/ total) : -1;
      final speed = _bps > 0
          ? ' - ${(_bps / (1024 * 1024)).toStringAsFixed(1)} MB/s'
          : '';
      final text = phase == DownloadPhase.downloading
          ? '$pct% (${_mb(received)}/${_mb(total)} MB)$speed'
          : (phase == DownloadPhase.verifying ? 'Verifying...' : 'Unpacking...');
      SystemBridge.updateDownloadService(
          'Downloading StudyReels models', text, pct);
    }
  }

  Future<void> _download() async {
    setState(() {
      _busy = true;
      _error = null;
      _received = 0;
      _bps = 0;
      _speedMark = 0;
      _speedMarkMs = 0;
    });
    _clock
      ..reset()
      ..start();
    await SystemBridge.requestPermissions();
    await SystemBridge.startDownloadService(
        'Downloading StudyReels models', 'Starting...');
    try {
      final docs = await getApplicationDocumentsDirectory();
      final downloader = ModelDownloader(docs.path);
      await downloader.ensureInstalled(_onProgress, onLog: (_) {});
      await SystemBridge.stopDownloadService();
      await SystemBridge.notifyDone('StudyReels is ready',
          'Models downloaded and installed. Tap to open.', true);
      widget.onRecheck();
    } catch (e) {
      await SystemBridge.stopDownloadService();
      await SystemBridge.notifyDone('Model download stopped',
          'Open StudyReels and tap Retry - it resumes.', false);
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = ModelDownloader.sanitizeError(e);
      });
    }
  }

  String get _phaseText {
    switch (_phase) {
      case DownloadPhase.downloading:
        return 'Downloading $_label';
      case DownloadPhase.verifying:
        return 'Verifying $_label';
      case DownloadPhase.extracting:
        return 'Unpacking $_label';
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final frac = _total > 0 ? (_received / _total).clamp(0.0, 1.0) : 0.0;
    final pct = (frac * 100).round();
    final speed = _bps > 0
        ? '${(_bps / (1024 * 1024)).toStringAsFixed(1)} MB/s'
        : '--';
    final eta = _bps > 0 && _phase == DownloadPhase.downloading
        ? _fmtEta((_total - _received) / _bps)
        : '--:--';
    return Scaffold(
      body: AmbientBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Spacer(),
                const GoldIconBadge(Icons.psychology_outlined, size: 76),
                const SizedBox(height: 22),
                Text('One-time setup',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.4,
                        color: cs.onSurface)),
                const SizedBox(height: 10),
                if (!_busy) ...[
                  Text(
                    'StudyReels runs 100% on-device. Download the AI models '
                    'once (${_mb(totalDownloadBytes)} MB, Wi-Fi recommended) - '
                    'after that, no internet at all.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 14, height: 1.5, color: cs.onSurfaceVariant),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: cs.error.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                            color: cs.error.withValues(alpha: 0.35)),
                      ),
                      child: Text(_error!,
                          maxLines: 4,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 13, color: cs.error)),
                    ),
                  ],
                ],
                if (_busy) ...[
                  const SizedBox(height: 6),
                  Text(_phaseText,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 18),
                  BeamProgress(value: frac),
                  const SizedBox(height: 12),
                  Text(
                    '$pct%  ·  ${_mb(_received)}/${_mb(_total)} MB  ·  $speed  ·  ETA $eta',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: cs.onSurfaceVariant),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Safe to leave the app - progress shows in a notification.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                  ),
                ],
                const Spacer(),
                if (!_busy)
                  GoldButton(
                    label: _error != null
                        ? 'Resume download'
                        : 'Download models (${_mb(totalDownloadBytes)} MB)',
                    icon: Icons.download_outlined,
                    onPressed: _download,
                  ),
                const SizedBox(height: 10),
                if (!_busy)
                  TextButton(
                    onPressed: widget.onRecheck,
                    child: const Text('I already have the models',
                        style: TextStyle(
                            color: AppColors.gold,
                            fontWeight: FontWeight.w700)),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
