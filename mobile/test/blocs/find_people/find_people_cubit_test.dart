import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:follow_repository/follow_repository.dart';
import 'package:funnelcake_api_client/funnelcake_api_client.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/blocs/find_people/find_people_cubit.dart';
import 'package:profile_repository/profile_repository.dart';

class _FollowRepository extends Mock implements FollowRepository {}

void main() {
  final owner = 'a' * 64;
  final candidate = 'b' * 64;
  final follows = _FollowRepository();
  FindPeopleRepository repository(
    Future<http.Response> Function(http.Request) handler,
  ) => FindPeopleRepository(
    apiClient: FunnelcakeApiClient(
      baseUrl: 'https://example.test',
      retryBaseDelay: Duration.zero,
      httpClient: MockClient(handler),
    ),
    accountPubkey: owner,
    currentPubkey: () => owner,
    isExcluded: (_) => false,
    readDismissed: () => [],
    writeDismissed: (_) async {},
  );
  String payload({String? cursor}) => jsonEncode({
    'suggestions': [
      {
        'pubkey': candidate,
        'profile': {'name': 'Creator'},
        'reason': 'personalized',
        'is_classic': false,
      },
    ],
    'next_cursor': cursor,
  });

  group('FindPeopleCubit', () {
    test('a failed follow keeps the person and allows retry', () async {
      final repo = repository((_) async => http.Response(payload(), 200));
      final cubit = FindPeopleCubit(
        repository: repo,
        followRepository: follows,
      );
      await cubit.load();
      when(() => follows.followWithResult(candidate))
          .thenThrow(StateError('offline'));
      await cubit.follow(cubit.state.suggestions.single);
      expect(cubit.state.suggestions.single.pubkey, candidate);
      expect(cubit.state.actionFailed, isTrue);
      expect(cubit.state.pendingPubkeys, isEmpty);
      when(() => follows.followWithResult(candidate))
          .thenAnswer((_) async => FollowOutcome.published);
      await cubit.follow(cubit.state.suggestions.single);
      expect(cubit.state.suggestions, isEmpty);
      expect(cubit.state.actionFailed, isFalse);
      await cubit.close();
      await repo.dispose();
    });
    test('load more failure retains people and retry cursor', () async {
      final repo = repository(
        (request) async => request.url.queryParameters.containsKey('cursor')
            ? http.Response('{}', 404)
            : http.Response(payload(cursor: 'next'), 200),
      );
      final cubit = FindPeopleCubit(
        repository: repo,
        followRepository: follows,
      );
      await cubit.load();
      await cubit.loadMore();
      expect(cubit.state.suggestions.single.pubkey, candidate);
      expect(cubit.state.nextCursor, 'next');
      expect(cubit.state.status, FindPeopleStatus.failure);
      await cubit.close();
      await repo.dispose();
    });
    test('dismissal updates every subscribed surface', () async {
      final repo = repository((_) async => http.Response(payload(), 200));
      final first = FindPeopleCubit(
        repository: repo,
        followRepository: follows,
      );
      final second = FindPeopleCubit(
        repository: repo,
        followRepository: follows,
      );
      await first.load();
      await second.load();
      await first.dismiss(first.state.suggestions.single);
      expect(first.state.suggestions, isEmpty);
      expect(second.state.suggestions, isEmpty);
      await first.close();
      await second.close();
      await repo.dispose();
    });
    test('closing a cubit ignores a pending response', () async {
      final response = Completer<http.Response>();
      final repo = repository((_) => response.future);
      final cubit = FindPeopleCubit(
        repository: repo,
        followRepository: follows,
      );
      final pending = cubit.load();
      await cubit.close();
      response.complete(http.Response(payload(), 200));
      await pending;
      expect(cubit.state.suggestions, isEmpty);
      await repo.dispose();
    });
    test(
      'an expired cursor restarts discovery without appending stale people',
      () async {
        var firstPage = true;
        final repo = repository((request) async {
          if (request.url.queryParameters.containsKey('cursor')) {
            return http.Response('{}', 410);
          }
          if (firstPage) {
            firstPage = false;
            return http.Response(payload(cursor: 'expired'), 200);
          }
          return http.Response(
            jsonEncode({
              'suggestions': [
                {
                  'pubkey': 'c' * 64,
                  'profile': {'name': 'Fresh creator'},
                  'reason': 'popular',
                  'is_classic': false,
                },
              ],
            }),
            200,
          );
        });
        final cubit = FindPeopleCubit(
          repository: repo,
          followRepository: follows,
        );
        await cubit.load();
        await cubit.loadMore();
        expect(cubit.state.suggestions.map((item) => item.pubkey), ['c' * 64]);
        expect(cubit.state.nextCursor, isNull);
        expect(cubit.state.status, FindPeopleStatus.success);
        await cubit.close();
        await repo.dispose();
      },
    );

    test('a new block between render and tap prevents following', () async {
      var blocked = false;
      final repo = FindPeopleRepository(
        apiClient: FunnelcakeApiClient(
          baseUrl: 'https://example.test',
          httpClient: MockClient((_) async => http.Response(payload(), 200)),
        ),
        accountPubkey: owner,
        currentPubkey: () => owner,
        isExcluded: (_) => blocked,
        readDismissed: () => [],
        writeDismissed: (_) async {},
      );
      final cubit = FindPeopleCubit(
        repository: repo,
        followRepository: follows,
      );
      await cubit.load();
      final row = cubit.state.suggestions.single;
      blocked = true;
      when(() => follows.followWithResult(candidate))
          .thenAnswer((_) async => FollowOutcome.published);
      expect(await cubit.follow(row), isNull);
      expect(cubit.state.suggestions, isEmpty);
      await cubit.close();
      await repo.dispose();
    });
    test(
      'a server safety refusal removes previously rendered people',
      () async {
        var unavailable = false;
        final repo = repository(
          (_) async => unavailable
              ? http.Response('{}', 503)
              : http.Response(payload(), 200),
        );
        final cubit = FindPeopleCubit(
          repository: repo,
          followRepository: follows,
        );
        await cubit.load();
        expect(cubit.state.suggestions, hasLength(1));
        unavailable = true;
        await cubit.load();
        expect(cubit.state.suggestions, isEmpty);
        expect(cubit.state.status, FindPeopleStatus.failure);
        await cubit.close();
        await repo.dispose();
      },
    );
    test(
      'load more preserves an optimistic follow that later rolls back',
      () async {
        final following = <String>{};
        final publication = Completer<FollowOutcome>();
        late final FindPeopleRepository repo;
        repo = FindPeopleRepository(
          apiClient: FunnelcakeApiClient(
            baseUrl: 'https://example.test',
            httpClient: MockClient(
              (request) async => http.Response(
                request.url.queryParameters.containsKey('cursor')
                    ? jsonEncode({
                        'suggestions': [
                          {
                            'pubkey': 'c' * 64,
                            'profile': {'name': 'Next creator'},
                            'reason': 'popular',
                            'is_classic': false,
                          },
                        ],
                      })
                    : payload(cursor: 'next'),
                200,
              ),
            ),
          ),
          accountPubkey: owner,
          currentPubkey: () => owner,
          isExcluded: (_) => false,
          isFollowing: following.contains,
          readDismissed: () => [],
          writeDismissed: (_) async {},
        );
        final cubit = FindPeopleCubit(
          repository: repo,
          followRepository: follows,
        );
        await cubit.load();
        final row = cubit.state.suggestions.single;
        when(() => follows.followWithResult(candidate)).thenAnswer((_) async {
          following.add(candidate);
          repo.notifyExclusionsChanged();
          try {
            return await publication.future;
          } catch (_) {
            following.remove(candidate);
            repo.notifyExclusionsChanged();
            rethrow;
          }
        });
        final pendingFollow = cubit.follow(row);
        await cubit.loadMore();
        final duringPublication = cubit.state.suggestions
            .map((item) => item.pubkey)
            .toList();
        publication.completeError(StateError('publication failed'));
        await pendingFollow;
        expect(duringPublication, [candidate, 'c' * 64]);
        expect(cubit.state.suggestions.map((item) => item.pubkey), [
          candidate,
          'c' * 64,
        ]);
        expect(cubit.state.pendingPubkeys, isEmpty);
        expect(cubit.state.actionFailed, isTrue);
        when(() => follows.followWithResult(candidate))
            .thenAnswer((_) async => FollowOutcome.published);
        expect(await cubit.follow(row), FollowOutcome.published);
        await cubit.close();
        await repo.dispose();
      },
    );

    test('a policy block removes a pending follow even while paging', () async {
      final following = <String>{};
      var blocked = false;
      final publication = Completer<FollowOutcome>();
      late final FindPeopleRepository repo;
      repo = FindPeopleRepository(
        apiClient: FunnelcakeApiClient(
          baseUrl: 'https://example.test',
          httpClient: MockClient(
            (request) async => http.Response(
              request.url.queryParameters.containsKey('cursor')
                  ? jsonEncode({'suggestions': []})
                  : payload(cursor: 'next'),
              200,
            ),
          ),
        ),
        accountPubkey: owner,
        currentPubkey: () => owner,
        isExcluded: (_) => blocked,
        isFollowing: following.contains,
        readDismissed: () => [],
        writeDismissed: (_) async {},
      );
      final cubit = FindPeopleCubit(
        repository: repo,
        followRepository: follows,
      );
      await cubit.load();
      final row = cubit.state.suggestions.single;
      when(() => follows.followWithResult(candidate)).thenAnswer((_) async {
        following.add(candidate);
        repo.notifyExclusionsChanged();
        try {
          return await publication.future;
        } catch (_) {
          following.remove(candidate);
          repo.notifyExclusionsChanged();
          rethrow;
        }
      });
      final pendingFollow = cubit.follow(row);
      blocked = true;
      repo.notifyExclusionsChanged();
      final afterBlock = cubit.state.suggestions.toList();
      await cubit.loadMore();
      publication.completeError(StateError('publication failed'));
      await pendingFollow;
      expect(afterBlock, isEmpty);
      expect(cubit.state.suggestions, isEmpty);
      await cubit.close();
      await repo.dispose();
    });

    test(
      '503 invalidates every surface and fences an older successful response',
      () async {
        final olderResponse = Completer<http.Response>();
        final olderRequested = Completer<void>();
        var refuse = false;
        var persisted = <String>[];
        final repo = FindPeopleRepository(
          apiClient: FunnelcakeApiClient(
            baseUrl: 'https://example.test',
            retryBaseDelay: Duration.zero,
            httpClient: MockClient((request) async {
              if (request.url.queryParameters.containsKey('cursor')) {
                olderRequested.complete();
                return olderResponse.future;
              }
              return refuse
                  ? http.Response('{}', 503)
                  : http.Response(payload(cursor: 'next'), 200);
            }),
          ),
          accountPubkey: owner,
          currentPubkey: () => owner,
          isExcluded: (_) => false,
          readDismissed: () => [],
          writeDismissed: (keys) async {
            persisted = keys;
          },
        );
        final first = FindPeopleCubit(
          repository: repo,
          followRepository: follows,
        );
        final second = FindPeopleCubit(
          repository: repo,
          followRepository: follows,
        );
        await first.load();
        await second.load();
        final oldRow = first.state.suggestions.single;
        final olderLoad = first.loadMore();
        addTearDown(() async {
          if (!olderResponse.isCompleted) {
            olderResponse.complete(http.Response(payload(), 200));
          }
          await olderLoad;
          await first.close();
          await second.close();
          await repo.dispose();
        });
        await olderRequested.future;
        refuse = true;
        await second.load();
        expect(first.state.suggestions, isEmpty);
        expect(second.state.suggestions, isEmpty);
        expect(first.state.status, FindPeopleStatus.failure);
        when(() => follows.followWithResult(candidate))
            .thenAnswer((_) async => FollowOutcome.published);
        expect(await first.follow(oldRow), isNull);
        expect(await first.dismiss(oldRow), isFalse);
        expect(persisted, isEmpty);
        olderResponse.complete(http.Response(payload(), 200));
        await olderLoad;
        expect(first.state.suggestions, isEmpty);
        expect(first.state.status, FindPeopleStatus.failure);
        expect(second.state.suggestions, isEmpty);
        expect(await first.follow(oldRow), isNull);
        refuse = false;
        await second.load();
        expect(second.state.suggestions.single.pubkey, candidate);
        expect(second.state.status, FindPeopleStatus.success);
      },
    );

    for (final restartCursor in [true, false]) {
      test(
        '${restartCursor ? 'cursor restart' : 'fresh reload'} replaces stale rows but preserves pending follow retry',
        () async {
          final following = <String>{};
          final publication = Completer<FollowOutcome>();
          var initial = true;
          late final FindPeopleRepository repo;
          repo = FindPeopleRepository(
            apiClient: FunnelcakeApiClient(
              baseUrl: 'https://example.test',
              retryBaseDelay: Duration.zero,
              httpClient: MockClient((request) async {
                if (request.url.queryParameters.containsKey('cursor')) {
                  return http.Response('{}', 410);
                }
                final keys = initial ? [candidate, 'd' * 64] : ['c' * 64];
                initial = false;
                return http.Response(
                  jsonEncode({
                    'suggestions': [
                      for (final key in keys)
                        {
                          'pubkey': key,
                          'profile': {'name': 'Creator'},
                          'reason': 'popular',
                          'is_classic': false,
                        },
                    ],
                    'next_cursor': 'next',
                  }),
                  200,
                );
              }),
            ),
            accountPubkey: owner,
            currentPubkey: () => owner,
            isExcluded: (_) => false,
            isFollowing: following.contains,
            readDismissed: () => [],
            writeDismissed: (_) async {},
          );
          final cubit = FindPeopleCubit(
            repository: repo,
            followRepository: follows,
          );
          await cubit.load();
          final row = cubit.state.suggestions.first;
          when(() => follows.followWithResult(candidate)).thenAnswer((_) async {
            following.add(candidate);
            repo.notifyExclusionsChanged();
            try {
              return await publication.future;
            } catch (_) {
              following.remove(candidate);
              repo.notifyExclusionsChanged();
              rethrow;
            }
          });
          final pendingFollow = cubit.follow(row);
          if (restartCursor) {
            await cubit.loadMore();
          } else {
            await cubit.load();
          }
          final duringPublication = cubit.state.suggestions
              .map((item) => item.pubkey)
              .toList();
          publication.completeError(StateError('publication failed'));
          await pendingFollow;
          expect(duringPublication, [candidate, 'c' * 64]);
          expect(cubit.state.suggestions.map((item) => item.pubkey), [
            candidate,
            'c' * 64,
          ]);
          expect(cubit.state.pendingPubkeys, isEmpty);
          expect(cubit.state.actionFailed, isTrue);
          await cubit.close();
          await repo.dispose();
        },
      );
    }
  });
}
