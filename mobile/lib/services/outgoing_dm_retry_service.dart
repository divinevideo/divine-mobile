// ABOUTME: Service that auto-sweeps the outgoing_dms queue for partial-
// ABOUTME: delivery, hard-failed, and soft-unconfirmed rows and re-drives each
// ABOUTME: via DmRepository. Triggered by app-foreground + connectivity events.

import 'dart:async';

import 'package:db_client/db_client.dart';
import 'package:dm_repository/dm_repository.dart';
import 'package:meta/meta.dart';
import 'package:nostr_sdk/nip19/pubkey_for_logs.dart';
import 'package:openvine/observability/crash_reporter.dart';
import 'package:openvine/services/outgoing_dm_retry_service_reportable_sites.dart';
import 'package:unified_logger/unified_logger.dart';

/// Backoff configuration for [OutgoingDmRetryService].
///
/// Defaults match `PendingActionRetryConfig` (5 retries, 2s → 5min,
/// 2× backoff) — same precedent epic #3912 cites.
class OutgoingDmRetryConfig {
  const OutgoingDmRetryConfig({
    this.maxRetries = 5,
    this.initialDelay = const Duration(seconds: 2),
    this.maxDelay = const Duration(minutes: 5),
    this.backoffMultiplier = 2.0,
  });

  final int maxRetries;
  final Duration initialDelay;
  final Duration maxDelay;
  final double backoffMultiplier;

  /// Minimum required gap between attempts for a row whose previous
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

/// Sweeps the durable `outgoing_dms` queue for rows whose recipient
/// gift wrap landed but whose self-wrap did not, and re-publishes the
/// missing self-wrap via [DmRepository.recoverSelfWrap].
///
/// **Triggers:** [appForegroundStream] transitions to `true` (the provider
/// seeds the stream with the current foreground state on subscription, so the
/// cold-start sweep fires automatically); when wired, [retryTriggerStream]
/// — connectivity/relay-reconnection events — so a send queued while offline
/// re-drives the instant the network returns; a self-scheduled follow-up
/// timer ([_followUpSweepGap]) whenever a pass leaves retryable work behind,
/// so rows converge during an uninterrupted foreground session too; and
/// [DmRepository.retryableOutgoingWork] nudges whenever a send or recovery
/// leaves a retryable row behind, which BOOTSTRAPS that follow-up timer —
/// without it a soft-unconfirmed send after a cold start sat pending until
/// the next foreground flip or connectivity change.
///
/// **Re-entrancy:** a sweep already in progress short-circuits the
/// next trigger; the deferred work is picked up on the next trigger.
///
/// **Per-row backoff:** rows whose `lastAttemptAt + backoff(retryCount)`
/// is in the future are skipped this pass. `incrementRetry` is called
/// only on a real publish failure so transient repo-not-ready states
/// don't burn the retry budget.
///
/// **Scope:** three sweep arms run on each trigger:
///
/// 1. `recipient: sent / self: failed` → [DmRepository.recoverSelfWrap]
///    (the canonical partial-delivery recovery from #4124).
/// 2. `recipient: failed` → [DmRepository.recoverFullSend] (replays both
///    wraps; rumor.id is stable across retries so NIP-17 receiver dedup
///    drops the duplicate copy if the original publish actually landed).
/// 3. Either wrap still `pending` and the row queuedAt is older than the
///    interrupted-send threshold → [DmRepository.recoverFullSend]. This
///    catches both app-killed mid-send rows (epic #3912's "outgoing DM
///    survives the app being killed mid-send") and soft-unconfirmed sends
///    (recipient frame written, no NIP-20 OK yet), both surfaced by
///    [OutgoingDmsDao.getStillPendingForOwner]. The min-age guard avoids
///    racing with a `sendMessage` still in flight in the same process;
///    idempotency at the receiver makes the race safe even if it fires false.
///    A pending row that has burned the retry budget (`retry_count >=
///    maxRetries`) is terminalized to `failed` here, since
///    `getStillPendingForOwner` — unlike the failed arm's
///    `getRetryableForOwner` — has no retry-count cap of its own.
class OutgoingDmRetryService {
  OutgoingDmRetryService({
    required DmRepository dmRepository,
    required OutgoingDmsDao outgoingDmsDao,
    required String userPubkey,
    required Stream<bool> appForegroundStream,
    CrashReporter? crashReporting,
    Stream<void>? retryTriggerStream,
    OfflineProbe? isOffline,
    OutgoingDmRetryConfig retryConfig = const OutgoingDmRetryConfig(),
    DateTime Function() now = DateTime.now,
  }) : _dmRepository = dmRepository,
       _dao = outgoingDmsDao,
       _userPubkey = userPubkey,
       _appForegroundStream = appForegroundStream,
       _retryTriggerStream = retryTriggerStream,
       _isOffline = isOffline,
       _retryConfig = retryConfig,
       _now = now,
       _crashReporting = crashReporting ?? const SilentCrashReporter();

