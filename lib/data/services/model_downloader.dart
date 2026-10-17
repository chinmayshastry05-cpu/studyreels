import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:archive/archive_io.dart';
import 'package:crypto/crypto.dart';

import 'system_bridge.dart';

/// One downloadable on-device model bundle (a Cactus .weights zip, Apache-2.0,
/// public and ungated). [urls] lists identical mirrors in preference order:
/// the GitHub release asset first (fast CDN), the Hugging Face original as
/// fallback. Bytes are identical across mirrors, so a partial download
/// resumes seamlessly on the next mirror, and the sha-256 check guarantees
/// integrity regardless of which mirror served the bytes.
class ModelBundle {
  final String label;
  final List<String> urls;
  final String destDirName;
  final int sizeBytes;
  final String sha256;

  const ModelBundle({
    required this.label,
    required this.urls,
    required this.destDirName,
    required this.sizeBytes,
    required this.sha256,
  });
}

/// The two bundles the app needs. Downloaded once on first launch, then the
/// app runs 100% on-device (inference never touches the network).
const qwen3Bundle = ModelBundle(
  label: 'Language model (Qwen3 0.6B int4)',
  urls: [
    'https://github.com/chinmayshastry05-cpu/studyreels/releases/download/models-v1/qwen3-0.6b-int4.zip',
    'https://huggingface.co/Cactus-Compute/Qwen3-0.6B/resolve/main/weights/qwen3-0.6b-int4.zip',
  ],
  destDirName: 'qwen3-0.6b-int4',
  sizeBytes: 376414357,
  sha256: '2f4f5e3b91fc62168e66a592d09cfd1792a0b96e1994d46b5de77ddebbf94427',
);

const whisperBundle = ModelBundle(
  label: 'Speech model (whisper-base int4)',
  urls: [
    'https://github.com/chinmayshastry05-cpu/studyreels/releases/download/models-v1/whisper-base-int4.zip',
    'https://huggingface.co/Cactus-Compute/whisper-base/resolve/main/weights/whisper-base-int4.zip',
  ],
  destDirName: 'whisper-base',
  sizeBytes: 76245569,
  sha256: '3c3cd19ad9499a31ebc3a9c7833d718bb841d48e871e57db4024d7666aa8bbe7',
);

const requiredBundles = [qwen3Bundle, whisperBundle];

final int totalDownloadBytes =
    requiredBundles.fold(0, (sum, b) => sum + b.sizeBytes);

class ModelDownloadException implements Exception {
  final String message;
  const ModelDownloadException(this.message);
  @override
  String toString() => message;
}

/// A mirror answered with an HTTP status we cannot download from. Retrying
/// the same mirror will not help; move straight to the next one.
class _StatusException implements Exception {
  final int statusCode;
  const _StatusException(this.statusCode);
}

/// Download progress phases, surfaced by the UI.
enum DownloadPhase { downloading, verifying, extracting }

typedef ProgressCallback = void Function(
  DownloadPhase phase,
  String label,
  int receivedBytes,
  int totalBytes,
);

/// Downloads the model bundles straight to the phone, with resume support.
///
/// Layout inside the app files dir:
///   models/<destDirName>/            extracted bundle (what Cactus loads)
///   models/.downloads/<dest>.part    partial zip, kept between retries
class ModelDownloader {
  /// Each mirror is tried this many times (resuming where it stopped)
  /// before the next mirror takes over.
  static const int attemptsPerMirror = 3;

  void Function(String line)? _log;

  /// No unzip progress for this long means the unpack is stuck.
  static const Duration unpackStall = Duration(seconds: 90);

  final String appFilesDir;
  final HttpClient Function() clientFactory;

  ModelDownloader(this.appFilesDir, {HttpClient Function()? clientFactory})
      : clientFactory = clientFactory ?? HttpClient.new;

  String _partPath(ModelBundle b) =>
      '$appFilesDir/models/.downloads/${b.destDirName}.part';

  String _destPath(ModelBundle b) => '$appFilesDir/models/${b.destDirName}';

  /// True when the extracted bundle dir exists and is non-empty.
  Future<bool> isInstalled(ModelBundle b) async {
    final dir = Directory(_destPath(b));
    if (!await dir.exists()) return false;
    return (await dir.list().toList()).isNotEmpty;
  }

