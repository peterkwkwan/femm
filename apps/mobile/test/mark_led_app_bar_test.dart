import 'package:femm_app/theme/petal_soft.dart';
import 'package:femm_app/widgets/calmness_mark.dart';
import 'package:femm_app/widgets/mark_led_app_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Mark-Led bar shows Calmness mark + quieter femm, no path label',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        theme: PetalSoft.theme(),
        home: const Scaffold(
          appBar: MarkLedAppBar(),
          body: SizedBox.shrink(),
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(CalmnessMark), findsOneWidget);
    expect(find.text('femm'), findsOneWidget);
    final femm = tester.widget<Text>(find.text('femm'));
    expect(femm.style?.fontFamily, PetalSoft.fontFamily);
    expect(femm.style?.fontSize, PetalSoft.wordmarkSize);
    expect(femm.style?.fontWeight, PetalSoft.wordmarkWeight);
    expect(femm.style?.color, PetalSoft.ink);
    expect(
      femm.style?.letterSpacing,
      PetalSoft.letterSpacingEm(
        PetalSoft.wordmarkSize,
        PetalSoft.wordmarkTrackingEm,
      ),
    );
    expect(find.text('Path A'), findsNothing);
    expect(find.text('PATH A'), findsNothing);
    expect(find.text('Welcome'), findsNothing);
    expect(find.text('Sign out'), findsNothing);
  });

  testWidgets('Mark-Led signed-in shows Sign out + avatar, no Path A',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    var signedOut = false;
    await tester.pumpWidget(
      MaterialApp(
        theme: PetalSoft.theme(),
        home: Scaffold(
          appBar: MarkLedAppBar(
            onSignOut: () => signedOut = true,
            avatarInitial: 'K',
          ),
          body: const SizedBox.shrink(),
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(CalmnessMark), findsOneWidget);
    expect(find.text('Sign out'), findsOneWidget);
    expect(find.byType(MarkLedAvatar), findsOneWidget);
    expect(find.text('K'), findsWidgets);
    expect(find.text('Path A'), findsNothing);

    await tester.tap(find.text('Sign out'));
    await tester.pump();
    expect(signedOut, isTrue);
  });

  testWidgets('lab-style AppBar actions never show Path A label', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        theme: PetalSoft.theme(),
        home: const Scaffold(
          appBar: MarkLedAppBar(),
          body: Text('body'),
        ),
      ),
    );
    await tester.pump();

    expect(find.textContaining('Path A'), findsNothing);
    expect(find.textContaining('PATH'), findsNothing);
  });
}
