// ABOUTME: Tests for the repository Riverpod providers.
// ABOUTME: Pins the vanish-source priming that keeps #8208 from regressing
// ABOUTME: and the contact-list flush when relays come back (#8331).

import 'package:content_blocklist_repository/content_blocklist_repository.dart';
import 'package:db_client/db_client.dart' hide Filter;
import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:follow_repository/follow_repository.dart';
import 'package:funnelcake_api_client/funnelcake_api_client.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/nostr_sdk.dart';
import 'package:openvine/models/environment_config.dart';
import 'package:openvine/providers/auth_providers.dart';
import 'package:openvine/providers/curation_providers.dart';
import 'package:openvine/providers/database_provider.dart';
import 'package:openvine/providers/environment_provider.dart';
import 'package:openvine/providers/moderation_providers.dart';
import 'package:openvine/providers/nostr_client_provider.dart';
import 'package:openvine/providers/relay_providers.dart';
import 'package:openvine/providers/repository_providers.dart';
import 'package:openvine/providers/shared_preferences_provider.dart';
import 'package:openvine/providers/social_providers.dart';
import 'package:openvine/providers/user_profile_providers.dart';
import 'package:openvine/providers/video_providers.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/connection_status_service.dart';
import 'package:openvine/services/personal_event_cache_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockMyFollowersDao extends Mock implements MyFollowersDao {}

class _MockAuthService extends Mock implements AuthService {}

class _MockPersonalEventCache extends Mock
    implements PersonalEventCacheService {}

class _MockEnvironmentConfig extends Mock implements EnvironmentConfig {}

class _TestEnvironment extends CurrentEnvironmentNotifier {
  _TestEnvironment(this.config);
  final EnvironmentConfig config;
  @override
  EnvironmentConfig build() => config;
}

class _MockNostrClient extends Mock implements NostrClient {}

class _MockFollowRepository extends Mock implements FollowRepository {}

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