  /// Total bytes still to download across all bundles (for the UI total).
  Future<int> remainingBytes() async {
    var remaining = 0;
    for (final b in requiredBundles) {
      if (await isInstalled(b)) continue;
      final part = File(_partPath(b));
      final have = await part.exists() ? await part.length() : 0;
      remaining += b.sizeBytes - (have < b.sizeBytes ? have : 0);
    }
    return remaining;
  }

  /// Downloads and extracts every bundle that is not yet installed.
  /// Resumes any .part file left by an earlier attempt. Throws
  /// [ModelDownloadException] on failure; retrying picks up where it left off.
  Future<void> ensureInstalled(ProgressCallback onProgress,
      {void Function(String line)? onLog}) async {
    _log = onLog;
    var doneBefore = 0;
    for (final b in requiredBundles) {
      if (await isInstalled(b)) {
        doneBefore += b.sizeBytes;
        continue;
      }
      final part = File(_partPath(b));
      await part.parent.create(recursive: true);
      await _download(b, part, (received) {
        onProgress(DownloadPhase.downloading, b.label,
            doneBefore + received, totalDownloadBytes);
      });
      onProgress(DownloadPhase.verifying, b.label,
          doneBefore + b.sizeBytes, totalDownloadBytes);
      _log?.call('sha256sum ${b.destDirName}.zip ...');
      await _verify(b, part);
      _log?.call('sha256 OK ${b.sha256.substring(0, 16)}...');
      onProgress(DownloadPhase.extracting, b.label,
          doneBefore + b.sizeBytes, totalDownloadBytes);
      _log?.call('unzip ${b.destDirName}.zip');
      await _extractWithRetry(b, part);
      _log?.call('installed ${b.destDirName}');
      await part.delete();
      doneBefore += b.sizeBytes;
    }
  }

  /// Strips embedded request URLs and caps length, so an error shown in the
  /// UI stays short and readable (CDN URLs carry huge signed query strings).
  static String sanitizeError(Object error) {
    var s = error.toString();
    s = s.replaceAll(RegExp(r',?\s*uri\s*=\s*\S+'), '');
    s = s.trim();
    if (s.isEmpty) return 'network error';
    if (s.length > 120) s = '${s.substring(0, 117)}...';
    return s;
  }

  /// Tries each mirror in turn, resuming the .part file on every attempt.
  Future<void> _download(ModelBundle b, File part,
      void Function(int received) onChunk) async {
    Object? lastError;
    for (final url in b.urls) {
      for (var attempt = 0; attempt < attemptsPerMirror; attempt++) {
        try {
          await _downloadOnce(url, b, part, onChunk);
          return;
        } on _StatusException catch (e) {
          // This mirror cannot serve the file; try the next mirror now.
          lastError = 'server answered HTTP ${e.statusCode}';
          break;
        } catch (e) {
          // Dropped connection, timeout, DNS... wait a moment and resume
          // on the same mirror.
          lastError = e;
          await Future<void>.delayed(Duration(seconds: 1 << attempt));
        }
      }
    }
    throw ModelDownloadException(
        'Download interrupted (${sanitizeError(lastError ?? 'network error')}). '
        'Tap Retry - it resumes where it stopped.');
  }

  /// One attempt against one mirror. Resumes the .part file when the server
  /// honors the Range header; otherwise restarts it. Throws on any failure.
  Future<void> _downloadOnce(String url, ModelBundle b, File part,
      void Function(int received) onChunk) async {
    final resumeFrom = await part.exists() ? await part.length() : 0;
    if (resumeFrom >= b.sizeBytes && resumeFrom > 0) return; // already complete
    final client = clientFactory();
    try {
      final request = await client.getUrl(Uri.parse(url));
      if (resumeFrom > 0) {
        request.headers.set(HttpHeaders.rangeHeader, 'bytes=$resumeFrom-');
      }
      final response = await request.close();
      IOSink sink;
      var received = resumeFrom;
      if (response.statusCode == HttpStatus.partialContent && resumeFrom > 0) {
        sink = part.openWrite(mode: FileMode.append);
      } else if (response.statusCode == HttpStatus.ok) {
        sink = part.openWrite(); // restart from scratch
        received = 0;
      } else {
        throw _StatusException(response.statusCode);
      }
      try {
        await for (final chunk in response) {
          sink.add(chunk);
          received += chunk.length;
          onChunk(received);
        }
        await sink.flush();
      } finally {
        await sink.close();
      }
    } finally {
      client.close();
    }
  }

