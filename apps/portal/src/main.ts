import './style.css';
import { PATH_C_DISCLAIMER, PORTAL_NOTE } from './disclaimers';
import {
  claimDemoClinic,
  downloadLabPdf,
  fetchClinic,
  fetchOwnProfile,
  fetchSummaryPack,
  listClinics,
  listUpcomingAppointments,
  signInWithGoogle,
  signOutUser,
  upsertOwnProfile,
  usingPlaceholders,
  watchAuth,
} from './supabase';
import {
  SPECIALTY_LABELS,
  SPEND_LABELS,
  type Clinic,
  type LabRow,
  type PractitionerProfile,
  type SummaryPack,
  type UpcomingAppointment,
} from './types';

const app = document.querySelector<HTMLDivElement>('#app');
if (!app) {
  throw new Error('#app root missing');
}

type View =
  | { name: 'signed-out'; error?: string }
  | { name: 'loading'; message: string }
  | {
      name: 'claim-clinic';
      profile: PractitionerProfile;
      clinics: Clinic[];
      error?: string;
    }
  | {
      name: 'appointments';
      profile: PractitionerProfile;
      clinic: Clinic;
      appointments: UpcomingAppointment[];
      error?: string;
    }
  | {
      name: 'pack';
      profile: PractitionerProfile;
      clinic: Clinic;
      pack: SummaryPack;
      labsExpanded: boolean;
      error?: string;
    };

let view: View = { name: 'signed-out' };
let profileSyncing = false;
let currentUserId: string | null = null;

function esc(value: string): string {
  return value
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;');
}

function formatWhen(iso: string | null): string {
  if (!iso) return 'Time TBD';
  try {
    return new Intl.DateTimeFormat('en-HK', {
      timeZone: 'Asia/Hong_Kong',
      weekday: 'short',
      year: 'numeric',
      month: 'short',
      day: 'numeric',
      hour: '2-digit',
      minute: '2-digit',
    }).format(new Date(iso));
  } catch {
    return iso;
  }
}

function formatLabValue(row: LabRow): string {
  const parts: string[] = [];
  if (row.value !== null && row.value !== undefined && row.value !== '') {
    parts.push(String(row.value));
  }
  if (row.unit) parts.push(row.unit);
  return parts.join(' ') || '—';
}

function render(): void {
  switch (view.name) {
    case 'signed-out':
      renderSignedOut(view.error);
      break;
    case 'loading':
      app!.innerHTML = `
        <main class="shell shell-wide">
          <p class="brand">femm</p>
          <p class="lede">${esc(view.message)}</p>
        </main>`;
      break;
    case 'claim-clinic':
      renderClaimClinic(view.profile, view.clinics, view.error);
      break;
    case 'appointments':
      renderAppointments(
        view.profile,
        view.clinic,
        view.appointments,
        view.error,
      );
      break;
    case 'pack':
      renderPack(view.profile, view.clinic, view.pack, view.labsExpanded, view.error);
      break;
  }
}

function renderSignedOut(error?: string): void {
  app!.innerHTML = `
    <main class="shell">
      <p class="brand">femm</p>
      <h1>Practitioner portal</h1>
      <p class="lede">Path C pre-visit packs for booked appointments. Google Auth via Supabase.</p>
      <p class="note">${esc(PORTAL_NOTE)}</p>
      ${
        usingPlaceholders
          ? '<p class="note">Placeholders active — copy <code>.env.example</code> → <code>.env.local</code> with your project URL + anon key.</p>'
          : ''
      }
      ${error ? `<p class="error">${esc(error)}</p>` : ''}
      <div class="actions">
        <button type="button" id="google-signin">Sign in with Google</button>
      </div>
    </main>
  `;
  document
    .querySelector('#google-signin')
    ?.addEventListener('click', () => void onGoogle());
}

