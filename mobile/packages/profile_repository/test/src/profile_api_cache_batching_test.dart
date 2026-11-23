import 'dart:async';
import 'dart:convert';

import 'package:fake_async/fake_async.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:funnelcake_api_client/funnelcake_api_client.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:models/models.dart';
import 'package:profile_repository/profile_repository.dart';

String _pk(int index) => index.toRadixString(16).padLeft(64, '0');

Map<String, Object?> _userJson(String pubkey, {bool eligible = true}) => {
  'pubkey': pubkey,
  'is_og_diviner': eligible,
  'has_vanish_request': false,
  'profile': {
    'name': 'User ${pubkey.substring(pubkey.length - 4)}',
    'profile_updated': '2026-11-01T00:00:00Z',
  },
};

void main() {
  group('ProfileApiCache micro-batching', () {
    test(
      'coalesces concurrent getProfile calls into one POST /api/users/bulk',
      () async {
        final requests = <http.Request>[];
        final pk1 = _pk(1);
        final pk2 = _pk(2);
        final pk3 = _pk(3);

        final httpClient = MockClient((request) async {
          requests.add(request);
          expect(request.method, 'POST');
          expect(request.url.path, '/api/users/bulk');
          return http.Response(
            jsonEncode({
              'users': [
                _userJson(pk1),
                _userJson(pk2, eligible: false),
                _userJson(pk3),
              ],
            }),
            200,
          );
        });
        addTearDown(httpClient.close);

        final api = FunnelcakeApiClient(
          baseUrl: 'https://profiles.example.test',
          httpClient: httpClient,
          retryBaseDelay: Duration.zero,
        );
        final cache = ProfileApiCache(
          client: api,
          batchWindow: const Duration(milliseconds: 10),
        );
        addTearDown(cache.dispose);

        final results = await Future.wait([
          cache.getProfile(pk1),
          cache.getProfile(pk2),
          cache.getProfile(pk3),
        ]);

        expect(requests, hasLength(1));
        expect(results[0], isA<UserProfileFound>());
        expect(results[1], isA<UserProfileFound>());
        expect(results[2], isA<UserProfileFound>());
        expect(await cache.isOgDiviner(pk1), isTrue);
        expect(await cache.isOgDiviner(pk2), isFalse);
        expect(await cache.isOgDiviner(pk3), isTrue);
        expect(requests, hasLength(1));
      },
    );

    test(
      'uses GET /api/users/<pubkey> when only one pubkey is queued',
      () async {
        final requests = <http.Request>[];
        final pk1 = _pk(1);

        final httpClient = MockClient((request) async {
          requests.add(request);
          return http.Response(jsonEncode(_userJson(pk1)), 200);
        });
        addTearDown(httpClient.close);

        final api = FunnelcakeApiClient(
          baseUrl: 'https://profiles.example.test',
          httpClient: httpClient,
          retryBaseDelay: Duration.zero,
        );
        final cache = ProfileApiCache(
          client: api,
          batchWindow: const Duration(milliseconds: 10),
        );
        addTearDown(cache.dispose);

        final result = await cache.getProfile(pk1);
        expect(result, isA<UserProfileFound>());
        expect(requests, hasLength(1));
        expect(requests.single.method, 'GET');
        expect(requests.single.url.path, '/api/users/$pk1');
      },
    );

    test(
      'chunks queued pubkeys at maxBulkBatchSize (100) per bulk request',
      () async {
        final bulkBatchSizes = <int>[];
        final httpClient = MockClient((request) async {
          expect(request.method, 'POST');
          expect(request.url.path, '/api/users/bulk');
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          final keys = (body['pubkeys'] as List).cast<String>();
          bulkBatchSizes.add(keys.length);
          return http.Response(
            jsonEncode({'users': keys.map(_userJson).toList()}),
            200,
          );
        });
        addTearDown(httpClient.close);

        final api = FunnelcakeApiClient(
          baseUrl: 'https://profiles.example.test',
          httpClient: httpClient,
          retryBaseDelay: Duration.zero,
        );
        final cache = ProfileApiCache(
          client: api,
          batchWindow: const Duration(milliseconds: 10),
        );
        addTearDown(cache.dispose);

        final pubkeys = List.generate(105, (i) => _pk(i + 1));
        final results = await Future.wait(pubkeys.map(cache.getProfile));

        expect(results, hasLength(105));
        expect(results.every((r) => r is UserProfileFound), isTrue);
        expect(bulkBatchSizes, equals([100, 5]));
      },
    );

    test(
      'falls back to individual GETs when POST /api/users/bulk fails',
      () async {
        final requests = <http.Request>[];
        final pk1 = _pk(1);
        final pk2 = _pk(2);

        final httpClient = MockClient((request) async {
          requests.add(request);
          if (request.url.path == '/api/users/bulk') {
            return http.Response('internal error', 500);
          }
          final pubkey = request.url.pathSegments.last;
          return http.Response(jsonEncode(_userJson(pubkey)), 200);
        });
        addTearDown(httpClient.close);

        final api = FunnelcakeApiClient(
          baseUrl: 'https://profiles.example.test',
          httpClient: httpClient,
          retryBaseDelay: Duration.zero,
        );
        final cache = ProfileApiCache(
          client: api,
          batchWindow: const Duration(milliseconds: 10),
        );
        addTearDown(cache.dispose);

        final results = await Future.wait([
          cache.getProfile(pk1),
          cache.getProfile(pk2),
        ]);

        expect(results[0], isA<UserProfileFound>());
        expect(results[1], isA<UserProfileFound>());
        expect(
          requests.where((r) => r.url.path == '/api/users/bulk'),
          isNotEmpty,
        );
        expect(
          requests.where((r) => r.method == 'GET').map((r) => r.url.path),
          containsAll(['/api/users/$pk1', '/api/users/$pk2']),
        );
      },
    );

    test(
      'explicit getBulkProfiles claims queued pubkeys without duplicate calls',
      () async {
        final requests = <http.Request>[];
        final pk1 = _pk(1);
        final pk2 = _pk(2);

        final httpClient = MockClient((request) async {
          requests.add(request);
          return http.Response(
            jsonEncode({
              'users': [_userJson(pk1), _userJson(pk2)],
            }),
            200,
          );
        });
        addTearDown(httpClient.close);

        final api = FunnelcakeApiClient(
          baseUrl: 'https://profiles.example.test',
          httpClient: httpClient,
          retryBaseDelay: Duration.zero,
        );
        final cache = ProfileApiCache(
          client: api,
          batchWindow: const Duration(milliseconds: 50),
        );
        addTearDown(cache.dispose);

        final singleFuture = cache.getProfile(pk1);
        final bulkFuture = cache.getBulkProfiles([pk1, pk2]);

        final single = await singleFuture;
        final bulk = await bulkFuture;
        // Let the batch window elapse to prove no duplicate GET fires.
        await Future<void>.delayed(const Duration(milliseconds: 70));

        expect(single, isA<UserProfileFound>());
        expect(bulk?.profiles, hasLength(2));
        expect(requests, hasLength(1));
        expect(requests.single.url.path, '/api/users/bulk');
      },
    );

    test(
      'asks GET /api/users/<pubkey> for a pubkey the bulk response omits',
      () async {
        final requests = <String>[];
        final pk1 = _pk(1);
        final pk2 = _pk(2);
        final httpClient = MockClient((request) async {
          requests.add('${request.method} ${request.url.path}');
          if (request.url.path == '/api/users/bulk') {
            return http.Response(
              jsonEncode({
                'users': [_userJson(pk1)],
                'missing': <String>[],
              }),
              200,
            );
          }
          return http.Response(
            jsonEncode({
              'pubkey': pk2,
              'has_vanish_request': true,
              'profile': null,
            }),
            200,
          );
        });
        addTearDown(httpClient.close);
        final cache = ProfileApiCache(
          client: FunnelcakeApiClient(
            baseUrl: 'https://profiles.example.test',
            httpClient: httpClient,
            retryBaseDelay: Duration.zero,
          ),
          batchWindow: const Duration(milliseconds: 10),
        );
        addTearDown(cache.dispose);

        final results = await Future.wait([
          cache.getProfile(pk1),
          cache.getProfile(pk2),
        ]);

        expect(results[0], isA<UserProfileFound>());
        expect(results[1], isA<UserProfileVanished>());
        expect(requests, ['POST /api/users/bulk', 'GET /api/users/$pk2']);
      },
    );

    test(
      'asks GET for a claimed queued pubkey the bulk response omits',
      () async {
        final requests = <String>[];
        final pk1 = _pk(1);
        final pk2 = _pk(2);
        final httpClient = MockClient((request) async {
          requests.add('${request.method} ${request.url.path}');
          if (request.url.path == '/api/users/bulk') {
            return http.Response(
              jsonEncode({
                'users': [_userJson(pk1)],
              }),
              200,
            );
          }
          return http.Response(
            jsonEncode({
              'pubkey': pk2,
              'has_vanish_request': true,
              'profile': null,
            }),
            200,
          );
        });
        addTearDown(httpClient.close);
        final cache = ProfileApiCache(
          client: FunnelcakeApiClient(
            baseUrl: 'https://profiles.example.test',
            httpClient: httpClient,
            retryBaseDelay: Duration.zero,
          ),
          batchWindow: const Duration(milliseconds: 50),
        );
        addTearDown(cache.dispose);

        final single = cache.getProfile(pk2);
        final bulk = await cache.getBulkProfiles([pk1, pk2]);

        expect(bulk?.profiles.keys, [pk1]);
        expect(await single, isA<UserProfileVanished>());
        expect(requests, ['POST /api/users/bulk', 'GET /api/users/$pk2']);
      },
    );

    test('does not retry individually after a bulk request times out', () {
      fakeAsync((async) {
        final requests = <String>[];
        final httpClient = MockClient((request) {
          requests.add('${request.method} ${request.url.path}');
          return Completer<http.Response>().future;
        });
        final cache = ProfileApiCache(
          client: FunnelcakeApiClient(
            baseUrl: 'https://profiles.example.test',
            httpClient: httpClient,
            timeout: const Duration(seconds: 1),
            retryBaseDelay: Duration.zero,
          ),
          batchWindow: const Duration(milliseconds: 10),
        );
        final errors = <Object>[];
        for (final pubkey in [_pk(1), _pk(2)]) {
          unawaited(
            cache.getProfile(pubkey).then<void>((_) {}, onError: errors.add),
          );
        }

        async.elapse(const Duration(seconds: 2));

        expect(errors, hasLength(2));
        expect(errors, everyElement(isA<FunnelcakeTimeoutException>()));
        expect(requests, ['POST /api/users/bulk']);
        cache.dispose();
        httpClient.close();
      });
    });

    test('does not retry individually after a rate-limited bulk request', () {
      fakeAsync((async) {
        final requests = <String>[];
        final httpClient = MockClient((request) async {
          requests.add('${request.method} ${request.url.path}');
          return http.Response('slow down', 429);
        });
        final cache = ProfileApiCache(
          client: FunnelcakeApiClient(
            baseUrl: 'https://profiles.example.test',
            httpClient: httpClient,
            retryBaseDelay: Duration.zero,
          ),
          batchWindow: const Duration(milliseconds: 10),
        );
        final errors = <Object>[];
        for (final pubkey in [_pk(1), _pk(2)]) {
          unawaited(
            cache.getProfile(pubkey).then<void>((_) {}, onError: errors.add),
          );
        }

        async.elapse(const Duration(milliseconds: 10));

        expect(errors, hasLength(2));
        expect(
          errors,
          everyElement(
            isA<FunnelcakeApiException>().having(
              (e) => e.statusCode,
              'statusCode',
              429,
            ),
          ),
        );
        expect(requests, ['POST /api/users/bulk']);
        cache.dispose();
        httpClient.close();
      });
    });

    test(
      'a claimed caller retries individually when the explicit request fails',
      () async {
        final requests = <String>[];
        final pk1 = _pk(1);
        final pk2 = _pk(2);
        final httpClient = MockClient((request) async {
          requests.add('${request.method} ${request.url.path}');
          if (request.url.path == '/api/users/bulk') {
            return http.Response('internal error', 500);
          }
          return http.Response(jsonEncode(_userJson(pk1)), 200);
        });
        addTearDown(httpClient.close);
        final cache = ProfileApiCache(
          client: FunnelcakeApiClient(
            baseUrl: 'https://profiles.example.test',
            httpClient: httpClient,
            retryBaseDelay: Duration.zero,
          ),
          batchWindow: const Duration(milliseconds: 50),
        );
        addTearDown(cache.dispose);

        final single = cache.getProfile(pk1);
        await expectLater(
          cache.getBulkProfiles([pk1, pk2]),
          throwsA(isA<FunnelcakeApiException>()),
        );

        expect(await single, isA<UserProfileFound>());
        expect(requests, ['POST /api/users/bulk', 'GET /api/users/$pk1']);
      },
    );

    test(
      'dispose cancels batch timer and completes queued callers with null',
      () async {
        var requestCount = 0;
        final httpClient = MockClient((request) async {
          requestCount++;
          return http.Response(jsonEncode(_userJson(_pk(1))), 200);
        });
        addTearDown(httpClient.close);

        final api = FunnelcakeApiClient(
          baseUrl: 'https://profiles.example.test',
          httpClient: httpClient,
          retryBaseDelay: Duration.zero,
        );
        final cache = ProfileApiCache(
          client: api,
          batchWindow: const Duration(milliseconds: 50),
        );

        final future = cache.getProfile(_pk(1));
        cache.dispose();

        expect(await future, isNull);
        await Future<void>.delayed(const Duration(milliseconds: 70));
        expect(requestCount, 0);
      },
    );

    test(
      'propagates errors from queued single GET lookups to awaiting callers',
      () async {
        final pk1 = _pk(1);
        final httpClient = MockClient((request) async {
          return http.Response('server error', 500);
        });
        addTearDown(httpClient.close);

        final api = FunnelcakeApiClient(
          baseUrl: 'https://profiles.example.test',
          httpClient: httpClient,
          retryBaseDelay: Duration.zero,
        );
        final cache = ProfileApiCache(
          client: api,
          batchWindow: const Duration(milliseconds: 10),
        );
        addTearDown(cache.dispose);

        await expectLater(
          cache.getProfile(pk1),
          throwsA(isA<FunnelcakeException>()),
        );
      },
    );

    test(
      'propagates errors to queued callers claimed by explicit getBulkProfiles',
      () async {
        final pk1 = _pk(1);
        final pk2 = _pk(2);
        final httpClient = MockClient((request) async {
          return http.Response('server error', 500);
        });
        addTearDown(httpClient.close);

        final api = FunnelcakeApiClient(
          baseUrl: 'https://profiles.example.test',
          httpClient: httpClient,
          retryBaseDelay: Duration.zero,
        );
        final cache = ProfileApiCache(
          client: api,
          batchWindow: const Duration(milliseconds: 50),
        );
        addTearDown(cache.dispose);

        final singleFuture = cache.getProfile(pk1);
        final bulkFuture = cache.getBulkProfiles([pk1, pk2]);

        await expectLater(
          Future.wait<Object?>([
            expectLater(singleFuture, throwsA(isA<FunnelcakeException>())),
            expectLater(bulkFuture, throwsA(isA<FunnelcakeException>())),
          ]),
          completes,
        );
      },
    );
  });
}
