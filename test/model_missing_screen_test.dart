import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studyreels/ui/screens/model_missing_screen.dart';

void main() {
  testWidgets('offers the in-app download and keeps the recheck path',
      (tester) async {
    const path =
        '/data/data/com.studyreels.app/files/models/qwen3-0.6b-int4';
    var rechecked = false;
    await tester.pumpWidget(
      MaterialApp(
        home: ModelMissingScreen(
          expectedPath: path,
          onRecheck: () => rechecked = true,
        ),
      ),
    );
    await tester.pump();

    expect(find.textContaining('One-time setup'), findsOneWidget);
    expect(find.textContaining('Download models'), findsOneWidget);

    await tester.tap(find.text('I already have the models'));
    expect(rechecked, isTrue);
  });
}
