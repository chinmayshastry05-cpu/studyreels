import '../models/segment.dart';

/// Scores predicted topic/problem boundaries against human-labelled gold
/// boundaries. Run this on the BASE model before any fine-tune, so the
/// fine-tune has something to beat.
///
/// A predicted segment matches a gold segment when both edges land within
/// [toleranceSec] of the gold edges. Each gold segment matches at most one
/// prediction (greedy, best first).
class BoundaryScores {
  /// Matched predictions / total predictions.
  final double precision;

  /// Matched gold / total gold.
  final double recall;

  final double f1;

  /// Of matched pairs, fraction with the same segment type.
  final double typeAccuracy;

  final int matched;
  final int predicted;
  final int gold;

  const BoundaryScores({
    required this.precision,
    required this.recall,
    required this.f1,
    required this.typeAccuracy,
    required this.matched,
    required this.predicted,
    required this.gold,
  });

  @override
  String toString() =>
      'P=${precision.toStringAsFixed(2)} R=${recall.toStringAsFixed(2)} '
      'F1=${f1.toStringAsFixed(2)} typeAcc=${typeAccuracy.toStringAsFixed(2)} '
      '($matched/$predicted predicted, $matched/$gold gold)';
}

class SegmentEval {
  static BoundaryScores score({
    required List<Segment> predicted,
    required List<Segment> gold,
    int toleranceSec = 15,
  }) {
    final remaining = List<Segment>.from(predicted);
    var matched = 0;
    var typeOk = 0;

    for (final g in gold) {
      Segment? best;
      var bestErr = 1 << 30;
      for (final p in remaining) {
        final err = (p.startSec - g.startSec).abs() +
            (p.endSec - g.endSec).abs();
        if (err <= toleranceSec * 2 && err < bestErr) {
          best = p;
          bestErr = err;
        }
      }
      if (best != null &&
          (best.startSec - g.startSec).abs() <= toleranceSec &&
          (best.endSec - g.endSec).abs() <= toleranceSec) {
        remaining.remove(best);
        matched++;
        if (best.type == g.type) typeOk++;
      }
    }

    final precision =
        predicted.isEmpty ? 0.0 : matched / predicted.length;
    final recall = gold.isEmpty ? 0.0 : matched / gold.length;
    final f1 = (precision + recall) == 0
        ? 0.0
        : 2 * precision * recall / (precision + recall);
    return BoundaryScores(
      precision: precision,
      recall: recall,
      f1: f1,
      typeAccuracy: matched == 0 ? 0.0 : typeOk / matched,
      matched: matched,
      predicted: predicted.length,
      gold: gold.length,
    );
  }
}
