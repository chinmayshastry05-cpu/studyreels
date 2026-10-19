import 'package:image_picker/image_picker.dart';

/// Import contract: pick a video from the device gallery via the system
/// picker (no broad storage permission). YouTube via yt-dlp stays out of
/// scope for videos already on the phone. No cloud services anywhere.
class VideoImportService {
  final ImagePicker _picker = ImagePicker();

  /// Returns the picked video file path, or null if cancelled.
  Future<String?> pickLocalVideo() async {
    final video = await _picker.pickVideo(source: ImageSource.gallery);
    final path = video?.path;
    return (path == null || path.isEmpty) ? null : path;
  }

  /// Recovers a pick lost when Android destroyed the MainActivity while
  /// the system picker was open: the plugin caches the picked file, but
  /// the original pickVideo() future never completes. One-time: the
  /// cache is cleared once read. Returns null when nothing was lost, if
  /// recovery reports an error, or on non-Android platforms (where
  /// retrieveLostData throws UnimplementedError).
  Future<String?> recoverLostVideo() async {
    try {
      final response = await _picker.retrieveLostData();
      if (response.exception != null) return null;
      final path = response.file?.path;
      return (path == null || path.isEmpty) ? null : path;
    } catch (_) {
      return null;
    }
  }

  /// Planned: download with yt-dlp, then import the local file.
  Future<String> importFromYoutube(String url) {
    throw UnimplementedError(
        'YouTube import via yt-dlp is planned after phase 1 (see README).');
  }
}
