import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Shown on startup when the on-device LLM bundle is not installed.
/// Displays the exact expected path and the one-time install steps.
class ModelMissingScreen extends StatelessWidget {
  final String expectedPath;
  final VoidCallback onRecheck;

  const ModelMissingScreen({
    super.key,
    required this.expectedPath,
    required this.onRecheck,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('StudyReels')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.psychology_outlined, size: 64),
            const SizedBox(height: 16),
            const Text(
              'Model not found on this device',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            const Text(
              'StudyReels runs 100% on-device, so the tiny LLM bundle '
              'must be installed once from your computer. Expected at:',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            GestureDetector(
              onTap: () => Clipboard.setData(
                  ClipboardData(text: expectedPath)),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white10,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  expectedPath,
                  style: const TextStyle(fontFamily: 'monospace'),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Install steps (one time):\n'
              '1. ./scripts/download_model.sh\n'
              '2. ./scripts/push_model.sh <bundle-dir>\n'
              '3. Tap Recheck below.',
              style: TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              icon: const Icon(Icons.refresh),
              label: const Text('Recheck'),
              onPressed: onRecheck,
            ),
          ],
        ),
      ),
    );
  }
}
