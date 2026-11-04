import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/clinic.dart';
import '../models/clinical_specialty.dart';
import '../models/lab_biomarker.dart';
import '../models/path_a_session.dart';
import '../models/spend_bucket.dart';

/// TEMP / investor-demo (2026-11-04): Google CTA skips OAuth/Google/Supabase.
///
/// When true:
/// - Continue with Google shows ~2s button loading then enters signed-in home
///   with [buildInvestorDemoStubUser] — no API / OAuth calls.
/// - Lab / Intake / Match services skip signed-out throws and use local stubs
///   so the full Path A pitch (upload → spend → symptoms → match → confirm →
///   extras) works without a real Supabase session.
///
/// Flip to `false` after the investor pitch to restore real Google → Supabase
/// auth and live service paths.
const bool kInvestorDemoBypassAuth = true;

/// Artificial delay while the Google CTA shows its loading spinner.
const Duration kInvestorDemoSignInDelay = Duration(seconds: 2);

/// Artificial delay while "Use demo PDF instead" shows its loading spinner.
const Duration kInvestorDemoPdfLoadDelay = Duration(seconds: 2);

/// Display name shown on signed-in home greeting during the investor pitch.
const String kInvestorDemoDisplayName = 'Sally';

/// Stable stub user id shared by Lab / Intake / Match offline paths.
const String kInvestorDemoUserId = 'investor-demo-user';

/// Stable stub lab document id from [buildInvestorDemoLabExtract].
const String kInvestorDemoLabDocumentId = 'investor-demo-lab-document';

/// Stable stub Path A session id for offline intake.
const String kInvestorDemoSessionId = 'investor-demo-session';

/// TEMP offline store: lab document ids confirmed without Supabase.
final Set<String> _investorDemoConfirmedLabDocs = <String>{};

/// Mark a lab document confirmed in the investor-demo offline store.
void markInvestorDemoLabConfirmed(String labDocumentId) {
  _investorDemoConfirmedLabDocs.add(labDocumentId);
}

/// Whether [labDocumentId] was confirmed via the offline demo path.
bool isInvestorDemoLabConfirmed(String labDocumentId) =>
    _investorDemoConfirmedLabDocs.contains(labDocumentId) ||
    labDocumentId == kInvestorDemoLabDocumentId;

/// Clear investor-demo offline lab-confirm flags (tests / reset).
void clearInvestorDemoLabConfirmStore() {
  _investorDemoConfirmedLabDocs.clear();
}

/// TEMP: true when bypass is on and there is no real Supabase JWT/session.
///
/// Prefer this over scattering `kInvestorDemoBypassAuth && session == null`.
bool isInvestorDemoOffline(SupabaseClient client) =>
    kInvestorDemoBypassAuth && client.auth.currentSession == null;

/// Resolve the effective user id for service calls.
///
/// Real session wins. When [kInvestorDemoBypassAuth] is true and there is no
/// current user, returns [kInvestorDemoUserId]. Otherwise throws [signedOutMessage].
String resolveDemoOrAuthUserId(
  SupabaseClient client, {
  String signedOutMessage = 'Not signed in',
}) {
  final id = client.auth.currentUser?.id;
  if (id != null) return id;
  if (kInvestorDemoBypassAuth) return kInvestorDemoUserId;
  throw StateError(signedOutMessage);
}

