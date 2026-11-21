// ABOUTME: Pins how videoEventPublisherProvider wires the dependencies that
// ABOUTME: resolve or rebuild at runtime: the sync repository must not rebuild
// ABOUTME: it (#6018), and a videos-repository rebuild must not strand a
// ABOUTME: publish already in flight on the instance it replaced (#11250).

import 'package:blossom_upload_service/blossom_upload_service.dart';
import 'package:creator_sync/creator_sync.dart';
import 'package:db_client/db_client.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:openvine/models/environment_config.dart';
import 'package:openvine/providers/auth_providers.dart';
import 'package:openvine/providers/creator_sync_provider.dart';
import 'package:openvine/providers/database_provider.dart';
import 'package:openvine/providers/environment_provider.dart';
import 'package:openvine/providers/nostr_client_provider.dart';
import 'package:openvine/providers/repository_providers.dart';
import 'package:openvine/providers/saved_sounds_provider.dart';
import 'package:openvine/providers/upload_media_providers.dart';
import 'package:openvine/providers/video_providers.dart';
import 'package:openvine/services/auth_service.dart' hide UserProfile;
import 'package:openvine/services/nip98_auth_service.dart';
import 'package:openvine/services/personal_event_cache_service.dart';
import 'package:openvine/services/saved_sounds_service.dart';
import 'package:openvine/services/upload_manager.dart';
import 'package:openvine/services/video_event_service.dart';
import 'package:videos_repository/videos_repository.dart';

class _MockUploadManager extends Mock implements UploadManager {}

class _MockNostrClient extends Mock implements NostrClient {}

class _MockAuthService extends Mock implements AuthService {}

class _MockPersonalEventCacheService extends Mock
    implements PersonalEventCacheService {}

class _MockVideoEventService extends Mock implements VideoEventService {}

class _MockBlossomUploadService extends Mock implements BlossomUploadService {}

class _MockAppDatabase extends Mock implements AppDatabase {}

class _MockProfileStatsDao extends Mock implements ProfileStatsDao {}

class _MockSavedSoundsService extends Mock implements SavedSoundsService {}

class _MockVideosRepository extends Mock implements VideosRepository {}

class _MockNip98AuthService extends Mock implements Nip98AuthService {}

class _MockSoundSyncRepository extends Mock implements SoundSyncRepository {}

const _ownerPubkey =
    'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';

void main() {
  group('videoEventPublisherProvider sync-repository wiring (#6018)', () {
    test(
      'the publisher instance is identical across a sync-repository '
      'resolution',
      () {
        final container = ProviderContainer(
          overrides: _publisherOverrides(
            authService: _MockAuthService(),
            videosRepository: (_) => _MockVideosRepository(),
          ),
        );
        addTearDown(container.dispose);

        final before = container.read(videoEventPublisherProvider);
        expect(
          before.trustedRelayUrlForTesting,
          'wss://relay.staging.divine.video',
        );

        // The transition this pins: soundSyncAvailabilityProvider resolving
        // well after videoEventPublisherProvider was first read.
        container.read(_syncRepositorySelector.notifier).state =
            _MockSoundSyncRepository();

        final after = container.read(videoEventPublisherProvider);

        expect(
          identical(before, after),
          isTrue,
          reason:
              'watching the resolved sync repository here would rebuild '
              'this keepAlive provider and discard its in-flight-publish '
              'coalescer (_inFlightDirectPublishes, #6018) on every '
              'vault-key resolution',
        );
      },
    );
  });

  group('videoEventPublisherProvider videos-repository wiring (#11250)', () {
    test(
      'a publisher replaced by a repository rebuild still reads the newest '
      'revision for a republish already in flight',
      () async {
        final firstRepository = _MockVideosRepository();
        when(
          () => firstRepository.fetchLatestVideoRevision(any()),
        ).thenAnswer((_) async => const LatestVideoRevisionAbsent());
        final authService = _MockAuthService();
        when(() => authService.currentPublicKeyHex).thenReturn(_ownerPubkey);

        final container = ProviderContainer(
          overrides: [
            ..._publisherOverrides(
              authService: authService,
              videosRepository: (ref) => ref.watch(_videosRepositorySelector),
            ),
            _videosRepositorySelector.overrideWith((_) => firstRepository),
          ],
        );
        addTearDown(container.dispose);

        final inFlight = container.read(videoEventPublisherProvider);
        // A content-filter or auth change rebuilds the repository, which
        // rebuilds the publisher provider and disposes the instance a save
        // that already started still holds.
        container.read(_videosRepositorySelector.notifier).state =
            _MockVideosRepository();
        expect(
          identical(container.read(videoEventPublisherProvider), inFlight),
          isFalse,
        );

        await expectLater(
          inFlight.republishWithSubtitles(
            existingEvent: VideoEvent(
              id: 'video-id',
              pubkey: _ownerPubkey,
              createdAt: 1,
              content: '',
              timestamp: DateTime.fromMillisecondsSinceEpoch(0),
              vineId: 'clip',
            ),
            textTrackRef: 'https://media.divine.video/${'b' * 64}',
          ),
          completion(isNull),
        );
        verify(
          () => firstRepository.fetchLatestVideoRevision(any()),
        ).called(1);
      },
    );
  });
}

/// The publisher's dependencies, with [authService] and [videosRepository]
/// supplied by the test and the sync repository read from
/// [_syncRepositorySelector].
List<Override> _publisherOverrides({
  required AuthService authService,
  required VideosRepository Function(Ref ref) videosRepository,
}) {
  final mockDatabase = _MockAppDatabase();
  when(() => mockDatabase.profileStatsDao).thenReturn(_MockProfileStatsDao());
  return [
    uploadManagerProvider.overrideWith((_) => _MockUploadManager()),
    nostrServiceProvider.overrideWithValue(_MockNostrClient()),
    authServiceProvider.overrideWith((_) => authService),
    personalEventCacheServiceProvider.overrideWith(
      (_) => _MockPersonalEventCacheService(),
    ),
    videoEventServiceProvider.overrideWith((_) => _MockVideoEventService()),
    blossomUploadServiceProvider.overrideWith(
      (_) => _MockBlossomUploadService(),
    ),
    profileRepositoryProvider.overrideWith((_) => null),
    databaseProvider.overrideWithValue(mockDatabase),
    savedSoundsServiceProvider.overrideWith((_) => _MockSavedSoundsService()),
    videosRepositoryProvider.overrideWith(videosRepository),
    currentEnvironmentProvider.overrideWithValue(
      const EnvironmentConfig(environment: AppEnvironment.staging),
    ),
    nip98AuthServiceProvider.overrideWith((_) => _MockNip98AuthService()),
    // Stand-in for soundSyncRepositoryValueProvider: the real provider
    // resolves asynchronously (a vault-key relay round trip), strictly later
    // than every other dependency above, which are all already resolved once
    // auth is ready.
    soundSyncRepositoryValueProvider.overrideWith(
      (ref) => ref.watch(_syncRepositorySelector),
    ),
  ];
}

/// Stand-in for the value `soundSyncRepositoryValueProvider` resolves to
/// once the vault key is available.
final _syncRepositorySelector = StateProvider<SoundSyncRepository?>(
  (_) => null,
);

/// Stand-in for the repository `videosRepositoryProvider` builds, which it
/// rebuilds when content filters or auth change.
final _videosRepositorySelector = StateProvider<VideosRepository>(
  (_) => _MockVideosRepository(),
);
