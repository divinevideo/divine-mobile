// ABOUTME: Bounded re-issue policy for feed subscriptions the relay never served.
// ABOUTME: Owns the online-retry cycle and the consecutive-timeout budget.

import 'dart:async';

import 'package:openvine/services/connection_status_service.dart';
import 'package:openvine/services/video_event_service.dart';
import 'package:unified_logger/unified_logger.dart';

/// Re-issues the relay subscription for [type] using its last-known
/// parameters.
typedef FeedResubscribe = Future<void> Function(SubscriptionType type);

/// Hands [type] to the relay-ready retry, which owns the wait for a usable
/// relay rather than a usable network.
typedef FeedRelayNotReady = void Function(SubscriptionType type);

/// Re-issues feed subscriptions that failed, a few times, while online.
///
/// Serves two callers: a subscribe that failed with a connection error, and a
/// feed load whose relay never answered (#7124). Both need the same thing —
/// re-issue these filters a few times, but only while a relay is reachable —
/// and both need it to stop rather than run for the life of the process. A
/// subscribe that finds no relay at all never comes here; it goes straight to
/// the relay-ready retry, and so does anything waiting here once the pool
/// reads offline.
///
/// The two budgets are deliberately separate. [scheduleWhenOnline] counts
/// re-subscribe *calls that threw*, which bounds a subscribe that cannot even
/// be issued. Writing a REQ to a relay that then stays silent does not throw,
/// so that budget resets on every attempt and cannot bound a silent relay;
/// [recordFeedLoadTimeout] counts consecutive unanswered loads instead and is
/// what stops that loop.
class FeedRetryScheduler {
  FeedRetryScheduler({
    required ConnectionStatusService connectionService,
    required FeedResubscribe resubscribe,
    required FeedRelayNotReady onRelayNotReady,
    this.maxAttempts = 3,
    this.retryDelay = const Duration(seconds: 10),
  }) : _connectionService = connectionService,
       _resubscribe = resubscribe,
       _onRelayNotReady = onRelayNotReady;

  static const _logName = 'FeedRetryScheduler';

  final ConnectionStatusService _connectionService;
  final FeedResubscribe _resubscribe;
  final FeedRelayNotReady _onRelayNotReady;

  /// How many re-issues one cycle may attempt, and how many unanswered loads
  /// in a row a feed may cost before it is left alone.
  final int maxAttempts;

  /// Gap between attempts within a cycle.
  final Duration retryDelay;

  Timer? _retryTimer;
  final Set<SubscriptionType> _typesAwaitingRetry = {};
  int _attempts = 0;

  /// Feed loads that hit the deadline in a row without the relay ever
  /// answering, per type.
  final Map<SubscriptionType, int> _consecutiveTimeouts = {};

  /// Attempts spent in the current cycle, for diagnostics.
  int get attempts => _attempts;

  /// Records a feed load that hit its deadline unanswered, and reports whether
  /// the feed still has budget to be re-issued.
  ///
  /// Cleared by [recordFeedServed], so a relay that recovers starts over with
  /// a full budget.
  bool recordFeedLoadTimeout(SubscriptionType type) {
    final consecutive = (_consecutiveTimeouts[type] ?? 0) + 1;
    _consecutiveTimeouts[type] = consecutive;
    if (consecutive <= maxAttempts) return true;
    Log.warning(
      'Giving up on ${type.name} after $consecutive consecutive timed-out '
      'loads; the next explicit subscribe starts over',
      name: _logName,
      category: LogCategory.video,
    );
    return false;
  }

  /// Records that [type] was actually served — a first event or an EOSE.
  void recordFeedServed(SubscriptionType type) {
    _consecutiveTimeouts.remove(type);
  }

  /// Clears the consecutive-timeout budget for [type].
  ///
  /// Call when the user (or another explicit path) starts a fresh subscribe
  /// for that feed. Without this, a type that exhausted [maxAttempts] stays
  /// latched until a load is actually served or [resetBudgets] runs — so a
  /// navigate-back after give-up would never re-arm auto-retry.
  void clearTimeoutBudget(SubscriptionType type) {
    _consecutiveTimeouts.remove(type);
  }

