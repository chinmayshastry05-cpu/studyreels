import 'dart:convert';

import '../models/segment.dart';
import 'llm_service.dart';

/// Thrown when the model's output fails schema or boundary validation.
class SegmentationException implements Exception {
  final String message;
  const SegmentationException(this.message);

  @override
  String toString() => 'SegmentationException: $message';
}

/// Turns a timestamped transcript chunk into topic/problem segments using
/// the tiny on-device specialist LLM.
///
/// JSON enforcement (Cactus has no GBNF grammar option):
///   1. strict prompt demanding JSON-only output,
///   2. Dart-side parse + boundary validation,
///   3. retry with a repair prompt on validation failure.
class SegmentationService {
  final LlmBackend llm;
  final String promptTemplate;
  final int maxRetries;

  const SegmentationService({
    required this.llm,
    required this.promptTemplate,
    this.maxRetries = 2,
  });

  /// Builds the full prompt for one transcript chunk.
  /// Template placeholders: {{CHUNK_START}}, {{CHUNK_END}}, {{TRANSCRIPT}}.
  String buildPrompt(
      String transcriptChunk, int chunkStartSec, int chunkEndSec) {
    return promptTemplate
        .replaceAll('{{CHUNK_START}}', chunkStartSec.toString())
        .replaceAll('{{CHUNK_END}}', chunkEndSec.toString())
        .replaceAll('{{TRANSCRIPT}}', transcriptChunk);
  }

  /// Runs the LLM and returns validated segments, retrying on validation
  /// failure with a repair prompt.
  Future<List<Segment>> segment(
      String transcriptChunk, int chunkStartSec, int chunkEndSec) async {
    final prompt = buildPrompt(transcriptChunk, chunkStartSec, chunkEndSec);
    String? lastError;
    for (var attempt = 0; attempt <= maxRetries; attempt++) {
      final ask = attempt == 0
          ? prompt
          : '$prompt\n\nYour previous output was invalid: $lastError\n'
              'Output ONLY the corrected JSON object, nothing else.';
      final raw = await llm.generate(ask, maxTokens: 512);
      try {
        return parseAndValidate(raw, chunkStartSec, chunkEndSec);
      } on SegmentationException catch (e) {
        lastError = e.message;
      } on FormatException catch (e) {
        lastError = e.message;
      }
    }
    throw SegmentationException(
        'Model output failed validation after ${maxRetries + 1} attempts: $lastError');
  }

  /// Pure function: parse model JSON and enforce boundary rules.
  /// Rules: valid schema, sorted by start, non-overlapping,
  /// every segment inside [chunkStartSec, chunkEndSec].
  static List<Segment> parseAndValidate(
      String rawJson, int chunkStartSec, int chunkEndSec) {
    final decoded = jsonDecode(rawJson);
    if (decoded is! Map<String, dynamic>) {
      throw const SegmentationException(
          'Top-level JSON must be an object');
    }
    final list = decoded['segments'];
    if (list is! List) {
      throw const SegmentationException('Missing "segments" array');
    }
    if (list.isEmpty) {
      throw const SegmentationException('No segments returned');
    }

    final segments = <Segment>[];
    for (final item in list) {
      if (item is! Map<String, dynamic>) {
        throw const SegmentationException(
            'Segment entry must be an object');
      }
      segments.add(Segment.fromJson(item));
    }

    for (var i = 1; i < segments.length; i++) {
      if (segments[i].startSec < segments[i - 1].startSec) {
        throw const SegmentationException(
            'Segments are not sorted by start time');
      }
    }

    for (var i = 0; i < segments.length; i++) {
      final s = segments[i];
      if (s.startSec < chunkStartSec || s.endSec > chunkEndSec) {
        throw SegmentationException(
            'Segment "${s.title}" [${s.startSec}-${s.endSec}] is outside '
            'chunk range [$chunkStartSec-$chunkEndSec]');
      }
      if (i > 0 && s.startSec < segments[i - 1].endSec) {
        throw SegmentationException(
            'Segments overlap: "${segments[i - 1].title}" and "${s.title}"');
      }
    }
    return segments;
  }
}
