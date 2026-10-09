import 'segment.dart';

/// A reel is timestamp-based: the ORIGINAL video file plus start/end
/// timestamps plus overlay captions. Reels are never re-rendered clips.
class Reel {
  final String id;
  final String videoPath;
  final Segment segment;
  final String chapter;
  final String? captionOverride;

  const Reel({
    required this.id,
    required this.videoPath,
    required this.segment,
    required this.chapter,
    this.captionOverride,
  });

  String get title => segment.title;
  bool get isProblem => segment.type == SegmentType.problem;
}
