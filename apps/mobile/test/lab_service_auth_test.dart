import 'package:femm_app/config/investor_demo_auth.dart';
import 'package:femm_app/services/lab_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test('detects Storage exp claim 403 as expired JWT', () {
    final error = StorageException(
      '"exp" claim timestamp check failed',
      statusCode: '403',
      error: 'Unauthorized',
    );
    expect(LabService.isExpiredJwtStorageError(error), isTrue);
    expect(
      LabService.userFacingError(error, bypassAuth: false),
      LabService.signedOutMessage,
    );
  });

  test('maps AuthException and signed-out StateError to clear copy', () {
    expect(
      LabService.userFacingError(
        StateError(LabService.signedOutMessage),
        bypassAuth: false,
      ),
      LabService.signedOutMessage,
    );
    expect(
      LabService.userFacingError(
        const AuthException('Invalid Refresh Token'),
        bypassAuth: false,
      ),
      LabService.signedOutMessage,
    );
  });

  test('investor bypass suppresses signed-out upload copy', () {
    expect(kInvestorDemoBypassAuth, isTrue);
    expect(
      LabService.userFacingError(
        const AuthException('Invalid Refresh Token'),
      ),
      isNot(LabService.signedOutMessage),
    );
    expect(
      LabService.userFacingError(
        StorageException(
          '"exp" claim timestamp check failed',
          statusCode: '403',
          error: 'Unauthorized',
        ),
      ),
      isNot(LabService.signedOutMessage),
    );
  });

  test('leaves unrelated errors readable', () {
    expect(
      LabService.userFacingError(
        StateError('Extract failed (HTTP 500)'),
        bypassAuth: false,
      ),
      'Bad state: Extract failed (HTTP 500)',
    );
    expect(
      LabService.isExpiredJwtStorageError(
        const StorageException('Payload too large', statusCode: '413'),
      ),
      isFalse,
    );
  });
}
