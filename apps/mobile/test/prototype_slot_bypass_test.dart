import 'package:femm_app/models/clinic.dart';
import 'package:femm_app/models/clinical_specialty.dart';
import 'package:femm_app/models/match_result.dart';
import 'package:femm_app/services/match_service.dart';
import 'package:flutter_test/flutter_test.dart';

Clinic _ridgeline() {
  return Clinic(
    id: 'clinic-bone-heart',
    specialty: ClinicalSpecialty.boneHeartRisk,
    name: 'Ridgeline Bone & Heart Risk Consult',
    district: 'Central',
    addressLine: '1 Demo Street',
    whyMatchBlurb: 'Demo clinic for bone / heart risk.',
  );
}

void main() {
  group('prototype slot supply bypass', () {
    test('buildPrototypeHold is active without Phase 1 supply rows', () {
      final now = DateTime.utc(2026, 11, 4, 2, 0);
      final match = MatchService.buildPrototypeHold(
        sessionId: 'session-1',
        specialty: ClinicalSpecialty.boneHeartRisk,
        whyCopy: 'Canned why — not a diagnosis.',
        clinic: _ridgeline(),
        now: now,
      );

      expect(match.hasActiveHold, isTrue);
      expect(MatchService.isPrototypeSlotId(match.slotId), isTrue);
      expect(match.clinic?.name, 'Ridgeline Bone & Heart Risk Consult');
      expect(match.slot, isNotNull);
      expect(match.holdExpiresAt, now.add(const Duration(minutes: 15)));
      expect(match.slot!.startsAt, now.add(const Duration(days: 1)));
    });

    test('prototype slot ids are distinct from real appointment_slots uuids',
        () {
      expect(MatchService.isPrototypeSlotId(null), isFalse);
      expect(
        MatchService.isPrototypeSlotId('a1b2c3d4-e5f6-7890-abcd-ef1234567890'),
        isFalse,
      );
      expect(
        MatchService.isPrototypeSlotId(
          '${MatchService.prototypeSlotIdPrefix}clinic-bone-heart',
        ),
        isTrue,
      );
    });

    test('confirmPrototypeHold books without supply reset or RPC', () {
      final now = DateTime.utc(2026, 11, 4, 3, 0);
      final stub = MatchService.buildPrototypeHold(
        sessionId: 'session-ridgeline',
        specialty: ClinicalSpecialty.boneHeartRisk,
        whyCopy: 'Canned why — not a diagnosis.',
        clinic: _ridgeline(),
        now: now,
      );

      final booking = MatchService.confirmPrototypeHold(
        stub,
        bookedAt: now.add(const Duration(minutes: 2)),
      );

      expect(booking.sessionId, 'session-ridgeline');
      expect(booking.clinicId, stub.clinicId);
      expect(MatchService.isPrototypeSlotId(booking.slotId), isTrue);
      expect(booking.specialty, ClinicalSpecialty.boneHeartRisk);
      expect(booking.whyCopy, stub.whyCopy);
      expect(booking.bookedAt, now.add(const Duration(minutes: 2)));
    });

    test('confirmPrototypeHold rejects real slot ids', () {
      final real = MatchService.buildPrototypeHold(
        sessionId: 's',
        specialty: ClinicalSpecialty.boneHeartRisk,
        whyCopy: 'why',
        clinic: _ridgeline(),
      );
      // Simulate a non-prototype match id.
      final notStub = PathAMatch(
        sessionId: real.sessionId,
        specialty: real.specialty,
        whyCopy: real.whyCopy,
        clinicId: real.clinicId,
        slotId: 'a1b2c3d4-e5f6-7890-abcd-ef1234567890',
        holdExpiresAt: real.holdExpiresAt,
        clinic: real.clinic,
        slot: real.slot,
      );
      expect(
        () => MatchService.confirmPrototypeHold(notStub),
        throwsArgumentError,
      );
    });
  });
}
