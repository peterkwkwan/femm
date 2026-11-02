import 'package:femm_app/theme/petal_soft.dart';
import 'package:femm_app/widgets/deep_accent_dusk_hills.dart';
import 'package:femm_app/widgets/deep_accent_dusk_welcome.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Deep Accent Dusk shows ink wordmark, hills, Google CTA',
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

    expect(find.text('femm'), findsOneWidget);
    final femm = tester.widget<Text>(find.text('femm'));
    expect(femm.style?.color, const Color(0xFF2A1F1C));

    expect(find.text('Welcome'), findsOneWidget);
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
