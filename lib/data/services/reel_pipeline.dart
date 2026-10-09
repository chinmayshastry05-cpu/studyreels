import '../models/chapter.dart';
import '../models/reel.dart';
import 'library_store.dart';
import 'llm_service.dart';
import 'segmentation_service.dart';
import 'transcript_chunker.dart';
import 'transcriber.dart';
import 'transcription_service.dart';

/// Pure orchestration: transcript -> chunks -> LLM segments -> reels.
/// All native/IO dependencies are injected; unit-tested with fakes.
Future<List<Reel>> buildReels({
  required Transcriber transcriber,
  required SegmentationService segmentation,
  required int Function(String text) countTokens,
  required String videoPath,
  required String chapterName,
  required void Function(String stage) onProgress,
}) async {
  onProgress('Transcribing audio…');
  final transcript = await transcriber.transcribeVideo(videoPath);
  if (transcript.isEmpty) {
    throw const PipelineException('Transcription produced no segments');
  }

  onProgress('Chunking transcript…');
  final chunks = TranscriptChunker.chunk(transcript, countTokens);

  final reels = <Reel>[];
  for (var i = 0; i < chunks.length; i++) {
    final chunk = chunks[i];
    onProgress('Finding topics & problems (${i + 1}/${chunks.length})…');
    final segments = await segmentation.segment(
      chunk.text,
      chunk.start.toInt(),
      chunk.end.toInt(),
    );
    for (final segment in segments) {
      reels.add(Reel(
        id: '${DateTime.now().millisecondsSinceEpoch}-$i-${segment.startSec}',
        videoPath: videoPath,
        segment: segment,
        chapter: chapterName,
        captions: transcript
            .where((t) =>
                t.start < segment.endSec && t.end > segment.startSec)
            .toList(),
      ));
    }
  }
  if (reels.isEmpty) {
    throw const PipelineException('Segmentation produced no reels');
  }
  return reels;
}

/// Thin production wiring: inits the on-device LLM, runs the pipeline
/// (transcription in a background isolate), saves the reels to the
/// library, disposes the model.
class ReelPipeline {
  final LibraryStore library;
  final String whisperModelDir;
  final String llmModelDir;
  final String promptTemplate;

  ReelPipeline({
    required this.library,
    required this.whisperModelDir,
    required this.llmModelDir,
    required this.promptTemplate,
  });

  Future<Chapter> run({
    required String videoPath,
    required String chapterName,
    required void Function(String stage) onProgress,
  }) async {
    final llm = CactusLlmBackend();
    try {
      onProgress('Loading on-device model…');
      await llm.init(llmModelDir);
      final segmentation = SegmentationService(
        llm: llm,
        promptTemplate: promptTemplate,
      );
      final reels = await buildReels(
        transcriber: BackgroundTranscriber(
          whisperModelDir: whisperModelDir,
          onProgress: onProgress,
        ),
        segmentation: segmentation,
        countTokens: llm.countTokens,
        videoPath: videoPath,
        chapterName: chapterName,
        onProgress: onProgress,
      );
      onProgress('Saving to library…');
      await library.addReels(reels);
      return Chapter(name: chapterName, reels: reels);
    } finally {
      await llm.dispose();
    }
  }
}

class PipelineException implements Exception {
  final String message;
  const PipelineException(this.message);

  @override
  String toString() => 'PipelineException: $message';
}
