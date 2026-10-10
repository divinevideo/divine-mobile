// ABOUTME: Exercises clock-skew recovery against a simulated NIP-98 server.
// ABOUTME: Keeps request binding, retry limits and account ownership observable.

import 'dart:async';
import 'dart:convert';

import 'package:clock/clock.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:funnelcake_api_client/funnelcake_api_client.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nostr_sdk/event.dart';
import 'package:openvine/providers/auth_providers.dart';
import 'package:openvine/providers/crossposting_providers.dart';
import 'package:openvine/providers/service_providers.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/nip98_auth_service.dart';
import 'package:openvine/services/nip98_http_client.dart';
import 'package:openvine/services/schedule_api_client.dart';
import 'package:unified_logger/unified_logger.dart';

class _MockAuthService extends Mock implements AuthService {}

const _owner =
    'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';

Map<String, dynamic> _authEvent(http.Request request) => jsonDecode(
  utf8.decode(
    base64Decode(request.headers['Authorization']!.substring(6)),
  ),
) as Map<String, dynamic>;

void main() {
  group('NIP-98 clock recovery', () {
    late _MockAuthService auth;
    late Nip98AuthService service;
    final serverTime = DateTime.utc(2026, 10, 8, 19);
    final uri = Uri.parse(
      'https://relay.example.com/api/notifications?limit=20',
    );

    setUp(() {
      auth = _MockAuthService();
      when(() => auth.isAuthenticated).thenReturn(true);
      when(() => auth.currentPublicKeyHex).thenReturn(_owner);
      when(
        () => auth.createAndSignEvent(
          kind: any(named: 'kind'),
          content: any(named: 'content'),
          tags: any(named: 'tags'),
          createdAt: any(named: 'createdAt'),
        ),
      ).thenAnswer((invocation) async {
        final tags = invocation.namedArguments[#tags] as List<List<String>>;
        return Event(
          _owner,
          27235,
          tags,
          '',
          createdAt:
              invocation.namedArguments[#createdAt] as int? ??
              clock.now().millisecondsSinceEpoch ~/ 1000,
        );
      });
      service = Nip98AuthService(
        authService: auth,
        elapsed: () => Duration.zero,
      );
    });

    tearDown(() => service.dispose());

    test(
      'a clock 30 seconds fast recovers from a future-timestamp 401',
      () async {
        await withClock(
          Clock.fixed(serverTime.add(const Duration(seconds: 30))),
          () async {
            var attempts = 0;
            final client = Nip98HttpClient(
              authService: service,
              trustedOrigin: uri,
              inner: MockClient((request) async {
                attempts++;
                final event = _authEvent(request);
                final timestamp = event['created_at'] as int;
                final serverTimestamp =
                    serverTime.millisecondsSinceEpoch ~/ 1000;
                final accepted = timestamp <= serverTimestamp + 10;
                return http.Response(
                  accepted ? '{}' : '{"error":"Auth failed: event timestamp is in the future"}',
                  accepted ? 200 : 401,
                  headers: {'date': 'Thu, 08 Oct 2026 19:00:00 GMT'},
                );
              }),
            );
            addTearDown(client.close);
            final token = await service.createAuthToken(
              url: uri.toString(),
              method: HttpMethod.get,
            );
            final response = await client.get(
              uri,
              headers: {'Authorization': token!.authorizationHeader},
            );
            expect(response.statusCode, 200);
            expect(attempts, 2);
          },
        );
      },
    );

    test('slow clocks recover and retain exact URL, method and body', () async {
      await withClock(
        Clock.fixed(serverTime.subtract(const Duration(minutes: 2))),
        () async {
          final sent = <http.Request>[];
          final client = Nip98HttpClient(
            authService: service,
            trustedOrigin: uri,
            inner: MockClient((request) async {
              sent.add(request);
              return http.Response(
                sent.length == 1
                    ? '{"message":"Auth failed: event expired (older than 60s)"}'
                    : '{}',
                sent.length == 1 ? 401 : 200,
                headers: {'date': 'Thu, 08 Oct 2026 19:00:00 GMT'},
              );
            }),
          );
          addTearDown(client.close);
          const body = '{"notification_ids":["synthetic-id"],"label":"café"}';
          final token = await service.createAuthToken(
            url: uri.toString(),
            method: HttpMethod.post,
            payload: body,
          );
          final response = await client.post(
            uri,
            headers: {
              'Authorization': token!.authorizationHeader,
              'Content-Type': 'application/json',
            },
            body: body,
          );
          expect(response.statusCode, 200);
          expect(sent, hasLength(2));
          expect(sent.last.url, uri);
          expect(sent.last.method, 'POST');
          expect(sent.last.bodyBytes, sent.first.bodyBytes);
          final event = _authEvent(sent.last);
          final tags = event['tags'] as List<dynamic>;
          expect(tags, contains(equals(['u', uri.toString()])));
          expect(tags, contains(equals(['method', 'POST'])));
          expect(
            tags,
            contains(
              equals(['payload', sha256.convert(utf8.encode(body)).toString()]),
            ),
          );
          expect(
            event['created_at'],
            serverTime.millisecondsSinceEpoch ~/ 1000,
          );
          expect(
            tags,
            contains(equals(['created_at', event['created_at'].toString()])),
          );
        },
      );
    });

    test(
      'a second timestamp rejection stops and preserves the error response',
      () async {
        var attempts = 0;
        final client = Nip98HttpClient(
          authService: service,
          trustedOrigin: uri,
          inner: MockClient((_) async {
            attempts++;
            return http.Response(
              '{"error":"Auth failed: event timestamp is in the future"}',
              401,
              headers: {
                'date': 'Thu, 08 Oct 2026 19:00:00 GMT',
                'x-test': 'preserved',
              },
            );
          }),
        );
        addTearDown(client.close);
        final token = await service.createAuthToken(
          url: uri.toString(),
          method: HttpMethod.get,
        );
        final response = await client.get(
          uri,
          headers: {'Authorization': token!.authorizationHeader},
        );
        expect(attempts, 2);
        expect(response.statusCode, 401);
        expect(response.body, contains('timestamp is in the future'));
        expect(response.headers['x-test'], 'preserved');
      },
    );

    for (final scenario in [
      (
        name: 'missing Date',
        date: null,
        age: null,
        body: '{"error":"Auth failed: event timestamp is in the future"}',
      ),
      (
        name: 'malformed Date',
        date: 'invalid',
        age: null,
        body: '{"error":"Auth failed: event timestamp is in the future"}',
      ),
      (
        name: 'cached Date',
        date: 'Thu, 08 Oct 2026 19:00:00 GMT',
        age: '30',
        body: '{"error":"Auth failed: event timestamp is in the future"}',
      ),
      (
        name: 'unrelated 401',
        date: 'Thu, 08 Oct 2026 19:00:00 GMT',
        age: null,
        body: '{"error":"Invalid signature"}',
      ),
      (
        name: 'unstructured error',
        date: 'Thu, 08 Oct 2026 19:00:00 GMT',
        age: null,
        body: 'event expired',
      ),
    ]) {
      test('${scenario.name} does not retry', () async {
        var attempts = 0;
        final client = Nip98HttpClient(
          authService: service,
          trustedOrigin: uri,
          inner: MockClient((_) async {
            attempts++;
            return http.Response(
              scenario.body,
              401,
              headers: {
                if (scenario.date != null) 'date': scenario.date!,
                if (scenario.age != null) 'age': scenario.age!,
              },
            );
          }),
        );
        addTearDown(client.close);
        final token = await service.createAuthToken(
          url: uri.toString(),
          method: HttpMethod.get,
        );
        final response = await client.get(
          uri,
          headers: {'Authorization': token!.authorizationHeader},
        );
        expect(attempts, 1);
        expect(response.statusCode, 401);
        expect(response.body, scenario.body);
      });
    }

    test('account switch during the first request cannot send a retry for the new account', () async {
      var attempts = 0;
      final client = Nip98HttpClient(
        authService: service,
        trustedOrigin: uri,
        inner: MockClient((_) async {
          attempts++;
          when(() => auth.currentPublicKeyHex).thenReturn('b' * 64);
          when(
            () => auth.createAndSignEvent(
              kind: any(named: 'kind'),
              content: any(named: 'content'),
              tags: any(named: 'tags'),
              createdAt: any(named: 'createdAt'),
            ),
          ).thenAnswer(
            (invocation) async => Event(
              'b' * 64,
              27235,
              invocation.namedArguments[#tags] as List<List<String>>,
              '',
              createdAt: invocation.namedArguments[#createdAt] as int,
            ),
          );
          return http.Response(
            '{"error":"Auth failed: event timestamp is in the future"}',
            401,
            headers: {'date': 'Thu, 08 Oct 2026 19:00:00 GMT'},
          );
        }),
      );
      addTearDown(client.close);
      final token = await service.createAuthToken(
        url: uri.toString(),
        method: HttpMethod.get,
      );
      final response = await client.get(
        uri,
        headers: {'Authorization': token!.authorizationHeader},
      );
      expect(response.statusCode, 401);
      expect(attempts, 1);
    });

    for (final target in [
      'http://relay.example.com/api',
      'https://other.example.com/api',
    ]) {
      test(
        'does not learn or retry outside the configured HTTPS origin: $target',
        () async {
          await withClock(
            Clock.fixed(serverTime.add(const Duration(seconds: 30))),
            () async {
              var attempts = 0;
              final client = Nip98HttpClient(
                authService: service,
                trustedOrigin: uri,
                inner: MockClient((_) async {
                  attempts++;
                  return http.Response(
                    '{"error":"Auth failed: event timestamp is in the future"}',
                    401,
                    headers: {'date': 'Thu, 08 Oct 2026 19:00:00 GMT'},
                  );
                }),
              );
              addTearDown(client.close);
              final token = await service.createAuthToken(
                url: target,
                method: HttpMethod.get,
              );
              await client.get(
                Uri.parse(target),
                headers: {'Authorization': token!.authorizationHeader},
              );
              final next = await service.createAuthToken(
                url: uri.toString(),
                method: HttpMethod.get,
              );
              expect(attempts, 1);
              expect(
                next!.signedEvent.createdAt,
                serverTime
                        .add(const Duration(seconds: 30))
                        .millisecondsSinceEpoch ~/
                    1000,
              );
            },
          );
        },
      );
    }

    test('a successful response primes only its own origin and invalidates older cached tokens', () async {
      await withClock(
        Clock.fixed(serverTime.add(const Duration(seconds: 90))),
        () async {
          final client = Nip98HttpClient(
            authService: service,
            trustedOrigin: uri,
            inner: MockClient(
              (_) async => http.Response(
                '{}',
                200,
                headers: {'date': 'Thu, 08 Oct 2026 19:00:00 GMT'},
              ),
            ),
          );
          addTearDown(client.close);
          final initial = await service.createAuthToken(
            url: uri.toString(),
            method: HttpMethod.get,
          );
          await client.get(
            uri,
            headers: {'Authorization': initial!.authorizationHeader},
          );
          final corrected = await service.createAuthToken(
            url: uri.toString(),
            method: HttpMethod.get,
          );
          final other = await service.createAuthToken(
            url: 'https://other.example.com/api',
            method: HttpMethod.get,
          );
          expect(
            corrected!.signedEvent.createdAt,
            serverTime.millisecondsSinceEpoch ~/ 1000,
          );
          expect(corrected.token, isNot(initial.token));
          expect(
            other!.signedEvent.createdAt,
            serverTime
                    .add(const Duration(seconds: 90))
                    .millisecondsSinceEpoch ~/
                1000,
          );
        },
      );
    });

    test(
      'signing consumes the cache budget rather than extending it',
      () async {
        var localTime = serverTime;
        await withClock(Clock(() => localTime), () async {
          service.dispose();
          service = Nip98AuthService(
            authService: auth,
            elapsed: () => localTime.difference(serverTime),
          );
          when(
            () => auth.createAndSignEvent(
              kind: any(named: 'kind'),
              content: any(named: 'content'),
              tags: any(named: 'tags'),
              createdAt: any(named: 'createdAt'),
            ),
          ).thenAnswer((invocation) async {
            localTime = localTime.add(const Duration(seconds: 20));
            return Event(
              _owner,
              27235,
              invocation.namedArguments[#tags] as List<List<String>>,
              '',
              createdAt: invocation.namedArguments[#createdAt] as int,
            );
          });
          final token = await service.createAuthToken(
            url: uri.toString(),
            method: HttpMethod.get,
          );
          expect(token!.expiresAt, serverTime.add(const Duration(seconds: 45)));
          expect(
            token.expiresAt.millisecondsSinceEpoch ~/ 1000 -
                token.signedEvent.createdAt,
            lessThan(60),
          );
          localTime = serverTime.add(const Duration(seconds: 45));
          expect(token.isExpired, isTrue);
          final next = await service.createAuthToken(
            url: uri.toString(),
            method: HttpMethod.get,
          );
          expect(
            next!.signedEvent.createdAt,
            serverTime
                    .add(const Duration(seconds: 45))
                    .millisecondsSinceEpoch ~/
                1000,
          );
        });
      },
    );

    test(
      'a signature taking the full cache budget is not sent or cached',
      () async {
        var localTime = serverTime;
        await withClock(Clock(() => localTime), () async {
          service.dispose();
          service = Nip98AuthService(
            authService: auth,
            elapsed: () => localTime.difference(serverTime),
          );
          when(
            () => auth.createAndSignEvent(
              kind: any(named: 'kind'),
              content: any(named: 'content'),
              tags: any(named: 'tags'),
              createdAt: any(named: 'createdAt'),
            ),
          ).thenAnswer((invocation) async {
            localTime = localTime.add(const Duration(seconds: 45));
            return Event(
              _owner,
              27235,
              invocation.namedArguments[#tags] as List<List<String>>,
              '',
              createdAt: invocation.namedArguments[#createdAt] as int,
            );
          });
          expect(
            await service.createAuthToken(
              url: uri.toString(),
              method: HttpMethod.get,
            ),
            isNull,
          );
          expect(service.cacheStats['total_cached'], 0);
        });
      },
    );

    test('notification fetch and mark-read both recover below the repository layer', () async {
      await withClock(Clock.fixed(serverTime.add(const Duration(seconds: 30))), () async {
        final attempts = <String, int>{};
        final transport = Nip98HttpClient(
          authService: service,
          trustedOrigin: uri,
          inner: MockClient((request) async {
            attempts.update(
              request.method,
              (value) => value + 1,
              ifAbsent: () => 1,
            );
            final timestamp = _authEvent(request)['created_at'] as int;
            final accepted =
                timestamp <= serverTime.millisecondsSinceEpoch ~/ 1000 + 10;
            return http.Response(
              accepted
                  ? (request.method == 'GET'
                        ? '{"notifications":[],"has_more":false}'
                        : '{"success":true}')
                  : '{"error":"Auth failed: event timestamp is in the future"}',
              accepted ? 200 : 401,
              headers: {'date': 'Thu, 08 Oct 2026 19:00:00 GMT'},
            );
          }),
        );
        addTearDown(transport.close);
        final api = FunnelcakeApiClient(
          baseUrl: uri.origin,
          httpClient: transport,
        );
        final getUri = api.notificationsUri(pubkey: _owner);
        final token = await service.createAuthToken(
          url: getUri.toString(),
          method: HttpMethod.get,
        );
        final notifications = await api.getNotifications(
          pubkey: _owner,
          authHeaders: {'Authorization': token!.authorizationHeader},
        );
        expect(notifications.notifications, isEmpty);
        // Simulate another clock correction before mark-read so its POST
        // exercises recovery independently of the successful GET.
        service.updateServerTime(
          uri,
          serverTime.add(const Duration(seconds: 30)),
        );
        final body = FunnelcakeApiClient.buildMarkNotificationsReadBody();
        final postToken = await service.createAuthToken(
          url: api.notificationsReadUri(pubkey: _owner).toString(),
          method: HttpMethod.post,
          payload: body,
        );
        final read = await api.markNotificationsRead(
          pubkey: _owner,
          authHeaders: {'Authorization': postToken!.authorizationHeader},
        );
        expect(read.success, isTrue);
        expect(attempts, {'GET': 2, 'POST': 2});
      });
    });

    test('schedule list recovers through its production transport', () async {
      await withClock(Clock.fixed(serverTime.add(const Duration(seconds: 30))), () async {
        var attempts = 0;
        final transport = MockClient((request) async {
          attempts++;
          final accepted =
              (_authEvent(request)['created_at'] as int) <=
              serverTime.millisecondsSinceEpoch ~/ 1000 + 10;
          return http.Response(
            accepted
                ? '{"scheduled":[]}'
                : '{"message":"Auth failed: event timestamp is in the future"}',
            accepted ? 200 : 401,
            headers: {'date': 'Thu, 08 Oct 2026 19:00:00 GMT'},
          );
        });
        addTearDown(transport.close);
        final api = ScheduleApiClient(
          httpClient: transport,
          nip98AuthService: service,
          apiBaseUrl: () => uri.origin,
        );
        expect(await api.list(), isA<ScheduleListLoaded>());
        expect(attempts, 2);
      });
    });

    test(
      'crossposting production wiring recovers without changing its owner',
      () async {
        await withClock(
          Clock.fixed(serverTime.add(const Duration(seconds: 90))),
          () async {
            var attempts = 0;
            final transport = MockClient((request) async {
              attempts++;
              final event = _authEvent(request);
              expect(event['pubkey'], _owner);
              final accepted =
                  ((event['created_at'] as int) -
                          serverTime.millisecondsSinceEpoch ~/ 1000)
                      .abs() <=
                  60;
              return http.Response(
                accepted ? '{"platforms":[]}' : '{"error":{"code":"unauthorized","message":"nostr auth event is expired or from the future"}}',
                accepted ? 200 : 401,
                headers: {'date': 'Thu, 08 Oct 2026 19:00:00 GMT'},
              );
            });
            final container = ProviderContainer(
              overrides: [
                instrumentedHttpClientFactoryProvider.overrideWithValue(
                  () => transport,
                ),
              ],
            );
            addTearDown(container.dispose);
            final api = container.read(crosspostingApiClientFactoryProvider)(
              nip98AuthService: service,
              ownerPubkey: _owner,
            );
            addTearDown(api.close);
            expect(await api.getPlatforms(), isEmpty);
            expect(attempts, 2);
          },
        );
      },
    );

    test('unsigned responses do not influence subsequent signing', () async {
      await withClock(
        Clock.fixed(serverTime.add(const Duration(seconds: 30))),
        () async {
          final client = Nip98HttpClient(
            authService: service,
            trustedOrigin: uri,
            inner: MockClient(
              (_) async => http.Response(
                '{}',
                200,
                headers: {'date': 'Thu, 08 Oct 2026 19:00:00 GMT'},
              ),
            ),
          );
          addTearDown(client.close);
          await client.get(uri);
          final token = await service.createAuthToken(
            url: uri.toString(),
            method: HttpMethod.get,
          );
          expect(
            token!.signedEvent.createdAt,
            serverTime
                    .add(const Duration(seconds: 30))
                    .millisecondsSinceEpoch ~/
                1000,
          );
        },
      );
    });

    test(
      'authenticated redirects are returned without following or learning',
      () async {
        var attempts = 0;
        final client = Nip98HttpClient(
          authService: service,
          trustedOrigin: uri,
          inner: MockClient((request) async {
            attempts++;
            expect(request.followRedirects, isFalse);
            return http.Response(
              '',
              302,
              headers: {
                'date': 'Thu, 08 Oct 2026 19:00:00 GMT',
                'location': 'https://other.example.com/',
              },
            );
          }),
        );
        addTearDown(client.close);
        final token = await service.createAuthToken(
          url: uri.toString(),
          method: HttpMethod.get,
        );
        final response = await client.get(
          uri,
          headers: {'Authorization': token!.authorizationHeader},
        );
        final next = await service.createAuthToken(
          url: uri.toString(),
          method: HttpMethod.get,
        );
        expect(attempts, 1);
        expect(response.statusCode, 302);
        expect(next, same(token));
      },
    );

    test('an exhausted request budget cannot start a retry', () async {
      var attempts = 0;
      final client = Nip98HttpClient(
        authService: service,
        trustedOrigin: uri,
        retryBudget: Duration.zero,
        inner: MockClient((_) async {
          attempts++;
          return http.Response(
            '{"error":"Auth failed: event timestamp is in the future"}',
            401,
            headers: {'date': 'Thu, 08 Oct 2026 19:00:00 GMT'},
          );
        }),
      );
      addTearDown(client.close);
      final token = await service.createAuthToken(
        url: uri.toString(),
        method: HttpMethod.get,
      );
      final response = await client.get(
        uri,
        headers: {'Authorization': token!.authorizationHeader},
      );
      expect(attempts, 1);
      expect(response.statusCode, 401);
    });

    test(
      'logout prevents a retry and preserves the original rejection',
      () async {
        var attempts = 0;
        final client = Nip98HttpClient(
          authService: service,
          trustedOrigin: uri,
          inner: MockClient((_) async {
            attempts++;
            when(() => auth.isAuthenticated).thenReturn(false);
            return http.Response(
              '{"error":"Auth failed: event timestamp is in the future"}',
              401,
              headers: {'date': 'Thu, 08 Oct 2026 19:00:00 GMT'},
            );
          }),
        );
        addTearDown(client.close);
        final token = await service.createAuthToken(
          url: uri.toString(),
          method: HttpMethod.get,
        );
        final response = await client.get(
          uri,
          headers: {'Authorization': token!.authorizationHeader},
        );
        expect(attempts, 1);
        expect(response.statusCode, 401);
      },
    );

    test('account changes invalidate cached authorizations', () async {
      final first = await service.createAuthToken(
        url: uri.toString(),
        method: HttpMethod.get,
      );
      when(() => auth.currentPublicKeyHex).thenReturn('b' * 64);
      when(
        () => auth.createAndSignEvent(
          kind: any(named: 'kind'),
          content: any(named: 'content'),
          tags: any(named: 'tags'),
          createdAt: any(named: 'createdAt'),
        ),
      ).thenAnswer(
        (invocation) async => Event(
          'b' * 64,
          27235,
          invocation.namedArguments[#tags] as List<List<String>>,
          '',
          createdAt: invocation.namedArguments[#createdAt] as int,
        ),
      );
      final second = await service.createAuthToken(
        url: uri.toString(),
        method: HttpMethod.get,
      );
      expect(second!.signedEvent.pubkey, 'b' * 64);
      expect(second.token, isNot(first!.token));
    });

    for (final skewSeconds in [30, 90]) {
      test(
        'a ${skewSeconds}s correction during signing re-signs once and caches corrected time',
        () async {
          await withClock(
            Clock.fixed(serverTime.add(Duration(seconds: skewSeconds))),
            () async {
              when(
                () => auth.createAndSignEvent(
                  kind: any(named: 'kind'),
                  content: any(named: 'content'),
                  tags: any(named: 'tags'),
                  createdAt: any(named: 'createdAt'),
                ),
              ).thenAnswer((invocation) async {
                service.updateServerTime(uri, serverTime);
                return Event(
                  _owner,
                  27235,
                  invocation.namedArguments[#tags] as List<List<String>>,
                  '',
                  createdAt: invocation.namedArguments[#createdAt] as int,
                );
              });
              final stale = await service.createAuthToken(
                url: uri.toString(),
                method: HttpMethod.get,
              );
              expect(stale, isNotNull);
              expect(
                stale!.signedEvent.createdAt,
                serverTime.millisecondsSinceEpoch ~/ 1000,
              );
              expect(service.cacheStats['total_cached'], 1);
              final corrected = await service.createAuthToken(
                url: uri.toString(),
                method: HttpMethod.get,
              );
              expect(
                corrected!.signedEvent.createdAt,
                serverTime.millisecondsSinceEpoch ~/ 1000,
              );
            },
          );
        },
      );
    }

    test(
      'overlapping requests survive the first learned server time',
      () async {
        await withClock(Clock.fixed(serverTime), () async {
          final pending = Completer<Event>();
          final signing = Completer<void>();
          var signatures = 0;
          when(
            () => auth.createAndSignEvent(
              kind: any(named: 'kind'),
              content: any(named: 'content'),
              tags: any(named: 'tags'),
              createdAt: any(named: 'createdAt'),
            ),
          ).thenAnswer((invocation) {
            signatures++;
            final event = Event(
              _owner,
              27235,
              invocation.namedArguments[#tags] as List<List<String>>,
              '',
              createdAt: invocation.namedArguments[#createdAt] as int,
            );
            if (signatures == 2) {
              signing.complete();
              return pending.future;
            }
            return Future.value(event);
          });
          final first = await service.createAuthToken(
            url: uri.toString(),
            method: HttpMethod.get,
          );
          final secondUri = uri.replace(query: 'limit=10');
          final second = service.createAuthToken(
            url: secondUri.toString(),
            method: HttpMethod.get,
          );
          await signing.future.timeout(
            const Duration(seconds: 5),
            onTimeout: () => throw StateError('Remote signing did not start'),
          );
          final client = Nip98HttpClient(
            authService: service,
            trustedOrigin: uri,
            inner: MockClient(
              (_) async => http.Response(
                '{}',
                200,
                headers: {'date': 'Thu, 08 Oct 2026 19:00:00 GMT'},
              ),
            ),
          );
          addTearDown(client.close);
          expect(
            (await client.get(
              uri,
              headers: {'Authorization': first!.authorizationHeader},
            )).statusCode,
            200,
          );
          pending.complete(
            Event(
              _owner,
              27235,
              [
                ['u', secondUri.toString()],
                ['method', 'GET'],
                [
                  'created_at',
                  (serverTime.millisecondsSinceEpoch ~/ 1000).toString(),
                ],
              ],
              '',
              createdAt: serverTime.millisecondsSinceEpoch ~/ 1000,
            ),
          );
          final result = await second.timeout(const Duration(seconds: 5));
          expect(result, isNotNull);
          expect(
            result!.signedEvent.createdAt,
            serverTime.millisecondsSinceEpoch ~/ 1000,
          );
          expect(signatures, 3);
          expect(
            await service.createAuthToken(
              url: secondUri.toString(),
              method: HttpMethod.get,
            ),
            same(result),
          );
        });
      },
    );

    test(
      'repeated corrections stop after two signatures without caching',
      () async {
        await withClock(Clock.fixed(serverTime), () async {
          var signatures = 0;
          when(
            () => auth.createAndSignEvent(
              kind: any(named: 'kind'),
              content: any(named: 'content'),
              tags: any(named: 'tags'),
              createdAt: any(named: 'createdAt'),
            ),
          ).thenAnswer((invocation) async {
            signatures++;
            service.updateServerTime(
              uri,
              serverTime.add(Duration(seconds: signatures * 10)),
            );
            return Event(
              _owner,
              27235,
              invocation.namedArguments[#tags] as List<List<String>>,
              '',
              createdAt: invocation.namedArguments[#createdAt] as int,
            );
          });
          expect(
            await service.createAuthToken(
              url: uri.toString(),
              method: HttpMethod.get,
            ),
            isNull,
          );
          expect(signatures, 2);
          expect(service.cacheStats['total_cached'], 0);
        });
      },
    );

    test(
      'a retained disposed service still signs without restarting its cache',
      () async {
        service.dispose();
        final token = await service.createAuthToken(
          url: uri.toString(),
          method: HttpMethod.get,
        );
        expect(token, isNotNull);
        expect(service.isCurrentOwner(_owner), isTrue);
        expect(service.cacheStats['total_cached'], 0);
        expect(
          await service.createAuthToken(
            url: uri.toString(),
            method: HttpMethod.get,
          ),
          isNot(same(token)),
        );
      },
    );

    test(
      'a device clock correction clears learned time for unwrapped callers',
      () async {
        var localTime = serverTime.add(const Duration(seconds: 30));
        await withClock(Clock(() => localTime), () async {
          service.updateServerTime(uri, serverTime);
          final first = await service.createAuthToken(
            url: uri.toString(),
            method: HttpMethod.get,
          );
          expect(
            first!.signedEvent.createdAt,
            serverTime.millisecondsSinceEpoch ~/ 1000,
          );
          localTime = serverTime;
          final corrected = await service.createAuthToken(
            url: uri.toString(),
            method: HttpMethod.get,
          );
          expect(
            corrected!.signedEvent.createdAt,
            serverTime.millisecondsSinceEpoch ~/ 1000,
          );
          expect(corrected, isNot(same(first)));
        });
      },
    );

    for (final learned in [false, true]) {
      test(
        'device correction during signing re-signs with learned=$learned',
        () async {
          var localTime = serverTime.add(const Duration(seconds: 30));
          await withClock(Clock(() => localTime), () async {
            if (learned) service.updateServerTime(uri, serverTime);
            final signing = Completer<void>();
            final release = Completer<void>();
            var signatures = 0;
            when(
              () => auth.createAndSignEvent(
                kind: any(named: 'kind'),
                content: any(named: 'content'),
                tags: any(named: 'tags'),
                createdAt: any(named: 'createdAt'),
              ),
            ).thenAnswer((invocation) async {
              signatures++;
              if (signatures == 1) {
                signing.complete();
                await release.future.timeout(
                  const Duration(seconds: 5),
                  onTimeout: () =>
                      throw StateError('Signature was not released'),
                );
              }
              return Event(
                _owner,
                27235,
                invocation.namedArguments[#tags] as List<List<String>>,
                '',
                createdAt: invocation.namedArguments[#createdAt] as int,
              );
            });
            final operation = service.createAuthToken(
              url: uri.toString(),
              method: HttpMethod.get,
            );
            await signing.future.timeout(
              const Duration(seconds: 5),
              onTimeout: () => throw StateError('Remote signing did not start'),
            );
            localTime = serverTime;
            release.complete();
            final token = await operation.timeout(const Duration(seconds: 5));
            expect(token, isNotNull);
            expect(
              token!.signedEvent.createdAt,
              serverTime.millisecondsSinceEpoch ~/ 1000,
            );
            expect(signatures, 2);
            expect(
              token.expiresAt.difference(localTime),
              lessThanOrEqualTo(const Duration(seconds: 45)),
            );
          });
        },
      );
    }

    test(
      'a provider-retained service signs after automatic disposal',
      () async {
        final container = ProviderContainer(
          overrides: [authServiceProvider.overrideWithValue(auth)],
        );
        addTearDown(container.dispose);
        final retained = container.read(nip98AuthServiceProvider);
        final first = await retained.createAuthToken(
          url: uri.toString(),
          method: HttpMethod.get,
        );
        expect(first, isNotNull);
        await container.pump();
        expect(retained.cacheStats['total_cached'], 0);
        final next = await retained.createAuthToken(
          url: uri.toString(),
          method: HttpMethod.get,
        );
        expect(next, isNotNull);
        expect(retained.cacheStats['total_cached'], 0);
        expect(next, isNot(same(first)));
      },
    );

    test(
      'a backward clock jump invalidates a token without learned offsets',
      () async {
        var localTime = serverTime.add(const Duration(seconds: 30));
        await withClock(Clock(() => localTime), () async {
          final first = await service.createAuthToken(
            url: uri.toString(),
            method: HttpMethod.get,
          );
          localTime = serverTime;
          final next = await service.createAuthToken(
            url: uri.toString(),
            method: HttpMethod.get,
          );
          expect(next, isNot(same(first)));
          expect(
            next!.signedEvent.createdAt,
            serverTime.millisecondsSinceEpoch ~/ 1000,
          );
        });
      },
    );

    for (final afterSigning in [false, true]) {
      test(
        'a nearly exhausted budget skips retry afterSigning=$afterSigning',
        () async {
          var elapsed = Duration.zero;
          var attempts = 0;
          final initial = await service.createAuthToken(
            url: uri.toString(),
            method: HttpMethod.get,
          );
          if (afterSigning) {
            when(
              () => auth.createAndSignEvent(
                kind: any(named: 'kind'),
                content: any(named: 'content'),
                tags: any(named: 'tags'),
                createdAt: any(named: 'createdAt'),
              ),
            ).thenAnswer((invocation) async {
              elapsed = const Duration(seconds: 14);
              return Event(
                _owner,
                27235,
                invocation.namedArguments[#tags] as List<List<String>>,
                '',
                createdAt: invocation.namedArguments[#createdAt] as int,
              );
            });
          }
          final client = Nip98HttpClient(
            authService: service,
            trustedOrigin: uri,
            elapsed: () => elapsed,
            inner: MockClient((_) async {
              attempts++;
              if (!afterSigning) elapsed = const Duration(seconds: 14);
              return http.Response(
                '{"error":"Auth failed: event timestamp is in the future"}',
                401,
                headers: {'date': 'Thu, 08 Oct 2026 19:00:00 GMT'},
              );
            }),
          );
          addTearDown(client.close);
          await LogCaptureService().clearAllLogs();
          final response = await client.get(
            uri,
            headers: {'Authorization': initial!.authorizationHeader},
          );
          expect(response.statusCode, 401);
          expect(attempts, 1);
          final logs = LogCaptureService().getRecentLogs().where(
            (entry) => entry.name == 'Nip98HttpClient',
          );
          expect(logs, hasLength(1));
          expect(logs.single.category, LogCategory.system);
          expect(
            logs.single.message,
            contains('insufficient remaining retry budget'),
          );
          expect(logs.single.message, isNot(contains(initial.token)));
        },
      );
    }

    for (final messageField in [false, true]) {
      test(
        'known timestamp message is recognized in either envelope field messageField=$messageField',
        () async {
          var attempts = 0;
          final client = Nip98HttpClient(
            authService: service,
            trustedOrigin: uri,
            inner: MockClient((_) async {
              attempts++;
              return http.Response(
                attempts == 1
                    ? jsonEncode({
                        'error': messageField
                            ? 'unauthorized'
                            : 'Auth failed: event timestamp is in the future',
                        'message': messageField
                            ? 'Auth failed: event timestamp is in the future'
                            : 'Unauthorized',
                      })
                    : '{}',
                attempts == 1 ? 401 : 200,
                headers: {'date': 'Thu, 08 Oct 2026 19:00:00 GMT'},
              );
            }),
          );
          addTearDown(client.close);
          final initial = await service.createAuthToken(
            url: uri.toString(),
            method: HttpMethod.get,
          );
          expect(
            (await client.get(
              uri,
              headers: {'Authorization': initial!.authorizationHeader},
            )).statusCode,
            200,
          );
          expect(attempts, 2);
        },
      );
    }

    test('re-signing shares its original monotonic signing budget', () async {
      var localTime = serverTime;
      await withClock(Clock(() => localTime), () async {
        var elapsed = Duration.zero;
        var signatures = 0;
        service.dispose();
        service = Nip98AuthService(authService: auth, elapsed: () => elapsed);
        when(
          () => auth.createAndSignEvent(
            kind: any(named: 'kind'),
            content: any(named: 'content'),
            tags: any(named: 'tags'),
            createdAt: any(named: 'createdAt'),
          ),
        ).thenAnswer((invocation) async {
          signatures++;
          elapsed += const Duration(seconds: 20);
          localTime = localTime.add(const Duration(seconds: 20));
          if (signatures == 1) {
            service.updateServerTime(uri, localTime);
          }
          return Event(
            _owner,
            27235,
            invocation.namedArguments[#tags] as List<List<String>>,
            '',
            createdAt: invocation.namedArguments[#createdAt] as int,
          );
        });
        final token = await service.createAuthToken(
          url: uri.toString(),
          method: HttpMethod.get,
        );
        expect(token, isNotNull);
        expect(signatures, 2);
        expect(token!.expiresAt, serverTime.add(const Duration(seconds: 45)));
      });
    });

    test(
      'an account change during re-signing cannot cache the old owner',
      () async {
        var signatures = 0;
        when(
          () => auth.createAndSignEvent(
            kind: any(named: 'kind'),
            content: any(named: 'content'),
            tags: any(named: 'tags'),
            createdAt: any(named: 'createdAt'),
          ),
        ).thenAnswer((invocation) async {
          signatures++;
          if (signatures == 1) service.updateServerTime(uri, serverTime);
          if (signatures == 2) {
            when(() => auth.currentPublicKeyHex).thenReturn('b' * 64);
          }
          return Event(
            _owner,
            27235,
            invocation.namedArguments[#tags] as List<List<String>>,
            '',
            createdAt: invocation.namedArguments[#createdAt] as int,
          );
        });
        expect(
          await service.createAuthToken(
            url: uri.toString(),
            method: HttpMethod.get,
          ),
          isNull,
        );
        expect(signatures, 2);
        expect(service.cacheStats['total_cached'], 0);
      },
    );

    test(
      'learning an origin preserves tokens cached for another origin',
      () async {
        const otherUrl = 'https://other.example.com/api';
        final other = await service.createAuthToken(
          url: otherUrl,
          method: HttpMethod.get,
        );
        await service.createAuthToken(
          url: uri.toString(),
          method: HttpMethod.get,
        );
        service.updateServerTime(uri, serverTime);
        expect(service.cacheStats['total_cached'], 1);
        expect(
          await service.createAuthToken(url: otherUrl, method: HttpMethod.get),
          same(other),
        );
      },
    );

    test(
      'learning time skips empty extra tags on cached signed events',
      () async {
        when(
          () => auth.createAndSignEvent(
            kind: any(named: 'kind'),
            content: any(named: 'content'),
            tags: any(named: 'tags'),
            createdAt: any(named: 'createdAt'),
          ),
        ).thenAnswer(
          (invocation) async => Event(
            _owner,
            27235,
            [[], ...invocation.namedArguments[#tags] as List<List<String>>],
            '',
            createdAt: invocation.namedArguments[#createdAt] as int,
          ),
        );
        expect(
          await service.createAuthToken(
            url: uri.toString(),
            method: HttpMethod.get,
          ),
          isNotNull,
        );
        expect(
          () => service.updateServerTime(uri, serverTime),
          returnsNormally,
        );
        expect(service.cacheStats['total_cached'], 0);
      },
    );

    test('closing the transport during a response prevents a retry', () async {
      var attempts = 0;
      late Nip98HttpClient client;
      client = Nip98HttpClient(
        authService: service,
        trustedOrigin: uri,
        inner: MockClient((_) async {
          attempts++;
          client.close();
          return http.Response(
            '{"error":"Auth failed: event timestamp is in the future"}',
            401,
            headers: {'date': 'Thu, 08 Oct 2026 19:00:00 GMT'},
          );
        }),
      );
      final token = await service.createAuthToken(
        url: uri.toString(),
        method: HttpMethod.get,
      );
      final response = await client.get(
        uri,
        headers: {'Authorization': token!.authorizationHeader},
      );
      expect(attempts, 1);
      expect(response.statusCode, 401);
    });
  });
}
