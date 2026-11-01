import 'clinical_specialty.dart';

class Clinic {
  Clinic({
    required this.id,
    required this.specialty,
    required this.name,
    required this.district,
    required this.addressLine,
    required this.whyMatchBlurb,
  });

  final String id;
  final ClinicalSpecialty specialty;
  final String name;
  final String district;
  final String addressLine;
  final String whyMatchBlurb;

  factory Clinic.fromJson(Map<String, dynamic> json) {
    return Clinic(
      id: json['id'].toString(),
      specialty: ClinicalSpecialty.parse(json['specialty']?.toString() ?? ''),
      name: (json['name'] ?? '').toString(),
      district: (json['district'] ?? '').toString(),
      addressLine: (json['address_line'] ?? '').toString(),
      whyMatchBlurb: (json['why_match_blurb'] ?? '').toString(),
    );
  }
}

class AppointmentSlot {
  AppointmentSlot({
    required this.id,
    required this.clinicId,
    required this.startsAt,
    required this.endsAt,
    required this.status,
    this.heldUntil,
    this.heldBy,
    this.bookedBy,
  });

  final String id;
  final String clinicId;
  final DateTime startsAt;
  final DateTime endsAt;
  final String status;
  final DateTime? heldUntil;
  final String? heldBy;
  final String? bookedBy;

  bool get isAvailable => status == 'available';

  factory AppointmentSlot.fromJson(Map<String, dynamic> json) {
    return AppointmentSlot(
      id: json['id'].toString(),
      clinicId: json['clinic_id'].toString(),
      startsAt: DateTime.parse(json['starts_at'].toString()).toUtc(),
      endsAt: DateTime.parse(json['ends_at'].toString()).toUtc(),
      status: (json['status'] ?? 'available').toString(),
      heldUntil: _parseTs(json['held_until']),
      heldBy: json['held_by']?.toString(),
      bookedBy: json['booked_by']?.toString(),
    );
  }

  static DateTime? _parseTs(Object? raw) {
    if (raw == null) return null;
    return DateTime.tryParse(raw.toString())?.toUtc();
  }
}

class UpsellPartner {
  UpsellPartner({
    required this.id,
    required this.spendBucketDb,
    required this.name,
    required this.tagline,
    required this.district,
  });

  final String id;
  final String spendBucketDb;
  final String name;
  final String tagline;
  final String district;

  factory UpsellPartner.fromJson(Map<String, dynamic> json) {
    return UpsellPartner(
      id: json['id'].toString(),
      spendBucketDb: (json['spend_bucket'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      tagline: (json['tagline'] ?? '').toString(),
      district: (json['district'] ?? '').toString(),
    );
  }
}
