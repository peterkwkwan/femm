import 'package:femm_app/constants/disclaimers.dart';
import 'package:femm_app/screens/signed_in_home.dart';
import 'package:femm_app/theme/petal_soft.dart';
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
  test('greeting and first-name helpers', () {
    expect(
      SignedInHome.greetingFor(DateTime(2026, 1, 1, 9)),
      'Good morning',
    );
    expect(
      SignedInHome.greetingFor(DateTime(2026, 1, 1, 14)),
      'Good afternoon',
    );
    expect(
      SignedInHome.greetingFor(DateTime(2026, 1, 1, 20)),
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

  testWidgets('Next-step hero shows identity, Upload, Path A rail, disclaimer',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    var signedOut = false;
    await tester.pumpWidget(
      MaterialApp(
        theme: PetalSoft.theme(),
        home: SignedInHome(
          user: _fakeUser(),
          busy: false,
          error: null,
          onSignOut: () => signedOut = true,
        ),
      ),
    );
    await tester.pump();

    expect(find.text('femm'), findsOneWidget);
    expect(find.text('Sign out'), findsOneWidget);
    expect(find.text('Kool, start with your labs'), findsOneWidget);
    expect(find.text('Kool Krib'), findsOneWidget);
    expect(find.text('kribkool@gmail.com'), findsOneWidget);
    expect(find.text('YOUR NEXT STEP'), findsOneWidget);
    expect(find.text('Upload a lab PDF'), findsOneWidget);
    expect(find.text('Upload lab PDF'), findsOneWidget);
    expect(find.text('Path A · Labs 1 of 4'), findsOneWidget);
    expect(find.text(FemmDisclaimers.oneLiner), findsOneWidget);
    expect(find.text('Signed in'), findsNothing);

    await tester.tap(find.text('Sign out'));
    await tester.pump();
    expect(signedOut, isTrue);
    expect(tester.takeException(), isNull);
  });
}
