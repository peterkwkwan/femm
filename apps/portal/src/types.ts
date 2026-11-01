/** Phase 5 Path C types for the thin practitioner portal. */

export type ClinicalSpecialty =
  | 'menopause_aware_gp'
  | 'gynae_endocrine'
  | 'sleep_mood'
  | 'bone_heart_risk';

export interface Clinic {
  id: string;
  specialty: ClinicalSpecialty;
  name: string;
  district: string;
  address_line: string;
}

export interface PractitionerProfile {
  id: string;
  email: string | null;
  display_name: string | null;
  role: string;
  clinic_id: string | null;
}

export interface LabRow {
  name: string;
  value: number | string | null;
  unit: string | null;
  ref_range: string | null;
  flag: 'H' | 'L' | null;
  sort_order?: number;
}

export interface SummaryPack {
  id: string;
  kind: 'clinical' | 'upsell';
  session_id: string;
  clinical_booking_id: string | null;
  clinic_id: string | null;
  path_tag: string;
  disclaimer: string;
  goals: {
    primary_goal?: string;
    /** Selected symptom chip labels from Path A multi-select. */
    symptoms?: string[];
    answers?: Record<string, string>;
  };
  spend_buckets: string[];
  match_reason: string | null;
  flagged_labs: LabRow[];
  labs: LabRow[];
  lab_document_id: string | null;
  storage_path: string | null;
  original_filename: string | null;
  patient_email: string | null;
  patient_display_name: string | null;
  slot_starts_at: string | null;
  specialty: ClinicalSpecialty | null;
  created_at: string;
}

export interface UpcomingAppointment {
  bookingId: string;
  specialty: ClinicalSpecialty;
  whyCopy: string;
  bookedAt: string;
  slotStartsAt: string | null;
  slotEndsAt: string | null;
  packId: string | null;
  patientEmail: string | null;
  patientDisplayName: string | null;
}

export const SPECIALTY_LABELS: Record<ClinicalSpecialty, string> = {
  menopause_aware_gp: 'Menopause-aware GP',
  gynae_endocrine: 'Gynae / endocrine',
  sleep_mood: 'Sleep / mood',
  bone_heart_risk: 'Bone / heart risk',
};

export const SPEND_LABELS: Record<string, string> = {
  skincare_aesthetics: 'Skincare / aesthetics',
  gym_physio: 'Gym / physio',
  supplements: 'Supplements',
  wellness_spa: 'Wellness / spa',
  mental_health: 'Mental health',
  private_gp: 'Private GP',
};
