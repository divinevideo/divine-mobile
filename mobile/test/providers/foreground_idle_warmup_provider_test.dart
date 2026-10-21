// ABOUTME: Provider wiring tests for foreground-idle warmup tasks.
// ABOUTME: Verifies app-shell gates and dependency arguments without real IO.

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:funnelcake_api_client/funnelcake_api_client.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/notifications/services/notification_refresh_coordinator.dart';
import 'package:openvine/providers/app_foreground_provider.dart';
import 'package:openvine/providers/curation_providers.dart';
import 'package:openvine/providers/for_you_provider.dart';
import 'package:openvine/providers/foreground_idle_warmup_provider.dart';
import 'package:openvine/providers/new_videos_feed_provider.dart';
import 'package:openvine/providers/popular_videos_feed_provider.dart';
import 'package:openvine/services/foreground_idle_warmup_coordinator.dart';
import 'package:openvine/state/video_feed_state.dart';

class _MockNotificationRefreshCoordinator extends Mock
    implements NotificationRefreshCoordinator {}

class _AvailableFunnelcake extends FunnelcakeAvailable {
  @override
  Future<bool> build() async => true;
}

Completer<bool>? _funnelcakeAvailabilityCompleter;

class _LoadingFunnelcake extends FunnelcakeAvailable {
  @override
  Future<bool> build() => _funnelcakeAvailabilityCompleter!.future;
}

final _feedBuilds = <String>[];
const _expectedWarmupBuilds = [
  'forYou',
  'newVideos',
  'popular',
  'popular:native',
  'popular:classic',
];

class _TestForYouFeed extends ForYouFeed {
  @override
  Future<VideoFeedState> build() async {
    _feedBuilds.add('forYou');
    return const VideoFeedState(videos: [], hasMoreContent: false);
  }
}

class _TestNewVideosFeed extends NewVideosFeed {
  @override
  Future<VideoFeedState> build() async {
    _feedBuilds.add('newVideos');
    return const VideoFeedState(videos: [], hasMoreContent: false);
  }
}

Completer<void>? _newVideosBuildGate;

class _GatedNewVideosFeed extends NewVideosFeed {
  @override
  Future<VideoFeedState> build() async {
    _feedBuilds.add('newVideos');
    await _newVideosBuildGate!.future;
    return const VideoFeedState(videos: [], hasMoreContent: false);
  }
}

class _TestPopularVideosFeed extends PopularVideosFeed {
  @override
  Future<VideoFeedState> build() async {
    _feedBuilds.add('popular');
    return const VideoFeedState(videos: [], hasMoreContent: false);
  }

  @override
  Future<void> preloadVariant(PopularVideosVariant variant) async {
    _feedBuilds.add('popular:${variant.name}');
    if (variant == PopularVideosVariant.native) {
      await _nativePreloadGate?.future;
    }
  }
}

/// Holds the popular task inside its first preload step.
Completer<void>? _nativePreloadGate;

