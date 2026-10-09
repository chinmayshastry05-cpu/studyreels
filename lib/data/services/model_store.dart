import 'dart:io';

/// Locates and verifies the on-device LLM bundle.
///
/// The app has no INTERNET permission, so the bundle is pushed once from a
/// dev machine (scripts/push_model.sh) into the app's private files dir:
///   <files>/models/qwen3-0.6b-int4/
class ModelStore {
  static const String modelDirName = 'qwen3-0.6b-int4';

  /// Pure function: the exact expected model path for an app files dir.
  /// Unit-tested.
  static String expectedModelPath(String appFilesDir) =>
      '$appFilesDir/models/$modelDirName';

  /// True when the model dir exists and is non-empty.
  static Future<bool> isModelPresent(String appFilesDir) async {
    final dir = Directory(expectedModelPath(appFilesDir));
    if (!await dir.exists()) return false;
    return (await dir.list().toList()).isNotEmpty;
  }
}
