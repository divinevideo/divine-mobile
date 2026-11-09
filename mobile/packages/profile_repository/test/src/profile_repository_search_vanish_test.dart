import 'dart:async';

import 'package:db_client/db_client.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:funnelcake_api_client/funnelcake_api_client.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/nostr_sdk.dart' show Event;
import 'package:profile_repository/profile_repository.dart';

class _NostrClient extends Mock implements NostrClient {}

class _ApiClient extends Mock implements FunnelcakeApiClient {}

class _Event extends Mock implements Event {
  @override
  DateTime get createdAtDateTime => DateTime.utc(2026);

  @override
  List<List<String>> get tags => const [];
}

void main() {
  setUpAll(() => registerFallbackValue(Duration.zero));
  const deleted =
      'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
  const live =
      'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';

  group('people search vanished accounts', () {
    late AppDatabase db;
    late _NostrClient nostr;
    late _ApiClient api;
    late ProfileRepository repo;

    UserProfile profile(String pubkey) => UserProfile(
      pubkey: pubkey,
      name: 'test account',
      rawData: const {},
      createdAt: DateTime.utc(2026),
      eventId:
          'cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc',
    );

    setUp(() async {
      db = AppDatabase.test(NativeDatabase.memory());
      nostr = _NostrClient();
      api = _ApiClient();
      when(() => api.isAvailable).thenReturn(true);
      when(
        () => api.searchProfiles(
          query: any(named: 'query'),
          limit: any(named: 'limit'),
          offset: any(named: 'offset'),
          sortBy: any(named: 'sortBy'),
          hasVideos: any(named: 'hasVideos'),
        ),
      ).thenAnswer((_) async => []);
      when(() => api.getBulkProfiles(any())).thenAnswer(
        (_) async => const BulkProfilesResponse(profiles: {}),
      );
      when(
        () => nostr.queryUsers(
          any(),
          limit: any(named: 'limit'),
          timeout: any(named: 'timeout'),
        ),
      ).thenAnswer((_) async => <Event>[]);
      repo = ProfileRepository(
        httpClient: MockClient((_) async => http.Response('{}', 404)),
        nostrClient: nostr,
        userProfilesDao: db.userProfilesDao,
        vanishedProfilesDao: db.vanishedProfilesDao,
        funnelcakeApiClient: api,
        localProfileSearch: (query, limit) =>
            db.userProfilesDao.searchProfilesByIdentity(query, limit: limit),
      );
      await db.userProfilesDao.upsertProfile(profile(deleted));
      await db.userProfilesDao.upsertProfile(profile(live));
    });

    tearDown(() async => db.close());

    test(
      'evicts a cached-only vanished result and preserves sparse misses',
      () async {
        when(() => api.getBulkProfiles(any())).thenAnswer(
          (_) async => const BulkProfilesResponse(
            profiles: {deleted: UserProfileVanished(pubkey: deleted)},
          ),
        );

        final results = await repo
            .searchUsersProgressive(query: 'test account')
            .toList();

        expect(results.first.profiles.map((p) => p.pubkey), contains(deleted));
        expect(results.last.profiles.map((p) => p.pubkey), [live]);
        expect(repo.isVanished(deleted), isTrue);
        expect(await db.userProfilesDao.getProfile(deleted), isNull);
        expect(await db.vanishedProfilesDao.getAllPubkeys(), contains(deleted));
        final requested =
            verify(() => api.getBulkProfiles(captureAny())).captured.single
                as List<String>;
        expect(requested, unorderedEquals([deleted, live]));
      },
    );

    test(
      'known vanished profiles never appear in local identity results',
      () async {
        await db.vanishedProfilesDao.markVanished(deleted);
        await repo.loadVanishedPubkeys();
        // Inject stale candidates to cover a fallback or racing local read.
        final staleRepo = ProfileRepository(
          httpClient: MockClient((_) async => http.Response('{}', 404)),
          nostrClient: nostr,
          userProfilesDao: db.userProfilesDao,
          vanishedProfilesDao: db.vanishedProfilesDao,
          localProfileSearch: (_, _) async => [profile(deleted), profile(live)],
        );
        final results = await staleRepo.searchCachedProfilesByIdentity(
          query: 'test account',
          limit: 20,
        );
        expect(results.map((p) => p.pubkey), [live]);
      },
    );

    test(
      'relay results cannot resurrect an account just evicted by bulk',
      () async {
        final event = _Event();
        when(() => event.pubkey).thenReturn(deleted);
        when(() => event.id).thenReturn('d' * 64);
        when(() => event.content).thenReturn('{"name":"test account"}');
        when(() => api.getBulkProfiles(any())).thenAnswer(
          (_) async => const BulkProfilesResponse(
            profiles: {deleted: UserProfileVanished(pubkey: deleted)},
          ),
        );
        when(
          () => nostr.queryUsers(
            any(),
            limit: any(named: 'limit'),
            timeout: any(named: 'timeout'),
          ),
        ).thenAnswer((_) async => [event]);

        final results = await repo
            .searchUsersProgressive(query: 'test account')
            .toList();

        expect(results, hasLength(3));
        for (final result in results.skip(1)) {
          expect(result.profiles.map((p) => p.pubkey), [live]);
        }
        expect(results.last.isComplete, isTrue);
      },
    );

    test(
      'only cached results absent from REST need the bulk recheck',
      () async {
        when(
          () => api.searchProfiles(
            query: any(named: 'query'),
            limit: any(named: 'limit'),
            offset: any(named: 'offset'),
            sortBy: any(named: 'sortBy'),
            hasVideos: any(named: 'hasVideos'),
          ),
        ).thenAnswer(
          (_) async => [
            const ProfileSearchResult(pubkey: live, name: 'test account'),
          ],
        );

        final results = await repo
            .searchUsersProgressive(query: 'test account')
            .toList();

        expect(results.last.profiles, hasLength(2));
        final requested =
            verify(() => api.getBulkProfiles(captureAny())).captured.single
                as List<String>;
        expect(requested, [deleted]);
      },
    );

    test(
      'pagination without local results never sends an empty bulk request',
      () async {
        final result = await repo
            .searchUsersProgressive(
              query: 'test account',
              offset: 20,
            )
            .last;
        expect(result.profiles, isEmpty);
        verifyNever(() => api.getBulkProfiles(any()));
      },
    );

    test('API unavailable keeps local search working', () async {
      when(() => api.isAvailable).thenReturn(false);
      final result = await repo
          .searchUsersProgressive(query: 'test account')
          .last;
      expect(result.profiles, hasLength(2));
      verifyNever(() => api.getBulkProfiles(any()));
    });

    test(
      'bulk failure keeps local results without inventing a vanish',
      () async {
        when(() => api.getBulkProfiles(any())).thenThrow(
          const FunnelcakeException('offline'),
        );
        final results = await repo
            .searchUsersProgressive(query: 'test account')
            .toList();
        expect(results.last.profiles, hasLength(2));
        expect(repo.isVanished(deleted), isFalse);
        expect(await db.userProfilesDao.getProfile(deleted), isNotNull);
      },
    );

    test('cancelled bulk response cannot evict or emit more results', () async {
      final response = Completer<BulkProfilesResponse>();
      final started = Completer<void>();
      when(() => api.getBulkProfiles(any())).thenAnswer((_) {
        started.complete();
        return response.future;
      });
      final token = SearchCancellationToken('vanish-search');
      final pending = repo
          .searchUsersProgressive(
            query: 'test account',
            cancellationToken: token,
          )
          .toList();
      await started.future.timeout(const Duration(seconds: 2));
      token.cancel();
      response.complete(
        const BulkProfilesResponse(
          profiles: {deleted: UserProfileVanished(pubkey: deleted)},
        ),
      );
      final results = await pending;
      expect(results, hasLength(1));
      expect(repo.isVanished(deleted), isFalse);
      expect(await db.userProfilesDao.getProfile(deleted), isNotNull);
    });
  });
}
