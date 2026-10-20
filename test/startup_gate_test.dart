// Regression test: StartupGate used to ignore FutureBuilder errors, so
// any startup failure (e.g. the documents directory being unavailable)
// left the app on an endless spinner. It must show an error + Retry.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studyreels/main.dart';

void main() {
  testWidgets('startup failure shows an error and Retry, not a spinner',
      (tester) async {
    // Make the documents directory unavailable: startup must fail.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (call) async =>
          throw PlatformException(code: 'unavailable', message: 'no docs'),
    );

    await tester.pumpWidget(const MaterialApp(home: StartupGate()));
    await tester.pumpAndSettle();

    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('StudyReels could not start.'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
  });
}
