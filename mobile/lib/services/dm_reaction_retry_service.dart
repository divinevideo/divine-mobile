// ABOUTME: Sweep that re-drives undelivered DM reactions and removals via
// ABOUTME: DmReactionsRepository on foreground, connectivity, repository
// ABOUTME: nudges and a follow-up heartbeat, so a stable session still recovers.

import 'dart:async';

import 'package:dm_repository/dm_repository.dart';
import 'package:meta/meta.dart';
import 'package:openvine/services/crash_reporting_service.dart';
import 'package:unified_logger/unified_logger.dart';

/// Stable identifiers for swallowed-failure sites inside
/// [DmReactionRetryService]. Forwarded as the Crashlytics `reason:` suffix so
/// the dashboard aggregates per site. Colocated with the service (rather than a
/// separate file) so it stays out of the untested-services floor.
abstract class DmReactionRetryServiceReportableSites {
  /// Per-reaction throw in the sweep loop — `retry` raised an unexpected
  /// exception.
  static const String perReactionUnexpectedThrow =
      'DmReactionRetryService.perReactionUnexpectedThrow';

  /// Top-level sweep catch — the sweep loop or repository call raised before
  /// per-reaction dispatch completed.
  static const String sweepTopLevel = 'DmReactionRetryService.sweepTopLevel';
}

/// Backoff + budget configuration for [DmReactionRetryService].
///
/// Mirrors `OutgoingDmRetryConfig` (5 retries, 2 s → 5 min, 2× backoff) so
/// reaction and message retries behave the same. Retry accounting is kept in
/// memory rather than on the `dm_message_reactions` row, so the budget resets
/// on a cold start. The follow-up heartbeat spends that budget within a
/// session; it never extends it.
class DmReactionRetryConfig {
  /// Construct a retry config.
  const DmReactionRetryConfig({
    this.maxRetries = 5,
    this.initialDelay = const Duration(seconds: 2),
    this.maxDelay = const Duration(minutes: 5),
    this.backoffMultiplier = 2.0,
    this.interruptedPendingMinAge = const Duration(seconds: 30),
    this.followUpSweepGap = const Duration(seconds: 30),
  });

  /// Attempts a single reaction gets before the sweep drops it (a manual
  /// re-tap still works).
  final int maxRetries;

  /// Delay before the first retry after a failure.
  final Duration initialDelay;

  /// Ceiling for the exponential backoff gap.
  final Duration maxDelay;

  /// Growth factor applied per attempt.
  final double backoffMultiplier;

  /// A `'pending'` row younger than this is skipped to avoid unnecessary
  /// retry work while its original publish is likely still in flight.
  /// Older rows may be interrupted sends. A group publish can outlive this
  /// guard; the repository coalesces retries with any original still running.
  final Duration interruptedPendingMinAge;

  /// How long after a pass that leaves retryable work behind (or after a
  /// repository nudge) the next pass runs on its own. Mirrors
  /// `OutgoingDmRetryService`'s follow-up gap, so a reaction or removal that
  /// did not confirm is re-driven within the session instead of waiting for
  /// the next foreground transition or connectivity change.
  final Duration followUpSweepGap;

  /// Minimum gap required before re-attempting a reaction whose previous
  /// attempt count is [retryCount]. Clamped at [maxDelay].
  Duration backoffFor(int retryCount) {
    if (retryCount <= 0) return Duration.zero;
    var ms = initialDelay.inMilliseconds.toDouble();
    for (var i = 0; i < retryCount; i++) {
      ms *= backoffMultiplier;
      if (ms >= maxDelay.inMilliseconds) return maxDelay;
    }
    return Duration(milliseconds: ms.round());
  }
}

enum _RetryAttemptOutcome { recovered, refused, failed }

