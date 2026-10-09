import 'segment.dart';
import 'transcript.dart';

/// A reel is timestamp-based: the ORIGINAL video file plus start/end
/// timestamps plus overlay captions. Reels are never re-rendered clips.
class Reel {
  final String id;
  final String videoPath;
  final Segment segment;
  final String chapter;

  /// Transcript lines overlapping this reel, shown as overlay captions
  /// during playback.
  final List<TranscriptSegment> captions;

  final String? captionOverride;

  const Reel({
    required this.id,
    required this.videoPath,
    required this.segment,
    required this.chapter,
    this.captions = const [],
    this.captionOverride,
  });

  String get title => segment.title;
  bool get isProblem => segment.type == SegmentType.problem;

  factory Reel.fromJson(Map<String, dynamic> json) {
    return Reel(
      id: json['id'] as String,
      videoPath: json['videoPath'] as String,
      segment:
          Segment.fromJson(json['segment'] as Map<String, dynamic>),
      chapter: json['chapter'] as String,
      captions: ((json['captions'] as List?) ?? [])
          .map((e) =>
              TranscriptSegment.fromJson(e as Map<String, dynamic>))
          .toList(),
      captionOverride: json['captionOverride'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'videoPath': videoPath,
        'segment': segment.toJson(),
        'chapter': chapter,
        'captions': captions.map((c) => c.toJson()).toList(),
        'captionOverride': captionOverride,
      };
}
