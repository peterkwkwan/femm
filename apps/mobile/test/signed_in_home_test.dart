import 'package:femm_app/screens/signed_in_home.dart';
import 'package:femm_app/theme/petal_soft.dart';
import 'package:femm_app/widgets/calmness_mark.dart';
import 'package:femm_app/widgets/mark_led_app_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

User _fakeUser({
  String? name = 'Kool Krib',
  String? email = 'kribkool@gmail.com',
}) {
  return User(
    id: 'user-1',
    appMetadata: const {},
    userMetadata: name == null ? null : {'full_name': name, 'name': name},
    aud: 'authenticated',
    email: email,
    createdAt: '2026-01-01T00:00:00Z',
  );
}

void main() {
  test('local-time greeting bands and first-name helpers', () {
    expect(
      SignedInHome.greetingFor(DateTime(2026, 1, 1, 0)),
      'Good morning',
    );
    expect(
      SignedInHome.greetingFor(DateTime(2026, 1, 1, 11)),
      'Good morning',
    );
    expect(
      SignedInHome.greetingFor(DateTime(2026, 1, 1, 12)),
      'Good afternoon',
    );
    expect(
      SignedInHome.greetingFor(DateTime(2026, 1, 1, 16)),
      'Good afternoon',
    );
    expect(
      SignedInHome.greetingFor(DateTime(2026, 1, 1, 17)),
      'Good evening',
    );
    expect(
      SignedInHome.greetingFor(DateTime(2026, 1, 1, 23)),
      'Good evening',
    );
    expect(
      SignedInHome.firstNameOf(
        displayName: 'Kool Krib',
        email: 'kribkool@gmail.com',
      ),
      'Kool',
    );
    expect(
      SignedInHome.initialOf(
        displayName: 'Kool Krib',
        email: 'kribkool@gmail.com',
      ),
      'K',
    );
  });

  testWidgets('Next-step hero greeting follows injected local clock',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    Future<void> pumpAt(DateTime local) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: PetalSoft.theme(),
          home: SignedInHome(
            user: _fakeUser(),
            busy: false,
            error: null,
            onSignOut: () {},
            clock: () => local,
          ),
        ),
      );
      await tester.pump();
    }

    await pumpAt(DateTime(2026, 1, 1, 9));
    expect(find.text('GOOD MORNING'), findsOneWidget);
    expect(find.text('GOOD AFTERNOON'), findsNothing);

    await pumpAt(DateTime(2026, 1, 1, 14));
    expect(find.text('GOOD AFTERNOON'), findsOneWidget);
    expect(find.text('GOOD MORNING'), findsNothing);

    await pumpAt(DateTime(2026, 1, 1, 20));
    expect(find.text('GOOD EVENING'), findsOneWidget);
    expect(find.text('GOOD MORNING'), findsNothing);
  });

  testWidgets('Next-step hero shows identity, Upload, Path A rail',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    var signedOut = false;
    final now = DateTime(2026, 6, 1, 15); // afternoon local
    await tester.pumpWidget(
      MaterialApp(
        theme: PetalSoft.theme(),
        home: SignedInHome(
          user: _fakeUser(),
          busy: false,
          error: null,
          onSignOut: () => signedOut = true,
          clock: () => now,
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(MarkLedTopBar), findsOneWidget);
    expect(find.byType(CalmnessMark), findsOneWidget);
    expect(find.text('femm'), findsOneWidget);
    expect(find.text('Sign out'), findsOneWidget);
    expect(find.byType(MarkLedAvatar), findsOneWidget);
    expect(find.text('GOOD AFTERNOON'), findsOneWidget);
    expect(find.text('GOOD MORNING'), findsNothing);
    expect(find.text('Kool, start with your labs'), findsOneWidget);
    expect(find.text('Kool Krib'), findsOneWidget);
    expect(find.text('kribkool@gmail.com'), findsOneWidget);
    expect(find.text('YOUR NEXT STEP'), findsOneWidget);
    expect(find.text('Upload a lab PDF'), findsOneWidget);
    expect(find.text('Upload lab PDF'), findsOneWidget);
    expect(find.text('Path A · Labs 1 of 4'), findsOneWidget);
    // Path label must not appear in the top-nav — only in body rail copy.
    expect(
      find.descendant(
        of: find.byType(MarkLedTopBar),
        matching: find.textContaining('Path A'),
      ),
      findsNothing,
    );
    expect(find.text('Care-navigation only — not a diagnosis.'), findsNothing);
    expect(find.text('Signed in'), findsNothing);

    await tester.tap(find.text('Sign out'));
    await tester.pump();
    expect(signedOut, isTrue);
    expect(tester.takeException(), isNull);
  });
}
