import 'package:femm_app/theme/petal_soft.dart';
import 'package:femm_app/widgets/calmness_mark.dart';
import 'package:femm_app/widgets/deep_accent_dusk_hills.dart';
import 'package:femm_app/widgets/deep_accent_dusk_welcome.dart';
import 'package:femm_app/widgets/mark_led_app_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
      'Deep Accent Dusk Stacked Corner: no nav bar, stacked brand, hills, CTA',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    var tapped = false;
    await tester.pumpWidget(
      MaterialApp(
        theme: PetalSoft.theme(),
        home: DeepAccentDuskWelcome(
          busy: false,
          error: null,
          usingPlaceholders: false,
          onGoogleSignIn: () => tapped = true,
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(MarkLedTopBar), findsNothing);
    expect(find.byType(MarkLedAppBar), findsNothing);
    expect(find.byType(AppBar), findsNothing);

    expect(find.byType(CalmnessMark), findsOneWidget);
    final mark = tester.widget<CalmnessMark>(find.byType(CalmnessMark));
    expect(mark.size, DeepAccentDuskWelcome.stackedMarkSize);
    expect(mark.size, greaterThan(42));

    expect(find.text('femm'), findsOneWidget);
    final femm = tester.widget<Text>(find.text('femm'));
    expect(femm.style?.color, PetalSoft.ink);
    expect(femm.style?.fontFamily, PetalSoft.fontFamily);
    expect(femm.style?.fontSize, DeepAccentDuskWelcome.stackedWordSize);
    expect(femm.style?.fontWeight, PetalSoft.wordmarkWeight);
    expect(
      femm.style?.letterSpacing,
      PetalSoft.letterSpacingEm(
        DeepAccentDuskWelcome.stackedWordSize,
        PetalSoft.wordmarkTrackingEm,
      ),
    );

    expect(find.text('Welcome'), findsOneWidget);
    final welcome = tester.widget<Text>(find.text('Welcome'));
    expect(welcome.style?.fontFamily, PetalSoft.fontFamily);
    expect(welcome.style?.fontSize, PetalSoft.welcomeSize);
    expect(welcome.style?.fontWeight, PetalSoft.welcomeWeight);
    expect(
      welcome.style?.letterSpacing,
      PetalSoft.letterSpacingEm(
        PetalSoft.welcomeSize,
        PetalSoft.welcomeTrackingEm,
      ),
    );
    expect(find.text(kWelcomeHelperCopy), findsOneWidget);
    expect(find.text('Continue with Google'), findsOneWidget);
    expect(find.byType(DeepAccentDuskHills), findsOneWidget);
    expect(find.text('Get started'), findsNothing);

    await tester.tap(find.text('Continue with Google'));
    await tester.pump();
    expect(tapped, isTrue);
    expect(tester.takeException(), isNull);

    // Let one animation tick run without throwing.
    await tester.pump(const Duration(milliseconds: 200));
    expect(tester.takeException(), isNull);
  });
}
