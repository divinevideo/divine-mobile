// ABOUTME: Tests the durable account-deletion coordinator HTTP contract.
// ABOUTME: Pins exact NIP-98 URLs, payload bytes, states, and 404 semantics.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nostr_sdk/event.dart';
import 'package:openvine/models/account_deletion_attempt.dart';
import 'package:openvine/repositories/account_deletion_recovery_repository.dart';
import 'package:openvine/services/nip98_auth_service.dart';

class _MockNip98AuthService extends Mock implements Nip98AuthService {}

void main() {
  late _MockNip98AuthService nip98;

  setUpAll(() {
    registerFallbackValue(HttpMethod.get);
  });

  setUp(() {
    nip98 = _MockNip98AuthService();
    when(
      () => nip98.createAuthToken(
        url: any(named: 'url'),
        method: any(named: 'method'),
        payload: any(named: 'payload'),
      ),
    ).thenAnswer((_) async => _token());
  });

  AccountDeletionRecoveryRepository repository(
    http.Client client, {
    Duration timeout = const Duration(seconds: 15),
    Duration retryBaseDelay = const Duration(milliseconds: 500),
    Future<void> Function(Duration) delay = Future<void>.delayed,
    String? Function()? currentPubkey,
  }) => AccountDeletionRecoveryRepository(
    baseUrl: 'https://api.divine.video/',
    nameServerBaseUrl: 'https://names.divine.video/',
    httpClient: client,
    nip98AuthService: nip98,
    currentPubkey:
        currentPubkey ??
        () =>
            '385c3a6ec0b9d57a4330dbd6284989be5bd00e41c535f9ca39b6ae7c521b81cd',
    timeout: timeout,
    retryBaseDelay: retryBaseDelay,
    delay: delay,
  );

  http.Response coordinatorPreparing(http.Request request) => http.Response(
    jsonEncode({
      'id': 'attempt-1',
      'status': 'preparing',
      'operation': 'none',
      'username': 'alice',
    }),
    201,
  );

  group('AccountDeletionRecoveryRepository methods', () {
    test('public status lookup needs only the receipt identity', () async {
      http.Request? captured;
      final result =
          await repository(
            MockClient((request) async {
              captured = request;
              return http.Response(
                jsonEncode({
                  'id': 'attempt-1',
                  'status': 'completed',
                  'failure_code': null,
                }),
                200,
              );
            }),
          ).fetchStatus(
            attemptId: 'attempt-1',
            pubkeyHex: '385c3a6ec0b9d57a4330dbd6284989be5bd00e41c535f9ca39b6ae7c521b81cd',
          );

      expect(result.status, AccountDeletionAttemptStatus.completed);
      expect(
        captured?.url.toString(),
        'https://api.divine.video/api/account-deletion/attempts/'
        'attempt-1/status',
      );
      expect(
        captured?.headers['x-account-deletion-pubkey'],
        '385c3a6ec0b9d57a4330dbd6284989be5bd00e41c535f9ca39b6ae7c521b81cd',
      );
      verifyNever(
        () => nip98.createAuthToken(
          url: any(named: 'url'),
          method: any(named: 'method'),
          payload: any(named: 'payload'),
        ),
      );
    });

    test('public status lookup preserves structured 404 evidence', () {
      expect(
        () =>
            repository(
              MockClient(
                (_) async => http.Response(
                  jsonEncode({'failure_code': 'attempt_not_found'}),
                  404,
                ),
              ),
            ).fetchStatus(
              attemptId: 'attempt-1',
              pubkeyHex: '385c3a6ec0b9d57a4330dbd6284989be5bd00e41c535f9ca39b6ae7c521b81cd',
            ),
        throwsA(
          isA<AccountDeletionRecoveryException>()
              .having((error) => error.statusCode, 'statusCode', 404)
              .having((error) => error.code, 'code', 'attempt_not_found'),
        ),
      );
    });

    test('public status lookup preserves server failures', () {
      expect(
        () =>
            repository(
              MockClient(
                (_) async => http.Response(
                  jsonEncode({'failure_code': 'coordinator_unavailable'}),
                  503,
                ),
              ),
              delay: (_) async {},
            ).fetchStatus(
              attemptId: 'attempt-1',
              pubkeyHex: '385c3a6ec0b9d57a4330dbd6284989be5bd00e41c535f9ca39b6ae7c521b81cd',
            ),
        throwsA(
          isA<AccountDeletionRecoveryException>()
              .having((error) => error.statusCode, 'statusCode', 503)
              .having(
                (error) => error.code,
                'code',
                'coordinator_unavailable',
              ),
        ),
      );
    });

    test(
      'prepare signs and posts the exact coordinator URL and body',
      () async {
        http.Request? captured;
        final result = await repository(
          MockClient((request) async {
            captured = request;
            return http.Response(
              jsonEncode({
                'id': 'attempt-1',
                'status': 'recoverable',
                'operation': 'none',
                'username': 'alice',
              }),
              201,
            );
          }),
        ).prepare(username: 'alice');

        expect(result.status, AccountDeletionAttemptStatus.recoverable);
        expect(
          captured?.url.toString(),
          'https://api.divine.video/api/account-deletion/attempts',
        );
        expect(captured?.body, jsonEncode({'username': 'alice'}));
        verify(
          () => nip98.createAuthToken(
            url: 'https://api.divine.video/api/account-deletion/attempts',
            method: HttpMethod.post,
            payload: jsonEncode({'username': 'alice'}),
          ),
        ).called(1);
      },
    );

    test('current returns null only for a definitive 404', () async {
      final result = await repository(
        MockClient((_) async => http.Response('{}', 404)),
      ).fetchCurrent();

      expect(result, isNull);
    });

    test('route-absent 404 preserves status, stage, and availability', () {
      expect(
        () => repository(
          MockClient((_) async => http.Response('', 404)),
        ).prepare(),
        throwsA(
          isA<AccountDeletionRecoveryException>()
              .having((error) => error.statusCode, 'statusCode', 404)
              .having(
                (error) => error.stage,
                'stage',
                AccountDeletionRecoveryStage.coordinatorAttempt,
              )
              .having(
                (error) => error.indicatesMissingCoordinatorRoute,
                'indicatesMissingCoordinatorRoute',
                isTrue,
              )
              .having(
                (error) => error.indicatesUsernameRecoveryUnsupported,
                'indicatesUsernameRecoveryUnsupported',
                isFalse,
              ),
        ),
      );
    });

    test('structured coordinator 404 is not classified as route absent', () {
      expect(
        () => repository(
          MockClient(
            (_) async => http.Response(
              jsonEncode({'failure_code': 'attempt_not_found'}),
              404,
            ),
          ),
        ).prepare(),
        throwsA(
          isA<AccountDeletionRecoveryException>()
              .having((error) => error.statusCode, 'statusCode', 404)
              .having(
                (error) => error.indicatesMissingCoordinatorRoute,
                'indicatesMissingCoordinatorRoute',
                isFalse,
              ),
        ),
      );
    });

    test('a coordinator with no Name Server stays user-actionable', () {
      expect(
        () => repository(
          MockClient(
            (_) async => http.Response(
              jsonEncode({
                'failure_code': 'username_recovery_unavailable',
                'failure_message':
                    'Username recovery is unavailable in this environment',
              }),
              503,
            ),
          ),
          delay: (_) async {},
        ).prepare(username: 'alice'),
        throwsA(
          isA<AccountDeletionRecoveryException>()
              .having((error) => error.statusCode, 'statusCode', 503)
              .having(
                (error) => error.stage,
                'stage',
                AccountDeletionRecoveryStage.coordinatorAttempt,
              )
              .having(
                (error) => error.indicatesUsernameRecoveryUnsupported,
                'indicatesUsernameRecoveryUnsupported',
                isTrue,
              ),
        ),
      );
    });

    test('a structured coordinator outage remains neutral', () {
      expect(
        () => repository(
          MockClient(
            (_) async => http.Response(
              jsonEncode({
                'failure_code': 'coordinator_unavailable',
                'failure_message':
                    'Deletion service is temporarily unavailable',
              }),
              503,
            ),
          ),
          delay: (_) async {},
        ).prepare(username: 'alice'),
        throwsA(
          isA<AccountDeletionRecoveryException>()
              .having(
                (error) => error.indicatesUsernameRecoveryUnsupported,
                'indicatesUsernameRecoveryUnsupported',
                isFalse,
              )
              .having(
                (error) => error.indicatesMissingCoordinatorRoute,
                'indicatesMissingCoordinatorRoute',
                isFalse,
              ),
        ),
      );
    });

    test('coordinator transport failure remains transient', () {
      expect(
        () => repository(
          MockClient((_) async => throw http.ClientException('offline')),
        ).prepare(),
        throwsA(
          isA<AccountDeletionRecoveryException>()
              .having(
                (error) => error.stage,
                'stage',
                AccountDeletionRecoveryStage.coordinatorAttempt,
              )
              .having(
                (error) => error.indicatesMissingCoordinatorRoute,
                'indicatesMissingCoordinatorRoute',
                isFalse,
              ),
        ),
      );
    });

    test('coordinator TLS failure remains transient', () {
      expect(
        () => repository(
          MockClient((_) async => throw const HandshakeException('bad TLS')),
        ).prepare(),
        throwsA(
          isA<AccountDeletionRecoveryException>()
              .having(
                (error) => error.stage,
                'stage',
                AccountDeletionRecoveryStage.coordinatorAttempt,
              )
              .having(
                (error) => error.indicatesMissingCoordinatorRoute,
                'indicatesMissingCoordinatorRoute',
                isFalse,
              ),
        ),
      );
    });

    test(
      'preparing username completes owner prepare and verified handshake',
      () async {
        final requests = <http.Request>[];
        final result = await repository(
          MockClient((request) async {
            requests.add(request);
            if (request.url.path == '/api/account-deletion/attempts') {
              return http.Response(
                jsonEncode({
                  'id': 'attempt-00000001',
                  'status': 'preparing',
                  'operation': 'none',
                  'username': 'alice',
                }),
                201,
              );
            }
            if (request.url.host == 'names.divine.video') {
              return http.Response(
                jsonEncode({
                  'attempt_id': 'attempt-00000001',
                  'state': 'pending',
                  'expires_at': 1787450400,
                }),
                200,
              );
            }
            return http.Response(
              jsonEncode({
                'id': 'attempt-00000001',
                'status': 'recoverable',
                'operation': 'none',
                'username': 'alice',
                'username_expires_at': 1787450400,
              }),
              200,
            );
          }),
        ).prepare(username: 'alice');

        expect(result.status, AccountDeletionAttemptStatus.recoverable);
        expect(result.usernameExpiresAt, 1787450400);
        expect(requests.map((request) => request.url.path), [
          '/api/account-deletion/attempts',
          '/api/username/release/prepare',
          '/api/account-deletion/attempts/attempt-00000001/username-prepared',
        ]);
      },
    );

    test('Name Server failure is tagged as username preparation', () {
      expect(
        () => repository(
          MockClient((request) async {
            if (request.url.host == 'names.divine.video') {
              return http.Response('{}', 503);
            }
            return coordinatorPreparing(request);
          }),
          delay: (_) async {},
        ).prepare(username: 'alice'),
        throwsA(
          isA<AccountDeletionRecoveryException>()
              .having((error) => error.statusCode, 'statusCode', 503)
              .having(
                (error) => error.stage,
                'stage',
                AccountDeletionRecoveryStage.usernamePreparation,
              ),
        ),
      );
    });

    test('coordinator confirmation failure has its own stage', () {
      expect(
        () => repository(
          MockClient((request) async {
            if (request.url.path == '/api/account-deletion/attempts') {
              return coordinatorPreparing(request);
            }
            if (request.url.host == 'names.divine.video') {
              return http.Response(
                jsonEncode({
                  'attempt_id': 'attempt-1',
                  'state': 'pending',
                  'expires_at': 1787450400,
                }),
                200,
              );
            }
            return http.Response('{}', 503);
          }),
          delay: (_) async {},
        ).prepare(username: 'alice'),
        throwsA(
          isA<AccountDeletionRecoveryException>()
              .having((error) => error.statusCode, 'statusCode', 503)
              .having(
                (error) => error.stage,
                'stage',
                AccountDeletionRecoveryStage.coordinatorUsernameConfirmation,
              ),
        ),
      );
    });

    test(
      'resume preparation preserves the existing coordinator attempt id',
      () async {
        final requests = <http.Request>[];
        final result =
            await repository(
              MockClient((request) async {
                requests.add(request);
                if (request.url.host == 'names.divine.video') {
                  return http.Response(
                    jsonEncode({
                      'attempt_id': 'existing-attempt',
                      'state': 'pending',
                      'expires_at': 1787450400,
                    }),
                    200,
                  );
                }
                return http.Response(
                  jsonEncode({
                    'id': 'existing-attempt',
                    'status': 'recoverable',
                    'operation': 'none',
                    'username': 'alice',
                  }),
                  200,
                );
              }),
            ).resumePreparation(
              const AccountDeletionAttempt(
                id: 'existing-attempt',
                status: AccountDeletionAttemptStatus.preparing,
                username: 'alice',
              ),
            );

        expect(result.id, 'existing-attempt');
        expect(requests.map((request) => request.url.path), [
          '/api/username/release/prepare',
          '/api/account-deletion/attempts/existing-attempt/username-prepared',
        ]);
      },
    );

    test('submit encodes IDs and surfaces processing state', () async {
      http.Request? captured;
      final result = await repository(
        MockClient((request) async {
          captured = request;
          return http.Response(
            jsonEncode({
              'id': 'attempt/1',
              'status': 'processing',
              'operation': 'none',
            }),
            202,
          );
        }),
      ).submit(attemptId: 'attempt/1', vanishEventId: 'event-id');

      expect(result.status, AccountDeletionAttemptStatus.processing);
      expect(
        captured?.url.toString(),
        'https://api.divine.video/api/account-deletion/attempts/'
        'attempt%2F1/submit',
      );
      expect(captured?.body, jsonEncode({'vanish_event_id': 'event-id'}));
    });

    test('cancel requires the distinct cancelled terminal state', () async {
      final result = await repository(
        MockClient(
          (_) async => http.Response(
            jsonEncode({
              'id': 'attempt-1',
              'status': 'cancelled',
              'operation': 'none',
            }),
            200,
          ),
        ),
      ).cancel(attemptId: 'attempt-1');

      expect(result.status, AccountDeletionAttemptStatus.cancelled);
      expect(result.requiresRecoveryScreen, isFalse);
    });

    test('unknown server state fails closed instead of guessing', () async {
      expect(
        () => repository(
          MockClient(
            (_) async => http.Response(
              jsonEncode({
                'id': 'attempt-1',
                'status': 'mystery',
                'operation': 'none',
              }),
              200,
            ),
          ),
        ).fetchCurrent(),
        throwsA(isA<FormatException>()),
      );
    });

    test('unknown operation fails closed instead of re-preparing', () async {
      expect(
        () => repository(
          MockClient(
            (_) async => http.Response(
              jsonEncode({
                'id': 'attempt-1',
                'status': 'preparing',
                'operation': 'rolling_back_somehow',
              }),
              200,
            ),
          ),
        ).fetchCurrent(),
        throwsA(isA<FormatException>()),
      );
    });

    for (final status in [
      'recoverable',
      'processing',
      'cancelled',
      'completed',
      'terminal_failure',
    ]) {
      test('$status + cancelling fails closed', () async {
        final result = repository(
          MockClient(
            (_) async => http.Response(
              jsonEncode({
                'id': 'attempt-1',
                'status': status,
                'operation': 'cancelling',
              }),
              200,
            ),
          ),
        );

        await expectLater(result.fetchCurrent(), throwsFormatException);
      });
    }

    test('202 cancel returns a cancellation-in-flight attempt', () async {
      final result = await repository(
        MockClient(
          (_) async => http.Response(
            jsonEncode({
              'id': 'attempt-1',
              'status': 'preparing',
              'operation': 'cancelling',
              'username': 'alice',
            }),
            202,
          ),
        ),
      ).cancel(attemptId: 'attempt-1');

      expect(result.isCancellationInFlight, isTrue);
    });

    test('cancelAndWait polls a 202 cancellation through cancelled', () async {
      var calls = 0;
      final result = await repository(
        MockClient((_) async {
          calls++;
          return switch (calls) {
            1 || 2 => http.Response(
              jsonEncode({
                'id': 'attempt-1',
                'status': 'preparing',
                'operation': 'cancelling',
                'username': 'alice',
              }),
              calls == 1 ? 202 : 200,
            ),
            _ => http.Response(
              jsonEncode({
                'id': 'attempt-1',
                'status': 'cancelled',
                'operation': 'none',
                'username': 'alice',
              }),
              200,
            ),
          };
        }),
        delay: (_) async {},
      ).cancelAndWait(attemptId: 'attempt-1');

      expect(result.status, AccountDeletionAttemptStatus.cancelled);
      expect(calls, 3);
    });

    test(
      'cancelAndWait gives up on a coordinator stuck in cancelling',
      () async {
        var calls = 0;
        final delays = <Duration>[];
        await expectLater(
          repository(
            MockClient((_) async {
              calls++;
              return http.Response(
                jsonEncode({
                  'id': 'attempt-1',
                  'status': 'preparing',
                  'operation': 'cancelling',
                  'username': 'alice',
                }),
                calls == 1 ? 202 : 200,
              );
            }),
            delay: (duration) async => delays.add(duration),
          ).cancelAndWait(
            attemptId: 'attempt-1',
            timeout: const Duration(seconds: 6),
          ),
          throwsA(isA<AccountDeletionRecoveryException>()),
        );

        expect(delays, hasLength(3));
        expect(calls, 4);
      },
    );

    test('coded error responses expose only the stable machine code', () async {
      expect(
        () => repository(
          MockClient(
            (_) async => http.Response(
              jsonEncode({
                'failure_code': 'cancellation_after_commit',
                'failure_message': 'server English must not reach the UI',
              }),
              409,
            ),
          ),
        ).cancel(attemptId: 'attempt-1'),
        throwsA(
          isA<AccountDeletionRecoveryException>()
              .having(
                (error) => error.code,
                'code',
                'cancellation_after_commit',
              )
              .having(
                (error) => error.message,
                'message',
                isNot(contains('server English')),
              ),
        ),
      );
    });

    test('429 and retryable 5xx use bounded exponential backoff', () async {
      var calls = 0;
      final delays = <Duration>[];
      final result = await repository(
        MockClient((_) async {
          calls++;
          if (calls == 1) return http.Response('{}', 429);
          if (calls == 2) return http.Response('{}', 503);
          return http.Response(
            jsonEncode({
              'id': 'attempt-1',
              'status': 'recoverable',
              'operation': 'none',
            }),
            200,
          );
        }),
        retryBaseDelay: const Duration(milliseconds: 10),
        delay: (duration) async => delays.add(duration),
      ).fetchCurrent();

      expect(result?.status, AccountDeletionAttemptStatus.recoverable);
      expect(calls, 3);
      expect(delays, const [
        Duration(milliseconds: 10),
        Duration(milliseconds: 20),
      ]);
    });

    test('exhausted 429 is not classified as a missing route', () {
      expect(
        () => repository(
          MockClient((_) async => http.Response('{}', 429)),
          delay: (_) async {},
        ).prepare(),
        throwsA(
          isA<AccountDeletionRecoveryException>()
              .having((error) => error.statusCode, 'statusCode', 429)
              .having(
                (error) => error.indicatesMissingCoordinatorRoute,
                'indicatesMissingCoordinatorRoute',
                isFalse,
              ),
        ),
      );
    });

    test('a stalled Name Server keeps the repository failure type', () async {
      expect(
        () => repository(
          MockClient((request) async {
            if (request.url.host == 'names.divine.video') {
              return Completer<http.Response>().future;
            }
            return coordinatorPreparing(request);
          }),
          timeout: const Duration(milliseconds: 50),
        ).prepare(username: 'alice'),
        throwsA(isA<AccountDeletionRecoveryException>()),
      );
    });

    test('a non-JSON Name Server reply keeps the repository failure type', () {
      expect(
        () => repository(
          MockClient((request) async {
            if (request.url.host == 'names.divine.video') {
              return http.Response('<html>502</html>', 200);
            }
            return coordinatorPreparing(request);
          }),
        ).prepare(username: 'alice'),
        throwsA(isA<AccountDeletionRecoveryException>()),
      );
    });

    test('rejects a cached NIP-98 token from a different account', () async {
      when(
        () => nip98.createAuthToken(
          url: any(named: 'url'),
          method: any(named: 'method'),
          payload: any(named: 'payload'),
        ),
      ).thenAnswer((_) async => _token(pubkey: _otherPubkey));

      expect(
        () => repository(
          MockClient((_) async => http.Response('{}', 404)),
        ).fetchCurrent(),
        throwsA(isA<AccountDeletionRecoveryException>()),
      );
    });
  });
}

const _otherPubkey =
    'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff';

Nip98Token _token({
  String pubkey =
      '385c3a6ec0b9d57a4330dbd6284989be5bd00e41c535f9ca39b6ae7c521b81cd',
}) {
  final now = clock.now();
  return Nip98Token(
    token: 'token',
    signedEvent: Event(pubkey, 27235, const [], ''),
    createdAt: now,
    expiresAt: now.add(const Duration(seconds: 45)),
  );
}
