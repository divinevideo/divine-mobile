// ABOUTME: Pins that a videoEventsProvider rebuild keeps the discovery feed
// ABOUTME: rendered instead of stranding it in a permanently loading state.

import 'package:content_blocklist_repository/content_blocklist_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/providers/app_foreground_provider.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/readiness_gate_providers.dart';
import 'package:openvine/providers/shared_preferences_provider.dart';
import 'package:openvine/providers/video_events_providers.dart';
import 'package:openvine/router/router.dart';
import 'package:openvine/services/video_event_service.dart';
import 'package:openvine/services/video_filter_builder.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockVideoEventService extends Mock implements VideoEventService {}

class _MockContentBlocklistRepository extends Mock
    implements ContentBlocklistRepository {}

class _FakeAppForeground extends AppForeground {
  @override
  bool build() => true;
}

/// Drives `isDiscoveryTabActiveProvider`, standing in for navigating away from
/// and back to the Explore tab.
final _tabActiveProvider = StateProvider<bool>((ref) => true);

/// Drives `contentFilterVersionProvider`, standing in for the user changing a
/// Show/Warn/Hide or video-shape preference.
final _filterVersionProvider = StateProvider<int>((ref) => 0);

class _TestFilterVersion extends ContentFilterVersion {
  @override
  int build() => ref.watch(_filterVersionProvider);
}

/// What `buildAsyncUI` renders for this state — the feed, or a spinner.
///
/// Asserting through `when` rather than on `isLoading` keeps the test about
/// what the user sees: `when` defaults to `skipLoadingOnReload: false`, so a
/// dependency-driven reload takes the loading branch even when a previous
/// value exists.
String _rendered(AsyncValue<List<VideoEvent>> state) => state.when(
  data: (videos) => 'feed(${videos.length})',
  loading: () => 'spinner',
  error: (_, _) => 'error',
);

VideoEvent _video(String id) {
  final now = DateTime.now();
  return VideoEvent(
    id: id,
    pubkey: 'author_$id',
    title: 'Video $id',
    content: 'content',
    videoUrl: 'https://example.com/$id.mp4',
    createdAt: now.millisecondsSinceEpoch,
    timestamp: now,
  );
}

ProviderContainer _createContainer(
  _MockVideoEventService service,
  SharedPreferences preferences,
) {
  final blocklist = _MockContentBlocklistRepository();
  when(() => blocklist.shouldFilterFromFeeds(any())).thenReturn(false);

  return ProviderContainer(
    overrides: [
      appReadyProvider.overrideWith((ref) => true),
      isDiscoveryTabActiveProvider.overrideWith(
        (ref) => ref.watch(_tabActiveProvider),
      ),
      contentFilterVersionProvider.overrideWith(_TestFilterVersion.new),
      sharedPreferencesProvider.overrideWithValue(preferences),
      contentBlocklistRepositoryProvider.overrideWithValue(blocklist),
      appForegroundProvider.overrideWith(_FakeAppForeground.new),
      videoEventServiceProvider.overrideWithValue(service),
      pageContextProvider.overrideWith(
        (ref) => Stream.value(
          const RouteContext(type: RouteType.explore, videoIndex: 0),
        ),
      ),
    ],
  );
}

void _setupMockDefaults(_MockVideoEventService mock, List<VideoEvent> videos) {
  when(() => mock.discoveryVideos).thenReturn(videos);
  when(() => mock.isSubscribed(any())).thenReturn(false);
  when(() => mock.filterVideoList(any())).thenAnswer(
    (invocation) => invocation.positionalArguments.first as List<VideoEvent>,
  );
  when(() => mock.addVideoUpdateListener(any())).thenReturn(() {});
  when(() => mock.addListener(any())).thenReturn(null);
  when(() => mock.removeListener(any())).thenReturn(null);
  // This mock exposes ChangeNotifier listener state to isolate the provider.
  // ignore: invalid_use_of_protected_member
  when(() => mock.hasListeners).thenReturn(false);
  when(
    () => mock.subscribeToDiscovery(
      limit: any(named: 'limit'),
      sortBy: any(named: 'sortBy'),
      nip50Sort: any(named: 'nip50Sort'),
      force: any(named: 'force'),
    ),
  ).thenAnswer((_) async {});
}

void main() {
  setUpAll(() {
    registerFallbackValue(SubscriptionType.discovery);
    registerFallbackValue(() {});
    registerFallbackValue(<VideoEvent>[]);
    registerFallbackValue(NIP50SortMode.hot);
  });

  group('VideoEventsProvider - rebuild', () {
    late _MockVideoEventService service;
    late SharedPreferences preferences;
    late ProviderContainer container;
    late List<VideoEvent> videos;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      preferences = await SharedPreferences.getInstance();
      videos = [_video('a'), _video('b')];
      service = _MockVideoEventService();
      _setupMockDefaults(service, videos);
      container = _createContainer(service, preferences);
    });

    tearDown(() => container.dispose());

    /// Reads the provider once the initial emission has settled, and fails
    /// loudly if the feed never loaded — otherwise a rebuild assertion could
    /// pass against a feed that was never rendered in the first place.
    Future<ProviderSubscription<AsyncValue<List<VideoEvent>>>>
    loadFeed() async {
      final subscription = container.listen(
        videoEventsProvider,
        (_, _) {},
        fireImmediately: true,
      );
      await pumpEventQueue();
      await pumpEventQueue();
      expect(
        _rendered(container.read(videoEventsProvider)),
        'feed(2)',
        reason: 'precondition: the feed must be loaded before the rebuild',
      );
      return subscription;
    }

    test(
      'leaving and returning to the Explore tab keeps the feed rendered',
      () async {
        final subscription = await loadFeed();

        container.read(_tabActiveProvider.notifier).state = false;
        await pumpEventQueue();
        container.read(_tabActiveProvider.notifier).state = true;
        await pumpEventQueue();
        await pumpEventQueue();

        expect(
          _rendered(container.read(videoEventsProvider)),
          'feed(2)',
          reason:
              'returning to Explore must not show a spinner over videos '
              'that are already loaded',
        );
        subscription.close();
      },
    );

    test('changing a content filter keeps the feed rendered', () async {
      final subscription = await loadFeed();

      container.read(_filterVersionProvider.notifier).state = 1;
      await pumpEventQueue();
      await pumpEventQueue();

      expect(
        _rendered(container.read(videoEventsProvider)),
        'feed(2)',
        reason:
            'a filter change rebuilds the provider; the unchanged list '
            'must still reach the new stream',
      );
      subscription.close();
    });

    test(
      'a subscriber that arrives after a rebuild still receives the feed',
      () async {
        final subscription = await loadFeed();

        container.read(_filterVersionProvider.notifier).state = 1;
        await pumpEventQueue();
        await pumpEventQueue();

        // Models a widget mounting after the rebuild, which depends on the
        // replacement BehaviorSubject actually holding a value to replay.
        final lateStates = <AsyncValue<List<VideoEvent>>>[];
        final lateSubscription = container.listen(
          videoEventsProvider,
          (_, next) => lateStates.add(next),
          fireImmediately: true,
        );
        await pumpEventQueue();

        expect(lateStates, isNotEmpty);
        expect(
          lateStates.map(_rendered),
          everyElement('feed(2)'),
          reason:
              'the replacement subject must replay the current feed to a '
              'late subscriber',
        );
        lateSubscription.close();
        subscription.close();
      },
    );
  });
}
