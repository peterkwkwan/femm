import 'package:femm_app/widgets/brand_forward_welcome.dart';
import 'package:femm_app/theme/petal_soft.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Brand-Forward welcome shows brand, helper, Google CTA',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    var tapped = false;
    await tester.pumpWidget(
      MaterialApp(
        theme: PetalSoft.theme(),
        home: BrandForwardWelcome(
          busy: false,
          error: null,
          usingPlaceholders: false,
          onGoogleSignIn: () => tapped = true,
        ),
      ),
    );
    await tester.pump();

    expect(find.text('femm'), findsOneWidget);
    expect(find.text('Welcome'), findsOneWidget);
    expect(find.text(kWelcomeHelperCopy), findsOneWidget);
    expect(find.text('Continue with Google'), findsOneWidget);
    expect(find.text('Get started'), findsNothing);

    await tester.tap(find.text('Continue with Google'));
    await tester.pump();
    expect(tapped, isTrue);
    expect(tester.takeException(), isNull);
  });
}
