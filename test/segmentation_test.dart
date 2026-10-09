import 'package:flutter_test/flutter_test.dart';
import 'package:studyreels/data/models/segment.dart';
import 'package:studyreels/data/services/llm_service.dart';
import 'package:studyreels/data/services/segmentation_service.dart';

const _validJson = '''
{"segments":[
  {"type":"topic","title":"Torque recap","start":0,"end":47},
  {"type":"topic","title":"Moment of inertia","start":47,"end":182},
  {"type":"problem","title":"Rod moment of inertia","start":182,"end":312},
  {"type":"topic","title":"Parallel axis theorem","start":312,"end":390},
  {"type":"problem","title":"Shifted disc axis","start":390,"end":465},
  {"type":"topic","title":"Wrap-up","start":465,"end":480}
]}
''';

const _overlappingJson = '''
{"segments":[
  {"type":"topic","title":"A","start":0,"end":100},
  {"type":"topic","title":"B","start":90,"end":200}
]}
''';

const _template = 'RANGE {{CHUNK_START}}-{{CHUNK_END}}\n{{TRANSCRIPT}}';

SegmentationService _service(LlmBackend llm, {int maxRetries = 2}) =>
    SegmentationService(
      llm: llm,
      promptTemplate: _template,
      maxRetries: maxRetries,
    );

void main() {
  group('parseAndValidate', () {
    test('accepts valid schema and boundary rules', () {
      final segs =
          SegmentationService.parseAndValidate(_validJson, 0, 480);
      expect(segs, hasLength(6));
      expect(segs[0].type, SegmentType.topic);
      expect(segs[2].type, SegmentType.problem);
      expect(segs[2].title, 'Rod moment of inertia');
      expect(segs[5].endSec, 480);
    });

    test('rejects overlapping segments', () {
      expect(
          () => SegmentationService.parseAndValidate(
              _overlappingJson, 0, 480),
          throwsA(isA<SegmentationException>()));
    });

    test('allows gaps: no filler segments required', () {
      // The prompt no longer forces gap-free tiling; intros/tangents may
      // be left unsegmented.
      const json = '{"segments":['
          '{"type":"topic","title":"A","start":30,"end":120},'
          '{"type":"problem","title":"B","start":300,"end":420}]}';
      final segs =
          SegmentationService.parseAndValidate(json, 0, 480);
      expect(segs, hasLength(2));
      expect(segs[0].startSec, 30);
      expect(segs[1].startSec, 300);
    });

    test('rejects segments outside the chunk range', () {
      const json =
          '{"segments":[{"type":"topic","title":"A","start":0,"end":500}]}';
      expect(() => SegmentationService.parseAndValidate(json, 0, 480),
          throwsA(isA<SegmentationException>()));
    });

    test('rejects unsorted segments', () {
      const json =
          '{"segments":[{"type":"topic","title":"B","start":100,"end":200},'
          '{"type":"topic","title":"A","start":0,"end":100}]}';
      expect(() => SegmentationService.parseAndValidate(json, 0, 480),
          throwsA(isA<SegmentationException>()));
    });

    test('rejects empty segment list', () {
      expect(
          () => SegmentationService.parseAndValidate(
              '{"segments":[]}', 0, 480),
          throwsA(isA<SegmentationException>()));
    });

    test('rejects missing segments key', () {
      expect(() => SegmentationService.parseAndValidate('{}', 0, 480),
          throwsA(isA<SegmentationException>()));
    });

    test('rejects unknown segment type', () {
      const json =
          '{"segments":[{"type":"quiz","title":"A","start":0,"end":100}]}';
      expect(() => SegmentationService.parseAndValidate(json, 0, 480),
          throwsA(isA<FormatException>()));
    });

    test('rejects end <= start', () {
      const json =
          '{"segments":[{"type":"topic","title":"A","start":100,"end":100}]}';
      expect(() => SegmentationService.parseAndValidate(json, 0, 480),
          throwsA(isA<FormatException>()));
    });
  });

  group('buildPrompt', () {
    test('replaces placeholders', () {
      final s = _service(FakeLlmBackend(_validJson));
      final p = s.buildPrompt('[00:00] hello', 0, 480);
      expect(p, contains('RANGE 0-480'));
      expect(p, contains('[00:00] hello'));
      expect(p, isNot(contains('{{CHUNK_START}}')));
    });
  });

  group('segment with retry (no grammar — prompt + validator)', () {
    test('returns validated segments from model JSON', () async {
      final s = _service(FakeLlmBackend(_validJson));
      final segs = await s.segment('[00:00] hello', 0, 480);
      expect(segs, hasLength(6));
      expect(segs.where((e) => e.type == SegmentType.problem), hasLength(2));
    });

    test('retries once after invalid output, then succeeds', () async {
      final llm = SequencedFakeLlmBackend([_overlappingJson, _validJson]);
      final s = _service(llm, maxRetries: 2);
      final segs = await s.segment('[00:00] hello', 0, 480);
      expect(segs, hasLength(6));
      expect(llm.calls, 2);
    });

    test('throws after retries are exhausted', () async {
      final llm = SequencedFakeLlmBackend(
          [_overlappingJson, _overlappingJson, _overlappingJson]);
      final s = _service(llm, maxRetries: 2);
      await expectLater(s.segment('[00:00] hello', 0, 480),
          throwsA(isA<SegmentationException>()));
      expect(llm.calls, 3); // initial + 2 retries
    });
  });
}
