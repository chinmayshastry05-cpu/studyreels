import 'package:flutter/services.dart';

/// Thin wrapper over the Android side (permissions, foreground download
/// service, notifications). Every call is safe off-device: on any failure
/// (tests, other platforms) it returns a harmless default.
class SystemBridge {
  static const MethodChannel _ch = MethodChannel('com.studyreels.app/system');

  static void Function(int done, int total, String name)? _onUnzip;
  static bool _handlerSet = false;

  static void _ensureHandler() {
    if (_handlerSet) return;
    _handlerSet = true;
    _ch.setMethodCallHandler((call) async {
      if (call.method == 'unzipProgress') {
        final a = Map<Object?, Object?>.from(call.arguments as Map);
        _onUnzip?.call((a['done'] as num).toInt(), (a['total'] as num).toInt(),
            a['name'].toString());
      }
      return null;
    });
  }

  /// Native streaming unzip. Returns false when the native side is not
  /// available (tests, non-Android) so the caller can fall back to Dart.
  /// Throws on a real unzip failure.
  static Future<bool> unzip(String zip, String dest,
      void Function(int done, int total, String name) onProgress) async {
    _ensureHandler();
    _onUnzip = onProgress;
    try {
      await _ch.invokeMethod<bool>('unzip', {'zip': zip, 'dest': dest});
      return true;
    } on MissingPluginException {
      return false;
    } finally {
      _onUnzip = null;
    }
  }

  static Future<void> cancelUnzip() => _call<bool>('unzipCancel');

  static Future<T?> _call<T>(String method, [Map<String, Object?>? args]) async {
    try {
      return await _ch.invokeMethod<T>(method, args);
    } catch (_) {
      return null;
    }
  }

  /// Runtime permissions the app needs that are not granted yet.
  static Future<List<String>> missingPermissions() async {
    final r = await _call<List<Object?>>('missingPermissions');
    return (r ?? const []).map((e) => e.toString()).toList();
  }

  /// Shows the system permission dialogs. True when everything is granted.
  static Future<bool> requestPermissions() async =>
      (await _call<bool>('requestPermissions')) ?? true;

  static Future<bool> isIgnoringBatteryOptimizations() async =>
      (await _call<bool>('isIgnoringBattery')) ?? true;

  static Future<void> requestIgnoreBatteryOptimizations() =>
      _call<bool>('requestIgnoreBattery');

  static Future<void> startDownloadService(String title, String text) =>
      _call<bool>('startService', {'title': title, 'text': text, 'percent': -1});

  static Future<void> updateDownloadService(
          String title, String text, int percent) =>
      _call<bool>(
          'updateService', {'title': title, 'text': text, 'percent': percent});

  static Future<void> stopDownloadService() => _call<bool>('stopService');

  static Future<void> notifyDone(String title, String text, bool ok) =>
      _call<bool>('notifyDone', {'title': title, 'text': text, 'ok': ok});
}
