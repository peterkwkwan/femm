import 'package:supabase_flutter/supabase_flutter.dart';

/// TEMP / investor-demo (2026-11-04): Google CTA skips OAuth/Google/Supabase.
///
/// When true, Continue with Google shows ~2s button loading then enters the
/// signed-in home with [buildInvestorDemoStubUser] — no API / OAuth calls.
/// Flip to `false` after the investor pitch to restore real Google → Supabase auth.
const bool kInvestorDemoBypassAuth = true;

/// Artificial delay while the Google CTA shows its loading spinner.
const Duration kInvestorDemoSignInDelay = Duration(seconds: 2);

/// Minimal fake Supabase [User] so signed-in home renders without a real session.
User buildInvestorDemoStubUser() {
  return User(
    id: 'investor-demo-user',
    appMetadata: const <String, dynamic>{},
    userMetadata: const <String, dynamic>{
      'full_name': 'Demo User',
      'name': 'Demo User',
    },
    aud: 'authenticated',
    email: 'demo@femm.app',
    createdAt: '2026-11-04T00:00:00Z',
  );
}

/// Runs the investor-demo short-circuit or the real Google sign-in.
///
/// Returns a stub [User] when [bypass] is true (caller should enter signed-in
/// shell). Returns `null` after [realSignIn] when bypass is off (session comes
/// from the auth stream).
Future<User?> maybeBypassGoogleSignIn({
  bool bypass = kInvestorDemoBypassAuth,
  Duration delay = kInvestorDemoSignInDelay,
  required Future<void> Function() realSignIn,
  User Function() stubUser = buildInvestorDemoStubUser,
}) async {
  if (!bypass) {
    await realSignIn();
    return null;
  }
  // TEMP / investor-demo: no Google / Supabase auth — delay then stub session.
  await Future<void>.delayed(delay);
  return stubUser();
}
