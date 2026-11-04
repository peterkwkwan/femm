import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/lab_biomarker.dart';

/// TEMP / investor-demo (2026-11-04): Google CTA skips OAuth/Google/Supabase.
///
/// When true, Continue with Google shows ~2s button loading then enters the
/// signed-in home with [buildInvestorDemoStubUser] — no API / OAuth calls.
/// Also skips LabService signed-out upload gates (local extract stub) so the
/// pitch is not blocked by "You're signed out…".
/// Flip to `false` after the investor pitch to restore real Google → Supabase auth.
const bool kInvestorDemoBypassAuth = true;

/// Artificial delay while the Google CTA shows its loading spinner.
const Duration kInvestorDemoSignInDelay = Duration(seconds: 2);

/// Display name shown on signed-in home greeting during the investor pitch.
const String kInvestorDemoDisplayName = 'Sally';

/// Minimal fake Supabase [User] so signed-in home renders without a real session.
User buildInvestorDemoStubUser() {
  return User(
    id: 'investor-demo-user',
    appMetadata: const <String, dynamic>{},
    userMetadata: const <String, dynamic>{
      'full_name': kInvestorDemoDisplayName,
      'name': kInvestorDemoDisplayName,
    },
    aud: 'authenticated',
    email: 'sally@femm.app',
    createdAt: '2026-11-04T00:00:00Z',
  );
}

/// TEMP local lab extract when bypass auth has no Supabase session.
///
/// Mirrors the Phase 1 golden fixture subset so Confirm labs can open without
/// Storage / Edge Function. Flip [kInvestorDemoBypassAuth] off to restore real upload.
({LabDocument document, List<LabBiomarker> biomarkers})
    buildInvestorDemoLabExtract({
  required String originalFilename,
}) {
  const documentId = 'investor-demo-lab-document';
  final document = LabDocument(
    id: documentId,
    storagePath: 'investor-demo-user/$documentId.pdf',
    status: 'extracted',
    originalFilename: originalFilename,
  );
  final biomarkers = <LabBiomarker>[
    LabBiomarker(
      id: 'investor-demo-row-1',
      sortOrder: 0,
      name: 'FSH',
      value: 68.4,
      unit: 'IU/L',
      refRange: 'Postmenopausal >25.8',
      flag: 'H',
    ),
    LabBiomarker(
      id: 'investor-demo-row-2',
      sortOrder: 1,
      name: 'LH',
      value: 42.1,
      unit: 'IU/L',
      refRange: 'Postmenopausal 7.7–58.5',
    ),
    LabBiomarker(
      id: 'investor-demo-row-3',
      sortOrder: 2,
      name: 'Estradiol (E2)',
      value: 28,
      unit: 'pmol/L',
      refRange: 'Postmenopausal <118',
    ),
    LabBiomarker(
      id: 'investor-demo-row-4',
      sortOrder: 3,
      name: 'Vitamin D (25-OH)',
      value: 38,
      unit: 'nmol/L',
      refRange: '50–125',
      flag: 'L',
    ),
    LabBiomarker(
      id: 'investor-demo-row-5',
      sortOrder: 4,
      name: 'HbA1c',
      value: 5.8,
      unit: '%',
      refRange: '<5.7',
      flag: 'H',
    ),
  ];
  return (document: document, biomarkers: biomarkers);
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
