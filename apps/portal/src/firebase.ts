import { initializeApp, type FirebaseOptions } from 'firebase/app';
import {
  connectAuthEmulator,
  getAuth,
  GoogleAuthProvider,
  onAuthStateChanged,
  signInAnonymously,
  signInWithPopup,
  signOut,
  type User,
} from 'firebase/auth';
import { connectFirestoreEmulator, getFirestore } from 'firebase/firestore';
import { connectStorageEmulator, getStorage } from 'firebase/storage';

/**
 * PLACEHOLDER client config — replace via Firebase console / FlutterFire twin.
 * Safe to ship as public web config once real; keep service-account JSON out of git.
 */
export const firebaseConfig: FirebaseOptions = {
  apiKey: import.meta.env.VITE_FIREBASE_API_KEY ?? 'REPLACE_WITH_WEB_API_KEY',
  authDomain:
    import.meta.env.VITE_FIREBASE_AUTH_DOMAIN ??
    'femm-prototype-REPLACE.firebaseapp.com',
  projectId:
    import.meta.env.VITE_FIREBASE_PROJECT_ID ?? 'femm-prototype-REPLACE',
  storageBucket:
    import.meta.env.VITE_FIREBASE_STORAGE_BUCKET ??
    'femm-prototype-REPLACE.appspot.com',
  messagingSenderId:
    import.meta.env.VITE_FIREBASE_MESSAGING_SENDER_ID ?? '000000000000',
  appId:
    import.meta.env.VITE_FIREBASE_APP_ID ??
    '1:000000000000:web:0000000000000000000000',
};

const app = initializeApp(firebaseConfig);
export const auth = getAuth(app);
export const db = getFirestore(app);
export const storage = getStorage(app);

const useEmulator = import.meta.env.VITE_USE_FIREBASE_EMULATOR === 'true';

if (useEmulator) {
  connectAuthEmulator(auth, 'http://127.0.0.1:9099', { disableWarnings: true });
  connectFirestoreEmulator(db, '127.0.0.1', 8080);
  connectStorageEmulator(storage, '127.0.0.1', 9199);
}

const provider = new GoogleAuthProvider();

export function watchAuth(cb: (user: User | null) => void): () => void {
  return onAuthStateChanged(auth, cb);
}

export async function signInWithGoogle(): Promise<User> {
  const result = await signInWithPopup(auth, provider);
  return result.user;
}

/** Local smoke when Google OAuth client IDs are not yet configured. */
export async function signInAnonymouslyForEmulator(): Promise<User> {
  const result = await signInAnonymously(auth);
  return result.user;
}

export async function signOutUser(): Promise<void> {
  await signOut(auth);
}

export { useEmulator };
