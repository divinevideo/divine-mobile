// ABOUTME: Pins how videoMetadataUpdateServiceProvider wires its newest
// ABOUTME: revision read and the personal event cache (#11466).

import 'package:blossom_upload_service/blossom_upload_service.dart';
import 'package:dm_repository/dm_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/event.dart';
import 'package:nostr_sdk/nostr_sdk.dart' show generatePrivateKey, getPublicKey;
import 'package:nostr_sdk/relay/publish_outcome.dart';
import 'package:openvine/models/auth_state.dart';
import 'package:openvine/models/environment_config.dart';
import 'package:openvine/models/video_editor/published_video_editor_seed.dart';
import 'package:openvine/providers/auth_providers.dart';
import 'package:openvine/providers/environment_provider.dart';
import 'package:openvine/providers/nostr_client_provider.dart';
import 'package:openvine/providers/repository_providers.dart';
import 'package:openvine/providers/shared_preferences_provider.dart';
import 'package:openvine/providers/upload_media_providers.dart';
import 'package:openvine/providers/video_providers.dart';
import 'package:openvine/services/personal_event_cache_service.dart';
import 'package:openvine/services/video_event_service.dart';
import 'package:openvine/services/video_metadata_update_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:videos_repository/videos_repository.dart';

import '../helpers/test_provider_overrides.dart';

class _MockNostrClient extends Mock implements NostrClient {}

class _MockPersonalEventCacheService extends Mock
    implements PersonalEventCacheService {}

class _MockVideoEventService extends Mock implements VideoEventService {}

class _MockBlossomUploadService extends Mock implements BlossomUploadService {}

class _MockVideosRepository extends Mock implements VideosRepository {}

class _MockDmRepository extends Mock implements DmRepository {}

class _FakeEvent extends Fake implements Event {}

class _FakeVideoEvent extends Fake implements VideoEvent {}

void main() {
  setUpAll(() {
    registerFallbackValue(_FakeEvent());
    registerFallbackValue(_FakeVideoEvent());
    registerFallbackValue(Duration.zero);
  });

  group('videoMetadataUpdateServiceProvider', () {
    test('reads the newest revision through videosRepositoryProvider and '
        'falls back to the personal event cache', () async {
      final privateKey = generatePrivateKey();
      final owner = getPublicKey(privateKey);
      final held = Event(
        owner,
        34236,
        [
          ['d', 'video-d-tag'],
          ['title', 'Held title'],
          ['imeta', 'url https://cdn.example.com/video.mp4', 'm video/mp4'],
        ],
        'Held content',
        createdAt: 1757385263,
      )..sign(privateKey);

      final videosRepository = _MockVideosRepository();
      when(
        () => videosRepository.fetchLatestVideoRevision(any()),
      ).thenAnswer((_) async => const LatestVideoRevisionUnknown());
      final personalEventCache = _MockPersonalEventCacheService();
      when(() => personalEventCache.getEventById(held.id)).thenReturn(held);
      when(() => personalEventCache.cacheUserEvent(any())).thenReturn(null);
      final videoEventService = _MockVideoEventService();
      when(() => videoEventService.updateVideoEvent(any())).thenReturn(null);

      final authService = createMockAuthService(
        authState: AuthState.authenticated,
        currentPublicKeyHex: owner,
      );
      when(
        () => authService.createAndSignEvent(
          kind: any(named: 'kind'),
          content: any(named: 'content'),
          tags: any(named: 'tags'),
          createdAt: any(named: 'createdAt'),
        ),
      ).thenAnswer(
        (invocation) async => Event(
          owner,
          invocation.namedArguments[#kind] as int,
          invocation.namedArguments[#tags] as List<List<String>>,
          invocation.namedArguments[#content] as String,
          createdAt: invocation.namedArguments[#createdAt] as int?,
        )..sign(privateKey),
      );

      final nostrClient = _MockNostrClient();
      when(() => nostrClient.isInitialized).thenReturn(true);
      when(() => nostrClient.configuredRelayCount).thenReturn(1);
      when(() => nostrClient.connectedRelayCount).thenReturn(1);
      when(
        () => nostrClient.configuredRelays,
      ).thenReturn(['wss://relay.staging.divine.video']);
      when(
        () => nostrClient.connectedRelays,
      ).thenReturn(['wss://relay.staging.divine.video']);
      when(
        () => nostrClient.publishEventAwaitOk(
          any(),
          timeout: any(named: 'timeout'),
        ),
      ).thenAnswer(
        (invocation) async => PublishOutcome(
          eventId: (invocation.positionalArguments.first as Event).id,
          acceptedBy: const ['wss://relay.staging.divine.video'],
          rejectedBy: const {},
          noResponseFrom: const [],
        ),
      );

      SharedPreferences.setMockInitialValues({});
      final preferences = await SharedPreferences.getInstance();

      final container = ProviderContainer(
        overrides: [
          nostrServiceProvider.overrideWithValue(nostrClient),
          authServiceProvider.overrideWith((_) => authService),
          blossomUploadServiceProvider.overrideWith(
            (_) => _MockBlossomUploadService(),
          ),
          currentEnvironmentProvider.overrideWithValue(
            const EnvironmentConfig(environment: AppEnvironment.staging),
          ),
          personalEventCacheServiceProvider.overrideWith(
            (_) => personalEventCache,
          ),
          videoEventServiceProvider.overrideWith((_) => videoEventService),
          videosRepositoryProvider.overrideWith((_) => videosRepository),
          dmRepositoryProvider.overrideWith((_) => _MockDmRepository()),
          sharedPreferencesProvider.overrideWithValue(preferences),
        ],
      );
      addTearDown(container.dispose);

      final opened = VideoEvent.fromNostrEvent(held);
      final result = await container
          .read(videoMetadataUpdateServiceProvider)
          .updateVideo(
            originalVideo: opened,
            editorState: editorStateFromPublishedVideo(opened),
            initialCollaboratorPubkeys: const {},
          );

      expect(result, isA<VideoUpdateSuccess>());
      verify(
        () => videosRepository.fetchLatestVideoRevision(
          '34236:$owner:video-d-tag',
        ),
      ).called(1);
      verify(() => personalEventCache.getEventById(held.id)).called(1);
    });
  });
}
