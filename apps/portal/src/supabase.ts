import { createClient, type Session, type User } from '@supabase/supabase-js';

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

/** Upsert own profile row (mirrors mobile; safe if already created). */
export async function upsertOwnProfile(user: User): Promise<void> {
  const meta = user.user_metadata ?? {};
  const displayName =
    (meta.full_name as string | undefined) ??
    (meta.name as string | undefined) ??
    null;

  const { error } = await supabase.from('profiles').upsert(
    {
      id: user.id,
      email: user.email,
      display_name: displayName,
      role: 'practitioner',
      updated_at: new Date().toISOString(),
    },
    { onConflict: 'id' },
  );
  if (error) {
    throw error;
  }
}
