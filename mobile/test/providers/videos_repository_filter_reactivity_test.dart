// ABOUTME: Regression test for #4755 — verifies that videosRepositoryProvider
// ABOUTME: rebuilds (yielding a fresh cache) when content filter preferences change.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:funnelcake_api_client/funnelcake_api_client.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/nostr_sdk.dart';
import 'package:openvine/features/feature_flags/models/feature_flag.dart';
import 'package:openvine/features/feature_flags/providers/feature_flag_providers.dart';
import 'package:openvine/features/feature_flags/services/build_configuration.dart';
import 'package:openvine/features/feature_flags/services/feature_flag_service.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/app_version_provider.dart';
import 'package:openvine/providers/curation_providers.dart';
import 'package:openvine/providers/nostr_client_provider.dart';
import 'package:openvine/providers/shared_preferences_provider.dart';
import 'package:openvine/services/content_filter_service.dart';
import 'package:openvine/services/divine_host_filter_service.dart';
import 'package:openvine/services/feed_aspect_ratio_preference_service.dart';
import 'package:openvine/services/seen_videos_service.dart';
import 'package:openvine/services/video_provenance_filter_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:videos_repository/videos_repository.dart';

class _MockVideoLocalStorage extends Mock implements VideoLocalStorage {}

class _MockNostrClient extends Mock implements NostrClient {}

class _MockFunnelcakeApiClient extends Mock implements FunnelcakeApiClient {}

class _MockSeenVideosService extends Mock implements SeenVideosService {}

class _MockSharedPreferences extends Mock implements SharedPreferences {}

class _MockContentFilterService extends Mock implements ContentFilterService {}

class _MockFeedAspectRatioPreferenceService extends Mock
    implements FeedAspectRatioPreferenceService {}

class _MockDivineHostFilterService extends Mock
    implements DivineHostFilterService {}

class _FakeVideoEvent extends Fake implements VideoEvent {}

class _MockProvenanceFilter extends Mock
    implements VideoProvenanceFilterService {}

/// Toggleable version counter that simulates contentFilterVersionProvider
/// changing when the user changes a filter preference.
final _filterVersionTrigger = StateProvider<int>((ref) => 0);

class _ContentFilterVersionFromTrigger extends ContentFilterVersion {
  @override
  int build() => ref.watch(_filterVersionTrigger);
}

class _DivineHostFilterVersionFromTrigger extends DivineHostFilterVersion {
  _DivineHostFilterVersionFromTrigger(this._trigger);

  final StateProvider<int> _trigger;

  @override
  int build() => ref.watch(_trigger);
}

class _StaticContentFilterVersion extends ContentFilterVersion {
  @override
  int build() => 0;
}

class _StaticDivineHostFilterVersion extends DivineHostFilterVersion {
  @override
  int build() => 0;
}

