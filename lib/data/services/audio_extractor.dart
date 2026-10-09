import 'package:flutter/services.dart';

/// Extracts a 16 kHz mono WAV from a video file via the Android platform
/// channel (MediaExtractor + MediaCodec, fully on-device).
class AudioExtractionException implements Exception {
  final String message;
  const AudioExtractionException(this.message);

  @override
  String toString() => 'AudioExtractionException: $message';
}

class AudioExtractor {
  static const _channel = MethodChannel('com.studyreels.app/audio');

  /// Returns the path of the extracted WAV in the app cache dir.
  static Future<String> extractWav(String videoPath) async {
    try {
      final wav = await _channel.invokeMethod<String>(
        'extractWav',
        {'videoPath': videoPath},
      );
      if (wav == null || wav.isEmpty) {
        throw const AudioExtractionException(
            'Native extractor returned an empty path');
      }
      return wav;
    } on PlatformException catch (e) {
      throw AudioExtractionException('${e.code}: ${e.message}');
    }
  }
}
