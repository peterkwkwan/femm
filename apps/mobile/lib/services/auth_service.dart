import 'dart:convert';

import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/supabase_config.dart';

/// Scopes Supabase Auth expects when exchanging a Google ID token.
///
/// Include `openid` so Credential Manager / GIS mint a proper OIDC ID token.
const List<String> kGoogleSignInScopes = <String>[
  'openid',
  'email',
  'profile',
];

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

    final expectedAudience = SupabaseConfig.googleServerClientId.trim();
    assertGoogleIdTokenAudience(
      idToken,
      expectedAudience: expectedAudience,
    );
    final claims = decodeJwtPayload(idToken);

    // google_sign_in 7 splits authn from authz: ID token from authenticate(),
    // access token from authorizationClient.
    final GoogleSignInClientAuthorization authorization =
        await account.authorizationClient.authorizationForScopes(
              kGoogleSignInScopes,
            ) ??
            await account.authorizationClient.authorizeScopes(
              kGoogleSignInScopes,
            );

    try {
      final response = await _signInWithGoogleTokens(
        idToken: idToken,
        accessToken: authorization.accessToken,
        claims: claims,
        expectedAudience: expectedAudience,
      );
      await _upsertProfile(response.user ?? _client.auth.currentUser);
      return response;
    } on AuthException catch (error) {
      throw AuthException(
        userFacingGoogleAuthMessage(
          error,
          claims: claims,
          expectedAudience: expectedAudience,
          supabaseHost: Uri.tryParse(SupabaseConfig.url)?.host,
        ),
        statusCode: error.statusCode,
        code: error.code,
      );
    }
  }

  /// Prefer idToken+accessToken; if Supabase returns Bad ID token and the JWT
  /// has `at_hash`, retry idToken-only (v7 authz token may not match at_hash).
  Future<AuthResponse> _signInWithGoogleTokens({
    required String idToken,
    required String accessToken,
    required Map<String, dynamic> claims,
    required String expectedAudience,
  }) async {
    try {
      return await _client.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: idToken,
        accessToken: accessToken,
      );
    } on AuthException catch (error) {
      final hasAtHash = claims['at_hash'] != null;
      final isBadIdToken = error.message.toLowerCase().contains('bad id token');
      if (!isBadIdToken || !hasAtHash) {
        rethrow;
      }
      // Separate authorizeScopes access tokens often do not match at_hash from
      // the Credential Manager ID token; GoTrue then fails VerifyAccessToken.
      return _client.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: idToken,
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
  final audiences = audienceFromClaims(payload);

  if (!audiences.contains(expectedAudience)) {
    throw StateError(
      'Google ID token aud ($audiences) does not match '
      'GOOGLE_SERVER_CLIENT_ID ($expectedAudience). Use the Google Cloud '
      'Web OAuth client ID in both dart-defines and Supabase Auth → Google '
      '→ Client IDs (not the Android client ID).',
    );
  }
}

List<String> audienceFromClaims(Map<String, dynamic> claims) {
  final aud = claims['aud'];
  return <String>[
    if (aud is String) aud,
    if (aud is List) ...aud.whereType<String>(),
  ];
}

/// Compact, non-secret JWT claim summary for on-device debugging.
String googleIdTokenDiagnostics(
  Map<String, dynamic> claims, {
  String? expectedAudience,
  String? supabaseHost,
}) {
  final aud = audienceFromClaims(claims).join(',');
  final exp = claims['exp'];
  String expLabel = '$exp';
  if (exp is int) {
    expLabel = DateTime.fromMillisecondsSinceEpoch(
      exp * 1000,
      isUtc: true,
    ).toIso8601String();
  }

  String shorten(String? value) {
    if (value == null || value.isEmpty) {
      return '(empty)';
    }
    if (value.length <= 16) {
      return value;
    }
    return '${value.substring(0, 8)}…${value.substring(value.length - 8)}';
  }

  return 'diag iss=${claims['iss']} aud=${shorten(aud)} '
      'azp=${shorten(claims['azp']?.toString())} '
      'exp=$expLabel nonce=${claims['nonce'] != null} '
      'at_hash=${claims['at_hash'] != null} '
      'expect=${shorten(expectedAudience)} '
      'host=${supabaseHost ?? '?'}';
}

/// Maps opaque Supabase Google ID-token failures to an actionable message.
String userFacingGoogleAuthMessage(
  AuthException error, {
  Map<String, dynamic>? claims,
  String? expectedAudience,
  String? supabaseHost,
}) {
  final message = error.message;
  final lower = message.toLowerCase();
  final diag = claims == null
      ? null
      : googleIdTokenDiagnostics(
          claims,
          expectedAudience: expectedAudience,
          supabaseHost: supabaseHost,
        );

  if (lower.contains('bad id token')) {
    return 'Google ID token was rejected by Supabase (Bad ID token). '
        'Confirm: (1) dart_defines GOOGLE_SERVER_CLIENT_ID is the Web client '
        '497406004004-vucsq218h9lhhvep09ls25o9i13vq36i.apps.googleusercontent.com, '
        '(2) same Web client ID + secret in Supabase Auth → Google → Client IDs, '
        '(3) Skip nonce check ON, (4) Android OAuth client com.femm.femm_app '
        'SHA-1 matches this install. '
        '${diag ?? ''} '
        'See docs/supabase-setup.md §3e.';
  }

  if (lower.contains('unacceptable audience')) {
    return 'Supabase rejected the Google ID token audience. Add the Web '
        'OAuth client ID to Supabase Auth → Google → Client IDs (same value '
        'as GOOGLE_SERVER_CLIENT_ID). ${diag ?? ''} '
        'See docs/supabase-setup.md.';
  }

  if (lower.contains('nonce')) {
    return 'Google ID token nonce check failed. Enable Skip nonce check under '
        'Supabase Auth → Providers → Google (required for google_sign_in). '
        '${diag ?? ''} See docs/supabase-setup.md.';
  }

  if (diag == null) {
    return message;
  }
  return '$message $diag';
}
