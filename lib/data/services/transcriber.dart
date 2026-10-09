import '../models/transcript.dart';

/// Abstract transcription source so the reel pipeline is unit-testable
/// without native code.
abstract class Transcriber {
  Future<List<TranscriptSegment>> transcribeVideo(String videoPath);
}
