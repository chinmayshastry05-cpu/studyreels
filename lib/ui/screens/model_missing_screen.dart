import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

import '../../data/services/model_downloader.dart';

/// Shown on startup when the on-device model bundles are not installed.
/// Offers a one-time in-app download (Wi-Fi recommended); after that the app
/// runs 100% on-device. Adb push from a computer still works - Recheck picks
/// it up.
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

  static String _mb(int bytes) => (bytes / (1024 * 1024)).toStringAsFixed(0);

  Future<void> _download() async {
    setState(() {
      _busy = true;
      _error = null;
      _received = 0;
    });
    try {
      final docs = await getApplicationDocumentsDirectory();
      final downloader = ModelDownloader(docs.path);
      await downloader.ensureInstalled((phase, label, received, total) {
        if (!mounted) return;
        setState(() {
          _phase = phase;
          _label = label;
          _received = received;
          _total = total;
        });
      });
      widget.onRecheck();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = e.toString();
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
        return 'Unpacking $_label (can take a minute)';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('StudyReels')),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.psychology_outlined, size: 64),
            const SizedBox(height: 16),
            const Text(
              'Models not found on this device',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            if (!_busy && _error == null) ...[
              Text(
                'StudyReels runs 100% on-device. Download the tiny language '
                'model and speech model once (${_mb(totalDownloadBytes)} MB '
                'total, Wi-Fi recommended) - after that no internet is needed.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              GestureDetector(
                onTap: () =>
                    Clipboard.setData(ClipboardData(text: widget.expectedPath)),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white10,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    widget.expectedPath,
                    style: const TextStyle(fontFamily: 'monospace'),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                icon: const Icon(Icons.download),
                label: Text('Download models (${_mb(totalDownloadBytes)} MB)'),
                onPressed: _download,
              ),
              const SizedBox(height: 8),
              TextButton.icon(
                icon: const Icon(Icons.refresh),
                label: const Text('Recheck'),
                onPressed: widget.onRecheck,
              ),
            ],
            if (_busy) ...[
              Text(_phaseText, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              LinearProgressIndicator(
                value: _total > 0 ? _received / _total : null,
              ),
              const SizedBox(height: 8),
              Text(
                '${_mb(_received)} / ${_mb(_total)} MB - keep the app open',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70),
              ),
            ],
            if (_error != null) ...[
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.redAccent),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
                onPressed: _download,
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: widget.onRecheck,
                child: const Text('Recheck'),
              ),
            ],
          ],
        ),
      ),
            ),
          ),
        ),
      ),
    );
  }
}
