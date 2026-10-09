/// A topic or problem boundary inside a lecture video, in seconds.
enum SegmentType { topic, problem }

SegmentType segmentTypeFromString(String s) {
  switch (s) {
    case 'topic':
      return SegmentType.topic;
    case 'problem':
      return SegmentType.problem;
    default:
      throw FormatException('Unknown segment type: $s');
  }
}

class Segment {
  final SegmentType type;
  final String title;
  final int startSec;
  final int endSec;

  const Segment({
    required this.type,
    required this.title,
    required this.startSec,
    required this.endSec,
  });

  factory Segment.fromJson(Map<String, dynamic> json) {
    final type = segmentTypeFromString(json['type'] as String);
    final title = (json['title'] as String).trim();
    final start = (json['start'] as num).toInt();
    final end = (json['end'] as num).toInt();
    if (title.isEmpty) {
      throw const FormatException('Segment title is empty');
    }
    if (start < 0 || end <= start) {
      throw FormatException('Invalid segment range: $start-$end');
    }
    return Segment(type: type, title: title, startSec: start, endSec: end);
  }

  Map<String, dynamic> toJson() => {
        'type': type.name,
        'title': title,
        'start': startSec,
        'end': endSec,
      };
}
