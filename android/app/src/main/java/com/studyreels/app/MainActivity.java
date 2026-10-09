package com.studyreels.app;

import androidx.annotation.NonNull;

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
    private final ExecutorService bg = Executors.newSingleThreadExecutor();

    @Override
    public void configureFlutterEngine(@NonNull FlutterEngine flutterEngine) {
        super.configureFlutterEngine(flutterEngine);
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

    @Override
    protected void onDestroy() {
        bg.shutdownNow();
        super.onDestroy();
    }
}
