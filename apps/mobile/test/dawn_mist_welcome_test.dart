import 'package:femm_app/theme/petal_soft.dart';
import 'package:femm_app/widgets/calmness_mark.dart';
import 'package:femm_app/widgets/dawn_mist_atmosphere.dart';
import 'package:femm_app/widgets/dawn_mist_welcome.dart';
import 'package:femm_app/widgets/mark_led_app_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
      'Dawn Mist: no nav, centered Cormorant Soft brand, mist wash, soft Google',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    var tapped = false;
    await tester.pumpWidget(
      MaterialApp(
        theme: PetalSoft.theme(),
        home: DawnMistWelcome(
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
    expect(mark.size, DawnMistWelcome.centeredMarkSize);
    expect(mark.size, 78);

    expect(find.text('femm'), findsOneWidget);
    final femm = tester.widget<Text>(find.text('femm'));
    expect(femm.style?.color, PetalSoft.ink);
    expect(femm.style?.fontFamily, PetalSoft.displayFontFamily);
    expect(femm.style?.fontSize, DawnMistWelcome.majesticWordSize);
    expect(femm.style?.fontWeight, PetalSoft.majesticWordmarkWeight);
    expect(femm.style?.fontStyle, FontStyle.italic);
    expect(
      femm.style?.letterSpacing,
      PetalSoft.letterSpacingEm(
        DawnMistWelcome.majesticWordSize,
        PetalSoft.majesticWordmarkTrackingEm,
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
    expect(
      kWelcomeHelperCopy,
      'Your journey to recovery starts here.',
    );
    expect(
      find.text('Your journey to recovery starts here.'),
      findsOneWidget,
    );
    expect(find.text('Continue with Google'), findsOneWidget);
    expect(find.byType(DawnMistAtmosphere), findsOneWidget);
    expect(find.text('Get started'), findsNothing);

    final ctaText = tester.widget<Text>(find.text('Continue with Google'));
    expect(ctaText.style?.fontFamily, PetalSoft.fontFamily);
    expect(ctaText.style?.fontWeight, FontWeight.w600);

    await tester.tap(find.text('Continue with Google'));
    await tester.pump();
    expect(tapped, isTrue);
    expect(tester.takeException(), isNull);

    // Let atmosphere animation tick without throwing.
    await tester.pump(const Duration(milliseconds: 200));
    expect(tester.takeException(), isNull);
  });
}
