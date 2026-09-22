// ABOUTME: Tests for user profile Riverpod providers.
// ABOUTME: Stats self-seed from cache and decouple from nostrReady (#5863).

import 'dart:async';

import 'package:db_client/db_client.dart' hide ProfileStats;
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:funnelcake_api_client/funnelcake_api_client.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:openvine/providers/curation_providers.dart';
import 'package:openvine/providers/database_provider.dart';
import 'package:openvine/providers/nostr_client_provider.dart';
import 'package:openvine/providers/repository_providers.dart';
import 'package:openvine/providers/shared_preferences_provider.dart';
import 'package:openvine/providers/user_profile_providers.dart';
import 'package:profile_repository/profile_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockProfileRepository extends Mock implements ProfileRepository {}

class _MockNostrClient extends Mock implements NostrClient {}

class _MockAppDatabase extends Mock implements AppDatabase {}

class _MockUserProfilesDao extends Mock implements UserProfilesDao {}

class _MockProfileStatsDao extends Mock implements ProfileStatsDao {}

class _MockPendingProfileSavesDao extends Mock
    implements PendingProfileSavesDao {}

class _MockIdentityEventsDao extends Mock implements IdentityEventsDao {}

class _MockVanishedProfilesDao extends Mock implements VanishedProfilesDao {}

class _TestNostrSession extends NostrSession {
  _TestNostrSession(this._readiness);

  final NostrSessionReadiness _readiness;

  @override
  NostrSessionReadiness build() => _readiness;
}

void _ignoreVanishedPubkeysChange(
  AsyncValue<Set<String>>? previous,
  AsyncValue<Set<String>> next,
) {}

