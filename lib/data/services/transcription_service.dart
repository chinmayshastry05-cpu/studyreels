import 'dart:convert';
import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';
import 'package:flutter/foundation.dart';

import '../../cactus/cactus.dart' as cactus;
import '../models/transcript.dart';
import 'audio_extractor.dart';
import 'transcriber.dart';

/// Transcribes in a background isolate so the UI thread never blocks —
/// a lecture can take minutes. Audio extraction stays on the main isolate
/// (platform channel); only plain strings cross the isolate boundary.
Future<List<TranscriptSegment>> transcribeVideoInBackground({
  required String videoPath,
  required String whisperModelDir,
  required void Function(String stage) onProgress,
}) async {
  onProgress('Extracting audio…');
  final wavPath = await AudioExtractor.extractWav(videoPath);
  try {
    onProgress('Transcribing audio on-device…');
    return await compute(
      _transcribeWav,
      {'whisperDir': whisperModelDir, 'wavPath': wavPath},
    );
  } finally {
    await File(wavPath).delete().catchError((_) => File(wavPath));
  }
}

Future<List<TranscriptSegment>> _transcribeWav(
    Map<String, String> args) {
  final service = TranscriptionService(args['whisperDir']!);
  return service.transcribeWav(args['wavPath']!);
}

/// Production [Transcriber]: background-isolate transcription.
class BackgroundTranscriber implements Transcriber {
  final String whisperModelDir;
  final void Function(String stage) onProgress;

  BackgroundTranscriber({
    required this.whisperModelDir,
    required this.onProgress,
  });

  @override
  Future<List<TranscriptSegment>> transcribeVideo(String videoPath) {
    return transcribeVideoInBackground(
      videoPath: videoPath,
      whisperModelDir: whisperModelDir,
      onProgress: onProgress,
    );
  }
}

/// On-device speech-to-text via the Cactus built-in transcription models.
///
/// Model pick: whisper-base (Cactus-Compute/whisper-base) — the smallest
/// Cactus transcription model with usable Hindi AND English. Whisper-tiny
/// exists but its Hindi quality is poor; moonshine/parakeet are English-only
/// and parakeet returns no timestamp segments. Language is left to the model
/// default (auto-detect), which handles Hindi/English/mixed lectures.
///
/// 100% LOCAL: transcription responses always carry cloud_handoff == false;
/// a missing or true value fails closed.
class TranscriptionException implements Exception {
  final String message;
  const TranscriptionException(this.message);

  @override
  String toString() => 'TranscriptionException: $message';
}

class TranscriptionService implements Transcriber {
  /// On-device whisper bundle dir, e.g.
  /// /data/data/com.studyreels.app/files/models/whisper-base
  final String whisperModelDir;

  /// Max bytes for the cactus_transcribe JSON response (full text + segments).
  static const int responseBufferSize = 8 * 1024 * 1024;

  TranscriptionService(this.whisperModelDir);

  /// Full pipeline: video file -> 16 kHz WAV -> timestamped segments.
  /// The temp WAV is deleted afterwards.
  Future<List<TranscriptSegment>> transcribeVideo(String videoPath) async {
    final wavPath = await AudioExtractor.extractWav(videoPath);
    try {
      return await transcribeWav(wavPath);
    } finally {
      await File(wavPath).delete().catchError((_) => File(wavPath));
    }
  }

  /// Transcribes an existing 16-bit PCM WAV file. Runs on the calling isolate;
  /// callers should move it off the UI thread for long audio.
  Future<List<TranscriptSegment>> transcribeWav(String wavPath) async {
    final modelPathPtr = whisperModelDir.toNativeUtf8();
    cactus.CactusModelT model = nullptr;
    final buf = calloc<Uint8>(responseBufferSize);
    try {
      model = cactus.cactusInit(modelPathPtr.cast(), nullptr, false);
      if (model == nullptr) {
        throw const TranscriptionException(
            'cactus_init returned null for the whisper model');
      }
      final wavPtr = wavPath.toNativeUtf8();
      final optionsPtr = '{"timestamps":true}'.toNativeUtf8();
      try {
        final rc = cactus.cactusTranscribe(
          model,
          wavPtr.cast(), // audio_file_path
          nullptr, // prompt
          buf.cast(), // responseBuffer
          responseBufferSize,
          optionsPtr.cast(), // optionsJson
          nullptr, // streaming callback
          nullptr, // userData
          nullptr, // pcmBuffer (file-based)
          0, // pcmBufferSize
        );
        if (rc < 0) {
          throw TranscriptionException(
              'cactus_transcribe failed with code $rc');
        }
        return parseTranscriptionResponse(buf.cast<Utf8>().toDartString());
      } finally {
        calloc.free(wavPtr);
        calloc.free(optionsPtr);
      }
    } finally {
      calloc.free(modelPathPtr);
      calloc.free(buf);
      if (model != nullptr) {
        cactus.cactusDestroy(model);
      }
    }
  }

  /// Parses and validates a cactus_transcribe response envelope.
  /// Pure function — unit-tested. Fails closed on cloud_handoff.
  static List<TranscriptSegment> parseTranscriptionResponse(
      String responseJson) {
    final decoded = jsonDecode(responseJson);
    if (decoded is! Map<String, dynamic>) {
      throw const TranscriptionException(
          'Malformed transcription response envelope');
    }
    if (decoded['cloud_handoff'] != false) {
      throw const TranscriptionException(
          'Cloud handoff detected or unconfirmed — refusing (local-only policy).');
    }
    if (decoded['success'] != true) {
      throw TranscriptionException(
          'Transcription failed: ${decoded['error']}');
    }
    final segments = decoded['segments'];
    if (segments is! List) {
      throw const TranscriptionException(
          'Transcription response has no segments list');
    }
    return segments
        .map((e) => TranscriptSegment.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
