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

  test('a failed follow keeps the person and allows retry', () async {
    final repo = repository((_) async => http.Response(payload(), 200));
    final cubit = FindPeopleCubit(repository: repo, followRepository: follows);
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
    final cubit = FindPeopleCubit(repository: repo, followRepository: follows);
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
    final first = FindPeopleCubit(repository: repo, followRepository: follows);
    final second = FindPeopleCubit(repository: repo, followRepository: follows);
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
    final cubit = FindPeopleCubit(repository: repo, followRepository: follows);
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
    final cubit = FindPeopleCubit(repository: repo, followRepository: follows);
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
  test('a server safety refusal removes previously rendered people', () async {
    var unavailable = false;
    final repo = repository(
      (_) async => unavailable
          ? http.Response('{}', 503)
          : http.Response(payload(), 200),
    );
    final cubit = FindPeopleCubit(repository: repo, followRepository: follows);
    await cubit.load();
    expect(cubit.state.suggestions, hasLength(1));
    unavailable = true;
    await cubit.load();
    expect(cubit.state.suggestions, isEmpty);
    expect(cubit.state.status, FindPeopleStatus.failure);
    await cubit.close();
    await repo.dispose();
  });
}