function renderClaimClinic(
  profile: PractitionerProfile,
  clinics: Clinic[],
  error?: string,
): void {
  const options = clinics
    .map(
      (c) => `
      <li>
        <button type="button" class="clinic-claim" data-clinic-id="${esc(c.id)}">
          <span class="clinic-name">${esc(c.name)}</span>
          <span class="clinic-meta">${esc(SPECIALTY_LABELS[c.specialty])} · ${esc(c.district)}</span>
        </button>
      </li>`,
    )
    .join('');

  app!.innerHTML = `
    <main class="shell shell-wide">
      <header class="top">
        <div>
          <p class="brand">femm</p>
          <h1>Claim a demo clinic</h1>
        </div>
        <button type="button" class="secondary" id="signout">Sign out</button>
      </header>
      <p class="lede">Link this Google account to one fictional Phase 1 clinic. You will only see Path C packs for bookings at that clinic.</p>
      <p class="note">Signed in as ${esc(profile.email ?? profile.id)}</p>
      ${error ? `<p class="error">${esc(error)}</p>` : ''}
      <ul class="clinic-list">${options || '<li class="note">No clinics — run Phase 1 seed.</li>'}</ul>
      <p class="disclaimer sticky">${esc(PATH_C_DISCLAIMER)}</p>
    </main>
  `;

  document
    .querySelector('#signout')
    ?.addEventListener('click', () => void onSignOut());
  document.querySelectorAll('.clinic-claim').forEach((btn) => {
    btn.addEventListener('click', () => {
      const id = (btn as HTMLButtonElement).dataset.clinicId;
      if (id) void onClaimClinic(id);
    });
  });
}

function renderAppointments(
  profile: PractitionerProfile,
  clinic: Clinic,
  appointments: UpcomingAppointment[],
  error?: string,
): void {
  const rows = appointments
    .map((a) => {
      const who =
        a.patientDisplayName || a.patientEmail || 'Patient';
      const openDisabled = a.packId ? '' : 'disabled';
      return `
      <li class="appt">
        <div class="appt-main">
          <p class="appt-when">${esc(formatWhen(a.slotStartsAt))}</p>
          <p class="appt-who">${esc(who)}</p>
          <p class="appt-meta">${esc(SPECIALTY_LABELS[a.specialty])}</p>
        </div>
        <button type="button" class="open-pack" data-pack-id="${esc(a.packId ?? '')}" ${openDisabled}>
          Open summary
        </button>
      </li>`;
    })
    .join('');

  app!.innerHTML = `
    <main class="shell shell-wide">
      <header class="top">
        <div>
          <p class="brand">femm</p>
          <h1>Upcoming appointments</h1>
        </div>
        <button type="button" class="secondary" id="signout">Sign out</button>
      </header>
      <p class="lede">${esc(clinic.name)} · ${esc(clinic.district)}</p>
      <p class="note">${esc(profile.email ?? '')} · booked practitioners only</p>
      ${error ? `<p class="error">${esc(error)}</p>` : ''}
      <ul class="appt-list">
        ${
          rows ||
          '<li class="note empty">No clinical bookings for this clinic yet. Complete Path A confirm in the Flutter app.</li>'
        }
      </ul>
      <p class="disclaimer sticky">${esc(PATH_C_DISCLAIMER)}</p>
    </main>
  `;

  document
    .querySelector('#signout')
    ?.addEventListener('click', () => void onSignOut());
  document.querySelectorAll('.open-pack').forEach((btn) => {
    btn.addEventListener('click', () => {
      const packId = (btn as HTMLButtonElement).dataset.packId;
      if (packId) void onOpenPack(packId);
    });
  });
}

