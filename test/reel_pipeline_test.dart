import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:studyreels/data/models/reel.dart';
import 'package:studyreels/data/models/segment.dart';
import 'package:studyreels/data/models/transcript.dart';
import 'package:studyreels/data/services/llm_service.dart';
import 'package:studyreels/data/services/reel_pipeline.dart';
import 'package:studyreels/data/services/segmentation_service.dart';
import 'package:studyreels/data/services/transcriber.dart';

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
