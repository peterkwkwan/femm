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

    test('stub user is enough for signed-in home identity', () {
      final user = buildInvestorDemoStubUser();
      expect(user.id, 'investor-demo-user');
      expect(user.email, 'demo@femm.app');
      expect(user.userMetadata?['full_name'], 'Demo User');
      expect(user.aud, 'authenticated');
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
      expect(stub.email, 'demo@femm.app');
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