function renderPack(
  profile: PractitionerProfile,
  clinic: Clinic,
  pack: SummaryPack,
  labsExpanded: boolean,
  error?: string,
): void {
  const primaryGoal = pack.goals.primary_goal?.trim() || '—';
  const answers = pack.goals.answers ?? {};
  const answerRows = Object.entries(answers)
    .map(
      ([k, v]) =>
        `<li><span class="k">${esc(k)}</span> <span class="v">${esc(v)}</span></li>`,
    )
    .join('');

  const spend = (pack.spend_buckets ?? [])
    .map((b) => SPEND_LABELS[b] ?? b)
    .map((label) => `<li>${esc(label)}</li>`)
    .join('');

  const flagged = (pack.flagged_labs ?? [])
    .map(
      (row) => `
      <tr>
        <td>${esc(row.name)}</td>
        <td>${esc(formatLabValue(row))}</td>
        <td>${esc(row.ref_range ?? '—')}</td>
        <td class="flag">${esc(row.flag ?? '')}</td>
      </tr>`,
    )
    .join('');

  const fullLabs = (pack.labs ?? [])
    .map(
      (row) => `
      <tr>
        <td>${esc(row.name)}</td>
        <td>${esc(formatLabValue(row))}</td>
        <td>${esc(row.ref_range ?? '—')}</td>
        <td class="flag">${esc(row.flag ?? '')}</td>
      </tr>`,
    )
    .join('');

  const patient =
    pack.patient_display_name || pack.patient_email || 'Patient';

  app!.innerHTML = `
    <main class="shell shell-wide">
      <header class="top">
        <div>
          <p class="brand">femm</p>
          <h1>Path C summary</h1>
        </div>
        <div class="actions-inline">
          <button type="button" class="secondary" id="back-list">Back</button>
          <button type="button" class="secondary" id="signout">Sign out</button>
        </div>
      </header>

      <p class="path-tag">${esc(pack.path_tag)}</p>
      <p class="lede">${esc(patient)} · ${esc(formatWhen(pack.slot_starts_at))} · ${esc(clinic.name)}</p>
      ${error ? `<p class="error">${esc(error)}</p>` : ''}

      <section class="pack-block">
        <h2>Goals</h2>
        <p class="primary-goal">${esc(primaryGoal)}</p>
        ${answerRows ? `<ul class="kv-list">${answerRows}</ul>` : ''}
      </section>

      <section class="pack-block">
        <h2>Spend</h2>
        <ul class="plain-list">${spend || '<li>—</li>'}</ul>
      </section>

      <section class="pack-block">
        <h2>Why this match</h2>
        <p>${esc(pack.match_reason ?? '—')}</p>
      </section>

      <section class="pack-block">
        <h2>Flagged labs</h2>
        <p class="note">H/L vs ref range only when present — no invented clinical meaning.</p>
        <table class="labs">
          <thead><tr><th>Name</th><th>Value</th><th>Ref</th><th>Flag</th></tr></thead>
          <tbody>
            ${flagged || '<tr><td colspan="4">No flagged rows</td></tr>'}
          </tbody>
        </table>
      </section>

      <section class="pack-block">
        <div class="expand-row">
          <h2>Full labs</h2>
          <button type="button" class="secondary" id="toggle-labs">
            ${labsExpanded ? 'Collapse' : 'Expand'}
          </button>
        </div>
        ${
          labsExpanded
            ? `<table class="labs">
                <thead><tr><th>Name</th><th>Value</th><th>Ref</th><th>Flag</th></tr></thead>
                <tbody>
                  ${fullLabs || '<tr><td colspan="4">No lab rows</td></tr>'}
                </tbody>
              </table>`
            : '<p class="note">Collapsed — expand to review the confirmed biomarker table.</p>'
        }
      </section>

      <section class="pack-block">
        <h2>Original PDF</h2>
        <p class="note">${esc(pack.original_filename ?? pack.storage_path ?? 'No file path on pack')}</p>
        <div class="actions">
          <button type="button" id="download-pdf" ${pack.storage_path ? '' : 'disabled'}>
            Download original PDF
          </button>
        </div>
      </section>

      <p class="disclaimer sticky">${esc(pack.disclaimer || PATH_C_DISCLAIMER)}</p>
      <p class="note">Signed in as ${esc(profile.email ?? profile.id)}</p>
    </main>
  `;

  document
    .querySelector('#signout')
    ?.addEventListener('click', () => void onSignOut());
  document.querySelector('#back-list')?.addEventListener('click', () => {
    void loadPractitionerHome(profile);
  });
  document.querySelector('#toggle-labs')?.addEventListener('click', () => {
    if (view.name !== 'pack') return;
    view = { ...view, labsExpanded: !view.labsExpanded };
    render();
  });
  document.querySelector('#download-pdf')?.addEventListener('click', () => {
    void onDownloadPdf(pack);
  });
}

