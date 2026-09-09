// ABOUTME: Coalesces authoritative notification refresh triggers.
// ABOUTME: Used by app resume and foreground push to keep snapshots fresh.

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:notification_repository/notification_repository.dart';
import 'package:openvine/notifications/providers/notification_repository_provider.dart';
import 'package:openvine/observability/crash_reporter.dart';
import 'package:openvine/services/crash_reporting_service.dart';
import 'package:unified_logger/unified_logger.dart';

/// Why an authoritative notification refresh was requested.
enum NotificationRefreshReason {
  /// App returned to foreground after background/inactive state.
  appResume,

  /// App is foreground and idle enough to opportunistically warm notifications.
  foregroundIdleWarmup,

  /// A foreground push arrived that may have a corresponding Inbox item.
  pushReceived,
}

/// Forwards an unexpected refresh failure to the crash reporter.
typedef NotificationRefreshErrorReporter = void Function(
  Object error,
  StackTrace stackTrace, {
  String? reason,
});

/// Coalesces notification refresh calls so independent liveness triggers do
/// not stampede Funnelcake.
class NotificationRefreshCoordinator {
  /// Crash reporting for the static fallback path (#4743). Assigned by
  /// `app_bootstrap`; tests assign a recording fake.
  static CrashReporter crashReporter = const SilentCrashReporter();

  /// Creates a refresh coordinator.
  ///
  /// [errorReporter] defaults to [CrashReportingService.recordError]; tests
  /// inject a recording fake.
  NotificationRefreshCoordinator({
    required NotificationRepository repository,
    Duration cooldown = const Duration(seconds: 30),
    Duration pushDebounce = const Duration(seconds: 3),
    Duration pushMaxWait = const Duration(seconds: 10),
    Duration pushMinimumInterval = const Duration(seconds: 10),
    DateTime Function()? now,
    NotificationRefreshErrorReporter? errorReporter,
  }) : _repository = repository,
       _cooldown = cooldown,
       _pushDebounce = pushDebounce,
       _pushMaxWait = pushMaxWait,
       _pushMinimumInterval = pushMinimumInterval,
       _now = now ?? DateTime.now,
       _reportError = errorReporter ?? _reportToCrashlytics;

  final NotificationRepository _repository;
  final Duration _cooldown;
  final Duration _pushDebounce;
  final Duration _pushMaxWait;
  final Duration _pushMinimumInterval;
  final DateTime Function() _now;
  final NotificationRefreshErrorReporter _reportError;

  DateTime? _lastSuccessAt;
  Future<void>? _inFlight;
  Timer? _pushDebounceTimer;
  Timer? _pushMaxWaitTimer;
  bool _disposed = false;

  /// Schedules one authoritative refresh after a foreground push burst ends.
  ///
  /// Every arrival resets the trailing debounce, while a separate maximum-wait
  /// timer prevents a sustained stream from postponing the refresh forever.
  /// Successful requests retain a short rate floor. The eventual refresh
  /// waits for an earlier refresh to finish and bypasses only the general
  /// success cooldown: the repository's deep-pagination protection still
  /// applies.
  void schedulePushRefresh() {
    if (_disposed) return;
    _pushDebounceTimer?.cancel();
    _pushDebounceTimer = Timer(_pushDebounce, _completePushBurst);
    _pushMaxWaitTimer ??= Timer(_pushMaxWait, _completePushBurst);
  }

  void _completePushBurst() {
    _pushDebounceTimer?.cancel();
    _pushDebounceTimer = null;
    _pushMaxWaitTimer?.cancel();
    _pushMaxWaitTimer = null;
    unawaited(_refreshAfterPushBurst());
  }

  /// Requests an authoritative first-page refresh.
  ///
  /// Returns the in-flight refresh if one already exists. Otherwise, unless
  /// [force] is true, skips when the snapshot is paginated beyond the first
  /// page (a first-page replace would collapse a feed the user scrolled
  /// deep into) or when inside [_cooldown] of the last *successful* refresh
  /// — a failed refresh does not consume the cooldown, so the next trigger
  /// retries immediately.
  Future<void> refresh({
    required NotificationRefreshReason reason,
    bool force = false,
  }) => _refresh(reason: reason, force: force);

