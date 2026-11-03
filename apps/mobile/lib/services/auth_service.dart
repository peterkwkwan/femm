import 'dart:convert';

import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/supabase_config.dart';

/// Scopes requested during Google authentication (OIDC ID token).
const List<String> kGoogleSignInScopes = <String>[
  'openid',
  'email',
  'profile',
];

/// Leeway when treating an ID token as already expired on-device.
const Duration kGoogleIdTokenExpiryLeeway = Duration(seconds: 60);

/// Google Auth via Supabase + `profiles` upsert for the femm user client.
///
/// Native flow for `google_sign_in` 7.x + Supabase:
/// 1. Initialize with the **Web** OAuth client ID (`GOOGLE_SERVER_CLIENT_ID`)
/// 2. Clear any cached Google account, then `authenticate()` for a fresh ID token
/// 3. `signInWithIdToken(idToken:)` only (no separate access token — avoids `at_hash`)
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

    // Drop any stale Supabase JWT so a failed prior attempt does not trigger
    // noisy /logout?scope=local 403 bad_jwt rows while diagnosing sign-in.
    if (_client.auth.currentSession != null) {
      await _client.auth.signOut();
    }

    // google_sign_in 7: call signOut before authenticate to avoid a cached
    // GoogleSignInAccount / stale ID token (exp already passed → Bad ID token).
    await _googleSignIn.signOut();

    var account = await _googleSignIn.authenticate(
      scopeHint: kGoogleSignInScopes,
    );
    var idToken = _requireIdToken(account);
    var claims = decodeJwtPayload(idToken);

    if (isGoogleIdTokenExpired(claims)) {
      await _googleSignIn.signOut();
      account = await _googleSignIn.authenticate(
        scopeHint: kGoogleSignInScopes,
      );
      idToken = _requireIdToken(account);
      claims = decodeJwtPayload(idToken);
      if (isGoogleIdTokenExpired(claims)) {
        throw StateError(expiredGoogleIdTokenMessage(claims));
      }
    }

    final expectedAudience = SupabaseConfig.googleServerClientId.trim();
    assertGoogleIdTokenAudience(
      idToken,
      expectedAudience: expectedAudience,
    );

    try {
      final response = await _client.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: idToken,
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

  String _requireIdToken(GoogleSignInAccount account) {
    final idToken = account.authentication.idToken;
    if (idToken == null || idToken.isEmpty) {
      throw StateError(
        'Google Sign-In returned no ID token. Pass '
        '--dart-define=GOOGLE_SERVER_CLIENT_ID=<Web client ID> '
        '(same Web client as Supabase Auth → Google → Client IDs).',
      );
    }
    return idToken;
  }

  Future<void> signOut() async {
    await _ensureGoogleInitialized();
    await Future.wait<void>([
      _client.auth.signOut(),
      _googleSignIn.signOut(),
    ]);
  }

  Future<void> _upsertProfile(User? user) {
    if (user == null) {
      return Future<void>.value();
    }
    final meta = user.userMetadata ?? const <String, dynamic>{};
    final displayName = (meta['full_name'] ??
            meta['name'] ??
            meta['display_name'])
        ?.toString();

    return _client.from('profiles').upsert(
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

DateTime? googleIdTokenExpiry(Map<String, dynamic> claims) {
  final exp = claims['exp'];
  if (exp is int) {
    return DateTime.fromMillisecondsSinceEpoch(exp * 1000, isUtc: true);
  }
  if (exp is num) {
    return DateTime.fromMillisecondsSinceEpoch(exp.toInt() * 1000, isUtc: true);
  }
  return null;
}

/// True when `exp` is already in the past (plus a small leeway).
bool isGoogleIdTokenExpired(
  Map<String, dynamic> claims, {
  DateTime? now,
  Duration leeway = kGoogleIdTokenExpiryLeeway,
}) {
  final expiry = googleIdTokenExpiry(claims);
  if (expiry == null) {
    return false;
  }
  final clock = (now ?? DateTime.now()).toUtc();
  return !expiry.isAfter(clock.subtract(leeway));
}

String expiredGoogleIdTokenMessage(Map<String, dynamic> claims) {
  final expiry = googleIdTokenExpiry(claims);
  return 'Google returned an expired ID token '
      '(exp=${expiry?.toIso8601String() ?? '?'}). '
      'On the phone: Settings → Date & time → turn ON automatic date & time '
      '(and automatic time zone), then force-stop the app and try again. '
      'Stale Credential Manager tokens also cause Supabase Bad ID token.';
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
  DateTime? now,
}) {
  final aud = audienceFromClaims(claims).join(',');
  final expiry = googleIdTokenExpiry(claims);
  final expLabel = expiry?.toIso8601String() ?? '${claims['exp']}';
  final clock = (now ?? DateTime.now()).toUtc();
  final expired = isGoogleIdTokenExpired(claims, now: clock);

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
      'exp=$expLabel expired=$expired nonce=${claims['nonce'] != null} '
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
    if (claims != null && isGoogleIdTokenExpired(claims)) {
      return '${expiredGoogleIdTokenMessage(claims)} ${diag ?? ''}';
    }
    return 'Google ID token was rejected by Supabase (Bad ID token). '
        'If diag shows expired=true, set the phone to automatic date & time '
        'and retry. Else confirm Web client ID / Skip nonce check. '
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
