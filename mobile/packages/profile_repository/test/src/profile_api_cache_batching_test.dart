import 'dart:async';
import 'dart:convert';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:funnelcake_api_client/funnelcake_api_client.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:models/models.dart';
import 'package:profile_repository/profile_repository.dart';

const _batchWindow = Duration(milliseconds: 10);

String _pk(int index) => index.toRadixString(16).padLeft(64, '0');

Map<String, Object?> _userJson(String pubkey, {bool eligible = true}) => {
  'pubkey': pubkey,
  'is_og_diviner': eligible,
  'has_vanish_request': false,
  'profile': {
    'name': 'Synthetic creator',
    'profile_updated': '2026-11-01T00:00:00Z',
  },
};

Map<String, Object?> _vanishedJson(String pubkey) => {
  'pubkey': pubkey,
  'has_vanish_request': true,
  'profile': null,
};

http.Response _ok(Object body) => http.Response(jsonEncode(body), 200);

bool _isBulk(http.Request request) => request.url.path == '/api/users/bulk';

/// The pubkeys a `POST /api/users/bulk` request asked for.
List<String> _bulkPubkeys(http.Request request) =>
    ((jsonDecode(request.body) as Map<String, dynamic>)['pubkeys'] as List)
        .cast<String>();

/// A cache over a mock server that records each request as `METHOD path`.
class _Fixture {
  _Fixture(
    FutureOr<http.Response> Function(http.Request request) respond, {
    Duration batchWindow = _batchWindow,
    Duration timeout = const Duration(seconds: 15),
  }) {
    httpClient = MockClient((request) async {
      requests.add('${request.method} ${request.url.path}');
      return respond(request);
    });
    cache = ProfileApiCache(
      client: FunnelcakeApiClient(
        baseUrl: 'https://profiles.example.test',
        httpClient: httpClient,
        timeout: timeout,
        retryBaseDelay: Duration.zero,
      ),
      batchWindow: batchWindow,
    );
  }

  final requests = <String>[];
  late final MockClient httpClient;
  late final ProfileApiCache cache;

  void close() {
    cache.dispose();
    httpClient.close();
  }
}

/// The outcome of a future, readable synchronously under fake time.
class _Outcome<T> {
  _Outcome(Future<T> future) {
    unawaited(
      future.then<void>(
        (value) {
          this.value = value;
          done = true;
        },
        onError: (Object e) {
          error = e;
          done = true;
        },
      ),
    );
  }

  bool done = false;
  T? value;
  Object? error;
}

Matcher _foundFor(String pubkey) => isA<UserProfileFound>().having(
  (result) => result.profile.pubkey,
  'profile.pubkey',
  pubkey,
);