void main() {
  setUpAll(() {
    registerFallbackValue(_FakeVideoEvent());
    registerFallbackValue(Duration.zero);
  });
  group('videosRepositoryProvider filter reactivity (#4755)', () {
    late _MockSharedPreferences mockPrefs;
    late _MockContentFilterService mockContentFilter;
    late _MockFeedAspectRatioPreferenceService mockAspectRatio;
    late _MockDivineHostFilterService mockDivineHost;
    late _MockNostrClient mockNostrClient;

    setUp(() {
      mockPrefs = _MockSharedPreferences();
      when(() => mockPrefs.getBool(any())).thenReturn(null);
      when(() => mockPrefs.setBool(any(), any())).thenAnswer((_) async => true);
      when(() => mockPrefs.getString(any())).thenReturn(null);
      when(
        () => mockPrefs.setString(any(), any()),
      ).thenAnswer((_) async => true);
      when(() => mockPrefs.getInt(any())).thenReturn(null);
      when(() => mockPrefs.setInt(any(), any())).thenAnswer((_) async => true);
      when(() => mockPrefs.getStringList(any())).thenReturn(null);
      when(
        () => mockPrefs.setStringList(any(), any()),
      ).thenAnswer((_) async => true);
      when(() => mockPrefs.containsKey(any())).thenReturn(false);
      when(() => mockPrefs.remove(any())).thenAnswer((_) async => true);

      mockContentFilter = _MockContentFilterService();
      mockAspectRatio = _MockFeedAspectRatioPreferenceService();
      mockDivineHost = _MockDivineHostFilterService();
      mockNostrClient = _MockNostrClient();

      when(() => mockNostrClient.isInitialized).thenReturn(true);
      when(() => mockNostrClient.publicKey).thenReturn('d' * 64);
      when(() => mockNostrClient.resolvePublicKey())
          .thenAnswer((_) async => null);
      when(() => mockNostrClient.hasKeys).thenReturn(false);
      when(() => mockNostrClient.connectedRelayCount).thenReturn(1);
      when(() => mockNostrClient.configuredRelays).thenReturn(<String>[]);

      when(() => mockDivineHost.showDivineHostedOnly).thenReturn(false);
      when(() => mockAspectRatio.shouldHideVideo(any())).thenReturn(false);
    });

    test(
      'Home follows seen-filter changes without restarting the session',
      () async {
        final flags = FeatureFlagService(mockPrefs, const BuildConfiguration());
        addTearDown(flags.dispose);
        await flags.setFlag(FeatureFlag.clientSeenFiltering, true);
        final seen = _MockSeenVideosService();
        when(seen.initializeForFeed).thenAnswer((_) async {});
        final watchedId = '1' * 64;
        final freshId = '2' * 64;
        when(
          () => seen.wasSeenRecently(any(), within: any(named: 'within')),
        ).thenAnswer(
          (invocation) => invocation.positionalArguments.first == watchedId,
        );
        final api = _MockFunnelcakeApiClient();
        when(() => api.isAvailable).thenReturn(true);
        when(
          () => api.getHomeFeed(
            pubkey: any(named: 'pubkey'),
            limit: any(named: 'limit'),
            before: any(named: 'before'),
          ),
        ).thenAnswer(
          (_) async => HomeFeedResponse(
            videos: [
              for (final id in [watchedId, freshId])
                VideoStats(
                  id: id,
                  pubkey: 'a' * 64,
                  createdAt: DateTime.utc(2026),
                  kind: 34236,
                  dTag: 'video-$id',
                  title: 'Test',
                  thumbnail: 'https://example.com/thumb.jpg',
                  videoUrl: 'https://example.com/$id.mp4',
                  reactions: 0,
                  comments: 0,
                  reposts: 0,
                  engagementScore: 0,
                ),
            ],
            rawBody: '{}',
          ),
        );
        when(() => api.getBulkVideoStats(any())).thenAnswer(
          (_) async => const BulkVideoStatsResponse(stats: {}),
        );
        final provenance = _MockProvenanceFilter();
        when(() => provenance.showVerifiedOnly).thenReturn(false);
        final container = ProviderContainer(
          overrides: [
            appVersionProvider.overrideWithValue('test'),
            sharedPreferencesProvider.overrideWithValue(mockPrefs),
            nostrServiceProvider.overrideWithValue(mockNostrClient),
            contentFilterServiceProvider.overrideWithValue(mockContentFilter),
            feedAspectRatioPreferenceServiceProvider.overrideWithValue(
              mockAspectRatio,
            ),
            contentFilterVersionProvider.overrideWith(
              _StaticContentFilterVersion.new,
            ),
            divineHostFilterVersionProvider.overrideWith(
              _StaticDivineHostFilterVersion.new,
            ),
            divineHostFilterServiceProvider.overrideWithValue(mockDivineHost),
            videoProvenanceFilterServiceProvider.overrideWithValue(provenance),
            featureFlagServiceProvider.overrideWithValue(flags),
            seenVideosServiceProvider.overrideWithValue(seen),
            funnelcakeApiClientProvider.overrideWithValue(api),
          ],
        );
        addTearDown(container.dispose);
        Future<List<String>> homeIds() async {
          final page = await container
              .read(videosRepositoryProvider)
              .getHomeFeedVideos(
                authors: ['a' * 64],
                userPubkey: 'd' * 64,
              );
          return page.videos.map((video) => video.id).toList();
        }

        expect(await homeIds(), [freshId]);
        await flags.setFlag(FeatureFlag.clientSeenFiltering, false);
        await container.pump();
        expect(await homeIds(), [watchedId, freshId]);
        await flags.setFlag(FeatureFlag.clientSeenFiltering, true);
        await container.pump();
        expect(await homeIds(), [freshId]);
      },
    );

    test(
      'repository and service follow the current owner for off-host media',
      () async {
        final host = _MockDivineHostFilterService();
        when(() => host.showDivineHostedOnly).thenReturn(true);
        final provenance = _MockProvenanceFilter();
        when(() => provenance.showVerifiedOnly).thenReturn(false);
        final storage = _MockVideoLocalStorage();
        final event = Event.fromJson({
          'id': 'c' * 64,
          'pubkey': 'a' * 64,
          'created_at': 1770000000,
          'kind': 34236,
          'content': '',
          'sig': 'd' * 128,
          'tags': [
            ['d', 'external-upload'],
            ['imeta', 'url https://example.com/video.mp4', 'm video/mp4'],
          ],
        });
        when(() => storage.getEventsByIds(any()))
            .thenAnswer((_) async => [event]);
        var viewer = 'a' * 64;
        when(() => mockNostrClient.publicKey).thenAnswer((_) => viewer);
        final container = ProviderContainer(
          overrides: [
            appVersionProvider.overrideWithValue('test'),
            videoLocalStorageProvider.overrideWithValue(storage),
            sharedPreferencesProvider.overrideWithValue(mockPrefs),
            nostrServiceProvider.overrideWithValue(mockNostrClient),
            contentFilterServiceProvider.overrideWithValue(mockContentFilter),
            feedAspectRatioPreferenceServiceProvider.overrideWithValue(
              mockAspectRatio,
            ),
            contentFilterVersionProvider.overrideWith(
              _StaticContentFilterVersion.new,
            ),
            divineHostFilterVersionProvider.overrideWith(
              _StaticDivineHostFilterVersion.new,
            ),
            divineHostFilterServiceProvider.overrideWithValue(host),
            videoProvenanceFilterServiceProvider.overrideWithValue(provenance),
          ],
        );
        addTearDown(container.dispose);
        final video = VideoEvent(
          id: 'c' * 64,
          pubkey: viewer,
          createdAt: 1770000000,
          timestamp: DateTime.utc(2026),
          content: '',
          videoUrl: 'https://example.com/video.mp4',
        );
        final repository = container.read(videosRepositoryProvider);
        final service = container.read(videoEventServiceProvider);
        expect(repository.applyContentPreferences([video]), [video]);
        expect(service.shouldHideVideo(video), isFalse);
        final route = await repository.lookupVideoForRouteId(video.id);
        expect(route, isA<VideoRouteFound>());
        expect((route as VideoRouteFound).video.id, video.id);
        viewer = 'b' * 64;
        expect(repository.applyContentPreferences([video]), isEmpty);
        expect(service.shouldHideVideo(video), isTrue);
        viewer = '';
        expect(repository.applyContentPreferences([video]), isEmpty);
        expect(service.shouldHideVideo(video), isTrue);
      },
    );

    // Home is fed over REST, so the repository's replacement stream is the
    // only way a republish from this device reaches its tile.
    test('forwards every video the service reports republished', () async {
      final provenance = _MockProvenanceFilter();
      when(() => provenance.showVerifiedOnly).thenReturn(false);
      final container = ProviderContainer(
        overrides: [
          appVersionProvider.overrideWithValue('test'),
          videoLocalStorageProvider.overrideWithValue(_MockVideoLocalStorage()),
          sharedPreferencesProvider.overrideWithValue(mockPrefs),
          nostrServiceProvider.overrideWithValue(mockNostrClient),
          contentFilterServiceProvider.overrideWithValue(mockContentFilter),
          feedAspectRatioPreferenceServiceProvider.overrideWithValue(
            mockAspectRatio,
          ),
          contentFilterVersionProvider.overrideWith(
            _StaticContentFilterVersion.new,
          ),
          divineHostFilterVersionProvider.overrideWith(
            _StaticDivineHostFilterVersion.new,
          ),
          divineHostFilterServiceProvider.overrideWithValue(mockDivineHost),
          videoProvenanceFilterServiceProvider.overrideWithValue(provenance),
        ],
      );
      addTearDown(container.dispose);
      final repository = container.read(videosRepositoryProvider);
      final replaced = <String>[];
      final subscription = repository.replacedVideos.listen(
        (video) => replaced.add(video.id),
      );
      addTearDown(subscription.cancel);

      container
          .read(videoEventServiceProvider)
          .updateVideoEvent(
            VideoEvent(
              id: 'e' * 64,
              pubkey: 'a' * 64,
              createdAt: 1770000000,
              timestamp: DateTime.utc(2026),
              content: '',
              videoUrl: 'https://example.com/video.mp4',
            ),
          );
      await pumpEventQueue();

      expect(replaced, ['e' * 64]);
    });

    for (final provenance in [false, true]) {
      test(
        'canonical filters replace ${provenance ? 'provenance' : 'host'} service instances',
        () async {
          final selection = StateProvider<bool>((ref) => false);
          final nextHost = _MockDivineHostFilterService();
          when(() => nextHost.showDivineHostedOnly).thenReturn(true);
          final oldProvenance = _MockProvenanceFilter();
          final nextProvenance = _MockProvenanceFilter();
          when(() => oldProvenance.showVerifiedOnly).thenReturn(false);
          when(() => nextProvenance.showVerifiedOnly).thenReturn(true);
          final container = ProviderContainer(
            overrides: [
              appVersionProvider.overrideWithValue('test'),
              sharedPreferencesProvider.overrideWithValue(mockPrefs),
              nostrServiceProvider.overrideWithValue(mockNostrClient),
              contentFilterServiceProvider.overrideWithValue(mockContentFilter),
              feedAspectRatioPreferenceServiceProvider.overrideWithValue(
                mockAspectRatio,
              ),
              contentFilterVersionProvider.overrideWith(
                _StaticContentFilterVersion.new,
              ),
              divineHostFilterVersionProvider.overrideWith(
                _StaticDivineHostFilterVersion.new,
              ),
              divineHostFilterServiceProvider.overrideWith(
                (ref) => !provenance && ref.watch(selection)
                    ? nextHost
                    : mockDivineHost,
              ),
              videoProvenanceFilterServiceProvider.overrideWith(
                (ref) => provenance && ref.watch(selection)
                    ? nextProvenance
                    : oldProvenance,
              ),
            ],
          );
          addTearDown(container.dispose);
          final video = VideoEvent(
            id: 'c' * 64,
            pubkey: 'a' * 64,
            createdAt: 1770000000,
            timestamp: DateTime.utc(2026),
            content: '',
            videoUrl: 'https://example.com/video.mp4',
          );
          final firstService = container.read(videoEventServiceProvider);
          final firstRepository = container.read(videosRepositoryProvider);
          expect(firstService.shouldHideVideo(video), isFalse);
          expect(firstRepository.applyContentPreferences([video]), [video]);
          container.read(selection.notifier).state = true;
          await container.pump();
          final replacementService = container.read(videoEventServiceProvider);
          final replacementRepository = container.read(
            videosRepositoryProvider,
          );
          expect(replacementService, isNot(same(firstService)));
          expect(replacementRepository, isNot(same(firstRepository)));
          expect(replacementService.shouldHideVideo(video), isTrue);
          expect(
            replacementRepository.applyContentPreferences([video]),
            isEmpty,
          );
          expect(container.read(divineHostFilterVersionProvider), 0);
        },
      );
    }

    test(
      'rebuilds with fresh instance when contentFilterVersionProvider changes',
      () async {
        final container = ProviderContainer(
          overrides: [
            appVersionProvider.overrideWithValue('test'),
            sharedPreferencesProvider.overrideWithValue(mockPrefs),
            nostrServiceProvider.overrideWithValue(mockNostrClient),
            contentFilterServiceProvider.overrideWithValue(mockContentFilter),
            feedAspectRatioPreferenceServiceProvider.overrideWithValue(
              mockAspectRatio,
            ),
            divineHostFilterServiceProvider.overrideWithValue(mockDivineHost),
            // Override the version providers with a state provider we control.
            contentFilterVersionProvider.overrideWith(
              _ContentFilterVersionFromTrigger.new,
            ),
            divineHostFilterVersionProvider.overrideWith(
              _StaticDivineHostFilterVersion.new,
            ),
          ],
        );
        addTearDown(container.dispose);

        final repo1 = container.read(videosRepositoryProvider);

        // Simulate a content filter preference change by bumping the version.
        container.read(_filterVersionTrigger.notifier).state++;

        // Allow provider rebuild to propagate.
        await container.pump();

        final repo2 = container.read(videosRepositoryProvider);

        expect(
          identical(repo1, repo2),
          isFalse,
          reason:
              'videosRepositoryProvider must yield a new instance '
              '(with fresh InMemoryFeedCache) when content filter version '
              'changes',
        );
      },
    );

    test('rebuilds with fresh instance when divineHostFilterVersionProvider '
        'changes', () async {
      final divineHostTrigger = StateProvider<int>((ref) => 0);

      final container = ProviderContainer(
        overrides: [
          appVersionProvider.overrideWithValue('test'),
          sharedPreferencesProvider.overrideWithValue(mockPrefs),
          nostrServiceProvider.overrideWithValue(mockNostrClient),
          contentFilterServiceProvider.overrideWithValue(mockContentFilter),
          feedAspectRatioPreferenceServiceProvider.overrideWithValue(
            mockAspectRatio,
          ),
          divineHostFilterServiceProvider.overrideWithValue(mockDivineHost),
          contentFilterVersionProvider.overrideWith(
            _StaticContentFilterVersion.new,
          ),
          divineHostFilterVersionProvider.overrideWith(
            () => _DivineHostFilterVersionFromTrigger(divineHostTrigger),
          ),
        ],
      );
      addTearDown(container.dispose);

      final repo1 = container.read(videosRepositoryProvider);

      // Simulate divine host filter toggle.
      container.read(divineHostTrigger.notifier).state++;

      // Allow provider rebuild to propagate.
      await container.pump();

      final repo2 = container.read(videosRepositoryProvider);

      expect(
        identical(repo1, repo2),
        isFalse,
        reason:
            'videosRepositoryProvider must yield a new instance '
            '(with fresh InMemoryFeedCache) when divine host filter version '
            'changes',
      );
    });
  });
}