  final DmRepository _dmRepository;
  final OutgoingDmsDao _dao;
  final String _userPubkey;
  final Stream<bool> _appForegroundStream;

  /// Fires a sweep on each event, independent of foreground transitions.
  /// Wired to connectivity/relay-reconnection so a message queued during a
  /// brief network drop is re-driven the moment the network returns — without
  /// waiting for the user to background and re-foreground the app.
  final Stream<void>? _retryTriggerStream;

  /// Connectivity probe (same contract as `NIP17MessageService`'s). When it
  /// reports offline no publish is dispatched and no row's retry budget is
  /// charged — every dispatch would deterministically hit the send path's
  /// own offline fail-fast, and five backgrounded/foregrounded cycles in
  /// airplane mode would otherwise exhaust a row into a terminal red bubble
  /// before the network ever came back. The pass instead surfaces aged
  /// unconfirmed `pending` rows as failed ([_surfaceOfflinePendingRows]) so
  /// they stop rendering as delivered, and the connectivity trigger stream
  /// re-fires the sweep the moment the network returns.
  final OfflineProbe? _isOffline;

  final OutgoingDmRetryConfig _retryConfig;
  final DateTime Function() _now;
  final CrashReporter _crashReporting;

  /// What a send can cost OUTSIDE [DmBatchSendBudget.messagePublishTimeout].
  ///
  /// Chiefly recipient kind-10050 inbox resolution, which runs before the
  /// publish is wrapped. This used to be a flat 30s estimate documented as
  /// "a margin, not a guarantee", because nothing bounded that resolution:
  /// on device it took 51s on a real send while the capped publish took 10ms
  /// (#7091). It is now derived from the bound actually enforced there, so it
  /// cannot drift from it — the #6586 failure mode.
  static final Duration _inboxResolutionMargin =
      DmSendBudget.inboxResolution + _nonCancellationCushion;

  /// Room beyond the two bounds for a send that has already been abandoned.
  ///
  /// `Future.timeout` does not cancel, so a send the backstop gave up on keeps
  /// running past the cap. This guard has to outlive the IN-FLIGHT send, not
  /// merely the cap, which is why deriving it from the bounds alone would be
  /// too tight.
  ///
  /// Sized to hold the total at the 160s it has shipped at: bounding the
  /// segments made the derivation honest, and re-deriving it downward at the
  /// same time would ship an unmeasured change to how soon the sweep re-drives
  /// a live send. That is a separate decision, on its own evidence.
  static const Duration _nonCancellationCushion = Duration(seconds: 23);

  /// Minimum age of a still-`pending` row before the interrupted-send arm
  /// may re-drive it. Must exceed the worst-case legitimately-in-flight
  /// send, or a foreground/connectivity trigger fired during a live send
  /// dispatches a concurrent duplicate publish of the same rumor. Receiver
  /// dedup makes that safe but wasteful; the old value (the 2s
  /// `initialDelay`) made it the common case.
  ///
  /// Derived from the backstop rather than restated as a literal. It was
  /// previously hardcoded to 120s against a 90s backstop, and #6586 showed why
  /// that is fragile twice over: the backstop had itself drifted below the
  /// chain it bounds, and `Future.timeout` does not cancel — so the abandoned
  /// send keeps running past the cap and this guard has to outlive the
  /// IN-FLIGHT send, not merely the cap.
  ///
  /// Both halves are now derived: the backstop covers the whole capped chain
  /// including the three pre-wrap steps that used to sit in its headroom, and
  /// [_inboxResolutionMargin] covers resolution at the bound now enforced on
  /// it. The guard is a guarantee rather than an estimate (#7091).
  static final Duration _interruptedMinAge =
      DmBatchSendBudget.messagePublishTimeout + _inboxResolutionMargin;

  /// The interrupted-send guard, for tests that need to age a row across it.
  ///
  /// Exposed so tests derive their timings from the guard instead of restating
  /// a literal — a hardcoded age silently stops testing the boundary the
  /// moment the budget moves, which is how #6586 stayed invisible.
  @visibleForTesting
  static Duration get interruptedMinAge => _interruptedMinAge;

  /// Gap between a sweep that left retryable work behind and the follow-up
  /// sweep it schedules. Without an in-session heartbeat, a soft-unconfirmed
  /// row created while the app stays foregrounded on stable connectivity was
  /// never re-driven until the next background/foreground flip.
  static const Duration _followUpSweepGap = Duration(seconds: 30);

