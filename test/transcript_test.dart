import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:studyreels/data/models/transcript.dart';
import 'package:studyreels/data/services/transcript_chunker.dart';
import 'package:studyreels/data/services/transcription_service.dart';

/// Fake token counter: 1 token per word, deterministic for tests.
int _words(String text) =>
    text.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;

TranscriptSegment _seg(double start, double end, int words) {
  final text = List.filled(words, 'word').join(' ');
  return TranscriptSegment(start: start, end: end, text: text);
}

void main() {
  group('TranscriptSegment.fromJson', () {
    test('parses start/end/text', () {
      final s = TranscriptSegment.fromJson(
          {'start': 12.5, 'end': 15.0, 'text': '  hello world  '});
      expect(s.start, 12.5);
      expect(s.end, 15.0);
      expect(s.text, 'hello world');
    });
  });

  group('TranscriptionService.parseTranscriptionResponse', () {
    String envelope({
      bool success = true,
      bool cloudHandoff = false,
      List<Map<String, Object>>? segments,
    }) {
      return jsonEncode({
        'success': success,
        'error': success ? null : 'boom',
        'cloud_handoff': cloudHandoff,
        'response': 'hello world',
        'segments': segments ??
            [
              {'start': 0.0, 'end': 2.5, 'text': 'hello world'},
              {'start': 2.5, 'end': 5.0, 'text': 'namaste duniya'},
            ],
      });
    }

    test('parses segments from a valid envelope', () {
      final segs = TranscriptionService.parseTranscriptionResponse(envelope());
      expect(segs, hasLength(2));
      expect(segs[0].start, 0.0);
      expect(segs[1].text, 'namaste duniya');
    });

    test('fails closed when cloud_handoff is true', () {
      expect(
        () => TranscriptionService.parseTranscriptionResponse(
            envelope(cloudHandoff: true)),
        throwsA(isA<TranscriptionException>()),
      );
    });

    test('fails closed when cloud_handoff is missing', () {
      final raw = jsonDecode(envelope()) as Map<String, dynamic>
        ..remove('cloud_handoff');
      expect(
        () => TranscriptionService.parseTranscriptionResponse(
            jsonEncode(raw)),
        throwsA(isA<TranscriptionException>()),
      );
    });

    test('throws when success is false', () {
      expect(
        () => TranscriptionService.parseTranscriptionResponse(
            envelope(success: false)),
        throwsA(isA<TranscriptionException>()),
      );
    });

    test('empty segments list parses to empty', () {
      final segs = TranscriptionService.parseTranscriptionResponse(
          envelope(segments: []));
      expect(segs, isEmpty);
    });
  });

  group('TranscriptChunker', () {
    test('empty input gives no chunks', () {
      expect(TranscriptChunker.chunk([], _words), isEmpty);
    });

    test('chunks stay within token bounds and cover everything', () {
      // 10 segments x 400 tokens = 4000 tokens, window 1200..2000.
      // Optimal packing: [2000, 2000] — every chunk within bounds.
      final segments = List.generate(
          10, (i) => _seg(i * 10.0, i * 10.0 + 9.0, 400));
      final chunks = TranscriptChunker.chunk(segments, _words);
      expect(chunks, hasLength(2));
      for (final c in chunks) {
        expect(c.tokens, inInclusiveRange(1200, 2000));
      }
      // Boundaries: chunk spans its segments exactly.
      expect(chunks[0].start, 0.0);
      expect(chunks[0].end, 49.0);
      expect(chunks[1].start, 50.0);
      expect(chunks[1].end, 99.0);
      // Total token coverage is complete.
      expect(
          chunks.fold<int>(0, (sum, c) => sum + c.tokens), 4000);
    });

    test('tail chunk may be smaller than minTokens', () {
      // 6 segments x 400 tokens = 2400 -> [2000, 400(tail)].
      final segments =
          List.generate(6, (i) => _seg(i * 10.0, i * 10.0 + 9.0, 400));
      final chunks = TranscriptChunker.chunk(segments, _words);
      expect(chunks.map((c) => c.tokens), [2000, 400]);
    });

    test('a single oversized segment becomes its own chunk', () {
      final segments = [_seg(0.0, 30.0, 5000)];
      final chunks = TranscriptChunker.chunk(segments, _words);
      expect(chunks, hasLength(1));
      expect(chunks[0].tokens, 5000);
    });

    test('chunk text joins segment texts in order', () {
      final segments = [
        const TranscriptSegment(start: 0, end: 1, text: 'ek'),
        const TranscriptSegment(start: 1, end: 2, text: 'do'),
      ];
      final chunks = TranscriptChunker.chunk(
        segments,
        _words,
        minTokens: 1,
        maxTokens: 100,
      );
      expect(chunks, hasLength(1));
      expect(chunks[0].text, 'ek do');
    });
  });
}
