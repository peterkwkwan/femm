import './style.css';
import {
  signInWithGoogle,
  signOutUser,
  upsertOwnProfile,
  usingPlaceholders,
  watchAuth,
} from './supabase';

const app = document.querySelector<HTMLDivElement>('#app');
if (!app) {
  throw new Error('#app root missing');
}

let profileSyncing = false;

function renderSignedOut(error?: string): void {
  app!.innerHTML = `
    <main class="shell">
      <p class="brand">femm</p>
      <h1>Practitioner portal</h1>
      <p class="lede">Phase 0.5 stub — Google Auth via Supabase. Appointments land in Phase 5.</p>
      <p class="note">Hong Kong prototype · English UI · not a diagnosis</p>
      ${
        usingPlaceholders
          ? '<p class="note">Placeholders active — copy <code>.env.example</code> → <code>.env.local</code> with your project URL + anon key.</p>'
          : ''
      }
      ${error ? `<p class="error">${escapeHtml(error)}</p>` : ''}
      <div class="actions">
        <button type="button" id="google-signin">Sign in with Google</button>
      </div>
    </main>
  `;

  document
    .querySelector('#google-signin')
    ?.addEventListener('click', () => void onGoogle());
}

function renderSignedIn(email: string | null, uid: string): void {
  app!.innerHTML = `
    <main class="shell">
      <p class="brand">femm</p>
      <h1>Practitioner portal</h1>
      <p class="lede">Signed in. Appointment list arrives in Phase 5.</p>
      <dl class="meta">
        <dt>UID</dt><dd>${escapeHtml(uid)}</dd>
        <dt>Email</dt><dd>${escapeHtml(email ?? '(none)')}</dd>
      </dl>
      <div class="actions">
        <button type="button" id="signout">Sign out</button>
      </div>
    </main>
  `;
  document
    .querySelector('#signout')
    ?.addEventListener('click', () => void onSignOut());
}

function escapeHtml(value: string): string {
  return value
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;');
}

async function onGoogle(): Promise<void> {
  try {
    await signInWithGoogle();
  } catch (err) {
    renderSignedOut(err instanceof Error ? err.message : String(err));
  }
}

async function onSignOut(): Promise<void> {
  try {
    await signOutUser();
  } catch (err) {
    renderSignedOut(err instanceof Error ? err.message : String(err));
  }
}

watchAuth((user) => {
  if (user) {
    renderSignedIn(user.email ?? null, user.id);
    if (!profileSyncing && !usingPlaceholders) {
      profileSyncing = true;
      void upsertOwnProfile(user)
        .catch((err) => {
          console.warn('profiles upsert failed', err);
        })
        .finally(() => {
          profileSyncing = false;
        });
    }
  } else {
    renderSignedOut();
  }
});