  StreamSubscription<bool>? _foregroundSubscription;
  StreamSubscription<void>? _retryTriggerSubscription;
  StreamSubscription<void>? _retryableWorkSubscription;
  Timer? _followUpTimer;
  bool _isInitialized = false;
  bool _isSweeping = false;

  /// Number of consecutive sweep passes whose top-level `try` threw. Only the
  /// first fault of a streak is reported to Crashlytics: a persistently-
  /// throwing DAO (non-self-healing SQLite corruption/lock) would otherwise
  /// re-report [OutgoingDmRetryServiceReportableSites.sweepTopLevel] every
  /// [_followUpSweepGap] for the whole foreground session. The first non-
  /// throwing pass resets it to 0 (in `sweep`'s `finally`), so a fresh streak
  /// reports again. Local `Log.error` still fires every pass — this gates only
  /// the crash-report escalation.
  int _consecutiveTopLevelFaults = 0;

  /// A repository nudge arrived while a sweep was running. Consumed in the
  /// sweep's `finally` (after `_isSweeping` clears) so a row that landed
  /// mid-pass — invisible to that pass's own counters — still arms the
  /// follow-up timer instead of stranding until the next external trigger.
  bool _nudgedDuringSweep = false;

  /// Per-rumor attempt count and last-attempt time for the message-deletion
  /// pass. Session-scoped: entries are pruned each sweep as rows settle.
  final Map<String, int> _deletionAttempts = {};
  final Map<String, DateTime> _deletionLastAttempt = {};

  bool get isInitialized => _isInitialized;

  @visibleForTesting
  bool get isSweeping => _isSweeping;

  /// Subscribe to foreground transitions. Idempotent: calling twice is
  /// a no-op so the eager-init read in `main.dart` and any test setup
  /// can coexist safely.
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

    // The send path nudges when it leaves a retryable row behind (soft
    // unconfirmed, hard failure, partial delivery). Without this the 30s
    // follow-up heartbeat never bootstraps: it is armed only at the end of
    // a sweep, and nothing swept when a send finished soft-unconfirmed —
    // the row sat pending (a delivered-looking bubble) until the next
    // background/foreground flip or connectivity change. Arm-only-if-idle:
    // a burst of sends must not keep postponing an armed deadline. The
    // emission can fire from inside a repository transaction, so this
    // handler only arms a timer — never touches the database.
    _retryableWorkSubscription = _dmRepository.retryableOutgoingWork.listen((
      _,
    ) {
      if (_isSweeping) {
        _nudgedDuringSweep = true;
        return;
      }
      _armFollowUpIfIdle();
    });

    Log.info(
      'initialized for ${pubkeyForLogs(_userPubkey)}',
      name: 'OutgoingDmRetryService',
      category: LogCategory.system,
    );
  }

  /// Cancel the trigger subscriptions and mark the service un-init.
  /// Idempotent.
  Future<void> dispose() async {
    // Synchronous teardown first: no new sweep may fire while the
    // subscription cancels below are awaited.
    _isInitialized = false;
    _followUpTimer?.cancel();
    _followUpTimer = null;
    _nudgedDuringSweep = false;
    _consecutiveTopLevelFaults = 0;
    await _foregroundSubscription?.cancel();
    _foregroundSubscription = null;
    await _retryTriggerSubscription?.cancel();
    _retryTriggerSubscription = null;
    await _retryableWorkSubscription?.cancel();
    _retryableWorkSubscription = null;
  }

