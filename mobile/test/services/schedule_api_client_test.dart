// ABOUTME: Tests for ScheduleApiClient: NIP-98 wiring per call and the
// ABOUTME: classification of every relay answer for schedule/list/cancel.

import 'dart:async';
import 'dart:convert';

import 'package:clock/clock.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nostr_sdk/event.dart';
import 'package:openvine/services/nip98_auth_service.dart';
import 'package:openvine/services/schedule_api_client.dart';
import 'package:unified_logger/unified_logger.dart';

class _MockNip98AuthService extends Mock implements Nip98AuthService {}

void main() {
  const testPubkey =
      '385c3a6ec0b9d57a4330dbd6284989be5bd00e41c535f9ca39b6ae7c521b81cd';
  const otherPubkey =
      'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff';
  const eventId =
      '4444444444444444444444444444444444444444444444444444444444444444';

  late _MockNip98AuthService mockNip98;

  setUpAll(() {
    registerFallbackValue(HttpMethod.post);
  });

  setUp(() {
    mockNip98 = _MockNip98AuthService();
  });

  Event buildVideoEvent({String pubkey = testPubkey}) {
    return Event(
      pubkey,
      34236,
      const [
        ['d', 'test-video-id'],
        ['title', 'Plants'],
      ],
      'A plant video',
      createdAt: 1800000000,
    );
  }

  Nip98Token buildToken({String signerPubkey = testPubkey}) {
    final signedEvent = Event(
      signerPubkey,
      27235,
      const [
        ['u', 'https://relay.divine.video/api/schedule'],
        ['method', 'POST'],
      ],
      '',
      createdAt: 1700000000,
    );
    final now = clock.now();
    return Nip98Token(
      token: 'fake-base64-token',
      signedEvent: signedEvent,
      createdAt: now,
      expiresAt: now.add(const Duration(seconds: 45)),
    );
  }

  void stubToken(Nip98Token? token) {
    when(
      () => mockNip98.createAuthToken(
        url: any(named: 'url'),
        method: any(named: 'method'),
        payload: any(named: 'payload'),
      ),
    ).thenAnswer((_) async => token);
  }

  ScheduleApiClient buildClient(
    http.Client httpClient, {
    String apiBaseUrl = 'https://relay.divine.video',
  }) {
    return ScheduleApiClient(
      httpClient: httpClient,
      nip98AuthService: mockNip98,
      apiBaseUrl: () => apiBaseUrl,
    );
  }

  MockClient respondWith(int status, Object body) {
    return MockClient(
      (_) async => http.Response(
        body is String ? body : jsonEncode(body),
        status,
      ),
    );
  }

  group(ScheduleApiClient, () {
    group('schedule', () {
      test('POSTs the signed event JSON with a NIP-98 header', () async {
        stubToken(buildToken());
        final event = buildVideoEvent();
        http.Request? captured;
        final client = buildClient(
          MockClient((request) async {
            captured = request;
            return http.Response(
              jsonEncode({
                'event_id': event.id,
                'scheduled': true,
                'publish_at': 1800000000,
              }),
              202,
            );
          }),
        );

        final result = await client.schedule(event);

        expect(captured!.method, 'POST');
        expect(
          captured!.url.toString(),
          'https://relay.divine.video/api/schedule',
        );
        expect(captured!.body, jsonEncode(event.toJson()));
        expect(captured!.headers['Authorization'], 'Nostr fake-base64-token');
        expect(
          result,
          isA<ScheduleSubmitAccepted>()
              .having((r) => r.eventId, 'eventId', event.id)
              .having((r) => r.publishAt, 'publishAt', 1800000000),
        );
        verify(
          () => mockNip98.createAuthToken(
            url: 'https://relay.divine.video/api/schedule',
            method: HttpMethod.post,
            payload: jsonEncode(event.toJson()),
          ),
        ).called(1);
      });

      test('strips a trailing slash from the base URL', () {
        final client = buildClient(
          respondWith(202, ''),
          apiBaseUrl: 'https://relay.divine.video/',
        );
        expect(client.scheduleUrl, 'https://relay.divine.video/api/schedule');
      });

      test('treats 409 as accepted with the event created_at', () async {
        stubToken(buildToken());
        final event = buildVideoEvent();
        final client = buildClient(
          respondWith(409, {
            'event_id': event.id,
            'accepted': false,
            'message': 'this event is already scheduled',
          }),
        );

        final result = await client.schedule(event);

        expect(
          result,
          isA<ScheduleSubmitAccepted>().having(
            (r) => r.publishAt,
            'publishAt',
            event.createdAt,
          ),
        );
      });

      test('a 202 whose acceptance does not match is transient', () async {
        stubToken(buildToken());
        final client = buildClient(
          respondWith(202, {
            'event_id': 'someone-else',
            'scheduled': true,
            'publish_at': 1,
          }),
        );

        final result = await client.schedule(buildVideoEvent());

        expect(
          result,
          isA<ScheduleSubmitTransientFailure>().having(
            (r) => r.unavailable,
            'unavailable',
            isFalse,
          ),
        );
      });

      test('refuses locally when the signer is not the author', () async {
        stubToken(buildToken(signerPubkey: otherPubkey));
        var requests = 0;
        final client = buildClient(
          MockClient((_) async {
            requests++;
            return http.Response('', 202);
          }),
        );

        final result = await client.schedule(buildVideoEvent());

        expect(requests, 0);
        expect(
          result,
          isA<ScheduleSubmitRejected>()
              .having((r) => r.statusCode, 'statusCode', 0)
              .having((r) => r.kind, 'kind', ScheduleRejectionKind.forbidden),
        );
      });

      test('is transient without a NIP-98 token', () async {
        stubToken(null);
        final client = buildClient(respondWith(202, ''));

        final result = await client.schedule(buildVideoEvent());

        expect(
          result,
          isA<ScheduleSubmitTransientFailure>().having(
            (r) => r.reason,
            'reason',
            'nip98_token_unavailable',
          ),
        );
      });

      for (final (status, message, kind) in [
        (
          400,
          'kind 1 cannot be scheduled',
          ScheduleRejectionKind.invalidRequest,
        ),
        (
          400,
          'created_at must be more than 60s in the future; publish it '
              'directly instead',
          ScheduleRejectionKind.notFutureEnough,
        ),
        (
          400,
          'created_at is beyond the maximum scheduling horizon',
          ScheduleRejectionKind.beyondHorizon,
        ),
        (401, 'Auth failed: expired', ScheduleRejectionKind.unauthorized),
        (
          403,
          'NIP-98 signer pubkey does not match event author',
          ScheduleRejectionKind.forbidden,
        ),
        (
          402,
          'scheduling is not enabled for this account',
          ScheduleRejectionKind.notEntitled,
        ),
        (
          429,
          'author already has 100 posts pending',
          ScheduleRejectionKind.overCap,
        ),
      ]) {
        test('maps $status "$message" to ${kind.name}', () async {
          stubToken(buildToken());
          final client = buildClient(
            respondWith(status, {
              'event_id': '',
              'accepted': false,
              'message': message,
            }),
          );

          final result = await client.schedule(buildVideoEvent());

          expect(
            result,
            isA<ScheduleSubmitRejected>()
                .having((r) => r.statusCode, 'statusCode', status)
                .having((r) => r.kind, 'kind', kind)
                .having((r) => r.message, 'message', message),
          );
        });
      }

      test('treats a 429 rate limit as a transient failure', () async {
        stubToken(buildToken());
        final client = buildClient(
          respondWith(429, {
            'event_id': '',
            'accepted': false,
            'message':
                'rate-limited: too many events from this pubkey, slow down',
          }),
        );

        final result = await client.schedule(buildVideoEvent());

        expect(
          result,
          isA<ScheduleSubmitTransientFailure>()
              .having((r) => r.reason, 'reason', 'http_429')
              .having((r) => r.unavailable, 'unavailable', isFalse),
        );
      });

      test('a relay 503 is transient and unavailable', () async {
        stubToken(buildToken());
        final client = buildClient(
          respondWith(503, {
            'event_id': '',
            'accepted': false,
            'message': 'Scheduling not enabled (no relay URL configured)',
          }),
        );

        final result = await client.schedule(buildVideoEvent());

        expect(
          result,
          isA<ScheduleSubmitTransientFailure>().having(
            (r) => r.unavailable,
            'unavailable',
            isTrue,
          ),
        );
      });

      test('a bodiless gateway 404 is transient and unavailable', () async {
        stubToken(buildToken());
        final client = buildClient(respondWith(404, ''));

        final result = await client.schedule(buildVideoEvent());

        expect(
          result,
          isA<ScheduleSubmitTransientFailure>()
              .having((r) => r.reason, 'reason', 'http_404')
              .having((r) => r.unavailable, 'unavailable', isTrue),
        );
      });

      test('a 500 is transient but not unavailable', () async {
        stubToken(buildToken());
        final client = buildClient(respondWith(500, 'boom'));

        final result = await client.schedule(buildVideoEvent());

        expect(
          result,
          isA<ScheduleSubmitTransientFailure>()
              .having((r) => r.reason, 'reason', 'http_500')
              .having((r) => r.unavailable, 'unavailable', isFalse),
        );
      });

      test('a network error is transient', () async {
        stubToken(buildToken());
        final client = buildClient(
          MockClient((_) async => throw http.ClientException('offline')),
        );

        final result = await client.schedule(buildVideoEvent());

        expect(
          result,
          isA<ScheduleSubmitTransientFailure>().having(
            (r) => r.reason,
            'reason',
            startsWith('network_error'),
          ),
        );
      });

      test('a timeout is transient', () {
        fakeAsync((async) {
          stubToken(buildToken());
          final client = ScheduleApiClient(
            httpClient: MockClient(
              (_) => Future.any([]),
            ),
            nip98AuthService: mockNip98,
            apiBaseUrl: () => 'https://relay.divine.video',
            timeout: const Duration(seconds: 1),
          );

          ScheduleSubmitResult? result;
          unawaited(client.schedule(buildVideoEvent()).then((r) => result = r));
          async.elapse(const Duration(seconds: 2));

          expect(
            result,
            isA<ScheduleSubmitTransientFailure>().having(
              (r) => r.reason,
              'reason',
              'timeout',
            ),
          );
        });
      });
    });

    group('list', () {
      test(
        'GETs with a NIP-98 header bound to GET and parses entries',
        () async {
          stubToken(buildToken());
          http.Request? captured;
          final client = buildClient(
            MockClient((request) async {
              captured = request;
              return http.Response(
                jsonEncode({
                  'scheduled': [
                    {
                      'event_id': eventId,
                      'kind': 34236,
                      'publish_at': 1800000000,
                      'state': 'schedule',
                      'failure_reason': '',
                    },
                    {
                      'event_id': 'f' * 64,
                      'kind': 22,
                      'publish_at': 1700000000,
                      'state': 'failed',
                      'failure_reason': 'blocked: banned',
                    },
                    {'event_id': 'missing-fields'},
                    {
                      'event_id': 'x' * 64,
                      'kind': 22,
                      'publish_at': 1,
                      'state': 'teleported',
                      'failure_reason': '',
                    },
                  ],
                }),
                200,
              );
            }),
          );

          final result = await client.list();

          expect(captured!.method, 'GET');
          expect(captured!.body, isEmpty);
          verify(
            () => mockNip98.createAuthToken(
              url: 'https://relay.divine.video/api/schedule',
              method: HttpMethod.get,
            ),
          ).called(1);
          final loaded = result as ScheduleListLoaded;
          expect(loaded.entries, hasLength(2));
          expect(loaded.entries[0].eventId, eventId);
          expect(loaded.entries[0].state, ScheduledPostServerState.schedule);
          expect(loaded.entries[0].publishAt, 1800000000);
          expect(loaded.entries[1].state, ScheduledPostServerState.failed);
          expect(loaded.entries[1].failureReason, 'blocked: banned');
        },
      );

      test('a non-200 is a failure carrying the status', () async {
        stubToken(buildToken());
        final client = buildClient(respondWith(404, ''));

        final result = await client.list();

        expect(
          result,
          isA<ScheduleListFailure>()
              .having((r) => r.statusCode, 'statusCode', 404)
              .having((r) => r.reason, 'reason', 'http_404'),
        );
      });

      test('a 200 without a list is a failure', () async {
        stubToken(buildToken());
        final client = buildClient(respondWith(200, {'scheduled': 'nope'}));

        expect(await client.list(), isA<ScheduleListFailure>());
      });

      test('is a failure without a NIP-98 token', () async {
        stubToken(null);
        final client = buildClient(respondWith(200, {'scheduled': []}));

        expect(
          await client.list(),
          isA<ScheduleListFailure>().having(
            (r) => r.reason,
            'reason',
            'nip98_token_unavailable',
          ),
        );
      });

      test('a network error is a failure', () async {
        stubToken(buildToken());
        final client = buildClient(
          MockClient((_) async => throw http.ClientException('offline')),
        );

        expect(await client.list(), isA<ScheduleListFailure>());
      });
    });

    group('cancel', () {
      test(
        'DELETEs the event path with a NIP-98 header bound to DELETE',
        () async {
          stubToken(buildToken());
          http.Request? captured;
          final client = buildClient(
            MockClient((request) async {
              captured = request;
              return http.Response(
                jsonEncode({'event_id': eventId, 'cancelled': true}),
                200,
              );
            }),
          );

          final result = await client.cancel(eventId);

          expect(captured!.method, 'DELETE');
          expect(
            captured!.url.toString(),
            'https://relay.divine.video/api/schedule/$eventId',
          );
          verify(
            () => mockNip98.createAuthToken(
              url: 'https://relay.divine.video/api/schedule/$eventId',
              method: HttpMethod.delete,
            ),
          ).called(1);
          expect(result, isA<ScheduleCancelled>());
        },
      );

      test('a relay 404 (JSON body) is not found', () async {
        stubToken(buildToken());
        final client = buildClient(
          respondWith(404, {
            'event_id': eventId,
            'accepted': false,
            'message': 'No such scheduled post',
          }),
        );

        expect(await client.cancel(eventId), isA<ScheduleCancelNotFound>());
      });

      test('a bodiless gateway 404 is transient and unavailable', () async {
        stubToken(buildToken());
        final client = buildClient(respondWith(404, ''));

        expect(
          await client.cancel(eventId),
          isA<ScheduleCancelTransientFailure>().having(
            (r) => r.unavailable,
            'unavailable',
            isTrue,
          ),
        );
      });

      test('a 409 is a conflict carrying the relay message', () async {
        stubToken(buildToken());
        final client = buildClient(
          respondWith(409, {
            'event_id': eventId,
            'accepted': false,
            'message': 'Post is no longer pending; there is no un-publish.',
          }),
        );

        expect(
          await client.cancel(eventId),
          isA<ScheduleCancelConflict>().having(
            (r) => r.message,
            'message',
            startsWith('Post is no longer pending'),
          ),
        );
      });

      test('a 500 is transient', () async {
        stubToken(buildToken());
        final client = buildClient(respondWith(500, 'boom'));

        expect(
          await client.cancel(eventId),
          isA<ScheduleCancelTransientFailure>()
              .having((r) => r.reason, 'reason', 'http_500')
              .having((r) => r.unavailable, 'unavailable', isFalse),
        );
      });

      test('is transient without a NIP-98 token', () async {
        stubToken(null);
        final client = buildClient(respondWith(200, ''));

        expect(
          await client.cancel(eventId),
          isA<ScheduleCancelTransientFailure>().having(
            (r) => r.reason,
            'reason',
            'nip98_token_unavailable',
          ),
        );
      });

      test('a network error is transient', () async {
        stubToken(buildToken());
        final client = buildClient(
          MockClient((_) async => throw http.ClientException('offline')),
        );

        expect(
          await client.cancel(eventId),
          isA<ScheduleCancelTransientFailure>(),
        );
      });

      group('logs why a cancel went nowhere', () {
        String logsFor(String id) => LogCaptureService()
            .getRecentLogs()
            .map((entry) => entry.message)
            .where((message) => message.contains(id))
            .join('\n');

        test('without a NIP-98 token', () async {
          final id = '1' * 64;
          stubToken(null);

          await buildClient(respondWith(200, '')).cancel(id);

          expect(logsFor(id), contains('NIP-98'));
        });

        test('on a network error', () async {
          final id = '2' * 64;
          stubToken(buildToken());

          await buildClient(
            MockClient((_) async => throw http.ClientException('offline')),
          ).cancel(id);

          expect(logsFor(id), contains('offline'));
        });

        test('on a timeout', () {
          fakeAsync((async) {
            final id = '3' * 64;
            stubToken(buildToken());
            final client = ScheduleApiClient(
              httpClient: MockClient((_) => Future.any([])),
              nip98AuthService: mockNip98,
              apiBaseUrl: () => 'https://relay.divine.video',
              timeout: const Duration(seconds: 1),
            );

            unawaited(client.cancel(id));
            async.elapse(const Duration(seconds: 2));

            expect(logsFor(id), contains('timed out'));
          });
        });
      });
    });
  });
}
