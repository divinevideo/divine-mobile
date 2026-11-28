// ABOUTME: Tests for KeycastRpc client - Nostr signing via RPC
// ABOUTME: Verifies all RPC methods with mocked HTTP, error handling, auth headers

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import 'package:http/testing.dart';
import 'package:keycast_flutter/src/models/exceptions.dart';
import 'package:keycast_flutter/src/models/keycast_session.dart';
import 'package:keycast_flutter/src/oauth/oauth_config.dart';
import 'package:keycast_flutter/src/rpc/keycast_rpc.dart';
import 'package:keycast_flutter/src/rpc/policy_refusal.dart';
import 'package:nostr_sdk/nostr_sdk.dart';

void main() {
  group('KeycastRpc', () {
    late MockClient mockClient;

    setUp(() {
      mockClient = MockClient((request) async {
        throw Exception('Unexpected request: ${request.url}');
      });
    });

    group('fromSession factory', () {
      test('creates RPC client from valid session', () {
        const config = OAuthConfig(
          serverUrl: 'https://login.divine.video',
          clientId: 'test',
          redirectUri: 'divine://callback',
        );
        final session = KeycastSession(
          bunkerUrl: 'bunker://test',
          accessToken: 'valid_token',
          expiresAt: DateTime.now().add(const Duration(hours: 1)),
        );

        final rpc = KeycastRpc.fromSession(config, session);
        expect(rpc, isNotNull);
      });

      test('throws SessionExpiredException for expired session', () {
        const config = OAuthConfig(
          serverUrl: 'https://login.divine.video',
          clientId: 'test',
          redirectUri: 'divine://callback',
        );
        final session = KeycastSession(
          bunkerUrl: 'bunker://test',
          accessToken: 'expired_token',
          expiresAt: DateTime.now().subtract(const Duration(hours: 1)),
        );

        expect(
          () => KeycastRpc.fromSession(config, session),
          throwsA(isA<SessionExpiredException>()),
        );
      });

      test('throws SessionExpiredException for null accessToken', () {
        const config = OAuthConfig(
          serverUrl: 'https://login.divine.video',
          clientId: 'test',
          redirectUri: 'divine://callback',
        );
        const session = KeycastSession(bunkerUrl: 'bunker://test');

        expect(
          () => KeycastRpc.fromSession(config, session),
          throwsA(isA<SessionExpiredException>()),
        );
      });
    });

    group('getPublicKey', () {
      test('returns hex pubkey from RPC', () async {
        mockClient = MockClient((request) async {
          expect(request.headers['Authorization'], 'Bearer test_token');
          expect(request.headers['Content-Type'], 'application/json');

          final body = jsonDecode(request.body);
          expect(body['method'], 'get_public_key');
          expect(body['params'], isEmpty);

          return http.Response(
            jsonEncode({
              'result':
                  '3bf0c63fcb93463407af97a5e5ee64fa883d107ef9e558472c4eb9aaaefa459d',
            }),
            200,
          );
        });

        final rpc = KeycastRpc(
          nostrApi: 'https://login.divine.video/api/nostr',
          accessToken: 'test_token',
          httpClient: mockClient,
        );

        final pubkey = await rpc.getPublicKey();
        expect(
          pubkey,
          '3bf0c63fcb93463407af97a5e5ee64fa883d107ef9e558472c4eb9aaaefa459d',
        );
      });

      test('retries once on a fresh transport after a socket error', () async {
        var firstClientCalls = 0;
        var retryClientCalls = 0;
        final firstClient = MockClient((request) async {
          firstClientCalls++;
          throw http.ClientException('Connection reset', request.url);
        });
        final retryClient = MockClient((request) async {
          retryClientCalls++;
          final body = jsonDecode(request.body);
          expect(body['method'], 'get_public_key');
          return http.Response(
            jsonEncode({
              'result':
                  '3bf0c63fcb93463407af97a5e5ee64fa883d107ef9e558472c4eb9aaaefa459d',
            }),
            200,
          );
        });
        var factoryCalls = 0;

        final rpc = KeycastRpc(
          nostrApi: 'https://login.divine.video/api/nostr',
          accessToken: 'test_token',
          httpClient: firstClient,
          httpClientFactory: () {
            factoryCalls++;
            return retryClient;
          },
        );

        final pubkey = await rpc.getPublicKey();

        expect(
          pubkey,
          '3bf0c63fcb93463407af97a5e5ee64fa883d107ef9e558472c4eb9aaaefa459d',
        );
        expect(firstClientCalls, equals(1));
        expect(factoryCalls, equals(1));
        expect(retryClientCalls, equals(1));
      });

      test('propagates socket error when the one retry also fails', () async {
        var firstClientCalls = 0;
        var retryClientCalls = 0;
        final firstClient = MockClient((request) async {
          firstClientCalls++;
          throw http.ClientException('Bad file descriptor', request.url);
        });
        final retryClient = MockClient((request) async {
          retryClientCalls++;
          throw http.ClientException('Connection reset', request.url);
        });

        final rpc = KeycastRpc(
          nostrApi: 'https://login.divine.video/api/nostr',
          accessToken: 'test_token',
          httpClient: firstClient,
          httpClientFactory: () => retryClient,
        );

        await expectLater(
          rpc.getPublicKey(),
          throwsA(isA<http.ClientException>()),
        );
        expect(firstClientCalls, equals(1));
        expect(retryClientCalls, equals(1));
      });

      test(
        'defers closing a retired transport until sibling requests finish',
        () async {
          const pubkey =
              '3bf0c63fcb93463407af97a5e5ee64fa883d107ef9e558472c4eb9aaaefa459d';
          final staleRequest = Completer<http.StreamedResponse>();
          late _ControlledClient firstClient;
          late _ControlledClient retryClient;
          var firstClientCalls = 0;
          var retryClientCalls = 0;
          var factoryCalls = 0;

          firstClient = _ControlledClient((request) {
            firstClientCalls++;
            if (firstClientCalls == 1) {
              return staleRequest.future;
            }
            throw http.ClientException('Connection reset', request.url);
          });
          retryClient = _ControlledClient((request) async {
            retryClientCalls++;
            return _rpcResult(request, {'result': pubkey});
          });
          final clients = [firstClient, retryClient];

          final rpc = KeycastRpc(
            nostrApi: 'https://login.divine.video/api/nostr',
            accessToken: 'test_token',
            httpClientFactory: () => clients[factoryCalls++],
          );

          final staleFuture = rpc.getPublicKey();
          await Future<void>.value();
          expect(firstClientCalls, equals(1));

          final resetResult = await rpc.getPublicKey();
          expect(resetResult, pubkey);
          expect(factoryCalls, equals(2));
          expect(firstClient.closeCount, equals(0));

          staleRequest.completeError(
            http.ClientException(
              'Bad file descriptor',
              Uri.parse('https://login.divine.video/api/nostr'),
            ),
          );

          expect(await staleFuture, pubkey);
          expect(factoryCalls, equals(2));
          expect(retryClientCalls, equals(2));
          expect(firstClient.closeCount, equals(1));
        },
      );

      test('close drains retired transports and rejects later use', () async {
        const pubkey =
            '3bf0c63fcb93463407af97a5e5ee64fa883d107ef9e558472c4eb9aaaefa459d';
        final staleRequest = Completer<http.StreamedResponse>();
        late _ControlledClient firstClient;
        late _ControlledClient retryClient;
        var firstClientCalls = 0;
        var retryClientCalls = 0;
        var factoryCalls = 0;

        firstClient = _ControlledClient((request) {
          firstClientCalls++;
          if (firstClientCalls == 1) {
            return staleRequest.future;
          }
          throw http.ClientException('Connection reset', request.url);
        });
        retryClient = _ControlledClient((request) async {
          retryClientCalls++;
          return _rpcResult(request, {'result': pubkey});
        });
        final clients = [firstClient, retryClient];

        final rpc = KeycastRpc(
          nostrApi: 'https://login.divine.video/api/nostr',
          accessToken: 'test_token',
          httpClientFactory: () => clients[factoryCalls++],
        );

        final staleFuture = rpc.getPublicKey();
        await Future<void>.value();
        expect(await rpc.getPublicKey(), pubkey);
        expect(firstClient.closeCount, equals(0));

        rpc.close();

        expect(firstClient.closeCount, equals(1));
        expect(retryClient.closeCount, equals(1));
        await expectLater(
          rpc.getPublicKey(),
          throwsA(isA<KeycastRpcClosedException>()),
        );

        staleRequest.completeError(
          http.ClientException(
            'Bad file descriptor',
            Uri.parse('https://login.divine.video/api/nostr'),
          ),
        );
        await expectLater(staleFuture, throwsA(isA<http.ClientException>()));
        expect(retryClientCalls, equals(1));
      });

      test('shares one single-op deadline across a socket retry', () async {
        var firstClientCalls = 0;
        var retryClientCalls = 0;
        final firstClient = MockClient((request) async {
          firstClientCalls++;
          await Future<void>.delayed(const Duration(milliseconds: 200));
          throw http.ClientException('Connection reset', request.url);
        });
        final retryClient = MockClient((request) {
          retryClientCalls++;
          return Completer<http.Response>().future;
        });
        final rpc = KeycastRpc(
          nostrApi: 'https://login.divine.video/api/nostr',
          accessToken: 'test_token',
          httpClient: firstClient,
          httpClientFactory: () => retryClient,
          requestTimeout: const Duration(milliseconds: 300),
        );
        final stopwatch = Stopwatch()..start();

        await expectLater(
          rpc.getPublicKey(),
          throwsA(isA<RpcTimeoutException>()),
        );

        expect(firstClientCalls, equals(1));
        expect(retryClientCalls, equals(1));
        // Shared deadline: ~300ms. A doubled (per-attempt) deadline would take
        // ~500ms, so this bound fails for the regression it guards while
        // leaving slack for loaded CI runners.
        expect(stopwatch.elapsed, lessThan(const Duration(milliseconds: 400)));
      });

      test(
        'shares one single-op deadline across a 401 refresh retry',
        () async {
          var callCount = 0;
          mockClient = MockClient((request) async {
            callCount++;
            if (callCount == 1) {
              await Future<void>.delayed(const Duration(milliseconds: 200));
              return http.Response('Unauthorized', 401);
            }
            return Completer<http.Response>().future;
          });
          final rpc = KeycastRpc(
            nostrApi: 'https://login.divine.video/api/nostr',
            accessToken: 'expired_token',
            httpClient: mockClient,
            onTokenRefresh: () async => 'fresh_token',
            requestTimeout: const Duration(milliseconds: 300),
          );
          final stopwatch = Stopwatch()..start();

          await expectLater(
            rpc.getPublicKey(),
            throwsA(isA<RpcTimeoutException>()),
          );

          expect(callCount, equals(2));
          // Shared deadline: ~300ms; a doubled deadline would take ~500ms.
          expect(
            stopwatch.elapsed,
            lessThan(const Duration(milliseconds: 400)),
          );
        },
      );
    });

    group('signEvent', () {
      test('returns signed event from RPC', () async {
        mockClient = MockClient((request) async {
          final body = jsonDecode(request.body);
          expect(body['method'], 'sign_event');
          expect(body['params'], isNotEmpty);

          return http.Response(
            jsonEncode({
              'result': {
                'id':
                    'abc123def456abc123def456abc123def456abc123def456abc123def456abcd',
                'pubkey':
                    '3bf0c63fcb93463407af97a5e5ee64fa883d107ef9e558472c4eb9aaaefa459d',
                'created_at': 1234567890,
                'kind': 1,
                'tags': <dynamic>[],
                'content': 'test content',
                'sig':
                    'sig123abc456sig123abc456sig123abc456sig123abc456sig123abc456sig123abc456sig123abc456sig123abc456sig123abc456sig123ab',
              },
            }),
            200,
          );
        });

        final rpc = KeycastRpc(
          nostrApi: 'https://login.divine.video/api/nostr',
          accessToken: 'test_token',
          httpClient: mockClient,
        );

        final event = Event(
          '3bf0c63fcb93463407af97a5e5ee64fa883d107ef9e558472c4eb9aaaefa459d',
          1,
          [],
          'test content',
        );

        final signed = await rpc.signEvent(event);
        expect(signed, isNotNull);
        expect(signed!.sig, isNotEmpty);
      });
    });

    group('nip44Encrypt', () {
      test('returns encrypted text from RPC', () async {
        mockClient = MockClient((request) async {
          final body = jsonDecode(request.body);
          expect(body['method'], 'nip44_encrypt');
          expect(body['params'].length, 2);

          return http.Response(
            jsonEncode({'result': 'encrypted_ciphertext_base64'}),
            200,
          );
        });

        final rpc = KeycastRpc(
          nostrApi: 'https://login.divine.video/api/nostr',
          accessToken: 'test_token',
          httpClient: mockClient,
        );

        final ciphertext = await rpc.nip44Encrypt(
          '3bf0c63fcb93463407af97a5e5ee64fa883d107ef9e558472c4eb9aaaefa459d',
          'hello world',
        );
        expect(ciphertext, 'encrypted_ciphertext_base64');
      });
    });

    group('nip44Decrypt', () {
      test('returns decrypted text from RPC', () async {
        mockClient = MockClient((request) async {
          final body = jsonDecode(request.body);
          expect(body['method'], 'nip44_decrypt');
          expect(body['params'].length, 2);

          return http.Response(
            jsonEncode({'result': 'decrypted plaintext'}),
            200,
          );
        });

        final rpc = KeycastRpc(
          nostrApi: 'https://login.divine.video/api/nostr',
          accessToken: 'test_token',
          httpClient: mockClient,
        );

        final plaintext = await rpc.nip44Decrypt(
          '3bf0c63fcb93463407af97a5e5ee64fa883d107ef9e558472c4eb9aaaefa459d',
          'encrypted_ciphertext',
        );
        expect(plaintext, 'decrypted plaintext');
      });
    });

    group('nip04 encrypt/decrypt', () {
      test('encrypt calls correct RPC method', () async {
        mockClient = MockClient((request) async {
          final body = jsonDecode(request.body);
          expect(body['method'], 'nip04_encrypt');
          return http.Response(jsonEncode({'result': 'nip04_ciphertext'}), 200);
        });

        final rpc = KeycastRpc(
          nostrApi: 'https://login.divine.video/api/nostr',
          accessToken: 'test_token',
          httpClient: mockClient,
        );

        final result = await rpc.encrypt('pubkey', 'plaintext');
        expect(result, 'nip04_ciphertext');
      });

      test('decrypt calls correct RPC method', () async {
        mockClient = MockClient((request) async {
          final body = jsonDecode(request.body);
          expect(body['method'], 'nip04_decrypt');
          return http.Response(jsonEncode({'result': 'nip04_plaintext'}), 200);
        });

        final rpc = KeycastRpc(
          nostrApi: 'https://login.divine.video/api/nostr',
          accessToken: 'test_token',
          httpClient: mockClient,
        );

        final result = await rpc.decrypt('pubkey', 'ciphertext');
        expect(result, 'nip04_plaintext');
      });
    });

    group('error handling', () {
      test('an unconfirmed-email cap refusal is typed and reported', () async {
        mockClient = MockClient((request) async {
          return http.Response(
            jsonEncode({
              'error': 'You have hit the limit',
              'code': 'UNCONFIRMED_RATE_LIMITED',
            }),
            429,
            headers: {'retry-after': '120'},
          );
        });
        final rpc = KeycastRpc(
          nostrApi: 'https://login.divine.video/api/nostr',
          accessToken: 'test_token',
          httpClient: mockClient,
        );
        final reported = KeycastPolicyRefusals.stream.first;

        await expectLater(
          rpc.getPublicKey,
          throwsA(
            isA<UnconfirmedRateLimitedException>().having(
              (error) => error.retryAfter,
              'retryAfter',
              const Duration(seconds: 120),
            ),
          ),
        );
        final refusal = await reported;
        expect(refusal.kind, KeycastPolicyRefusalKind.unconfirmedRateLimited);
        expect(refusal.retryAfter, const Duration(seconds: 120));
      });

      test('an unconfirmed-email DM refusal is typed and reported', () async {
        mockClient = MockClient((request) async {
          return http.Response(
            jsonEncode({
              'error': 'Confirm your email to send direct messages.',
              'code': 'EMAIL_NOT_CONFIRMED',
            }),
            403,
          );
        });
        final rpc = KeycastRpc(
          nostrApi: 'https://login.divine.video/api/nostr',
          accessToken: 'test_token',
          httpClient: mockClient,
        );
        final reported = KeycastPolicyRefusals.stream.first;

        await expectLater(
          rpc.getPublicKey,
          throwsA(isA<EmailNotConfirmedException>()),
        );
        expect(
          (await reported).kind,
          KeycastPolicyRefusalKind.emailNotConfirmed,
        );
      });

      test('a refusal names the account whose signer was refused', () async {
        mockClient = MockClient((request) async {
          return http.Response(
            jsonEncode({
              'error': 'Confirm your email to send direct messages.',
              'code': 'EMAIL_NOT_CONFIRMED',
            }),
            403,
          );
        });
        final rpc = KeycastRpc(
          nostrApi: 'https://login.divine.video/api/nostr',
          accessToken: 'test_token',
          httpClient: mockClient,
          owner: 'owner-pubkey',
        );
        final reported = KeycastPolicyRefusals.stream.first;

        await expectLater(
          rpc.getPublicKey,
          throwsA(isA<EmailNotConfirmedException>()),
        );
        expect((await reported).owner, 'owner-pubkey');
      });

      test(
        "a signer built from a session refuses in its owner's name",
        () async {
          const config = OAuthConfig(
            serverUrl: 'https://login.divine.video',
            clientId: 'test',
            redirectUri: 'divine://callback',
          );
          final session = KeycastSession(
            bunkerUrl: 'bunker://test',
            accessToken: 'valid_token',
            expiresAt: DateTime.now().add(const Duration(hours: 1)),
            userPubkey: 'session-owner',
          );

          expect(
            KeycastRpc.fromSession(config, session).owner,
            'session-owner',
          );
        },
      );

      test('another 403 stays a plain RpcException', () async {
        mockClient = MockClient((request) async {
          return http.Response(
            jsonEncode({'error': 'Operation denied by policy'}),
            403,
          );
        });
        final rpc = KeycastRpc(
          nostrApi: 'https://login.divine.video/api/nostr',
          accessToken: 'test_token',
          httpClient: mockClient,
        );

        await expectLater(
          rpc.getPublicKey,
          throwsA(
            allOf(
              isA<RpcException>(),
              isNot(isA<EmailNotConfirmedException>()),
              isNot(isA<UnconfirmedRateLimitedException>()),
            ),
          ),
        );
      });

      test('throws RpcException on error response', () async {
        mockClient = MockClient((request) async {
          return http.Response(jsonEncode({'error': 'signing_failed'}), 200);
        });

        final rpc = KeycastRpc(
          nostrApi: 'https://login.divine.video/api/nostr',
          accessToken: 'test_token',
          httpClient: mockClient,
        );

        expect(rpc.getPublicKey, throwsA(isA<RpcException>()));
      });

      test('throws RpcException on HTTP error', () async {
        mockClient = MockClient((request) async {
          return http.Response('Server error', 500);
        });

        final rpc = KeycastRpc(
          nostrApi: 'https://login.divine.video/api/nostr',
          accessToken: 'test_token',
          httpClient: mockClient,
        );

        expect(rpc.getPublicKey, throwsA(isA<RpcException>()));
      });

      test('a 504 throws RpcTimeoutException, marked transient', () async {
        // Keycast bounds its own /api/nostr handler at 8s and its tower layer
        // at 10s; both answer 504 (keycast#351). That is Keycast reporting a
        // timeout, so it has to reach callers classified as one — a plain
        // non-200 gets terminalized, which is strictly worse than the client
        // timeout it replaced. The marker is what dm_repository branches on;
        // it cannot import this package to check the concrete type (#7092).
        mockClient = MockClient((request) async {
          return http.Response(
            jsonEncode({'error': 'RPC request timed out after 8s'}),
            504,
          );
        });

        final rpc = KeycastRpc(
          nostrApi: 'https://login.divine.video/api/nostr',
          accessToken: 'test_token',
          httpClient: mockClient,
        );

        await expectLater(
          rpc.getPublicKey(),
          throwsA(
            isA<RpcTimeoutException>().having(
              (e) => e,
              'transient marker',
              isA<TransientSignerFailure>(),
            ),
          ),
        );
      });

      test('other 5xx stay plain RpcException, not transient', () async {
        // The classification is deliberately narrow. 504 is the only status
        // on this route that means "I ran out of time and produced nothing";
        // 503 is a degraded dependency and 500 an unhandled error, neither of
        // which promises the operation did not happen.
        for (final status in [500, 502, 503]) {
          mockClient = MockClient((request) async {
            return http.Response('Server error', status);
          });

          final rpc = KeycastRpc(
            nostrApi: 'https://login.divine.video/api/nostr',
            accessToken: 'test_token',
            httpClient: mockClient,
          );

          await expectLater(
            rpc.getPublicKey(),
            throwsA(isNot(isA<TransientSignerFailure>())),
            reason: 'HTTP $status must not be classified as transient',
          );
        }
      });
    });

    group('token refresh on 401', () {
      test('retries with new token after 401 when callback succeeds', () async {
        var callCount = 0;
        mockClient = MockClient((request) async {
          callCount++;
          if (callCount == 1) {
            expect(request.headers['Authorization'], 'Bearer expired_token');
            return http.Response('Unauthorized', 401);
          }
          expect(request.headers['Authorization'], 'Bearer fresh_token');
          return http.Response(
            jsonEncode({
              'result':
                  '3bf0c63fcb93463407af97a5e5ee64fa883d107ef9e558472c4eb9aaaefa459d',
            }),
            200,
          );
        });

        final rpc = KeycastRpc(
          nostrApi: 'https://login.divine.video/api/nostr',
          accessToken: 'expired_token',
          httpClient: mockClient,
          onTokenRefresh: () async => 'fresh_token',
        );

        final pubkey = await rpc.getPublicKey();
        expect(
          pubkey,
          '3bf0c63fcb93463407af97a5e5ee64fa883d107ef9e558472c4eb9aaaefa459d',
        );
        expect(callCount, equals(2));
      });

      test('throws RpcException when callback returns null', () async {
        mockClient = MockClient((request) async {
          return http.Response('Unauthorized', 401);
        });

        final rpc = KeycastRpc(
          nostrApi: 'https://login.divine.video/api/nostr',
          accessToken: 'expired_token',
          httpClient: mockClient,
          onTokenRefresh: () async => null,
        );

        expect(rpc.getPublicKey, throwsA(isA<RpcException>()));
      });

      test('throws RpcException on 401 when no callback provided', () async {
        mockClient = MockClient((request) async {
          return http.Response('Unauthorized', 401);
        });

        final rpc = KeycastRpc(
          nostrApi: 'https://login.divine.video/api/nostr',
          accessToken: 'expired_token',
          httpClient: mockClient,
        );

        expect(rpc.getPublicKey, throwsA(isA<RpcException>()));
      });

      test('does not retry on non-401 errors', () async {
        var callCount = 0;
        mockClient = MockClient((request) async {
          callCount++;
          return http.Response('Server error', 500);
        });

        final rpc = KeycastRpc(
          nostrApi: 'https://login.divine.video/api/nostr',
          accessToken: 'test_token',
          httpClient: mockClient,
          onTokenRefresh: () async => 'fresh_token',
        );

        expect(rpc.getPublicKey, throwsA(isA<RpcException>()));
        await Future<void>.delayed(Duration.zero);
        expect(callCount, equals(1));
      });

      test('throws when retry also returns 401', () async {
        var callCount = 0;
        mockClient = MockClient((request) async {
          callCount++;
          return http.Response('Unauthorized', 401);
        });

        final rpc = KeycastRpc(
          nostrApi: 'https://login.divine.video/api/nostr',
          accessToken: 'expired_token',
          httpClient: mockClient,
          onTokenRefresh: () async => 'also_expired_token',
        );

        expect(rpc.getPublicKey, throwsA(isA<RpcException>()));
        await Future<void>.delayed(Duration.zero);
        expect(callCount, equals(2));
      });

      test('fromSession passes onTokenRefresh to instance', () {
        const config = OAuthConfig(
          serverUrl: 'https://login.divine.video',
          clientId: 'test',
          redirectUri: 'divine://callback',
        );
        final session = KeycastSession(
          bunkerUrl: 'bunker://test',
          accessToken: 'valid_token',
          expiresAt: DateTime.now().add(const Duration(hours: 1)),
        );

        final rpc = KeycastRpc.fromSession(
          config,
          session,
          onTokenRefresh: () async => 'refreshed',
        );
        expect(rpc, isNotNull);
      });
    });

    group('request timeout', () {
      test('the single-op default is 20s and the batch default 30s', () {
        // Pinned because #6046 accidentally regressed the GLOBAL single-op
        // default to 12s while sizing it for the DM pipeline. None of the
        // production construction sites override requestTimeout, so that
        // bound applies to every RPC caller (video publish signing, likes,
        // reposts, follows) and cannot be re-tuned for one of them.
        //
        // 30s → 20s in #7092. The 30s was sized to cover ~20-30s single-op
        // latency under Keycast DB-pool contention (keycast#291); keycast#351
        // now bounds that handler at 8s and answers 504, so a live request
        // cannot spend that long server-side and the bound reverts to what it
        // is actually for — a dead-socket backstop sized on mobile transport
        // cost. Do not chase it further down: the value below the server
        // ceiling is where a live-but-slow request starts losing the server's
        // own classified answer to an anonymous client timeout.
        expect(KeycastRpc.defaultRequestTimeout, const Duration(seconds: 20));
        expect(
          KeycastRpc.defaultBatchRequestTimeout,
          const Duration(seconds: 30),
        );
      });

      test(
        'throws RpcTimeoutException when a single-op request hangs',
        () async {
          // Simulates a dead socket (e.g. Android Doze killing the
          // connection) — the request future never completes. Single-op RPCs
          // carry the same transient marker as Keycast's own 504 so DM sends
          // classify both give-up paths identically.
          mockClient = MockClient(
            (request) => Completer<http.Response>().future,
          );

          final rpc = KeycastRpc(
            nostrApi: 'https://login.divine.video/api/nostr',
            accessToken: 'test_token',
            httpClient: mockClient,
            requestTimeout: const Duration(milliseconds: 50),
          );

          await expectLater(
            rpc.getPublicKey(),
            throwsA(
              isA<RpcTimeoutException>().having(
                (e) => e,
                'transient marker',
                isA<TransientSignerFailure>(),
              ),
            ),
          );
        },
      );
    });

    group('requests and close across error zones', () {
      const pubkey =
          '3bf0c63fcb93463407af97a5e5ee64fa883d107ef9e558472c4eb9aaaefa459d';

      test(
        'closing from another error zone cancels a pending connect without '
        'leaking it to the zone that started the request',
        () async {
          // A real dart:io client whose connect never finishes until it is
          // cancelled, like one stuck on a stalled network. dart:io creates
          // the attempt's future in the zone that opened the request, and
          // HttpClient.close listens to it from the zone that closes.
          final connectStarted = Completer<void>();
          final rpc = KeycastRpc(
            nostrApi: 'https://login.divine.video/api/nostr',
            accessToken: 'test_token',
            httpClientFactory: () => IOClient(
              HttpClient()
                ..connectionFactory = (uri, proxyHost, proxyPort) async {
                  final attempt = Completer<Socket>();
                  if (!connectStarted.isCompleted) connectStarted.complete();
                  return ConnectionTask.fromSocket(attempt.future, () {
                    if (attempt.isCompleted) return;
                    attempt.completeError(
                      const SocketException('Connection attempt cancelled'),
                    );
                  });
                },
            ),
          );
          final leaked = <Object>[];

          late Future<Object?> outcome;
          runZonedGuarded(() {
            outcome = rpc.getPublicKey().then<Object?>(
              (value) => value,
              onError: (Object error) => error,
            );
          }, (error, _) => leaked.add(error));
          await connectStarted.future;
          // HttpClient registers the attempt for cancellation only once the
          // factory's future has resolved.
          await pumpEventQueue();

          runZonedGuarded(rpc.close, (error, _) => leaked.add(error));

          expect(await outcome, isA<http.ClientException>());
          await pumpEventQueue();
          expect(leaked, isEmpty);
        },
      );

      test('returns the result to a request made from another zone', () async {
        final rpc = KeycastRpc(
          nostrApi: 'https://login.divine.video/api/nostr',
          accessToken: 'test_token',
          httpClient: MockClient(
            (request) async =>
                http.Response(jsonEncode({'result': pubkey}), 200),
          ),
        );
        final leaked = <Object>[];

        late Future<String?> result;
        runZonedGuarded(() {
          result = rpc.getPublicKey();
        }, (error, _) => leaked.add(error));

        expect(await result, pubkey);
        expect(leaked, isEmpty);
      });

      test('returns the failure to a request made from another zone', () async {
        final rpc = KeycastRpc(
          nostrApi: 'https://login.divine.video/api/nostr',
          accessToken: 'test_token',
          httpClient: MockClient(
            (request) async =>
                throw http.ClientException('Connection reset', request.url),
          ),
          httpClientFactory: () => MockClient(
            (request) async =>
                throw http.ClientException('Connection reset', request.url),
          ),
        );
        final leaked = <Object>[];

        late Future<Object?> outcome;
        runZonedGuarded(() {
          outcome = rpc.getPublicKey().then<Object?>(
            (value) => value,
            onError: (Object error) => error,
          );
        }, (error, _) => leaked.add(error));

        expect(await outcome, isA<http.ClientException>());
        expect(leaked, isEmpty);
      });
    });

    group('signCanonicalPayload', () {
      test(
        'returns hex signature from RPC and base64-encodes payload',
        () async {
          final payload = Uint8List.fromList([0x01, 0x02, 0x03, 0xff]);
          const expectedSig =
              '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef'
              '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef';

          mockClient = MockClient((request) async {
            expect(request.headers['Authorization'], 'Bearer test_token');
            expect(request.headers['Content-Type'], 'application/json');

            final body = jsonDecode(request.body);
            expect(body['method'], 'sign_canonical');
            expect(body['params'], [base64Encode(payload)]);

            return http.Response(jsonEncode({'result': expectedSig}), 200);
          });

          final rpc = KeycastRpc(
            nostrApi: 'https://login.divine.video/api/nostr',
            accessToken: 'test_token',
            httpClient: mockClient,
          );

          final result = await rpc.signCanonicalPayload(payload);
          expect(result, equals(expectedSig));
        },
      );

      test(
        'returns null (not throw) when backend reports method-not-found',
        () async {
          var callCount = 0;
          mockClient = MockClient((request) async {
            callCount++;
            return http.Response(
              jsonEncode({'error': 'method_not_found'}),
              200,
            );
          });

          final rpc = KeycastRpc(
            nostrApi: 'https://login.divine.video/api/nostr',
            accessToken: 'test_token',
            httpClient: mockClient,
          );

          final result = await rpc.signCanonicalPayload(
            Uint8List.fromList([1, 2, 3]),
          );
          expect(result, isNull);

          final secondResult = await rpc.signCanonicalPayload(
            Uint8List.fromList([4, 5, 6]),
          );
          expect(secondResult, isNull);
          expect(callCount, equals(1));
        },
      );

      test(
        'caches unsupported HTTP response and skips later requests',
        () async {
          var callCount = 0;
          mockClient = MockClient((request) async {
            callCount++;
            return http.Response(
              jsonEncode({'error': 'Unsupported method: sign_canonical'}),
              400,
            );
          });

          final rpc = KeycastRpc(
            nostrApi: 'https://login.divine.video/api/nostr',
            accessToken: 'test_token',
            httpClient: mockClient,
          );

          final result = await rpc.signCanonicalPayload(
            Uint8List.fromList([1, 2, 3]),
          );
          expect(result, isNull);

          final secondResult = await rpc.signCanonicalPayload(
            Uint8List.fromList([4, 5, 6]),
          );
          expect(secondResult, isNull);
          expect(callCount, equals(1));
        },
      );

      test('does not cache transient HTTP failures', () async {
        var callCount = 0;
        mockClient = MockClient((request) async {
          callCount++;
          if (callCount == 1) {
            return http.Response('Server error', 500);
          }
          return http.Response(jsonEncode({'result': 'a' * 128}), 200);
        });

        final rpc = KeycastRpc(
          nostrApi: 'https://login.divine.video/api/nostr',
          accessToken: 'test_token',
          httpClient: mockClient,
        );

        final firstResult = await rpc.signCanonicalPayload(
          Uint8List.fromList([1, 2, 3]),
        );
        expect(firstResult, isNull);

        final secondResult = await rpc.signCanonicalPayload(
          Uint8List.fromList([4, 5, 6]),
        );
        expect(secondResult, equals('a' * 128));
        expect(callCount, equals(2));
      });

      test('returns null on HTTP 500 error response', () async {
        mockClient = MockClient((request) async {
          return http.Response('Server error', 500);
        });

        final rpc = KeycastRpc(
          nostrApi: 'https://login.divine.video/api/nostr',
          accessToken: 'test_token',
          httpClient: mockClient,
        );

        final result = await rpc.signCanonicalPayload(
          Uint8List.fromList([1, 2, 3]),
        );
        expect(result, isNull);
      });

      test('returns null on network exception', () async {
        mockClient = MockClient((request) async {
          throw Exception('connection refused');
        });

        final rpc = KeycastRpc(
          nostrApi: 'https://login.divine.video/api/nostr',
          accessToken: 'test_token',
          httpClient: mockClient,
        );

        final result = await rpc.signCanonicalPayload(
          Uint8List.fromList([1, 2, 3]),
        );
        expect(result, isNull);
      });
    });

    group('nip17UnwrapBatch', () {
      Map<String, dynamic> giftWrap(String id) => {
        'id': id,
        'pubkey': 'a' * 64,
        'created_at': 1700000000,
        'kind': 1059,
        'tags': <List<String>>[],
        'content': 'ciphertext-$id',
        'sig': 'b' * 128,
      };

      test('throws when the RPC is closed', () async {
        final rpc = KeycastRpc(
          nostrApi: 'https://login.divine.video/api/nostr',
          accessToken: 'test_token',
          httpClient: mockClient,
        )..close();

        await expectLater(
          rpc.nip17UnwrapBatch([giftWrap('1')]),
          throwsA(isA<KeycastRpcClosedException>()),
        );
      });

      test('posts the verb with the gift-wrap list and parses ordered '
          'slots', () async {
        final wraps = [giftWrap('11'), giftWrap('22')];
        final rumor = {
          'id': 'c' * 64,
          'pubkey': 'd' * 64,
          'created_at': 1700000001,
          'kind': 14,
          'tags': <List<String>>[],
          'content': 'hello',
        };

        mockClient = MockClient((request) async {
          expect(request.headers['Authorization'], 'Bearer test_token');
          final body = jsonDecode(request.body);
          expect(body['method'], 'nip17_unwrap_batch');
          expect(body['params'], wraps);
          return http.Response(
            jsonEncode({
              'result': [
                {'rumor': rumor, 'sender': 'd' * 64},
                {'error': 'sender_mismatch'},
              ],
            }),
            200,
          );
        });

        final rpc = KeycastRpc(
          nostrApi: 'https://login.divine.video/api/nostr',
          accessToken: 'test_token',
          httpClient: mockClient,
        );

        final slots = await rpc.nip17UnwrapBatch(wraps);
        expect(slots, hasLength(2));
        expect(slots![0].isSuccess, isTrue);
        expect(slots[0].sender, 'd' * 64);
        expect(slots[0].rumor, rumor);
        expect(slots[1].isSuccess, isFalse);
        expect(slots[1].error, 'sender_mismatch');
      });

      test('retries batch request once on a fresh transport after a socket '
          'error', () async {
        final wraps = [giftWrap('11')];
        final rumor = {
          'id': 'c' * 64,
          'pubkey': 'd' * 64,
          'created_at': 1700000001,
          'kind': 14,
          'tags': <List<String>>[],
          'content': 'hello',
        };
        var firstClientCalls = 0;
        var retryClientCalls = 0;
        final firstClient = MockClient((request) async {
          firstClientCalls++;
          throw http.ClientException('Bad file descriptor', request.url);
        });
        final retryClient = MockClient((request) async {
          retryClientCalls++;
          final body = jsonDecode(request.body);
          expect(body['method'], 'nip17_unwrap_batch');
          expect(body['params'], wraps);
          return http.Response(
            jsonEncode({
              'result': [
                {'rumor': rumor, 'sender': 'd' * 64},
              ],
            }),
            200,
          );
        });

        final rpc = KeycastRpc(
          nostrApi: 'https://login.divine.video/api/nostr',
          accessToken: 'test_token',
          httpClient: firstClient,
          httpClientFactory: () => retryClient,
        );

        final slots = await rpc.nip17UnwrapBatch(wraps);

        expect(slots, hasLength(1));
        expect(slots![0].isSuccess, isTrue);
        expect(firstClientCalls, equals(1));
        expect(retryClientCalls, equals(1));
      });

      test('returns null when the backend lacks the verb', () async {
        mockClient = MockClient((request) async {
          return http.Response(
            jsonEncode({'error': 'Unsupported method: nip17_unwrap_batch'}),
            200,
          );
        });
        final rpc = KeycastRpc(
          nostrApi: 'https://login.divine.video/api/nostr',
          accessToken: 'test_token',
          httpClient: mockClient,
        );
        expect(await rpc.nip17UnwrapBatch([giftWrap('1')]), isNull);
      });

      test('throws rather than returning null on a request-level rejection '
          'that shares the unsupported-method status code', () async {
        // Same HTTP 400 as an absent verb, different body. Collapsing this to
        // null would latch the caller onto the per-wrap decrypt path for the
        // whole session because of one bad request (#7323).
        mockClient = MockClient((request) async {
          return http.Response('boom', 400);
        });
        final rpc = KeycastRpc(
          nostrApi: 'https://login.divine.video/api/nostr',
          accessToken: 'test_token',
          httpClient: mockClient,
        );
        await expectLater(
          rpc.nip17UnwrapBatch([giftWrap('1')]),
          throwsA(isA<RpcException>()),
        );
      });

      test('throws on a transient server error', () async {
        // A 503 under pool saturation is not evidence the verb is missing.
        // Before #7323 this latched the drain onto two decrypt round trips per
        // wrap for the rest of the session.
        mockClient = MockClient((request) async {
          return http.Response('Database temporarily unavailable', 503);
        });
        final rpc = KeycastRpc(
          nostrApi: 'https://login.divine.video/api/nostr',
          accessToken: 'test_token',
          httpClient: mockClient,
        );
        await expectLater(
          rpc.nip17UnwrapBatch([giftWrap('1')]),
          throwsA(isA<RpcException>()),
        );
      });

      test('throws on an expired token rather than latching the verb '
          'off', () async {
        // A 401 that survives refresh is an auth problem, not a capability
        // one — the verb is still there once the session recovers.
        mockClient = MockClient((request) async {
          return http.Response('Unauthorized', 401);
        });
        final rpc = KeycastRpc(
          nostrApi: 'https://login.divine.video/api/nostr',
          accessToken: 'test_token',
          httpClient: mockClient,
        );
        await expectLater(
          rpc.nip17UnwrapBatch([giftWrap('1')]),
          throwsA(isA<RpcException>()),
        );
      });

      test('returns null on the plain-text unsupported-method body, not '
          'only the JSON one', () async {
        // keycast answers HTTP 400 with a bare body for an unknown method
        // (`format!("Unsupported method: {}", method)`), so the body — not the
        // status — identifies an older backend. The sibling nip17WrapBatch
        // suite pins the same shape.
        mockClient = MockClient((request) async {
          return http.Response('Unsupported method: nip17_unwrap_batch', 400);
        });
        final rpc = KeycastRpc(
          nostrApi: 'https://login.divine.video/api/nostr',
          accessToken: 'test_token',
          httpClient: mockClient,
        );
        expect(await rpc.nip17UnwrapBatch([giftWrap('1')]), isNull);
      });

      test('propagates TimeoutException rather than swallowing it to '
          'null', () async {
        // A timed-out page must be retryable by the caller, never mistaken
        // for "no messages" — so unlike signCanonicalPayload, the batch verb
        // does not catch TimeoutException.
        mockClient = MockClient((request) => Completer<http.Response>().future);
        // The batch verb is bounded by batchRequestTimeout (not the shorter
        // single-op requestTimeout), so shorten that one to exercise the
        // timeout-propagation path.
        final rpc = KeycastRpc(
          nostrApi: 'https://login.divine.video/api/nostr',
          accessToken: 'test_token',
          httpClient: mockClient,
          batchRequestTimeout: const Duration(milliseconds: 50),
        );
        await expectLater(
          rpc.nip17UnwrapBatch([giftWrap('1')]),
          throwsA(isA<TimeoutException>()),
        );
      });

      test('late 401 with timed-out refresh propagates timeout rather than '
          'returning null', () async {
        var postCalls = 0;
        mockClient = MockClient((request) async {
          postCalls++;
          await Future<void>.delayed(const Duration(milliseconds: 150));
          return http.Response('expired', 401);
        });
        var refreshCalls = 0;
        final rpc = KeycastRpc(
          nostrApi: 'https://login.divine.video/api/nostr',
          accessToken: 'expired_token',
          httpClient: mockClient,
          batchRequestTimeout: const Duration(milliseconds: 200),
          onTokenRefresh: () async {
            refreshCalls++;
            await Future<void>.delayed(const Duration(milliseconds: 100));
            return 'fresh_token';
          },
        );

        await expectLater(
          rpc.nip17UnwrapBatch([giftWrap('1')]),
          throwsA(isA<TimeoutException>()),
        );
        expect(
          postCalls,
          equals(1),
          reason: 'the refresh timed out before a retry POST could be issued.',
        );
        expect(refreshCalls, equals(1));
      });

      test('is bounded by batchRequestTimeout, not the shorter single-op '
          'requestTimeout', () async {
        // The heavier batch verb must NOT be aborted by the short single-op
        // requestTimeout — only batchRequestTimeout bounds it. Answer after the
        // single-op bound would have fired but well within the batch bound.
        final rumor = {
          'id': 'c' * 64,
          'pubkey': 'd' * 64,
          'created_at': 1700000001,
          'kind': 14,
          'tags': <List<String>>[],
          'content': 'hello',
        };
        mockClient = MockClient((request) async {
          await Future<void>.delayed(const Duration(milliseconds: 200));
          return http.Response(
            jsonEncode({
              'result': [
                {'rumor': rumor, 'sender': 'd' * 64},
              ],
            }),
            200,
          );
        });
        final rpc = KeycastRpc(
          nostrApi: 'https://login.divine.video/api/nostr',
          accessToken: 'test_token',
          httpClient: mockClient,
          requestTimeout: const Duration(milliseconds: 50),
          batchRequestTimeout: const Duration(seconds: 5),
        );

        final slots = await rpc.nip17UnwrapBatch([giftWrap('1')]);
        expect(slots, hasLength(1));
        expect(slots![0].isSuccess, isTrue);
      });
    });

    group('nip17WrapBatch', () {
      final rumor = {
        'id': 'c' * 64,
        'pubkey': 'd' * 64,
        'created_at': 1700000001,
        'kind': 14,
        'tags': [
          ['p', 'e' * 64],
        ],
        'content': 'hello',
        'sig': '',
      };
      final recipients = ['e' * 64, 'd' * 64];

      Map<String, dynamic> wrap(String id) => {
        'id': id,
        'pubkey': 'f' * 64,
        'created_at': 1700000000,
        'kind': 1059,
        'tags': [
          ['p', 'e' * 64],
        ],
        'content': 'ciphertext-$id',
        'sig': 'b' * 128,
      };

      KeycastRpc rpcWith(MockClient client, {Duration? batchTimeout}) =>
          KeycastRpc(
            nostrApi: 'https://login.divine.video/api/nostr',
            accessToken: 'test_token',
            httpClient: client,
            batchRequestTimeout:
                batchTimeout ?? KeycastRpc.defaultBatchRequestTimeout,
          );

      test('posts the rumor and recipient list as two positional params '
          'and parses ordered slots', () async {
        mockClient = MockClient((request) async {
          expect(request.headers['Authorization'], 'Bearer test_token');
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          expect(body['method'], 'nip17_wrap_batch');
          // The server parses exactly [rumorObject, [recipientHex...]]; a
          // flattened or reordered params list is a request-level rejection.
          expect(body['params'], [rumor, recipients]);
          return http.Response(
            jsonEncode({
              'result': [
                {'gift_wrap': wrap('11')},
                {'gift_wrap': wrap('22')},
              ],
            }),
            200,
          );
        });

        final slots = await rpcWith(
          mockClient,
        ).nip17WrapBatch(rumor, recipients);

        expect(slots, hasLength(2));
        expect(slots![0].isSuccess, isTrue);
        expect(slots[0].giftWrap, wrap('11'));
        expect(slots[1].giftWrap, wrap('22'));
      });

      test('keeps a per-recipient error slot isolated from its '
          'siblings', () async {
        mockClient = MockClient((request) async {
          return http.Response(
            jsonEncode({
              'result': [
                {'gift_wrap': wrap('11')},
                {'error': 'invalid_recipient'},
              ],
            }),
            200,
          );
        });

        final slots = await rpcWith(
          mockClient,
        ).nip17WrapBatch(rumor, recipients);

        expect(slots![0].isSuccess, isTrue);
        expect(slots[1].isSuccess, isFalse);
        expect(slots[1].error, 'invalid_recipient');
        expect(slots[1].giftWrap, isNull);
      });

      test('reports a malformed slot as a failure rather than throwing', () {
        // A slot that is neither {gift_wrap} nor {error} must not take the
        // whole send down; the caller treats it like any other failed slot.
        mockClient = MockClient((request) async {
          return http.Response(
            jsonEncode({
              'result': [
                {'unexpected': true},
              ],
            }),
            200,
          );
        });

        return expectLater(
          rpcWith(mockClient).nip17WrapBatch(rumor, recipients),
          completion(
            allOf(
              hasLength(1),
              predicate<List<GiftWrapSlot>>(
                (slots) => slots.single.error == 'invalid_slot',
                'reports invalid_slot',
              ),
            ),
          ),
        );
      });

      test('returns null when the backend lacks the verb', () async {
        // keycast answers HTTP 400 with this body for an unknown method, so
        // the body — not the status — is what identifies an older backend.
        mockClient = MockClient((request) async {
          return http.Response('Unsupported method: nip17_wrap_batch', 400);
        });

        expect(
          await rpcWith(mockClient).nip17WrapBatch(rumor, recipients),
          isNull,
        );
      });

      test('throws rather than returning null on a request-level rejection '
          'that shares the unsupported-method status code', () async {
        // Same HTTP 400 as an absent verb, different body. Collapsing this to
        // null would latch the caller onto the slow path for the whole session
        // because of one bad request.
        mockClient = MockClient((request) async {
          return http.Response('Rumor kind must be 14 or 15', 400);
        });

        await expectLater(
          rpcWith(mockClient).nip17WrapBatch(rumor, recipients),
          throwsA(isA<RpcException>()),
        );
      });

      test('throws on a transient server error', () async {
        // A 503 under pool saturation is not evidence the verb is missing.
        mockClient = MockClient((request) async {
          return http.Response('Database temporarily unavailable', 503);
        });

        await expectLater(
          rpcWith(mockClient).nip17WrapBatch(rumor, recipients),
          throwsA(isA<RpcException>()),
        );
      });

      test('throws on the policy refusal so the caller can terminalize '
          'it', () async {
        // The verified_minor gate answers 403 with this marker; the send path
        // matches on it to return `blocked` instead of a retryable failure.
        mockClient = MockClient((request) async {
          return http.Response('Operation denied by policy', 403);
        });

        await expectLater(
          rpcWith(mockClient).nip17WrapBatch(rumor, recipients),
          throwsA(
            isA<RpcException>().having(
              (e) => e.message,
              'message',
              contains('Operation denied by policy'),
            ),
          ),
        );
      });

      test('propagates transient RpcTimeoutException rather than swallowing '
          'it to null', () async {
        mockClient = MockClient((request) => Completer<http.Response>().future);

        await expectLater(
          rpcWith(
            mockClient,
            batchTimeout: const Duration(milliseconds: 50),
          ).nip17WrapBatch(rumor, recipients),
          throwsA(isA<RpcTimeoutException>()),
        );
      });

      test(
        'shares one batch deadline across a 401 refresh and retry',
        () async {
          var callCount = 0;
          mockClient = MockClient((request) async {
            callCount++;
            if (callCount == 1) {
              await Future<void>.delayed(const Duration(milliseconds: 100));
              return http.Response('Unauthorized', 401);
            }
            return Completer<http.Response>().future;
          });
          final rpc = KeycastRpc(
            nostrApi: 'https://login.divine.video/api/nostr',
            accessToken: 'expired_token',
            httpClient: mockClient,
            onTokenRefresh: () async => 'fresh_token',
            batchRequestTimeout: const Duration(milliseconds: 250),
          );
          final stopwatch = Stopwatch()..start();

          await expectLater(
            rpc.nip17WrapBatch(rumor, recipients),
            throwsA(isA<RpcTimeoutException>()),
          );

          expect(callCount, 2);
          expect(
            stopwatch.elapsed,
            lessThan(const Duration(milliseconds: 330)),
          );
        },
      );

      test(
        'classifies a refresh timeout as a transient batch timeout',
        () async {
          mockClient = MockClient(
            (request) async => http.Response('Unauthorized', 401),
          );
          final rpc = KeycastRpc(
            nostrApi: 'https://login.divine.video/api/nostr',
            accessToken: 'expired_token',
            httpClient: mockClient,
            onTokenRefresh: () => Completer<String?>().future,
            batchRequestTimeout: const Duration(milliseconds: 50),
          );

          await expectLater(
            rpc.nip17WrapBatch(rumor, recipients),
            throwsA(isA<RpcTimeoutException>()),
          );
        },
      );

      test('is bounded by batchRequestTimeout, not the shorter single-op '
          'requestTimeout', () async {
        mockClient = MockClient((request) async {
          await Future<void>.delayed(const Duration(milliseconds: 200));
          return http.Response(
            jsonEncode({
              'result': [
                {'gift_wrap': wrap('11')},
              ],
            }),
            200,
          );
        });
        final rpc = KeycastRpc(
          nostrApi: 'https://login.divine.video/api/nostr',
          accessToken: 'test_token',
          httpClient: mockClient,
          requestTimeout: const Duration(milliseconds: 50),
          batchRequestTimeout: const Duration(seconds: 5),
        );

        final slots = await rpc.nip17WrapBatch(rumor, recipients);
        expect(slots, hasLength(1));
        expect(slots![0].isSuccess, isTrue);
      });
    });
  });
}

http.StreamedResponse _rpcResult(
  http.BaseRequest request,
  Object body, {
  int statusCode = 200,
}) {
  return http.StreamedResponse(
    Stream.value(utf8.encode(jsonEncode(body))),
    statusCode,
    request: request,
  );
}

class _ControlledClient extends http.BaseClient {
  _ControlledClient(this._handler);

  final Future<http.StreamedResponse> Function(http.BaseRequest request)
  _handler;
  int closeCount = 0;
  bool isClosed = false;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    if (isClosed) {
      throw http.ClientException('Client is already closed.', request.url);
    }
    return _handler(request);
  }

  @override
  void close() {
    closeCount++;
    isClosed = true;
  }
}