  /// One pass over the retryable queue. Public so tests can drive it
  /// directly without constructing a foreground stream.
  @visibleForTesting
  Future<void> sweep() async {
    if (_isSweeping) {
      Log.debug(
        'sweep already in progress, skipping',
        name: 'OutgoingDmRetryService',
        category: LogCategory.system,
      );
      return;
    }
    _isSweeping = true;
    var sweepThrew = false;

    try {
      // Offline gate: dispatching while offline deterministically fails
      // every row via the send path's own offline fail-fast and burns the
      // retry budget for attempts that never had a chance. Instead of
      // publishing, surface aged unconfirmed rows as failed (see
      // [_surfaceOfflinePendingRows]) and skip the rest of the pass; the
      // connectivity trigger re-fires it the moment the network is back.
      // Probe errors fall through to sweeping (assume online).
      if (await _isOfflineSafely()) {
        // Rows younger than the min-age guard are skipped by the surfacing
        // pass — schedule the follow-up so they are re-examined while the
        // device stays offline, instead of looking delivered for the whole
        // offline session.
        _scheduleFollowUp(workRemains: await _surfaceOfflinePendingRows());
        return;
      }

      final retryable = await _dao.getRetryableForOwner(
        ownerPubkey: _userPubkey,
        maxRetries: _retryConfig.maxRetries,
      );

      var processedSelfWrap = 0;
      var failedSelfWrap = 0;
      var blockedSelfWrap = 0;
      var processedFullSend = 0;
      var failedFullSend = 0;
      var blockedFullSend = 0;
      var skippedBackoff = 0;
      var abortedNotReady = false;

      // Rows this loop actually dispatched (or owned when the dispatch
      // threw). The interrupted arm below skips these — but ONLY these: a
      // row that matches neither arm (e.g. recipient=pending/self=failed)
      // must stay visible to the interrupted arm, or it is stranded forever
      // as a permanently sent-looking pending bubble.
      final dispatchedIds = <String>{};

      for (final row in retryable) {
        if (abortedNotReady) break;

        // Per-row backoff check before any dispatch.
        final lastAttempt = row.lastAttemptAt;
        if (lastAttempt != null) {
          final gap = _now().difference(lastAttempt);
          final required = _retryConfig.backoffFor(row.retryCount);
          if (gap < required) {
            skippedBackoff++;
            continue;
          }
        }

        if (row.recipientWrapStatus == OutgoingWrapStatus.sent &&
            row.selfWrapStatus == OutgoingWrapStatus.failed) {
          // State A: recipient delivered, self-wrap missing. The
          // canonical case #4124 is closing.
          dispatchedIds.add(row.id);
          try {
            final result = await _dmRepository.recoverSelfWrap(rumorId: row.id);
            if (result.success) {
              // recoverSelfWrap deleted the row on success. The bumped
              // retryCount would be moot anyway, so skip incrementRetry.
              processedSelfWrap++;
            } else if (result.blocked) {
              // Terminal: the row is addressed to its own sender, which
              // recoverSelfWrap refuses and drops (#8363). It is never
              // retried, so the counter is not bumped and the pass does not
              // count it as a failure.
              blockedSelfWrap++;
            } else {
              // Publish failed. recoverSelfWrap already wrote
              // selfWrapStatus=failed + lastError + lastAttemptAt via
              // markSelfWrapStatus; bump the retry counter so the next
              // sweep applies backoff and so the row eventually exits
              // the retryable filter at maxRetries.
              await _dao.incrementRetry(row.id);
              failedSelfWrap++;
            }
          } on Object catch (e, stackTrace) {
            // recoverSelfWrap's contract documents StateError (repo or
            // DAO not initialized) and ArgumentError (row missing /
            // foreign owner) as part of the public surface. Catching
            // them — alongside any unexpected throw from the underlying
            // publish — is the correct behavior here, not a code smell.
            if (e is StateError) {
              // No attempt was made because the repo wasn't ready.
              // Don't bump retry; abort this pass and let the next
              // foreground transition retry once auth is ready.
              Log.warning(
                'repo not ready during sweep; aborting pass: $e',
                name: 'OutgoingDmRetryService',
                category: LogCategory.system,
              );
              abortedNotReady = true;
            } else if (e is ArgumentError) {
              // Row went missing or wrong owner between
              // getRetryableForOwner and dispatch. Terminal for this
              // row — don't bump retry.
              Log.warning(
                'skipping row ${row.id}: $e',
                name: 'OutgoingDmRetryService',
                category: LogCategory.system,
              );
            } else {
              // Unexpected throw before publish completed. Bump retry
              // so backoff applies and the row eventually exits the
              // filter.
              await _dao.incrementRetry(row.id);
              Log.error(
                'recoverSelfWrap threw for ${row.id}: $e',
                name: 'OutgoingDmRetryService',
                category: LogCategory.system,
                error: e,
                stackTrace: stackTrace,
              );
              unawaited(
                _crashReporting.recordError(
                  e,
                  stackTrace,
                  reason: OutgoingDmRetryServiceReportableSites
                      .perRowUnexpectedThrow,
                ),
              );
            }
          }
        } else if (row.recipientWrapStatus == OutgoingWrapStatus.failed) {
          // State B: recipient publish itself failed. Replay the
          // full send. NIP-17 receiver-side dedup keys on the rumor
          // id (preserved across retries via `rumor_event_json`), so
          // re-publishing is safe even when the original publish
          // actually landed but the local persist failed.
          dispatchedIds.add(row.id);
          try {
            final result = await _dmRepository.recoverFullSend(
              rumorId: row.id,
            );
            if (result.success) {
              // recoverFullSend's success path either deletes the row
              // (full delivery) or promotes it to
              // `recipient: sent / self: failed` (partial). Either
              // way the row exits the recipient-failed filter, so
              // skip incrementRetry.
              processedFullSend++;
            } else if (result.blocked) {
              // Terminal, not transient: recoverFullSend settled the row for
              // a #176 policy block, or dropped a one-to-one row addressed to
              // its own sender (#8363). Don't bump the retry counter (every
              // retry would be refused again), and count it as terminal
              // rather than a failure.
              blockedFullSend++;
            } else if (result.retryablePending) {
              // Soft-unconfirmed: recoverFullSend already bumped the retry
              // counter via _finalizeAfterRecipientUnconfirmed. Bumping
              // again here double-charged every soft attempt and halved
              // the effective retry budget.
              failedFullSend++;
            } else {
              // Publish failed again. recoverFullSend already
              // re-marked both wraps failed with the new error via
              // _finalizeAfterRecipientFailure (which writes
              // lastAttemptAt through the DAO codec). Bump the retry
              // counter so backoff applies and the row eventually
              // exits the retryable filter at maxRetries.
              await _dao.incrementRetry(row.id);
              failedFullSend++;
            }
          } on Object catch (e, stackTrace) {
            // Same error policy as the recoverSelfWrap dispatch
            // above. recoverFullSend's contract documents StateError
            // (repo or DAO not initialized) and ArgumentError (row
            // missing / foreign owner) as part of its public surface.
            if (e is StateError) {
              Log.warning(
                'repo not ready during sweep; aborting pass: $e',
                name: 'OutgoingDmRetryService',
                category: LogCategory.system,
              );
              abortedNotReady = true;
            } else if (e is ArgumentError) {
              Log.warning(
                'skipping row ${row.id}: $e',
                name: 'OutgoingDmRetryService',
                category: LogCategory.system,
              );
            } else {
              await _dao.incrementRetry(row.id);
              Log.error(
                'recoverFullSend threw for ${row.id}: $e',
                name: 'OutgoingDmRetryService',
                category: LogCategory.system,
                error: e,
                stackTrace: stackTrace,
              );
            }
          }
        }
      }

      // Interrupted-send arm: pending rows older than the min-age guard
      // are app-killed mid-send. The user perceives the bubble as
      // never-delivered; the relay may or may not have accepted the
      // original wire copy. recoverFullSend re-wraps the SAME rumor
      // (preserving rumor.id), so NIP-17 receiver dedup collapses
      // duplicates if both wire copies eventually land.
      var processedInterrupted = 0;
      var failedInterrupted = 0;
      var blockedInterrupted = 0;
      var exhaustedInterrupted = 0;
      var skippedInterruptedTooYoung = 0;
      if (!abortedNotReady) {
        final pending = await _dao.getStillPendingForOwner(_userPubkey);
        for (final row in pending) {
          // Skip rows already dispatched above (a recipient=failed +
          // self=pending row appears in both filters; the failed arm owns
          // that dispatch). Rows the arms did NOT match — e.g.
          // recipient=pending / self=failed — fall through to this arm.
          if (dispatchedIds.contains(row.id)) continue;

          // Exhausted guard: a pending row that has burned the retry budget
          // is terminally unconfirmable — a soft-unconfirmed send whose OK
          // never arrived, or an app-killed row that can never reach a relay.
          // Flip it to `failed` so it stops re-driving, renders as a red
          // failed bubble, and becomes a manual-retry candidate. The failed
          // arm's `getRetryableForOwner` already caps at `retry_count <
          // maxRetries`; `getStillPendingForOwner` does not, so without this
          // an unconfirmable pending row would re-drive forever.
          if (row.retryCount >= _retryConfig.maxRetries) {
            await _markInterruptedExhausted(row);
            exhaustedInterrupted++;
            continue;
          }

          // Min-age guard: if the row was recently enqueued, the
          // originating sendMessage call may still be in flight in this
          // process (inbox resolution + the derived publish backstop). Wait
          // out that window before treating the row as interrupted, or a
          // trigger fired mid-send dispatches a concurrent duplicate
          // publish of the same rumor. Idempotent receiver dedup makes a
          // false negative safe — it means a one-cycle delay, not data
          // loss.
          final age = _now().difference(row.queuedAt);
          if (age < _interruptedMinAge) {
            skippedInterruptedTooYoung++;
            continue;
          }

          // Per-row backoff: same gate as the other arms.
          final lastAttempt = row.lastAttemptAt;
          if (lastAttempt != null) {
            final gap = _now().difference(lastAttempt);
            final required = _retryConfig.backoffFor(row.retryCount);
            if (gap < required) {
              skippedBackoff++;
              continue;
            }
          }

          try {
            final result = await _dmRepository.recoverFullSend(
              rumorId: row.id,
            );
            if (result.success) {
              processedInterrupted++;
            } else if (result.blocked) {
              // Terminal, same as the failed-send arm: recoverFullSend
              // settled or dropped the row, so don't re-arm it.
              blockedInterrupted++;
            } else if (result.retryablePending) {
              // Soft-unconfirmed: the repo already bumped the counter via
              // _finalizeAfterRecipientUnconfirmed — no double charge.
              failedInterrupted++;
            } else {
              await _dao.incrementRetry(row.id);
              failedInterrupted++;
            }
          } on Object catch (e, stackTrace) {
            if (e is StateError) {
              Log.warning(
                'repo not ready during interrupted-send sweep; aborting: $e',
                name: 'OutgoingDmRetryService',
                category: LogCategory.system,
              );
              abortedNotReady = true;
              break;
            } else if (e is ArgumentError) {
              Log.warning(
                'skipping interrupted row ${row.id}: $e',
                name: 'OutgoingDmRetryService',
                category: LogCategory.system,
              );
            } else {
              await _dao.incrementRetry(row.id);
              Log.error(
                'recoverFullSend threw for interrupted ${row.id}: $e',
                name: 'OutgoingDmRetryService',
                category: LogCategory.system,
                error: e,
                stackTrace: stackTrace,
              );
              unawaited(
                _crashReporting.recordError(
                  e,
                  stackTrace,
                  reason: OutgoingDmRetryServiceReportableSites
                      .perRowUnexpectedThrow,
                ),
              );
            }
          }
        }
      }

      final deletions = await _sweepMessageDeletions();

      Log.info(
        'sweep complete: '
        'self-wrap-recovered=$processedSelfWrap '
        'self-wrap-failed=$failedSelfWrap '
        'self-wrap-blocked=$blockedSelfWrap '
        'full-send-recovered=$processedFullSend '
        'full-send-failed=$failedFullSend '
        'full-send-blocked=$blockedFullSend '
        'interrupted-recovered=$processedInterrupted '
        'interrupted-failed=$failedInterrupted '
        'interrupted-blocked=$blockedInterrupted '
        'interrupted-exhausted=$exhaustedInterrupted '
        'skipped-backoff=$skippedBackoff '
        'skipped-interrupted-too-young=$skippedInterruptedTooYoung '
        'aborted-not-ready=$abortedNotReady '
        'deletions(sent=${deletions.sent} blocked=${deletions.blocked} '
        'unconfirmed=${deletions.unconfirmed} '
        'skipped-backoff=${deletions.skippedBackoff} '
        'skipped-exhausted=${deletions.skippedExhausted})',
        name: 'OutgoingDmRetryService',
        category: LogCategory.system,
      );

      // Everything that neither delivered nor terminalized this pass is
      // still driveable work: failed re-attempts, rows skipped by backoff
      // or the min-age guard, and an aborted not-ready pass (rows
      // untouched). Derived from the pass's own counters so no extra DAO
      // round-trip is spent on the decision.
      _scheduleFollowUp(
        workRemains:
            abortedNotReady ||
            failedSelfWrap > 0 ||
            failedFullSend > 0 ||
            failedInterrupted > 0 ||
            skippedBackoff > 0 ||
            skippedInterruptedTooYoung > 0 ||
            deletions.unconfirmed > 0 ||
            deletions.skippedBackoff > 0,
      );
    } on Object catch (e, stackTrace) {
      sweepThrew = true;
      _consecutiveTopLevelFaults++;
      Log.error(
        'sweep failed: $e',
        name: 'OutgoingDmRetryService',
        category: LogCategory.system,
        error: e,
        stackTrace: stackTrace,
      );
      // Escalate to Crashlytics only on the first fault of a consecutive-
      // throw streak. A persistently-throwing DAO re-enters this catch every
      // _followUpSweepGap (the re-arm below keeps the heartbeat alive), and
      // its reads run before any per-row work advances a retry counter, so
      // nothing drains the queue to break the loop. Reporting each pass would
      // re-fire the same stack every 30s all session; the first non-throwing
      // pass resets the streak so a genuinely new fault reports again.
      if (_consecutiveTopLevelFaults == 1) {
        unawaited(
          _crashReporting.recordError(
            e,
            stackTrace,
            reason: OutgoingDmRetryServiceReportableSites.sweepTopLevel,
          ),
        );
      }
      // A throwing pass never reached the try-path _scheduleFollowUp, so
      // without re-arming here a transient DAO error (e.g. a busy database)
      // would silence the 30s heartbeat until an external trigger — exactly
      // the steady-foreground, stable-network session the heartbeat exists
      // for. Queue state is unknown after a throw, so assume work remains;
      // the next successful pass's own workRemains:false self-cancels the
      // timer once the queue drains.
      _scheduleFollowUp(workRemains: true);
    } finally {
      // Any pass that did not throw (including an early offline-gate return)
      // ends the fault streak, so the next throw reports afresh. `finally`
      // runs after early returns too, which is why the reset lives here.
      if (!sweepThrew) _consecutiveTopLevelFaults = 0;
      _isSweeping = false;
      // A nudge that arrived mid-pass may describe a row this pass never
      // saw. Consume it AFTER _isSweeping clears — checking earlier would
      // reopen a strand window between _scheduleFollowUp and the flag
      // check.
      if (_nudgedDuringSweep) {
        _nudgedDuringSweep = false;
        _armFollowUpIfIdle();
      }
    }
  }

