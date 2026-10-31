import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/supabase_config.dart';

/// Google Auth via Supabase + `profiles` upsert for the femm user client.
class AuthService {
  AuthService({
    SupabaseClient? client,
    GoogleSignIn? googleSignIn,
  })  : _client = client ?? Supabase.instance.client,
        _googleSignIn = googleSignIn ?? GoogleSignIn.instance;

  final SupabaseClient _client;
  final GoogleSignIn _googleSignIn;
  Future<void>? _googleInit;

  Stream<AuthState> get authStateChanges => _client.auth.onAuthStateChange;

  Session? get currentSession => _client.auth.currentSession;

  User? get currentUser => _client.auth.currentUser;

  Future<void> _ensureGoogleInitialized() {
    final serverClientId = SupabaseConfig.googleServerClientId;
    return _googleInit ??= _googleSignIn.initialize(
      serverClientId: serverClientId.isEmpty ? null : serverClientId,
    );
  }

  /// Native Google Sign-In → Supabase session → upsert `public.profiles`.
  Future<AuthResponse> signInWithGoogle() async {
    await _ensureGoogleInitialized();
    final GoogleSignInAccount account = await _googleSignIn.authenticate();
    final GoogleSignInAuthentication googleAuth = account.authentication;
    final idToken = googleAuth.idToken;
    if (idToken == null) {
      throw StateError(
        'Google Sign-In returned no ID token. Pass '
        '--dart-define=GOOGLE_SERVER_CLIENT_ID=<Web client ID> '
        '(same Web client as Supabase Auth → Google).',
      );
    }

    final response = await _client.auth.signInWithIdToken(
      provider: OAuthProvider.google,
      idToken: idToken,
    );
    await _upsertProfile(response.user ?? _client.auth.currentUser);
    return response;
  }

  Future<void> signOut() async {
    await _ensureGoogleInitialized();
    await Future.wait<void>([
      _client.auth.signOut(),
      _googleSignIn.signOut(),
    ]);
  }

  Future<void> _upsertProfile(User? user) async {
    if (user == null) {
      return;
    }
    final meta = user.userMetadata ?? const <String, dynamic>{};
    final displayName = (meta['full_name'] ??
            meta['name'] ??
            meta['display_name'])
        ?.toString();

    await _client.from('profiles').upsert(
      <String, dynamic>{
        'id': user.id,
        'email': user.email,
        'display_name': displayName,
        'role': 'user',
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      },
      onConflict: 'id',
    );
  }
}
