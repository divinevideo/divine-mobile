// ABOUTME: App-shell providers for foreground-idle data warmups.
// ABOUTME: Warms adjacent surfaces and retires disposable caches while idle.

import 'dart:async';

import 'package:clock/clock.dart';
import 'package:db_client/db_client.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:funnelcake_api_client/funnelcake_api_client.dart';
import 'package:openvine/notifications/services/notification_refresh_coordinator.dart';
import 'package:openvine/providers/app_foreground_provider.dart';
import 'package:openvine/providers/curation_providers.dart';
import 'package:openvine/providers/database_provider.dart';
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
      final coordinator = ForegroundIdleWarmupCoordinator(
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
              // An account switch can land during the first preload; the
              // second would then fetch for an account that has left (#10291).
              if (!ref.mounted) return;
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
      ref.onDispose(coordinator.dispose);
      return coordinator;
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

const _retiredCacheStartupDelay = Duration(seconds: 10);
const _retiredCacheCleanupInterval = Duration(seconds: 1);
const _retiredCacheWorkBudget = Duration(milliseconds: 50);

/// The package-owned, resumable retired-cache cleanup operation.
final retiredEventCacheProvider = Provider<RetiredEventCache>(
  (ref) => RetiredEventCache(ref.watch(databaseProvider)),
);

/// Reclaims old event caches after startup, yielding between tiny SQL batches.
final retiredEventCacheCleanupSchedulerProvider =
    Provider<ForegroundIdleWarmupScheduler>((ref) {
      final activityGate = ref.watch(foregroundFeedActivityGateProvider);
      final cache = ref.watch(retiredEventCacheProvider);
      final notBefore = clock.now().add(_retiredCacheStartupDelay);
      late final ForegroundIdleWarmupScheduler scheduler;
      final coordinator = ForegroundIdleWarmupCoordinator(
        isForeground: () => ref.read(appForegroundProvider),
        isIdle: () => activityGate.isIdle,
        gateChanges: activityGate.changes,
        tasks: [
          ForegroundIdleWarmupTask(
            id: ForegroundIdleWarmupTaskId.retiredEventCache,
            cooldown: Duration.zero,
            shouldRun: () => !clock.now().isBefore(notBefore),
            run: () async {
              final budget = Stopwatch()..start();
              var hasMore = true;
              do {
                hasMore = await cache.pruneBatch();
              } while (hasMore &&
                  ref.mounted &&
                  ref.read(appForegroundProvider) &&
                  activityGate.isIdle &&
                  budget.elapsed < _retiredCacheWorkBudget);
              if (!hasMore) scheduler.stop();
            },
          ),
        ],
      );
      scheduler = ForegroundIdleWarmupScheduler(
        requestWarmup: (trigger) => coordinator.requestWarmup(trigger: trigger),
        interval: _retiredCacheCleanupInterval,
      );
      ref.onDispose(coordinator.dispose);
      ref.onDispose(scheduler.stop);
      return scheduler;
    });
