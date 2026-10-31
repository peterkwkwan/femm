/// Client config from `--dart-define` (or defaults that compile without a project).
///
/// ```bash
/// flutter run \
///   --dart-define=SUPABASE_URL=https://YOUR_PROJECT_REF.supabase.co \
///   --dart-define=SUPABASE_ANON_KEY=eyJ... \
///   --dart-define=GOOGLE_SERVER_CLIENT_ID=123....apps.googleusercontent.com
/// ```
///
/// Never put the **service_role** key here. Anon is public-by-design; RLS must stay on.
class SupabaseConfig {
  const SupabaseConfig._();

  /// Placeholder URL so the shell boots before Peter creates a project.
  static const String url = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://YOUR_PROJECT_REF.supabase.co',
  );

  /// Placeholder anon key (not a real JWT). Replace via dart-define.
  static const String anonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6ImFub24iLCJleHAiOjE5ODM4MTI5OTZ9.placeholder',
  );

  /// Google Cloud **Web** OAuth client ID (same as Supabase Auth → Google).
  /// Required for Android ID-token → `signInWithIdToken`.
  static const String googleServerClientId = String.fromEnvironment(
    'GOOGLE_SERVER_CLIENT_ID',
  );

  static bool get hasRealProject =>
      url.contains('YOUR_PROJECT_REF') == false &&
      anonKey.contains('placeholder') == false;
}