/// Minimal fake Supabase [User] so signed-in home renders without a real session.
User buildInvestorDemoStubUser() {
  return User(
    id: kInvestorDemoUserId,
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
  final document = LabDocument(
    id: kInvestorDemoLabDocumentId,
    storagePath: '$kInvestorDemoUserId/$kInvestorDemoLabDocumentId.pdf',
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

/// TEMP offline Path A session (Confirm → spend/symptoms/match).
PathASession buildInvestorDemoSession({
  String sessionId = kInvestorDemoSessionId,
  String labDocumentId = kInvestorDemoLabDocumentId,
  DateTime? spendCompletedAt,
  DateTime? surveyCompletedAt,
  List<SpendBucket> spendBuckets = const <SpendBucket>[],
  Map<String, String> surveyAnswers = const <String, String>{},
}) {
  return PathASession(
    id: sessionId,
    labDocumentId: labDocumentId,
    spendCompletedAt: spendCompletedAt,
    surveyCompletedAt: surveyCompletedAt,
    spendBuckets: spendBuckets,
    surveyAnswers: surveyAnswers,
  );
}

/// Fictional clinics mirroring `supabase/seed/phase1_demo_supply.sql`.
Clinic buildInvestorDemoClinic(ClinicalSpecialty specialty) {
  return switch (specialty) {
    ClinicalSpecialty.menopauseAwareGp => Clinic(
        id: '11111111-1111-4111-8111-111111111101',
        specialty: ClinicalSpecialty.menopauseAwareGp,
        name: 'Pearl Midlife Family Clinic',
        district: 'Central',
        addressLine: '12/F, Fiction House, 88 Des Voeux Road Central',
        whyMatchBlurb:
            'Matched as a menopause-aware GP for general midlife symptom '
            'navigation and first-line care coordination.',
      ),
    ClinicalSpecialty.gynaeEndocrine => Clinic(
        id: '11111111-1111-4111-8111-111111111102',
        specialty: ClinicalSpecialty.gynaeEndocrine,
        name: 'Victoria Harbour Gynae & Endocrine',
        district: 'Admiralty',
        addressLine: 'Suite 1503, Demo Tower, 1 Queensway',
        whyMatchBlurb:
            'Matched for gynae/endocrine review when hormonal and reproductive '
            'history needs specialist input.',
      ),
    ClinicalSpecialty.sleepMood => Clinic(
        id: '11111111-1111-4111-8111-111111111103',
        specialty: ClinicalSpecialty.sleepMood,
        name: 'Calm Peak Sleep & Mood Studio',
        district: 'Causeway Bay',
        addressLine: '5/F, Mock Mall, 500 Hennessy Road',
        whyMatchBlurb:
            'Matched for sleep and mood-focused consult when selected symptoms '
            'emphasise insomnia, anxiety, or low mood.',
      ),
    ClinicalSpecialty.boneHeartRisk => Clinic(
        id: '11111111-1111-4111-8111-111111111104',
        specialty: ClinicalSpecialty.boneHeartRisk,
        name: 'RidgeLine Bone & Heart Risk Consult',
        district: 'Tsim Sha Tsui',
        addressLine: '8/F, Sample Centre, 18 Salisbury Road',
        whyMatchBlurb:
            'Matched for bone and cardiovascular risk consult when labs/goals '
            'point at lipids, bone, or cardiometabolic concern.',
      ),
  };
}

/// Fictional upsell partners mirroring Phase 1 seed (one per spend bucket).
List<UpsellPartner> investorDemoUpsellPartners() {
  return <UpsellPartner>[
    UpsellPartner(
      id: '33333333-3333-4333-8333-333333333301',
      spendBucketDb: SpendBucket.skincareAesthetics.dbValue,
      name: 'Lumen Skin Lab HK',
      tagline: 'Fictional aesthetics studio for midlife skin/hair spend alignment.',
      district: 'Central',
    ),
    UpsellPartner(
      id: '33333333-3333-4333-8333-333333333302',
      spendBucketDb: SpendBucket.gymPhysio.dbValue,
      name: 'Kowloon Motion Physio & Gym',
      tagline: 'Fictional physio/gym partner for strength and joint spend.',
      district: 'Jordan',
    ),
    UpsellPartner(
      id: '33333333-3333-4333-8333-333333333303',
      spendBucketDb: SpendBucket.supplements.dbValue,
      name: 'Green Harbour Supplements Co.',
      tagline: 'Fictional retail partner for vitamin/supplement spend.',
      district: 'Mong Kok',
    ),
    UpsellPartner(
      id: '33333333-3333-4333-8333-333333333304',
      spendBucketDb: SpendBucket.wellnessSpa.dbValue,
      name: 'Mist & Tide Wellness Spa',
      tagline: 'Fictional spa/wellness partner for recovery spend.',
      district: 'Repulse Bay',
    ),
    UpsellPartner(
      id: '33333333-3333-4333-8333-333333333305',
      spendBucketDb: SpendBucket.mentalHealth.dbValue,
      name: 'Open Window Counselling HK',
      tagline: 'Fictional counselling partner for mental-health spend.',
      district: 'Wan Chai',
    ),
    UpsellPartner(
      id: '33333333-3333-4333-8333-333333333306',
      spendBucketDb: SpendBucket.privateGp.dbValue,
      name: 'Island Private GP Desk',
      tagline: 'Fictional private GP partner for existing GP spend.',
      district: 'Quarry Bay',
    ),
  ];
}

/// Partners matching the user's selected spend buckets (demo offline path).
List<UpsellPartner> investorDemoPartnersForSpend(List<SpendBucket> buckets) {
  if (buckets.isEmpty) return const <UpsellPartner>[];
  final keys = buckets.map((b) => b.dbValue).toList();
  final keySet = keys.toSet();
  final list = investorDemoUpsellPartners()
      .where((p) => keySet.contains(p.spendBucketDb))
      .toList();
  list.sort((a, b) {
    final ia = keys.indexOf(a.spendBucketDb);
    final ib = keys.indexOf(b.spendBucketDb);
    return ia.compareTo(ib);
  });
  return list;
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
