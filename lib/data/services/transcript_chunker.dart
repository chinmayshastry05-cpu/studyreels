import '../models/transcript.dart';

/// Groups transcript segments into token-bounded chunks for the segmentation
/// LLM. Pure logic — the token counter is injected so this is unit-testable
/// without native code.
///
/// Target: 1200–2000 tokens per chunk (the segmentation prompt wants
/// 1.2K–2K-token transcript windows). Chunks never split a segment; a chunk
/// is emitted once it holds >= minTokens and the next segment would push it
/// past maxTokens. The tail chunk may be smaller than minTokens.
///
/// Chunks overlap by [overlapTokens] (trailing segments are repeated at the
/// start of the next chunk) so a topic/problem straddling a boundary is seen
/// whole by at least one segmentation call. The pipeline dedupes the
/// resulting cross-chunk duplicates (see dedupeSegments).
class TranscriptChunker {
  static List<TranscriptChunk> chunk(
    List<TranscriptSegment> segments,
    int Function(String text) countTokens, {
    int minTokens = 1200,
    int maxTokens = 2000,
    int overlapTokens = 200,
  }) {
    assert(minTokens > 0 && maxTokens >= minTokens);
    assert(overlapTokens >= 0 && overlapTokens < maxTokens);
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
      // Retain trailing segments covering ~overlapTokens for the next chunk.
      final keep = <TranscriptSegment>[];
      var keepTokens = 0;
      for (var i = buf.length - 1;
          i >= 0 && keepTokens < overlapTokens;
          i--) {
        keep.insert(0, buf[i]);
        keepTokens += countTokens(buf[i].text);
      }
      buf = keep;
      bufTokens = keepTokens;
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