  Future<void> _refresh({
    required NotificationRefreshReason reason,
    bool force = false,
    bool bypassCooldown = false,
  }) {
    final inFlight = _inFlight;
    if (inFlight != null) return inFlight;

    if (!force && _repository.hasPaginatedBeyondFirstPage) {
      Log.debug(
        'Skipping ${reason.name} refresh: snapshot is paginated beyond '
        'the first page',
        name: 'NotificationRefreshCoordinator',
        category: LogCategory.api,
      );
      return Future<void>.value();
    }

    final lastSuccessAt = _lastSuccessAt;
    if (!force &&
        !bypassCooldown &&
        lastSuccessAt != null &&
        _now().difference(lastSuccessAt) < _cooldown) {
      return Future<void>.value();
    }

    final future = _runRefresh(reason).whenComplete(() {
      _inFlight = null;
    });
    _inFlight = future;
    return future;
  }

  Future<void> _refreshAfterPushBurst() async {
    final inFlight = _inFlight;
    if (inFlight != null) await inFlight;
    if (_disposed) return;

    final lastSuccessAt = _lastSuccessAt;
    if (lastSuccessAt != null) {
      final elapsed = _now().difference(lastSuccessAt);
      if (elapsed < _pushMinimumInterval) {
        final remaining = _pushMinimumInterval - elapsed;
        _pushDebounceTimer?.cancel();
        _pushMaxWaitTimer?.cancel();
        _pushMaxWaitTimer = null;
        _pushDebounceTimer = Timer(remaining, _completePushBurst);
        return;
      }
    }

    await _refresh(
      reason: NotificationRefreshReason.pushReceived,
      bypassCooldown: true,
    );
  }

  /// Cancels pending burst work owned by this coordinator.
  void dispose() {
    _disposed = true;
    _pushDebounceTimer?.cancel();
    _pushDebounceTimer = null;
    _pushMaxWaitTimer?.cancel();
    _pushMaxWaitTimer = null;
  }

  Future<void> _runRefresh(NotificationRefreshReason reason) async {
    try {
      final applied = await _repository.refreshApplied();
      if (applied) {
        _lastSuccessAt = _now();
      }
    } on Exception catch (e, s) {
      // Typed FunnelcakeException (4xx/5xx/timeout) — expected domain
      // failures, NOT Reportable per .claude/rules/error_handling.md.
      Log.log(
        'Notification refresh failed (${reason.name}): $e',
        name: 'NotificationRefreshCoordinator',
        category: LogCategory.api,
        level: LogLevel.warning,
        error: e,
        stackTrace: s,
      );
    } catch (e, s) {
      if (e is StateError && _repository.isClosed) {
        // An account switch closed the repository mid-refresh; the
        // snapshot emit threw before any DAO write. Expected noise.
        Log.debug(
          'Notification refresh aborted (${reason.name}): '
          'repository closed',
          name: 'NotificationRefreshCoordinator',
          category: LogCategory.api,
        );
        return;
      }
      // Errors (StateError, TypeError, RangeError) are matrix-YES
      // invariant violations. The coordinator is app-layer, so direct
      // crash-reporter use is allowed.
      Log.error(
        'Notification refresh invariant failure (${reason.name}): $e',
        name: 'NotificationRefreshCoordinator',
        category: LogCategory.api,
        error: e,
        stackTrace: s,
      );
      _reportError(
        e,
        s,
        reason: 'NotificationRefreshCoordinator.${reason.name}',
      );
    }
  }

  static void _reportToCrashlytics(
    Object error,
    StackTrace stackTrace, {
    String? reason,
  }) {
    unawaited(
      NotificationRefreshCoordinator.crashReporter.recordError(
        error,
        stackTrace,
        reason: reason,
      ),
    );
  }
}

/// Provider for the active authenticated user's refresh coordinator.
final notificationRefreshCoordinatorProvider =
    Provider<NotificationRefreshCoordinator?>((ref) {
      final repository = ref.watch(notificationRepositoryProvider);
      if (repository == null) return null;
      final coordinator = NotificationRefreshCoordinator(
        repository: repository,
      );
      ref.onDispose(coordinator.dispose);
      return coordinator;
    });
