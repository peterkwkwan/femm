import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/clinic.dart';
import '../models/clinical_specialty.dart';
import '../models/lab_biomarker.dart';
import '../models/match_result.dart';
import '../models/path_a_session.dart';
import '../models/spend_bucket.dart';
import 'lab_service.dart';
import 'match_engine.dart';

/// Phase 4: rule-based match, 15-min hold RPCs, clinical + upsell bookings.
class MatchService {
  MatchService({
    SupabaseClient? client,
    MatchEngine? engine,
    LabService? labService,
  })  : _client = client ?? Supabase.instance.client,
        _engine = engine ?? const MatchEngine(),
        _labService = labService ?? LabService();

  final SupabaseClient _client;
  final MatchEngine _engine;
  final LabService _labService;

  String get _uid {
    final id = _client.auth.currentUser?.id;
    if (id == null) {
      throw StateError('Not signed in');
    }
    return id;
  }

  Future<void> releaseExpiredHolds() async {
    await _client.rpc('release_expired_slot_holds');
  }

  Future<Clinic> fetchClinicBySpecialty(ClinicalSpecialty specialty) async {
    final row = await _client
        .from('clinics')
        .select()
        .eq('specialty', specialty.dbValue)
        .single();
    return Clinic.fromJson(Map<String, dynamic>.from(row));
  }

  Future<Clinic?> fetchClinic(String clinicId) async {
    final row = await _client
        .from('clinics')
        .select()
        .eq('id', clinicId)
        .maybeSingle();
    if (row == null) return null;
    return Clinic.fromJson(Map<String, dynamic>.from(row));
  }

  Future<AppointmentSlot?> fetchSlot(String slotId) async {
    final row = await _client
        .from('appointment_slots')
        .select()
        .eq('id', slotId)
        .maybeSingle();
    if (row == null) return null;
    return AppointmentSlot.fromJson(Map<String, dynamic>.from(row));
  }

  /// Next bookable slot for clinic: available, or held by current user, soonest start.
  Future<AppointmentSlot?> nextHoldableSlot(String clinicId) async {
    await releaseExpiredHolds();
    final uid = _uid;
    final rows = await _client
        .from('appointment_slots')
        .select()
        .eq('clinic_id', clinicId)
        .order('starts_at');

    AppointmentSlot? best;
    for (final raw in rows as List<dynamic>) {
      final slot = AppointmentSlot.fromJson(
        Map<String, dynamic>.from(raw as Map),
      );
      if (slot.status == 'available') {
        best = slot;
        break;
      }
      if (slot.status == 'held' &&
          slot.heldBy == uid &&
          slot.heldUntil != null &&
          slot.heldUntil!.isAfter(DateTime.now().toUtc())) {
        best = slot;
        break;
      }
    }
    return best;
  }

  Future<List<UpsellPartner>> partnersForSpend(
    List<SpendBucket> buckets,
  ) async {
    if (buckets.isEmpty) return const <UpsellPartner>[];
    final keys = buckets.map((b) => b.dbValue).toList();
    final keySet = keys.toSet();
    final rows = await _client.from('upsell_partners').select();
    final list = (rows as List<dynamic>)
        .map((e) => UpsellPartner.fromJson(Map<String, dynamic>.from(e as Map)))
        .where((p) => keySet.contains(p.spendBucketDb))
        .toList();
    // Stable order: follow user's spend list order.
    list.sort((a, b) {
      final ia = keys.indexOf(a.spendBucketDb);
      final ib = keys.indexOf(b.spendBucketDb);
      return ia.compareTo(ib);
    });
    return list;
  }

  Future<PathAMatch?> fetchMatch(String sessionId) async {
    final uid = _uid;
    final row = await _client
        .from('path_a_matches')
        .select()
        .eq('session_id', sessionId)
        .eq('user_id', uid)
        .maybeSingle();
    if (row == null) return null;
    final map = Map<String, dynamic>.from(row);
    final clinic = await fetchClinic(map['clinic_id'].toString());
    AppointmentSlot? slot;
    final slotId = map['slot_id']?.toString();
    if (slotId != null) {
      slot = await fetchSlot(slotId);
    }
    return PathAMatch.fromJson(map, clinic: clinic, slot: slot);
  }

  Future<ClinicalBooking?> fetchClinicalBooking(String sessionId) async {
    final uid = _uid;
    final row = await _client
        .from('clinical_bookings')
        .select()
        .eq('session_id', sessionId)
        .eq('user_id', uid)
        .maybeSingle();
    if (row == null) return null;
    return ClinicalBooking.fromJson(Map<String, dynamic>.from(row));
  }

