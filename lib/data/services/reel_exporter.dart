import 'package:flutter/services.dart';

/// One-tap "save reel to gallery": stream-copy trim (no re-encode) done
/// natively, saved via MediaStore into Movies/StudyReels.
class ReelExportException implements Exception {
  final String message;
  const ReelExportException(this.message);

  @override
  String toString() => 'ReelExportException: $message';
}

class ReelExporter {
  static const _channel = MethodChannel('com.studyreels.app/export');

  /// Exports [startSec, endSec] of [videoPath] as an MP4 into the gallery.
  /// Returns the MediaStore URI of the saved clip.
  static Future<String> exportClip({
    required String videoPath,
    required double startSec,
    required double endSec,
  }) async {
    try {
      final uri = await _channel.invokeMethod<String>(
        'exportClip',
        {
          'videoPath': videoPath,
          'startSec': startSec,
          'endSec': endSec,
        },
      );
      if (uri == null || uri.isEmpty) {
        throw const ReelExportException('Exporter returned an empty URI');
      }
      return uri;
    } on PlatformException catch (e) {
      throw ReelExportException('${e.code}: ${e.message}');
    }
  }

  /// Caption burn-in needs a full decode → render-text → re-encode pass.
  /// Not built yet — the fast stream-copy trim above is the default.
  static Future<String> exportClipWithCaptions({
    required String videoPath,
    required double startSec,
    required double endSec,
  }) {
    throw UnimplementedError(
      'Caption burn-in needs video re-encode and is not in this build. '
      'Use exportClip (fast, no re-encode) instead.',
    );
  }
}
