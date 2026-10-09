import 'package:flutter_test/flutter_test.dart';
import 'package:studyreels/data/services/llm_service.dart';

/// Locked rule: 100% LOCAL. Every completion must pass
/// {"auto_handoff": false}, and every response must confirm
/// cloud_handoff == false (fail closed).
void main() {
  group('local-only policy', () {
    test('completion options always disable cloud handoff', () {
      final opts =
          CactusLlmBackend.buildCompletionOptions(maxTokens: 512);
      expect(opts['auto_handoff'], isFalse);
      expect(opts['max_tokens'], 512);
    });

    test('accepts a local response (cloud_handoff == false)', () {
      const response =
          '{"success":true,"error":null,"cloud_handoff":false,'
          '"response":"{\\"segments\\":[]}","function_calls":[]}';
      final text = CactusLlmBackend.extractAssistantText(response);
      expect(text, contains('segments'));
    });

    test('rejects a cloud-handoff response', () {
      const response =
          '{"success":true,"error":null,"cloud_handoff":true,'
          '"response":"hello"}';
      expect(() => CactusLlmBackend.extractAssistantText(response),
          throwsA(isA<LlmException>()));
    });

    test('rejects a response missing the cloud_handoff field', () {
      const response = '{"success":true,"response":"hello"}';
      expect(() => CactusLlmBackend.extractAssistantText(response),
          throwsA(isA<LlmException>()));
    });

    test('rejects a failed generation', () {
      const response =
          '{"success":false,"error":"oom","cloud_handoff":false}';
      expect(() => CactusLlmBackend.extractAssistantText(response),
          throwsA(isA<LlmException>()));
    });
  });
}