  /// One pass over the delete-for-everyone requests that no relay has
  /// confirmed, re-driving each through [DmRepository.retryMessageDeletion].
  ///
  /// Attempt and backoff bookkeeping is in memory rather than on the row: a
  /// `direct_messages` row carries no retry columns, and the sweep only needs
  /// to avoid hammering within a session — the pending status itself is what
  /// survives a restart. `DmReactionRetryService` tracks its own deletions
  /// the same way.
  Future<
    ({
      int sent,
      int blocked,
      int unconfirmed,
      int skippedBackoff,
      int skippedExhausted,
    })
  >
  _sweepMessageDeletions() async {
    final targets = await _dmRepository.retryableMessageDeletions();
    _deletionAttempts.removeWhere(
      (id, _) => !targets.any((t) => t.rumorId == id),
    );
    _deletionLastAttempt.removeWhere(
      (id, _) => !targets.any((t) => t.rumorId == id),
    );

    var sent = 0;
    var blocked = 0;
    var unconfirmed = 0;
    var skippedBackoff = 0;
    var skippedExhausted = 0;

    for (final target in targets) {
      final attempts = _deletionAttempts[target.rumorId] ?? 0;
      if (attempts >= _retryConfig.maxRetries) {
        skippedExhausted++;
        continue;
      }
      final lastAttempt = _deletionLastAttempt[target.rumorId];
      if (lastAttempt != null &&
          _now().difference(lastAttempt) < _retryConfig.backoffFor(attempts)) {
        skippedBackoff++;
        continue;
      }

      _deletionAttempts[target.rumorId] = attempts + 1;
      _deletionLastAttempt[target.rumorId] = _now();

      final DmMessageDeletionOutcome outcome;
      try {
        outcome = await _dmRepository.retryMessageDeletion(
          rumorId: target.rumorId,
        );
      } on Object catch (e, stackTrace) {
        unconfirmed++;
        Log.error(
          'retryMessageDeletion threw for ${target.rumorId}: $e',
          name: 'OutgoingDmRetryService',
          category: LogCategory.system,
          error: e,
          stackTrace: stackTrace,
        );
        unawaited(
          _crashReporting.recordError(
            e,
            stackTrace,
            reason: OutgoingDmRetryServiceReportableSites.perRowUnexpectedThrow,
          ),
        );
        continue;
      }

      switch (outcome) {
        case DmMessageDeletionOutcome.sent:
          sent++;
        case DmMessageDeletionOutcome.blocked:
          blocked++;
        case DmMessageDeletionOutcome.unconfirmed:
          unconfirmed++;
        case DmMessageDeletionOutcome.unavailable:
          // Nothing was attempted, so refund the budget this row just spent
          // rather than exhausting it on a state the sweep cannot influence.
          _deletionAttempts[target.rumorId] = attempts;
      }
    }

    return (
      sent: sent,
      blocked: blocked,
      unconfirmed: unconfirmed,
      skippedBackoff: skippedBackoff,
      skippedExhausted: skippedExhausted,
    );
  }

