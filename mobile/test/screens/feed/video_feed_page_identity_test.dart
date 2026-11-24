import 'dart:async';

import 'package:cache_sync/cache_sync.dart';
import 'package:curated_list_repository/curated_list_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:funnelcake_api_client/funnelcake_api_client.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:openvine/blocs/video_feed/video_feed_bloc.dart';
import 'package:openvine/blocs/video_playback_status/video_playback_status_cubit.dart';
import 'package:openvine/config/adaptive_classics.dart';
import 'package:openvine/features/feature_flags/models/feature_flag.dart';
import 'package:openvine/features/feature_flags/providers/feature_flag_providers.dart';
import 'package:openvine/observability/screen_frame_trace.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/startup_performance_provider.dart';
import 'package:openvine/screens/feed/video_feed_page.dart';
import 'package:openvine/services/age_verification_service.dart';
import 'package:openvine/services/analytics_service.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/broken_video_tracker.dart';
import 'package:openvine/services/startup_performance_service.dart';
import 'package:openvine/widgets/screen_frame_trace_scope.dart';
import 'package:people_lists_repository/people_lists_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';
import 'package:videos_repository/videos_repository.dart';

import '../../helpers/test_provider_overrides.dart';

class _VideosRepository extends Mock implements VideosRepository {
  _VideosRepository({Stream<String> removals = const Stream.empty()}) {
    when(() => removedVideoIds).thenAnswer((_) => removals);
    when(() => replacedVideos).thenAnswer((_) => const Stream.empty());
  }

  @override
  bool isVideoKnownDeleted(VideoEvent video) => false;
}

class _CuratedListRepository extends Mock implements CuratedListRepository {}

class _PeopleListsRepository extends Mock implements PeopleListsRepository {}

// Identity and policy tests still construct Home's always-available people
// source. Keep that incidental source in memory for cases focused on videos.
PeopleListsRepository _emptyPeopleListsRepository() {
  final repository = _PeopleListsRepository();
  when(
    () =>
        repository.readFollowedLists(viewerPubkey: any(named: 'viewerPubkey')),
  ).thenAnswer((_) async => const []);
  when(
    () =>
        repository.watchFollowedLists(viewerPubkey: any(named: 'viewerPubkey')),
  ).thenAnswer((_) => const Stream.empty());
  when(
    () => repository.syncFollowedLists(
      viewerPubkey: any(named: 'viewerPubkey'),
      isCancelled: any(named: 'isCancelled'),
    ),
  ).thenAnswer((_) async {});
  return repository;
}

VideoEvent _removalVideo(String digit) => VideoEvent(
  id: digit * 64,
  pubkey: _policyViewer,
  createdAt: 1700000000,
  content: 'Synthetic removal fixture',
  timestamp: DateTime.utc(2026),
  videoUrl: 'https://example.com/$digit.mp4',
);

// Assert bloc transitions before pumping a frame: these wiring tests do not
// need native media playback to observe a repository replacement.
Future<void> _loadRemovalVideos(
  WidgetTester tester,
  _SafetyPolicyHome home,
) async {
  when(
    () => home.videos.getRecommendedVideos(
      userPubkey: any(named: 'userPubkey'),
      until: any(named: 'until'),
      skipCache: any(named: 'skipCache'),
      revalidate: any(named: 'revalidate'),
    ),
  ).thenAnswer(
    (_) async =>
        HomeFeedResult(videos: [_removalVideo('1'), _removalVideo('2')]),
  );
  home.originalFeed.add(const VideoFeedRefreshRequested());
  await tester.runAsync(pumpEventQueue);
  expect(home.originalFeed.state.videos, [
    _removalVideo('1'),
    _removalVideo('2'),
  ]);
}

