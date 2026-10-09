import 'package:file_picker/file_picker.dart';

/// Import contract: local file via the system picker now,
/// YouTube via yt-dlp planned later. No cloud services anywhere.
class VideoImportService {
  /// Returns the picked video file path, or null if cancelled.
  Future<String?> pickLocalVideo() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.video,
      allowMultiple: false,
    );
    final path = result?.files.single.path;
    return (path == null || path.isEmpty) ? null : path;
  }

  /// Planned: download with yt-dlp, then import the local file.
  Future<String> importFromYoutube(String url) {
    throw UnimplementedError(
        'YouTube import via yt-dlp is planned after phase 1 (see README).');
  }
}
