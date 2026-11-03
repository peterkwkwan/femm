import 'package:femm_app/theme/petal_soft.dart';
import 'package:femm_app/widgets/path_a_step_header.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Path A step rail uses 4 steps with icon-node captions',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    Future<void> pumpStep(PathAStep step) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: PetalSoft.theme(),
          home: Scaffold(body: PathAStepHeader(step: step)),
        ),
      );
      await tester.pump();
    }

    await pumpStep(PathAStep.labs);
    expect(find.text('LABS · STEP 1 OF 4'), findsOneWidget);
    expect(find.text('Step 1 · Labs'), findsOneWidget);
    expect(PathAStepHeader.totalSteps, 4);

    await pumpStep(PathAStep.routine);
    expect(find.text('ROUTINE · STEP 2 OF 4'), findsOneWidget);

    await pumpStep(PathAStep.symptoms);
    expect(find.text('SYMPTOMS · STEP 3 OF 4'), findsOneWidget);

    await pumpStep(PathAStep.match);
    expect(find.text('MATCH · STEP 4 OF 4'), findsOneWidget);

    expect(find.textContaining('OF 3'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