void main() {
  const pubkey =
      'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';

  group('profileVanishedSnapshotProvider', () {
    test('reads the durable vanish row from a cold provider', () async {
      final database = _MockAppDatabase();
      final vanishedProfilesDao = _MockVanishedProfilesDao();
      final lookup = Completer<bool>();
      when(() => database.vanishedProfilesDao).thenReturn(vanishedProfilesDao);
      when(
        () => vanishedProfilesDao.isVanished(pubkey),
      ).thenAnswer((_) => lookup.future);
      final container = ProviderContainer(
        overrides: [databaseProvider.overrideWithValue(database)],
      );
      addTearDown(container.dispose);

      final result = container.read(
        profileVanishedSnapshotProvider(pubkey).future,
      );
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      lookup.complete(true);

      expect(await result, isTrue);
      verify(() => vanishedProfilesDao.isVanished(pubkey)).called(1);
    });
  });

  group('profileIdentityResolvingProvider', () {
    test('stays resolving while the read repository is unavailable', () {
      final container = ProviderContainer(
        overrides: [profileReadRepositoryProvider.overrideWithValue(null)],
      );
      addTearDown(container.dispose);

      expect(
        container.read(profileIdentityResolvingProvider(pubkey)),
        isTrue,
      );
    });

    test('stops resolving after a fresh profile fetch settles', () async {
      final profileRepository = _MockProfileRepository();
      final fetch = Completer<UserProfile?>();
      when(
        () => profileRepository.getCachedProfile(pubkey: pubkey),
      ).thenAnswer((_) async => null);
      when(
        () => profileRepository.fetchFreshProfile(pubkey: pubkey),
      ).thenAnswer((_) => fetch.future);
      when(
        () => profileRepository.watchProfile(pubkey: pubkey),
      ).thenAnswer((_) => Stream.value(null));

      final container = ProviderContainer(
        overrides: [
          profileReadRepositoryProvider.overrideWithValue(profileRepository),
        ],
      );
      addTearDown(container.dispose);
      final subscription = container.listen(
        profileIdentityResolvingProvider(pubkey),
        (_, _) {},
        fireImmediately: true,
      );
      addTearDown(subscription.close);

      expect(subscription.read(), isTrue);

      fetch.complete(null);
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      expect(subscription.read(), isFalse);
    });

    test(
      'stays resolving until the one-shot and reactive reads both settle',
      () async {
        final profileRepository = _MockProfileRepository();
        final fetch = Completer<UserProfile?>();
        final profiles = StreamController<UserProfile?>();
        addTearDown(profiles.close);
        when(
          () => profileRepository.getCachedProfile(pubkey: pubkey),
        ).thenAnswer((_) async => null);
        when(
          () => profileRepository.fetchFreshProfile(pubkey: pubkey),
        ).thenAnswer((_) => fetch.future);
        when(
          () => profileRepository.watchProfile(pubkey: pubkey),
        ).thenAnswer((_) => profiles.stream);

        final container = ProviderContainer(
          overrides: [
            profileReadRepositoryProvider.overrideWithValue(profileRepository),
          ],
        );
        addTearDown(container.dispose);
        final subscription = container.listen(
          profileIdentityResolvingProvider(pubkey),
          (_, _) {},
          fireImmediately: true,
        );
        addTearDown(subscription.close);

        fetch.complete(null);
        await Future<void>.delayed(Duration.zero);
        await Future<void>.delayed(Duration.zero);

        expect(subscription.read(), isTrue);

        profiles.add(null);
        await Future<void>.delayed(Duration.zero);

        expect(subscription.read(), isFalse);
      },
    );

    test('releases profile watchers after the last listener closes', () async {
      final profileRepository = _MockProfileRepository();
      final profiles = StreamController<UserProfile?>();
      addTearDown(profiles.close);
      when(
        () => profileRepository.getCachedProfile(pubkey: pubkey),
      ).thenAnswer((_) async => null);
      when(
        () => profileRepository.fetchFreshProfile(pubkey: pubkey),
      ).thenAnswer((_) async => null);
      when(
        () => profileRepository.watchProfile(pubkey: pubkey),
      ).thenAnswer((_) => profiles.stream);

      final container = ProviderContainer(
        overrides: [
          profileReadRepositoryProvider.overrideWithValue(profileRepository),
        ],
      );
      addTearDown(container.dispose);
      final subscription = container.listen(
        profileIdentityResolvingProvider(pubkey),
        (_, _) {},
        fireImmediately: true,
      );

      expect(
        container.exists(profileIdentityResolvingProvider(pubkey)),
        isTrue,
      );

      subscription.close();
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      expect(
        container.exists(profileIdentityResolvingProvider(pubkey)),
        isFalse,
      );
    });
  });

  group('profileVanishedProvider', () {
    test(
      'returns the durable value synchronously after the source resolves',
      () async {
        final database = _MockAppDatabase();
        final vanishedProfilesDao = _MockVanishedProfilesDao();
        when(
          () => database.vanishedProfilesDao,
        ).thenReturn(vanishedProfilesDao);
        when(
          vanishedProfilesDao.watchAllPubkeys,
        ).thenAnswer((_) => Stream.value([pubkey]));
        final container = ProviderContainer(
          overrides: [databaseProvider.overrideWithValue(database)],
        );
        addTearDown(container.dispose);

        final sourceSub = container.listen(
          vanishedProfilePubkeysProvider,
          _ignoreVanishedPubkeysChange,
          fireImmediately: true,
        );
        addTearDown(sourceSub.close);
        await Future<void>.delayed(Duration.zero);

        expect(container.read(profileVanishedProvider(pubkey)), isTrue);
      },
    );

    test('updates directly when the durable source changes', () async {
      final database = _MockAppDatabase();
      final vanishedProfilesDao = _MockVanishedProfilesDao();
      final pubkeys = StreamController<List<String>>();
      addTearDown(pubkeys.close);
      when(() => database.vanishedProfilesDao).thenReturn(vanishedProfilesDao);
      when(
        vanishedProfilesDao.watchAllPubkeys,
      ).thenAnswer((_) => pubkeys.stream);
      final container = ProviderContainer(
        overrides: [databaseProvider.overrideWithValue(database)],
      );
      addTearDown(container.dispose);

      final sourceSub = container.listen(
        vanishedProfilePubkeysProvider,
        _ignoreVanishedPubkeysChange,
        fireImmediately: true,
      );
      addTearDown(sourceSub.close);
      final values = <bool>[];
      final profileSub = container.listen(
        profileVanishedProvider(pubkey),
        (_, value) => values.add(value),
        fireImmediately: true,
      );
      addTearDown(profileSub.close);

      pubkeys.add(const []);
      await Future<void>.delayed(Duration.zero);
      pubkeys.add([pubkey]);
      await Future<void>.delayed(Duration.zero);

      expect(values, [false, true]);
    });
  });

  group('userProfileReactiveProvider', () {
    late _MockProfileRepository profileRepository;
    late ProviderContainer container;

    setUp(() {
      profileRepository = _MockProfileRepository();
      container = ProviderContainer(
        overrides: [
          profileReadRepositoryProvider.overrideWithValue(profileRepository),
        ],
      );
      addTearDown(container.dispose);
    });

    test(
      'does not touch a disposed Ref after immediate invalidation',
      () async {
        when(
          () => profileRepository.getCachedProfile(pubkey: pubkey),
        ).thenAnswer((_) async => null);
        when(
          () => profileRepository.fetchFreshProfile(pubkey: pubkey),
        ).thenAnswer((_) async => null);
        when(
          () => profileRepository.watchProfile(pubkey: pubkey),
        ).thenAnswer((_) => const Stream<UserProfile?>.empty());

        final uncaughtErrors = await _captureUncaughtErrors(() async {
          final sub = container.listen(
            userProfileReactiveProvider(pubkey),
            (_, _) {},
            fireImmediately: true,
          );

          container.invalidate(userProfileReactiveProvider(pubkey));
          sub.close();
          await Future<void>.delayed(Duration.zero);
        });

        expect(uncaughtErrors, isEmpty);
      },
    );

    test('emits cached stream value before live updates', () async {
      final liveController = StreamController<UserProfile?>();
      addTearDown(liveController.close);
      final cachedProfile = _profile(pubkey, name: 'cached');
      final liveProfile = _profile(pubkey, name: 'live');

      when(
        () => profileRepository.getCachedProfile(pubkey: pubkey),
      ).thenAnswer((_) async => cachedProfile);
      when(
        () => profileRepository.watchProfile(pubkey: pubkey),
      ).thenAnswer((_) => liveController.stream);

      final emitted = <AsyncValue<UserProfile?>>[];
      final sub = container.listen(
        userProfileReactiveProvider(pubkey),
        (_, next) => emitted.add(next),
        fireImmediately: true,
      );
      addTearDown(sub.close);

      await untilCalled(() => profileRepository.watchProfile(pubkey: pubkey));
      await Future<void>.delayed(Duration.zero);
      liveController.add(cachedProfile);
      await Future<void>.delayed(Duration.zero);
      liveController.add(liveProfile);
      await Future<void>.delayed(Duration.zero);

      expect(emitted.where((value) => value.hasValue).map((v) => v.value), [
        cachedProfile,
        liveProfile,
      ]);
      verifyNever(() => profileRepository.fetchFreshProfile(pubkey: pubkey));
    });

    test('fetches fresh profile once when cache is empty', () async {
      final liveController = StreamController<UserProfile?>();
      addTearDown(liveController.close);

      when(
        () => profileRepository.getCachedProfile(pubkey: pubkey),
      ).thenAnswer((_) async => null);
      when(
        () => profileRepository.fetchFreshProfile(pubkey: pubkey),
      ).thenAnswer((_) async => null);
      when(
        () => profileRepository.watchProfile(pubkey: pubkey),
      ).thenAnswer((_) => liveController.stream);

      final sub = container.listen(
        userProfileReactiveProvider(pubkey),
        (_, _) {},
        fireImmediately: true,
      );
      addTearDown(sub.close);

      await Future<void>.delayed(Duration.zero);

      verify(
        () => profileRepository.fetchFreshProfile(pubkey: pubkey),
      ).called(1);
    });

    test('cancels the underlying profile stream when disposed', () async {
      var wasCancelled = false;
      final liveController = StreamController<UserProfile?>(
        onCancel: () {
          wasCancelled = true;
        },
      );
      addTearDown(liveController.close);

      when(
        () => profileRepository.getCachedProfile(pubkey: pubkey),
      ).thenAnswer((_) async => _profile(pubkey));
      when(
        () => profileRepository.watchProfile(pubkey: pubkey),
      ).thenAnswer((_) => liveController.stream);

      final sub = container.listen(
        userProfileReactiveProvider(pubkey),
        (_, _) {},
        fireImmediately: true,
      );

      await Future<void>.delayed(Duration.zero);
      sub.close();
      container.invalidate(userProfileReactiveProvider(pubkey));
      await Future<void>.delayed(Duration.zero);

      expect(wasCancelled, isTrue);
    });

    test(
      'resolves to AsyncData(null) when no repository is available',
      () async {
        final emptyContainer = ProviderContainer(
          overrides: [profileReadRepositoryProvider.overrideWithValue(null)],
        );
        addTearDown(emptyContainer.dispose);

        final emitted = <AsyncValue<UserProfile?>>[];
        final sub = emptyContainer.listen(
          userProfileReactiveProvider(pubkey),
          (_, next) => emitted.add(next),
          fireImmediately: true,
        );
        addTearDown(sub.close);

        await Future<void>.delayed(Duration.zero);

        expect(emitted, isNotEmpty);
        // Not AsyncLoading: a stream that closes without ever emitting
        // strands the provider in AsyncLoading forever, which callers cannot
        // tell apart from "still fetching" — so UserName fell through to a
        // generated name and never revisited it (#6423).
        expect(emitted.last, isA<AsyncData<UserProfile?>>());
        expect(emitted.last.value, isNull);
      },
    );
  });

  group('blockedUserProfilesProvider', () {
    late _MockProfileRepository profileRepository;
    late ProviderContainer container;

    setUp(() {
      profileRepository = _MockProfileRepository();
      container = ProviderContainer(
        overrides: [
          profileReadRepositoryProvider.overrideWithValue(profileRepository),
        ],
      );
      addTearDown(container.dispose);
    });

    test('fetches blocked pubkeys in one filter-bypassing batch', () async {
      final blockedProfile = _profile(pubkey, name: 'blocked');
      when(
        () => profileRepository.fetchBatchProfiles(
          pubkeys: [pubkey],
          ignoreBlockFilter: true,
        ),
      ).thenAnswer((_) async => {pubkey: blockedProfile});

      final result = await container.read(
        blockedUserProfilesProvider({pubkey}).future,
      );

      expect(result, {pubkey: blockedProfile});
      verify(
        () => profileRepository.fetchBatchProfiles(
          pubkeys: [pubkey],
          ignoreBlockFilter: true,
        ),
      ).called(1);
    });

    test('chunks large blocklists into bounded batch requests', () async {
      final pubkeys = {
        for (var i = 0; i < 51; i++) i.toString().padLeft(64, '0'),
      };
      when(
        () => profileRepository.fetchBatchProfiles(
          pubkeys: any(named: 'pubkeys'),
          ignoreBlockFilter: true,
        ),
      ).thenAnswer((_) async => {});

      await container.read(blockedUserProfilesProvider(pubkeys).future);

      final captured = verify(
        () => profileRepository.fetchBatchProfiles(
          pubkeys: captureAny(named: 'pubkeys'),
          ignoreBlockFilter: true,
        ),
      ).captured.cast<List<String>>();
      expect(captured.map((chunk) => chunk.length), [50, 1]);
    });
  });

  group('blockedUserProfileProvider', () {
    test('streams cache updates without starting a per-user fetch', () async {
      final profileRepository = _MockProfileRepository();
      final updates = StreamController<UserProfile?>();
      addTearDown(updates.close);
      when(
        () => profileRepository.watchProfile(pubkey: pubkey),
      ).thenAnswer((_) => updates.stream);
      final container = ProviderContainer(
        overrides: [
          profileReadRepositoryProvider.overrideWithValue(profileRepository),
        ],
      );
      addTearDown(container.dispose);

      final emitted = <UserProfile?>[];
      final subscription = container.listen(
        blockedUserProfileProvider(pubkey),
        (_, next) {
          if (next.hasValue) emitted.add(next.value);
        },
        fireImmediately: true,
      );
      addTearDown(subscription.close);
      final cachedProfile = _profile(pubkey, name: 'updated');

      updates.add(cachedProfile);
      await Future<void>.delayed(Duration.zero);

      expect(emitted, [cachedProfile]);
      verify(() => profileRepository.watchProfile(pubkey: pubkey)).called(1);
      verifyNever(
        () => profileRepository.fetchFreshProfile(pubkey: any(named: 'pubkey')),
      );
    });
  });

  group('fetchUserProfileProvider', () {
    late _MockProfileRepository profileRepository;
    late ProviderContainer container;

    setUp(() {
      profileRepository = _MockProfileRepository();
      container = ProviderContainer(
        overrides: [
          profileReadRepositoryProvider.overrideWithValue(profileRepository),
        ],
      );
      addTearDown(container.dispose);
    });

    test('returns cached profile without scheduling a revalidation', () async {
      final cachedProfile = _profile(pubkey, name: 'cached');
      when(
        () => profileRepository.getCachedProfile(pubkey: pubkey),
      ).thenAnswer((_) async => cachedProfile);

      final result = await container.read(
        fetchUserProfileProvider(pubkey).future,
      );

      expect(result, cachedProfile);
      verifyNever(() => profileRepository.fetchFreshProfile(pubkey: pubkey));
      verifyNever(() => profileRepository.revalidateVanishOnce(pubkey));
    });

    test('fetches fresh profile when cache is empty', () async {
      final freshProfile = _profile(pubkey, name: 'live');
      when(
        () => profileRepository.getCachedProfile(pubkey: pubkey),
      ).thenAnswer((_) async => null);
      when(
        () => profileRepository.fetchFreshProfile(pubkey: pubkey),
      ).thenAnswer((_) async => freshProfile);

      final result = await container.read(
        fetchUserProfileProvider(pubkey).future,
      );

      expect(result, freshProfile);
      verify(
        () => profileRepository.fetchFreshProfile(pubkey: pubkey),
      ).called(1);
      verifyNever(() => profileRepository.revalidateVanishOnce(pubkey));
    });
  });

  group('userProfileStatsReactiveProvider lifecycle', () {
    test(
      'does not touch a disposed Ref after immediate invalidation',
      () async {
        final profileRepository = _MockProfileRepository();
        final container = ProviderContainer(
          overrides: [
            profileReadRepositoryProvider.overrideWithValue(profileRepository),
          ],
        );
        addTearDown(container.dispose);

        when(
          () => profileRepository.fetchFreshProfile(pubkey: pubkey),
        ).thenAnswer((_) async => null);
        when(
          () => profileRepository.watchProfileStats(pubkey: pubkey),
        ).thenAnswer((_) => const Stream<ProfileStats?>.empty());

        final uncaughtErrors = await _captureUncaughtErrors(() async {
          final sub = container.listen(
            userProfileStatsReactiveProvider(pubkey),
            (_, _) {},
            fireImmediately: true,
          );

          container.invalidate(userProfileStatsReactiveProvider(pubkey));
          sub.close();
          await Future<void>.delayed(Duration.zero);
        });

        expect(uncaughtErrors, isEmpty);
      },
    );
  });

  group('userProfileStatsReactiveProvider', () {
    late _MockProfileRepository profileRepository;
    late StreamController<ProfileStats?> statsController;
    late ProviderContainer container;

    setUp(() {
      profileRepository = _MockProfileRepository();
      statsController = StreamController<ProfileStats?>();
      container = ProviderContainer(
        overrides: [
          // #5863: counts now source from the identity-known-gated stats repo.
          profileReadRepositoryProvider.overrideWithValue(profileRepository),
        ],
      );
      addTearDown(container.dispose);
      addTearDown(statsController.close);

      when(
        () => profileRepository.watchProfileStats(pubkey: pubkey),
      ).thenAnswer((_) => statsController.stream);
      when(
        () => profileRepository.fetchFreshProfile(pubkey: pubkey),
      ).thenAnswer((_) async => null);
    });

    test('fetches a fresh profile as soon as stats are watched', () async {
      final emitted = <AsyncValue<ProfileStats?>>[];
      final sub = container.listen(
        userProfileStatsReactiveProvider(pubkey),
        (_, next) => emitted.add(next),
        fireImmediately: true,
      );

      await Future<void>.delayed(Duration.zero);

      verify(
        () => profileRepository.fetchFreshProfile(pubkey: pubkey),
      ).called(1);

      statsController.add(null);
      await Future<void>.delayed(Duration.zero);

      const stats = ProfileStats(
        pubkey: pubkey,
        followers: 12,
        following: 34,
        totalLikes: 56,
        totalViews: 78,
      );
      statsController.add(stats);
      await Future<void>.delayed(Duration.zero);

      expect(emitted.last.value, stats);
      sub.close();
      container.invalidate(userProfileStatsReactiveProvider(pubkey));
      await Future<void>.delayed(Duration.zero);
      await statsController.close();
    });

    test(
      'does not refetch active counts when stats repo stays stable',
      () async {
        var fetchCount = 0;
        final nostrClient = _MockNostrClient();
        when(
          () => profileRepository.fetchFreshProfile(pubkey: pubkey),
        ).thenAnswer((_) async {
          fetchCount++;
          return null;
        });

        final streamContainer = ProviderContainer(
          overrides: [
            nostrSessionProvider.overrideWith(
              () => _TestNostrSession(
                const NostrSessionReadiness.identityKnown(pubkey: pubkey),
              ),
            ),
            profileReadRepositoryProvider.overrideWith((ref) {
              final identityPubkey = ref.watch(
                nostrSessionProvider.select((readiness) {
                  if (readiness.phase == NostrSessionPhase.identityKnown ||
                      readiness.phase == NostrSessionPhase.nostrReady) {
                    return readiness.pubkey;
                  }
                  return null;
                }),
              );
              return identityPubkey == null ? null : profileRepository;
            }),
          ],
        );
        addTearDown(streamContainer.dispose);

        final sub = streamContainer.listen(
          userProfileStatsReactiveProvider(pubkey),
          (_, _) {},
          fireImmediately: true,
        );

        await Future<void>.delayed(Duration.zero);
        expect(fetchCount, 1);

        streamContainer
            .read(nostrSessionProvider.notifier)
            .update(
              NostrSessionReadiness.nostrReady(
                pubkey: pubkey,
                client: nostrClient,
              ),
            );
        await Future<void>.delayed(Duration.zero);

        expect(fetchCount, 1);
        sub.close();
        streamContainer.invalidate(userProfileStatsReactiveProvider(pubkey));
        await Future<void>.delayed(Duration.zero);
        await statsController.close();
      },
    );
  });

  group('videoCardAuthorStatsProvider', () {
    late _MockProfileRepository profileRepository;
    late ProviderContainer container;

    setUp(() {
      profileRepository = _MockProfileRepository();
      container = ProviderContainer(
        overrides: [
          profileReadRepositoryProvider.overrideWithValue(profileRepository),
        ],
      );
      addTearDown(container.dispose);

      when(
        () => profileRepository.fetchFreshProfile(pubkey: pubkey),
      ).thenAnswer((_) async => null);
    });

    test('does not fetch when a fresh cached row answers the card', () async {
      when(
        () => profileRepository.getCachedProfileStats(pubkey: pubkey),
      ).thenAnswer((_) async => _stats(pubkey));
      final updates = StreamController<ProfileStats?>();
      when(
        () => profileRepository.watchProfileStats(pubkey: pubkey),
      ).thenAnswer((_) => updates.stream);

      final emitted = <AsyncValue<ProfileStats?>>[];
      final sub = container.listen(
        videoCardAuthorStatsProvider(pubkey),
        (_, next) => emitted.add(next),
        fireImmediately: true,
      );
      addTearDown(sub.close);
      addTearDown(updates.close);

      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      verifyNever(() => profileRepository.fetchFreshProfile(pubkey: pubkey));

      updates.add(_stats(pubkey));
      await Future<void>.delayed(Duration.zero);

      expect(emitted.last.value, _stats(pubkey));
    });

    test('fetches once when the stats cache is empty', () async {
      when(
        () => profileRepository.getCachedProfileStats(pubkey: pubkey),
      ).thenAnswer((_) async => null);
      final updates = StreamController<ProfileStats?>();
      when(
        () => profileRepository.watchProfileStats(pubkey: pubkey),
      ).thenAnswer((_) => updates.stream);

      final sub = container.listen(
        videoCardAuthorStatsProvider(pubkey),
        (_, _) {},
        fireImmediately: true,
      );
      addTearDown(sub.close);
      addTearDown(updates.close);

      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      verify(
        () => profileRepository.fetchFreshProfile(pubkey: pubkey),
      ).called(1);
    });

    test('releases the stats watcher when the card unmounts', () async {
      var cancelled = false;
      final updates = StreamController<ProfileStats?>(
        onCancel: () => cancelled = true,
      );
      when(
        () => profileRepository.getCachedProfileStats(pubkey: pubkey),
      ).thenAnswer((_) async => _stats(pubkey));
      when(
        () => profileRepository.watchProfileStats(pubkey: pubkey),
      ).thenAnswer((_) => updates.stream);

      final sub = container.listen(
        videoCardAuthorStatsProvider(pubkey),
        (_, _) {},
        fireImmediately: true,
      );

      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      expect(container.exists(videoCardAuthorStatsProvider(pubkey)), isTrue);

      sub.close();
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      expect(cancelled, isTrue);
      expect(container.exists(videoCardAuthorStatsProvider(pubkey)), isFalse);
      await updates.close();
    });
  });

  group('read/write split (#6423)', () {
    test('the reactive profile resolves from cache while the signing gate is '
        'still shut', () async {
      final repository = _MockProfileRepository();
      final cached = UserProfile(
        pubkey: pubkey,
        name: 'real-name',
        rawData: const {},
        createdAt: DateTime.utc(2026),
        eventId: 'event-id',
      );
      when(
        () => repository.getCachedProfile(pubkey: pubkey),
      ).thenAnswer((_) async => cached);
      when(
        () => repository.watchProfile(pubkey: pubkey),
      ).thenAnswer((_) => Stream<UserProfile?>.value(cached));

      final container = ProviderContainer(
        overrides: [
          // The state the reporter was stuck in: identity known, relays not
          // yet connected, so the signing-gated repository is null.
          profileRepositoryProvider.overrideWithValue(null),
          profileReadRepositoryProvider.overrideWithValue(repository),
        ],
      );
      addTearDown(container.dispose);

      final emitted = <AsyncValue<UserProfile?>>[];
      final sub = container.listen(
        userProfileReactiveProvider(pubkey),
        (_, next) => emitted.add(next),
        fireImmediately: true,
      );
      addTearDown(sub.close);

      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      expect(emitted.last.value?.name, 'real-name');
    });
  });

  group('profileStatsRepository gating (#5863)', () {
    ProviderContainer containerWith(NostrSessionReadiness readiness) {
      final container = ProviderContainer(
        overrides: [
          nostrSessionProvider.overrideWith(() => _TestNostrSession(readiness)),
        ],
      );
      addTearDown(container.dispose);
      return container;
    }

    test('is null when signed out', () {
      final container = containerWith(const NostrSessionReadiness.signedOut());
      expect(container.read(profileReadRepositoryProvider), isNull);
    });

    test(
      'the relay-backed profileRepository stays null at identity-known, which '
      'is exactly the window the stats repo unblocks',
      () {
        final container = containerWith(
          const NostrSessionReadiness.identityKnown(pubkey: pubkey),
        );
        // The nostrReady gate is not satisfied at identity-known, so the
        // relay-backed repo (and its counts) are still null here — the bug the
        // identity-known-gated stats repo fixes by rendering counts earlier.
        expect(container.read(profileRepositoryProvider), isNull);
      },
    );

    test('preserves the stats repository instance from identity-known to '
        'nostrReady for the same pubkey', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final nostrClient = _MockNostrClient();
      final database = _MockAppDatabase();
      final userProfilesDao = _MockUserProfilesDao();
      final profileStatsDao = _MockProfileStatsDao();
      final pendingProfileSavesDao = _MockPendingProfileSavesDao();
      final funnelcakeClient = FunnelcakeApiClient(
        baseUrl: 'https://api.divine.video',
      );

      when(() => database.userProfilesDao).thenReturn(userProfilesDao);
      when(() => database.profileStatsDao).thenReturn(profileStatsDao);
      when(
        () => database.pendingProfileSavesDao,
      ).thenReturn(pendingProfileSavesDao);
      when(
        () => database.identityEventsDao,
      ).thenReturn(_MockIdentityEventsDao());
      final vanishedProfilesDao = _MockVanishedProfilesDao();
      // The repository hydrates its vanish set on construction, so this has
      // to resolve or the provider throws before it returns an instance.
      when(
        vanishedProfilesDao.getAllPubkeys,
      ).thenAnswer((_) async => <String>[]);
      when(() => database.vanishedProfilesDao).thenReturn(vanishedProfilesDao);

      final container = ProviderContainer(
        overrides: [
          nostrSessionProvider.overrideWith(
            () => _TestNostrSession(
              const NostrSessionReadiness.identityKnown(pubkey: pubkey),
            ),
          ),
          nostrServiceProvider.overrideWithValue(nostrClient),
          databaseProvider.overrideWithValue(database),
          sharedPreferencesProvider.overrideWithValue(prefs),
          funnelcakeApiClientProvider.overrideWithValue(funnelcakeClient),
        ],
      );
      addTearDown(container.dispose);

      final identityKnownRepo = container.read(profileReadRepositoryProvider);
      expect(identityKnownRepo, isNotNull);

      container
          .read(nostrSessionProvider.notifier)
          .update(
            NostrSessionReadiness.nostrReady(
              pubkey: pubkey,
              client: nostrClient,
            ),
          );

      final nostrReadyRepo = container.read(profileReadRepositoryProvider);
      expect(identical(identityKnownRepo, nostrReadyRepo), isTrue);
    });
  });
}

ProfileStats _stats(String pubkey) => ProfileStats(
  pubkey: pubkey,
  followers: 12,
  following: 34,
  totalLikes: 56,
  totalViews: 78,
);

UserProfile _profile(String pubkey, {String name = 'profile'}) {
  final eventId = switch (name) {
    'cached' =>
      'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb',
    'live' =>
      'cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc',
    _ => 'dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd',
  };

  return UserProfile(
    pubkey: pubkey,
    name: name,
    rawData: {'name': name},
    createdAt: DateTime.utc(2026),
    eventId: eventId,
  );
}

Future<List<Object>> _captureUncaughtErrors(
  Future<void> Function() body,
) async {
  final errors = <Object>[];
  final previousFlutterError = FlutterError.onError;
  FlutterError.onError = (details) {
    errors.add(details.exception);
  };

  try {
    await runZonedGuarded(body, (error, _) {
      errors.add(error);
    });
  } finally {
    FlutterError.onError = previousFlutterError;
  }

  return errors;
}
