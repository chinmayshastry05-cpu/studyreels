import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:studyreels/data/services/audio_extractor.dart';
import 'package:studyreels/data/services/reel_exporter.dart';
import 'package:studyreels/main.dart' as app;

/// On-device integration tests. Run with:
///   flutter test integration_test
///     --dart-define=TEST_VIDEO_PATH=/data/local/tmp/test_video.mp4
///
/// Every test fails fast instead of hanging: the startup screen shows an
/// endlessly-animating CircularProgressIndicator, so pumpAndSettle() would
/// never settle on its own — poll with bounded pumps instead. Native
/// channel calls (MediaExtractor/MediaCodec/MediaMuxer) get explicit
/// timeouts because a stuck codec would otherwise block forever.
///
/// What this proves: the app launches, the model-missing gate works, the
/// native audio-extraction path yields a valid WAV, the reel-export path
/// writes a MediaStore clip — on a real Android runtime.
///
/// What this does NOT prove: Cactus/Qwen inference speed or quality (no
/// model bundle is installed on the emulator), real Snapdragon 7 Gen 1
/// performance, or the OS gallery-picker UI (a separate activity, not
/// drivable from flutter_test).
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  const testVideoPath =
      String.fromEnvironment('TEST_VIDEO_PATH', defaultValue: '');
  const perTestTimeout = Timeout(Duration(minutes: 3));

  group('emulator integration', () {
    testWidgets('launch shows the model-missing screen', (tester) async {
      app.main();
      // Bounded poll: the startup CircularProgressIndicator animates
      // forever, so pumpAndSettle() can never return while it is up.
      const deadline = Duration(seconds: 30);
      final stopwatch = Stopwatch()..start();
      while (stopwatch.elapsed < deadline) {
        await tester.pump(const Duration(milliseconds: 500));
        if (find
            .text('Model not found on this device')
            .evaluate()
            .isNotEmpty) {
          break;
        }
      }
      expect(
        find.text('Model not found on this device'),
        findsOneWidget,
        reason: 'model-missing screen did not appear within $deadline '
            '(startup future may be stuck)',
      );
      expect(find.textContaining('qwen3-0.6b-int4'), findsOneWidget);
    }, timeout: perTestTimeout);

    testWidgets('audio extraction produces a valid WAV', (tester) async {
      expect(testVideoPath, isNotEmpty,
          reason: 'Pass --dart-define=TEST_VIDEO_PATH=<device path>');
      late final String wavPath;
      try {
        wavPath = await AudioExtractor.extractWav(testVideoPath).timeout(
          const Duration(minutes: 2),
          onTimeout: () => throw TimeoutException(
              'extractWav did not return within 2 minutes for '
              '$testVideoPath (MediaCodec may be stuck)'),
        );
      } on TimeoutException catch (e) {
        fail(e.message ?? 'audio extraction timed out');
      }
      final wav = File(wavPath);
      expect(await wav.exists(), isTrue,
          reason: 'extractWav returned a path that does not exist: $wavPath');
      final bytes = await wav.readAsBytes();
      // RIFF/WAVE header + fmt chunk: minimal validity check.
      expect(bytes.length, greaterThan(44));
      expect(String.fromCharCodes(bytes.sublist(0, 4)), 'RIFF');
      expect(String.fromCharCodes(bytes.sublist(8, 12)), 'WAVE');
      await wav.delete();
    }, timeout: perTestTimeout);

    testWidgets('reel export saves a clip to MediaStore', (tester) async {
      expect(testVideoPath, isNotEmpty,
          reason: 'Pass --dart-define=TEST_VIDEO_PATH=<device path>');
      late final String uri;
      try {
        uri = await ReelExporter.exportClip(
          videoPath: testVideoPath,
          startSec: 0.5,
          endSec: 3.5,
        ).timeout(
          const Duration(minutes: 2),
          onTimeout: () => throw TimeoutException(
              'exportClip did not return within 2 minutes '
              '(MediaMuxer may be stuck)'),
        );
      } on TimeoutException catch (e) {
        fail(e.message ?? 'reel export timed out');
      }
      expect(uri.startsWith('content://media/'), isTrue,
          reason: 'Expected a MediaStore URI, got: $uri');
    }, timeout: perTestTimeout);
  });
}