/// Records each Classics read Home's session sends, with its viewer.
List<(ClassicRecommendationsRequest, String?)> _stubClassicRecommendations(
  _VideosRepository videos,
) {
  registerFallbackValue(const ClassicRecommendationsRequest(seed: 'fallback'));
  registerFallbackValue(<VideoEvent>[]);
  final requests = <(ClassicRecommendationsRequest, String?)>[];
  when(() => videos.applyContentPreferences(any())).thenAnswer(
    (call) => call.positionalArguments.single as List<VideoEvent>,
  );
  when(
    () => videos.getClassicRecommendations(
      request: any(named: 'request'),
      userPubkey: any(named: 'userPubkey'),
      isCurrent: any(named: 'isCurrent'),
    ),
  ).thenAnswer((call) async {
    requests.add((
      call.namedArguments[#request] as ClassicRecommendationsRequest,
      call.namedArguments[#userPubkey] as String?,
    ));
    return HomeFeedResult(
      videos: [_removalVideo('1'), _removalVideo('2')],
      paginationCursor: 'next',
      hasMore: true,
      recommendationPageCount: 1,
    );
  });
  return requests;
}

class _StartupPerformance extends Mock implements StartupPerformanceService {}

/// Consents until disposed, as a live service does after initialization.
class _ConsentingAnalytics extends TestAnalyticsService {
  bool _retired = false;

  @override
  bool get initializedAnalyticsConsent => !_retired;

  @override
  void dispose() {
    _retired = true;
    super.dispose();
  }
}

class _Nostr extends Mock implements NostrClient {}

class _Api extends Mock implements FunnelcakeApiClient {}

enum _SafetyPolicy { adultVerification, captureProvenance }

const _policyViewer =
    'eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee';

class _SafetyPolicyHome {
  _SafetyPolicyHome({
    required this.preferences,
    required this.ageVerification,
    required this.container,
    required this.videos,
    required this.originalFeed,
    required this.originalPlayback,
  });

  final SharedPreferences preferences;
  final AgeVerificationService ageVerification;
  final ProviderContainer container;
  final _VideosRepository videos;
  final VideoFeedBloc originalFeed;
  final VideoPlaybackStatusCubit originalPlayback;
}

Future<_SafetyPolicyHome> _mountSafetyPolicyHome(
  WidgetTester tester, {
  FeedMode initialMode = FeedMode.forYou,
  Stream<String> removals = const Stream.empty(),
  VideosRepository? Function()? currentRepository,
  List<Override> overrides = const [],
}) async {
  await CacheSync.init(dao: _CacheDao());
  SharedPreferences.setMockInitialValues({
    'selected_feed_mode_$_policyViewer': 'forYou',
    'adult_content_verified_$_policyViewer': true,
  });
  final preferences = await SharedPreferences.getInstance();
  final videos = _VideosRepository(removals: removals);
  final curated = _CuratedListRepository();
  when(curated.getSubscribedLists).thenReturn([]);
  when(
    () => curated.subscriptionSnapshots,
  ).thenAnswer((_) => const Stream<CuratedListSubscriptionSnapshot>.empty());
  when(
    () => videos.getRecommendedVideos(
      userPubkey: any(named: 'userPubkey'),
      until: any(named: 'until'),
      skipCache: any(named: 'skipCache'),
      revalidate: any(named: 'revalidate'),
    ),
  ).thenAnswer((_) async => const HomeFeedResult(videos: []));
  late ProviderContainer container;
  final ageVerification = AgeVerificationService(
    preferences: preferences,
    currentPubkeyHex: () => _policyViewer,
    onAdultContentVerificationChanged: () => container
        .read(adultContentVerificationVersionProvider.notifier)
        .increment(),
  );
  await tester.pumpWidget(
    testMaterialApp(
      home: Scaffold(body: VideoFeedPage(initialMode: initialMode)),
      mockSharedPreferences: preferences,
      mockAuthService: createMockAuthService(
        authState: AuthState.authenticated,
        currentPublicKeyHex: _policyViewer,
      ),
      mockProfileRepository: createMockProfileRepository(),
      additionalOverrides: [
        // Stable repository identities prove the Page owns safety invalidation.
        videosRepositoryProvider.overrideWith(
          (_) => currentRepository?.call() ?? videos,
        ),
        peopleListsRepositoryProvider.overrideWithValue(
          _emptyPeopleListsRepository(),
        ),
        curatedListRepositoryProvider.overrideWithValue(curated),
        ageVerificationServiceProvider.overrideWithValue(ageVerification),
        // Home mounts directly here, without app bootstrap starting its timer.
        startupPerformanceServiceProvider.overrideWithValue(
          _StartupPerformance(),
        ),
        ...overrides,
      ],
    ),
  );
  await tester.pumpAndSettle();
  await tester.runAsync(pumpEventQueue);
  await tester.pump();
  container = ProviderScope.containerOf(
    tester.element(find.byType(VideoFeedPage)),
  );
  final view = tester.element(find.byType(VideoFeedView));
  final feed = view.read<VideoFeedBloc>();
  final playback = view.read<VideoPlaybackStatusCubit>();
  expect(feed.state.status, VideoFeedStatus.success);
  expect(feed.state.source, const VideoFeedSource.forYou());
  expect(feed.isClosed, isFalse);
  expect(playback.isClosed, isFalse);
  verify(
    () => videos.getRecommendedVideos(
      userPubkey: _policyViewer,
      until: any(named: 'until'),
      skipCache: any(named: 'skipCache'),
      revalidate: any(named: 'revalidate'),
    ),
  ).called(1);
  return _SafetyPolicyHome(
    preferences: preferences,
    ageVerification: ageVerification,
    container: container,
    videos: videos,
    originalFeed: feed,
    originalPlayback: playback,
  );
}

class _PagePreferencesGate extends InMemorySharedPreferencesStore {
  _PagePreferencesGate(this.key, String value)
    : super.withData({'flutter.$key': value});
  final String key;
  final started = Completer<void>();
  final release = Completer<void>();
  final repaired = Completer<void>();
  bool _blocked = false;

  @override
  Future<bool> setValue(String valueType, String key, Object value) async {
    if (key == 'flutter.${this.key}' && value == 'forYou' && !_blocked) {
      _blocked = true;
      started.complete();
      await release.future;
    }
    final result = await super.setValue(valueType, key, value);
    if (_blocked &&
        key == 'flutter.${this.key}' &&
        value != 'forYou' &&
        !repaired.isCompleted) {
      repaired.complete();
    }
    return result;
  }
}

class _CacheDao implements CacheDao {
  @override
  Future<CacheEntry?> readEntry(String key) async => null;
  @override
  Future<void> write({
    required String key,
    required String payload,
    Duration? ttl,
  }) async {}
  @override
  Future<void> delete(String key) async {}
  @override
  Future<void> deletePrefix(String prefix) async {}
  @override
  Future<int> totalPayloadBytes() async => 0;
  @override
  Future<void> evictOldest(int bytesToFree) async {}
}

void main() {
  setUp(() {
    final originalPreferencesPlatform = SharedPreferencesStorePlatform.instance;
    addTearDown(() {
      SharedPreferences.setMockInitialValues({});
      SharedPreferencesStorePlatform.instance = originalPreferencesPlatform;
    });
  });

  group('VideoFeedPage account and repository identity', () {
    testWidgets(
      'seen-filter toggles replace Home while unrelated flags retain it',
      (
        tester,
      ) async {
        final home = await _mountSafetyPolicyHome(
          tester,
          initialMode: FeedMode.following,
        );
        final flags = home.container.read(featureFlagServiceProvider);
        final debugToolsEnabled = flags.isEnabled(FeatureFlag.debugTools);
        await flags.setFlag(FeatureFlag.debugTools, !debugToolsEnabled);
        await tester.pumpAndSettle();
        expect(flags.isEnabled(FeatureFlag.debugTools), !debugToolsEnabled);
        final view = tester.element(find.byType(VideoFeedView));
        expect(view.read<VideoFeedBloc>(), same(home.originalFeed));
        expect(
          view.read<VideoPlaybackStatusCubit>(),
          same(home.originalPlayback),
        );

        var previousFeed = home.originalFeed;
        for (final enabled in [false, true]) {
          await flags.setFlag(FeatureFlag.clientSeenFiltering, enabled);
          await tester.pumpAndSettle();
          await tester.runAsync(pumpEventQueue);
          await tester.pump();
          final feed = tester
              .element(find.byType(VideoFeedView))
              .read<VideoFeedBloc>();
          expect(previousFeed.isClosed, isTrue);
          expect(feed, isNot(same(previousFeed)));
          expect(feed.state.status, VideoFeedStatus.success);
          expect(feed.state.source, const VideoFeedSource.forYou());
          expect(
            home.preferences.getString('selected_feed_mode_$_policyViewer'),
            'forYou',
          );
          previousFeed = feed;
        }
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.runAsync(pumpEventQueue);
      },
    );

    testWidgets(
      'keeps one home feed visit while a filter change replaces Home',
      (tester) async {
        final home = await _mountSafetyPolicyHome(tester);
        final scope = tester.state(find.byType(ScreenFrameTraceScope));
        expect(
          (scope.widget as ScreenFrameTraceScope).screen,
          TracedScreen.homeFeed,
        );

        final flags = home.container.read(featureFlagServiceProvider);
        await flags.setFlag(
          FeatureFlag.clientSeenFiltering,
          !flags.isEnabled(FeatureFlag.clientSeenFiltering),
        );
        await tester.pumpAndSettle();
        await tester.runAsync(pumpEventQueue);
        await tester.pump();

        expect(home.originalFeed.isClosed, isTrue);
        expect(tester.state(find.byType(ScreenFrameTraceScope)), same(scope));
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.runAsync(pumpEventQueue);
      },
    );

    testWidgets('wires repository deletion notifications to the Home bloc', (
      tester,
    ) async {
      final removals = StreamController<String>.broadcast();
      addTearDown(removals.close);
      final home = await _mountSafetyPolicyHome(
        tester,
        removals: removals.stream,
      );
      await _loadRemovalVideos(tester, home);
      final deletedId = '2' * 64;
      expect(removals.hasListener, isTrue);
      removals.add(deletedId);
      await tester.runAsync(pumpEventQueue);
      expect(home.originalFeed.state.videos, [_removalVideo('1')]);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.runAsync(pumpEventQueue);
      expect(removals.hasListener, isFalse);
    });

    testWidgets(
      'keeps a video the dead-media guard marked broken out of a Home refresh',
      (tester) async {
        // #5953: the guard persists a moderation-blocked 404 in the
        // per-account BrokenVideoTracker, which every other feed honours.
        final home = await _mountSafetyPolicyHome(tester);
        final brokenId = '2' * 64;
        final tracker = (await tester.runAsync(
          () => home.container.read(brokenVideoTrackerProvider.future),
        ))!;
        await tester.runAsync(
          () => tracker.markVideoBroken(
            brokenId,
            'Confirmed moderation-unavailable 404 in home feed',
          ),
        );
        expect(tracker.isVideoBroken(brokenId), isTrue);
        when(
          () => home.videos.getRecommendedVideos(
            userPubkey: any(named: 'userPubkey'),
            until: any(named: 'until'),
            skipCache: any(named: 'skipCache'),
            revalidate: any(named: 'revalidate'),
          ),
        ).thenAnswer(
          (_) async =>
              HomeFeedResult(videos: [_removalVideo('1'), _removalVideo('2')]),
        );

        home.originalFeed.add(const VideoFeedRefreshRequested());
        await tester.runAsync(pumpEventQueue);

        expect(home.originalFeed.state.videos, [_removalVideo('1')]);
      },
    );

    testWidgets(
      'drops a Home video the viewer has not reached once it is marked broken',
      (tester) async {
        // #5953: a mark ahead of the viewer leaves the session at once.
        final home = await _mountSafetyPolicyHome(tester);
        await _loadRemovalVideos(tester, home);
        final tracker = (await tester.runAsync(
          () => home.container.read(brokenVideoTrackerProvider.future),
        ))!;

        await tester.runAsync(
          () => tracker.markVideoBroken(
            '2' * 64,
            'Confirmed moderation-unavailable 404 in home feed',
          ),
        );
        await tester.runAsync(pumpEventQueue);

        expect(tracker.isVideoBroken('2' * 64), isTrue);
        expect(home.originalFeed.state.videos, [_removalVideo('1')]);
      },
    );

    testWidgets(
      'drops a Home video marked in an earlier session once the tracker loads',
      (tester) async {
        // Home can serve its list before the tracker resolves, so nothing
        // filtered the ids the tracker then loads from storage.
        final trackerLoaded = Completer<BrokenVideoTracker>();
        final home = await _mountSafetyPolicyHome(
          tester,
          overrides: [
            brokenVideoTrackerProvider.overrideWith(
              (_) => trackerLoaded.future,
            ),
          ],
        );
        await _loadRemovalVideos(tester, home);
        final tracker = BrokenVideoTracker(ownerPubkey: _policyViewer);
        await tester.runAsync(() async {
          await tracker.initialize();
          await tracker.markVideoBroken(
            '2' * 64,
            'Marked in an earlier session',
          );
        });

        trackerLoaded.complete(tracker);
        await tester.runAsync(pumpEventQueue);

        expect(home.originalFeed.state.videos, [_removalVideo('1')]);
      },
    );

    testWidgets(
      'Classics resumes on the same video when a marked one comes before it',
      (tester) async {
        final home = await _mountSafetyPolicyHome(
          tester,
          overrides: [adaptiveClassicsEnabledProvider.overrideWithValue(true)],
        );
        registerFallbackValue(
          const ClassicRecommendationsRequest(seed: 'fallback'),
        );
        registerFallbackValue(<VideoEvent>[]);
        when(() => home.videos.applyContentPreferences(any())).thenAnswer(
          (call) => call.positionalArguments.single as List<VideoEvent>,
        );
        when(
          () => home.videos.getClassicRecommendations(
            request: any(named: 'request'),
            userPubkey: any(named: 'userPubkey'),
            isCurrent: any(named: 'isCurrent'),
          ),
        ).thenAnswer(
          (_) async => HomeFeedResult(
            videos: [
              for (final digit in '1234'.split('')) _removalVideo(digit),
            ],
            paginationCursor: 'next',
            hasMore: true,
            recommendationPageCount: 1,
          ),
        );
        final tracker = (await tester.runAsync(
          () => home.container.read(brokenVideoTrackerProvider.future),
        ))!;
        await tester.runAsync(
          () => tracker.markVideoBroken('2' * 64, 'Confirmed unavailable'),
        );
        home.originalFeed.add(
          const VideoFeedSourceChanged(VideoFeedSource.classic()),
        );
        await tester.runAsync(pumpEventQueue);
        expect(home.originalFeed.state.videos, [
          _removalVideo('1'),
          _removalVideo('3'),
          _removalVideo('4'),
        ]);

        // Watch video 3, leave Classics, come back.
        home.originalFeed.add(const VideoFeedActiveIndexChanged(1));
        await tester.runAsync(pumpEventQueue);
        home.originalFeed.add(
          const VideoFeedSourceChanged(VideoFeedSource.forYou()),
        );
        await tester.runAsync(pumpEventQueue);
        home.originalFeed.add(
          const VideoFeedSourceChanged(VideoFeedSource.classic()),
        );
        await tester.runAsync(pumpEventQueue);

        final state = home.originalFeed.state;
        expect(state.videos[state.currentIndex], _removalVideo('3'));
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.runAsync(pumpEventQueue);
      },
    );

    testWidgets(
      'Classics drops unavailable videos ahead without moving the active slot',
      (tester) async {
        final trackerLoaded = Completer<BrokenVideoTracker>();
        final home = await _mountSafetyPolicyHome(
          tester,
          overrides: [
            adaptiveClassicsEnabledProvider.overrideWithValue(true),
            brokenVideoTrackerProvider.overrideWith(
              (_) => trackerLoaded.future,
            ),
          ],
        );
        registerFallbackValue(
          const ClassicRecommendationsRequest(seed: 'fallback'),
        );
        registerFallbackValue(<VideoEvent>[]);
        when(() => home.videos.applyContentPreferences(any())).thenAnswer(
          (call) => call.positionalArguments.single as List<VideoEvent>,
        );
        when(
          () => home.videos.getClassicRecommendations(
            request: any(named: 'request'),
            userPubkey: any(named: 'userPubkey'),
            isCurrent: any(named: 'isCurrent'),
          ),
        ).thenAnswer(
          (_) async => HomeFeedResult(
            videos: [
              for (final digit in '1234'.split('')) _removalVideo(digit),
            ],
            paginationCursor: 'next',
            hasMore: true,
          ),
        );

        home.originalFeed.add(
          const VideoFeedSourceChanged(VideoFeedSource.classic()),
        );
        await tester.runAsync(pumpEventQueue);
        home.originalFeed.add(const VideoFeedActiveIndexChanged(1));
        await tester.runAsync(pumpEventQueue);
        expect(home.originalFeed.state.videos[1], _removalVideo('2'));

        final tracker = BrokenVideoTracker(ownerPubkey: _policyViewer);
        addTearDown(tracker.dispose);
        await tester.runAsync(() async {
          await tracker.initialize();
          for (final digit in '124'.split('')) {
            await tracker.markVideoBroken(
              digit * 64,
              'Marked in an earlier session',
            );
          }
        });
        trackerLoaded.complete(tracker);
        await tester.runAsync(pumpEventQueue);

        expect(home.originalFeed.state.videos, [
          _removalVideo('1'),
          _removalVideo('2'),
          _removalVideo('3'),
        ]);
        expect(home.originalFeed.state.currentIndex, 1);

        home.originalFeed.add(
          const VideoFeedSourceChanged(VideoFeedSource.forYou()),
        );
        await tester.runAsync(pumpEventQueue);
        home.originalFeed.add(
          const VideoFeedSourceChanged(VideoFeedSource.classic()),
        );
        await tester.runAsync(pumpEventQueue);

        expect(home.originalFeed.state.videos, [_removalVideo('3')]);
        expect(home.originalFeed.state.currentIndex, 0);
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.runAsync(pumpEventQueue);
      },
    );

    testWidgets(
      'same-account repository replacement keeps Home alive and follows removals',
      (tester) async {
        final oldRemovals = StreamController<String>.broadcast();
        final newRemovals = StreamController<String>.broadcast();
        addTearDown(oldRemovals.close);
        addTearDown(newRemovals.close);
        VideosRepository? currentRepository;
        final home = await _mountSafetyPolicyHome(
          tester,
          removals: oldRemovals.stream,
          currentRepository: () => currentRepository,
        );
        final replacement = _VideosRepository(removals: newRemovals.stream);
        currentRepository = replacement;
        home.container.invalidate(videosRepositoryProvider);
        await tester.pumpAndSettle();
        await tester.runAsync(pumpEventQueue);
        await tester.pump();
        final view = tester.element(find.byType(VideoFeedView));
        expect(view.read<VideoFeedBloc>(), same(home.originalFeed));
        expect(
          view.read<VideoPlaybackStatusCubit>(),
          same(home.originalPlayback),
        );
        expect(oldRemovals.hasListener, isFalse);
        expect(newRemovals.hasListener, isTrue);
        await _loadRemovalVideos(tester, home);
        oldRemovals.add('1' * 64);
        newRemovals.add('2' * 64);
        await tester.runAsync(pumpEventQueue);
        expect(home.originalFeed.state.videos, [_removalVideo('1')]);
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.runAsync(pumpEventQueue);
        expect(newRemovals.hasListener, isFalse);
      },
    );

    testWidgets('Classics sends no viewer while analytics consent is off', (
      tester,
    ) async {
      // The shared fixture never initializes, so consent stays off.
      final home = await _mountSafetyPolicyHome(
        tester,
        overrides: [adaptiveClassicsEnabledProvider.overrideWithValue(true)],
      );
      final requests = _stubClassicRecommendations(home.videos);
      home.originalFeed.add(
        const VideoFeedSourceChanged(VideoFeedSource.classic()),
      );
      await tester.runAsync(pumpEventQueue);
      expect(requests, isNotEmpty);
      expect(requests.map((request) => request.$2), everyElement(isNull));
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.runAsync(pumpEventQueue);
    });

    testWidgets(
      'Classics follows a same-account analytics rebuild without rebuilding '
      'Home',
      (tester) async {
        AnalyticsService analytics = _ConsentingAnalytics();
        final home = await _mountSafetyPolicyHome(
          tester,
          overrides: [
            adaptiveClassicsEnabledProvider.overrideWithValue(true),
            analyticsServiceProvider.overrideWith((ref) {
              final current = analytics;
              ref.onDispose(current.dispose);
              return current;
            }),
          ],
        );
        final requests = _stubClassicRecommendations(home.videos);
        final retired = analytics;
        final replacement = _ConsentingAnalytics();
        analytics = replacement;
        home.container.invalidate(analyticsServiceProvider);
        await tester.pumpAndSettle();
        await tester.runAsync(pumpEventQueue);
        await tester.pump();
        expect(
          tester.element(find.byType(VideoFeedView)).read<VideoFeedBloc>(),
          same(home.originalFeed),
        );
        expect(retired.initializedAnalyticsConsent, isFalse);

        // Assert bloc transitions without pumping frames, as the removal
        // tests do: Classics playback needs no native media here.
        home.originalFeed.add(
          const VideoFeedSourceChanged(VideoFeedSource.classic()),
        );
        await tester.runAsync(pumpEventQueue);
        expect(requests, isNotEmpty);
        expect(requests.last.$2, _policyViewer);

        requests.clear();
        replacement.recordRecommendationInteraction(
          ClassicFeedInteraction(
            videoId: _removalVideo('2').id,
            signal: ClassicFeedSignal.positive,
          ),
        );
        await tester.runAsync(pumpEventQueue);
        expect(requests, isNotEmpty);
        expect(requests.last.$2, _policyViewer);
        expect(
          requests.last.$1.recentInteractions.map((i) => i.videoId),
          contains(_removalVideo('2').id),
        );
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.runAsync(pumpEventQueue);
      },
    );

    testWidgets(
      'legacy false flags preserve people sources and saved selection',
      (tester) async {
        await CacheSync.init(dao: _CacheDao());
        final viewer = 'a' * 64;
        final owner = 'b' * 64;
        final member = 'c' * 64;
        final source = VideoFeedSource.peopleList(
          listId: 'crew',
          listName: 'Flag Crew',
          listOwnerPubkey: owner,
        );
        final selectionKey = 'selected_feed_mode_$viewer';
        SharedPreferences.setMockInitialValues({
          selectionKey: FeedModePreferenceStore.storageValueFor(source),
          'ff_curatedLists': false,
          'ff_profileListFeatures': false,
        });
        final prefs = await SharedPreferences.getInstance();
        final people = _PeopleListsRepository();
        final videos = _VideosRepository();
        final curated = _CuratedListRepository();
        final copies = [
          PeopleListSearchResult(
            ownerPubkey: owner,
            list: UserList(
              id: 'crew',
              name: 'Flag Crew',
              pubkeys: [member],
              createdAt: DateTime.utc(2026),
              updatedAt: DateTime.utc(2026),
            ),
          ),
        ];
        final stream =
            StreamController<List<PeopleListSearchResult>>.broadcast();
        addTearDown(stream.close);
        when(
          () => people.readFollowedLists(viewerPubkey: viewer),
        ).thenAnswer((_) async => copies);
        when(
          () => people.watchFollowedLists(viewerPubkey: viewer),
        ).thenAnswer((_) => stream.stream);
        when(
          () => people.isFollowingList(
            viewerPubkey: viewer,
            ownerPubkey: owner,
            listId: 'crew',
          ),
        ).thenAnswer((_) async => true);
        when(
          () => people.syncFollowedLists(
            viewerPubkey: any(named: 'viewerPubkey'),
            isCancelled: any(named: 'isCancelled'),
          ),
        ).thenAnswer((_) async {});
        when(curated.getSubscribedLists).thenReturn([]);
        when(() => curated.subscriptionSnapshots).thenAnswer(
          (_) => const Stream<CuratedListSubscriptionSnapshot>.empty(),
        );
        when(
          () => videos.getVideosByAuthors(
            authorPubkeys: any(named: 'authorPubkeys'),
            until: any(named: 'until'),
          ),
        ).thenAnswer((_) async => []);
        when(
          () => videos.getRecommendedVideos(
            userPubkey: any(named: 'userPubkey'),
            until: any(named: 'until'),
            skipCache: any(named: 'skipCache'),
            revalidate: any(named: 'revalidate'),
          ),
        ).thenAnswer((_) async => const HomeFeedResult(videos: []));
        await tester.pumpWidget(
          testMaterialApp(
            home: const Scaffold(body: VideoFeedPage()),
            mockSharedPreferences: prefs,
            mockAuthService: createMockAuthService(
              authState: AuthState.authenticated,
              currentPublicKeyHex: viewer,
            ),
            mockProfileRepository: createMockProfileRepository(),
            additionalOverrides: [
              videosRepositoryProvider.overrideWithValue(videos),
              curatedListRepositoryProvider.overrideWithValue(curated),
              peopleListsRepositoryProvider.overrideWithValue(people),
            ],
          ),
        );
        await tester.pumpAndSettle();
        await tester.runAsync(pumpEventQueue);
        await tester.pump();
        final original = tester
            .element(find.byType(VideoFeedView))
            .read<VideoFeedBloc>();
        expect(original.state.source, source);
        expect(find.text('Flag Crew'), findsOneWidget);
        expect(stream.hasListener, isTrue);
        await tester.tap(find.text('Flag Crew'));
        await tester.pumpAndSettle();
        expect(find.text('Flag Crew'), findsNWidgets(2));
        Navigator.of(tester.element(find.byType(VideoFeedView))).pop();
        await tester.pumpAndSettle();
        expect(original.state.source, source);
        expect(original.state.followedPeopleLists, copies);
        expect(stream.hasListener, isTrue);
        expect(
          prefs.getString(selectionKey),
          FeedModePreferenceStore.storageValueFor(source),
        );
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.runAsync(pumpEventQueue);
        await tester.pump();
        expect(original.isClosed, isTrue);
        expect(stream.hasListener, isFalse);
      },
    );

    testWidgets(
      'Home is rebuilt for another account',
      (tester) async {
        await CacheSync.init(dao: _CacheDao());
        final firstViewer = 'a' * 64;
        final secondViewer = 'd' * 64;
        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();
        final videos = _VideosRepository();
        final curated = _CuratedListRepository();
        final authStates = StreamController<AuthState>.broadcast();
        addTearDown(authStates.close);
        final auth = createMockAuthService(
          authState: AuthState.authenticated,
          currentPublicKeyHex: firstViewer,
        );
        when(() => auth.authStateStream).thenAnswer((_) => authStates.stream);
        when(curated.getSubscribedLists).thenReturn([]);
        when(() => curated.subscriptionSnapshots).thenAnswer(
          (_) => const Stream<CuratedListSubscriptionSnapshot>.empty(),
        );
        when(
          () => videos.getRecommendedVideos(
            userPubkey: any(named: 'userPubkey'),
            until: any(named: 'until'),
            skipCache: any(named: 'skipCache'),
            revalidate: any(named: 'revalidate'),
          ),
        ).thenAnswer((_) async => const HomeFeedResult(videos: []));
        await tester.pumpWidget(
          testMaterialApp(
            home: const Scaffold(body: VideoFeedPage()),
            mockSharedPreferences: prefs,
            mockAuthService: auth,
            mockProfileRepository: createMockProfileRepository(),
            additionalOverrides: [
              videosRepositoryProvider.overrideWithValue(videos),
              peopleListsRepositoryProvider.overrideWithValue(
                _emptyPeopleListsRepository(),
              ),
              curatedListRepositoryProvider.overrideWithValue(curated),
            ],
          ),
        );
        await tester.pumpAndSettle();
        await tester.runAsync(pumpEventQueue);
        await tester.pump();
        final original = tester
            .element(find.byType(VideoFeedView))
            .read<VideoFeedBloc>();

        when(() => auth.currentPublicKeyHex).thenReturn(secondViewer);
        authStates
          ..add(AuthState.checking)
          ..add(AuthState.authenticated);
        await tester.runAsync(pumpEventQueue);
        await tester.pumpAndSettle();
        await tester.runAsync(pumpEventQueue);
        await tester.pump();

        final switched = tester
            .element(find.byType(VideoFeedView))
            .read<VideoFeedBloc>();
        expect(identical(switched, original), isFalse);
        expect(original.isClosed, isTrue);
        expect(tester.takeException(), isNull);
      },
    );
  });

  group('VideoFeedPage curated repository identity', () {
    group('safety policy boundary', () {
      for (final policy in _SafetyPolicy.values) {
        testWidgets(
          '${policy.name} restriction replaces Home and playback with stable repositories',
          (tester) async {
            final home = await _mountSafetyPolicyHome(tester);
            switch (policy) {
              case _SafetyPolicy.adultVerification:
                expect(home.ageVerification.isAdultContentVerified, isTrue);
                expect(
                  await home.ageVerification.setAdultContentVerified(false),
                  isTrue,
                );
                expect(home.ageVerification.isAdultContentVerified, isFalse);
                expect(
                  home.container.read(adultContentVerificationVersionProvider),
                  1,
                );
              case _SafetyPolicy.captureProvenance:
                home.container.read(videoProvenanceFilterVersionProvider);
                final service = home.container.read(
                  videoProvenanceFilterServiceProvider,
                );
                expect(service.showVerifiedOnly, isFalse);
                await service.setShowVerifiedOnly(true);
                expect(service.showVerifiedOnly, isTrue);
                expect(
                  home.container.read(videoProvenanceFilterVersionProvider),
                  1,
                );
            }
            await tester.pumpAndSettle();
            await tester.runAsync(pumpEventQueue);
            await tester.pump();
            final view = tester.element(find.byType(VideoFeedView));
            final replacement = view.read<VideoFeedBloc>();
            final playback = view.read<VideoPlaybackStatusCubit>();
            expect(replacement, isNot(same(home.originalFeed)));
            expect(playback, isNot(same(home.originalPlayback)));
            expect(home.originalFeed.isClosed, isTrue);
            expect(home.originalPlayback.isClosed, isTrue);
            expect(replacement.state.status, VideoFeedStatus.success);
            expect(replacement.state.source, const VideoFeedSource.forYou());
            expect(
              home.preferences.getString('selected_feed_mode_$_policyViewer'),
              'forYou',
            );
            verify(
              () => home.videos.getRecommendedVideos(
                userPubkey: _policyViewer,
                until: any(named: 'until'),
                skipCache: any(named: 'skipCache'),
                revalidate: any(named: 'revalidate'),
              ),
            ).called(1);
            expect(tester.takeException(), isNull);
            await tester.pumpWidget(const SizedBox.shrink());
            await tester.runAsync(pumpEventQueue);
            await tester.pump();
            expect(replacement.isClosed, isTrue);
            expect(playback.isClosed, isTrue);
          },
        );
      }

      testWidgets('verification start-up notice retains Home and playback', (
        tester,
      ) async {
        final home = await _mountSafetyPolicyHome(tester);
        // Start-up retires legacy keys and notifies without changing the
        // verified state, which happens on every cold start.
        await tester.runAsync(home.ageVerification.initialize);
        expect(home.container.read(adultContentVerificationVersionProvider), 1);
        expect(home.ageVerification.isAdultContentVerified, isTrue);
        await tester.pumpAndSettle();
        await tester.runAsync(pumpEventQueue);
        await tester.pump();

        final view = tester.element(find.byType(VideoFeedView));
        expect(view.read<VideoFeedBloc>(), same(home.originalFeed));
        expect(
          view.read<VideoPlaybackStatusCubit>(),
          same(home.originalPlayback),
        );
        expect(home.originalFeed.isClosed, isFalse);
        verifyNever(
          () => home.videos.getRecommendedVideos(
            userPubkey: _policyViewer,
            until: any(named: 'until'),
            skipCache: any(named: 'skipCache'),
            revalidate: any(named: 'revalidate'),
          ),
        );
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.runAsync(pumpEventQueue);
        await tester.pump();
      });

      testWidgets('unrelated blocklist sync retains Home and playback', (
        tester,
      ) async {
        final home = await _mountSafetyPolicyHome(tester);
        const unrelatedAuthor =
            'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff';
        final blocklist = home.container.read(
          contentBlocklistRepositoryProvider,
        );
        expect(blocklist.isBlocked(unrelatedAuthor), isFalse);
        await blocklist.blockUser(unrelatedAuthor, ourPubkey: _policyViewer);
        await tester.pumpAndSettle();
        await tester.runAsync(pumpEventQueue);
        await tester.pump();
        expect(blocklist.isBlocked(unrelatedAuthor), isTrue);
        expect(home.container.read(blocklistVersionProvider), 1);
        final view = tester.element(find.byType(VideoFeedView));
        expect(view.read<VideoFeedBloc>(), same(home.originalFeed));
        expect(
          view.read<VideoPlaybackStatusCubit>(),
          same(home.originalPlayback),
        );
        expect(home.originalFeed.isClosed, isFalse);
        expect(home.originalPlayback.isClosed, isFalse);
        expect(home.originalFeed.state.source, const VideoFeedSource.forYou());
        expect(
          home.preferences.getString('selected_feed_mode_$_policyViewer'),
          'forYou',
        );
        verifyNever(
          () => home.videos.getRecommendedVideos(
            userPubkey: _policyViewer,
            until: any(named: 'until'),
            skipCache: any(named: 'skipCache'),
            revalidate: any(named: 'revalidate'),
          ),
        );
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.runAsync(pumpEventQueue);
        await tester.pump();
        expect(home.originalFeed.isClosed, isTrue);
        expect(home.originalPlayback.isClosed, isTrue);
      });
    });

    testWidgets(
      'curated repository replacement closes old Home and restores from the new snapshot',
      (tester) async {
        await CacheSync.init(dao: _CacheDao());
        final viewer = 'a' * 64;
        final author = 'b' * 64;
        final originalList = CuratedList(
          id: 'crew',
          pubkey: author,
          name: 'Original Crew',
          videoEventIds: [author],
          createdAt: DateTime.utc(2026),
          updatedAt: DateTime.utc(2026),
        );
        final source = VideoFeedSource.subscribedList(
          listId: originalList.authorScopedId,
          listName: originalList.name,
        );
        final key = 'selected_feed_mode_$viewer';
        SharedPreferences.setMockInitialValues({
          key: FeedModePreferenceStore.storageValueFor(source),
        });
        final prefs = await SharedPreferences.getInstance();
        final videos = _VideosRepository();
        final originalRepository = _CuratedListRepository();
        final replacementRepository = _CuratedListRepository();
        final originalSnapshots =
            StreamController<CuratedListSubscriptionSnapshot>.broadcast();
        final replacementSnapshots =
            StreamController<CuratedListSubscriptionSnapshot>.broadcast();
        addTearDown(originalSnapshots.close);
        addTearDown(replacementSnapshots.close);
        final initialSnapshot = CuratedListSubscriptionSnapshot(
          lists: [originalList],
          isComplete: true,
        );
        final emptySnapshot = CuratedListSubscriptionSnapshot(
          lists: const [],
          isComplete: true,
        );
        for (final (repository, snapshot, stream) in [
          (originalRepository, initialSnapshot, originalSnapshots.stream),
          (replacementRepository, emptySnapshot, replacementSnapshots.stream),
        ]) {
          when(repository.getSubscribedLists).thenReturn(snapshot.lists);
          when(() => repository.subscriptionSnapshot).thenReturn(snapshot);
          when(
            () => repository.subscriptionSnapshots,
          ).thenAnswer((_) => stream);
          when(
            () => repository.hasCompleteSubscriptionSnapshot,
          ).thenReturn(true);
        }
        when(
          () => originalRepository.getListById(originalList.authorScopedId),
        ).thenReturn(originalList);
        when(
          () => replacementRepository.getListById(originalList.authorScopedId),
        ).thenReturn(null);
        when(
          () => originalRepository.getOrderedVideoIds(
            originalList.authorScopedId,
          ),
        ).thenReturn([author]);
        when(() => videos.getVideosForList(any())).thenAnswer((_) async => []);
        when(
          () => videos.getRecommendedVideos(
            userPubkey: any(named: 'userPubkey'),
            limit: any(named: 'limit'),
            until: any(named: 'until'),
            skipCache: any(named: 'skipCache'),
            revalidate: any(named: 'revalidate'),
          ),
        ).thenAnswer((_) async => const HomeFeedResult(videos: []));
        await tester.pumpWidget(
          testMaterialApp(
            home: ProviderScope(
              overrides: [
                curatedListRepositoryProvider.overrideWithValue(
                  originalRepository,
                ),
              ],
              child: const Scaffold(body: VideoFeedPage()),
            ),
            mockSharedPreferences: prefs,
            mockAuthService: createMockAuthService(
              authState: AuthState.authenticated,
              currentPublicKeyHex: viewer,
            ),
            mockProfileRepository: createMockProfileRepository(),
            additionalOverrides: [
              videosRepositoryProvider.overrideWithValue(videos),
              peopleListsRepositoryProvider.overrideWithValue(
                _emptyPeopleListsRepository(),
              ),
            ],
          ),
        );
        await tester.pumpAndSettle();
        await tester.runAsync(pumpEventQueue);
        await tester.pump();
        final original = tester
            .element(find.byType(VideoFeedView))
            .read<VideoFeedBloc>();
        final container = ProviderScope.containerOf(
          tester.element(find.byType(VideoFeedPage)),
        );
        expect(original.state.source, source);
        expect(original.state.status, VideoFeedStatus.success);
        expect(originalSnapshots.hasListener, isTrue);
        expect(find.text('Original Crew'), findsOneWidget);
        container.updateOverrides([
          curatedListRepositoryProvider.overrideWithValue(
            replacementRepository,
          ),
        ]);
        await tester.pumpAndSettle();
        await tester.runAsync(pumpEventQueue);
        await tester.pump();
        final replaced = tester
            .element(find.byType(VideoFeedView))
            .read<VideoFeedBloc>();
        expect(identical(replaced, original), isFalse);
        expect(original.isClosed, isTrue);
        expect(originalSnapshots.hasListener, isFalse);
        expect(replacementSnapshots.hasListener, isTrue);
        expect(replaced.state.source, const VideoFeedSource.forYou());
        expect(replaced.state.status, VideoFeedStatus.success);
        expect(replaced.state.subscribedLists, isEmpty);
        expect(find.text('Original Crew'), findsNothing);
        expect(prefs.getString(key), 'forYou');
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.runAsync(pumpEventQueue);
        await tester.pump();
        expect(replaced.isClosed, isTrue);
        expect(replacementSnapshots.hasListener, isFalse);
      },
    );
    for (final remount in [false, true]) {
      testWidgets(
        remount
            ? 'actual same-account Page remount retains accepted selection'
            : 'actual Home retains account coordinator across replacement during an old provisional write',
        (tester) async {
          await CacheSync.init(dao: _CacheDao());
          final viewer = 'a' * 64;
          final author = 'b' * 64;
          final list = CuratedList(
            id: 'crew',
            pubkey: author,
            name: 'Persistent Crew',
            videoEventIds: [author],
            createdAt: DateTime.utc(2026),
            updatedAt: DateTime.utc(2026),
          );
          final source = VideoFeedSource.subscribedList(
            listId: list.authorScopedId,
            listName: list.name,
          );
          final key = 'selected_feed_mode_$viewer';
          SharedPreferences.setMockInitialValues({});
          final gate = _PagePreferencesGate(
            key,
            FeedModePreferenceStore.storageValueFor(source),
          );
          SharedPreferencesStorePlatform.instance = gate;
          final prefs = await SharedPreferences.getInstance();
          addTearDown(() {
            if (!gate.release.isCompleted) gate.release.complete();
            SharedPreferences.setMockInitialValues({});
          });
          final originalRepository = CuratedListRepository(
            nostrClient: _Nostr(),
            funnelcakeApiClient: _Api(),
          );
          final replacementRepository = CuratedListRepository(
            nostrClient: _Nostr(),
            funnelcakeApiClient: _Api(),
          );
          originalRepository.setSubscribedLists([list]);
          replacementRepository.setSubscribedLists([list]);
          addTearDown(originalRepository.dispose);
          addTearDown(replacementRepository.dispose);
          final videos = _VideosRepository();
          when(
            () => videos.getVideosForList(any()),
          ).thenAnswer((_) async => []);
          when(
            () => videos.getRecommendedVideos(
              userPubkey: any(named: 'userPubkey'),
              limit: any(named: 'limit'),
              until: any(named: 'until'),
              skipCache: any(named: 'skipCache'),
              revalidate: any(named: 'revalidate'),
            ),
          ).thenAnswer((_) async => const HomeFeedResult(videos: []));
          final homeMounted = ValueNotifier(true);
          addTearDown(homeMounted.dispose);
          await tester.pumpWidget(
            testMaterialApp(
              home: ProviderScope(
                overrides: [
                  curatedListRepositoryProvider.overrideWithValue(
                    originalRepository,
                  ),
                ],
                child: ValueListenableBuilder<bool>(
                  valueListenable: homeMounted,
                  builder: (_, mounted, _) => mounted
                      ? const Scaffold(body: VideoFeedPage())
                      : const SizedBox.shrink(),
                ),
              ),
              mockSharedPreferences: prefs,
              mockAuthService: createMockAuthService(
                authState: AuthState.authenticated,
                currentPublicKeyHex: viewer,
              ),
              mockProfileRepository: createMockProfileRepository(),
              additionalOverrides: [
                videosRepositoryProvider.overrideWithValue(videos),
                peopleListsRepositoryProvider.overrideWithValue(
                  _emptyPeopleListsRepository(),
                ),
              ],
            ),
          );
          await tester.pumpAndSettle();
          await tester.runAsync(pumpEventQueue);
          await tester.pump();
          final originalElement = tester.element(find.byType(VideoFeedView));
          final original = originalElement.read<VideoFeedBloc>();
          final coordinator = originalElement
              .read<FeedModePersistenceCoordinator>();
          final container = ProviderScope.containerOf(
            tester.element(find.byType(VideoFeedPage)),
          );
          expect(original.state.source, source);
          expect(original.state.status, VideoFeedStatus.success);
          originalRepository.setSubscribedLists([]);
          await tester.runAsync(
            () => gate.started.future.timeout(const Duration(seconds: 5)),
          );
          expect(prefs.getString(key), 'forYou');
          if (remount) {
            homeMounted.value = false;
            await tester.pump();
            await tester.runAsync(pumpEventQueue);
          }
          container.updateOverrides([
            curatedListRepositoryProvider.overrideWithValue(
              replacementRepository,
            ),
          ]);
          if (remount) {
            homeMounted.value = true;
            await tester.pump();
          }
          await tester.pumpAndSettle();
          await tester.runAsync(pumpEventQueue);
          await tester.pump();
          final replacementElement = tester.element(find.byType(VideoFeedView));
          final replacement = replacementElement.read<VideoFeedBloc>();
          expect(identical(replacement, original), isFalse);
          expect(
            identical(
              replacementElement.read<FeedModePersistenceCoordinator>(),
              coordinator,
            ),
            isTrue,
          );
          expect(replacement.state.source, source);
          expect(replacement.state.status, VideoFeedStatus.success);
          await tester.runAsync(() async {
            gate.release.complete();
            await gate.repaired.future.timeout(const Duration(seconds: 5));
            await prefs.reload();
          });
          await tester.runAsync(pumpEventQueue);
          await tester.pumpAndSettle();
          expect(original.isClosed, isTrue);
          expect(replacement.state.source, source);
          expect(
            prefs.getString(key),
            FeedModePreferenceStore.storageValueFor(source),
          );
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.runAsync(pumpEventQueue);
          await tester.pump();
          expect(replacement.isClosed, isTrue);
          expect(
            () => FeedModePreferenceStore(
              sharedPreferences: prefs,
              userPubkey: viewer,
              followRepository: createMockFollowRepository(),
              curatedListRepository: replacementRepository,
              persistenceCoordinator: coordinator,
            ),
            throwsStateError,
          );
        },
      );
    }
  });
}