void main() {
  const pubkey =
      'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';

  group('followRepositoryProvider follower persistence', () {
    setUpAll(() => registerFallbackValue(<Filter>[]));

    test(
      'hydrates relationships from the injected database follower DAO',
      () async {
        final follower = '1' * 64;
        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();
        final database = _MockAppDatabase();
        final followersDao = _MockMyFollowersDao();
        when(() => database.profileStatsDao).thenReturn(_MockProfileStatsDao());
        when(() => database.myFollowersDao).thenReturn(followersDao);
        when(() => followersDao.followersOf(pubkey)).thenAnswer(
          (_) async => [
            (pubkey: follower, followedAt: 100),
          ],
        );
        final client = _MockNostrClient();
        when(() => client.publicKey).thenReturn(pubkey);
        when(() => client.hasKeys).thenReturn(false);
        when(
          () => client.subscribe(
            any(),
            subscriptionId: any(named: 'subscriptionId'),
          ),
        ).thenAnswer((_) => const Stream<Event>.empty());
        when(() => client.unsubscribe(any())).thenAnswer((_) async {});
        final personalCache = _MockPersonalEventCache();
        when(() => personalCache.isInitialized).thenReturn(false);
        final environment = _MockEnvironmentConfig();
        when(() => environment.indexerRelays).thenReturn(const []);
        final connectionStatus = ConnectionStatusService();
        addTearDown(connectionStatus.dispose);
        final container = ProviderContainer(
          overrides: [
            nostrServiceProvider.overrideWithValue(client),
            nostrSessionProvider.overrideWith(
              () => _TestNostrSession(
                const NostrSessionReadiness.identityKnown(pubkey: pubkey),
              ),
            ),
            personalEventCacheServiceProvider.overrideWithValue(personalCache),
            pendingActionServiceProvider.overrideWithValue(null),
            authServiceProvider.overrideWithValue(_MockAuthService()),
            connectionStatusServiceProvider.overrideWithValue(connectionStatus),
            databaseProvider.overrideWithValue(database),
            sharedPreferencesProvider.overrideWithValue(prefs),
            funnelcakeApiClientProvider.overrideWithValue(
              FunnelcakeApiClient(baseUrl: ''),
            ),
            currentEnvironmentProvider.overrideWith(
              () => _TestEnvironment(environment),
            ),
            contentBlocklistRepositoryProvider.overrideWithValue(
              ContentBlocklistRepository(),
            ),
          ],
        );
        addTearDown(container.dispose);
        final repository = container.read(followRepositoryProvider);
        expect(repository.relationshipTo(follower), FollowRelationship.none);
        when(() => client.hasKeys).thenReturn(true);
        await repository.initialize();
        expect(
          repository.relationshipTo(follower),
          FollowRelationship.followsYou,
        );
        verify(() => followersDao.followersOf(pubkey)).called(1);
        verifyNever(() => client.queryEvents(any()));
        verifyNever(
          () => client.readEvents(any(), requireAllRelaysSettled: true),
        );
      },
    );
  });

  group('profileReadRepositoryProvider vanish priming (#8208)', () {
    // Builds a container wired for the REAL _buildProfileRepository. Overriding
    // profileReadRepositoryProvider itself — what every test in
    // user_profile_providers_test.dart does — skips the factory entirely and
    // would make these assertions vacuous, so only its leaf dependencies are
    // replaced here.
    //
    // Deliberately a helper called from the test bodies rather than a shared
    // setUp: stubs registered in a shared setUp are inherited invisibly by
    // every descendant test (#8399).
    Future<(ProviderContainer, _MockVanishedProfilesDao)> buildContainer({
      required List<String> vanished,
    }) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final database = _MockAppDatabase();
      final vanishedProfilesDao = _MockVanishedProfilesDao();

      when(() => database.userProfilesDao).thenReturn(_MockUserProfilesDao());
      when(() => database.profileStatsDao).thenReturn(_MockProfileStatsDao());
      when(
        () => database.pendingProfileSavesDao,
      ).thenReturn(_MockPendingProfileSavesDao());
      when(
        () => database.identityEventsDao,
      ).thenReturn(_MockIdentityEventsDao());
      when(() => database.vanishedProfilesDao).thenReturn(vanishedProfilesDao);
      // ProfileRepository hydrates its in-memory vanish mirror on construction,
      // so this has to resolve or the provider throws before returning.
      when(
        vanishedProfilesDao.getAllPubkeys,
      ).thenAnswer((_) async => <String>[]);
      // The durable table's live view — the source the priming subscribes.
      when(
        vanishedProfilesDao.watchAllPubkeys,
      ).thenAnswer((_) => Stream.value(vanished));

      final container = ProviderContainer(
        overrides: [
          // identity-known is the cheapest gate that yields a repository: it
          // needs no NostrClient in the readiness.
          nostrSessionProvider.overrideWith(
            () => _TestNostrSession(
              const NostrSessionReadiness.identityKnown(pubkey: pubkey),
            ),
          ),
          nostrServiceProvider.overrideWithValue(_MockNostrClient()),
          databaseProvider.overrideWithValue(database),
          sharedPreferencesProvider.overrideWithValue(prefs),
          funnelcakeApiClientProvider.overrideWithValue(
            FunnelcakeApiClient(baseUrl: 'https://api.divine.video'),
          ),
        ],
      );
      addTearDown(container.dispose);
      return (container, vanishedProfilesDao);
    }

    test('building the read repository subscribes the durable vanish source '
        'without anyone reading profileVanished', () async {
      final (container, vanishedProfilesDao) = await buildContainer(
        vanished: const [],
      );

      expect(
        container.exists(vanishedProfilePubkeysProvider),
        isFalse,
        reason: 'precondition: nothing has touched the source yet',
      );

      expect(container.read(profileReadRepositoryProvider), isNotNull);

      // The priming ref.listen in _buildProfileRepository is the only thing
      // that can have mounted this. Delete that line and both fail.
      expect(container.exists(vanishedProfilePubkeysProvider), isTrue);
      verify(vanishedProfilesDao.watchAllPubkeys).called(1);
      expect(
        container.exists(profileVanishedProvider(pubkey)),
        isFalse,
        reason: 'the derived provider must not be what mounted the source',
      );
    });

    test(
      'a vanished account reads true once the primed source emits',
      () async {
        final (container, _) = await buildContainer(vanished: const [pubkey]);

        // Hold a live listener, as production does: zendeskIdentitySync watches
        // a repository provider (auth_providers.dart) and AppRootSideEffects
        // watches that, above the router. Riverpod buffers events into a
        // provider nothing is listening to, so a bare read() would leave the
        // primed stream's first row undelivered and this would stay
        // AsyncLoading forever — which is a property of the harness, not of the
        // priming.
        final repository = container.listen(
          profileReadRepositoryProvider,
          (_, _) {},
          fireImmediately: true,
        );
        addTearDown(repository.close);
        expect(repository.read(), isNotNull);
        await pumpEventQueue();

        expect(container.read(profileVanishedProvider(pubkey)), isTrue);
      },
    );
  });

  group('contactListDirtyBroadcastBridgeProvider reconnect flush (#8331)', () {
    const grace = Duration(seconds: 1);
    const relay = 'wss://relay.divine.video';

    // A withheld kind 3 sits local until something says the relays might be
    // healthy again. Before #8331 fed ConnectionStatusService, the
    // offline-to-online edge could never fire, so this bridge only heard
    // session-ready and app-foreground — neither of which is "the relays
    // came back".
    (ProviderContainer, _MockFollowRepository, ConnectionStatusService)
    buildContainer() {
      final client = _MockNostrClient();
      when(() => client.hasKeys).thenReturn(true);
      when(() => client.publicKey).thenReturn(pubkey);
      final followRepository = _MockFollowRepository();
      when(
        followRepository.retryPendingContactListBroadcast,
      ).thenAnswer((_) async => true);
      final connectionStatus = ConnectionStatusService(offlineGrace: grace);
      addTearDown(connectionStatus.dispose);

      final container = ProviderContainer(
        overrides: [
          nostrSessionProvider.overrideWith(
            () => _TestNostrSession(
              NostrSessionReadiness.nostrReady(pubkey: pubkey, client: client),
            ),
          ),
          followRepositoryProvider.overrideWithValue(followRepository),
          connectionStatusServiceProvider.overrideWithValue(connectionStatus),
        ],
      );
      addTearDown(container.dispose);
      container.read(contactListDirtyBroadcastBridgeProvider);
      return (container, followRepository, connectionStatus);
    }

    test('retries the withheld broadcast when relays come back', () {
      fakeAsync((async) {
        final (_, followRepository, connectionStatus) = buildContainer();

        connectionStatus.updateRelayStatuses({relay: false});
        async.elapse(grace);
        verifyNever(followRepository.retryPendingContactListBroadcast);

        connectionStatus.updateRelayStatuses({relay: true});
        async.flushMicrotasks();

        verify(followRepository.retryPendingContactListBroadcast).called(1);
      });
    });

    test('stops listening once the bridge is disposed', () {
      fakeAsync((async) {
        final (container, followRepository, connectionStatus) =
            buildContainer();

        connectionStatus.updateRelayStatuses({relay: false});
        async.elapse(grace);
        container.dispose();

        connectionStatus.updateRelayStatuses({relay: true});
        async.flushMicrotasks();

        verifyNever(followRepository.retryPendingContactListBroadcast);
      });
    });
  });
}
