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

  /// Planned: download with yt-dlp, then import the local file.
  Future<String> importFromYoutube(String url) {
    throw UnimplementedError(
        'YouTube import via yt-dlp is planned after phase 1 (see README).');
  }
}
