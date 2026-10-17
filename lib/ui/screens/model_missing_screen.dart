import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

import '../../data/services/model_downloader.dart';
import '../../data/services/system_bridge.dart';

const _green = Color(0xFF39FF14);
const _dim = Color(0xFF7CB77C);

/// Shown on startup when the on-device model bundles are not installed.
/// Terminal-style one-time download. Runs under an Android foreground
/// service with a progress notification, so it keeps going when the app is
/// backgrounded or the screen is off. Resumable: a killed download continues
/// from its .part file the next time the app opens.
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
  int _received = 0;
  int _total = totalDownloadBytes;
  String? _error;
  final List<String> _lines = [];
  final ScrollController _scroll = ScrollController();

  // speed / ETA
  final Stopwatch _clock = Stopwatch();
  int _speedMark = 0;
  int _speedMarkMs = 0;
  double _bps = 0;
  int _lastLogMb = -1;
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
        _addLine('resuming interrupted download ...');
        _download();
      }
    } catch (_) {}
  }

  void _addLine(String s) {
    if (!mounted) return;
    setState(() {
      _lines.add(s);
      if (_lines.length > 300) _lines.removeRange(0, _lines.length - 300);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.jumpTo(_scroll.position.maxScrollExtent);
      }
    });
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
    final mbNow = received ~/ (25 * 1024 * 1024);
    if (phase == DownloadPhase.downloading && mbNow != _lastLogMb) {
      _lastLogMb = mbNow;
      _addLine('Get:1 $label  ${_mb(received)}/${_mb(total)} MB');
    }
    if (_phase != phase) {
      _addLine(phase == DownloadPhase.verifying
          ? 'Verifying $label ...'
          : 'Unpacking $label ...');
    }
    setState(() {
      _phase = phase;
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
      SystemBridge.updateDownloadService('Downloading StudyReels models', text, pct);
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
    _addLine('\$ studyreels-models --install');
    await SystemBridge.requestPermissions();
    await SystemBridge.startDownloadService(
        'Downloading StudyReels models', 'Starting...');
    try {
      final docs = await getApplicationDocumentsDirectory();
      final downloader = ModelDownloader(docs.path);
      await downloader.ensureInstalled(_onProgress, onLog: _addLine);
      _addLine('Done. Models installed.');
      await SystemBridge.stopDownloadService();
      await SystemBridge.notifyDone('StudyReels is ready',
          'Models downloaded and installed. Tap to open.', true);
      widget.onRecheck();
    } catch (e) {
      await SystemBridge.stopDownloadService();
      await SystemBridge.notifyDone('Model download stopped',
          'Open StudyReels and tap Retry - it resumes.', false);
      if (!mounted) return;
      _addLine('E: ${ModelDownloader.sanitizeError(e)}');
      setState(() {
        _busy = false;
        _error = ModelDownloader.sanitizeError(e);
      });
    }
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Widget _bar() {
    final frac = _total > 0 ? (_received / _total).clamp(0.0, 1.0) : 0.0;
    const width = 24;
    final filled = (frac * width).round();
    final bar = '#' * filled + '.' * (width - filled);
    final pct = (frac * 100).toStringAsFixed(0).padLeft(3);
    final speed = _bps > 0
        ? '${(_bps / (1024 * 1024)).toStringAsFixed(1)} MB/s'
        : '-- MB/s';
    final eta = _bps > 0 && _phase == DownloadPhase.downloading
        ? _fmtEta((_total - _received) / _bps)
        : '--:--';
    return Text('[$bar] $pct%\n${_mb(_received)}/${_mb(_total)} MB  $speed  ETA $eta',
        style: const TextStyle(
            fontFamily: 'monospace', color: _green, fontSize: 13, height: 1.4));
  }

  @override
  Widget build(BuildContext context) {
    const mono = TextStyle(fontFamily: 'monospace', color: _green, fontSize: 12.5);
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('studyreels@device:~\$ setup',
                  style: TextStyle(
                      fontFamily: 'monospace',
                      color: _green,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              const Text('Models not found on this device',
                  style: TextStyle(fontFamily: 'monospace', color: Colors.amber)),
              const SizedBox(height: 10),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    border: Border.all(color: _green.withValues(alpha: 0.4)),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: _lines.isEmpty
                      ? SingleChildScrollView(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                  'StudyReels runs 100% on-device. Download the tiny '
                                  'language model and speech model once '
                                  '(${_mb(totalDownloadBytes)} MB total, Wi-Fi '
                                  'recommended). Keeps going in the background.',
                                  style: mono.copyWith(color: _dim)),
                              const SizedBox(height: 12),
                              GestureDetector(
                                onTap: () => Clipboard.setData(
                                    ClipboardData(text: widget.expectedPath)),
                                child: Text(widget.expectedPath,
                                    style: mono.copyWith(color: Colors.white38)),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          controller: _scroll,
                          itemCount: _lines.length,
                          itemBuilder: (_, i) => Text(_lines[i],
                              style: mono, softWrap: false,
                              overflow: TextOverflow.ellipsis),
                        ),
                ),
              ),
              const SizedBox(height: 12),
              if (_busy) _bar(),
              if (_error != null)
                Text(_error!,
                    style: const TextStyle(
                        fontFamily: 'monospace', color: Colors.redAccent),
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis),
              const SizedBox(height: 10),
              if (!_busy)
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                      backgroundColor: _green, foregroundColor: Colors.black),
                  onPressed: _download,
                  child: Text(_error != null
                      ? 'Retry'
                      : 'Download models (${_mb(totalDownloadBytes)} MB)'),
                ),
              if (!_busy)
                TextButton(
                  onPressed: widget.onRecheck,
                  child: const Text('Recheck', style: TextStyle(color: _dim)),
                ),
              if (_busy)
                const Text('Safe to leave the app - see notification.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontFamily: 'monospace', color: _dim, fontSize: 12)),
            ],
          ),
        ),
      ),
    );
  }
}
