import 'package:femm_app/screens/lab_upload_screen.dart';
import 'package:femm_app/theme/petal_soft.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('lab upload petal soft empty state', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        theme: PetalSoft.theme(),
        home: const LabUploadScreen(labService: null),
      ),
    );
    await tester.pump();

    expect(find.text('Your health-check labs'), findsOneWidget);
    expect(find.text('Tap to choose a PDF'), findsOneWidget);
    expect(find.text('Choose PDF'), findsOneWidget);
    expect(find.text('Use demo PDF instead'), findsOneWidget);
    expect(find.text('Continue Path A'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
