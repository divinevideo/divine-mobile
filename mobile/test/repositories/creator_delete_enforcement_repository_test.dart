// ABOUTME: Tests creator-delete sync, polling, and honest fallback mapping.
// ABOUTME: Covers every response class in the mobile/backend contract.

import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nostr_sdk/event.dart';
import 'package:openvine/repositories/creator_delete_enforcement_repository.dart';
import 'package:openvine/services/nip98_auth_service.dart';

import '../helpers/recording_performance_monitor.dart';

class _MockNip98AuthService extends Mock implements Nip98AuthService {}

class _MockNip98Token extends Mock implements Nip98Token {}

void main() {
  setUpAll(() => registerFallbackValue(HttpMethod.get));

  group(CreatorDeleteEnforcementRepository, () {
    late _MockNip98AuthService auth;
    late _MockNip98Token token;
    late List<Object> reports;

    setUp(() {
      auth = _MockNip98AuthService();
      token = _MockNip98Token();
      reports = [];
      when(() => token.authorizationHeader).thenReturn('Nostr signed');
      when(
        () => auth.createAuthToken(
          url: any(named: 'url'),
          method: any(named: 'method'),
          payload: any(named: 'payload'),
        ),
      ).thenAnswer((_) async => token);
    });

    CreatorDeleteEnforcementRepository build(
      FutureOr<http.Response> Function(http.Request) handler,
    ) => CreatorDeleteEnforcementRepository(
      baseUrl: 'https://moderation.example',
      httpClient: MockClient((request) async => handler(request)),
      nip98AuthService: auth,
      pollTimeout: const Duration(seconds: 1),
      delay: (_) async {},
      reportError: (error, _) => reports.add(error),
    );

    test(
      'records delayed deletion separately from request completion',
      () async {
        final monitor = RecordingPerformanceMonitor();
        final repository = CreatorDeleteEnforcementRepository(
          baseUrl: 'https://moderation.example',
          httpClient: MockClient((_) async => http.Response('missing', 404)),
          nip98AuthService: auth,
          performanceMonitor: monitor,
        );
        final result = await repository.enforce('private-kind5');
        expect(result.status, CreatorDeleteEnforcementStatus.delayed);
        final trace = monitor.traces.single;
        expect(trace.name, 'creator_delete_enforcement');
        expect(trace.attributes['outcome'], 'delayed');
        expect(trace.attributes['reason'], 'http_404');
        expect(trace.metrics['request_count'], 1);
        expect(trace.metrics['poll_count'], 0);
        expect(trace.metrics['signing_ms'], greaterThanOrEqualTo(0));
        expect(trace.metrics['http_ms'], greaterThanOrEqualTo(0));
        expect(trace.stops, 1);
        expect(trace.attributes.toString(), isNot(contains('private-kind5')));
      },
    );

    test(
      'tracks polling as part of one completed deletion operation',
      () async {
        final monitor = RecordingPerformanceMonitor();
        final repository = CreatorDeleteEnforcementRepository(
          baseUrl: 'https://moderation.example',
          httpClient: MockClient(
            (request) async => request.method == 'POST'
                ? http.Response('', 202)
                : http.Response('{"targets":[{"status":"success"}]}', 200),
          ),
          nip98AuthService: auth,
          performanceMonitor: monitor,
          delay: (_) async {},
        );
        final result = await repository.enforce('private-kind5');
        expect(result.status, CreatorDeleteEnforcementStatus.confirmed);
        final trace = monitor.traces.single;
        expect(trace.attributes['outcome'], 'confirmed');
        expect(trace.metrics['request_count'], 2);
        expect(trace.metrics['poll_count'], 1);
        expect(trace.stops, 1);
      },
    );

    test(
      'overlapping deletions retain independent terminal measurements',
      () async {
        final monitor = RecordingPerformanceMonitor();
        final firstResponse = Completer<http.Response>();
        var requests = 0;
        final repository = CreatorDeleteEnforcementRepository(
          baseUrl: 'https://moderation.example',
          httpClient: MockClient(
            (_) async => ++requests == 1
                ? firstResponse.future
                : http.Response('missing', 404),
          ),
          nip98AuthService: auth,
          performanceMonitor: monitor,
        );
        final first = repository.enforce('first-private-kind5');
        final second = repository.enforce('second-private-kind5');
        expect((await second).status, CreatorDeleteEnforcementStatus.delayed);
        expect(monitor.traces.first.stops, 0);
        firstResponse.complete(http.Response('{"status":"success"}', 200));
        expect((await first).status, CreatorDeleteEnforcementStatus.confirmed);
        expect(monitor.traces.map((trace) => trace.attributes['outcome']), [
          'confirmed',
          'delayed',
        ]);
        expect(monitor.traces.map((trace) => trace.stops), [1, 1]);
      },
    );

    test('maps synchronous success to confirmed', () async {
      final result = await build((request) {
        expect(request.bodyBytes, isEmpty);
        return http.Response('{"status":"success"}', 200);
      }).enforce('kind5');

      expect(result.status, CreatorDeleteEnforcementStatus.confirmed);
      verify(
        () => auth.createAuthToken(
          url: 'https://moderation.example/api/delete/kind5',
          method: HttpMethod.post,
          payload: '',
        ),
      ).called(1);
    });

    test(
      'posts the signed event and authenticates the exact UTF-8 body',
      () async {
        final event = Event.fromJson({
          'id': 'ab' * 32,
          'pubkey': 'cd' * 32,
          'created_at': 1757385263,
          'kind': 5,
          'tags': [
            ['e', 'ef' * 32],
          ],
          'content': 'Delete café 🌱',
          'sig': '12' * 64,
        });
        final body = jsonEncode({'event': event.toJson()});
        final result = await build((request) {
          expect(request.method, 'POST');
          expect(request.url.path, '/api/delete/${event.id}');
          expect(request.headers['content-type'], contains('application/json'));
          expect(request.bodyBytes, utf8.encode(body));
          expect(jsonDecode(request.body), {'event': event.toJson()});
          return http.Response('{"status":"success"}', 200);
        }).enforce(event.id, deletionEvent: event);

        expect(result.status, CreatorDeleteEnforcementStatus.confirmed);
        verify(
          () => auth.createAuthToken(
            url: 'https://moderation.example/api/delete/${event.id}',
            method: HttpMethod.post,
            payload: body,
          ),
        ).called(1);
      },
    );

    test(
      'signed event is sent only on POST when cleanup needs polling',
      () async {
        final event = Event.fromJson({
          'id': 'ab' * 32,
          'pubkey': 'cd' * 32,
          'created_at': 1757385263,
          'kind': 5,
          'tags': <List<String>>[],
          'content': '',
          'sig': '12' * 64,
        });
        var calls = 0;
        final result = await build((request) {
          calls++;
          if (request.method == 'POST') {
            expect(jsonDecode(request.body), {'event': event.toJson()});
            return http.Response('', 202);
          }
          expect(request.method, 'GET');
          expect(request.bodyBytes, isEmpty);
          return http.Response('{"targets":[{"status":"success"}]}', 200);
        }).enforce(event.id, deletionEvent: event);

        expect(result.status, CreatorDeleteEnforcementStatus.confirmed);
        expect(calls, 2);
        verify(
          () => auth.createAuthToken(
            url: 'https://moderation.example/api/delete-status/${event.id}',
            method: HttpMethod.get,
          ),
        ).called(1);
      },
    );

    test('disabled enforcement does not contact the production API', () async {
      var calls = 0;
      final repository = CreatorDeleteEnforcementRepository(
        baseUrl: 'https://moderation.example',
        httpClient: MockClient((_) async {
          calls++;
          return http.Response('', 500);
        }),
        nip98AuthService: auth,
        enabled: false,
      );

      final result = await repository.enforce('local-kind5');

      expect(result.status, CreatorDeleteEnforcementStatus.unavailable);
      expect(calls, 0);
    });

    test(
      'missing auth token delays cleanup without making a request',
      () async {
        var calls = 0;
        when(
          () => auth.createAuthToken(
            url: any(named: 'url'),
            method: any(named: 'method'),
            payload: any(named: 'payload'),
          ),
        ).thenAnswer((_) async => null);
        final repository = CreatorDeleteEnforcementRepository(
          baseUrl: 'https://moderation.example',
          httpClient: MockClient((_) async {
            calls++;
            return http.Response('', 200);
          }),
          nip98AuthService: auth,
        );

        final result = await repository.enforce('kind5');

        expect(result.status, CreatorDeleteEnforcementStatus.delayed);
        expect(calls, 0);
      },
    );

    test('maps synchronous terminal failure to permanent failure', () async {
      final result = await build(
        (_) => http.Response(
          '{"status":"failed","targets":[{"status":"failed:permanent:blossom_400"}]}',
          200,
        ),
      ).enforce('kind5');

      expect(result.status, CreatorDeleteEnforcementStatus.failed);
    });

    test('keeps synchronous transient target failures delayed', () async {
      final result = await build(
        (_) => http.Response(
          '{"status":"failed","targets":[{"status":"failed:transient:network"}]}',
          200,
        ),
      ).enforce('kind5');

      expect(result.status, CreatorDeleteEnforcementStatus.delayed);
    });

    test(
      'keeps mixed synchronous success and transient targets delayed',
      () async {
        final result = await build(
          (_) => http.Response(
            '{"status":"failed","targets":['
            '{"status":"success"},'
            '{"status":"failed:transient:network"}'
            ']}',
            200,
          ),
        ).enforce('kind5');

        expect(result.status, CreatorDeleteEnforcementStatus.delayed);
      },
    );

    test('reports a synchronous response with missing target states', () async {
      final result = await build(
        (_) => http.Response('{"status":"failed"}', 200),
      ).enforce('kind5');

      expect(result.status, CreatorDeleteEnforcementStatus.failed);
      expect(reports, hasLength(1));
    });

    test('reports malformed synchronous target states', () async {
      final result = await build(
        (_) => http.Response(
          '{"status":"failed","targets":[{"status":null}]}',
          200,
        ),
      ).enforce('kind5');

      expect(result.status, CreatorDeleteEnforcementStatus.failed);
      expect(reports, hasLength(1));
    });

    test('polls after 202 and confirms all targets', () async {
      var calls = 0;
      final result = await build((request) {
        calls++;
        return calls == 1
            ? http.Response('{"status":"in_progress"}', 202)
            : http.Response('{"targets":[{"status":"success"}]}', 200);
      }).enforce('kind5');

      expect(result.status, CreatorDeleteEnforcementStatus.confirmed);
      expect(calls, 2);
    });

    test('returns delayed immediately after POST 404', () async {
      var calls = 0;
      final result = await build((request) {
        calls++;
        return calls == 1
            ? http.Response('', 404)
            : http.Response('{"targets":[{"status":"success"}]}', 200);
      }).enforce('kind5');

      expect(result.status, CreatorDeleteEnforcementStatus.delayed);
      expect(calls, 1);
    });

    test('returns delayed immediately after 5xx', () async {
      final result = await build(
        (_) => http.Response('', 503),
      ).enforce('kind5');

      expect(result.status, CreatorDeleteEnforcementStatus.delayed);
    });

    test('returns delayed immediately after network failure', () async {
      final result = await build(
        (_) => throw http.ClientException('offline'),
      ).enforce('kind5');

      expect(result.status, CreatorDeleteEnforcementStatus.delayed);
    });

    test('returns delayed immediately after 429', () async {
      var calls = 0;
      final result = await build((_) {
        calls++;
        return calls < 3
            ? http.Response('', 429)
            : http.Response('{"targets":[{"status":"success"}]}', 200);
      }).enforce('kind5');

      expect(result.status, CreatorDeleteEnforcementStatus.delayed);
      expect(calls, 1);
    });

    for (final statusCode in [400, 403, 413]) {
      test('$statusCode is a reportable client-contract failure', () async {
        final result = await build(
          (_) => http.Response('', statusCode),
        ).enforce('kind5');

        expect(result.status, CreatorDeleteEnforcementStatus.failed);
        expect(reports, hasLength(1));
      });
    }

    test(
      '401 is delayed without reporting a client contract failure',
      () async {
        final result = await build(
          (_) => http.Response('', 401),
        ).enforce('kind5');

        expect(result.status, CreatorDeleteEnforcementStatus.delayed);
        expect(reports, isEmpty);
      },
    );

    test('maps a permanent target status from polling to failure', () async {
      var calls = 0;
      final result = await build((_) {
        calls++;
        return calls == 1
            ? http.Response('', 202)
            : http.Response(
                '{"targets":[{"status":"failed:permanent:blossom_400"}]}',
                200,
              );
      }).enforce('kind5');

      expect(result.status, CreatorDeleteEnforcementStatus.failed);
    });

    test('keeps accepted and transient target rows pending', () async {
      var calls = 0;
      final result = await build((_) {
        calls++;
        return calls == 1
            ? http.Response('', 202)
            : http.Response(
                '{"targets":[{"status":"failed:transient:network"}]}',
                200,
              );
      }).enforce('kind5');

      expect(result.status, CreatorDeleteEnforcementStatus.delayed);
    });

    test('treats malformed terminal JSON as reportable', () async {
      final result = await build(
        (_) => http.Response('{"unexpected":true}', 200),
      ).enforce('kind5');

      expect(result.status, CreatorDeleteEnforcementStatus.failed);
      expect(reports, hasLength(1));
    });

    test(
      'reports an unexpected client error and keeps cleanup delayed',
      () async {
        when(
          () => auth.createAuthToken(
            url: any(named: 'url'),
            method: any(named: 'method'),
            payload: any(named: 'payload'),
          ),
        ).thenThrow(StateError('signer failed'));

        final result = await build(
          (_) => http.Response('{"status":"success"}', 200),
        ).enforce('kind5');

        expect(result.status, CreatorDeleteEnforcementStatus.delayed);
        expect(reports, hasLength(1));
      },
    );

    test('bounds a non-interactive signer that never completes', () async {
      final monitor = RecordingPerformanceMonitor();
      final signer = Completer<Nip98Token?>();
      when(
        () => auth.createAuthToken(
          url: any(named: 'url'),
          method: any(named: 'method'),
          payload: any(named: 'payload'),
        ),
      ).thenAnswer((_) => signer.future);
      final repository = CreatorDeleteEnforcementRepository(
        baseUrl: 'https://moderation.example',
        httpClient: MockClient((_) async => http.Response('', 200)),
        nip98AuthService: auth,
        performanceMonitor: monitor,
        requestTimeout: const Duration(milliseconds: 10),
      );

      final result = await repository
          .enforce('kind5')
          .timeout(const Duration(milliseconds: 100));

      expect(result.status, CreatorDeleteEnforcementStatus.delayed);
      expect(monitor.traces.single.attributes['reason'], 'signing_timeout');
      expect(monitor.traces.single.metrics['http_ms'], 0);
      expect(monitor.traces.single.stops, 1);
    });

    test('does not time out a human-approved signer', () async {
      final signer = Completer<Nip98Token?>();
      when(
        () => auth.createAuthToken(
          url: any(named: 'url'),
          method: any(named: 'method'),
          payload: any(named: 'payload'),
        ),
      ).thenAnswer((_) => signer.future);
      final repository = CreatorDeleteEnforcementRepository(
        baseUrl: 'https://moderation.example',
        httpClient: MockClient(
          (_) async => http.Response('{"status":"success"}', 200),
        ),
        nip98AuthService: auth,
        requestTimeout: const Duration(milliseconds: 10),
        shouldBoundSigning: () => false,
      );

      final resultFuture = repository.enforce('kind5');
      var completed = false;
      unawaited(resultFuture.then((_) => completed = true));
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(completed, isFalse);

      signer.complete(token);
      final result = await resultFuture;
      expect(result.status, CreatorDeleteEnforcementStatus.delayed);
    });
  });
}
