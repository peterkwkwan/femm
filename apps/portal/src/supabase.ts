import { createClient, type Session, type User } from '@supabase/supabase-js';

import type {
  Clinic,
  PractitionerProfile,
  SummaryPack,
  UpcomingAppointment,
} from './types';

const url =
  import.meta.env.VITE_SUPABASE_URL ?? 'https://YOUR_PROJECT_REF.supabase.co';
const anonKey =
  import.meta.env.VITE_SUPABASE_ANON_KEY ??
  'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6ImFub24iLCJleHAiOjE5ODM4MTI5OTZ9.placeholder';

/** True when still on scaffold placeholders (no real project wired). */
export const usingPlaceholders =
  url.includes('YOUR_PROJECT_REF') || anonKey.includes('placeholder');

export const supabase = createClient(url, anonKey);

export function watchAuth(
  cb: (user: User | null, session: Session | null) => void,
): () => void {
  void supabase.auth.getSession().then(({ data }) => {
    cb(data.session?.user ?? null, data.session);
  });
  const { data } = supabase.auth.onAuthStateChange((_event, session) => {
    cb(session?.user ?? null, session);
  });
  return () => data.subscription.unsubscribe();
}

/** Google OAuth via Supabase (redirect back to this origin). */
export async function signInWithGoogle(): Promise<void> {
  const { error } = await supabase.auth.signInWithOAuth({
    provider: 'google',
    options: {
      redirectTo: window.location.origin,
    },
  });
  if (error) {
    throw error;
  }
}

export async function signOutUser(): Promise<void> {
  const { error } = await supabase.auth.signOut();
  if (error) {
    throw error;
  }
}

/** Upsert own profile as practitioner (portal). Preserves clinic_id if already set. */
export async function upsertOwnProfile(user: User): Promise<PractitionerProfile> {
  const meta = user.user_metadata ?? {};
  const displayName =
    (meta.full_name as string | undefined) ??
    (meta.name as string | undefined) ??
    null;

  const existing = await fetchOwnProfile(user.id);

  const { data, error } = await supabase
    .from('profiles')
    .upsert(
      {
        id: user.id,
        email: user.email,
        display_name: displayName,
        role: 'practitioner',
        clinic_id: existing?.clinic_id ?? null,
        updated_at: new Date().toISOString(),
      },
      { onConflict: 'id' },
    )
    .select()
    .single();

  if (error) {
    throw error;
  }
  return mapProfile(data);
}

export async function fetchOwnProfile(
  userId: string,
): Promise<PractitionerProfile | null> {
  const { data, error } = await supabase
    .from('profiles')
    .select('id, email, display_name, role, clinic_id')
    .eq('id', userId)
    .maybeSingle();
  if (error) {
    throw error;
  }
  return data ? mapProfile(data) : null;
}

function mapProfile(row: Record<string, unknown>): PractitionerProfile {
  return {
    id: String(row.id),
    email: (row.email as string | null) ?? null,
    display_name: (row.display_name as string | null) ?? null,
    role: String(row.role ?? 'practitioner'),
    clinic_id: (row.clinic_id as string | null) ?? null,
  };
}

export async function listClinics(): Promise<Clinic[]> {
  const { data, error } = await supabase
    .from('clinics')
    .select('id, specialty, name, district, address_line')
    .order('name');
  if (error) {
    throw error;
  }
  return (data ?? []).map((row) => ({
    id: String(row.id),
    specialty: row.specialty as Clinic['specialty'],
    name: String(row.name),
    district: String(row.district),
    address_line: String(row.address_line),
  }));
}

export async function fetchClinic(clinicId: string): Promise<Clinic | null> {
  const { data, error } = await supabase
    .from('clinics')
    .select('id, specialty, name, district, address_line')
    .eq('id', clinicId)
    .maybeSingle();
  if (error) {
    throw error;
  }
  if (!data) return null;
  return {
    id: String(data.id),
    specialty: data.specialty as Clinic['specialty'],
    name: String(data.name),
    district: String(data.district),
    address_line: String(data.address_line),
  };
}

export async function claimDemoClinic(clinicId: string): Promise<void> {
  const { error } = await supabase.rpc('claim_demo_clinic', {
    p_clinic_id: clinicId,
  });
  if (error) {
    throw error;
  }
}

