import './style.css';
import {
  signInAnonymouslyForEmulator,
  signInWithGoogle,
  signOutUser,
  useEmulator,
  watchAuth,
} from './firebase';

const app = document.querySelector<HTMLDivElement>('#app');
if (!app) {
  throw new Error('#app root missing');
}

function renderSignedOut(error?: string): void {
  app!.innerHTML = `
    <main class="shell">
      <p class="brand">femm</p>
      <h1>Practitioner portal</h1>
      <p class="lede">Phase 0 stub — Google Auth only. Appointments land in Phase 5.</p>
      <p class="note">Hong Kong prototype · English UI · not a diagnosis</p>
      ${error ? `<p class="error">${escapeHtml(error)}</p>` : ''}
      <div class="actions">
        <button type="button" id="google-signin">Sign in with Google</button>
        ${
          useEmulator
            ? '<button type="button" id="emulator-signin" class="secondary">Emulator anonymous sign-in</button>'
            : ''
        }
      </div>
    </main>
  `;

  document
    .querySelector('#google-signin')
    ?.addEventListener('click', () => void onGoogle());
  document
    .querySelector('#emulator-signin')
    ?.addEventListener('click', () => void onEmulator());
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

async function onEmulator(): Promise<void> {
  try {
    await signInAnonymouslyForEmulator();
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
    renderSignedIn(user.email, user.uid);
  } else {
    renderSignedOut();
  }
});
