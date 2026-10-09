/// Phase 1 import contract.
///
/// Local file import is stubbed for UI development (wire a file picker here).
/// YouTube import via yt-dlp is planned after phase 1 (see README) and is
/// intentionally not implemented yet. No cloud services are used anywhere.
class VideoImportService {
  /// Returns the picked video file path, or null if cancelled.
  /// TODO(phase-1): wire a file picker and copy into the app library dir.
  Future<String?> pickLocalVideo() async {
    return null;
  }

  /// Planned: download with yt-dlp, then import the local file.
  Future<String> importFromYoutube(String url) {
    throw UnimplementedError(
        'YouTube import via yt-dlp is planned after phase 1 (see README).');
  }
}