/** Upcoming clinical appointments for the practitioner's claimed clinic. */
export async function listUpcomingAppointments(
  clinicId: string,
): Promise<UpcomingAppointment[]> {
  const { data: bookings, error } = await supabase
    .from('clinical_bookings')
    .select('id, specialty, why_copy, booked_at, slot_id, user_id, session_id')
    .eq('clinic_id', clinicId)
    .order('booked_at', { ascending: false });

  if (error) {
    throw error;
  }
  if (!bookings?.length) {
    return [];
  }

  const slotIds = bookings.map((b) => b.slot_id as string);
  const bookingIds = bookings.map((b) => b.id as string);

  const [{ data: slots }, { data: packs }] = await Promise.all([
    supabase
      .from('appointment_slots')
      .select('id, starts_at, ends_at')
      .in('id', slotIds),
    supabase
      .from('summary_packs')
      .select(
        'id, clinical_booking_id, patient_email, patient_display_name, slot_starts_at',
      )
      .in('clinical_booking_id', bookingIds)
      .eq('kind', 'clinical'),
  ]);

  const slotMap = new Map(
    (slots ?? []).map((s) => [String(s.id), s] as const),
  );
  const packByBooking = new Map(
    (packs ?? []).map((p) => [String(p.clinical_booking_id), p] as const),
  );

  const rows: UpcomingAppointment[] = bookings.map((b) => {
    const slot = slotMap.get(String(b.slot_id));
    const pack = packByBooking.get(String(b.id));
    const packStarts = pack?.slot_starts_at
      ? String(pack.slot_starts_at)
      : null;
    return {
      bookingId: String(b.id),
      specialty: b.specialty as UpcomingAppointment['specialty'],
      whyCopy: String(b.why_copy),
      bookedAt: String(b.booked_at),
      slotStartsAt: slot?.starts_at
        ? String(slot.starts_at)
        : packStarts,
      slotEndsAt: slot?.ends_at ? String(slot.ends_at) : null,
      packId: pack ? String(pack.id) : null,
      patientEmail: pack
        ? ((pack.patient_email as string | null) ?? null)
        : null,
      patientDisplayName: pack
        ? ((pack.patient_display_name as string | null) ?? null)
        : null,
    };
  });

  // Upcoming first by slot start; undated at end.
  rows.sort((a, b) => {
    const ta = a.slotStartsAt ? Date.parse(a.slotStartsAt) : Number.POSITIVE_INFINITY;
    const tb = b.slotStartsAt ? Date.parse(b.slotStartsAt) : Number.POSITIVE_INFINITY;
    return ta - tb;
  });

  return rows;
}

export async function fetchSummaryPack(packId: string): Promise<SummaryPack> {
  const { data, error } = await supabase
    .from('summary_packs')
    .select('*')
    .eq('id', packId)
    .single();
  if (error) {
    throw error;
  }
  return mapPack(data as Record<string, unknown>);
}

function mapPack(row: Record<string, unknown>): SummaryPack {
  const goalsRaw = row.goals;
  const goals =
    goalsRaw && typeof goalsRaw === 'object'
      ? (goalsRaw as SummaryPack['goals'])
      : {};
  const spend = Array.isArray(row.spend_buckets)
    ? (row.spend_buckets as string[])
    : [];
  const flagged = Array.isArray(row.flagged_labs)
    ? (row.flagged_labs as SummaryPack['flagged_labs'])
    : [];
  const labs = Array.isArray(row.labs)
    ? (row.labs as SummaryPack['labs'])
    : [];

  return {
    id: String(row.id),
    kind: row.kind as SummaryPack['kind'],
    session_id: String(row.session_id),
    clinical_booking_id: (row.clinical_booking_id as string | null) ?? null,
    clinic_id: (row.clinic_id as string | null) ?? null,
    path_tag: String(row.path_tag ?? 'Path A'),
    disclaimer: String(
      row.disclaimer ??
        'Care-navigation only — not a diagnosis or medical advice.',
    ),
    goals,
    spend_buckets: spend,
    match_reason: (row.match_reason as string | null) ?? null,
    flagged_labs: flagged,
    labs,
    lab_document_id: (row.lab_document_id as string | null) ?? null,
    storage_path: (row.storage_path as string | null) ?? null,
    original_filename: (row.original_filename as string | null) ?? null,
    patient_email: (row.patient_email as string | null) ?? null,
    patient_display_name: (row.patient_display_name as string | null) ?? null,
    slot_starts_at: (row.slot_starts_at as string | null) ?? null,
    specialty: (row.specialty as SummaryPack['specialty']) ?? null,
    created_at: String(row.created_at),
  };
}

/** Auth'd download of original lab PDF (RLS: booked practitioner only). */
export async function downloadLabPdf(
  storagePath: string,
  filenameHint: string | null,
): Promise<void> {
  const { data, error } = await supabase.storage
    .from('lab-pdfs')
    .download(storagePath);
  if (error) {
    throw error;
  }
  const urlObject = URL.createObjectURL(data);
  const a = document.createElement('a');
  a.href = urlObject;
  a.download = filenameHint?.trim() || storagePath.split('/').pop() || 'labs.pdf';
  document.body.appendChild(a);
  a.click();
  a.remove();
  URL.revokeObjectURL(urlObject);
}