  /// Resets every timeout budget, for an explicit user-driven retry.
  void resetBudgets() {
    _consecutiveTimeouts.clear();
    _attempts = 0;
  }

  /// Schedule a retry of [subscriptionType] while a relay is reachable.
  ///
  /// The failed type is recorded so the retry re-establishes the feed that
  /// actually broke (with its original parameters) — previously the retry
  /// hardcoded the discovery feed, so home/hashtag/profile feeds never
  /// recovered through this path.
  ///
  /// A pool that reads offline is handed to the relay-ready retry at once,
  /// and again if it goes offline mid-cycle. Offline means no relay is
  /// reachable (#8331), and a pool that has spent its self-heal budget stays
  /// down until something dials it (#8992); polling `isOnline` here would wait
  /// on a flag that cannot flip without that dial.
  void scheduleWhenOnline(SubscriptionType subscriptionType) {
    _typesAwaitingRetry.add(subscriptionType);

    if (!_connectionService.isOnline) {
      _handOffToRelayReady();
      return;
    }

    // An active cycle keeps its attempt budget. A fresh cycle starts
    // over — previously an exhausted counter was never reset, leaving
    // retries dead for the rest of the session.
    if (_retryTimer?.isActive ?? false) return;
    _attempts = 0;

    _retryTimer = Timer.periodic(retryDelay, (timer) {
      if (!_connectionService.isOnline) {
        _handOffToRelayReady();
        return;
      }
      if (_typesAwaitingRetry.isEmpty || _attempts >= maxAttempts) {
        _typesAwaitingRetry.clear();
        timer.cancel();
        return;
      }

      _attempts++;
      Log.warning(
        'Attempting to resubscribe to '
        '${_typesAwaitingRetry.map((t) => t.name).join(", ")} '
        '(attempt $_attempts/$maxAttempts)',
        name: _logName,
        category: LogCategory.video,
      );

      for (final type in Set<SubscriptionType>.of(_typesAwaitingRetry)) {
        _retrySubscription(type, timer);
      }
    });
  }

  /// Ends the online cycle and hands every waiting feed to the relay-ready
  /// retry, which owns the wait for a usable relay and dials the pool.
  void _handOffToRelayReady() {
    final pending = Set<SubscriptionType>.of(_typesAwaitingRetry);
    _typesAwaitingRetry.clear();
    _retryTimer?.cancel();
    _retryTimer = null;
    _attempts = 0;
    Log.info(
      'No relay reachable; handing ${pending.map((t) => t.name).join(", ")} '
      'to the relay-ready retry',
      name: _logName,
      category: LogCategory.video,
    );
    pending.forEach(_onRelayNotReady);
  }

  /// Re-issue the relay subscription for [type] using its last-known
  /// parameters, forcing past duplicate detection (the dead subscription
  /// is still registered after an onError, so a non-forced call no-ops).
  void _retrySubscription(SubscriptionType type, Timer timer) {
    unawaited(
      _resubscribe(type)
          .then((_) {
            _typesAwaitingRetry.remove(type);
            Log.info(
              'Successfully resubscribed to ${type.name} feed',
              name: _logName,
              category: LogCategory.video,
            );
            if (_typesAwaitingRetry.isEmpty) {
              timer.cancel();
              _attempts = 0;
            }
          })
          .catchError((Object e) {
            Log.error(
              'Retry attempt $_attempts for ${type.name} failed: $e',
              name: _logName,
              category: LogCategory.video,
            );
            if (e is RelayNotReadyException) {
              _typesAwaitingRetry.remove(type);
              if (_typesAwaitingRetry.isEmpty) {
                timer.cancel();
                _attempts = 0;
              }
              _onRelayNotReady(type);
              return;
            }
            if (_attempts >= maxAttempts) {
              _typesAwaitingRetry.clear();
              timer.cancel();
              Log.warning(
                'Max retry attempts reached for video feed subscription',
                name: _logName,
                category: LogCategory.video,
              );
            }
          }),
    );
  }

  void dispose() {
    _retryTimer?.cancel();
    _retryTimer = null;
    _typesAwaitingRetry.clear();
  }
}
