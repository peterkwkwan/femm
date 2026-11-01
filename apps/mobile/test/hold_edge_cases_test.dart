import 'package:femm_app/constants/disclaimers.dart';
import 'package:femm_app/models/clinical_specialty.dart';
import 'package:femm_app/models/match_result.dart';
import 'package:flutter_test/flutter_test.dart';

PathAMatch _match({
  String? slotId = 'slot-1',
  DateTime? holdExpiresAt,
}) {
  return PathAMatch(
    sessionId: 'session-1',
    specialty: ClinicalSpecialty.menopauseAwareGp,
    whyCopy: 'Canned why — not a diagnosis.',
    clinicId: 'clinic-1',
    slotId: slotId,
    holdExpiresAt: holdExpiresAt,
  );
}

void main() {
  group('PathAMatch.hasActiveHold', () {
    test('true when slot + future expires_at', () {
      final m = _match(
        holdExpiresAt: DateTime.now().toUtc().add(const Duration(minutes: 14)),
      );
      expect(m.hasActiveHold, isTrue);
    });

    test('false when hold expired (expire/release edge)', () {
      final m = _match(
        holdExpiresAt:
            DateTime.now().toUtc().subtract(const Duration(seconds: 1)),
      );
      expect(m.hasActiveHold, isFalse);
    });

    test('false when slot cleared after release_expired_slot_holds', () {
      final m = _match(
        slotId: null,
        holdExpiresAt: null,
      );
      expect(m.hasActiveHold, isFalse);
    });

    test('false when expires_at missing even if slot id present', () {
      final m = _match(holdExpiresAt: null);
      expect(m.hasActiveHold, isFalse);
    });
  });

  group('ClinicalBooking double-confirm payload', () {
    test('fromJson ignores already_booked flag (idempotent confirm)', () {
      final booking = ClinicalBooking.fromJson(<String, dynamic>{
        'id': 'b1',
        'session_id': 's1',
        'clinic_id': 'c1',
        'slot_id': 'slot-1',
        'specialty': 'menopause_aware_gp',
        'why_copy': 'Why — not a diagnosis.',
        'booked_at': '2026-11-01T12:00:00Z',
        'already_booked': true,
      });
      expect(booking.id, 'b1');
      expect(booking.sessionId, 's1');
      expect(booking.specialty, ClinicalSpecialty.menopauseAwareGp);
    });
  });

  group('Disclaimer audit strings', () {
    test('sticky match + Path C one-liners assert not-a-diagnosis', () {
      expect(FemmDisclaimers.assertsNotDiagnosis(FemmDisclaimers.stickyMatch),
          isTrue);
      expect(FemmDisclaimers.assertsNotDiagnosis(FemmDisclaimers.oneLiner),
          isTrue);
      expect(
        FemmDisclaimers.assertsNotDiagnosis(FemmDisclaimers.pathCOneLiner),
        isTrue,
      );
      expect(FemmDisclaimers.pathCOneLiner.toLowerCase(),
          contains('not a diagnosis'));
    });
  });
}
