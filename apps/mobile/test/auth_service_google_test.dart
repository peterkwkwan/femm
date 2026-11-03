import 'dart:convert';

import 'package:femm_app/services/auth_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

String _fakeJwt(Map<String, dynamic> payload) {
  String enc(Object value) =>
      base64Url.encode(utf8.encode(value is String ? value : jsonEncode(value))).replaceAll('=', '');
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

  group('userFacingGoogleAuthMessage', () {
    test('expands Bad ID token', () {
      final message = userFacingGoogleAuthMessage(
        const AuthApiException('Bad ID token', statusCode: '400'),
      );
      expect(message, contains('Skip nonce check is ON'));
      expect(message, contains('GOOGLE_SERVER_CLIENT_ID'));
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
