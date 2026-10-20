// ignore_for_file: avoid_print
// Reproducing test for the F55 import bug (v0.2.2-debug-5):
// pick a video in the system picker -> tap Done -> picker closes, app
// stays on the Import screen, no loading, no error, no reel.
//
// Root cause (verified in image_picker_android 0.8.13+25 source):
// while the picker is open, Android may destroy the MainActivity. The
// plugin discards the delegate holding the Dart callback and constructs
// a fresh one; the picker result then lands in the plugin's
// SharedPreferences cache (finishWithSuccess with a null callback calls
// cache.saveResult) and the original pickVideo() future never completes.
// The app never called retrieveLostData(), so the picked file sat in
// the cache unretrieved and the Import screen stayed idle.
//
// The fix: recover the lost pick via retrieveLostData() — on app
// resume (auto-start the import the user already confirmed with Done),
// before launching a new picker, and after a null pick. These tests
// prove the ImportScreen wiring: pick-null + recovery-path must run
// the pipeline; resume must auto-run it; normal pick still works;
// pick-null + recovery-null stays idle (cancel path).

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studyreels/data/models/chapter.dart';
import 'package:studyreels/data/models/reel.dart';
import 'package:studyreels/data/models/segment.dart';
import 'package:studyreels/data/services/video_import_service.dart';
import 'package:studyreels/ui/screens/import_screen.dart';
import 'package:studyreels/ui/widgets/fx.dart';

class _FakeImporter extends VideoImportService {
  String? pickResult;
  bool throwOnPick = false;
  final List<String?> recoverResults = [];
  int recoverCalls = 0;

  @override
  Future<String?> pickLocalVideo() async {
    if (throwOnPick) {
      throw Exception('PlatformException(already_active)');
    }
    return pickResult;
  }

  @override
  Future<String?> recoverLostVideo() async {
    recoverCalls++;
    if (recoverResults.isEmpty) return null;
    return recoverResults.removeAt(0);
  }
}

Chapter _fakeChapter() => const Chapter(
      name: 'Test Chapter',
      reels: [
        Reel(
          id: 'r1',
          videoPath: '/tmp/test.mp4',
          chapter: 'Test Chapter',
          segment: const Segment(
            type: SegmentType.topic,
            title: 'Intro',
            startSec: 0,
            endSec: 30,
          ),
        ),
      ],
    );

Widget _screen({
  required _FakeImporter importer,
  required void Function() onDone,
  required List<String> ranPaths,
}) {
  return MaterialApp(
    home: ImportScreen(
      onDone: onDone,
      importer: importer,
      runner: ({required String videoPath, required void Function(String) onProgress}) async {
        ranPaths.add(videoPath);
        return _fakeChapter();
      },
    ),
  );
}

void main() {
  testWidgets('pick returns null + recovery returns a path runs the pipeline',
      (tester) async {
    final importer = _FakeImporter()
      ..pickResult = null
      ..recoverResults.add('/tmp/recovered.mp4');
    final ranPaths = <String>[];
    var done = false;
    await tester.pumpWidget(_screen(
      importer: importer,
      onDone: () => done = true,
      ranPaths: ranPaths,
    ));
    await tester.pump();

    await tester.tap(find.byType(GlowCard).first);
    await tester.pumpAndSettle();

    // The recovered pick is imported without re-picking.
    expect(ranPaths, ['/tmp/recovered.mp4']);
    expect(done, isTrue);
    expect(find.textContaining('Saved 1 reels'), findsOneWidget);
  });

  testWidgets('app resume auto-runs the pipeline on a recovered pick',
      (tester) async {
    final importer = _FakeImporter()..recoverResults.add('/tmp/resumed.mp4');
    final ranPaths = <String>[];
    var done = false;
    await tester.pumpWidget(_screen(
      importer: importer,
      onDone: () => done = true,
      ranPaths: ranPaths,
    ));
    await tester.pump();

    // The user returns from the picker (Done) -> app resumes.
    TestWidgetsFlutterBinding.instance
        .handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();

    expect(ranPaths, ['/tmp/resumed.mp4']);
    expect(done, isTrue);
  });

  testWidgets('normal pick still runs the pipeline', (tester) async {
    final importer = _FakeImporter()..pickResult = '/tmp/picked.mp4';
    final ranPaths = <String>[];
    var done = false;
    await tester.pumpWidget(_screen(
      importer: importer,
      onDone: () => done = true,
      ranPaths: ranPaths,
    ));
    await tester.pump();

    await tester.tap(find.byType(GlowCard).first);
    await tester.pumpAndSettle();

    expect(ranPaths, ['/tmp/picked.mp4']);
    expect(done, isTrue);
  });

  testWidgets('pick null + recovery null stays idle (cancel path)',
      (tester) async {
    final importer = _FakeImporter()..pickResult = null;
    final ranPaths = <String>[];
    var done = false;
    await tester.pumpWidget(_screen(
      importer: importer,
      onDone: () => done = true,
      ranPaths: ranPaths,
    ));
    await tester.pump();

    await tester.tap(find.byType(GlowCard).first);
    await tester.pumpAndSettle();

    expect(ranPaths, isEmpty);
    expect(done, isFalse);
    expect(find.text('Pick a lecture video'), findsOneWidget);
  });

  testWidgets('picker throwing shows the error card, not a crash',
      (tester) async {
    final importer = _FakeImporter()..throwOnPick = true;
    final ranPaths = <String>[];
    await tester.pumpWidget(_screen(
      importer: importer,
      onDone: () {},
      ranPaths: ranPaths,
    ));
    await tester.pump();

    await tester.tap(find.byType(GlowCard).first);
    await tester.pumpAndSettle();

    expect(ranPaths, isEmpty);
    expect(find.text('Import failed'), findsOneWidget);
    expect(find.textContaining('video picker could not be opened'),
        findsOneWidget);
  });
}

