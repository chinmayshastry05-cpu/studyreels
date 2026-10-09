import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:studyreels/data/services/audio_extractor.dart';
import 'package:studyreels/data/services/reel_exporter.dart';
import 'package:studyreels/main.dart' as app;

/// On-device integration tests. Run with:
///   flutter test integration_test
///     --dart-define=TEST_VIDEO_PATH=/sdcard/test_video.mp4
///
/// What this proves: the app launches, the model-missing gate works, the
/// native audio-extraction path produces a valid WAV, and the reel-export
/// path writes a clip to MediaStore — all on a real Android runtime.
///
/// What this does NOT prove: Cactus/Qwen inference speed or quality (no
/// model is installed on the emulator), or the system gallery-picker UI
/// (a separate OS activity, not drivable from flutter_test).
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  const testVideoPath =
      String.fromEnvironment('TEST_VIDEO_PATH', defaultValue: '');

  group('emulator integration', () {
    testWidgets('launch shows the model-missing screen', (tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 5));
      expect(find.text('Model not found on this device'), findsOneWidget);
      expect(find.textContaining('qwen3-0.6b-int4'), findsOneWidget);
    });

    testWidgets('audio extraction produces a valid WAV', (tester) async {
      expect(testVideoPath, isNotEmpty,
          reason: 'Pass --dart-define=TEST_VIDEO_PATH=<device path>');
      final wavPath = await AudioExtractor.extractWav(testVideoPath);
      final wav = File(wavPath);
      expect(await wav.exists(), isTrue);
      final bytes = await wav.readAsBytes();
      // RIFF/WAVE header + fmt chunk: minimal validity check.
      expect(bytes.length, greaterThan(44));
      expect(String.fromCharCodes(bytes.sublist(0, 4)), 'RIFF');
      expect(String.fromCharCodes(bytes.sublist(8, 12)), 'WAVE');
      await wav.delete();
    });

    testWidgets('reel export saves a clip to MediaStore', (tester) async {
      expect(testVideoPath, isNotEmpty,
          reason: 'Pass --dart-define=TEST_VIDEO_PATH=<device path>');
      final uri = await ReelExporter.exportClip(
        videoPath: testVideoPath,
        startSec: 0.5,
        endSec: 3.5,
      );
      expect(uri.startsWith('content://media/'), isTrue,
          reason: 'Expected a MediaStore URI, got: $uri');
    });
  });
}