  Future<List<UpsellBooking>> fetchUpsellBookings(String sessionId) async {
    final uid = _uid;
    final rows = await _client
        .from('upsell_bookings')
        .select()
        .eq('session_id', sessionId)
        .eq('user_id', uid);
    return (rows as List<dynamic>)
        .map((e) => UpsellBooking.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  /// Leave-and-return while still on the match screen: refresh only.
  /// Reuses an active hold or existing clinical booking; does **not** take a
  /// new hold if the previous one expired (UI shows re-hold CTA instead).
  Future<({PathAMatch? match, ClinicalBooking? clinical, bool holdExpired})>
      resumeMatchState(PathASession session) async {
    final existingBooking = await fetchClinicalBooking(session.id);
    if (existingBooking != null) {
      final match = await fetchMatch(session.id);
      if (match != null) {
        return (match: match, clinical: existingBooking, holdExpired: false);
      }
      final clinic = await fetchClinic(existingBooking.clinicId);
      final slot = await fetchSlot(existingBooking.slotId);
      return (
        match: PathAMatch(
          sessionId: session.id,
          specialty: existingBooking.specialty,
          whyCopy: existingBooking.whyCopy,
          clinicId: existingBooking.clinicId,
          slotId: existingBooking.slotId,
          clinic: clinic,
          slot: slot,
        ),
        clinical: existingBooking,
        holdExpired: false,
      );
    }

    await releaseExpiredHolds();
    final existing = await fetchMatch(session.id);
    if (existing != null && existing.hasActiveHold) {
      return (match: existing, clinical: null, holdExpired: false);
    }
    return (
      match: existing,
      clinical: null,
      holdExpired: true,
    );
  }

  /// Run engine → pick slot → 15-min hold. Reuses active hold when still valid.
  Future<({PathAMatch match, ClinicalBooking? clinical})> startOrResumeMatch(
    PathASession session,
  ) async {
    final existingBooking = await fetchClinicalBooking(session.id);
    if (existingBooking != null) {
      final match = await fetchMatch(session.id);
      if (match != null) {
        return (match: match, clinical: existingBooking);
      }
      // Booking without match row (shouldn't happen) — synthesize from booking.
      final clinic = await fetchClinic(existingBooking.clinicId);
      final slot = await fetchSlot(existingBooking.slotId);
      return (
        match: PathAMatch(
          sessionId: session.id,
          specialty: existingBooking.specialty,
          whyCopy: existingBooking.whyCopy,
          clinicId: existingBooking.clinicId,
          slotId: existingBooking.slotId,
          clinic: clinic,
          slot: slot,
        ),
        clinical: existingBooking,
      );
    }

    await releaseExpiredHolds();

    final existing = await fetchMatch(session.id);
    if (existing != null && existing.hasActiveHold) {
      return (match: existing, clinical: null);
    }

    final biomarkers = await _labService.fetchBiomarkers(session.labDocumentId);
    final flaggedOnly = biomarkers
        .where((b) => !b.isDeleted && b.flag != null)
        .toList();

    final recommendation = _engine.recommend(
      surveyAnswers: session.surveyAnswers,
      biomarkers: flaggedOnly,
    );

    final clinic = await fetchClinicBySpecialty(recommendation.specialty);
    final slot = await nextHoldableSlot(clinic.id);
    if (slot == null) {
      throw StateError(
        'No available slots for ${clinic.name}. Reset Phase 1 demo supply.',
      );
    }

    final held = await _client.rpc(
      'hold_slot_for_match',
      params: <String, dynamic>{
        'p_session_id': session.id,
        'p_slot_id': slot.id,
        'p_specialty': recommendation.specialty.dbValue,
        'p_why_copy': recommendation.whyCopy,
        'p_clinic_id': clinic.id,
      },
    );

    final heldMap = Map<String, dynamic>.from(held as Map);
    final refreshedSlot = await fetchSlot(slot.id) ?? slot;
    return (
      match: PathAMatch.fromJson(
        heldMap,
        clinic: clinic,
        slot: refreshedSlot,
      ),
      clinical: null,
    );
  }

  Future<ClinicalBooking> confirmClinical(String sessionId) async {
    final result = await _client.rpc(
      'confirm_clinical_booking',
      params: <String, dynamic>{'p_session_id': sessionId},
    );
    return ClinicalBooking.fromJson(Map<String, dynamic>.from(result as Map));
  }

  Future<UpsellBooking> bookUpsell({
    required String sessionId,
    required String partnerId,
  }) async {
    final result = await _client.rpc(
      'book_upsell_partner',
      params: <String, dynamic>{
        'p_session_id': sessionId,
        'p_partner_id': partnerId,
      },
    );
    return UpsellBooking.fromJson(Map<String, dynamic>.from(result as Map));
  }
}