void main() {
  group('foregroundIdleWarmupCoordinatorProvider', () {
    late _MockNotificationRefreshCoordinator notificationCoordinator;

    ProviderContainer createContainer({
      bool funnelcakeAvailabilityLoading = false,
      bool newVideosGated = false,
    }) {
      when(
        () => notificationCoordinator.refresh(
          reason: NotificationRefreshReason.foregroundIdleWarmup,
        ),
      ).thenAnswer((_) async {});

      final container = ProviderContainer(
        overrides: [
          notificationRefreshCoordinatorProvider.overrideWithValue(
            notificationCoordinator,
          ),
          funnelcakeAvailableProvider.overrideWith(
            funnelcakeAvailabilityLoading
                ? _LoadingFunnelcake.new
                : _AvailableFunnelcake.new,
          ),
          forYouFeedProvider.overrideWith(_TestForYouFeed.new),
          newVideosFeedProvider.overrideWith(
            newVideosGated ? _GatedNewVideosFeed.new : _TestNewVideosFeed.new,
          ),
          popularVideosFeedProvider.overrideWith(_TestPopularVideosFeed.new),
        ],
      );
      addTearDown(container.dispose);
      return container;
    }

    setUp(() {
      notificationCoordinator = _MockNotificationRefreshCoordinator();
      _feedBuilds.clear();
      _funnelcakeAvailabilityCompleter = null;
      _newVideosBuildGate = null;
      _nativePreloadGate = null;
    });

    test(
      'a pass still running when the container is disposed ends quietly',
      () async {
        _newVideosBuildGate = Completer<void>();
        final container = createContainer(newVideosGated: true);
        await container.read(funnelcakeAvailableProvider.future);

        final pass = container
            .read(foregroundIdleWarmupCoordinatorProvider)
            .requestWarmup(trigger: ForegroundIdleWarmupTrigger.startupSettled);
        await pumpEventQueue();
        expect(_feedBuilds, ['forYou', 'newVideos']);

        // An in-place account switch disposes the outgoing container while
        // its startup pass is still inside a task (#10291).
        container.dispose();
        _newVideosBuildGate!.complete();

        await expectLater(
          pass.timeout(const Duration(seconds: 5)),
          completes,
        );
        expect(_feedBuilds, ['forYou', 'newVideos']);
      },
    );

    test(
      'an activity event queued before disposal does not read the provider',
      () async {
        _newVideosBuildGate = Completer<void>();
        final container = createContainer(newVideosGated: true);
        await container.read(funnelcakeAvailableProvider.future);

        final pass = container
            .read(foregroundIdleWarmupCoordinatorProvider)
            .requestWarmup(trigger: ForegroundIdleWarmupTrigger.startupSettled);
        await pumpEventQueue();
        expect(_feedBuilds, ['forYou', 'newVideos']);

        // The gate's stream delivers asynchronously, so this event reaches
        // the pass's gate listener only after the container is gone.
        container.read(foregroundFeedActivityGateProvider).markActive();
        container.dispose();
        await pumpEventQueue();
        _newVideosBuildGate!.complete();

        await expectLater(
          pass.timeout(const Duration(seconds: 5)),
          completes,
        );
        expect(_feedBuilds, ['forYou', 'newVideos']);
      },
    );

    test(
      'the popular task skips its second preload when the container is '
      'disposed during the first',
      () async {
        _nativePreloadGate = Completer<void>();
        final container = createContainer();
        await container.read(funnelcakeAvailableProvider.future);

        final pass = container
            .read(foregroundIdleWarmupCoordinatorProvider)
            .requestWarmup(trigger: ForegroundIdleWarmupTrigger.startupSettled);
        await pumpEventQueue();
        expect(_feedBuilds, contains('popular:native'));

        // A switch landing inside the popular task: its second preload would
        // fetch for the account that has left (#10291).
        container.dispose();
        _nativePreloadGate!.complete();
        await pass.timeout(const Duration(seconds: 5));

        expect(_feedBuilds, isNot(contains('popular:classic')));
      },
    );

    test('foreground=false gates all warmup work', () async {
      final container = createContainer();
      container.read(appForegroundProvider.notifier).setForeground(false);

      await container
          .read(foregroundIdleWarmupCoordinatorProvider)
          .requestWarmup(
            trigger: ForegroundIdleWarmupTrigger.videoPlaybackSettled,
          );

      expect(_feedBuilds, isEmpty);
      verifyNever(
        () => notificationCoordinator.refresh(
          reason: NotificationRefreshReason.foregroundIdleWarmup,
        ),
      );
    });

    test('recent foreground feed activity gates all warmup work', () async {
      final container = createContainer();
      container.read(foregroundFeedActivityGateProvider).markActive();

      await container
          .read(foregroundIdleWarmupCoordinatorProvider)
          .requestWarmup(
            trigger: ForegroundIdleWarmupTrigger.videoPlaybackSettled,
          );

      expect(_feedBuilds, isEmpty);
      verifyNever(
        () => notificationCoordinator.refresh(
          reason: NotificationRefreshReason.foregroundIdleWarmup,
        ),
      );
    });

    test('unresolved Funnelcake availability skips For You warmup', () async {
      _funnelcakeAvailabilityCompleter = Completer<bool>();
      final container = createContainer(
        funnelcakeAvailabilityLoading: true,
      );

      await container
          .read(foregroundIdleWarmupCoordinatorProvider)
          .requestWarmup(
            trigger: ForegroundIdleWarmupTrigger.videoPlaybackSettled,
          );

      expect(_feedBuilds, [
        'newVideos',
        'popular',
        'popular:native',
        'popular:classic',
      ]);

      _funnelcakeAvailabilityCompleter!.complete(true);
      await container.read(funnelcakeAvailableProvider.future);

      await container
          .read(foregroundIdleWarmupCoordinatorProvider)
          .requestWarmup(
            trigger: ForegroundIdleWarmupTrigger.periodicIdleCheck,
          );

      expect(_feedBuilds, [
        'newVideos',
        'popular',
        'popular:native',
        'popular:classic',
        'forYou',
      ]);
    });

    test('popular warmup preloads native and classic variants', () async {
      final container = createContainer();
      await container.read(funnelcakeAvailableProvider.future);

      await container
          .read(foregroundIdleWarmupCoordinatorProvider)
          .requestWarmup(
            trigger: ForegroundIdleWarmupTrigger.videoPlaybackSettled,
          );

      expect(_feedBuilds, _expectedWarmupBuilds);
    });

    test('notification warmup uses foreground idle warmup reason', () async {
      final container = createContainer();
      await container.read(funnelcakeAvailableProvider.future);

      await container
          .read(foregroundIdleWarmupCoordinatorProvider)
          .requestWarmup(
            trigger: ForegroundIdleWarmupTrigger.videoPlaybackSettled,
          );

      verify(
        () => notificationCoordinator.refresh(
          reason: NotificationRefreshReason.foregroundIdleWarmup,
        ),
      ).called(1);
    });
  });
}