/// Re-drives undelivered own DM reactions and removals, closing the
/// reliability gap that leaves a reaction lost when its recipient gift wrap
/// fails to land on a flaky relay.
///
/// DM *messages* get this durability from the `outgoing_dms` queue +
/// `OutgoingDmRetryService`; reactions previously had only a manual re-tap.
/// This service reuses the reaction's own durable record — the
/// `dm_message_reactions` row keeps the rumor JSON while `publishStatus` is
/// `'failed'`/`'pending'` — and replays it through
/// [DmReactionsRepository.retry], which requires the relay's NIP-20 `OK`
/// before marking the reaction sent.
///
/// **Triggers:** [appForegroundStream] transitions to `true` (the provider
/// seeds the current foreground state, so the cold-start sweep fires
/// automatically), the optional connectivity stream, the repository's
/// `retryableReactionWork` nudge, and a follow-up heartbeat. The heartbeat is
/// armed whenever a pass leaves rows that can still be retried this session,
/// and by a nudge when none is armed. Without it a session on stable
/// connectivity has no second pass at all: a removal that did not confirm
/// leaves no chip to re-tap, so the counterparty keeps a reaction the sender
/// believes is gone.
///
/// **Re-entrancy:** a sweep already in progress short-circuits the next
/// trigger. A nudge or heartbeat that lands mid-pass is remembered and arms a
/// follow-up when the pass ends, because the pass may have listed its rows
/// before the new one existed.
///
/// **Backoff/budget:** per-reaction attempts are tracked in memory. A reaction
/// is skipped until `lastAttempt + backoff(attempts)` elapses and dropped from
/// the sweep once it hits [DmReactionRetryConfig.maxRetries] (a manual re-tap
/// still works). Entries for reactions that are no longer retryable (sent,
/// deleted) are pruned each pass so the maps stay bounded to the live set.
class DmReactionRetryService {
  /// Construct the service. [reactionsRepository] must be the same instance
  /// the UI publishes through, so retried rows share its DAO and credentials.
  DmReactionRetryService({
    required DmReactionsRepository reactionsRepository,
    required Stream<bool> appForegroundStream,
    required CrashReportingService crashReporting,
    Stream<void>? retryTriggerStream,
    OfflineProbe? isOffline,
    DmReactionRetryConfig retryConfig = const DmReactionRetryConfig(),
    DateTime Function() now = DateTime.now,
  }) : _repository = reactionsRepository,
       _appForegroundStream = appForegroundStream,
       _retryTriggerStream = retryTriggerStream,
       _isOffline = isOffline,
       _config = retryConfig,
       _now = now,
       _crashReporting = crashReporting;

  final DmReactionsRepository _repository;
  final Stream<bool> _appForegroundStream;

  /// Fires a sweep on each event, independent of foreground transitions.
  /// Wired to connectivity/relay-reconnection so a reaction (or removal) made
  /// during a brief network drop is re-driven the moment the network returns —
  /// without waiting for the user to background and re-foreground the app.
  final Stream<void>? _retryTriggerStream;

  /// Connectivity probe (same contract as `NIP17MessageService`'s). When it
  /// reports offline the pass is skipped entirely: every dispatch would
  /// deterministically hit the send path's own offline fail-fast, and
  /// [_driveTargets] charges a target's budget on any non-success result. So
  /// five foreground transitions in airplane mode would otherwise exhaust a
  /// pending removal, after which the sweep skips it for the rest of the
  /// process and the kind-5 never publishes — invisibly, because the chip is
  /// already filtered out of the thread. [_retryTriggerStream] re-fires the
  /// sweep when the network returns. Mirrors `OutgoingDmRetryService`. #7319.
  final OfflineProbe? _isOffline;

  final DmReactionRetryConfig _config;
  final DateTime Function() _now;
  final CrashReportingService _crashReporting;

  /// Tracking-key prefix for the add/publish retry phase.
  static const String _addPhase = 'add';

  /// Tracking-key prefix for the removal (kind-5) retry phase.
  static const String _deletionPhase = 'del';

  /// Backoff/attempt tracking, keyed by `'<phase>:<rumorId>'`. The phase prefix
  /// keeps the add and deletion budgets separate: a row keeps its rumor id when
  /// it flips from a `failed`/`pending` add to a `deletion_pending` removal, so
  /// a bare-id key would let a removal inherit the add phase's exhausted budget
  /// and never re-drive the kind-5 (the counterparty keeps a reaction you
  /// removed until the next cold start).
  final Map<String, int> _attempts = {};
  final Map<String, DateTime> _lastAttempt = {};