  /// Runs the injected connectivity probe, defaulting to online on any error
  /// (and when no probe is wired) so a flaky probe never starves the sweep.
  Future<bool> _isOfflineSafely() async {
    final probe = _isOffline;
    if (probe == null) return false;
    try {
      return await probe();
    } on Object catch (e) {
      Log.warning(
        'offline probe failed; assuming online: $e',
        name: 'OutgoingDmRetryService',
        category: LogCategory.system,
      );
      return false;
    }
  }

  /// Schedule a follow-up sweep while retryable work remains, so rows
  /// converge during an uninterrupted foreground session instead of waiting
  /// for the next background/foreground flip or connectivity change. The
  /// timer self-cancels once a pass leaves nothing to drive (every row
  /// delivered, cancelled, or terminalized at the retry cap).
  void _scheduleFollowUp({required bool workRemains}) {
    _followUpTimer?.cancel();
    _followUpTimer = null;
    if (!workRemains || !_isInitialized) return;
    _followUpTimer = Timer(_followUpSweepGap, () {
      _followUpTimer = null;
      if (!_isInitialized) return;
      unawaited(sweep());
    });
  }

  /// Arm the follow-up timer only when none is armed. Used by the
  /// repository's retryable-work nudge: unlike [_scheduleFollowUp] (which
  /// resets the deadline at the end of a sweep), a nudge must never postpone
  /// an already-armed deadline, or a steady stream of sends would starve the
  /// sweep indefinitely.
  void _armFollowUpIfIdle() {
    if (!_isInitialized || _followUpTimer != null) return;
    _followUpTimer = Timer(_followUpSweepGap, () {
      _followUpTimer = null;
      if (!_isInitialized) return;
      unawaited(sweep());
    });
  }

