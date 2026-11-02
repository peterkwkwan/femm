import 'package:femm_app/screens/lab_upload_screen.dart';
import 'package:femm_app/theme/petal_soft.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('stacked labs cards + encrypted storage copy', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        theme: PetalSoft.theme(),
        home: const LabUploadScreen(labService: null),
      ),
    );
    await tester.pump();

    expect(find.text('LABS · STEP 1 OF 4'), findsOneWidget);
    expect(find.text('Your health-check labs'), findsOneWidget);
    expect(find.text('Upload PDF'), findsOneWidget);
    expect(find.text('Take a photo'), findsOneWidget);
    expect(find.text('Prototype · camera won’t open'), findsOneWidget);
    expect(find.text(LabUploadScreen.storageHelperCopy), findsOneWidget);
    expect(
      find.text('Original PDF is stored privately for later Path C download.'),
      findsNothing,
    );

    await tester.tap(find.text('Take a photo'));
    await tester.pump();
    expect(find.text('Camera isn’t wired in this prototype.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
