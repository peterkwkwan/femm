import 'package:femm_app/config/investor_demo_auth.dart';
import 'package:femm_app/theme/petal_soft.dart';
import 'package:femm_app/widgets/dawn_mist_welcome.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('investor demo Google bypass', () {
    test('flag is on for the pitch (flip false after)', () {
      expect(kInvestorDemoBypassAuth, isTrue);
      expect(kInvestorDemoSignInDelay, const Duration(seconds: 2));
    });

    test('stub user greets as Sally on signed-in home', () {
      final user = buildInvestorDemoStubUser();
      expect(user.id, 'investor-demo-user');
      expect(user.email, 'sally@femm.app');
      expect(user.userMetadata?['full_name'], 'Sally');
      expect(user.userMetadata?['name'], kInvestorDemoDisplayName);
      expect(user.aud, 'authenticated');
    });

    test('local lab extract stub skips Storage for pitch upload', () {
      final extract = buildInvestorDemoLabExtract(
        originalFilename: 'synthetic-hk-womens-panel.pdf',
      );
      expect(extract.document.id, 'investor-demo-lab-document');
      expect(extract.document.originalFilename, 'synthetic-hk-womens-panel.pdf');
      expect(extract.document.status, 'extracted');
      expect(extract.biomarkers, isNotEmpty);
      expect(extract.biomarkers.first.name, 'FSH');
      expect(extract.biomarkers.first.flag, 'H');
    });

    test('bypass path delays then returns stub without calling OAuth',
        () async {
      var realCalled = false;
      final future = maybeBypassGoogleSignIn(
        bypass: true,
        delay: const Duration(milliseconds: 40),
        realSignIn: () async {
          realCalled = true;
        },
      );

      // Still waiting — OAuth must not have run.
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(realCalled, isFalse);

      final stub = await future;
      expect(realCalled, isFalse);
      expect(stub, isNotNull);
      expect(stub!.id, buildInvestorDemoStubUser().id);
      expect(stub.email, 'sally@femm.app');
      expect(stub.userMetadata?['full_name'], 'Sally');
    });

    test('real path calls sign-in and returns null (session via stream)',
        () async {
      var realCalled = false;
      final stub = await maybeBypassGoogleSignIn(
        bypass: false,
        delay: const Duration(seconds: 30),
        realSignIn: () async {
          realCalled = true;
        },
      );
      expect(realCalled, isTrue);
      expect(stub, isNull);
    });
  });

  testWidgets('Dawn Mist Google CTA shows spinner while busy', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        theme: PetalSoft.theme(),
        home: DawnMistWelcome(
          busy: true,
          error: null,
          usingPlaceholders: false,
          onGoogleSignIn: () {},
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Continue with Google'), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });
}
