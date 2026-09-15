// ABOUTME: Tests for headless authentication response models
// ABOUTME: Verifies JSON parsing, factory constructors, and error handling

import 'package:flutter_test/flutter_test.dart';
import 'package:keycast_flutter/src/oauth/headless_models.dart';

void main() {
  group('HeadlessRegisterResult', () {
    group('constructor', () {
      test('creates instance with required fields', () {
        final result = HeadlessRegisterResult(
          success: true,
          pubkey: 'test_pubkey',
          verificationRequired: true,
        );

        expect(result.success, isTrue);
        expect(result.pubkey, 'test_pubkey');
        expect(result.verificationRequired, isTrue);
        expect(result.deviceCode, isNull);
        expect(result.email, isNull);
        expect(result.errorCode, isNull);
      });

      test('creates instance with all optional fields', () {
        final result = HeadlessRegisterResult(
          success: true,
          pubkey: 'test_pubkey',
          verificationRequired: true,
          deviceCode: 'device_123',
          email: 'test@example.com',
        );

        expect(result.deviceCode, 'device_123');
        expect(result.email, 'test@example.com');
      });
    });

    group('fromJson', () {
      test('parses complete JSON response', () {
        final json = {
          'success': true,
          'pubkey': 'abc123',
          'verification_required': true,
          'device_code': 'dev_code',
          'email': 'user@test.com',
          'error': null,
        };

        final result = HeadlessRegisterResult.fromJson(json);

        expect(result.success, isTrue);
        expect(result.pubkey, 'abc123');
        expect(result.verificationRequired, isTrue);
        expect(result.deviceCode, 'dev_code');
        expect(result.email, 'user@test.com');
        expect(result.errorCode, isNull);
      });

      test('uses defaults for missing fields', () {
        final json = <String, dynamic>{};

        final result = HeadlessRegisterResult.fromJson(json);

        expect(result.success, isFalse);
        expect(result.pubkey, '');
        expect(result.verificationRequired, isTrue);
        expect(result.deviceCode, isNull);
        expect(result.email, isNull);
        expect(result.errorCode, isNull);
      });

      test('parses error field', () {
        final json = {
          'success': false,
          'pubkey': '',
          'verification_required': false,
          'error': 'email_taken',
        };

        final result = HeadlessRegisterResult.fromJson(json);

        expect(result.success, isFalse);
        expect(result.errorCode, 'email_taken');
      });
    });

    group('error factory', () {
      test('creates error result with message', () {
        final result = HeadlessRegisterResult.error('Registration failed');

        expect(result.success, isFalse);
        expect(result.pubkey, '');
        expect(result.verificationRequired, isFalse);
        expect(result.errorDescription, 'Registration failed');
      });
    });

    group('failure classification', () {
      test('maps each supported code and defaults unknown', () {
        HeadlessRegisterResult error(String code) =>
            HeadlessRegisterResult.error('message', code: code);

        expect(
          error('CONFLICT').failure,
          KeycastRegisterFailure.emailAlreadyRegistered,
        );
        expect(
          error('EMAIL_ALREADY_EXISTS').failure,
          KeycastRegisterFailure.emailAlreadyRegistered,
        );
        expect(
          error('INVALID_EMAIL').failure,
          KeycastRegisterFailure.invalidEmail,
        );
        expect(
          error('rate_limited').failure,
          KeycastRegisterFailure.rateLimited,
        );
        expect(error('server_error').failure, KeycastRegisterFailure.server);
        expect(
          error('connection_error').failure,
          KeycastRegisterFailure.network,
        );
        expect(error('network_error').failure, KeycastRegisterFailure.network);
        expect(
          error('registration_failed').failure,
          KeycastRegisterFailure.unknown,
        );
      });
    });
  });

  group('HeadlessLoginResult', () {
    group('constructor', () {
      test('creates instance with required fields', () {
        final result = HeadlessLoginResult(success: true);

        expect(result.success, isTrue);
        expect(result.code, isNull);
        expect(result.pubkey, isNull);
        expect(result.state, isNull);
        expect(result.errorCode, isNull);
        expect(result.errorDescription, isNull);
      });

      test('creates instance with all optional fields', () {
        final result = HeadlessLoginResult(
          success: true,
          code: 'auth_code',
          pubkey: 'user_pubkey',
          state: 'state_123',
        );

        expect(result.code, 'auth_code');
        expect(result.pubkey, 'user_pubkey');
        expect(result.state, 'state_123');
      });
    });

    group('fromJson', () {
      test('parses a success response (code is the OAuth code)', () {
        final json = {
          'success': true,
          'code': 'auth_code_xyz',
          'pubkey': 'user_pk',
          'state': 'my_state',
        };

        final result = HeadlessLoginResult.fromJson(json);

        expect(result.success, isTrue);
        expect(result.code, 'auth_code_xyz');
        expect(result.pubkey, 'user_pk');
        expect(result.state, 'my_state');
        expect(result.errorCode, isNull);
        expect(result.errorDescription, isNull);
      });

      test('uses defaults for missing fields', () {
        final json = <String, dynamic>{};

        final result = HeadlessLoginResult.fromJson(json);

        expect(result.success, isFalse);
        expect(result.code, isNull);
        expect(result.pubkey, isNull);
        expect(result.state, isNull);
        expect(result.errorCode, isNull);
        expect(result.errorDescription, isNull);
      });

      test(
        'on a failure body, code is the machine code, not the OAuth code',
        () {
          // Real keycast 401: {"code":"INVALID_CREDENTIALS","error":"..."}.
          final json = {
            'success': false,
            'code': 'INVALID_CREDENTIALS',
            'error': 'Invalid email or password',
          };

          final result = HeadlessLoginResult.fromJson(json);

          expect(result.success, isFalse);
          expect(result.code, isNull, reason: 'no OAuth code on failure');
          expect(result.errorCode, 'INVALID_CREDENTIALS');
          expect(result.errorDescription, 'Invalid email or password');
          expect(result.failure, KeycastLoginFailure.invalidCredentials);
        },
      );
    });

    group('error factory', () {
      test('creates error result with message and default code', () {
        final result = HeadlessLoginResult.error('Login failed');

        expect(result.success, isFalse);
        expect(result.errorCode, 'client_error');
        expect(result.errorDescription, 'Login failed');
      });

      test('creates error result with custom code', () {
        final result = HeadlessLoginResult.error(
          'Network error',
          code: 'connection_error',
        );

        expect(result.success, isFalse);
        expect(result.errorCode, 'connection_error');
        expect(result.errorDescription, 'Network error');
        expect(result.failure, KeycastLoginFailure.network);
      });
    });

    group('failure classification', () {
      test('maps each server code and defaults unknown', () {
        HeadlessLoginResult err(String code) =>
            HeadlessLoginResult.error('msg', code: code);

        expect(
          err('INVALID_CREDENTIALS').failure,
          KeycastLoginFailure.invalidCredentials,
        );
        expect(
          err('EMAIL_NOT_VERIFIED').failure,
          KeycastLoginFailure.emailNotVerified,
        );
        expect(err('INVALID_EMAIL').failure, KeycastLoginFailure.invalidEmail);
        expect(
          err('TOO_MANY_ATTEMPTS').failure,
          KeycastLoginFailure.rateLimited,
        );
        expect(err('timeout').failure, KeycastLoginFailure.network);
        expect(err('connection_error').failure, KeycastLoginFailure.network);
        expect(err('INTERNAL_ERROR').failure, KeycastLoginFailure.unknown);
        expect(err('anything_else').failure, KeycastLoginFailure.unknown);
      });
    });
  });

  group('PollResult', () {
    group('constructor', () {
      test('creates instance with required status', () {
        final result = PollResult(status: PollStatus.pending);

        expect(result.status, PollStatus.pending);
        expect(result.code, isNull);
        expect(result.error, isNull);
      });

      test('creates instance with all fields', () {
        final result = PollResult(
          status: PollStatus.complete,
          code: 'auth_code',
        );

        expect(result.status, PollStatus.complete);
        expect(result.code, 'auth_code');
      });
    });

    group('pending factory', () {
      test('creates pending result', () {
        final result = PollResult.pending();

        expect(result.status, PollStatus.pending);
        expect(result.code, isNull);
        expect(result.error, isNull);
      });
    });

    group('complete factory', () {
      test('creates complete result with code', () {
        final result = PollResult.complete('my_auth_code');

        expect(result.status, PollStatus.complete);
        expect(result.code, 'my_auth_code');
        expect(result.error, isNull);
      });
    });

    group('error factory', () {
      test('creates error result with message', () {
        final result = PollResult.error('Token expired');

        expect(result.status, PollStatus.error);
        expect(result.code, isNull);
        expect(result.error, 'Token expired');
      });
    });
  });

  group('ForgotPasswordResult', () {
    group('constructor', () {
      test('creates instance with required fields', () {
        final result = ForgotPasswordResult(success: true);

        expect(result.success, isTrue);
        expect(result.message, isNull);
        expect(result.error, isNull);
      });

      test('creates instance with all fields', () {
        final result = ForgotPasswordResult(
          success: true,
          message: 'Email sent',
        );

        expect(result.success, isTrue);
        expect(result.message, 'Email sent');
      });
    });

    group('fromJson', () {
      test('parses complete JSON response', () {
        final json = {
          'success': true,
          'message': 'Password reset email sent',
          'error': null,
        };

        final result = ForgotPasswordResult.fromJson(json);

        expect(result.success, isTrue);
        expect(result.message, 'Password reset email sent');
        expect(result.error, isNull);
      });

      test('uses defaults for missing fields', () {
        final json = <String, dynamic>{};

        final result = ForgotPasswordResult.fromJson(json);

        expect(result.success, isFalse);
        expect(result.message, isNull);
        expect(result.error, isNull);
      });

      test('parses error field', () {
        final json = {'success': false, 'error': 'user_not_found'};

        final result = ForgotPasswordResult.fromJson(json);

        expect(result.success, isFalse);
        expect(result.error, 'user_not_found');
      });
    });

    group('error factory', () {
      test('creates error result with message', () {
        final result = ForgotPasswordResult.error('Network error');

        expect(result.success, isFalse);
        expect(result.error, 'Network error');
        expect(result.message, isNull);
      });
    });
  });

  group('ResetPasswordResult', () {
    group('constructor', () {
      test('creates instance with required fields', () {
        final result = ResetPasswordResult(success: true);

        expect(result.success, isTrue);
        expect(result.message, isNull);
      });

      test('creates instance with all fields', () {
        final result = ResetPasswordResult(
          success: true,
          message: 'Password updated',
        );

        expect(result.success, isTrue);
        expect(result.message, 'Password updated');
      });
    });

    group('fromJson', () {
      test('parses complete JSON response', () {
        final json = {'success': true, 'message': 'Password has been reset'};

        final result = ResetPasswordResult.fromJson(json);

        expect(result.success, isTrue);
        expect(result.message, 'Password has been reset');
      });

      test('uses defaults for missing fields', () {
        final json = <String, dynamic>{};

        final result = ResetPasswordResult.fromJson(json);

        expect(result.success, isFalse);
        expect(result.message, isNull);
      });
    });

    group('error factory', () {
      test('creates error result with message', () {
        final result = ResetPasswordResult.error('Token expired');

        expect(result.success, isFalse);
        expect(result.message, 'Token expired');
      });
    });
  });

  group('DeleteAccountResult', () {
    group('constructor', () {
      test('creates instance with required fields', () {
        final result = DeleteAccountResult(success: true);

        expect(result.success, isTrue);
        expect(result.message, isNull);
        expect(result.error, isNull);
      });

      test('creates instance with all fields', () {
        final result = DeleteAccountResult(
          success: true,
          message: 'Account deleted',
        );

        expect(result.success, isTrue);
        expect(result.message, 'Account deleted');
      });
    });

    group('fromJson', () {
      test('parses complete JSON response', () {
        final json = {
          'success': true,
          'message': 'Account successfully deleted',
          'error': null,
        };

        final result = DeleteAccountResult.fromJson(json);

        expect(result.success, isTrue);
        expect(result.message, 'Account successfully deleted');
        expect(result.error, isNull);
      });

      test('uses defaults for missing fields', () {
        final json = <String, dynamic>{};

        final result = DeleteAccountResult.fromJson(json);

        expect(result.success, isFalse);
        expect(result.message, isNull);
        expect(result.error, isNull);
      });

      test('parses error field', () {
        final json = {'success': false, 'error': 'unauthorized'};

        final result = DeleteAccountResult.fromJson(json);

        expect(result.success, isFalse);
        expect(result.error, 'unauthorized');
      });
    });

    group('error factory', () {
      test('creates error result with message', () {
        final result = DeleteAccountResult.error('Deletion failed');

        expect(result.success, isFalse);
        expect(result.error, 'Deletion failed');
        expect(result.message, isNull);
      });
    });
  });
}
