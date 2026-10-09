import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:studyreels/data/services/model_store.dart';

void main() {
  group('ModelStore', () {
    test('expectedModelPath points at the app files models dir', () {
      expect(
        ModelStore.expectedModelPath('/data/data/com.studyreels.app/files'),
        '/data/data/com.studyreels.app/files/models/qwen3-0.6b-int4',
      );
    });

    test('isModelPresent is false when the dir is missing', () async {
      final tmp =
          await Directory.systemTemp.createTemp('studyreels_test_');
      try {
        expect(await ModelStore.isModelPresent(tmp.path), isFalse);
      } finally {
        await tmp.delete(recursive: true);
      }
    });

    test('isModelPresent is false when the dir is empty', () async {
      final tmp =
          await Directory.systemTemp.createTemp('studyreels_test_');
      try {
        await Directory(ModelStore.expectedModelPath(tmp.path))
            .create(recursive: true);
        expect(await ModelStore.isModelPresent(tmp.path), isFalse);
      } finally {
        await tmp.delete(recursive: true);
      }
    });

    test('isModelPresent is true when the dir is non-empty', () async {
      final tmp =
          await Directory.systemTemp.createTemp('studyreels_test_');
      try {
        final dir = await Directory(ModelStore.expectedModelPath(tmp.path))
            .create(recursive: true);
        await File('${dir.path}/weights.bin').writeAsString('x');
        expect(await ModelStore.isModelPresent(tmp.path), isTrue);
      } finally {
        await tmp.delete(recursive: true);
      }
    });
  });
}
