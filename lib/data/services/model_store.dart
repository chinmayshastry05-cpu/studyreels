import 'dart:io';

/// Locates and verifies the on-device LLM bundle.
///
/// The app has no INTERNET permission, so the bundle is pushed once from a
/// dev machine (scripts/push_model.sh) into the app's private files dir:
///   <files>/models/qwen3-0.6b-int4/
class ModelStore {
  static const String modelDirName = 'qwen3-0.6b-int4';
  static const String whisperDirName = 'whisper-base';

  /// Pure function: the exact expected model path for an app files dir.
  /// Unit-tested.
  static String expectedModelPath(String appFilesDir) =>
      '$appFilesDir/models/$modelDirName';

  /// Expected whisper-base bundle dir (pushed via scripts/push_model.sh).
  static String expectedWhisperPath(String appFilesDir) =>
      '$appFilesDir/models/$whisperDirName';

  /// True when the model dir holds a loadable bundle (has config.txt).
  /// A non-empty dir without config.txt is a broken/partial install: the
  /// engine's cactus_init would return null on it, so route to re-download.
  static Future<bool> isModelPresent(String appFilesDir) async {
    return isBundleDir(expectedModelPath(appFilesDir));
  }

  /// True when the whisper bundle dir holds a loadable bundle.
  static Future<bool> isWhisperPresent(String appFilesDir) async {
    return isBundleDir(expectedWhisperPath(appFilesDir));
  }

  /// True when [dirPath] contains a Cactus bundle manifest (config.txt).
  static Future<bool> isBundleDir(String dirPath) async {
    return File('$dirPath/config.txt').exists();
  }

  /// True when [dirPath] exists and contains at least one entry.
  static Future<bool> isDirNonEmpty(String dirPath) async {
    final dir = Directory(dirPath);
    if (!await dir.exists()) return false;
    return (await dir.list().toList()).isNotEmpty;
  }
}
