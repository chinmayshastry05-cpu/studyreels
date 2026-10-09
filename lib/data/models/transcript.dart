/// Timestamped transcript pieces produced by Cactus transcription
/// (whisper, `timestamps: true`) and the token-bounded chunks fed to the
/// segmentation LLM.

class TranscriptSegment {
  /// Start time in seconds.
  final double start;

  /// End time in seconds.
  final double end;

  final String text;

  const TranscriptSegment({
    required this.start,
    required this.end,
    required this.text,
  });

  /// Parses one `{start, end, text}` entry from a cactus_transcribe response.
  factory TranscriptSegment.fromJson(Map<String, dynamic> json) {
    return TranscriptSegment(
      start: (json['start'] as num).toDouble(),
      end: (json['end'] as num).toDouble(),
      text: (json['text'] as String).trim(),
    );
  }
}

class TranscriptChunk {
  final double start;
  final double end;
  final String text;

  /// Token count per the segmentation model's own tokenizer.
  final int tokens;

  const TranscriptChunk({
    required this.start,
    required this.end,
    required this.text,
    required this.tokens,
  });
}
