import 'package:flutter_test/flutter_test.dart';
import 'package:studyreels/data/models/chapter.dart';
import 'package:studyreels/data/models/reel.dart';
import 'package:studyreels/data/models/segment.dart';

void main() {
  group('Segment', () {
    test('fromJson parses valid input', () {
      final s = Segment.fromJson({
        'type': 'problem',
        'title': 'Rolling without slipping',
        'start': 215,
        'end': 340,
      });
      expect(s.type, SegmentType.problem);
      expect(s.title, 'Rolling without slipping');
      expect(s.startSec, 215);
      expect(s.endSec, 340);
    });

    test('toJson round-trips', () {
      const s = Segment(
          type: SegmentType.topic,
          title: 'Torque',
          startSec: 0,
          endSec: 47);
      final back = Segment.fromJson(s.toJson());
      expect(back.title, s.title);
      expect(back.startSec, s.startSec);
      expect(back.endSec, s.endSec);
      expect(back.type, s.type);
    });

    test('rejects empty title', () {
      expect(
          () => Segment.fromJson(
              {'type': 'topic', 'title': '  ', 'start': 0, 'end': 10}),
          throwsA(isA<FormatException>()));
    });

    test('rejects end <= start', () {
      expect(
          () => Segment.fromJson(
              {'type': 'topic', 'title': 'X', 'start': 50, 'end': 50}),
          throwsA(isA<FormatException>()));
    });
  });

  group('Reel and Chapter', () {
    const topic = Segment(
        type: SegmentType.topic, title: 'T', startSec: 0, endSec: 10);
    const problem = Segment(
        type: SegmentType.problem, title: 'P', startSec: 10, endSec: 20);

    test('isProblem reflects segment type', () {
      const r1 = Reel(
          id: '1', videoPath: 'a.mp4', segment: topic, chapter: 'Ch1');
      const r2 = Reel(
          id: '2', videoPath: 'a.mp4', segment: problem, chapter: 'Ch1');
      expect(r1.isProblem, isFalse);
      expect(r2.isProblem, isTrue);
    });

    test('Chapter splits topics and problems', () {
      const c = Chapter(name: 'Ch1', reels: [
        Reel(id: '1', videoPath: 'a.mp4', segment: topic, chapter: 'Ch1'),
        Reel(id: '2', videoPath: 'a.mp4', segment: problem, chapter: 'Ch1'),
      ]);
      expect(c.topics, hasLength(1));
      expect(c.problems, hasLength(1));
    });
  });
}
