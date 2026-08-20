// ABOUTME: Tests for KeycastOAuth client - OAuth flow handling
// ABOUTME: Verifies URL building, callback parsing, token exchange (mocked HTTP)

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:keycast_flutter/src/models/exceptions.dart';
import 'package:keycast_flutter/src/models/keycast_session.dart';
import 'package:keycast_flutter/src/oauth/callback_result.dart';
import 'package:keycast_flutter/src/oauth/headless_models.dart';
import 'package:keycast_flutter/src/oauth/oauth_client.dart';
import 'package:keycast_flutter/src/oauth/oauth_config.dart';
import 'package:keycast_flutter/src/storage/keycast_storage.dart';

void main() {
  const config = OAuthConfig(
    serverUrl: 'https://login.divine.video',
    clientId: 'test-client',
    redirectUri: 'divine://oauth/callback',
  );

  group('KeycastOAuth', () {
    group('getAuthorizationUrl', () {
      test('generates URL with required parameters', () async {
        final oauth = KeycastOAuth(config: config);
        final (url, verifier) = await oauth.getAuthorizationUrl();

        final uri = Uri.parse(url);
        expect(uri.host, 'login.divine.video');
        expect(uri.path, '/api/oauth/authorize');
        expect(uri.queryParameters['client_id'], 'test-client');
        expect(uri.queryParameters['redirect_uri'], 'divine://oauth/callback');
        expect(uri.queryParameters['code_challenge'], isNotEmpty);
        expect(uri.queryParameters['code_challenge_method'], 'S256');
        expect(verifier, isNotEmpty);
      });

      test('includes default scope', () async {
        final oauth = KeycastOAuth(config: config);
        final (url, _) = await oauth.getAuthorizationUrl();

        final uri = Uri.parse(url);
        expect(uri.queryParameters['scope'], 'policy:social');
      });

      test('accepts custom scope', () async {
        final oauth = KeycastOAuth(config: config);
        final (url, _) = await oauth.getAuthorizationUrl(scope: 'custom:scope');

        final uri = Uri.parse(url);
        expect(uri.queryParameters['scope'], 'custom:scope');
      });

      test('includes default_register=true by default', () async {
        final oauth = KeycastOAuth(config: config);
        final (url, _) = await oauth.getAuthorizationUrl();

        final uri = Uri.parse(url);
        expect(uri.queryParameters['default_register'], 'true');
      });

      test('respects defaultRegister=false', () async {
        final oauth = KeycastOAuth(config: config);
        final (url, _) = await oauth.getAuthorizationUrl(
          defaultRegister: false,
        );

        final uri = Uri.parse(url);
        expect(uri.queryParameters['default_register'], 'false');
      });

      test('omits byok_pubkey when nsec not provided', () async {
        final oauth = KeycastOAuth(config: config);
        final (url, _) = await oauth.getAuthorizationUrl();

        final uri = Uri.parse(url);
        expect(uri.queryParameters.containsKey('byok_pubkey'), isFalse);
      });

      test('includes byok_pubkey when nsec provided', () async {
        final oauth = KeycastOAuth(config: config);
        final (url, verifier) = await oauth.getAuthorizationUrl(
          nsec:
              'nsec1vl029mgpspedva04g90vltkh6fvh240zqtv9k0t9af8935ke9laqsnlfe5',
        );

        final uri = Uri.parse(url);
        expect(uri.queryParameters.containsKey('byok_pubkey'), isTrue);
        expect(uri.queryParameters['byok_pubkey']?.length, 64);
        expect(verifier, contains('.nsec1'));
      });

      test('returns null URL for invalid nsec', () async {
        final oauth = KeycastOAuth(config: config);
        final (url, _) = await oauth.getAuthorizationUrl(nsec: 'invalid');
        expect(url, isEmpty);
      });
    });

    group('parseCallback', () {
      test('extracts code from successful callback', () {
        final oauth = KeycastOAuth(config: config);
        final result = oauth.parseCallback(
          'divine://oauth/callback?code=auth_code_123',
        );

        expect(result, isA<CallbackSuccess>());
        expect((result as CallbackSuccess).code, 'auth_code_123');
      });

      test('extracts error from failed callback', () {
        final oauth = KeycastOAuth(config: config);
        final result = oauth.parseCallback(
          'divine://oauth/callback?error=access_denied&error_description=User%20denied',
        );

        expect(result, isA<CallbackError>());
        final error = result as CallbackError;
        expect(error.error, 'access_denied');
        expect(error.description, 'User denied');
      });

      test('returns error for missing code and error', () {
        final oauth = KeycastOAuth(config: config);
        final result = oauth.parseCallback('divine://oauth/callback');

        expect(result, isA<CallbackError>());
        expect((result as CallbackError).error, 'invalid_response');
      });
    });

    group('exchangeCode', () {
      test('exchanges code for tokens', () async {
        final mockClient = MockClient((request) async {
          expect(
            request.url.toString(),
            'https://login.divine.video/api/oauth/token',
          );
          expect(request.method, 'POST');

          final body = jsonDecode(request.body);
          expect(body['grant_type'], 'authorization_code');
          expect(body['code'], 'auth_code');
          expect(body['code_verifier'], 'test_verifier');

          return http.Response(
            jsonEncode({
              'bunker_url': 'bunker://abc123',
              'access_token': 'access_token_xyz',
              'token_type': 'Bearer',
              'expires_in': 3600,
            }),
            200,
          );
        });

        final oauth = KeycastOAuth(config: config, httpClient: mockClient);
        final response = await oauth.exchangeCode(
          code: 'auth_code',
          verifier: 'test_verifier',
        );

        expect(response.bunkerUrl, 'bunker://abc123');
        expect(response.accessToken, 'access_token_xyz');
        expect(response.expiresIn, 3600);
      });

      test('throws OAuthException on error response', () async {
        final mockClient = MockClient((request) async {
          return http.Response(
            jsonEncode({
              'error': 'invalid_grant',
              'error_description': 'Code expired',
            }),
            400,
          );
        });

        final oauth = KeycastOAuth(config: config, httpClient: mockClient);

        expect(
          () => oauth.exchangeCode(code: 'bad_code', verifier: 'verifier'),
          throwsA(isA<Exception>()),
        );
      });
    });

    group('getSession', () {
      test('returns stored session when valid and not expired', () async {
        final storage = MemoryKeycastStorage();
        final session = KeycastSession(
          bunkerUrl: 'bunker://test123',
          accessToken: 'token123',
          expiresAt: DateTime.now().add(const Duration(hours: 1)),
        );
        await storage.write('keycast_session', jsonEncode(session.toJson()));

        final oauth = KeycastOAuth(config: config, storage: storage);
        final result = await oauth.getSession();

        expect(result, isNotNull);
        expect(result!.bunkerUrl, 'bunker://test123');
        expect(result.accessToken, 'token123');
      });

      test('returns null when session is expired', () async {
        final storage = MemoryKeycastStorage();
        final session = KeycastSession(
          bunkerUrl: 'bunker://test123',
          accessToken: 'token123',
          expiresAt: DateTime.now().subtract(const Duration(hours: 1)),
        );
        await storage.write('keycast_session', jsonEncode(session.toJson()));

        final oauth = KeycastOAuth(config: config, storage: storage);
        final result = await oauth.getSession();

        expect(result, isNull);
      });

      test('returns null when no session stored', () async {
        final storage = MemoryKeycastStorage();
        final oauth = KeycastOAuth(config: config, storage: storage);
        final result = await oauth.getSession();

        expect(result, isNull);
      });

      test('returns null when JSON parsing fails', () async {
        final storage = MemoryKeycastStorage();
        await storage.write('keycast_session', 'invalid json {{{');

        final oauth = KeycastOAuth(config: config, storage: storage);
        final result = await oauth.getSession();

        expect(result, isNull);
      });
    });

    group('logout', () {
      test('deletes session, handle, and refresh token from storage', () async {
        final storage = MemoryKeycastStorage();
        await storage.write('keycast_session', 'session_data');
        await storage.write('keycast_auth_handle', 'handle_data');
        await storage.write('keycast_refresh_token', 'refresh_data');

        final mockClient = MockClient((request) async {
          return http.Response('', 200);
        });

        final oauth = KeycastOAuth(
          config: config,
          httpClient: mockClient,
          storage: storage,
        );
        await oauth.logout();

        expect(await storage.read('keycast_session'), isNull);
        expect(await storage.read('keycast_auth_handle'), isNull);
        expect(await storage.read('keycast_refresh_token'), isNull);
      });

      test('makes POST request to logout endpoint', () async {
        var logoutCalled = false;
        final mockClient = MockClient((request) async {
          if (request.url.path == '/api/auth/logout') {
            expect(request.method, 'POST');
            logoutCalled = true;
          }
          return http.Response('', 200);
        });

        final oauth = KeycastOAuth(config: config, httpClient: mockClient);
        await oauth.logout();

        // The POST request is fire-and-forget (unawaited), so wait for microtasks
        await Future<void>.delayed(Duration.zero);

        expect(logoutCalled, isTrue);
      });

      test('does not leak an unhandled error when the server is '
          'unreachable', () async {
        final mockClient = MockClient((request) async {
          throw http.ClientException('Connection refused', request.url);
        });

        final oauth = KeycastOAuth(config: config, httpClient: mockClient);

        final escaped = <Object>[];
        await runZonedGuarded(() async {
          await oauth.logout();
          // Let the fire-and-forget POST reject.
          await Future<void>.delayed(Duration.zero);
        }, (error, _) => escaped.add(error));

        expect(
          escaped,
          isEmpty,
          reason:
              'Local logout is complete; a failed best-effort server '
              'notification must not surface as an unhandled async error',
        );
      });
    });

    group('getAuthorizationUrl - additional', () {
      test('includes authorization_handle when stored', () async {
        final storage = MemoryKeycastStorage();
        await storage.write('keycast_auth_handle', 'stored_handle_123');

        final oauth = KeycastOAuth(config: config, storage: storage);
        final (url, _) = await oauth.getAuthorizationUrl();

        final uri = Uri.parse(url);
        expect(
          uri.queryParameters['authorization_handle'],
          'stored_handle_123',
        );
      });

      test('includes prompt parameter when provided', () async {
        final oauth = KeycastOAuth(config: config);
        final (url, _) = await oauth.getAuthorizationUrl(prompt: 'login');

        final uri = Uri.parse(url);
        expect(uri.queryParameters['prompt'], 'login');
      });

      test('prefers explicit authorizationHandle over stored', () async {
        final storage = MemoryKeycastStorage();
        await storage.write('keycast_auth_handle', 'stored_handle');

        final oauth = KeycastOAuth(config: config, storage: storage);
        final (url, _) = await oauth.getAuthorizationUrl(
          authorizationHandle: 'explicit_handle',
        );

        final uri = Uri.parse(url);
        expect(uri.queryParameters['authorization_handle'], 'explicit_handle');
      });
    });

    group('headlessRegister', () {
      test('returns success result on 200 response', () async {
        final mockClient = MockClient((request) async {
          expect(request.url.path, '/api/headless/register');
          expect(request.method, 'POST');
          return http.Response(
            jsonEncode({
              'success': true,
              'pubkey': 'abc123pubkey',
              'verification_required': true,
              'device_code': 'device_code_123',
            }),
            200,
          );
        });

        final oauth = KeycastOAuth(config: config, httpClient: mockClient);
        final (result, verifier) = await oauth.headlessRegister(
          email: 'test@example.com',
          password: 'password123',
        );

        expect(result.success, isTrue);
        expect(result.pubkey, 'abc123pubkey');
        expect(result.deviceCode, 'device_code_123');
        expect(verifier, isNotEmpty);
      });

      test('returns success result on 201 response', () async {
        final mockClient = MockClient((request) async {
          return http.Response(
            jsonEncode({
              'success': true,
              'pubkey': 'newpubkey',
              'verification_required': true,
            }),
            201,
          );
        });

        final oauth = KeycastOAuth(config: config, httpClient: mockClient);
        final (result, _) = await oauth.headlessRegister(
          email: 'test@example.com',
          password: 'password123',
        );

        expect(result.success, isTrue);
      });

      test('includes nsec in body when provided', () async {
        final mockClient = MockClient((request) async {
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          expect(body['nsec'], contains('nsec1'));
          return http.Response(
            jsonEncode({
              'success': true,
              'pubkey': 'byok_pubkey',
              'verification_required': true,
            }),
            200,
          );
        });

        final oauth = KeycastOAuth(config: config, httpClient: mockClient);
        await oauth.headlessRegister(
          email: 'test@example.com',
          password: 'password123',
          nsec:
              'nsec1vl029mgpspedva04g90vltkh6fvh240zqtv9k0t9af8935ke9laqsnlfe5',
        );
      });

      test('includes state parameter when provided', () async {
        final mockClient = MockClient((request) async {
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          expect(body['state'], 'my_state_value');
          return http.Response(
            jsonEncode({
              'success': true,
              'pubkey': 'pubkey',
              'verification_required': true,
            }),
            200,
          );
        });

        final oauth = KeycastOAuth(config: config, httpClient: mockClient);
        await oauth.headlessRegister(
          email: 'test@example.com',
          password: 'password123',
          state: 'my_state_value',
        );
      });

      test('sends marketing_consent true in body when opted in', () async {
        final mockClient = MockClient((request) async {
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          expect(body['marketing_consent'], isTrue);
          return http.Response(
            jsonEncode({
              'success': true,
              'pubkey': 'pubkey',
              'verification_required': true,
            }),
            200,
          );
        });

        final oauth = KeycastOAuth(config: config, httpClient: mockClient);
        await oauth.headlessRegister(
          email: 'test@example.com',
          password: 'password123',
          marketingConsent: true,
        );
      });

      test('sends marketing_consent false in body by default', () async {
        final mockClient = MockClient((request) async {
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          expect(body['marketing_consent'], isFalse);
          return http.Response(
            jsonEncode({
              'success': true,
              'pubkey': 'pubkey',
              'verification_required': true,
            }),
            200,
          );
        });

        final oauth = KeycastOAuth(config: config, httpClient: mockClient);
        await oauth.headlessRegister(
          email: 'test@example.com',
          password: 'password123',
        );
      });

      test('returns error on 404 response', () async {
        final mockClient = MockClient((request) async {
          return http.Response('Not Found', 404);
        });

        final oauth = KeycastOAuth(config: config, httpClient: mockClient);
        final (result, _) = await oauth.headlessRegister(
          email: 'test@example.com',
          password: 'password123',
        );

        expect(result.success, isFalse);
        expect(result.errorDescription, contains('not available'));
      });

      test('returns error on 500+ server error', () async {
        final mockClient = MockClient((request) async {
          return http.Response('Internal Server Error', 500);
        });

        final oauth = KeycastOAuth(config: config, httpClient: mockClient);
        final (result, _) = await oauth.headlessRegister(
          email: 'test@example.com',
          password: 'password123',
        );

        expect(result.success, isFalse);
        expect(result.errorDescription, contains('Server error'));
        expect(result.errorDescription, contains('500'));
      });

      test('returns error on invalid JSON response', () async {
        final mockClient = MockClient((request) async {
          return http.Response('not valid json {{{', 200);
        });

        final oauth = KeycastOAuth(config: config, httpClient: mockClient);
        final (result, _) = await oauth.headlessRegister(
          email: 'test@example.com',
          password: 'password123',
        );

        expect(result.success, isFalse);
        expect(result.errorDescription, contains('Invalid server response'));
      });

      test('returns error with error/message fields from response', () async {
        final mockClient = MockClient((request) async {
          return http.Response(
            jsonEncode({
              'code': 'CONFLICT',
              'error': 'Email already registered',
            }),
            400,
          );
        });

        final oauth = KeycastOAuth(config: config, httpClient: mockClient);
        final (result, _) = await oauth.headlessRegister(
          email: 'test@example.com',
          password: 'password123',
        );

        expect(result.success, isFalse);
        expect(result.errorCode, contains('CONFLICT'));
        expect(result.errorDescription, contains('Email already registered'));
      });

      test('returns error on SocketException', () async {
        final mockClient = MockClient((request) async {
          throw const SocketException('Connection refused');
        });

        final oauth = KeycastOAuth(config: config, httpClient: mockClient);
        final (result, _) = await oauth.headlessRegister(
          email: 'test@example.com',
          password: 'password123',
        );

        expect(result.success, isFalse);
        expect(result.errorDescription, contains('Cannot connect to server'));
      });

      test('returns error on other network errors', () async {
        final mockClient = MockClient((request) async {
          throw Exception('Some other error');
        });

        final oauth = KeycastOAuth(config: config, httpClient: mockClient);
        final (result, _) = await oauth.headlessRegister(
          email: 'test@example.com',
          password: 'password123',
        );

        expect(result.success, isFalse);
        expect(result.errorDescription, contains('Network error'));
      });
    });

    group('headlessLogin', () {
      test('returns success result on 200 response', () async {
        final mockClient = MockClient((request) async {
          expect(request.url.path, '/api/headless/login');
          expect(request.method, 'POST');
          return http.Response(
            jsonEncode({
              'success': true,
              'code': 'auth_code_123',
              'pubkey': 'user_pubkey',
            }),
            200,
          );
        });

        final oauth = KeycastOAuth(config: config, httpClient: mockClient);
        final (result, verifier) = await oauth.headlessLogin(
          email: 'test@example.com',
          password: 'password123',
        );

        expect(result.success, isTrue);
        expect(result.code, 'auth_code_123');
        expect(result.pubkey, 'user_pubkey');
        expect(verifier, isNotEmpty);
      });

      test('includes state parameter when provided', () async {
        final mockClient = MockClient((request) async {
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          expect(body['state'], 'login_state');
          return http.Response(
            jsonEncode({'success': true, 'code': 'code123'}),
            200,
          );
        });

        final oauth = KeycastOAuth(config: config, httpClient: mockClient);
        await oauth.headlessLogin(
          email: 'test@example.com',
          password: 'password123',
          state: 'login_state',
        );
      });

      test('returns error on 404 response', () async {
        final mockClient = MockClient((request) async {
          return http.Response('Not Found', 404);
        });

        final oauth = KeycastOAuth(config: config, httpClient: mockClient);
        final (result, _) = await oauth.headlessLogin(
          email: 'test@example.com',
          password: 'password123',
        );

        expect(result.success, isFalse);
        expect(result.errorCode, 'endpoint_not_found');
      });

      test('returns error on 500+ server error', () async {
        final mockClient = MockClient((request) async {
          return http.Response('Internal Server Error', 503);
        });

        final oauth = KeycastOAuth(config: config, httpClient: mockClient);
        final (result, _) = await oauth.headlessLogin(
          email: 'test@example.com',
          password: 'password123',
        );

        expect(result.success, isFalse);
        expect(result.errorCode, 'server_error');
        expect(result.errorDescription, contains('503'));
      });

      test('returns error on invalid JSON response', () async {
        final mockClient = MockClient((request) async {
          return http.Response('not valid json', 200);
        });

        final oauth = KeycastOAuth(config: config, httpClient: mockClient);
        final (result, _) = await oauth.headlessLogin(
          email: 'test@example.com',
          password: 'password123',
        );

        expect(result.success, isFalse);
        expect(result.errorCode, 'invalid_response');
      });

      test('reads keycast INVALID_CREDENTIALS 401 (machine code + '
          'human message, no error_description)', () async {
        // Byte-for-byte the body keycast returns on a failed login (observed
        // via a cargo test + live e2e against keycast @5cda156):
        // {"error":"Invalid email or password","code":"INVALID_CREDENTIALS"}
        final mockClient = MockClient((request) async {
          return http.Response(
            jsonEncode({
              'code': 'INVALID_CREDENTIALS',
              'error': 'Invalid email or password',
            }),
            401,
          );
        });

        final oauth = KeycastOAuth(config: config, httpClient: mockClient);
        final (result, _) = await oauth.headlessLogin(
          email: 'test@example.com',
          password: 'password123',
        );

        expect(result.success, isFalse);
        expect(result.errorCode, 'INVALID_CREDENTIALS');
        expect(result.failure, KeycastLoginFailure.invalidCredentials);
        // The human message keycast actually sends, not a client fallback.
        expect(result.errorDescription, 'Invalid email or password');
      });

      test('classifies EMAIL_NOT_VERIFIED 403', () async {
        final mockClient = MockClient((request) async {
          return http.Response(
            jsonEncode({
              'code': 'EMAIL_NOT_VERIFIED',
              'error': 'Please verify your email address before signing in',
            }),
            403,
          );
        });

        final oauth = KeycastOAuth(config: config, httpClient: mockClient);
        final (result, _) = await oauth.headlessLogin(
          email: 'test@example.com',
          password: 'password123',
        );

        expect(result.errorCode, 'EMAIL_NOT_VERIFIED');
        expect(result.failure, KeycastLoginFailure.emailNotVerified);
      });

      test('classifies INVALID_EMAIL 400', () async {
        final mockClient = MockClient((request) async {
          return http.Response(
            jsonEncode({
              'code': 'INVALID_EMAIL',
              'error': 'Please enter a valid email address.',
            }),
            400,
          );
        });

        final oauth = KeycastOAuth(config: config, httpClient: mockClient);
        final (result, _) = await oauth.headlessLogin(
          email: 'bad',
          password: 'password123',
        );

        expect(result.errorCode, 'INVALID_EMAIL');
        expect(result.failure, KeycastLoginFailure.invalidEmail);
      });

      test('returns error on SocketException', () async {
        final mockClient = MockClient((request) async {
          throw const SocketException('Connection refused');
        });

        final oauth = KeycastOAuth(config: config, httpClient: mockClient);
        final (result, _) = await oauth.headlessLogin(
          email: 'test@example.com',
          password: 'password123',
        );

        expect(result.success, isFalse);
        expect(result.errorCode, 'connection_error');
        expect(result.failure, KeycastLoginFailure.network);
      });

      test('returns error on other network errors', () async {
        final mockClient = MockClient((request) async {
          throw Exception('Timeout');
        });

        final oauth = KeycastOAuth(config: config, httpClient: mockClient);
        final (result, _) = await oauth.headlessLogin(
          email: 'test@example.com',
          password: 'password123',
        );

        expect(result.success, isFalse);
        expect(result.errorCode, 'network_error');
        expect(result.failure, KeycastLoginFailure.network);
        expect(result.errorDescription, contains('Network error'));
      });
    });

    group('pollForCode', () {
      test('returns complete with code on 200 with code', () async {
        final mockClient = MockClient((request) async {
          expect(request.url.path, '/api/oauth/poll');
          expect(request.url.queryParameters['device_code'], 'device123');
          return http.Response(jsonEncode({'code': 'auth_code_456'}), 200);
        });

        final oauth = KeycastOAuth(config: config, httpClient: mockClient);
        final result = await oauth.pollForCode('device123');

        expect(result.status, PollStatus.complete);
        expect(result.code, 'auth_code_456');
      });

      test('returns pending on 200 without code', () async {
        final mockClient = MockClient((request) async {
          return http.Response(jsonEncode({}), 200);
        });

        final oauth = KeycastOAuth(config: config, httpClient: mockClient);
        final result = await oauth.pollForCode('device123');

        expect(result.status, PollStatus.pending);
      });

      test('returns pending on 202 status', () async {
        final mockClient = MockClient((request) async {
          return http.Response('', 202);
        });

        final oauth = KeycastOAuth(config: config, httpClient: mockClient);
        final result = await oauth.pollForCode('device123');

        expect(result.status, PollStatus.pending);
      });

      test('returns error with JSON error on non-200/202', () async {
        final mockClient = MockClient((request) async {
          return http.Response(
            jsonEncode({
              'error': 'expired_token',
              'error_description': 'Device code expired',
            }),
            400,
          );
        });

        final oauth = KeycastOAuth(config: config, httpClient: mockClient);
        final result = await oauth.pollForCode('device123');

        expect(result.status, PollStatus.error);
        expect(result.error, 'Device code expired');
        expect(result.errorCode, 'expired_token');
        expect(result.statusCode, 400);
      });

      test('returns terminal duplicate email failure on 409', () async {
        final mockClient = MockClient((request) async {
          return http.Response(
            jsonEncode({'error': 'This email is already registered.'}),
            409,
          );
        });

        final oauth = KeycastOAuth(config: config, httpClient: mockClient);
        final result = await oauth.pollForCode('device123');

        expect(result.status, PollStatus.error);
        expect(result.error, 'This email is already registered.');
        expect(result.statusCode, 409);
        expect(result.failure, KeycastAuthFailure.emailAlreadyRegistered);
        expect(result.isTransientFailure, isFalse);
      });

      test('returns transient failure on 503', () async {
        final mockClient = MockClient((request) async {
          return http.Response(
            jsonEncode({'error': 'Temporary verification failure'}),
            503,
          );
        });

        final oauth = KeycastOAuth(config: config, httpClient: mockClient);
        final result = await oauth.pollForCode('device123');

        expect(result.status, PollStatus.error);
        expect(result.error, 'Temporary verification failure');
        expect(result.statusCode, 503);
        expect(result.failure, KeycastAuthFailure.temporary);
        expect(result.isTransientFailure, isTrue);
      });

      test('returns error with HTTP status on invalid JSON', () async {
        final mockClient = MockClient((request) async {
          return http.Response('not json', 400);
        });

        final oauth = KeycastOAuth(config: config, httpClient: mockClient);
        final result = await oauth.pollForCode('device123');

        expect(result.status, PollStatus.error);
        expect(result.error, 'HTTP 400');
      });

      test('returns error on network error', () async {
        final mockClient = MockClient((request) async {
          throw Exception('Network failure');
        });

        final oauth = KeycastOAuth(config: config, httpClient: mockClient);
        final result = await oauth.pollForCode('device123');

        expect(result.status, PollStatus.error);
        expect(result.error, contains('Network error'));
      });
    });

    group('verifyPin', () {
      test('returns success with code on 200 with code', () async {
        final mockClient = MockClient((request) async {
          expect(request.url.path, '/api/headless/verify-pin');
          expect(request.method, 'POST');
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          expect(body['device_code'], 'device123');
          expect(body['pin'], '123456');
          return http.Response(jsonEncode({'code': 'auth_code_789'}), 200);
        });

        final oauth = KeycastOAuth(config: config, httpClient: mockClient);
        final result = await oauth.verifyPin(
          deviceCode: 'device123',
          pin: '123456',
        );

        expect(result.success, isTrue);
        expect(result.code, 'auth_code_789');
        expect(result.errorCode, isNull);
      });

      test('returns success on 201 with code', () async {
        final mockClient = MockClient((request) async {
          return http.Response(jsonEncode({'code': 'auth_code_789'}), 201);
        });

        final oauth = KeycastOAuth(config: config, httpClient: mockClient);
        final result = await oauth.verifyPin(
          deviceCode: 'device123',
          pin: '123456',
        );

        expect(result.success, isTrue);
        expect(result.code, 'auth_code_789');
      });

      test('treats 200 with an empty code as already completed', () async {
        final mockClient = MockClient((request) async {
          return http.Response(jsonEncode({'success': true, 'code': ''}), 200);
        });

        final oauth = KeycastOAuth(config: config, httpClient: mockClient);
        final result = await oauth.verifyPin(
          deviceCode: 'device123',
          pin: '123456',
        );

        expect(result.success, isTrue);
        expect(result.alreadyCompleted, isTrue);
        expect(result.code, isNull);
        expect(result.errorCode, isNull);
      });

      test('maps 400 to an invalid-PIN error', () async {
        final mockClient = MockClient((request) async {
          return http.Response(
            jsonEncode({
              'error': 'invalid_pin',
              'error_description': 'Incorrect code',
            }),
            400,
          );
        });

        final oauth = KeycastOAuth(config: config, httpClient: mockClient);
        final result = await oauth.verifyPin(
          deviceCode: 'device123',
          pin: '000000',
        );

        expect(result.success, isFalse);
        expect(result.errorCode, VerifyPinError.invalid);
      });

      test('maps an expired error code to an expired-PIN error', () async {
        final mockClient = MockClient((request) async {
          return http.Response(jsonEncode({'error': 'pin_expired'}), 410);
        });

        final oauth = KeycastOAuth(config: config, httpClient: mockClient);
        final result = await oauth.verifyPin(
          deviceCode: 'device123',
          pin: '123456',
        );

        expect(result.success, isFalse);
        expect(result.errorCode, VerifyPinError.expired);
      });

      test('maps a lockout response to a locked-PIN error', () async {
        final mockClient = MockClient((request) async {
          return http.Response(jsonEncode({'error': 'too_many_attempts'}), 429);
        });

        final oauth = KeycastOAuth(config: config, httpClient: mockClient);
        final result = await oauth.verifyPin(
          deviceCode: 'device123',
          pin: '123456',
        );

        expect(result.success, isFalse);
        expect(result.errorCode, VerifyPinError.locked);
      });

      test('maps a 404 (endpoint absent) to an unavailable error', () async {
        // A 404 means the verify-pin endpoint isn't deployed on this server.
        // Surfaced as "use the email link / resend", not "incorrect PIN".
        final mockClient = MockClient((request) async {
          return http.Response('Not Found', 404);
        });

        final oauth = KeycastOAuth(config: config, httpClient: mockClient);
        final result = await oauth.verifyPin(
          deviceCode: 'device123',
          pin: '123456',
        );

        expect(result.success, isFalse);
        expect(result.errorCode, VerifyPinError.unavailable);
      });

      test('maps an unclassified 4xx to an unavailable error', () async {
        // Anything that isn't the expected wrong-PIN response (400/401) and
        // isn't locked/expired is treated as the PIN path being unavailable.
        final mockClient = MockClient((request) async {
          return http.Response(jsonEncode({'error': 'forbidden'}), 403);
        });

        final oauth = KeycastOAuth(config: config, httpClient: mockClient);
        final result = await oauth.verifyPin(
          deviceCode: 'device123',
          pin: '123456',
        );

        expect(result.success, isFalse);
        expect(result.errorCode, VerifyPinError.unavailable);
      });

      test(
        'maps 409 EMAIL_ALREADY_EXISTS to duplicate-email recovery',
        () async {
          final mockClient = MockClient((request) async {
            return http.Response(
              jsonEncode({'code': 'EMAIL_ALREADY_EXISTS'}),
              409,
            );
          });

          final oauth = KeycastOAuth(config: config, httpClient: mockClient);
          final result = await oauth.verifyPin(
            deviceCode: 'device123',
            pin: '123456',
          );

          expect(result.success, isFalse);
          expect(result.errorCode, VerifyPinError.emailAlreadyRegistered);
        },
      );

      test('maps a 401 to an invalid-PIN error', () async {
        final mockClient = MockClient((request) async {
          return http.Response(jsonEncode({'error': 'unauthorized'}), 401);
        });

        final oauth = KeycastOAuth(config: config, httpClient: mockClient);
        final result = await oauth.verifyPin(
          deviceCode: 'device123',
          pin: '000000',
        );

        expect(result.success, isFalse);
        expect(result.errorCode, VerifyPinError.invalid);
      });

      test('maps a 5xx response to a server error', () async {
        final mockClient = MockClient((request) async {
          return http.Response('Internal Server Error', 500);
        });

        final oauth = KeycastOAuth(config: config, httpClient: mockClient);
        final result = await oauth.verifyPin(
          deviceCode: 'device123',
          pin: '123456',
        );

        expect(result.success, isFalse);
        expect(result.errorCode, VerifyPinError.server);
      });

      test('maps invalid JSON to a server error', () async {
        final mockClient = MockClient((request) async {
          return http.Response('not json {{{', 400);
        });

        final oauth = KeycastOAuth(config: config, httpClient: mockClient);
        final result = await oauth.verifyPin(
          deviceCode: 'device123',
          pin: '123456',
        );

        expect(result.success, isFalse);
        expect(result.errorCode, VerifyPinError.server);
      });

      test('maps a network failure to a network error', () async {
        final mockClient = MockClient((request) async {
          throw Exception('Network failure');
        });

        final oauth = KeycastOAuth(config: config, httpClient: mockClient);
        final result = await oauth.verifyPin(
          deviceCode: 'device123',
          pin: '123456',
        );

        expect(result.success, isFalse);
        expect(result.errorCode, VerifyPinError.network);
      });

      test(
        'honors json[code] for the failure identifier (no error field)',
        () async {
          // keycast may return the error identifier under `code` (same as the
          // 2xx success path and register/login helpers). A 400 whose status
          // alone would read as wrong-PIN must still map to expired via the code.
          final mockClient = MockClient((request) async {
            return http.Response(jsonEncode({'code': 'pin_expired'}), 400);
          });

          final oauth = KeycastOAuth(config: config, httpClient: mockClient);
          final result = await oauth.verifyPin(
            deviceCode: 'device123',
            pin: '123456',
          );

          expect(result.success, isFalse);
          expect(result.errorCode, VerifyPinError.expired);
        },
      );

      test(
        'maps a generic invalid_request 400 to unavailable, not invalid',
        () async {
          // A generic OAuth/request error is NOT a wrong-PIN signal; treat it as
          // the PIN path being unavailable so the user is steered to the link /
          // resend instead of being told their PIN was wrong.
          final mockClient = MockClient((request) async {
            return http.Response(jsonEncode({'error': 'invalid_request'}), 400);
          });

          final oauth = KeycastOAuth(config: config, httpClient: mockClient);
          final result = await oauth.verifyPin(
            deviceCode: 'device123',
            pin: '123456',
          );

          expect(result.success, isFalse);
          expect(result.errorCode, VerifyPinError.unavailable);
        },
      );

      test('maps a genuine wrong-PIN 400 to an invalid-PIN error', () async {
        final mockClient = MockClient((request) async {
          return http.Response(jsonEncode({'error': 'invalid_pin'}), 400);
        });

        final oauth = KeycastOAuth(config: config, httpClient: mockClient);
        final result = await oauth.verifyPin(
          deviceCode: 'device123',
          pin: '000000',
        );

        expect(result.success, isFalse);
        expect(result.errorCode, VerifyPinError.invalid);
      });
    });

    group('resendVerification', () {
      test('posts the email and returns success on 200', () async {
        final mockClient = MockClient((request) async {
          expect(request.url.path, '/api/auth/resend-verification');
          expect(request.method, 'POST');
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          expect(body['email'], 'test@example.com');
          return http.Response(
            jsonEncode({'success': true, 'message': 'Sent'}),
            200,
          );
        });

        final oauth = KeycastOAuth(config: config, httpClient: mockClient);
        final result = await oauth.resendVerification('test@example.com');

        expect(result.success, isTrue);
      });

      test('returns success even when the body is not JSON', () async {
        final mockClient = MockClient((request) async {
          return http.Response('OK', 200);
        });

        final oauth = KeycastOAuth(config: config, httpClient: mockClient);
        final result = await oauth.resendVerification('test@example.com');

        expect(result.success, isTrue);
      });

      test('returns failure on a network error', () async {
        final mockClient = MockClient((request) async {
          throw Exception('Network failure');
        });

        final oauth = KeycastOAuth(config: config, httpClient: mockClient);
        final result = await oauth.resendVerification('test@example.com');

        expect(result.success, isFalse);
      });
    });

    group('resendHeadlessVerification', () {
      test(
        'posts the device code to the headless resend-pin endpoint',
        () async {
          final mockClient = MockClient((request) async {
            expect(request.url.path, '/api/headless/resend-pin');
            expect(request.method, 'POST');
            final body = jsonDecode(request.body) as Map<String, dynamic>;
            expect(body['device_code'], 'device123');
            expect(body.containsKey('email'), isFalse);
            return http.Response(
              jsonEncode({'success': true, 'message': 'Sent'}),
              200,
            );
          });

          final oauth = KeycastOAuth(config: config, httpClient: mockClient);
          final result = await oauth.resendHeadlessVerification('device123');

          expect(result.success, isTrue);
        },
      );

      test('returns success even when the body is not JSON', () async {
        final mockClient = MockClient((request) async {
          return http.Response('OK', 200);
        });

        final oauth = KeycastOAuth(config: config, httpClient: mockClient);
        final result = await oauth.resendHeadlessVerification('device123');

        expect(result.success, isTrue);
      });

      test('returns failure on a network error', () async {
        final mockClient = MockClient((request) async {
          throw Exception('Network failure');
        });

        final oauth = KeycastOAuth(config: config, httpClient: mockClient);
        final result = await oauth.resendHeadlessVerification('device123');

        expect(result.success, isFalse);
        expect(result.errorCode, ResendVerificationError.network);
      });

      test('reports a 404 as unavailable, not a decline', () async {
        final mockClient = MockClient((request) async {
          return http.Response('Not Found', 404);
        });

        final oauth = KeycastOAuth(config: config, httpClient: mockClient);
        final result = await oauth.resendHeadlessVerification('device123');

        expect(result.success, isFalse);
        expect(result.errorCode, ResendVerificationError.unavailable);
      });

      // Status, both body keys and the message string are copied verbatim from
      // keycast `headless_resend_pin`, the `expires_at <= Utc::now()` branch in
      // `api/src/api/http/headless.rs`. That route answers an expired
      // registration with 200 and `success: false`, not with the 410 the
      // `/api/auth/*` routes use for their unrelated RegistrationExpired.
      test('reports an expired registration response as expired', () async {
        final mockClient = MockClient((request) async {
          return http.Response(
            jsonEncode({
              'success': false,
              'message': 'This registration has expired. Please sign up again.',
            }),
            200,
          );
        });

        final oauth = KeycastOAuth(config: config, httpClient: mockClient);
        final result = await oauth.resendHeadlessVerification('device123');

        expect(result.success, isFalse);
        expect(
          result.message,
          'This registration has expired. Please sign up again.',
        );
        expect(result.errorCode, ResendVerificationError.expired);
      });

      test('reports an unrecognised success:false body as declined', () async {
        final mockClient = MockClient((request) async {
          return http.Response(
            jsonEncode({
              'success': false,
              'message': 'Please try again later.',
            }),
            200,
          );
        });

        final oauth = KeycastOAuth(config: config, httpClient: mockClient);
        final result = await oauth.resendHeadlessVerification('device123');

        expect(result.success, isFalse);
        expect(result.errorCode, ResendVerificationError.declined);
      });

      test('reports a 4xx other than 404 as declined', () async {
        final mockClient = MockClient((request) async {
          return http.Response(jsonEncode({'error': 'too_many'}), 429);
        });

        final oauth = KeycastOAuth(config: config, httpClient: mockClient);
        final result = await oauth.resendHeadlessVerification('device123');

        expect(result.errorCode, ResendVerificationError.declined);
      });

      test('reports a 5xx as a server failure', () async {
        final mockClient = MockClient((request) async {
          return http.Response('boom', 503);
        });

        final oauth = KeycastOAuth(config: config, httpClient: mockClient);
        final result = await oauth.resendHeadlessVerification('device123');

        expect(result.errorCode, ResendVerificationError.server);
      });
    });

    group('sendPasswordResetEmail', () {
      test('returns success on 200 response', () async {
        final mockClient = MockClient((request) async {
          expect(request.url.path, '/api/auth/forgot-password');
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          expect(body['email'], 'test@example.com');
          return http.Response(
            jsonEncode({'success': true, 'message': 'Email sent'}),
            200,
          );
        });

        final oauth = KeycastOAuth(config: config, httpClient: mockClient);
        final result = await oauth.sendPasswordResetEmail('test@example.com');

        expect(result.success, isTrue);
        expect(result.message, 'Email sent');
      });

      test('returns success on 201 response', () async {
        final mockClient = MockClient((request) async {
          return http.Response(jsonEncode({'success': true}), 201);
        });

        final oauth = KeycastOAuth(config: config, httpClient: mockClient);
        final result = await oauth.sendPasswordResetEmail('test@example.com');

        expect(result.success, isTrue);
      });

      test('returns error with error/message from response', () async {
        final mockClient = MockClient((request) async {
          return http.Response(
            jsonEncode({
              'error': 'user_not_found',
              'message': 'No user with that email',
            }),
            404,
          );
        });

        final oauth = KeycastOAuth(config: config, httpClient: mockClient);
        final result = await oauth.sendPasswordResetEmail('test@example.com');

        expect(result.success, isFalse);
        expect(result.error, contains('user_not_found'));
      });

      test('returns error on network error', () async {
        final mockClient = MockClient((request) async {
          throw Exception('Connection timeout');
        });

        final oauth = KeycastOAuth(config: config, httpClient: mockClient);
        final result = await oauth.sendPasswordResetEmail('test@example.com');

        expect(result.success, isFalse);
        expect(result.error, contains('Network error'));
      });
    });

    group('resetPassword', () {
      test('returns success on 200 response', () async {
        final mockClient = MockClient((request) async {
          expect(request.url.path, '/api/auth/reset-password');
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          expect(body['token'], 'reset_token_123');
          expect(body['new_password'], 'newpassword456');
          return http.Response(
            jsonEncode({'success': true, 'message': 'Password reset'}),
            200,
          );
        });

        final oauth = KeycastOAuth(config: config, httpClient: mockClient);
        final result = await oauth.resetPassword(
          token: 'reset_token_123',
          newPassword: 'newpassword456',
        );

        expect(result.success, isTrue);
        expect(result.message, 'Password reset');
      });

      test('returns success on 201 response', () async {
        final mockClient = MockClient((request) async {
          return http.Response(jsonEncode({'success': true}), 201);
        });

        final oauth = KeycastOAuth(config: config, httpClient: mockClient);
        final result = await oauth.resetPassword(
          token: 'token',
          newPassword: 'password',
        );

        expect(result.success, isTrue);
      });

      test('returns error with message from response', () async {
        final mockClient = MockClient((request) async {
          return http.Response(jsonEncode({'message': 'Token expired'}), 400);
        });

        final oauth = KeycastOAuth(config: config, httpClient: mockClient);
        final result = await oauth.resetPassword(
          token: 'expired_token',
          newPassword: 'password',
        );

        expect(result.success, isFalse);
        expect(result.message, 'Token expired');
      });

      test('returns error on network error', () async {
        final mockClient = MockClient((request) async {
          throw Exception('Server unreachable');
        });

        final oauth = KeycastOAuth(config: config, httpClient: mockClient);
        final result = await oauth.resetPassword(
          token: 'token',
          newPassword: 'password',
        );

        expect(result.success, isFalse);
        expect(result.message, contains('Network error'));
      });
    });

    group('verifyEmail', () {
      test('returns success on idempotent completed verification', () async {
        final mockClient = MockClient((request) async {
          expect(request.url.path, '/api/auth/verify-email');
          expect(request.method, 'POST');
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          expect(body['token'], 'verify-token');
          return http.Response(
            jsonEncode({'success': true, 'message': 'Email already verified'}),
            200,
          );
        });

        final oauth = KeycastOAuth(config: config, httpClient: mockClient);
        final result = await oauth.verifyEmail(token: 'verify-token');

        expect(result.success, isTrue);
        expect(result.message, 'Email already verified');
        expect(result.statusCode, 200);
        expect(result.failure, isNull);
      });

      test('maps duplicate email conflict to terminal failure', () async {
        final mockClient = MockClient((request) async {
          return http.Response(
            jsonEncode({
              'error':
                  'This email is already registered. Please log in instead.',
            }),
            409,
          );
        });

        final oauth = KeycastOAuth(config: config, httpClient: mockClient);
        final result = await oauth.verifyEmail(token: 'duplicate-token');

        expect(result.success, isFalse);
        expect(
          result.error,
          'This email is already registered. Please log in instead.',
        );
        expect(
          result.errorCode,
          'This email is already registered. Please log in instead.',
        );
        expect(result.statusCode, 409);
        expect(result.failure, KeycastAuthFailure.emailAlreadyRegistered);
        expect(result.isTransientFailure, isFalse);
      });

      test('maps expired token to expired verification failure', () async {
        final mockClient = MockClient((request) async {
          return http.Response(
            jsonEncode({'error': 'Invalid or expired verification token'}),
            401,
          );
        });

        final oauth = KeycastOAuth(config: config, httpClient: mockClient);
        final result = await oauth.verifyEmail(token: 'expired-token');

        expect(result.success, isFalse);
        expect(result.error, 'Invalid or expired verification token');
        expect(result.statusCode, 401);
        expect(result.failure, KeycastAuthFailure.expiredVerification);
      });

      test('maps backend failure to transient failure', () async {
        final mockClient = MockClient((request) async {
          return http.Response(
            jsonEncode({'error': 'Temporary verification failure'}),
            503,
          );
        });

        final oauth = KeycastOAuth(config: config, httpClient: mockClient);
        final result = await oauth.verifyEmail(token: 'retry-token');

        expect(result.success, isFalse);
        expect(result.error, 'Temporary verification failure');
        expect(result.statusCode, 503);
        expect(result.failure, KeycastAuthFailure.temporary);
        expect(result.isTransientFailure, isTrue);
      });
    });

    group('deleteAccount', () {
      test('returns success and clears storage on 200', () async {
        final storage = MemoryKeycastStorage();
        await storage.write('keycast_session', 'session_data');
        await storage.write('keycast_auth_handle', 'handle_data');
        await storage.write('keycast_refresh_token', 'refresh_data');

        final mockClient = MockClient((request) async {
          expect(request.url.path, '/api/user/account');
          expect(request.method, 'DELETE');
          expect(request.headers['Authorization'], 'Bearer test_token');
          return http.Response(
            jsonEncode({'success': true, 'message': 'Account deleted'}),
            200,
          );
        });

        final oauth = KeycastOAuth(
          config: config,
          httpClient: mockClient,
          storage: storage,
        );
        final result = await oauth.deleteAccount('test_token');

        expect(result.success, isTrue);
        expect(result.message, 'Account deleted');
        expect(await storage.read('keycast_session'), isNull);
        expect(await storage.read('keycast_auth_handle'), isNull);
        expect(await storage.read('keycast_refresh_token'), isNull);
      });

      test('returns error on 401 unauthorized', () async {
        final mockClient = MockClient((request) async {
          return http.Response('Unauthorized', 401);
        });

        final oauth = KeycastOAuth(config: config, httpClient: mockClient);
        final result = await oauth.deleteAccount('invalid_token');

        expect(result.success, isFalse);
        expect(result.error, contains('Unauthorized'));
        expect(result.requiresReauthentication, isTrue);
      });

      test(
        'flags reauthentication on 403 carrying the server message',
        () async {
          // Verbatim body from keycast's delete_account handler when the token
          // is neither user-signed nor first-party. It does not contain any of
          // the phrases a client might be tempted to match on, which is why the
          // flag exists.
          const serverMessage =
              'Account deletion requires the Divine app or web login with your '
              'private key';
          final mockClient = MockClient((request) async {
            return http.Response(jsonEncode({'error': serverMessage}), 403);
          });

          final oauth = KeycastOAuth(config: config, httpClient: mockClient);
          final result = await oauth.deleteAccount('refreshed_token');

          expect(result.success, isFalse);
          expect(result.error, serverMessage);
          expect(result.requiresReauthentication, isTrue);
        },
      );

      test('flags reauthentication on 403 with an unreadable body', () async {
        final mockClient = MockClient((request) async {
          return http.Response('Forbidden', 403);
        });

        final oauth = KeycastOAuth(config: config, httpClient: mockClient);
        final result = await oauth.deleteAccount('refreshed_token');

        expect(result.success, isFalse);
        expect(result.error, contains('requires signing in again'));
        expect(result.requiresReauthentication, isTrue);
      });

      test('sends the bearer token even when a signer is available', () async {
        // keycast's delete route strips a `Bearer ` prefix and rejects every
        // other scheme, so leading with a `Nostr` proof is answered 401 before
        // the proof is read — after the irreversible NIP-62 vanish has already
        // been published. Leading with the bearer token is the whole fix.
        final sentAuthorizations = <String?>[];
        var signerCalls = 0;
        final mockClient = MockClient((request) async {
          sentAuthorizations.add(request.headers['Authorization']);
          return http.Response(
            jsonEncode({'success': true, 'message': 'Account deleted'}),
            200,
          );
        });

        final oauth = KeycastOAuth(config: config, httpClient: mockClient);
        final result = await oauth.deleteAccount(
          'refreshed_token',
          nip98Signer: (_) async {
            signerCalls++;
            return 'BASE64EVENT';
          },
        );

        expect(result.success, isTrue);
        expect(sentAuthorizations, ['Bearer refreshed_token']);
        expect(signerCalls, isZero);
      });

      test('retries with a NIP-98 proof after a 403', () async {
        // A 403 means the credential was read and refused, which is the case a
        // proof-of-key would cure. A 401 means it could not be read at all.
        final sentAuthorizations = <String?>[];
        final mockClient = MockClient((request) async {
          sentAuthorizations.add(request.headers['Authorization']);
          if (sentAuthorizations.length == 1) {
            return http.Response('Forbidden', 403);
          }
          return http.Response(
            jsonEncode({'success': true, 'message': 'Account deleted'}),
            200,
          );
        });

        final oauth = KeycastOAuth(config: config, httpClient: mockClient);
        final result = await oauth.deleteAccount(
          'refreshed_token',
          nip98Signer: (_) async => 'BASE64EVENT',
        );

        expect(result.success, isTrue);
        expect(sentAuthorizations, [
          'Bearer refreshed_token',
          'Nostr BASE64EVENT',
        ]);
      });

      test('keeps the 403 when the proof retry is refused', () async {
        // Keycast strips a `Bearer ` prefix and answers every other scheme
        // 401, so the retry this route allows is exactly the one it rejects.
        // Adopting that 401 would replace the accurate "not authorized to
        // delete" — plus the server's own prose — with "invalid or expired
        // token", which is the misdiagnosis #4881 is about.
        final sentAuthorizations = <String?>[];
        final mockClient = MockClient((request) async {
          sentAuthorizations.add(request.headers['Authorization']);
          if (sentAuthorizations.length == 1) {
            return http.Response(
              jsonEncode({'message': 'Account deletion requires the app'}),
              403,
            );
          }
          return http.Response('Invalid or expired token', 401);
        });

        final oauth = KeycastOAuth(config: config, httpClient: mockClient);
        final result = await oauth.deleteAccount(
          'refreshed_token',
          nip98Signer: (_) async => 'BASE64EVENT',
        );

        expect(sentAuthorizations, [
          'Bearer refreshed_token',
          'Nostr BASE64EVENT',
        ]);
        expect(result.success, isFalse);
        expect(result.error, 'Account deletion requires the app');
        expect(result.requiresReauthentication, isTrue);
      });

      test('keeps the 403 when the proof retry cannot be sent', () async {
        // A dropped socket on the retry must not escape to the network-error
        // handler: that clears `requiresReauthentication`, which is the only
        // thing the UI branches on, so the user would be told to check their
        // connection after the irreversible vanish had already published.
        final mockClient = MockClient((request) async {
          if (request.headers['Authorization']!.startsWith('Bearer ')) {
            return http.Response(
              jsonEncode({'message': 'Account deletion requires the app'}),
              403,
            );
          }
          throw const SocketException('connection reset');
        });

        final oauth = KeycastOAuth(config: config, httpClient: mockClient);
        final result = await oauth.deleteAccount(
          'refreshed_token',
          nip98Signer: (_) async => 'BASE64EVENT',
        );

        expect(result.error, 'Account deletion requires the app');
        expect(result.requiresReauthentication, isTrue);
      });

      test('keeps the 403 when the proof retry hangs', () async {
        // Same contract for the timeout path, which is the likelier one: the
        // signer sits between the two requests, so the connection can idle
        // long enough for the retry to open on a dead one.
        final mockClient = MockClient((request) {
          if (request.headers['Authorization']!.startsWith('Bearer ')) {
            return Future.value(
              http.Response(
                jsonEncode({'message': 'Account deletion requires the app'}),
                403,
              ),
            );
          }
          return Completer<http.Response>().future;
        });

        final oauth = KeycastOAuth(
          config: config,
          httpClient: mockClient,
          requestTimeout: const Duration(milliseconds: 50),
        );
        final result = await oauth.deleteAccount(
          'refreshed_token',
          nip98Signer: (_) async => 'BASE64EVENT',
        );

        expect(result.error, 'Account deletion requires the app');
        expect(result.requiresReauthentication, isTrue);
      });

      test('does not retry a 401 with a proof', () async {
        // 401 is what keycast answers when it cannot parse the credential.
        // Re-sending an unparseable scheme would only repeat the failure.
        var requests = 0;
        var signerCalls = 0;
        final mockClient = MockClient((request) async {
          requests++;
          return http.Response('Unauthorized', 401);
        });

        final oauth = KeycastOAuth(config: config, httpClient: mockClient);
        final result = await oauth.deleteAccount(
          'expired_token',
          nip98Signer: (_) async {
            signerCalls++;
            return 'BASE64EVENT';
          },
        );

        expect(result.success, isFalse);
        expect(result.requiresReauthentication, isTrue);
        expect(requests, 1);
        expect(signerCalls, isZero);
      });

      test(
        'signs the retry proof over the exact URL the request is sent to',
        () async {
          // NIP-98 binds the signature to the `u` tag; if the signer is handed a
          // different URL than the request uses, the server rejects every proof.
          String? signedUrl;
          Uri? requestedUri;
          var requests = 0;
          final mockClient = MockClient((request) async {
            requestedUri = request.url;
            requests++;
            if (requests == 1) return http.Response('Forbidden', 403);
            return http.Response(
              jsonEncode({'success': true, 'message': 'Account deleted'}),
              200,
            );
          });

          final oauth = KeycastOAuth(config: config, httpClient: mockClient);
          await oauth.deleteAccount(
            'token',
            nip98Signer: (url) async {
              signedUrl = url;
              return 'PROOF';
            },
          );

          expect(signedUrl, isNotNull);
          expect(signedUrl, requestedUri.toString());
        },
      );

      test('keeps the 403 when the signer returns null', () async {
        var requests = 0;
        final mockClient = MockClient((request) async {
          requests++;
          return http.Response('Forbidden', 403);
        });

        final oauth = KeycastOAuth(config: config, httpClient: mockClient);
        final result = await oauth.deleteAccount(
          'test_token',
          nip98Signer: (_) async => null,
        );

        expect(result.success, isFalse);
        expect(result.error, contains('requires signing in again'));
        expect(result.requiresReauthentication, isTrue);
        expect(requests, 1);
      });

      test('keeps the 403 when the signer throws', () async {
        // A throwing signer must not surface as a network error: that would
        // tell the user to check their connection for a refused credential.
        final mockClient = MockClient((request) async {
          return http.Response('Forbidden', 403);
        });

        final oauth = KeycastOAuth(config: config, httpClient: mockClient);
        final result = await oauth.deleteAccount(
          'test_token',
          nip98Signer: (_) async => throw StateError('signer gone'),
        );

        expect(result.success, isFalse);
        expect(result.error, contains('requires signing in again'));
        expect(result.requiresReauthentication, isTrue);
      });

      test('uses the bearer token when no signer is supplied', () async {
        // Pins the default: existing callers keep their current behavior.
        String? sentAuthorization;
        final mockClient = MockClient((request) async {
          sentAuthorization = request.headers['Authorization'];
          return http.Response(
            jsonEncode({'success': true, 'message': 'Account deleted'}),
            200,
          );
        });

        final oauth = KeycastOAuth(config: config, httpClient: mockClient);
        await oauth.deleteAccount('test_token');

        expect(sentAuthorization, 'Bearer test_token');
      });

      test('returns error on 404 not found', () async {
        final mockClient = MockClient((request) async {
          return http.Response('Not Found', 404);
        });

        final oauth = KeycastOAuth(config: config, httpClient: mockClient);
        final result = await oauth.deleteAccount('token');

        expect(result.success, isFalse);
        expect(result.error, contains('not found'));
      });

      test('returns error on 500+ server error', () async {
        final mockClient = MockClient((request) async {
          return http.Response('Internal Error', 502);
        });

        final oauth = KeycastOAuth(config: config, httpClient: mockClient);
        final result = await oauth.deleteAccount('token');

        expect(result.success, isFalse);
        expect(result.error, contains('Server error'));
        expect(result.error, contains('502'));
        expect(result.requiresReauthentication, isFalse);
      });

      test('returns error with JSON error on other status', () async {
        final mockClient = MockClient((request) async {
          return http.Response(
            jsonEncode({
              'error': 'deletion_pending',
              'message': 'Account deletion already in progress',
            }),
            409,
          );
        });

        final oauth = KeycastOAuth(config: config, httpClient: mockClient);
        final result = await oauth.deleteAccount('token');

        expect(result.success, isFalse);
        expect(result.error, contains('deletion_pending'));
      });

      test('returns error with HTTP status on invalid JSON', () async {
        final mockClient = MockClient((request) async {
          return http.Response('not json response', 422);
        });

        final oauth = KeycastOAuth(config: config, httpClient: mockClient);
        final result = await oauth.deleteAccount('token');

        expect(result.success, isFalse);
        expect(result.error, 'HTTP 422');
      });

      test('returns error on SocketException', () async {
        final mockClient = MockClient((request) async {
          throw const SocketException('Connection refused');
        });

        final oauth = KeycastOAuth(config: config, httpClient: mockClient);
        final result = await oauth.deleteAccount('token');

        expect(result.success, isFalse);
        expect(result.error, contains('Cannot connect to server'));
        expect(result.requiresReauthentication, isFalse);
      });

      test('returns error on other network errors', () async {
        final mockClient = MockClient((request) async {
          throw Exception('DNS resolution failed');
        });

        final oauth = KeycastOAuth(config: config, httpClient: mockClient);
        final result = await oauth.deleteAccount('token');

        expect(result.success, isFalse);
        expect(result.error, contains('Network error'));
      });
    });

    group('refreshSession', () {
      test('returns null when no refresh token stored', () async {
        final storage = MemoryKeycastStorage();
        final oauth = KeycastOAuth(config: config, storage: storage);

        final result = await oauth.refreshSession();
        expect(result, isNull);
      });

      test('exchanges refresh token and saves new session on 200', () async {
        final storage = MemoryKeycastStorage();
        await storage.write('keycast_refresh_token', 'old_refresh_token');

        final mockClient = MockClient((request) async {
          expect(request.url.path, '/api/oauth/token');
          expect(request.method, 'POST');
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          expect(body['grant_type'], 'refresh_token');
          expect(body['refresh_token'], 'old_refresh_token');
          expect(body['client_id'], 'test-client');

          return http.Response(
            jsonEncode({
              'bunker_url': 'bunker://refreshed',
              'access_token': 'new_access_token',
              'token_type': 'Bearer',
              'expires_in': 86400,
              'refresh_token': 'new_refresh_token',
              'authorization_handle': 'new_handle',
            }),
            200,
          );
        });

        final oauth = KeycastOAuth(
          config: config,
          httpClient: mockClient,
          storage: storage,
        );
        final result = await oauth.refreshSession();

        expect(result, isNotNull);
        expect(result!.bunkerUrl, 'bunker://refreshed');
        expect(result.accessToken, 'new_access_token');
        expect(result.refreshToken, 'new_refresh_token');
        expect(result.hasRpcAccess, isTrue);

        // Verify new session was saved
        final savedSession = await storage.read('keycast_session');
        expect(savedSession, isNotNull);

        // Verify new refresh token was saved
        final savedRefresh = await storage.read('keycast_refresh_token');
        expect(savedRefresh, 'new_refresh_token');

        // Verify new handle was saved
        final savedHandle = await storage.read('keycast_auth_handle');
        expect(savedHandle, 'new_handle');
      });

      test('returns null and clears refresh token on non-200', () async {
        final storage = MemoryKeycastStorage();
        await storage.write('keycast_refresh_token', 'expired_refresh');

        final mockClient = MockClient((request) async {
          return http.Response(
            jsonEncode({
              'error': 'invalid_grant',
              'error_description': 'Refresh token expired',
            }),
            400,
          );
        });

        final oauth = KeycastOAuth(
          config: config,
          httpClient: mockClient,
          storage: storage,
        );
        final result = await oauth.refreshSession();

        expect(result, isNull);
        // Refresh token should be cleared (server consumed it)
        expect(await storage.read('keycast_refresh_token'), isNull);
      });

      test(
        'throws network exception and preserves refresh token on network error',
        () async {
          final storage = MemoryKeycastStorage();
          await storage.write('keycast_refresh_token', 'my_refresh_token');

          final mockClient = MockClient((request) async {
            throw const SocketException('Connection refused');
          });

          final oauth = KeycastOAuth(
            config: config,
            httpClient: mockClient,
            storage: storage,
          );

          await expectLater(
            oauth.refreshSession(),
            throwsA(isA<OAuthNetworkException>()),
          );
          // Refresh token should be preserved (server didn't consume it)
          expect(
            await storage.read('keycast_refresh_token'),
            'my_refresh_token',
          );
        },
      );

      test('binds userPubkey before saving session', () async {
        final storage = MemoryKeycastStorage();
        await storage.write('keycast_refresh_token', 'old_refresh_token');

        final mockClient = MockClient((request) async {
          return http.Response(
            jsonEncode({
              'bunker_url': 'bunker://refreshed',
              'access_token': 'new_access_token',
              'token_type': 'Bearer',
              'expires_in': 86400,
              'refresh_token': 'new_refresh_token',
            }),
            200,
          );
        });

        final oauth = KeycastOAuth(
          config: config,
          httpClient: mockClient,
          storage: storage,
        );
        final result = await oauth.refreshSession(userPubkey: 'abc123pubkey');

        expect(result, isNotNull);
        expect(result!.userPubkey, 'abc123pubkey');

        final savedJson = await storage.read('keycast_session');
        final saved = KeycastSession.fromJson(
          jsonDecode(savedJson!) as Map<String, dynamic>,
        );
        expect(saved.userPubkey, 'abc123pubkey');
      });

      test(
        'does not save a refresh response that completes after logout',
        () async {
          final storage = MemoryKeycastStorage();
          await storage.write('keycast_refresh_token', 'old_refresh_token');

          final refreshResponse = Completer<http.Response>();
          var refreshRequestStarted = false;
          final mockClient = MockClient((request) async {
            if (request.url.path == '/api/oauth/token') {
              refreshRequestStarted = true;
              return refreshResponse.future;
            }
            if (request.url.path == '/api/auth/logout') {
              return http.Response('', 204);
            }
            fail('Unexpected request to ${request.url}');
          });

          final oauth = KeycastOAuth(
            config: config,
            httpClient: mockClient,
            storage: storage,
          );

          final refresh = oauth.refreshSession();
          while (!refreshRequestStarted) {
            await Future<void>.delayed(Duration.zero);
          }

          await oauth.logout();
          refreshResponse.complete(
            http.Response(
              jsonEncode({
                'bunker_url': 'bunker://refreshed',
                'access_token': 'new_access_token',
                'token_type': 'Bearer',
                'expires_in': 86400,
                'refresh_token': 'new_refresh_token',
                'authorization_handle': 'new_handle',
              }),
              200,
            ),
          );

          expect(await refresh, isNull);
          expect(await storage.read('keycast_session'), isNull);
          expect(await storage.read('keycast_refresh_token'), isNull);
          expect(await storage.read('keycast_auth_handle'), isNull);
        },
      );
    });

    group('getSessionOrRefresh', () {
      test('returns valid session when not expired', () async {
        final storage = MemoryKeycastStorage();
        final validSession = KeycastSession(
          bunkerUrl: 'bunker://test',
          accessToken: 'valid_token',
          expiresAt: DateTime.now().add(const Duration(hours: 1)),
        );
        await storage.write(
          'keycast_session',
          jsonEncode(validSession.toJson()),
        );

        // No HTTP calls expected — session is valid
        final mockClient = MockClient((request) async {
          fail('Should not make HTTP request when session is valid');
        });

        final oauth = KeycastOAuth(
          config: config,
          httpClient: mockClient,
          storage: storage,
        );
        final result = await oauth.getSessionOrRefresh();

        expect(result, isNotNull);
        expect(result!.accessToken, 'valid_token');
      });

      test('refreshes and returns session when expired', () async {
        final storage = MemoryKeycastStorage();
        // Store an expired session
        final expiredSession = KeycastSession(
          bunkerUrl: 'bunker://test',
          accessToken: 'expired_token',
          expiresAt: DateTime.now().subtract(const Duration(hours: 1)),
        );
        await storage.write(
          'keycast_session',
          jsonEncode(expiredSession.toJson()),
        );
        await storage.write('keycast_refresh_token', 'my_refresh_token');

        final mockClient = MockClient((request) async {
          // Should hit the token endpoint for refresh
          expect(request.url.path, '/api/oauth/token');
          return http.Response(
            jsonEncode({
              'bunker_url': 'bunker://refreshed',
              'access_token': 'new_access_token',
              'token_type': 'Bearer',
              'expires_in': 86400,
              'refresh_token': 'new_refresh_token',
            }),
            200,
          );
        });

        final oauth = KeycastOAuth(
          config: config,
          httpClient: mockClient,
          storage: storage,
        );
        final result = await oauth.getSessionOrRefresh();

        expect(result, isNotNull);
        expect(result!.accessToken, 'new_access_token');
      });

      test('returns null when no session and no refresh token', () async {
        final storage = MemoryKeycastStorage();
        // No session, no refresh token

        final mockClient = MockClient((request) async {
          fail('Should not make HTTP request when no refresh token');
        });

        final oauth = KeycastOAuth(
          config: config,
          httpClient: mockClient,
          storage: storage,
        );
        final result = await oauth.getSessionOrRefresh();

        expect(result, isNull);
      });
    });

    group('request timeouts', () {
      /// HTTP client whose requests never complete — simulates a dead
      /// socket (e.g. Android Doze killing the connection).
      MockClient hangingClient() =>
          MockClient((request) => Completer<http.Response>().future);

      const shortTimeout = Duration(milliseconds: 50);

      test('refreshSession fails within the timeout and preserves the '
          'refresh token', () async {
        final storage = MemoryKeycastStorage();
        await storage.write('keycast_refresh_token', 'my_refresh_token');

        final oauth = KeycastOAuth(
          config: config,
          httpClient: hangingClient(),
          storage: storage,
          requestTimeout: shortTimeout,
        );

        await expectLater(
          oauth.refreshSession(),
          throwsA(isA<OAuthNetworkException>()),
        );
        // CRITICAL: a timeout is a network failure, not an auth
        // rejection — the refresh token must survive so the next
        // attempt can retry.
        expect(await storage.read('keycast_refresh_token'), 'my_refresh_token');
      });

      test('exchangeCode throws TimeoutException on hung request', () async {
        final oauth = KeycastOAuth(
          config: config,
          httpClient: hangingClient(),
          requestTimeout: shortTimeout,
        );

        await expectLater(
          oauth.exchangeCode(code: 'code', verifier: 'verifier'),
          throwsA(isA<TimeoutException>()),
        );
      });

      test(
        'headlessLogin returns timeout error result on hung request',
        () async {
          final oauth = KeycastOAuth(
            config: config,
            httpClient: hangingClient(),
            requestTimeout: shortTimeout,
          );

          final (result, verifier) = await oauth.headlessLogin(
            email: 'test@example.com',
            password: 'password123',
          );

          expect(result.success, isFalse);
          expect(result.errorCode, 'timeout');
          expect(result.failure, KeycastLoginFailure.network);
          expect(verifier, isNotEmpty);
        },
      );

      test(
        'headlessRegister returns timeout error result on hung request',
        () async {
          final oauth = KeycastOAuth(
            config: config,
            httpClient: hangingClient(),
            requestTimeout: shortTimeout,
          );

          final (result, verifier) = await oauth.headlessRegister(
            email: 'test@example.com',
            password: 'password123',
          );

          expect(result.success, isFalse);
          expect(result.errorCode, 'timeout');
          expect(verifier, isNotEmpty);
        },
      );

      test('pollForCode returns error result on hung request', () async {
        final oauth = KeycastOAuth(
          config: config,
          httpClient: hangingClient(),
          requestTimeout: shortTimeout,
        );

        final result = await oauth.pollForCode('device123');

        expect(result.status, PollStatus.error);
        expect(result.error, contains('TimeoutException'));
      });

      test('verifyEmail returns network failure on hung request', () async {
        final oauth = KeycastOAuth(
          config: config,
          httpClient: hangingClient(),
          requestTimeout: shortTimeout,
        );

        final result = await oauth.verifyEmail(token: 'verify-token');

        expect(result.success, isFalse);
        expect(result.error, contains('TimeoutException'));
        expect(result.failure, KeycastAuthFailure.network);
        expect(result.isTransientFailure, isTrue);
      });

      test(
        'sendPasswordResetEmail returns error result on hung request',
        () async {
          final oauth = KeycastOAuth(
            config: config,
            httpClient: hangingClient(),
            requestTimeout: shortTimeout,
          );

          final result = await oauth.sendPasswordResetEmail('test@example.com');

          expect(result.success, isFalse);
          expect(result.error, contains('TimeoutException'));
        },
      );

      test('resetPassword returns error result on hung request', () async {
        final oauth = KeycastOAuth(
          config: config,
          httpClient: hangingClient(),
          requestTimeout: shortTimeout,
        );

        final result = await oauth.resetPassword(
          token: 'reset-token',
          newPassword: 'new-password',
        );

        expect(result.success, isFalse);
        expect(result.message, contains('TimeoutException'));
      });

      // Both resend methods rely on the generic catch to turn a hang into a
      // network failure; neither had a timeout test, so that path was
      // unverified in either direction.
      test(
        'resendVerification reports network failure on hung request',
        () async {
          final oauth = KeycastOAuth(
            config: config,
            httpClient: hangingClient(),
            requestTimeout: shortTimeout,
          );

          final result = await oauth.resendVerification('test@example.com');

          expect(result.success, isFalse);
          expect(result.errorCode, ResendVerificationError.network);
        },
      );

      test(
        'resendHeadlessVerification reports network failure on hung request',
        () async {
          final oauth = KeycastOAuth(
            config: config,
            httpClient: hangingClient(),
            requestTimeout: shortTimeout,
          );

          final result = await oauth.resendHeadlessVerification('device-code');

          expect(result.success, isFalse);
          expect(result.errorCode, ResendVerificationError.network);
        },
      );
    });

    group('close', () {
      test('closes the HTTP client', () {
        var closeCalled = false;
        final mockClient = _CloseTrackingClient(() {
          closeCalled = true;
        });

        KeycastOAuth(config: config, httpClient: mockClient).close();

        expect(closeCalled, isTrue);
      });
    });
  });
}

/// Helper client that tracks when close() is called
class _CloseTrackingClient extends http.BaseClient {
  _CloseTrackingClient(this.onClose);
  final void Function() onClose;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    throw UnimplementedError();
  }

  @override
  void close() {
    onClose();
  }
}
