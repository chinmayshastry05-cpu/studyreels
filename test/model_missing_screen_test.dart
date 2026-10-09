import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studyreels/ui/screens/model_missing_screen.dart';

void main() {
  testWidgets('shows the exact expected model path', (tester) async {
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

    expect(find.textContaining('Model not found'), findsOneWidget);
    expect(find.text(path), findsOneWidget);
    expect(find.textContaining('push_model.sh'), findsOneWidget);

    await tester.tap(find.text('Recheck'));
    expect(rechecked, isTrue);
  });
}
