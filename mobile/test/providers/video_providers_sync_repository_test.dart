// ABOUTME: Pins that videoEventPublisherProvider is not rebuilt when the
// ABOUTME: sync repository resolves, reopening the #6018 duplicate-publish
// ABOUTME: window its in-flight-publish coalescer closed.

import 'package:blossom_upload_service/blossom_upload_service.dart';
import 'package:creator_sync/creator_sync.dart';
import 'package:db_client/db_client.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
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

void main() {
  group('videoEventPublisherProvider sync-repository wiring (#6018)', () {
    test(
      'the publisher instance is identical across a sync-repository '
      'resolution',
      () {
        final mockDatabase = _MockAppDatabase();
        when(
          () => mockDatabase.profileStatsDao,
        ).thenReturn(_MockProfileStatsDao());

        final container = ProviderContainer(
          overrides: [
            uploadManagerProvider.overrideWith((_) => _MockUploadManager()),
            nostrServiceProvider.overrideWithValue(_MockNostrClient()),
            authServiceProvider.overrideWith((_) => _MockAuthService()),
            personalEventCacheServiceProvider.overrideWith(
              (_) => _MockPersonalEventCacheService(),
            ),
            videoEventServiceProvider.overrideWith(
              (_) => _MockVideoEventService(),
            ),
            blossomUploadServiceProvider.overrideWith(
              (_) => _MockBlossomUploadService(),
            ),
            profileRepositoryProvider.overrideWith((_) => null),
            databaseProvider.overrideWithValue(mockDatabase),
            savedSoundsServiceProvider.overrideWith(
              (_) => _MockSavedSoundsService(),
            ),
            videosRepositoryProvider.overrideWith(
              (_) => _MockVideosRepository(),
            ),
            currentEnvironmentProvider.overrideWithValue(
              const EnvironmentConfig(environment: AppEnvironment.staging),
            ),
            nip98AuthServiceProvider.overrideWith(
              (_) => _MockNip98AuthService(),
            ),
            // Stand-in for soundSyncRepositoryValueProvider: the real
            // provider resolves asynchronously (a vault-key relay round
            // trip), strictly later than every other dependency above,
            // which are all already resolved once auth is ready.
            soundSyncRepositoryValueProvider.overrideWith(
              (ref) => ref.watch(_syncRepositorySelector),
            ),
          ],
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
}

/// Stand-in for the value `soundSyncRepositoryValueProvider` resolves to
/// once the vault key is available.
final _syncRepositorySelector = StateProvider<SoundSyncRepository?>(
  (_) => null,
);
