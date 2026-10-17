import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studyreels/data/services/model_downloader.dart';

void main() {
  group('ModelDownloader', () {
    test('bundle metadata matches the published Hugging Face files', () {
      expect(qwen3Bundle.sizeBytes, 376414357);
      expect(qwen3Bundle.destDirName, 'qwen3-0.6b-int4');
      expect(whisperBundle.sizeBytes, 76245569);
      expect(whisperBundle.destDirName, 'whisper-base');
      expect(totalDownloadBytes,
          qwen3Bundle.sizeBytes + whisperBundle.sizeBytes);
      for (final b in requiredBundles) {
        expect(b.urls.length, greaterThanOrEqualTo(2));
        // GitHub release mirror first (fast CDN), Hugging Face as fallback.
        expect(b.urls.first, startsWith('https://github.com/'));
        expect(b.urls.last, startsWith('https://huggingface.co/'));
        expect(b.sha256.length, 64);
      }
    });

    test('sanitizeError strips URLs and caps length', () {
      const raw = 'HttpException: Connection closed while receiving data, '
          'uri = https://us.aws.cdn.hf.co/xet-bridge/abc?Policy=verylongsignedquery';
      final clean = ModelDownloader.sanitizeError(raw);
      expect(clean, isNot(contains('http')));
      expect(clean, contains('Connection closed'));
      expect(clean.length, lessThanOrEqualTo(120));
      expect(ModelDownloader.sanitizeError('x' * 500).length,
          lessThanOrEqualTo(120));
    });

    test('extractZip unpacks a flat zip into the dest dir', () async {
      final tmp = await Directory.systemTemp.createTemp('studyreels_dl_');
      try {
        final archive = Archive()
          ..addFile(ArchiveFile('config.txt', 4, utf8.encode('cfg1')))
          ..addFile(ArchiveFile('a.weights', 5, utf8.encode('wghts')));
        final zipPath = '${tmp.path}/bundle.zip';
        await File(zipPath)
            .writeAsBytes(ZipEncoder().encode(archive)!, flush: true);

        final dest = '${tmp.path}/models/qwen3-0.6b-int4';
        await ModelDownloader.extractZip(zipPath, dest);

        expect(await File('$dest/config.txt').readAsString(), 'cfg1');
        expect(await File('$dest/a.weights').readAsString(), 'wghts');
      } finally {
        await tmp.delete(recursive: true);
      }
    });

    test('extractZip lifts a single top-level folder', () async {
      final tmp = await Directory.systemTemp.createTemp('studyreels_dl_');
      try {
        final archive = Archive()
          ..addFile(ArchiveFile('wrapped/config.txt', 4, utf8.encode('cfg1')))
          ..addFile(ArchiveFile('wrapped/a.weights', 5, utf8.encode('wghts')));
        final zipPath = '${tmp.path}/bundle.zip';
        await File(zipPath)
            .writeAsBytes(ZipEncoder().encode(archive)!, flush: true);

        final dest = '${tmp.path}/models/whisper-base';
        await ModelDownloader.extractZip(zipPath, dest);

        expect(await File('$dest/config.txt').readAsString(), 'cfg1');
        expect(await File('$dest/a.weights').readAsString(), 'wghts');
      } finally {
        await tmp.delete(recursive: true);
      }
    });
  });
}
