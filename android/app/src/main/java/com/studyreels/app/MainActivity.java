package com.studyreels.app;

import android.Manifest;
import android.app.NotificationManager;
import android.content.Intent;
import android.content.pm.PackageManager;
import android.net.Uri;
import android.os.Build;
import android.os.PowerManager;
import android.provider.Settings;

import androidx.annotation.NonNull;
import androidx.core.app.ActivityCompat;
import androidx.core.content.ContextCompat;

import java.util.ArrayList;
import java.util.List;

import java.io.File;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;

import io.flutter.embedding.android.FlutterActivity;
import io.flutter.embedding.engine.FlutterEngine;
import io.flutter.plugin.common.MethodChannel;

/**
 * Plain Flutter host activity plus one platform channel:
 *
 * - "com.studyreels.app/audio" / "extractWav": decodes the audio track of a
 *   video file to a 16 kHz mono WAV (see AudioExtractor) for cactus_transcribe.
 *   Runs on a background thread; the WAV lands in the app cache dir.
 *
 * The on-device LLM itself is reached from Dart directly via FFI
 * (lib/cactus/cactus.dart + libcactus_engine.so in jniLibs/arm64-v8a), so no
 * JNI bridge is needed for inference.
 */
public class MainActivity extends FlutterActivity {
    private static final String AUDIO_CHANNEL = "com.studyreels.app/audio";
    private static final String EXPORT_CHANNEL = "com.studyreels.app/export";
    private static final String SYSTEM_CHANNEL = "com.studyreels.app/system";
    private static final int REQ_PERMS = 7001;
    private MethodChannel.Result pendingPerms;
    private final ExecutorService bg = Executors.newSingleThreadExecutor();