  StreamSubscription<bool>? _foregroundSubscription;
  StreamSubscription<void>? _retryTriggerSubscription;
  StreamSubscription<void>? _retryableWorkSubscription;
  Timer? _followUpTimer;
  bool _isInitialized = false;
  bool _isSweeping = false;

  /// A nudge or heartbeat arrived while a pass was running. Consumed after
  /// the pass so a row that landed mid-pass still arms a follow-up.
  bool _wakeRequestedDuringSweep = false;

  /// Passes in a row that threw before listing the worklist. Bounds the
  /// heartbeat so a persistent fault cannot loop for the rest of the session.
  int _consecutiveSweepFaults = 0;

  bool get isInitialized => _isInitialized;

  @visibleForTesting
  bool get isSweeping => _isSweeping;

  /// Subscribe to the retry triggers. Idempotent: calling twice is a no-op so
  /// the eager-init read in `main.dart` and any test setup coexist.
  Future<void> initialize() async {
    if (_isInitialized) return;
    _isInitialized = true;

    _foregroundSubscription = _appForegroundStream.listen((foreground) {
      if (foreground) {
        unawaited(sweep());
      }
    });

    _retryTriggerSubscription = _retryTriggerStream?.listen((_) {
      unawaited(sweep());
    });

    _retryableWorkSubscription = _repository.retryableReactionWork.listen(
      (_) => _onRepositoryNudge(),
    );

    Log.info(
      'initialized',
      name: 'DmReactionRetryService',
      category: LogCategory.system,
    );
  }

  /// Cancel the trigger subscriptions and the heartbeat, and mark the service
  /// un-init. Idempotent.
  Future<void> dispose() async {
    _isInitialized = false;
    _followUpTimer?.cancel();
    _followUpTimer = null;
    await _foregroundSubscription?.cancel();
    _foregroundSubscription = null;
    await _retryTriggerSubscription?.cancel();
    _retryTriggerSubscription = null;
    await _retryableWorkSubscription?.cancel();
    _retryableWorkSubscription = null;
  }