void main() {
  group(ProfileApiCache, () {
    group('getProfile', () {
      test('sends a lone call as a single GET once the window ends', () {
        fakeAsync((async) {
          final pk1 = _pk(1);
          final fixture = _Fixture((_) => _ok(_userJson(pk1)));
          final outcome = _Outcome(fixture.cache.getProfile(pk1));

          async.elapse(_batchWindow - const Duration(milliseconds: 1));
          expect(fixture.requests, isEmpty);
          async.elapse(const Duration(milliseconds: 1));

          expect(fixture.requests, ['GET /api/users/$pk1']);
          expect(outcome.value, _foundFor(pk1));
          fixture.close();
        });
      });

      test('coalesces concurrent calls into one bulk request', () {
        fakeAsync((async) {
          final pk1 = _pk(1);
          final pk2 = _pk(2);
          final pk3 = _pk(3);
          final asked = <List<String>>[];
          final fixture = _Fixture((request) {
            asked.add(_bulkPubkeys(request));
            return _ok({
              'users': [
                _userJson(pk1),
                _userJson(pk2, eligible: false),
                _userJson(pk3),
              ],
            });
          });
          final outcomes = [
            for (final pubkey in [pk1, pk2, pk3])
              _Outcome(fixture.cache.getProfile(pubkey)),
          ];

          async.elapse(_batchWindow);

          expect(fixture.requests, ['POST /api/users/bulk']);
          expect(asked, [
            [pk1, pk2, pk3],
          ]);
          expect(outcomes[0].value, _foundFor(pk1));
          expect(outcomes[1].value, _foundFor(pk2));
          expect(outcomes[2].value, _foundFor(pk3));
          fixture.close();
        });
      });

      test('caches eligibility from a coalesced lookup', () {
        fakeAsync((async) {
          final pk1 = _pk(1);
          final pk2 = _pk(2);
          final fixture = _Fixture(
            (_) => _ok({
              'users': [_userJson(pk1), _userJson(pk2, eligible: false)],
            }),
          );
          for (final pubkey in [pk1, pk2]) {
            _Outcome(fixture.cache.getProfile(pubkey));
          }
          async.elapse(_batchWindow);

          final first = _Outcome(fixture.cache.isOgDiviner(pk1));
          final second = _Outcome(fixture.cache.isOgDiviner(pk2));
          async.flushMicrotasks();

          expect(first.value, isTrue);
          expect(second.value, isFalse);
          expect(fixture.requests, ['POST /api/users/bulk']);
          fixture.close();
        });
      });

      test('caches eligibility from a lone lookup', () {
        fakeAsync((async) {
          final pk1 = _pk(1);
          final fixture = _Fixture((_) => _ok(_userJson(pk1)));
          final changes = <String>[];
          final subscription = fixture.cache.eligibilityChanges.listen(
            changes.add,
          );
          _Outcome(fixture.cache.getProfile(pk1));
          async.elapse(_batchWindow);

          final eligible = _Outcome(fixture.cache.isOgDiviner(pk1));
          async.flushMicrotasks();

          expect(eligible.value, isTrue);
          expect(changes, [pk1]);
          expect(fixture.requests, ['GET /api/users/$pk1']);
          unawaited(subscription.cancel());
          fixture.close();
        });
      });

      test('answers each caller with its own row in any response order', () {
        fakeAsync((async) {
          final pk1 = _pk(1);
          final pk2 = _pk(2);
          final fixture = _Fixture(
            (_) => _ok({
              'users': [_userJson(pk2), _userJson(pk1)],
            }),
          );
          final first = _Outcome(fixture.cache.getProfile(pk1));
          final second = _Outcome(fixture.cache.getProfile(pk2));

          async.elapse(_batchWindow);

          expect(first.value, _foundFor(pk1));
          expect(second.value, _foundFor(pk2));
          fixture.close();
        });
      });

      test('shares one request for a pubkey asked for twice in a window', () {
        fakeAsync((async) {
          final pk1 = _pk(1);
          final pk2 = _pk(2);
          final asked = <List<String>>[];
          final fixture = _Fixture((request) {
            asked.add(_bulkPubkeys(request));
            return _ok({
              'users': [_userJson(pk1), _userJson(pk2)],
            });
          });
          final first = _Outcome(fixture.cache.getProfile(pk1));
          final again = _Outcome(fixture.cache.getProfile(pk1));
          _Outcome(fixture.cache.getProfile(pk2));

          async.elapse(_batchWindow);

          expect(first.value, _foundFor(pk1));
          expect(identical(again.value, first.value), isTrue);
          expect(asked, [
            [pk1, pk2],
          ]);
          fixture.close();
        });
      });

      test('asks again once a coalesced lookup has settled', () {
        fakeAsync((async) {
          final pk1 = _pk(1);
          final pk2 = _pk(2);
          final fixture = _Fixture(
            (request) => _isBulk(request)
                ? _ok({
                    'users': [_userJson(pk1), _userJson(pk2)],
                  })
                : _ok(_userJson(pk1)),
          );
          for (final pubkey in [pk1, pk2]) {
            _Outcome(fixture.cache.getProfile(pubkey));
          }
          async.elapse(_batchWindow);

          final later = _Outcome(fixture.cache.getProfile(pk1));
          async.elapse(_batchWindow);

          expect(later.value, _foundFor(pk1));
          expect(fixture.requests, [
            'POST /api/users/bulk',
            'GET /api/users/$pk1',
          ]);
          fixture.close();
        });
      });

      test('asks again once a lone lookup has settled', () {
        fakeAsync((async) {
          final pk1 = _pk(1);
          var calls = 0;
          final fixture = _Fixture(
            (_) => ++calls == 1
                ? http.Response('not found', 404)
                : _ok(_userJson(pk1)),
          );
          final first = _Outcome(fixture.cache.getProfile(pk1));
          async.elapse(_batchWindow);

          final later = _Outcome(fixture.cache.getProfile(pk1));
          async.elapse(_batchWindow);

          expect(first.done, isTrue);
          expect(first.value, isNull);
          expect(later.value, _foundFor(pk1));
          expect(fixture.requests, hasLength(2));
          fixture.close();
        });
      });

      test('chunks queued pubkeys at maxBulkBatchSize per bulk request', () {
        fakeAsync((async) {
          final bulkSizes = <int>[];
          final fixture = _Fixture((request) {
            final pubkeys = _bulkPubkeys(request);
            bulkSizes.add(pubkeys.length);
            return _ok({'users': pubkeys.map(_userJson).toList()});
          });
          final pubkeys = List.generate(105, (i) => _pk(i + 1));
          final outcomes = [
            for (final pubkey in pubkeys)
              _Outcome(fixture.cache.getProfile(pubkey)),
          ];

          async.elapse(_batchWindow);

          expect(outcomes.every((o) => o.value is UserProfileFound), isTrue);
          expect(bulkSizes, [ProfileApiCache.maxBulkBatchSize, 5]);
          fixture.close();
        });
      });

      test('asks the single endpoint for a pubkey the bulk response omits', () {
        fakeAsync((async) {
          final pk1 = _pk(1);
          final pk2 = _pk(2);
          final fixture = _Fixture(
            (request) => _isBulk(request)
                ? _ok({
                    'users': [_userJson(pk1)],
                    'missing': <String>[],
                  })
                : _ok(_vanishedJson(pk2)),
          );
          final first = _Outcome(fixture.cache.getProfile(pk1));
          final vanished = _Outcome(fixture.cache.getProfile(pk2));

          async.elapse(_batchWindow);

          expect(first.value, _foundFor(pk1));
          expect(vanished.value, isA<UserProfileVanished>());
          expect(fixture.requests, [
            'POST /api/users/bulk',
            'GET /api/users/$pk2',
          ]);
          fixture.close();
        });
      });

      test('retries each pubkey on its own when the bulk request fails', () {
        fakeAsync((async) {
          final pk1 = _pk(1);
          final pk2 = _pk(2);
          final fixture = _Fixture(
            (request) => _isBulk(request)
                ? http.Response('internal error', 500)
                : _ok(_userJson(request.url.pathSegments.last)),
          );
          final first = _Outcome(fixture.cache.getProfile(pk1));
          final second = _Outcome(fixture.cache.getProfile(pk2));

          async.elapse(_batchWindow);

          expect(first.value, _foundFor(pk1));
          expect(second.value, _foundFor(pk2));
          expect(fixture.requests.first, 'POST /api/users/bulk');
          expect(
            fixture.requests.skip(1),
            unorderedEquals(['GET /api/users/$pk1', 'GET /api/users/$pk2']),
          );
          fixture.close();
        });
      });

      test('does not retry individually after a bulk request times out', () {
        fakeAsync((async) {
          final fixture = _Fixture(
            (_) => Completer<http.Response>().future,
            timeout: const Duration(seconds: 1),
          );
          final outcomes = [
            for (final pubkey in [_pk(1), _pk(2)])
              _Outcome(fixture.cache.getProfile(pubkey)),
          ];

          async.elapse(const Duration(seconds: 2));

          for (final outcome in outcomes) {
            expect(outcome.error, isA<FunnelcakeTimeoutException>());
          }
          expect(fixture.requests, ['POST /api/users/bulk']);
          fixture.close();
        });
      });

      test('does not retry individually after a rate-limited bulk request', () {
        fakeAsync((async) {
          final fixture = _Fixture((_) => http.Response('slow down', 429));
          final outcomes = [
            for (final pubkey in [_pk(1), _pk(2)])
              _Outcome(fixture.cache.getProfile(pubkey)),
          ];

          async.elapse(_batchWindow);

          for (final outcome in outcomes) {
            expect(
              outcome.error,
              isA<FunnelcakeApiException>().having(
                (e) => e.statusCode,
                'statusCode',
                429,
              ),
            );
          }
          expect(fixture.requests, ['POST /api/users/bulk']);
          fixture.close();
        });
      });

      test("passes a lone lookup's error to its caller", () {
        fakeAsync((async) {
          final fixture = _Fixture((_) => http.Response('server error', 500));
          final outcome = _Outcome(fixture.cache.getProfile(_pk(1)));

          async.elapse(_batchWindow);

          expect(outcome.error, isA<FunnelcakeException>());
          fixture.close();
        });
      });
    });

    group('getBulkProfiles', () {
      test('answers queued callers it claims, without a second request', () {
        fakeAsync((async) {
          final pk1 = _pk(1);
          final pk2 = _pk(2);
          final fixture = _Fixture(
            (_) => _ok({
              'users': [_userJson(pk1), _userJson(pk2)],
            }),
            batchWindow: const Duration(milliseconds: 50),
          );
          final single = _Outcome(fixture.cache.getProfile(pk1));
          final bulk = _Outcome(fixture.cache.getBulkProfiles([pk1, pk2]));

          // Past the window: a queued pubkey left unclaimed would send a GET.
          async.elapse(const Duration(milliseconds: 70));

          expect(single.value, _foundFor(pk1));
          expect(bulk.value?.profiles, hasLength(2));
          expect(fixture.requests, ['POST /api/users/bulk']);
          fixture.close();
        });
      });

      test('asks the single endpoint for a claimed pubkey it omits', () {
        fakeAsync((async) {
          final pk1 = _pk(1);
          final pk2 = _pk(2);
          final fixture = _Fixture(
            (request) => _isBulk(request)
                ? _ok({
                    'users': [_userJson(pk1)],
                  })
                : _ok(_vanishedJson(pk2)),
            batchWindow: const Duration(milliseconds: 50),
          );
          final single = _Outcome(fixture.cache.getProfile(pk2));
          final bulk = _Outcome(fixture.cache.getBulkProfiles([pk1, pk2]));

          async.elapse(Duration.zero);

          expect(bulk.value?.profiles.keys, [pk1]);
          expect(single.value, isA<UserProfileVanished>());
          expect(fixture.requests, [
            'POST /api/users/bulk',
            'GET /api/users/$pk2',
          ]);
          fixture.close();
        });
      });

      test('a claimed caller retries on its own when the request fails', () {
        fakeAsync((async) {
          final pk1 = _pk(1);
          final pk2 = _pk(2);
          final fixture = _Fixture(
            (request) => _isBulk(request)
                ? http.Response('internal error', 500)
                : _ok(_userJson(pk1)),
            batchWindow: const Duration(milliseconds: 50),
          );
          final single = _Outcome(fixture.cache.getProfile(pk1));
          final bulk = _Outcome(fixture.cache.getBulkProfiles([pk1, pk2]));

          async.elapse(Duration.zero);

          expect(bulk.error, isA<FunnelcakeApiException>());
          expect(single.value, _foundFor(pk1));
          expect(fixture.requests, [
            'POST /api/users/bulk',
            'GET /api/users/$pk1',
          ]);
          fixture.close();
        });
      });

      test("passes the retry's error to a claimed caller when it fails", () {
        fakeAsync((async) {
          final fixture = _Fixture(
            (_) => http.Response('server error', 500),
            batchWindow: const Duration(milliseconds: 50),
          );
          final single = _Outcome(fixture.cache.getProfile(_pk(1)));
          final bulk = _Outcome(
            fixture.cache.getBulkProfiles([_pk(1), _pk(2)]),
          );

          async.elapse(Duration.zero);

          expect(bulk.error, isA<FunnelcakeException>());
          expect(single.error, isA<FunnelcakeException>());
          fixture.close();
        });
      });
    });

    group('dispose', () {
      test(
        'cancels the batch timer and completes queued callers with null',
        () {
          fakeAsync((async) {
            final fixture = _Fixture((_) => _ok(_userJson(_pk(1))));
            final outcome = _Outcome(fixture.cache.getProfile(_pk(1)));
            expect(async.pendingTimers, hasLength(1));

            fixture.cache.dispose();
            expect(async.pendingTimers, isEmpty);
            async.flushMicrotasks();

            expect(outcome.done, isTrue);
            expect(outcome.value, isNull);
            async.elapse(const Duration(milliseconds: 100));
            expect(fixture.requests, isEmpty);
            fixture.httpClient.close();
          });
        },
      );
    });
  });
}
