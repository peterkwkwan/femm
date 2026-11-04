import 'package:femm_app/config/investor_demo_auth.dart';
import 'package:femm_app/models/clinical_specialty.dart';
import 'package:femm_app/models/spend_bucket.dart';
import 'package:femm_app/services/intake_service.dart';
import 'package:femm_app/services/match_service.dart';
import 'package:femm_app/theme/petal_soft.dart';
import 'package:femm_app/widgets/dawn_mist_welcome.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('investor demo Google bypass', () {
    test('flag is on for the pitch (flip false after)', () {
      expect(kInvestorDemoBypassAuth, isTrue);
      expect(kInvestorDemoSignInDelay, const Duration(seconds: 2));
      expect(kInvestorDemoUserId, 'investor-demo-user');
    });

    test('stub user greets as Sally on signed-in home', () {
      final user = buildInvestorDemoStubUser();
      expect(user.id, kInvestorDemoUserId);
      expect(user.email, 'sally@femm.app');
      expect(user.userMetadata?['full_name'], 'Sally');
      expect(user.userMetadata?['name'], kInvestorDemoDisplayName);
      expect(user.aud, 'authenticated');
    });

    test('local lab extract stub skips Storage for pitch upload', () {
      final extract = buildInvestorDemoLabExtract(
        originalFilename: 'synthetic-hk-womens-panel.pdf',
      );
      expect(extract.document.id, kInvestorDemoLabDocumentId);
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

  group('investor demo full-path stubs', () {
    setUp(IntakeService.clearInvestorDemoStore);

    test('demo session stub is ready after spend + symptoms stamps', () {
      final session = buildInvestorDemoSession(
        spendCompletedAt: DateTime.utc(2026, 11, 4),
        surveyCompletedAt: DateTime.utc(2026, 11, 4),
        spendBuckets: const [SpendBucket.supplements],
        surveyAnswers: const {'hot_flushes': 'Hot flushes'},
      );
      expect(session.id, kInvestorDemoSessionId);
      expect(session.labDocumentId, kInvestorDemoLabDocumentId);
      expect(session.hasSpend, isTrue);
      expect(session.hasSurvey, isTrue);
      expect(session.readyForMatch, isTrue);
    });

    test('demo clinics cover every clinical specialty (seed mirror)', () {
      for (final specialty in ClinicalSpecialty.values) {
        final clinic = buildInvestorDemoClinic(specialty);
        expect(clinic.specialty, specialty);
        expect(clinic.name, isNotEmpty);
        expect(clinic.id, startsWith('11111111-'));
      }
    });

    test('demo upsell partners cover every spend bucket', () {
      final partners = investorDemoUpsellPartners();
      expect(partners, hasLength(SpendBucket.values.length));
      final buckets = partners.map((p) => p.spendBucketDb).toSet();
      for (final bucket in SpendBucket.values) {
        expect(buckets, contains(bucket.dbValue));
      }
    });

    test('partnersForSpend filters and preserves spend order', () {
      final partners = investorDemoPartnersForSpend(const [
        SpendBucket.mentalHealth,
        SpendBucket.skincareAesthetics,
      ]);
      expect(partners, hasLength(2));
      expect(partners[0].spendBucketDb, SpendBucket.mentalHealth.dbValue);
      expect(partners[1].spendBucketDb, SpendBucket.skincareAesthetics.dbValue);
    });

    test('lab confirm store gates match readiness offline', () {
      clearInvestorDemoLabConfirmStore();
      expect(isInvestorDemoLabConfirmed('other-doc'), isFalse);
      markInvestorDemoLabConfirmed('other-doc');
      expect(isInvestorDemoLabConfirmed('other-doc'), isTrue);
      // Default demo lab id is always treated as confirmable for the pitch.
      expect(isInvestorDemoLabConfirmed(kInvestorDemoLabDocumentId), isTrue);
    });

    test('prototype hold + confirm stubs complete clinical booking offline', () {
      final clinic =
          buildInvestorDemoClinic(ClinicalSpecialty.boneHeartRisk);
      final hold = MatchService.buildPrototypeHold(
        sessionId: kInvestorDemoSessionId,
        specialty: ClinicalSpecialty.boneHeartRisk,
        whyCopy: 'Demo why',
        clinic: clinic,
      );
      expect(MatchService.isPrototypeSlotId(hold.slotId), isTrue);
      expect(hold.hasActiveHold, isTrue);

      final booking = MatchService.confirmPrototypeHold(hold);
      expect(booking.sessionId, kInvestorDemoSessionId);
      expect(booking.clinicId, clinic.id);
      expect(MatchService.isPrototypeSlotId(booking.slotId), isTrue);
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