  /// Terminalize a pending row that has exhausted its retry budget so it
  /// leaves the pending set, stops re-driving, and stays out of
  /// `getRetryableForOwner` (which caps at `retry_count < maxRetries`).
  ///
  /// When the recipient wrap already landed (`sent`), the message WAS
  /// delivered — only the invisible self-wrap sync is outstanding. Flip
  /// ONLY the self wrap to `failed` (the row then reads as sent/failed,
  /// which renders delivered-looking via the existing State A surface).
  /// Flipping the recipient wrap too would misrender a delivered message
  /// as a red "Not delivered" bubble and let Resend republish it — the
  /// same reason [_surfaceOfflinePendingRows] leaves already-`sent`
  /// recipient wraps untouched. Rows whose recipient wrap is still
  /// pending/failed terminalize both wraps.
  ///
  /// Swallows DAO errors — a failed mark just means the row is
  /// re-evaluated next sweep and terminalized then.
  Future<void> _markInterruptedExhausted(OutgoingDm row) async {
    if (row.recipientWrapStatus == OutgoingWrapStatus.sent) {
      try {
        await _dao.markSelfWrapStatus(
          id: row.id,
          status: OutgoingWrapStatus.failed,
          lastError: 'Exhausted retries without self-wrap confirmation',
        );
      } on Object catch (e) {
        Log.warning(
          'failed to terminalize self wrap for exhausted row ${row.id}: $e',
          name: 'OutgoingDmRetryService',
          category: LogCategory.system,
        );
      }
      return;
    }
    await _terminalizeRow(
      row.id,
      error: 'Exhausted retries without recipient confirmation',
    );
  }

