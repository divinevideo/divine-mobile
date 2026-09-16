// ABOUTME: App-shell providers for foreground-idle data warmups.
// ABOUTME: Warms existing feed and notification caches without prefetching media bytes.

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:funnelcake_api_client/funnelcake_api_client.dart';
import 'package:openvine/notifications/services/notification_refresh_coordinator.dart';
import 'package:openvine/providers/app_foreground_provider.dart';
import 'package:openvine/providers/curation_providers.dart';
import 'package:openvine/providers/for_you_provider.dart';
import 'package:openvine/providers/new_videos_feed_provider.dart';
import 'package:openvine/providers/popular_videos_feed_provider.dart';
import 'package:openvine/providers/provider_detached_future.dart';
import 'package:openvine/services/foreground_idle_warmup_coordinator.dart';

/// Tracks whether foreground feeds have recently been under user control.
class ForegroundFeedActivityGate {
  /// Creates a feed activity gate.
  ForegroundFeedActivityGate({Duration idleDelay = const Duration(seconds: 10)})
    : _idleDelay = idleDelay;

  final Duration _idleDelay;
  final _changes = StreamController<void>.broadcast();

  Timer? _idleTimer;
  bool _isIdle = true;

  /// Emits whenever foreground feed activity changes warmup eligibility.
  Stream<void> get changes => _changes.stream;

  /// Whether foreground warmup work may run.
  bool get isIdle => _isIdle;

  /// Marks the foreground feed active until [idleDelay] elapses with no update.
  void markActive() {
    _idleTimer?.cancel();
    if (_isIdle) {
      _isIdle = false;
      _changes.add(null);
    }
    _idleTimer = Timer(_idleDelay, () {
      _isIdle = true;
      _changes.add(null);
    });
  }

  /// Releases resources owned by the gate.
  void dispose() {
    _idleTimer?.cancel();
    runProviderDetached(
      _changes.close(),
      'close the foreground activity stream',
      logName: 'ForegroundFeedActivityGate',
    );
  }
}

/// Foreground feed activity gate used to keep warmups behind active swipes.
final foregroundFeedActivityGateProvider = Provider<ForegroundFeedActivityGate>(
  (ref) {
    final gate = ForegroundFeedActivityGate();
    ref.onDispose(gate.dispose);
    return gate;
  },
);

/// Coordinates low-priority data warmups for adjacent app surfaces.
final foregroundIdleWarmupCoordinatorProvider =
    Provider<ForegroundIdleWarmupCoordinator>((ref) {
      final activityGate = ref.watch(foregroundFeedActivityGateProvider);
      return ForegroundIdleWarmupCoordinator(
        isForeground: () => ref.read(appForegroundProvider),
        isIdle: () => activityGate.isIdle,
        gateChanges: activityGate.changes,
        tasks: [
          ForegroundIdleWarmupTask(
            id: ForegroundIdleWarmupTaskId.forYou,
            cooldown: const Duration(minutes: 10),
            shouldRun: () =>
                ref.read(funnelcakeAvailableProvider).asData?.value == true,
            run: () async {
              await ref.read(forYouFeedProvider.future);
            },
          ),
          ForegroundIdleWarmupTask(
            id: ForegroundIdleWarmupTaskId.newVideos,
            cooldown: const Duration(minutes: 10),
            run: () async {
              await ref.read(newVideosFeedProvider.future);
            },
          ),
          ForegroundIdleWarmupTask(
            id: ForegroundIdleWarmupTaskId.popular,
            cooldown: const Duration(minutes: 10),
            run: () async {
              await ref.read(popularVideosFeedProvider.future);
              final popular = ref.read(popularVideosFeedProvider.notifier);
              await popular.preloadVariant(PopularVideosVariant.native);
              await popular.preloadVariant(PopularVideosVariant.classic);
            },
          ),
          ForegroundIdleWarmupTask(
            id: ForegroundIdleWarmupTaskId.notifications,
            cooldown: const Duration(minutes: 1),
            run: () async {
              await ref
                  .read(notificationRefreshCoordinatorProvider)
                  ?.refresh(
                    reason: NotificationRefreshReason.foregroundIdleWarmup,
                  );
            },
          ),
        ],
      );
    });

/// Starts the foreground-idle warmup schedule for the app shell.
final foregroundIdleWarmupSchedulerProvider =
    Provider<ForegroundIdleWarmupScheduler>((ref) {
      final coordinator = ref.watch(foregroundIdleWarmupCoordinatorProvider);
      final scheduler = ForegroundIdleWarmupScheduler(
        requestWarmup: (trigger) => coordinator.requestWarmup(trigger: trigger),
      );
      ref.onDispose(scheduler.stop);
      return scheduler;
    });
