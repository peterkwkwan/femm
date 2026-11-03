import 'dart:convert';

import 'package:femm_app/services/auth_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

String _fakeJwt(Map<String, dynamic> payload) {
  String enc(Object value) => base64Url
      .encode(utf8.encode(value is String ? value : jsonEncode(value)))
      .replaceAll('=', '');
  return '${enc({"alg": "none", "typ": "JWT"})}.${enc(payload)}.sig';
}

void main() {
  group('decodeJwtPayload / assertGoogleIdTokenAudience', () {
    test('accepts matching aud string', () {
      const clientId = '123-abc.apps.googleusercontent.com';
      final token = _fakeJwt({
        'iss': 'https://accounts.google.com',
        'aud': clientId,
        'sub': 'user-1',
      });
      expect(
        () => assertGoogleIdTokenAudience(
          token,
          expectedAudience: clientId,
        ),
        returnsNormally,
      );
    });

    test('rejects mismatched aud with actionable StateError', () {
      final token = _fakeJwt({
        'iss': 'https://accounts.google.com',
        'aud': 'android-client.apps.googleusercontent.com',
        'sub': 'user-1',
      });
      expect(
        () => assertGoogleIdTokenAudience(
          token,
          expectedAudience: 'web-client.apps.googleusercontent.com',
        ),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            contains('does not match GOOGLE_SERVER_CLIENT_ID'),
          ),
        ),
      );
    });

    test('rejects non-JWT tokens', () {
      expect(
        () => decodeJwtPayload('not-a-jwt'),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            contains('non-JWT ID token'),
          ),
        ),
      );
    });
  });

  group('isGoogleIdTokenExpired', () {
    test('detects Peter-style exp ~4.5h before request', () {
      // exp 2026-11-03T08:51:08Z ; request ~13:26Z
      const exp = 1793695868; // 2026-11-03 08:51:08 UTC
      final claims = {'exp': exp};
      final now = DateTime.utc(2026, 11, 3, 13, 26, 40);
      expect(isGoogleIdTokenExpired(claims, now: now), isTrue);
      expect(
        expiredGoogleIdTokenMessage(claims),
        contains('automatic date & time'),
      );
    });

    test('accepts fresh token', () {
      final now = DateTime.utc(2026, 11, 3, 13, 26, 40);
      final exp = now.add(const Duration(minutes: 50)).millisecondsSinceEpoch ~/
          1000;
      expect(isGoogleIdTokenExpired({'exp': exp}, now: now), isFalse);
    });
  });

  group('googleIdTokenDiagnostics', () {
    test('includes expired flag', () {
      final now = DateTime.utc(2026, 11, 3, 13, 26, 40);
      final diag = googleIdTokenDiagnostics(
        {
          'iss': 'https://accounts.google.com',
          'aud':
              '497406004004-vucsq218h9lhhvep09ls25o9i13vq36i.apps.googleusercontent.com',
          'exp': 1793695868,
        },
        expectedAudience:
            '497406004004-vucsq218h9lhhvep09ls25o9i13vq36i.apps.googleusercontent.com',
        supabaseHost: 'puopkxhzijhzcaqpqqns.supabase.co',
        now: now,
      );
      expect(diag, contains('expired=true'));
      expect(diag, contains('host=puopkxhzijhzcaqpqqns.supabase.co'));
    });
  });

  group('userFacingGoogleAuthMessage', () {
    test('Bad ID token with expired claims points at device clock', () {
      final message = userFacingGoogleAuthMessage(
        const AuthApiException('Bad ID token', statusCode: '400'),
        claims: {
          'iss': 'https://accounts.google.com',
          'aud':
              '497406004004-vucsq218h9lhhvep09ls25o9i13vq36i.apps.googleusercontent.com',
          'exp': 1793695868, // 08:51Z — already past vs "now" in test env
        },
        expectedAudience:
            '497406004004-vucsq218h9lhhvep09ls25o9i13vq36i.apps.googleusercontent.com',
        supabaseHost: 'puopkxhzijhzcaqpqqns.supabase.co',
      );
      expect(message, contains('automatic date & time'));
      expect(message, contains('diag iss='));
    });

    test('expands unacceptable audience', () {
      final message = userFacingGoogleAuthMessage(
        const AuthApiException(
          'Unacceptable audience in id_token: [x]',
          statusCode: '400',
        ),
      );
      expect(message, contains('Client IDs'));
    });

    test('passes through unrelated messages', () {
      expect(
        userFacingGoogleAuthMessage(const AuthException('network down')),
        'network down',
      );
    });
  });
}
