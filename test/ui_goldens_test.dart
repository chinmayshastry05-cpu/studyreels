import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:studyreels/data/models/reel.dart';
import 'package:studyreels/data/models/segment.dart';
import 'package:studyreels/data/models/transcript.dart';
import 'package:studyreels/data/services/library_store.dart';
import 'package:studyreels/main.dart';
import 'package:studyreels/ui/screens/model_missing_screen.dart';
import 'package:studyreels/ui/screens/permissions_screen.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';

/// Golden screenshots of the main screens (dark + light samples) for design
/// review. Skipped in CI: goldens are machine-local and these screens need
/// real fonts loaded from disk.
final bool inCI = Platform.environment.containsKey('CI');

class FakeVideoPlatform extends VideoPlayerPlatform {
  @override
  Future<int?> create(DataSource dataSource) async => 1;
  @override
  Future<void> dispose(int textureId) async {}
  @override
  Future<void> init() async {}
  @override
  Widget buildView(int textureId) => Container(color: Colors.black);
  @override
  Stream<VideoEvent> videoEventsFor(int textureId) => Stream.value(VideoEvent(
        eventType: VideoEventType.initialized,
        duration: const Duration(minutes: 3),
        size: const Size(720, 1280),
      ));
  @override
  Future<void> play(int textureId) async {}
  @override
  Future<void> pause(int textureId) async {}
  @override
  Future<void> setLooping(int textureId, bool looping) async {}
  @override
  Future<void> setVolume(int textureId, double volume) async {}
  @override
  Future<void> setPlaybackSpeed(int textureId, double speed) async {}
  @override
  Future<void> seekTo(int textureId, Duration position) async {}
  @override
  Future<Duration> getPosition(int textureId) async => Duration.zero;
  @override
  Future<void> setMixWithOthers(bool mixWithOthers) async {}
}

LibraryStore fakeLibrary() {
  final store = LibraryStore(persist: false);
  Reel reel(String id, String title, String chapter, bool problem, int s,
          int e) =>
      Reel(
        id: id,
        videoPath: '/v/lec.mp4',
        chapter: chapter,
        segment: Segment(
            type: problem ? SegmentType.problem : SegmentType.topic,
            title: title,
            startSec: s,
            endSec: e),
        captions: [
          const TranscriptSegment(
              start: 0,
              end: 12,
              text: 'So torque is the rotational equivalent of force.'),
        ],
      );
  store.addReels([
    reel('1', 'Torque and rotational force', 'Rotational Mechanics', false,
        0, 94),
    reel('2', 'Moment of inertia, intuitively', 'Rotational Mechanics',
        false, 94, 210),
    reel('3', 'Pulley with two masses', 'Rotational Mechanics', true, 210,
        360),
    reel('4', 'History of the aeroplane', 'History of Aviation', false, 0,
        150),
    reel('5', 'Lift vs weight problem', 'History of Aviation', true, 150,
        300),
  ]);
  return store;
}

Future<void> loadFonts() async {
  for (final f in [
    'Inter-Regular',
    'Inter-Medium',
    'Inter-SemiBold',
    'Inter-Bold'
  ]) {
    final data = await File('assets/fonts/$f.ttf').readAsBytes();
    final loader = FontLoader('Inter')
      ..addFont(Future.value(ByteData.view(data.buffer)));
    await loader.load();
  }
  final root = Platform.environment['FLUTTER_ROOT']!;
  final icons = await File(
          '$root/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf')
      .readAsBytes();
  final iconLoader = FontLoader('MaterialIcons')
    ..addFont(Future.value(ByteData.view(icons.buffer)));
  await iconLoader.load();
}

Future<void> snap(WidgetTester tester, String name, Widget child,
    {bool dark = true}) async {
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: buildAppTheme(dark ? Brightness.dark : Brightness.light),
    home: child,
  ));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
  await expectLater(
      find.byType(MaterialApp), matchesGoldenFile('goldens/$name.png'));
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await loadFonts();
    VideoPlayerPlatform.instance = FakeVideoPlatform();
    // path_provider + system bridge: safe defaults for screen-only tests.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('plugins.flutter.io/path_provider'),
            (call) async => '/tmp/studyreels-test');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('com.studyreels.app/system'),
            (call) async {
      switch (call.method) {
        case 'missingPermissions':
          return ['android.permission.POST_NOTIFICATIONS'];
        case 'isIgnoringBatteryOptimizations':
          return false;
        default:
          return null;
      }
    });
  });

  testWidgets('feed with reels', (tester) async {
    await snap(
        tester,
        'feed',
        ChangeNotifierProvider.value(
          value: fakeLibrary(),
          child: const HomeShell(),
        ));
  }, skip: inCI);

  testWidgets('library', (tester) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(Brightness.dark),
      home: ChangeNotifierProvider.value(
        value: fakeLibrary(),
        child: const HomeShell(),
      ),
    ));
    await tester.pump();
    await tester.tap(find.text('Library'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await expectLater(
        find.byType(MaterialApp), matchesGoldenFile('goldens/library.png'));
  }, skip: inCI);

  testWidgets('import idle + running', (tester) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(Brightness.dark),
      home: ChangeNotifierProvider.value(
        value: fakeLibrary(),
        child: const HomeShell(),
      ),
    ));
    await tester.pump();
    await tester.tap(find.text('Import'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await expectLater(
        find.byType(MaterialApp), matchesGoldenFile('goldens/import.png'));
  }, skip: inCI);

  testWidgets('model download screen', (tester) async {
    await snap(
        tester,
        'setup',
        ModelMissingScreen(
            expectedPath: '/data/data/com.studyreels.app/files/models',
            onRecheck: () {}));
  }, skip: inCI);

  testWidgets('permissions screen', (tester) async {
    await snap(tester, 'permissions', PermissionsScreen(onDone: () {}));
  }, skip: inCI);

  testWidgets('library light theme', (tester) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(Brightness.light),
      home: ChangeNotifierProvider.value(
        value: fakeLibrary(),
        child: const HomeShell(),
      ),
    ));
    await tester.pump();
    await tester.tap(find.text('Library'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await expectLater(find.byType(MaterialApp),
        matchesGoldenFile('goldens/library_light.png'));
  }, skip: inCI);
}
