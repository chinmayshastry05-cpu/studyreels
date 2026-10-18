// ignore_for_file: avoid_print
// Progress logging is intentional here: the CI emulator job reads it from
// the `--reporter expanded` output.

import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:studyreels/data/services/library_store.dart';
import 'package:studyreels/data/services/llm_service.dart';
import 'package:studyreels/data/services/reel_pipeline.dart';
import 'package:studyreels/data/services/transcription_service.dart';

/// END-TO-END proof with the REAL model bundles on a real Android runtime:
/// engine init -> whisper transcription -> Qwen segmentation -> library.
///
/// Setup (once, from the dev machine):
///   unzip qwen3-0.6b-int4.zip -d /tmp/models/qwen3-0.6b-int4
///   unzip whisper-base-int4.zip -d /tmp/models/whisper-base
///   adb push /tmp/models /data/local/tmp/models
///   adb shell chmod -R a+rX /data/local/tmp/models
///   adb push <a clean 30-60s speech clip> /data/local/tmp/e2e_lecture.mp4
///
/// Run (engine .so staged in android/app/src/main/jniLibs/arm64-v8a first,
/// same as the release flow):
///   ORG_GRADLE_PROJECT_targetAbi=arm64-v8a \
///   flutter test integration_test/e2e_import_test.dart --reporter expanded
///
/// The clip is 30-60s of clean English narration (a trimmed window of the
/// Mike Matas TED talk, CI trims it with ffmpeg): short enough to keep
/// the emulator run fast, clean enough that transcript quality is a real
/// signal. A long TED clip once passed with two comma-only segments and
/// broke segmentation downstream, so the whisper test now also requires
/// at least one segment with real words. The raised 4K context size is
/// NOT exercised by this short clip; that proof lives in the QEMU
/// engine tests (long-context recall), not here.
///
/// `flutter test` needs INTERNET for its localhost VM-service socket; the
/// product ships without it. Generate the throwaway debug manifest exactly
/// like CI does (android/app/src/debug/AndroidManifest.xml with
/// uses-permission INTERNET) — it is never committed, never in releases.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  const llmDir = String.fromEnvironment('E2E_LLM_DIR',
      defaultValue: '/data/local/tmp/models/qwen3-0.6b-int4');
  const whisperDir = String.fromEnvironment('E2E_WHISPER_DIR',
      defaultValue: '/data/local/tmp/models/whisper-base');
  const videoPath = String.fromEnvironment('E2E_VIDEO_PATH',
      defaultValue: '/data/local/tmp/e2e_lecture.mp4');

  group('end-to-end import with real models', () {
    test('qwen3 bundle loads via cactus_init and generates', () async {
      expect(File('$llmDir/config.txt').existsSync(), isTrue,
          reason: 'LLM bundle not at $llmDir - see setup steps in this file');
      final llm = CactusLlmBackend();
      try {
        final sw = Stopwatch()..start();
        await llm.init(llmDir);
        print('E2E: cactus_init OK in ${sw.elapsed}');
        expect(await llm.isReady, isTrue);
        final text = await llm.generate(
            'Reply with exactly the word: ok',
            maxTokens: 32);
        print('E2E: first generation in ${sw.elapsed}: "$text"');
        expect(text.trim(), isNotEmpty);
      } finally {
        await llm.dispose();
      }
    }, timeout: const Timeout(Duration(minutes: 20)));

    test('whisper bundle transcribes a real clip', () async {
      expect(File('$whisperDir/config.txt').existsSync(), isTrue,
          reason:
              'Whisper bundle not at $whisperDir - see setup steps in this file');
      expect(File(videoPath).existsSync(), isTrue,
          reason: 'Test clip not at $videoPath - see setup steps in this file');
      final sw = Stopwatch()..start();
      final transcript = await transcribeVideoInBackground(
        videoPath: videoPath,
        whisperModelDir: whisperDir,
        onProgress: (s) => print('E2E: $s'),
      );
      print('E2E: transcription in ${sw.elapsed}: '
          '${transcript.length} segments');
      for (final t in transcript.take(5)) {
        print('E2E:   [${t.start}-${t.end}] ${t.text}');
      }
      expect(transcript, isNotEmpty,
          reason: 'whisper returned no segments - wrong clip (needs real '
              'speech) or the whisper/vad bundle is broken');
      // Transcript-quality gate: a clean-speech clip must yield real
      // words, not just punctuation noise. (A long TED clip once passed
      // isNotEmpty with two comma-only segments; that masked a useless
      // transcript and broke the pipeline's segmentation downstream.)
      expect(
          transcript.any((t) => RegExp(r'[A-Za-z]').hasMatch(t.text)),
          isTrue,
          reason: 'whisper returned only punctuation/noise - no real words '
              'in the transcript; check the clip (clean speech?) or the '
              'whisper build');
    }, timeout: const Timeout(Duration(minutes: 30)));

    test('full pipeline: video in, reels in the library', () async {
      final sw = Stopwatch()..start();
      final template = await rootBundle
          .loadString('assets/prompts/segmentation_prompt.md');
      final library = LibraryStore(persist: false);
      final pipeline = ReelPipeline(
        library: library,
        whisperModelDir: whisperDir,
        llmModelDir: llmDir,
        promptTemplate: template,
      );
      final chapter = await pipeline.run(
        videoPath: videoPath,
        onProgress: (s) => print('E2E: $s [${sw.elapsed}]'),
      );
      print('E2E: pipeline done in ${sw.elapsed}: '
          'chapter "${chapter.name}", ${chapter.reels.length} reels');
      for (final r in chapter.reels) {
        print('E2E:   ${r.segment.type} ${r.segment.startSec}-'
            '${r.segment.endSec}s: ${r.segment.title}');
      }
      expect(chapter.name.trim(), isNotEmpty);
      expect(chapter.reels, isNotEmpty,
          reason: 'pipeline produced no reels');
      for (final r in chapter.reels) {
        expect(r.segment.endSec > r.segment.startSec, isTrue,
            reason: 'reel "${r.segment.title}" has bad timestamps');
        expect(r.segment.title.trim(), isNotEmpty);
      }
      expect(library.reels.length, chapter.reels.length);
    }, timeout: const Timeout(Duration(minutes: 60)));
  });
}