  Future<void> _verify(ModelBundle b, File part) async {
    final length = await part.length();
    if (length != b.sizeBytes) {
      throw const ModelDownloadException(
          'Download incomplete. Tap retry to resume.');
    }
    final digest = await sha256.bind(part.openRead()).first;
    if (digest.toString() != b.sha256) {
      await part.delete(); // corrupt; do not resume from it
      throw const ModelDownloadException(
          'Downloaded file failed the integrity check and was deleted. Tap retry to download it again.');
    }
  }

  /// Extracts the zip into models/<destDirName>/ (atomically via a temp dir).
  Future<void> _extract(ModelBundle b, File part) => extractZip(
      part.path, _destPath(b),
      onFile: (d, t, name) => _log?.call('  inflating [$d/$t] $name'),
      stall: unpackStall);

  /// One automatic retry if the unpack fails or stalls.
  Future<void> _extractWithRetry(ModelBundle b, File part) async {
    try {
      await _extract(b, part);
    } catch (e) {
      _log?.call('unpack failed (${sanitizeError(e)}), retrying once');
      await _extract(b, part);
    }
  }

  /// Dart fallback unzip, in its own top-level-style scope so the isolate
  /// closure captures only two strings.
  static Future<void> _dartUnzip(String zipPath, String outPath) =>
      Isolate.run(() {
        extractFileToDisk(zipPath, outPath);
      });

  /// Extracts [zipPath] into [destPath] (atomically via a temp dir next to
  /// it). If the zip wraps everything in a single top-level folder, that
  /// folder is lifted. Public so it is unit-testable without the network.
  static Future<void> extractZip(String zipPath, String destPath,
      {void Function(int done, int total, String name)? onFile,
      Duration stall = const Duration(seconds: 90)}) async {
    final part = File(zipPath);
    final dest = Directory(destPath);
    final tmp = Directory('$destPath.extract');
    if (await tmp.exists()) await tmp.delete(recursive: true);
    await tmp.create(recursive: true);
    try {
      final partPath = part.path;
      final tmpPath = tmp.path;
      // Prefer the native streaming unzip (fast, per-file progress, no big
      // in-memory archive). Fall back to the Dart unzip off-device.
      var last = DateTime.now();
      final native = SystemBridge.unzip(partPath, tmpPath, (d, t, name) {
        last = DateTime.now();
        onFile?.call(d, t, name);
      });
      native.ignore();
      final watchdog = Completer<bool>();
      final timer = Timer.periodic(const Duration(seconds: 5), (_) {
        if (!watchdog.isCompleted &&
            DateTime.now().difference(last) > stall) {
          SystemBridge.cancelUnzip();
          watchdog.completeError(
              const ModelDownloadException('Unpacking stalled (no progress).'));
        }
      });
      bool usedNative;
      try {
        usedNative = await Future.any([native, watchdog.future]);
      } finally {
        timer.cancel();
      }
      if (!usedNative) {
        // extractFileToDisk is CPU-bound; keep it off the UI isolate.
        await _dartUnzip(partPath, tmpPath);
      }

      // If the zip wrapped everything in a single top-level folder, lift it.
      final entries = await tmp.list().toList();
      Directory source = tmp;
      if (entries.length == 1 && entries.single is Directory) {
        source = entries.single as Directory;
      }
      if (await dest.exists()) await dest.delete(recursive: true);
      await source.rename(dest.path);
      if (source.path != tmp.path && await tmp.exists()) {
        await tmp.delete(recursive: true);
      }
    } catch (e) {
      if (await tmp.exists()) await tmp.delete(recursive: true);
      throw ModelDownloadException(
          'Could not unpack the model. Tap retry. ($e)');
    }
  }
}
