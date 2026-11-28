import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:funnelcake_api_client/funnelcake_api_client.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:profile_repository/profile_repository.dart';

void main() {
  const owner =
      '79be667ef9dcbbac55a06295ce870b07029bfcdb2dce28d959f2815b16f81798';
  const candidate =
      'c6047f9441ed7d6d3045406e95c07cd85c778e4b8cef3ca7abac09b95c709ee5';
  const secondCandidate =
      'f9308a019258c31049344f85f89d5229b531c845836f99b08601f113bce036f9';
  const thirdCandidate =
      'e493dbf1c10d80f3581e4904930b1404cc6c13900ee0758474fa94abe8c4cd13';
  const otherOwner =
      '2f8bde4d1a07209355b4a7250a5c5128e88b84bddc619ab7cba8d569b240efe4';
  Map<String, Object?> suggestion(String key, {bool classic = false}) => {
    'pubkey': key,
    'profile': {'display_name': 'A creator'},
    'reason': classic ? 'classic' : 'personalized',
    'is_classic': classic,
  };

  group('FindPeopleRepository', () {
    test(
      'filters self, follows, hidden accounts and duplicate suggestions',
      () async {
        final client = FunnelcakeApiClient(
          baseUrl: 'https://example.test',
          httpClient: MockClient(
            (request) async => http.Response(
              jsonEncode({
                'suggestions': [
                  suggestion(owner),
                  suggestion(candidate),
                  suggestion(candidate),
                  suggestion(secondCandidate),
                  suggestion(thirdCandidate),
                ],
                'next_cursor': 'opaque +/?',
              }),
              200,
            ),
          ),
        );
        final repository = FindPeopleRepository(
          apiClient: client,
          accountPubkey: owner,
          currentPubkey: () => owner,
          isExcluded: (key) => key == secondCandidate || key == thirdCandidate,
          readDismissed: () => [],
          writeDismissed: (_) async {},
        );
        final page = await repository.load();
        expect(page.suggestions.map((item) => item.pubkey), [candidate]);
        expect(page.nextCursor, 'opaque +/?');
        await repository.dispose();
      },
    );

    test(
      'signer failure uses public recommendations without credentials',
      () async {
        final requests = <http.Request>[];
        final repository = FindPeopleRepository(
          apiClient: FunnelcakeApiClient(
            baseUrl: 'https://example.test',
            httpClient: MockClient((request) async {
              requests.add(request);
              return http.Response(
                jsonEncode({
                  'suggestions': [suggestion(candidate)],
                }),
                200,
              );
            }),
          ),
          accountPubkey: owner,
          currentPubkey: () => owner,
          isExcluded: (_) => false,
          readDismissed: () => [],
          writeDismissed: (_) async {},
          requestHeaders: (_) async => throw StateError('signer unavailable'),
        );
        expect((await repository.load()).suggestions.single.pubkey, candidate);
        expect(requests.single.headers.containsKey('Authorization'), isFalse);
        await repository.dispose();
      },
    );

    test(
      'hung signer falls back to public recommendations within budget',
      () async {
        final hungSigner = Completer<Map<String, String>>();
        final requests = <http.Request>[];
        final repository = FindPeopleRepository(
          apiClient: FunnelcakeApiClient(
            baseUrl: 'https://example.test',
            httpClient: MockClient((request) async {
              requests.add(request);
              return http.Response(
                jsonEncode({
                  'suggestions': [suggestion(candidate)],
                }),
                200,
              );
            }),
          ),
          accountPubkey: owner,
          currentPubkey: () => owner,
          isExcluded: (_) => false,
          readDismissed: () => [],
          writeDismissed: (_) async {},
          signerTimeout: const Duration(milliseconds: 20),
          requestHeaders: (_) => hungSigner.future,
        );
        final page = await repository.load();
        expect(page.suggestions.single.pubkey, candidate);
        expect(requests.single.headers.containsKey('Authorization'), isFalse);
        // Late error after timeout must not leak as an unhandled async error.
        hungSigner.completeError(StateError('late signer failure'));
        await Future<void>.delayed(Duration.zero);
        await repository.dispose();
      },
    );

    test(
      'unavailable signer restarts an authenticated cursor in public context',
      () async {
        final requests = <http.Request>[];
        final repository = FindPeopleRepository(
          apiClient: FunnelcakeApiClient(
            baseUrl: 'https://example.test',
            httpClient: MockClient((request) async {
              requests.add(request);
              if (request.url.queryParameters.containsKey('cursor')) {
                return http.Response(
                  '{"error":"cursor context mismatch"}',
                  400,
                );
              }
              return http.Response(
                jsonEncode({
                  'suggestions': [suggestion(candidate)],
                }),
                200,
              );
            }),
          ),
          accountPubkey: owner,
          currentPubkey: () => owner,
          isExcluded: (_) => false,
          readDismissed: () => [],
          writeDismissed: (_) async {},
          requestHeaders: (_) async => throw StateError('signer unavailable'),
        );
        final result = await repository.load(cursor: 'verified-self-cursor');
        expect(result.restarted, isTrue);
        expect(result.suggestions.single.pubkey, candidate);
        expect(requests, hasLength(2));
        expect(
          requests.first.url.queryParameters['cursor'],
          'verified-self-cursor',
        );
        expect(
          requests.last.url.queryParameters.containsKey('cursor'),
          isFalse,
        );
        expect(
          requests.every(
            (request) => !request.headers.containsKey('Authorization'),
          ),
          isTrue,
        );
        await repository.dispose();
      },
    );

    test(
      'bad fresh requests remain errors rather than infinite restarts',
      () async {
        var requests = 0;
        final repository = FindPeopleRepository(
          apiClient: FunnelcakeApiClient(
            baseUrl: 'https://example.test',
            httpClient: MockClient((_) async {
              requests++;
              return http.Response('{}', 400);
            }),
          ),
          accountPubkey: owner,
          currentPubkey: () => owner,
          isExcluded: (_) => false,
          readDismissed: () => [],
          writeDismissed: (_) async {},
        );
        await expectLater(
          repository.load(),
          throwsA(
            isA<FunnelcakeApiException>().having(
              (error) => error.statusCode,
              'statusCode',
              400,
            ),
          ),
        );
        expect(requests, 1);
        await repository.dispose();
      },
    );

    test('account retirement during signing sends no stale request', () async {
      for (final failSigning in [false, true]) {
        var current = owner;
        var requests = 0;
        final signing = Completer<Map<String, String>>();
        final started = Completer<void>();
        final repository = FindPeopleRepository(
          apiClient: FunnelcakeApiClient(
            baseUrl: 'https://example.test',
            httpClient: MockClient((_) async {
              requests++;
              return http.Response('{"suggestions": []}', 200);
            }),
          ),
          accountPubkey: owner,
          currentPubkey: () => current,
          isExcluded: (_) => false,
          readDismissed: () => [],
          writeDismissed: (_) async {},
          requestHeaders: (_) {
            started.complete();
            return signing.future;
          },
        );
        final pending = repository.load();
        await started.future;
        current = otherOwner;
        if (failSigning) {
          signing.completeError(StateError('signer retired'));
        } else {
          signing.complete({'Authorization': 'Nostr obsolete-owner'});
        }
        expect((await pending).suggestions, isEmpty);
        expect(requests, 0);
        await repository.dispose();
      }
    });

    test(
      'account retirement between transport retries does not sign again',
      () async {
        var current = owner;
        var signatures = 0;
        var requests = 0;
        final repository = FindPeopleRepository(
          apiClient: FunnelcakeApiClient(
            baseUrl: 'https://example.test',
            retryBaseDelay: Duration.zero,
            httpClient: MockClient((_) async {
              requests++;
              current = otherOwner;
              throw http.ClientException('connection interrupted');
            }),
          ),
          accountPubkey: owner,
          currentPubkey: () => current,
          isExcluded: (_) => false,
          readDismissed: () => [],
          writeDismissed: (_) async {},
          requestHeaders: (_) async {
            signatures++;
            return {'Authorization': 'Nostr current-owner'};
          },
        );
        expect((await repository.load()).suggestions, isEmpty);
        expect(signatures, 1);
        expect(requests, 1);
        await repository.dispose();
      },
    );

    test('dismissal persists and disappears from another surface', () async {
      var stored = <String>[];
      final repository = FindPeopleRepository(
        apiClient: FunnelcakeApiClient(
          baseUrl: 'https://example.test',
          httpClient: MockClient(
            (_) async => http.Response(
              jsonEncode({
                'suggestions': [suggestion(candidate)],
              }),
              200,
            ),
          ),
        ),
        accountPubkey: owner,
        currentPubkey: () => owner,
        isExcluded: (_) => false,
        readDismissed: () => stored,
        writeDismissed: (keys) async {
          stored = keys;
        },
      );
      final page = await repository.load();
      await repository.dismiss(candidate);
      expect(stored, [candidate]);
      expect(repository.filter(page.suggestions), isEmpty);
      expect((await repository.load()).suggestions, isEmpty);
      await repository.dispose();
    });

    test('ignores a response after account switch', () async {
      var current = owner;
      final response = Completer<http.Response>();
      final repository = FindPeopleRepository(
        apiClient: FunnelcakeApiClient(
          baseUrl: 'https://example.test',
          httpClient: MockClient((_) => response.future),
        ),
        accountPubkey: owner,
        currentPubkey: () => current,
        isExcluded: (_) => false,
        readDismissed: () => [],
        writeDismissed: (_) async {},
      );
      final pending = repository.load();
      current = otherOwner;
      response.complete(
        http.Response(
          jsonEncode({
            'suggestions': [suggestion(candidate)],
          }),
          200,
        ),
      );
      expect((await pending).suggestions, isEmpty);
      await repository.dispose();
    });

    test('retains cursor when a whole page was excluded', () async {
      final repository = FindPeopleRepository(
        apiClient: FunnelcakeApiClient(
          baseUrl: 'https://example.test',
          httpClient: MockClient(
            (_) async => http.Response(
              jsonEncode({
                'suggestions': [suggestion(owner)],
                'next_cursor': 'next',
              }),
              200,
            ),
          ),
        ),
        accountPubkey: owner,
        currentPubkey: () => owner,
        isExcluded: (_) => false,
        readDismissed: () => [],
        writeDismissed: (_) async {},
      );
      final page = await repository.load();
      expect(page.suggestions, isEmpty);
      expect(page.nextCursor, 'next');
      await repository.dispose();
    });
    test(
      'concurrent dismissals persist in order without losing either person',
      () async {
        var stored = <String>[];
        final firstWrite = Completer<void>();
        var writes = 0;
        final repo = FindPeopleRepository(
          apiClient: FunnelcakeApiClient(baseUrl: 'https://example.test'),
          accountPubkey: owner,
          currentPubkey: () => owner,
          isExcluded: (_) => false,
          readDismissed: () => [],
          writeDismissed: (keys) async {
            writes++;
            if (writes == 1) await firstWrite.future;
            stored = keys;
          },
        );
        final first = repo.dismiss(candidate);
        final second = repo.dismiss(secondCandidate);
        await Future<void>.delayed(Duration.zero);
        firstWrite.complete();
        await Future.wait([first, second]);
        expect(stored.toSet(), {candidate, secondCandidate});
        await repo.dispose();
      },
    );

    test(
      'a server safety refusal never returns previously fetched people',
      () async {
        var unavailable = false;
        final repo = FindPeopleRepository(
          apiClient: FunnelcakeApiClient(
            baseUrl: 'https://example.test',
            retryBaseDelay: Duration.zero,
            httpClient: MockClient(
              (_) async => unavailable
                  ? http.Response('{}', 503)
                  : http.Response(
                      jsonEncode({
                        'suggestions': [suggestion(candidate)],
                      }),
                      200,
                    ),
            ),
          ),
          accountPubkey: owner,
          currentPubkey: () => owner,
          isExcluded: (_) => false,
          readDismissed: () => [],
          writeDismissed: (_) async {},
        );
        expect((await repo.load()).suggestions.single.pubkey, candidate);
        unavailable = true;
        await expectLater(repo.load(), throwsA(anything));
        await repo.dispose();
      },
    );
    test(
      'policy refusal invalidates observers until a fresh safe read recovers',
      () async {
        var unavailable = false;
        final olderResponse = Completer<http.Response>();
        final olderRequested = Completer<void>();
        String payload() => jsonEncode({
          'suggestions': [suggestion(candidate)],
        });
        final repo = FindPeopleRepository(
          apiClient: FunnelcakeApiClient(
            baseUrl: 'https://example.test',
            httpClient: MockClient((request) async {
              if (request.url.queryParameters['cursor'] == 'older') {
                olderRequested.complete();
                return olderResponse.future;
              }
              return unavailable
                  ? http.Response('{}', 503)
                  : http.Response(payload(), 200);
            }),
          ),
          accountPubkey: owner,
          currentPubkey: () => owner,
          isExcluded: (_) => false,
          readDismissed: () => [],
          writeDismissed: (_) async {},
        );
        final availability = <bool>[];
        final subscription = repo.changes.listen((_) {
          availability.add(repo.isEligibilityAvailable);
        });
        final first = await repo.load();
        expect(first.suggestions.single.pubkey, candidate);
        final older = repo.load(cursor: 'older');
        await olderRequested.future;
        unavailable = true;
        await expectLater(
          repo.load(),
          throwsA(isA<FindPeopleUnavailableException>()),
        );
        expect(repo.filter(first.suggestions), isEmpty);
        expect(availability, [false]);
        olderResponse.complete(http.Response(payload(), 200));
        await expectLater(
          older,
          throwsA(isA<FindPeopleUnavailableException>()),
        );
        expect(repo.filter(first.suggestions), isEmpty);
        expect(availability, [false]);
        unavailable = false;
        final recovered = await repo.load();
        expect(recovered.suggestions.single.pubkey, candidate);
        expect(repo.filter(first.suggestions).single.pubkey, candidate);
        expect(availability, [false, true]);
        await subscription.cancel();
        await repo.dispose();
      },
    );

    test('an expired cursor replaces the page with fresh ranking', () async {
      final cursors = <String?>[];
      var firstPage = true;
      final repo = FindPeopleRepository(
        apiClient: FunnelcakeApiClient(
          baseUrl: 'https://example.test',
          httpClient: MockClient((request) async {
            final cursor = request.url.queryParameters['cursor'];
            cursors.add(cursor);
            if (cursor != null) {
              return http.Response('{}', 410);
            }
            final key = firstPage ? candidate : secondCandidate;
            final next = firstPage ? 'expired +/?=' : 'fresh';
            firstPage = false;
            return http.Response(
              jsonEncode({
                'suggestions': [suggestion(key)],
                'next_cursor': next,
              }),
              200,
            );
          }),
        ),
        accountPubkey: owner,
        currentPubkey: () => owner,
        isExcluded: (_) => false,
        readDismissed: () => [],
        writeDismissed: (_) async {},
      );
      final initial = await repo.load(limit: 3);
      expect(initial.suggestions.single.pubkey, candidate);
      final restarted = await repo.load(limit: 3, cursor: initial.nextCursor);
      expect(restarted.restarted, isTrue);
      expect(restarted.suggestions.single.pubkey, secondCandidate);
      expect(restarted.nextCursor, 'fresh');
      expect(cursors, [null, 'expired +/?=', null]);
      await repo.dispose();
    });

    test(
      'failed dismissal stays retryable without poisoning queued writes',
      () async {
        var writes = 0;
        var stored = <String>[];
        const otherCandidate = secondCandidate;
        final repo = FindPeopleRepository(
          apiClient: FunnelcakeApiClient(
            baseUrl: 'https://example.test',
            httpClient: MockClient(
              (_) async => http.Response(
                jsonEncode({
                  'suggestions': [
                    suggestion(candidate),
                    suggestion(otherCandidate),
                  ],
                }),
                200,
              ),
            ),
          ),
          accountPubkey: owner,
          currentPubkey: () => owner,
          isExcluded: (_) => false,
          readDismissed: () => [],
          writeDismissed: (keys) async {
            if (++writes == 1) {
              throw StateError('storage unavailable');
            }
            stored = keys;
          },
        );
        final page = await repo.load();
        final failed = expectLater(repo.dismiss(candidate), throwsStateError);
        final queued = repo.dismiss(otherCandidate);
        await Future.wait([failed, queued]);
        expect(stored, [otherCandidate]);
        expect(repo.filter(page.suggestions).single.pubkey, candidate);
        await repo.dismiss(candidate);
        expect(stored.toSet(), {candidate, otherCandidate});
        expect(repo.filter(page.suggestions), isEmpty);
        await repo.dispose();
      },
    );
  });
}