  /// One pass over the retryable reactions. Public so tests can drive it
  /// directly without constructing a foreground stream.
  @visibleForTesting
  Future<void> sweep() async {
    if (_isSweeping) {
      Log.debug(
        'sweep already in progress, skipping',
        name: 'DmReactionRetryService',
        category: LogCategory.system,
      );
      return;
    }
    // Repo not credentialed yet (cold start before auth) — `retry` would no-op
    // and burn the attempt budget. Skip; the next foreground transition
    // retries once credentials are wired.
    if (!_repository.isInitialized) return;
    _isSweeping = true;
    var sweepThrew = false;

    try {
      // Offline: every dispatch would deterministically hit the send path's
      // own offline fail-fast, and _driveTargets charges the budget on any
      // non-success result. Gate the whole pass rather than the dispatch, so
      // no target is charged for a network outage. _retryTriggerStream
      // re-fires the sweep when connectivity returns. #7319.
      if (await _isOfflineSafely()) {
        Log.debug(
          'device offline; skipping sweep without charging retry budgets',
          name: 'DmReactionRetryService',
          category: LogCategory.system,
        );
        return;
      }

      final reactionTargets = await _repository.retryableReactions();
      final deletionTargets = await _repository.retryableDeletions();
      _pruneTracking(<String>{
        for (final t in reactionTargets) '$_addPhase:${t.rumorId}',
        for (final t in deletionTargets) '$_deletionPhase:${t.rumorId}',
      });

      // Adds apply the pending min-age guard (a fresh 'pending' row may still
      // have its original publish in flight). Removals do not: a
      // 'deletion_pending' row is never in-flight for the sweep's purposes.
      final r = await _driveTargets(
        reactionTargets,
        phase: _addPhase,
        applyPendingMinAge: true,
        driver: (t) async =>
            (await _repository.retry(
              rumorId: t.rumorId,
              targetMessageAuthor: t.targetMessageAuthor,
            )).success
            ? _RetryAttemptOutcome.recovered
            : _RetryAttemptOutcome.failed,
      );
      final d = await _driveTargets(
        deletionTargets,
        phase: _deletionPhase,
        applyPendingMinAge: false,
        driver: (t) async => switch (await _repository.retryDeletion(
          rumorId: t.rumorId,
          targetMessageAuthor: t.targetMessageAuthor,
        )) {
          DmReactionDeletionOutcome.sent => _RetryAttemptOutcome.recovered,
          DmReactionDeletionOutcome.refused => _RetryAttemptOutcome.refused,
          DmReactionDeletionOutcome.unconfirmed ||
          DmReactionDeletionOutcome.unavailable => _RetryAttemptOutcome.failed,
        },
      );

      Log.info(
        'sweep complete: '
        'reactions(recovered=${r.recovered} failed=${r.failed} '
        'refused=${r.refused} '
        'skipped-backoff=${r.skippedBackoff} '
        'skipped-exhausted=${r.skippedExhausted} '
        'skipped-too-young=${r.skippedTooYoung}) '
        'deletions(recovered=${d.recovered} failed=${d.failed} '
        'refused=${d.refused} '
        'skipped-backoff=${d.skippedBackoff} '
        'skipped-exhausted=${d.skippedExhausted})',
        name: 'DmReactionRetryService',
        category: LogCategory.system,
      );

      _scheduleFollowUp(workRemains: r.stillRetryable + d.stillRetryable > 0);
    } on Object catch (e, stackTrace) {
      sweepThrew = true;
      _consecutiveSweepFaults++;
      // Queue state is unknown after a throw, so assume work remains, but
      // only for as many passes as a row gets attempts: a fault that never
      // clears must not keep the heartbeat alive for the rest of the session.
      _scheduleFollowUp(
        workRemains: _consecutiveSweepFaults < _config.maxRetries,
      );
      Log.error(
        'sweep failed: $e',
        name: 'DmReactionRetryService',
        category: LogCategory.system,
        error: e,
        stackTrace: stackTrace,
      );
      unawaited(
        _crashReporting.recordError(
          e,
          stackTrace,
          reason: DmReactionRetryServiceReportableSites.sweepTopLevel,
        ),
      );
    } finally {
      if (!sweepThrew) _consecutiveSweepFaults = 0;
      _isSweeping = false;
      // Consumed after `_isSweeping` clears: checking earlier would reopen a
      // window between the pass's own scheduling and this flag.
      if (_wakeRequestedDuringSweep) {
        _wakeRequestedDuringSweep = false;
        _armFollowUpIfIdle();
      }
    }
  }

  /// Arm the heartbeat to run one more pass after [DmReactionRetryConfig
  /// .followUpSweepGap], or cancel it when nothing can be retried.
  void _scheduleFollowUp({required bool workRemains}) {
    _followUpTimer?.cancel();
    _followUpTimer = null;
    if (!workRemains || !_isInitialized) return;
    _followUpTimer = Timer(_config.followUpSweepGap, _onFollowUpTimer);
  }

  /// Arm the heartbeat only when none is armed, so a burst of nudges cannot
  /// keep pushing an armed deadline out.
  void _armFollowUpIfIdle() {
    if (!_isInitialized || _followUpTimer != null) return;
    _followUpTimer = Timer(_config.followUpSweepGap, _onFollowUpTimer);
  }

  void _onFollowUpTimer() {
    _followUpTimer = null;
    if (_isSweeping) {
      _wakeRequestedDuringSweep = true;
      return;
    }
    unawaited(sweep());
  }

  /// The repository left a row for the sweep. Emissions can follow a database
  /// write that is still being read, so this only arms a timer.
  void _onRepositoryNudge() {
    if (_isSweeping) {
      _wakeRequestedDuringSweep = true;
      return;
    }
    _armFollowUpIfIdle();
  }

