import 'dart:async';

import 'package:db_client/db_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:funnelcake_api_client/funnelcake_api_client.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/nostr_sdk.dart';
import 'package:profile_repository/profile_repository.dart';

class _Nostr extends Mock implements NostrClient {}

class _Api extends Mock implements FunnelcakeApiClient {}

class _Profiles extends Mock implements UserProfilesDao {}

class _Vanished extends Mock implements VanishedProfilesDao {}

void main() {
  setUpAll(() => registerFallbackValue(Duration.zero));

  late Completer<List<UserProfile>> localResults;
  late Completer<List<ProfileSearchResult>> apiResults;
  late Completer<List<Event>> relayResults;
  late Completer<List<String>> vanishedResults;
  late ProfileRepository repository;
  late _Profiles profiles;
  late bool apiStarted;
  late bool relayStarted;

  void setUpSearch({
    bool delayVanished = false,
    List<String> vanishedPubkeys = const [],
  }) {
    apiStarted = false;
    relayStarted = false;
    localResults = Completer<List<UserProfile>>();
    apiResults = Completer<List<ProfileSearchResult>>();
    relayResults = Completer<List<Event>>();
    vanishedResults = Completer<List<String>>();
    final nostr = _Nostr();
    final api = _Api();
    profiles = _Profiles();
    final vanished = _Vanished();
    when(() => api.isAvailable).thenReturn(true);
    when(
      () => api.searchProfiles(
        query: 'test person',
        limit: 200,
        sortBy: profileSearchSortRelevance,
      ),
    ).thenAnswer((_) {
      apiStarted = true;
      return apiResults.future;
    });
    when(() => api.getBulkProfiles(any())).thenAnswer(
      (_) async => const BulkProfilesResponse(profiles: {}),
    );
    when(
      () => nostr.queryUsers(
        'test person',
        limit: 200,
        timeout: any(named: 'timeout'),
      ),
    ).thenAnswer((_) {
      relayStarted = true;
      return relayResults.future;
    });
    when(() => profiles.getProfile(any())).thenAnswer((_) async => null);
    when(vanished.getAllPubkeys).thenAnswer((_) => vanishedResults.future);
    if (!delayVanished) vanishedResults.complete(vanishedPubkeys);
    repository = ProfileRepository(
      nostrClient: nostr,
      userProfilesDao: profiles,
      vanishedProfilesDao: vanished,
      funnelcakeApiClient: api,
      httpClient: MockClient((_) async => http.Response('{}', 404)),
      localProfileSearch: (_, _) => localResults.future,
    );
  }

  group('ProfileRepository.searchUsersProgressive', () {
    test('REST results appear while local and relay are unresolved', () async {
      setUpSearch();
      final emissions = <ProgressiveSearchResult>[];
      final subscription = repository
          .searchUsersProgressive(
            query: 'test person',
            sortBy: profileSearchSortRelevance,
          )
          .listen(emissions.add);
      await pumpEventQueue();
      apiResults.complete([_result('1'), _result('2')]);
      await pumpEventQueue();

      expect(emissions, isNotEmpty);
      expect(emissions.last.profiles.map((p) => p.pubkey), [
        _id('1'),
        _id('2'),
      ]);
      expect(
        emissions.last.sources[SearchSource.localCache],
        isA<SearchSourcePending>(),
      );
      expect(
        emissions.last.sources[SearchSource.nip50Relay],
        isA<SearchSourcePending>(),
      );
      unawaited(subscription.cancel());
      await pumpEventQueue();
    });

    test('relay results appear while local and REST are unresolved', () async {
      setUpSearch();
      final emissions = <ProgressiveSearchResult>[];
      final subscription = repository
          .searchUsersProgressive(
            query: 'test person',
            sortBy: profileSearchSortRelevance,
          )
          .listen(emissions.add);
      await pumpEventQueue();
      relayResults.complete([_event('3')]);
      await pumpEventQueue();

      expect(emissions, isNotEmpty);
      expect(emissions.last.profiles.single.pubkey, _id('3'));
      expect(emissions.last.isComplete, isFalse);
      unawaited(subscription.cancel());
      await pumpEventQueue();
    });

    test(
      'late local revision merges server counts without changing server order',
      () async {
        setUpSearch();
        final emissions = <ProgressiveSearchResult>[];
        repository
            .searchUsersProgressive(
              query: 'test person',
              sortBy: profileSearchSortRelevance,
            )
            .listen(emissions.add);
        await pumpEventQueue();
        apiResults.complete([_result('2'), _result('1')]);
        relayResults.complete([]);
        await pumpEventQueue();
        localResults.complete([
          UserProfile(
            pubkey: _id('1'),
            name: 'test person local',
            rawData: const {'name': 'test person local'},
            createdAt: DateTime.utc(2026),
            eventId: _id('a'),
          ),
          UserProfile(
            pubkey: _id('3'),
            name: 'test person cached only',
            rawData: const {},
            createdAt: DateTime.utc(2026),
            eventId: _id('c'),
          ),
        ]);
        await pumpEventQueue();

        expect(emissions.last.profiles.map((p) => p.pubkey), [
          _id('2'),
          _id('1'),
          _id('3'),
        ]);
        final profile = emissions.last.profiles[1];
        expect(profile.name, 'test person local');
        expect(profile.rawData['video_count'], 7);
        expect(emissions.last.isComplete, isTrue);
      },
    );

    test(
      'remote work starts while vanished policy loads, with no early emission',
      () async {
        setUpSearch(delayVanished: true);
        final emissions = <ProgressiveSearchResult>[];
        final subscription = repository
            .searchUsersProgressive(
              query: 'test person',
              sortBy: profileSearchSortRelevance,
            )
            .listen(emissions.add);
        await pumpEventQueue();
        expect(apiStarted, isTrue);
        expect(relayStarted, isTrue);
        apiResults.complete([_result('1')]);
        relayResults.complete([]);
        await pumpEventQueue();
        expect(emissions, isEmpty);
        vanishedResults.complete([]);
        await pumpEventQueue();
        expect(emissions.last.profiles.single.pubkey, _id('1'));
        await subscription.cancel();
      },
    );

    test(
      'late older local revision cannot restore server-cleared fields',
      () async {
        setUpSearch();
        final emissions = <ProgressiveSearchResult>[];
        repository
            .searchUsersProgressive(
              query: 'test person',
              sortBy: profileSearchSortRelevance,
            )
            .listen(emissions.add);
        await pumpEventQueue();
        apiResults.complete([_result('1')]);
        relayResults.complete([]);
        await pumpEventQueue();
        localResults.complete([
          UserProfile(
            pubkey: _id('1'),
            name: 'test person stale',
            picture: 'https://example.com/removed.jpg',
            rawData: const {'name': 'test person stale'},
            createdAt: DateTime.utc(2024),
            eventId: _id('a'),
          ),
        ]);
        await pumpEventQueue();
        expect(emissions.last.profiles.single.name, 'test person server');
        expect(emissions.last.profiles.single.picture, isNull);
        expect(emissions.last.isComplete, isTrue);
      },
    );

    test(
      'an earlier relay response cannot replace the selected server revision',
      () async {
        setUpSearch();
        final emissions = <ProgressiveSearchResult>[];
        repository
            .searchUsersProgressive(
              query: 'test person',
              sortBy: profileSearchSortRelevance,
            )
            .listen(emissions.add);
        relayResults.complete([
          Event.fromJson({
            'id': _id('b'),
            'pubkey': _id('1'),
            'created_at': DateTime.utc(2027).millisecondsSinceEpoch ~/ 1000,
            'kind': 0,
            'content': '{"name":"test person relay"}',
            'tags': <List<String>>[],
            'sig': '',
          }),
        ]);
        await pumpEventQueue();
        apiResults.complete([_result('1')]);
        localResults.complete([]);
        await pumpEventQueue();
        expect(emissions.last.profiles.single.name, 'test person server');
        expect(emissions.last.isComplete, isTrue);
      },
    );

    test('relay candidates cannot expose a durably vanished account', () async {
      setUpSearch(vanishedPubkeys: [_id('3')]);
      final emissions = <ProgressiveSearchResult>[];
      final done = Completer<void>();
      repository
          .searchUsersProgressive(
            query: 'test person',
            sortBy: profileSearchSortRelevance,
          )
          .listen(emissions.add, onDone: done.complete);
      relayResults.complete([_event('3')]);
      localResults.complete([]);
      apiResults.complete([]);
      await done.future;
      expect(emissions.last.profiles, isEmpty);
      expect(
        emissions.last.sources[SearchSource.nip50Relay],
        isA<SearchSourceSuccess>(),
      );
      expect(repository.isVanished(_id('3')), isTrue);
    });

    test(
      'a failed vanished-policy read fails closed without publishing profiles',
      () async {
        setUpSearch(delayVanished: true);
        final emissions = <ProgressiveSearchResult>[];
        final errors = <Object>[];
        final done = Completer<void>();
        repository
            .searchUsersProgressive(
              query: 'test person',
              sortBy: profileSearchSortRelevance,
            )
            .listen(emissions.add, onError: errors.add, onDone: done.complete);
        vanishedResults.completeError(StateError('policy unavailable'));
        localResults.complete([]);
        apiResults.complete([_result('1')]);
        relayResults.complete([]);
        await done.future;
        expect(emissions, isEmpty);
        expect(errors, [isA<StateError>()]);
      },
    );

    test(
      'consumer cancellation stops subsequent cache enrichment reads',
      () async {
        setUpSearch();
        final cacheRead = Completer<UserProfile?>();
        var reads = 0;
        when(() => profiles.getProfile(any())).thenAnswer((_) {
          reads++;
          return cacheRead.future;
        });
        final subscription = repository
            .searchUsersProgressive(
              query: 'test person',
              sortBy: profileSearchSortRelevance,
            )
            .listen((_) {});
        localResults.complete([
          for (final digit in ['1', '2'])
            UserProfile(
              pubkey: _id(digit),
              name: 'test person local',
              rawData: const {},
              createdAt: DateTime.utc(2026),
              eventId: _id('a'),
            ),
        ]);
        apiResults.complete([]);
        relayResults.complete([]);
        await pumpEventQueue();
        expect(reads, 1);
        await subscription.cancel();
        cacheRead.complete(null);
        await pumpEventQueue();
        expect(reads, 1);
      },
    );

    test(
      'consumer cancellation does not wait for unresolved local search',
      () async {
        setUpSearch();
        final emissions = <ProgressiveSearchResult>[];
        final subscription = repository
            .searchUsersProgressive(
              query: 'test person',
              sortBy: profileSearchSortRelevance,
            )
            .listen(emissions.add);
        await pumpEventQueue();
        var cancelled = false;
        unawaited(subscription.cancel().then((_) => cancelled = true));
        await pumpEventQueue();
        expect(cancelled, isTrue);
        localResults.completeError(StateError('cache unavailable'));
        apiResults.completeError(Exception('API unavailable'));
        relayResults.completeError(StateError('relay unavailable'));
        await pumpEventQueue();
        expect(emissions, isEmpty);
      },
    );
  });
}

String _id(String digit) => digit * 64;

ProfileSearchResult _result(String digit) => ProfileSearchResult(
  pubkey: _id(digit),
  name: 'test person server',
  createdAt: DateTime.utc(2025),
  videoCount: 7,
);

Event _event(String digit) => Event.fromJson({
  'id': _id('b'),
  'pubkey': _id(digit),
  'created_at': 1704067200,
  'kind': 0,
  'content': '{"name":"test person relay"}',
  'tags': <List<String>>[],
  'sig': '',
});
