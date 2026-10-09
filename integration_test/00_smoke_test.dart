import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

/// Harness smoke test — runs FIRST (filename order) and pumps only a bare
/// MaterialApp, no StudyReels code at all.
///
/// If this hangs/fails, the problem is the test harness, the VM-service
/// connection, or the emulator itself — not our app startup. If this
/// passes and app_test.dart hangs, the problem is in our startup path.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('harness smoke: pumps a bare MaterialApp', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: Text('smoke')),
    ));
    expect(find.text('smoke'), findsOneWidget);
  }, timeout: const Timeout(Duration(minutes: 2)));
}