  /// Drive one list of retry [targets] through [driver]. Backoff/attempt
  /// tracking is keyed by `'<phase>:<rumorId>'` so the add and deletion phases
  /// keep independent budgets even though a row keeps its rumor id across the
  /// `failed`/`pending` → `deletion_pending` lifecycle flip.
  Future<
    ({
      int recovered,
      int failed,
      int refused,
      int skippedBackoff,
      int skippedExhausted,
      int skippedTooYoung,
      int stillRetryable,
    })
  >
  _driveTargets(
    List<DmReactionRetryTarget> targets, {
    required String phase,
    required bool applyPendingMinAge,
    required Future<_RetryAttemptOutcome> Function(DmReactionRetryTarget)
    driver,
  }) async {
    var recovered = 0;
    var failed = 0;
    var refused = 0;
    var skippedBackoff = 0;
    var skippedExhausted = 0;
    var skippedTooYoung = 0;

    // Rows this session may still attempt: they back off, age past the
    // in-flight guard, or failed with budget left. A row that was delivered,
    // refused, or has spent its budget will never be attempted again, so it
    // must not keep the heartbeat alive.
    var stillRetryable = 0;

    for (final target in targets) {
      final id = '$phase:${target.rumorId}';
      final attempts = _attempts[id] ?? 0;

      if (attempts >= _config.maxRetries) {
        skippedExhausted++;
        continue;
      }

      final last = _lastAttempt[id];
      if (last != null) {
        final gap = _now().difference(last);
        if (gap < _config.backoffFor(attempts)) {
          skippedBackoff++;
          stillRetryable++;
          continue;
        }
      }

      // Avoid re-driving very fresh pending rows. Age alone cannot establish
      // that a sequential group publish finished: the timeout is per recipient.
      // The repository joins any original still running instead of replaying it.
      if (applyPendingMinAge && target.publishStatus == 'pending') {
        final age = _now().difference(
          DateTime.fromMillisecondsSinceEpoch(target.createdAt * 1000),
        );
        if (age < _config.interruptedPendingMinAge) {
          skippedTooYoung++;
          stillRetryable++;
          continue;
        }
      }

      try {
        switch (await driver(target)) {
          case _RetryAttemptOutcome.recovered:
            _attempts.remove(id);
            _lastAttempt.remove(id);
            recovered++;
          case _RetryAttemptOutcome.refused:
            _attempts.remove(id);
            _lastAttempt.remove(id);
            refused++;
          case _RetryAttemptOutcome.failed:
            _attempts[id] = attempts + 1;
            _lastAttempt[id] = _now();
            failed++;
            if (attempts + 1 < _config.maxRetries) stillRetryable++;
        }
      } on Object catch (e, stackTrace) {
        _attempts[id] = attempts + 1;
        _lastAttempt[id] = _now();
        failed++;
        if (attempts + 1 < _config.maxRetries) stillRetryable++;
        Log.error(
          'reaction retry threw for $id: $e',
          name: 'DmReactionRetryService',
          category: LogCategory.system,
          error: e,
          stackTrace: stackTrace,
        );
        unawaited(
          _crashReporting.recordError(
            e,
            stackTrace,
            reason: DmReactionRetryServiceReportableSites
                .perReactionUnexpectedThrow,
          ),
        );
      }
    }

    return (
      recovered: recovered,
      failed: failed,
      refused: refused,
      skippedBackoff: skippedBackoff,
      skippedExhausted: skippedExhausted,
      skippedTooYoung: skippedTooYoung,
      stillRetryable: stillRetryable,
    );
  }

  /// Probe connectivity, treating a broken probe as online.
  ///
  /// A probe that throws must never disable retries outright — that would
  /// turn a transient platform-channel error into a permanently stalled
  /// queue. Mirrors `OutgoingDmRetryService._isOfflineSafely`.
  Future<bool> _isOfflineSafely() async {
    final probe = _isOffline;
    if (probe == null) return false;
    try {
      return await probe();
    } on Object catch (e) {
      Log.warning(
        'offline probe failed; assuming online: $e',
        name: 'DmReactionRetryService',
        category: LogCategory.system,
      );
      return false;
    }
  }

  void _pruneTracking(Set<String> liveIds) {
    _attempts.removeWhere((id, _) => !liveIds.contains(id));
    _lastAttempt.removeWhere((id, _) => !liveIds.contains(id));
  }
}
