import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:studyreels/data/models/reel.dart';
import 'package:studyreels/data/models/segment.dart';
import 'package:studyreels/data/models/transcript.dart';
import 'package:studyreels/data/services/llm_service.dart';
import 'package:studyreels/data/services/reel_pipeline.dart';
import 'package:studyreels/data/services/segmentation_service.dart';
import 'package:studyreels/data/services/transcriber.dart';
import 'package:studyreels/data/services/transcript_chunker.dart';

class FakeTranscriber implements Transcriber {
  final List<TranscriptSegment> segments;
  FakeTranscriber(this.segments);

  @override
  Future<List<TranscriptSegment>> transcribeVideo(String videoPath) async {
    return segments;
  }
}

int _words(String text) =>
    text.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;

void main() {
  group('captionAt', () {
    const caps = [
      TranscriptSegment(start: 0, end: 5, text: 'intro'),
      TranscriptSegment(start: 5, end: 10, text: 'main point'),
    ];

    test('finds the caption containing the position', () {
      expect(captionAt(caps, 2.5)?.text, 'intro');
      expect(captionAt(caps, 7.0)?.text, 'main point');
    });

    test('boundary is inclusive of start, exclusive of end', () {
      expect(captionAt(caps, 5.0)?.text, 'main point');
      expect(captionAt(caps, 0.0)?.text, 'intro');
    });

    test('returns null outside all ranges', () {
      expect(captionAt(caps, 10.0), isNull);
      expect(captionAt(caps, -1.0), isNull);
      expect(captionAt([], 2.0), isNull);
    });
  });

  group('Reel JSON', () {
    test('round-trips through toJson/fromJson', () {
      const reel = Reel(
        id: 'r1',
        videoPath: '/v/lec.mp4',
        segment: Segment(
          type: SegmentType.problem,
          title: 'Q1',
          startSec: 65,
          endSec: 115,
        ),
        chapter: 'Math',
        captions: [
          TranscriptSegment(start: 60, end: 70, text: 'question'),
        ],
      );
      final back = Reel.fromJson(
          jsonDecode(jsonEncode(reel.toJson())) as Map<String, dynamic>);
      expect(back.id, 'r1');
      expect(back.videoPath, '/v/lec.mp4');
      expect(back.title, 'Q1');
      expect(back.isProblem, isTrue);
      expect(back.chapter, 'Math');
      expect(back.captions, hasLength(1));
      expect(back.captions[0].text, 'question');
    });
  });

  group('buildReels', () {
    const prompt = '{{CHUNK_START}} {{CHUNK_END}} {{TRANSCRIPT}}';

    Future<List<Reel>> run(
        List<TranscriptSegment> transcript, String llmJson) {
      final stages = <String>[];
      return buildReels(
        transcriber: FakeTranscriber(transcript),
        segmentation: SegmentationService(
          llm: SequencedFakeLlmBackend([llmJson]),
          promptTemplate: prompt,
        ),
        countTokens: _words,
        videoPath: '/v/lec.mp4',
        chapterName: 'Physics',
        onProgress: stages.add,
      );
    }

    test('builds reels with chapter, captions and video path', () async {
      final transcript = [
        TranscriptSegment(
            start: 0, end: 60, text: List.filled(10, 'w').join(' ')),
        TranscriptSegment(
            start: 60, end: 120, text: List.filled(10, 'w').join(' ')),
      ];
      final reels = await run(
        transcript,
        jsonEncode({
          'segments': [
            {'type': 'topic', 'title': 'T1', 'start': 5, 'end': 55},
            {'type': 'problem', 'title': 'P1', 'start': 65, 'end': 115},
          ]
        }),
      );
      expect(reels, hasLength(2));
      expect(reels[0].title, 'T1');
      expect(reels[0].isProblem, isFalse);
      expect(reels[1].isProblem, isTrue);
      for (final r in reels) {
        expect(r.chapter, 'Physics');
        expect(r.videoPath, '/v/lec.mp4');
      }
      // Captions are the transcript lines overlapping each segment.
      expect(reels[0].captions, hasLength(1));
      expect(reels[1].captions, hasLength(1));
    });

    test('throws when transcription is empty', () async {
      expect(
        run([], jsonEncode({'segments': []})),
        throwsA(isA<PipelineException>()),
      );
    });

    test('a problem spanning two chunks is deduped to one reel', () async {
      // 8 x 400-token segments -> chunks [0,299] and [240,479] (overlap).
      // A problem straddling the boundary is segmented by both chunks with
      // slightly uncertain edges; dedupe must keep exactly one reel.
      final transcript = List.generate(
        8,
        (i) => TranscriptSegment(
            start: i * 60.0,
            end: i * 60.0 + 59.0,
            text: List.filled(400, 'w').join(' ')),
      );
      final chunks = TranscriptChunker.chunk(transcript, _words);
      expect(chunks.map((c) => c.tokens), [2000, 1600]);
      expect(chunks[1].start, lessThan(chunks[0].end));

      final chunk1Json = jsonEncode({
        'segments': [
          {'type': 'problem', 'title': 'Big problem', 'start': 200, 'end': 290},
        ]
      });
      final chunk2Json = jsonEncode({
        'segments': [
          // Same problem, uncertain boundaries in the overlap region.
          {'type': 'problem', 'title': 'Big problem', 'start': 240, 'end': 360},
        ]
      });
      final stages = <String>[];
      final reels = await buildReels(
        transcriber: FakeTranscriber(transcript),
        segmentation: SegmentationService(
          llm: SequencedFakeLlmBackend([chunk1Json, chunk2Json]),
          promptTemplate: prompt,
        ),
        countTokens: _words,
        videoPath: '/v/lec.mp4',
        chapterName: 'Physics',
        onProgress: stages.add,
      );
      // Merged to the union: one reel covering the whole problem.
      expect(reels, hasLength(1));
      expect(reels[0].title, 'Big problem');
      expect(reels[0].isProblem, isTrue);
      expect(reels[0].segment.startSec, 200);
      expect(reels[0].segment.endSec, 360);
    });

    test('distinct adjacent segments are not deduped', () {
      final kept = dedupeSegments(const [
        Segment(type: SegmentType.topic, title: 'A', startSec: 0, endSec: 100),
        Segment(type: SegmentType.topic, title: 'B', startSec: 100, endSec: 200),
        Segment(
            type: SegmentType.problem, title: 'C', startSec: 200, endSec: 300),
      ]);
      expect(kept, hasLength(3));
    });

    test('same-type duplicates merge to their union', () {
      final kept = dedupeSegments(const [
        Segment(
            type: SegmentType.problem, title: 'P', startSec: 200, endSec: 290),
        // 50s overlap of a 90s segment (>= 50%) -> same content, merge.
        Segment(
            type: SegmentType.problem, title: 'P', startSec: 240, endSec: 360),
      ]);
      expect(kept, hasLength(1));
      expect(kept[0].startSec, 200);
      expect(kept[0].endSec, 360);
    });

    test('small overlaps and type disagreements are kept', () {
      final kept = dedupeSegments(const [
        Segment(
            type: SegmentType.problem, title: 'P', startSec: 200, endSec: 290),
        // 10s overlap of a 100s segment (< 50%) -> distinct.
        Segment(
            type: SegmentType.problem, title: 'Q', startSec: 280, endSec: 380),
        // Heavy overlap but different type -> model disagreed, keep both.
        Segment(
            type: SegmentType.topic, title: 'T', startSec: 370, endSec: 470),
      ]);
      expect(kept.map((s) => s.title), ['P', 'Q', 'T']);
    });

    test('empty model segments surface as a segmentation error', () async {
      // The segmentation service itself rejects an empty segments array
      // during validation, before the pipeline's own empty-reels check.
      final transcript = [
        const TranscriptSegment(start: 0, end: 60, text: 'hello'),
      ];
      expect(
        run(transcript, jsonEncode({'segments': []})),
        throwsA(isA<SegmentationException>()),
      );
    });
  });
}
