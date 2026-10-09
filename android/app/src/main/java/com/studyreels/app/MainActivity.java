package com.studyreels.app;

import io.flutter.embedding.android.FlutterActivity;

/**
 * Plain Flutter host activity.
 *
 * The on-device LLM (Cactus engine) is reached from Dart directly via FFI
 * (lib/cactus/cactus.dart + libcactus_engine.so in jniLibs/arm64-v8a), so no
 * platform-channel / JNI bridge is needed here.
 */
public class MainActivity extends FlutterActivity {
}