async function onGoogle(): Promise<void> {
  try {
    await signInWithGoogle();
  } catch (err) {
    view = {
      name: 'signed-out',
      error: err instanceof Error ? err.message : String(err),
    };
    render();
  }
}

async function onSignOut(): Promise<void> {
  try {
    await signOutUser();
  } catch (err) {
    view = {
      name: 'signed-out',
      error: err instanceof Error ? err.message : String(err),
    };
    render();
  }
}

async function onClaimClinic(clinicId: string): Promise<void> {
  view = { name: 'loading', message: 'Linking clinic…' };
  render();
  try {
    await claimDemoClinic(clinicId);
    if (!currentUserId) throw new Error('Not signed in');
    const profile = await fetchOwnProfile(currentUserId);
    if (!profile) throw new Error('Profile missing after claim');
    await loadPractitionerHome(profile);
  } catch (err) {
    const clinics = await listClinics().catch(() => [] as Clinic[]);
    const profile = currentUserId
      ? await fetchOwnProfile(currentUserId)
      : null;
    view = {
      name: 'claim-clinic',
      profile: profile ?? {
        id: currentUserId ?? '',
        email: null,
        display_name: null,
        role: 'practitioner',
        clinic_id: null,
      },
      clinics,
      error: err instanceof Error ? err.message : String(err),
    };
    render();
  }
}

async function onOpenPack(packId: string): Promise<void> {
  if (view.name !== 'appointments' && view.name !== 'pack') return;
  const profile = view.profile;
  const clinic = view.name === 'appointments' || view.name === 'pack'
    ? view.clinic
    : null;
  if (!clinic) return;

  view = { name: 'loading', message: 'Loading summary pack…' };
  render();
  try {
    const pack = await fetchSummaryPack(packId);
    view = {
      name: 'pack',
      profile,
      clinic,
      pack,
      labsExpanded: false,
    };
    render();
  } catch (err) {
    await loadPractitionerHome(profile, err instanceof Error ? err.message : String(err));
  }
}

async function onDownloadPdf(pack: SummaryPack): Promise<void> {
  if (!pack.storage_path || view.name !== 'pack') return;
  try {
    await downloadLabPdf(pack.storage_path, pack.original_filename);
  } catch (err) {
    view = {
      ...view,
      error: err instanceof Error ? err.message : String(err),
    };
    render();
  }
}

async function loadPractitionerHome(
  profile: PractitionerProfile,
  error?: string,
): Promise<void> {
  view = { name: 'loading', message: 'Loading appointments…' };
  render();

  try {
    if (!profile.clinic_id) {
      const clinics = await listClinics();
      view = { name: 'claim-clinic', profile, clinics, error };
      render();
      return;
    }

    const clinic = await fetchClinic(profile.clinic_id);
    if (!clinic) {
      const clinics = await listClinics();
      view = {
        name: 'claim-clinic',
        profile: { ...profile, clinic_id: null },
        clinics,
        error: 'Linked clinic missing — claim again after re-seeding.',
      };
      render();
      return;
    }

    const appointments = await listUpcomingAppointments(clinic.id);
    view = { name: 'appointments', profile, clinic, appointments, error };
    render();
  } catch (err) {
    view = {
      name: 'signed-out',
      error: err instanceof Error ? err.message : String(err),
    };
    render();
  }
}

watchAuth((user) => {
  if (!user) {
    currentUserId = null;
    view = { name: 'signed-out' };
    render();
    return;
  }

  currentUserId = user.id;
  if (profileSyncing || usingPlaceholders) {
    if (usingPlaceholders) {
      view = {
        name: 'signed-out',
        error: 'Configure VITE_SUPABASE_* before signing in.',
      };
      render();
    }
    return;
  }

  profileSyncing = true;
  view = { name: 'loading', message: 'Signing in…' };
  render();

  void upsertOwnProfile(user)
    .then((profile) => loadPractitionerHome(profile))
    .catch((err) => {
      view = {
        name: 'signed-out',
        error: err instanceof Error ? err.message : String(err),
      };
      render();
    })
    .finally(() => {
      profileSyncing = false;
    });
});
