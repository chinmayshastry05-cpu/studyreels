import '../models/transcript.dart';

/// Groups transcript segments into token-bounded chunks for the segmentation
/// LLM. Pure logic — the token counter is injected so this is unit-testable
/// without native code.
///
/// Target: 1200–2000 tokens per chunk (the segmentation prompt wants
/// 1.2K–2K-token transcript windows). Chunks never split a segment; a chunk
/// is emitted once it holds >= minTokens and the next segment would push it
/// past maxTokens. The tail chunk may be smaller than minTokens.
class TranscriptChunker {
  static List<TranscriptChunk> chunk(
    List<TranscriptSegment> segments,
    int Function(String text) countTokens, {
    int minTokens = 1200,
    int maxTokens = 2000,
  }) {
    assert(minTokens > 0 && maxTokens >= minTokens);
    final chunks = <TranscriptChunk>[];
    var buf = <TranscriptSegment>[];
    var bufTokens = 0;

    void flush() {
      if (buf.isEmpty) return;
      chunks.add(TranscriptChunk(
        start: buf.first.start,
        end: buf.last.end,
        text: buf.map((s) => s.text).join(' '),
        tokens: bufTokens,
      ));
      buf = <TranscriptSegment>[];
      bufTokens = 0;
    }

    for (final segment in segments) {
      final t = countTokens(segment.text);
      if (buf.isNotEmpty &&
          bufTokens + t > maxTokens &&
          bufTokens >= minTokens) {
        flush();
      }
      buf.add(segment);
      bufTokens += t;
    }
    flush();
    return chunks;
  }
}