  /// Offline pass: no publish can succeed, so instead of leaving the queue
  /// untouched, surface the rows the user would otherwise misread as
  /// delivered. A still-`pending` recipient wrap renders as a plain sent
  /// bubble — no indicator, no tap affordance — so while the device is
  /// offline an unconfirmed send is indistinguishable from a delivered one
  /// and unreachable from the UI (#6046 "resend swallows the failed
  /// message"). Flip aged pending rows to `failed` (red "Not delivered",
  /// tappable, re-driven by the reconnect sweep) WITHOUT charging the retry
  /// budget — no publish attempt was made. The min-age guard keeps a
  /// legitimately in-flight `sendMessage` row out of this pass; its own
  /// offline fail-fast marks it failed within the publish window anyway.
  /// Rows whose recipient wrap already landed are left alone — the message
  /// was delivered; only the invisible self-wrap sync is outstanding.
  ///
  /// Returns whether unfinished work remains: pending rows still younger
  /// than the min-age guard (they need a later pass to flip), or a failed
  /// fetch (state unknown — retry later). Drives the offline follow-up
  /// scheduling in [sweep].
  Future<bool> _surfaceOfflinePendingRows() async {
    var flipped = 0;
    var youngRemaining = 0;
    try {
      final pending = await _dao.getStillPendingForOwner(_userPubkey);
      for (final row in pending) {
        if (row.recipientWrapStatus != OutgoingWrapStatus.pending) continue;
        final age = _now().difference(row.queuedAt);
        if (age < _interruptedMinAge) {
          youngRemaining++;
          continue;
        }
        await _terminalizeRow(
          row.id,
          error: 'Message not sent: device offline',
        );
        flipped++;
      }
    } on Object catch (e) {
      Log.warning(
        'offline pending-row surfacing failed: $e',
        name: 'OutgoingDmRetryService',
        category: LogCategory.system,
      );
      return true;
    }
    Log.debug(
      'device offline, skipping sweep pass '
      '(unconfirmed rows surfaced as failed: $flipped, '
      'still too young: $youngRemaining)',
      name: 'OutgoingDmRetryService',
      category: LogCategory.system,
    );
    return youngRemaining > 0;
  }

  /// Mark both wraps of [rumorId] `failed` with [error]. Swallows DAO
  /// errors — a failed mark just means the row is re-evaluated on a later
  /// pass and terminalized then.
  Future<void> _terminalizeRow(String rumorId, {required String error}) async {
    try {
      await _dao.markRecipientWrapStatus(
        id: rumorId,
        status: OutgoingWrapStatus.failed,
        lastError: error,
      );
      await _dao.markSelfWrapStatus(
        id: rumorId,
        status: OutgoingWrapStatus.failed,
        lastError: error,
      );
    } on Object catch (e) {
      Log.warning(
        'failed to terminalize row $rumorId: $e',
        name: 'OutgoingDmRetryService',
        category: LogCategory.system,
      );
    }
  }
}
