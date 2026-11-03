import 'dart:convert';

import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/supabase_config.dart';

/// Scopes Supabase Auth expects when exchanging a Google ID token.
const List<String> kGoogleSignInScopes = <String>['email', 'profile'];

/// Google Auth via Supabase + `profiles` upsert for the femm user client.
///
/// Native flow follows Supabase + `google_sign_in` 7.x:
/// 1. Initialize with the **Web** OAuth client ID (`GOOGLE_SERVER_CLIENT_ID`)
/// 2. Authenticate for an ID token
/// 3. Authorize scopes for an access token
/// 4. `signInWithIdToken(idToken:, accessToken:)`
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
    final serverClientId = SupabaseConfig.googleServerClientId.trim();
    if (serverClientId.isEmpty) {
      throw StateError(
        'GOOGLE_SERVER_CLIENT_ID is empty. Pass the Google Cloud '
        'Web OAuth client ID (same value as Supabase Auth → Google → '
        'Client IDs) via --dart-define or dart_defines.json.',
      );
    }
    return _googleInit ??= _googleSignIn.initialize(
      serverClientId: serverClientId,
    );
  }

  /// Native Google Sign-In → Supabase session → upsert `public.profiles`.
  Future<AuthResponse> signInWithGoogle() async {
    await _ensureGoogleInitialized();

    final GoogleSignInAccount account = await _googleSignIn.authenticate(
      scopeHint: kGoogleSignInScopes,
    );

    final idToken = account.authentication.idToken;
    if (idToken == null || idToken.isEmpty) {
      throw StateError(
        'Google Sign-In returned no ID token. Pass '
        '--dart-define=GOOGLE_SERVER_CLIENT_ID=<Web client ID> '
        '(same Web client as Supabase Auth → Google → Client IDs).',
      );
    }

    assertGoogleIdTokenAudience(
      idToken,
      expectedAudience: SupabaseConfig.googleServerClientId.trim(),
    );

    // google_sign_in 7 splits authn from authz: ID token from authenticate(),
    // access token from authorizationClient (required by signInWithIdToken).
    final GoogleSignInClientAuthorization authorization =
        await account.authorizationClient.authorizationForScopes(
              kGoogleSignInScopes,
            ) ??
            await account.authorizationClient.authorizeScopes(
              kGoogleSignInScopes,
            );

    try {
      final response = await _client.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: idToken,
        accessToken: authorization.accessToken,
      );
      await _upsertProfile(response.user ?? _client.auth.currentUser);
      return response;
    } on AuthException catch (error) {
      throw AuthException(
        userFacingGoogleAuthMessage(error),
        statusCode: error.statusCode,
        code: error.code,
      );
    }
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

/// Decode a JWT payload without verifying the signature (local preflight only).
Map<String, dynamic> decodeJwtPayload(String jwt) {
  final parts = jwt.split('.');
  if (parts.length != 3) {
    throw StateError(
      'Google Sign-In returned a non-JWT ID token (${parts.length} parts). '
      'Use the Web OAuth client ID as GOOGLE_SERVER_CLIENT_ID, not an '
      'access token or Android client ID.',
    );
  }

  final normalized = base64Url.normalize(parts[1]);
  final decoded = utf8.decode(base64Url.decode(normalized));
  final payload = jsonDecode(decoded);
  if (payload is! Map<String, dynamic>) {
    throw StateError('Google ID token payload is not a JSON object.');
  }
  return payload;
}

/// Ensures the ID token `aud` matches the Web client ID we asked Google for
/// (and that Supabase Auth → Google must accept).
void assertGoogleIdTokenAudience(
  String idToken, {
  required String expectedAudience,
}) {
  if (expectedAudience.isEmpty) {
    return;
  }

  final payload = decodeJwtPayload(idToken);
  final aud = payload['aud'];
  final audiences = <String>[
    if (aud is String) aud,
    if (aud is List) ...aud.whereType<String>(),
  ];

  if (!audiences.contains(expectedAudience)) {
    throw StateError(
      'Google ID token aud ($audiences) does not match '
      'GOOGLE_SERVER_CLIENT_ID ($expectedAudience). Use the Google Cloud '
      'Web OAuth client ID in both dart-defines and Supabase Auth → Google '
      '→ Client IDs (not the Android client ID).',
    );
  }
}

/// Maps opaque Supabase Google ID-token failures to an actionable message.
String userFacingGoogleAuthMessage(AuthException error) {
  final message = error.message;
  final lower = message.toLowerCase();

  if (lower.contains('bad id token')) {
    return 'Google ID token was rejected by Supabase (Bad ID token). '
        'Confirm: (1) GOOGLE_SERVER_CLIENT_ID is the Web OAuth client ID, '
        '(2) the same Web client ID + secret are in Supabase Auth → Google, '
        '(3) Skip nonce check is ON, (4) Android OAuth client exists for '
        'com.femm.femm_app + this device SHA-1. See docs/supabase-setup.md.';
  }

  if (lower.contains('unacceptable audience')) {
    return 'Supabase rejected the Google ID token audience. Add the Web '
        'OAuth client ID to Supabase Auth → Google → Client IDs (same value '
        'as GOOGLE_SERVER_CLIENT_ID). See docs/supabase-setup.md.';
  }

  if (lower.contains('nonce')) {
    return 'Google ID token nonce check failed. Enable Skip nonce check under '
        'Supabase Auth → Providers → Google (required for google_sign_in). '
        'See docs/supabase-setup.md.';
  }

  return message;
}