    @Override
    public void configureFlutterEngine(@NonNull FlutterEngine flutterEngine) {
        super.configureFlutterEngine(flutterEngine);
        final MethodChannel sys = new MethodChannel(
                flutterEngine.getDartExecutor().getBinaryMessenger(),
                SYSTEM_CHANNEL);
        sys.setMethodCallHandler((call, result) -> {
            switch (call.method) {
                case "unzip": {
                    String zip = call.argument("zip");
                    String dest = call.argument("dest");
                    if (zip == null || dest == null) {
                        result.error("BAD_ARGS", "zip and dest required", null);
                        break;
                    }
                    bg.execute(() -> {
                        try {
                            final long[] last = {0};
                            Unzipper.unzip(zip, dest, (d, t, name) -> {
                                long now = System.currentTimeMillis();
                                if (d != t && now - last[0] < 100) return;
                                last[0] = now;
                                java.util.HashMap<String, Object> m =
                                        new java.util.HashMap<>();
                                m.put("done", d);
                                m.put("total", t);
                                m.put("name", name);
                                runOnUiThread(() ->
                                        sys.invokeMethod("unzipProgress", m));
                            });
                            runOnUiThread(() -> result.success(true));
                        } catch (Exception e) {
                            runOnUiThread(() -> result.error("UNZIP_FAILED",
                                    String.valueOf(e.getMessage()), null));
                        }
                    });
                    break;
                }
                case "unzipCancel":
                    Unzipper.cancelled = true;
                    result.success(true);
                    break;
                case "missingPermissions":
                    result.success(missingPermissions());
                    break;
                case "requestPermissions": {
                    List<String> missing = missingPermissions();
                    if (missing.isEmpty()) {
                        result.success(true);
                    } else if (pendingPerms != null) {
                        result.error("BUSY", "request in progress", null);
                    } else {
                        pendingPerms = result;
                        ActivityCompat.requestPermissions(this,
                                missing.toArray(new String[0]), REQ_PERMS);
                    }
                    break;
                }
                case "isIgnoringBattery": {
                    PowerManager pm = (PowerManager) getSystemService(POWER_SERVICE);
                    result.success(pm.isIgnoringBatteryOptimizations(getPackageName()));
                    break;
                }
                case "requestIgnoreBattery": {
                    try {
                        Intent i = new Intent(
                                Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS,
                                Uri.parse("package:" + getPackageName()));
                        startActivity(i);
                        result.success(true);
                    } catch (Exception e) {
                        result.success(false);
                    }
                    break;
                }
                case "startService":
                case "updateService": {
                    String title = call.argument("title");
                    String text = call.argument("text");
                    Number pct = call.argument("percent");
                    Intent i = new Intent(this, DownloadService.class);
                    i.setAction(call.method.equals("startService")
                            ? DownloadService.ACTION_START
                            : DownloadService.ACTION_UPDATE);
                    i.putExtra("title", title);
                    i.putExtra("text", text);
                    i.putExtra("percent", pct == null ? -1 : pct.intValue());
                    try {
                        if (call.method.equals("startService")
                                && Build.VERSION.SDK_INT >= 26) {
                            startForegroundService(i);
                        } else {
                            startService(i);
                        }
                        result.success(true);
                    } catch (Exception e) {
                        result.success(false);
                    }
                    break;
                }
                case "stopService": {
                    Intent i = new Intent(this, DownloadService.class);
                    i.setAction(DownloadService.ACTION_STOP);
                    try {
                        startService(i);
                    } catch (Exception ignored) {
                    }
                    result.success(true);
                    break;
                }
                case "notifyDone": {
                    String title = call.argument("title");
                    String text = call.argument("text");
                    DownloadService.ensureChannels(this);
                    boolean ok = call.argument("ok") == null
                            || Boolean.TRUE.equals(call.argument("ok"));
                    android.app.Notification n = DownloadService.build(this,
                            title == null ? "StudyReels" : title,
                            text == null ? "" : text, -1, false,
                            DownloadService.CH_DONE);
                    try {
                        getSystemService(NotificationManager.class)
                                .notify(DownloadService.ID_DONE, n);
                    } catch (Exception ignored) {
                    }
                    result.success(ok);
                    break;
                }
                default:
                    result.notImplemented();
            }
        });
        new MethodChannel(
                flutterEngine.getDartExecutor().getBinaryMessenger(),
                EXPORT_CHANNEL).setMethodCallHandler((call, result) -> {
            if (call.method.equals("exportClip")) {
                String videoPath = call.argument("videoPath");
                // Dart numbers may decode as Double or Long — normalize.
                Number startNum = call.argument("startSec");
                Number endNum = call.argument("endSec");
                if (videoPath == null || startNum == null || endNum == null) {
                    result.error("BAD_ARGS",
                            "videoPath, startSec, endSec are required", null);
                    return;
                }
                final double startSec = startNum.doubleValue();
                final double endSec = endNum.doubleValue();
                bg.execute(() -> {
                    try {
                        String uri = VideoExporter.exportClip(
                                this, videoPath, startSec, endSec);
                        runOnUiThread(() -> result.success(uri));
                    } catch (Exception e) {
                        runOnUiThread(() -> result.error(
                                "EXPORT_FAILED", String.valueOf(e.getMessage()),
                                null));
                    }
                });
            } else {
                result.notImplemented();
            }
        });
        new MethodChannel(
                flutterEngine.getDartExecutor().getBinaryMessenger(),
                AUDIO_CHANNEL).setMethodCallHandler((call, result) -> {
            if (call.method.equals("extractWav")) {
                String videoPath = call.argument("videoPath");
                if (videoPath == null || videoPath.isEmpty()) {
                    result.error("BAD_ARGS", "videoPath is required", null);
                    return;
                }
                bg.execute(() -> {
                    try {
                        File out = new File(getCacheDir(),
                                "audio_" + System.currentTimeMillis() + ".wav");
                        String wav = AudioExtractor.extractWav(
                                videoPath, out.getAbsolutePath());
                        runOnUiThread(() -> result.success(wav));
                    } catch (Exception e) {
                        runOnUiThread(() -> result.error(
                                "EXTRACT_FAILED", String.valueOf(e.getMessage()),
                                null));
                    }
                });
            } else {
                result.notImplemented();
            }
        });
    }

    private List<String> missingPermissions() {
        List<String> need = new ArrayList<>();
        if (Build.VERSION.SDK_INT >= 33) {
            need.add(Manifest.permission.POST_NOTIFICATIONS);
            need.add(Manifest.permission.READ_MEDIA_VIDEO);
        } else if (Build.VERSION.SDK_INT >= 23) {
            need.add(Manifest.permission.READ_EXTERNAL_STORAGE);
        }
        if (Build.VERSION.SDK_INT <= 28) {
            need.add(Manifest.permission.WRITE_EXTERNAL_STORAGE);
        }
        List<String> missing = new ArrayList<>();
        for (String p : need) {
            if (ContextCompat.checkSelfPermission(this, p)
                    != PackageManager.PERMISSION_GRANTED) {
                missing.add(p);
            }
        }
        return missing;
    }

    @Override
    public void onRequestPermissionsResult(int requestCode,
            @NonNull String[] permissions, @NonNull int[] grantResults) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults);
        if (requestCode == REQ_PERMS && pendingPerms != null) {
            MethodChannel.Result r = pendingPerms;
            pendingPerms = null;
            r.success(missingPermissions().isEmpty());
        }
    }

    @Override
    protected void onDestroy() {
        bg.shutdownNow();
        super.onDestroy();
    }
}
