import 'dart:convert';
import 'dart:ffi';

import 'package:ffi/ffi.dart';

import '../../cactus/cactus.dart' as cactus;

/// Errors from the on-device LLM backend.
class LlmException implements Exception {
  final String message;
  const LlmException(this.message);

  @override
  String toString() => 'LlmException: $message';
}

class LlmNotLoadedException extends LlmException {
  const LlmNotLoadedException()
      : super('Model is not loaded. Call init() with a valid model path first.');
}

/// Abstraction over the native engine so segmentation logic can be
/// unit-tested without native code.
///
/// NOTE: Cactus completion options have no GBNF grammar support, so JSON is
/// enforced by a strict prompt plus Dart-side validation with retry
/// (see SegmentationService). The grammar file from the earlier llama.cpp
/// design was removed for this reason.
abstract class LlmBackend {
  Future<bool> get isReady;
  Future<void> init(String modelPath);
  Future<String> generate(String prompt, {int maxTokens = 512});
  Future<void> dispose();
}

/// Production backend: Cactus engine via Dart FFI.
///
/// 100% LOCAL POLICY (locked):
/// - Every cactusComplete call passes {"auto_handoff": false}.
/// - Never set a Cactus cloud API key. Never enable telemetry.
/// - Every response is asserted to have cloud_handoff == false (fail closed:
///   a missing field is treated as a violation).
class CactusLlmBackend implements LlmBackend {
  cactus.CactusModelT _model = nullptr;
  bool _ready = false;

  /// Validates a Cactus return code. Per the engine source (cactus_complete
  /// in the pinned third_party/cactus submodule), completion calls return
  /// the NUMBER OF BYTES WRITTEN on success (positive) and a negative value
  /// on error — so only rc < 0 is a failure. Pure function — unit-tested.
  static void checkOk(int rc, String what) {
    if (rc < 0) {
      throw LlmException('$what failed with code $rc');
    }
  }

  /// Builds the completion options. Pure function — unit-tested to always
  /// carry "auto_handoff": false.
  static Map<String, Object?> buildCompletionOptions(
      {required int maxTokens}) {
    return {
      'max_tokens': maxTokens,
      'temperature': 0.2,
      'auto_handoff': false, // LOCAL ONLY: never hand off to cloud.
    };
  }

  /// Extracts the assistant text from a cactus_complete response envelope.
  /// Throws if cloud_handoff is not exactly false. Pure function —
  /// unit-tested.
  static String extractAssistantText(String responseJson) {
    final decoded = jsonDecode(responseJson);
    if (decoded is! Map<String, dynamic>) {
      throw const LlmException('Malformed engine response envelope');
    }
    if (decoded['cloud_handoff'] != false) {
      throw const LlmException(
          'Cloud handoff detected or unconfirmed — refusing (local-only policy).');
    }
    if (decoded['success'] != true) {
      throw LlmException('Generation failed: ${decoded['error']}');
    }
    final text = decoded['response'];
    if (text is! String || text.trim().isEmpty) {
      throw const LlmException('Engine returned empty text');
    }
    return text;
  }

  @override
  Future<bool> get isReady async => _ready;

  @override
  Future<void> init(String modelPath) async {
    if (_ready) return;
    final pathPtr = modelPath.toNativeUtf8();
    try {
      _model = cactus.cactusInit(pathPtr.cast(), nullptr, false);
      if (_model == nullptr) {
        throw const LlmException('cactus_init returned null model handle');
      }
      _ready = true;
    } finally {
      calloc.free(pathPtr);
    }
  }

  @override
  Future<String> generate(String prompt, {int maxTokens = 512}) async {
    if (!_ready || _model == nullptr) {
      throw const LlmNotLoadedException();
    }
    final messages =
        jsonEncode([{'role': 'user', 'content': prompt}]).toNativeUtf8();
    final options =
        jsonEncode(buildCompletionOptions(maxTokens: maxTokens)).toNativeUtf8();
    final buf = calloc<Int8>(65536);
    try {
      final rc = cactus.cactusComplete(
        _model,
        messages.cast(),
        buf.cast(),
        65536,
        options.cast(),
        nullptr, // toolsJson
        nullptr, // streaming callback
        nullptr, // userData
        nullptr, // pcmBuffer
        0, // pcmBufferSize
      );
      checkOk(rc, 'cactus_complete');
      final responseJson = buf.cast<Utf8>().toDartString();
      return extractAssistantText(responseJson);
    } finally {
      calloc.free(messages);
      calloc.free(options);
      calloc.free(buf);
    }
  }

  /// Token count for [text] using the loaded model's own tokenizer.
  /// Used to size transcript chunks (1.2K–2K tokens) accurately.
  /// Returns the required token count without copying tokens: a NULL buffer
  /// query per the cactus_tokenize docs (rc 0 = ok, -2 = buffer too small,
  /// both set out_len).
  int countTokens(String text) {
    if (!_ready || _model == nullptr) {
      throw const LlmNotLoadedException();
    }
    final textPtr = text.toNativeUtf8();
    final outLen = calloc<IntPtr>();
    try {
      final rc = cactus.cactusTokenize(
        _model,
        textPtr.cast(),
        nullptr.cast<Uint32>(),
        0,
        outLen,
      );
      if (rc != 0 && rc != -2) {
        throw LlmException('cactus_tokenize failed with code $rc');
      }
      return outLen.value;
    } finally {
      calloc.free(textPtr);
      calloc.free(outLen);
    }
  }

  @override
  Future<void> dispose() async {
    if (_model != nullptr) {
      cactus.cactusDestroy(_model);
      _model = nullptr;
    }
    _ready = false;
  }
}

/// Test fake: returns canned output, no native code involved.
class FakeLlmBackend implements LlmBackend {
  final String cannedOutput;
  bool _ready = true;

  FakeLlmBackend(this.cannedOutput);

  @override
  Future<bool> get isReady async => _ready;

  @override
  Future<void> init(String modelPath) async {
    _ready = true;
  }

  @override
  Future<String> generate(String prompt, {int maxTokens = 512}) async {
    return cannedOutput;
  }

  @override
  Future<void> dispose() async {
    _ready = false;
  }
}

/// Test fake: returns a sequence of outputs, one per generate() call.
class SequencedFakeLlmBackend implements LlmBackend {
  final List<String> outputs;
  int _calls = 0;
  int get calls => _calls;

  SequencedFakeLlmBackend(this.outputs);

  @override
  Future<bool> get isReady async => true;

  @override
  Future<void> init(String modelPath) async {}

  @override
  Future<String> generate(String prompt, {int maxTokens = 512}) async {
    final out = outputs[_calls.clamp(0, outputs.length - 1)];
    _calls++;
    return out;
  }

  @override
  Future<void> dispose() async {}
}
