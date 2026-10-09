import 'package:flutter_test/flutter_test.dart';
import 'package:studyreels/data/models/segment.dart';
import 'package:studyreels/data/services/segment_eval.dart';

const _gold = [
  Segment(type: SegmentType.topic, title: 'A', startSec: 0, endSec: 100),
  Segment(type: SegmentType.problem, title: 'B', startSec: 120, endSec: 240),
];

void main() {
  group('SegmentEval', () {
    test('perfect prediction scores 1.0', () {
      final s = SegmentEval.score(predicted: _gold, gold: _gold);
      expect(s.precision, 1.0);
      expect(s.recall, 1.0);
      expect(s.f1, 1.0);
      expect(s.typeAccuracy, 1.0);
    });

    test('boundaries within tolerance match', () {
      final predicted = const [
        Segment(type: SegmentType.topic, title: 'A', startSec: 10, endSec: 95),
        Segment(
            type: SegmentType.problem, title: 'B', startSec: 130, endSec: 230),
      ];
      final s = SegmentEval.score(predicted: predicted, gold: _gold);
      expect(s.matched, 2);
      expect(s.f1, 1.0);
    });

    test('boundaries outside tolerance do not match', () {
      final predicted = const [
        Segment(type: SegmentType.topic, title: 'A', startSec: 50, endSec: 100),
      ];
      final s = SegmentEval.score(predicted: predicted, gold: _gold);
      expect(s.matched, 0);
      expect(s.precision, 0.0);
      expect(s.recall, 0.0);
    });

    test('partial predictions give partial precision/recall', () {
      final predicted = const [
        Segment(type: SegmentType.topic, title: 'A', startSec: 0, endSec: 100),
        Segment(type: SegmentType.topic, title: 'X', startSec: 300, endSec: 400),
      ];
      final s = SegmentEval.score(predicted: predicted, gold: _gold);
      expect(s.precision, 0.5);
      expect(s.recall, 0.5);
    });

    test('type accuracy counts mismatched types among matches', () {
      final predicted = const [
        // Right edges, wrong type.
        Segment(type: SegmentType.problem, title: 'A', startSec: 0, endSec: 100),
        Segment(
            type: SegmentType.problem, title: 'B', startSec: 120, endSec: 240),
      ];
      final s = SegmentEval.score(predicted: predicted, gold: _gold);
      expect(s.matched, 2);
      expect(s.typeAccuracy, 0.5);
    });

    test('empty predictions score zero without crashing', () {
      final s = SegmentEval.score(predicted: const [], gold: _gold);
      expect(s.f1, 0.0);
      expect(s.recall, 0.0);
    });
  });
}
