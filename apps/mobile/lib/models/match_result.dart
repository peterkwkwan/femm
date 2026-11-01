import 'clinical_specialty.dart';
import 'clinic.dart';

/// In-memory outcome of the rule-based match engine (before hold RPC).
class MatchRecommendation {
  const MatchRecommendation({
    required this.specialty,
    required this.whyCopy,
  });

  final ClinicalSpecialty specialty;
  final String whyCopy;
}

/// Persisted match + optional active hold (from `path_a_matches` / hold RPC).
class PathAMatch {
  PathAMatch({
    required this.sessionId,
    required this.specialty,
    required this.whyCopy,
    required this.clinicId,
    this.slotId,
    this.holdExpiresAt,
    this.clinic,
    this.slot,
  });

  final String sessionId;
  final ClinicalSpecialty specialty;
  final String whyCopy;
  final String clinicId;
  final String? slotId;
  final DateTime? holdExpiresAt;
  final Clinic? clinic;
  final AppointmentSlot? slot;

  bool get hasActiveHold {
    final until = holdExpiresAt;
    if (until == null || slotId == null) return false;
    return until.isAfter(DateTime.now().toUtc());
  }

  factory PathAMatch.fromJson(
    Map<String, dynamic> json, {
    Clinic? clinic,
    AppointmentSlot? slot,
  }) {
    return PathAMatch(
      sessionId: json['session_id'].toString(),
      specialty: ClinicalSpecialty.parse(json['specialty']?.toString() ?? ''),
      whyCopy: (json['why_copy'] ?? '').toString(),
      clinicId: json['clinic_id'].toString(),
      slotId: json['slot_id']?.toString(),
      holdExpiresAt: _parseTs(json['hold_expires_at']),
      clinic: clinic,
      slot: slot,
    );
  }

  static DateTime? _parseTs(Object? raw) {
    if (raw == null) return null;
    return DateTime.tryParse(raw.toString())?.toUtc();
  }
}

class ClinicalBooking {
  ClinicalBooking({
    required this.id,
    required this.sessionId,
    required this.clinicId,
    required this.slotId,
    required this.specialty,
    required this.whyCopy,
    required this.bookedAt,
  });

  final String id;
  final String sessionId;
  final String clinicId;
  final String slotId;
  final ClinicalSpecialty specialty;
  final String whyCopy;
  final DateTime bookedAt;

  factory ClinicalBooking.fromJson(Map<String, dynamic> json) {
    return ClinicalBooking(
      id: json['id'].toString(),
      sessionId: json['session_id'].toString(),
      clinicId: json['clinic_id'].toString(),
      slotId: json['slot_id'].toString(),
      specialty: ClinicalSpecialty.parse(json['specialty']?.toString() ?? ''),
      whyCopy: (json['why_copy'] ?? '').toString(),
      bookedAt: DateTime.parse(json['booked_at'].toString()).toUtc(),
    );
  }
}

class UpsellBooking {
  UpsellBooking({
    required this.id,
    required this.sessionId,
    required this.partnerId,
    required this.spendBucketDb,
    required this.bookedAt,
  });

  final String id;
  final String sessionId;
  final String partnerId;
  final String spendBucketDb;
  final DateTime bookedAt;

  factory UpsellBooking.fromJson(Map<String, dynamic> json) {
    return UpsellBooking(
      id: json['id'].toString(),
      sessionId: json['session_id'].toString(),
      partnerId: json['partner_id'].toString(),
      spendBucketDb: (json['spend_bucket'] ?? '').toString(),
      bookedAt: DateTime.parse(json['booked_at'].toString()).toUtc(),
    );
  }
}
