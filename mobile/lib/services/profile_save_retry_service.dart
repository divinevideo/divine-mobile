// ABOUTME: Auto-sweeps the durable pending-profile-save slot (#3161) and
// ABOUTME: re-drives the queued kind-0 publish via
// ABOUTME: ProfileRepository.drivePendingSave. Triggered by app-foreground
// ABOUTME: transitions and connectivity/relay-reconnect; mirrors
// ABOUTME: OutgoingDmRetryService.

import 'dart:async';

import 'package:db_client/db_client.dart';
import 'package:meta/meta.dart';
import 'package:nostr_sdk/nip19/pubkey_for_logs.dart';
import 'package:nostr_sdk/signer/signer_failure.dart';
import 'package:openvine/services/crash_reporting_service.dart';
import 'package:profile_repository/profile_repository.dart';
import 'package:unified_logger/unified_logger.dart';

/// Crashlytics `reason:` suffix for the sweep's top-level catch. Inlined as a
/// single site per `error_handling.md` (a dedicated *ReportableSites class is
/// only warranted once a feature has 2+ migrated sites).
const _sweepTopLevelSite = 'ProfileSaveRetryService.sweepTopLevel';

/// Backoff configuration for [ProfileSaveRetryService].
///
/// Defaults match `OutgoingDmRetryConfig` / `PendingActionRetryConfig`
/// (5 retries, 2s → 5min, 2× backoff).
class ProfileSaveRetryConfig {
  const ProfileSaveRetryConfig({
    this.maxRetries = 5,
    this.initialDelay = const Duration(seconds: 2),
    this.maxDelay = const Duration(minutes: 5),
    this.backoffMultiplier = 2.0,
  });

  /// Maximum publish attempts before the slot is marked failed.
  final int maxRetries;

  /// Delay before the second attempt (the first retry).
  final Duration initialDelay;

  /// Upper bound on the backoff delay.
  final Duration maxDelay;

  /// Multiplier applied per prior attempt.
  final double backoffMultiplier;

  /// Minimum gap required before a row whose previous attempt count is
  /// [retryCount] may be retried. Clamped at [maxDelay].
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

/// Re-drives the single durable pending profile/username save for one account
/// until a relay confirms the kind-0 publish, then the slot clears itself.
///
/// **Triggers:** [appForegroundStream] transitions to `true`, each event on
/// [retryTriggerStream] (wired to connectivity/relay-reconnect), and a fresh
/// enqueue observed on the durable slot (a new generation) — so a save stranded
/// by a failed editor fast-path is re-driven without waiting for the next
/// foreground/connectivity event. The provider seeds the foreground stream with
/// the current state on subscription, so the cold-start sweep fires
/// automatically.
///
/// **Re-entrancy:** a trigger that arrives while a pass is in flight is
/// coalesced into a single follow-up pass, not dropped. A newer generation that
/// replaced an older, in-flight one is therefore always driven — the older
/// pass's generation-guarded writes no-op against the newer row, then the loop
/// re-reads and drives the current generation (latest intent wins).
///
/// **Per-row backoff:** a slot whose `lastAttemptAt + backoff(retryCount)` is
/// in the future is skipped this pass.
///
/// **Terminal state:** once [ProfileSaveRetryConfig.maxRetries] is reached, or
/// the divine.video username claim fails permanently (taken, reserved, or
/// invalid format), the slot is marked `failed` and left for the user to retry
/// manually via [retryNow].
class ProfileSaveRetryService {
  ProfileSaveRetryService({
    required ProfileRepository profileRepository,
    required PendingProfileSavesDao pendingProfileSavesDao,
    required String userPubkey,
    required Stream<bool> appForegroundStream,
    required CrashReportingService crashReporting,
    Stream<void>? retryTriggerStream,
    ProfileSaveRetryConfig retryConfig = const ProfileSaveRetryConfig(),
    DateTime Function() now = DateTime.now,
  }) : _profileRepository = profileRepository,
       _dao = pendingProfileSavesDao,
       _userPubkey = userPubkey,
       _appForegroundStream = appForegroundStream,
       _retryTriggerStream = retryTriggerStream,
       _retryConfig = retryConfig,
       _now = now,
       _crashReporting = crashReporting;

  final ProfileRepository _profileRepository;
  final PendingProfileSavesDao _dao;
  final String _userPubkey;
  final Stream<bool> _appForegroundStream;
  final Stream<void>? _retryTriggerStream;
  final ProfileSaveRetryConfig _retryConfig;
  final DateTime Function() _now;
  final CrashReportingService _crashReporting;

  StreamSubscription<bool>? _foregroundSubscription;
  StreamSubscription<void>? _retryTriggerSubscription;

  /// Reactive view of the durable slot. Makes the sweep **level-triggered**: a
  /// fresh enqueue (new [PendingProfileSaveEntry.generation]) wakes an
  /// otherwise-idle service, so a save stranded by a failed editor fast-path is
  /// re-driven without waiting for the *next* foreground/connectivity event
  /// (#3161 review).
  StreamSubscription<PendingProfileSaveEntry?>? _pendingSaveSubscription;

  /// Self-scheduled next attempt. A recovery signal (foreground/connectivity)
  /// can arrive before the relay pool has reconnected, so relying on that one
  /// signal would strand the save until the *next* signal. After every
  /// non-terminal outcome the sweep arms this timer for the row's remaining
  /// backoff, so one offline→online transition keeps retrying until a relay
  /// confirms the publish (#3161 review).
  Timer? _retryTimer;

  bool _isInitialized = false;
  bool _isSweeping = false;

  /// A trigger (foreground/connectivity/enqueue/chain) arrived while a sweep was
  /// in flight. Coalesced into a single follow-up pass drained by [sweep]'s loop
  /// once the current pass finishes, so a mid-sweep enqueue is never dropped.
  bool _sweepAgain = false;

  /// Set before awaiting cancellation in [dispose] so a sweep resuming past an
  /// `await` (or a queued timer callback) after teardown becomes a no-op — it
  /// must not arm a new timer or mutate the (now account-detached) slot.
  bool _disposed = false;

  /// The last [PendingProfileSaveEntry.generation] the slot watcher reacted to.
  /// De-dupes the watcher against the service's own status/retry writes (same
  /// generation) and the initial priming emission, so only a genuinely new
  /// enqueue wakes an idle service.
  String? _lastWakeGeneration;

  bool get isInitialized => _isInitialized;

  @visibleForTesting
  bool get isSweeping => _isSweeping;

  /// Subscribe to the trigger streams and run a cold-start sweep. Idempotent.
  Future<void> initialize() async {
    if (_isInitialized) return;
    _isInitialized = true;

    // A slot left `syncing` by an app-kill mid-publish is reset to `pending`
    // so this session retries it.
    await _profileRepository.resetInterruptedPendingSave(_userPubkey);

    // Prime the watcher with the current generation before subscribing so its
    // initial emission (and the service's own later writes, which keep the same
    // generation) don't spuriously wake the service — only a fresh enqueue with
    // a new generation does. The cold-start sweep for whatever is already queued
    // is driven by the foreground seed below, as before.
    _lastWakeGeneration = (await _dao.get(_userPubkey))?.generation;
    _pendingSaveSubscription = _dao.watch(_userPubkey).listen(_onSlotChanged);

    _foregroundSubscription = _appForegroundStream.listen((foreground) {
      if (foreground) unawaited(sweep());
    });
    _retryTriggerSubscription = _retryTriggerStream?.listen((_) {
      unawaited(sweep());
    });

    // The cold-start sweep is driven by the foreground stream, which the
    // provider seeds with the current state on subscription (mirrors
    // OutgoingDmRetryService) — no explicit sweep() call needed here.

    Log.info(
      'initialized for ${pubkeyForLogs(_userPubkey)}',
      name: 'ProfileSaveRetryService',
      category: LogCategory.system,
    );
  }

  /// Cancel the trigger subscriptions and pending retry timer and mark the
  /// service un-init. Idempotent.
  ///
  /// [_disposed] is set **first**, before awaiting cancellation, so an
  /// in-flight sweep resuming past an `await` (and any queued timer callback)
  /// sees teardown and bails without arming a new timer or mutating the slot —
  /// `cancel`/`_cancelRetryTimer` alone only stop work that exists at this
  /// instant, not work a resuming sweep is about to schedule (#3161 review).
  Future<void> dispose() async {
    _disposed = true;
    await _pendingSaveSubscription?.cancel();
    _pendingSaveSubscription = null;
    await _foregroundSubscription?.cancel();
    _foregroundSubscription = null;
    await _retryTriggerSubscription?.cancel();
    _retryTriggerSubscription = null;
    _cancelRetryTimer();
    _isInitialized = false;
  }

  /// Reset a `failed` slot back to `pending` (fresh retry budget) and sweep.
  /// Wired to the UI's manual "retry" affordance.
  Future<void> retryNow() async {
    final entry = await _dao.get(_userPubkey);
    if (entry == null) return;
    // Re-upsert resets retryCount → 0, status → pending, lastError → null and
    // mints a fresh generation. Record it as the last woken generation so the
    // watcher doesn't fire a redundant backstop sweep for our own re-enqueue —
    // the explicit sweep below already drives it.
    _lastWakeGeneration = await _dao.upsert(
      PendingProfileSaveEntry(
        userPubkey: entry.userPubkey,
        payloadJson: entry.payloadJson,
        claimConfirmed: entry.claimConfirmed,
        queuedAt: _now(),
      ),
    );
    await sweep();
  }

  /// Drive the pending-save slot to a resting point. Public so tests and the
  /// manual-retry path can drive it directly.
  ///
  /// Runs [_runSweepOnce] in a loop that drains [_sweepAgain]: a trigger that
  /// arrives while a pass is in flight (an enqueue, a completed older drive that
  /// left a newer generation queued, a foreground/connectivity event) is
  /// coalesced into one follow-up pass instead of being dropped — so a newer
  /// generation that replaced an older, in-flight one is always driven, without
  /// a second external signal (#3161 review).
  @visibleForTesting
  Future<void> sweep() async {
    if (_disposed) return;
    if (_isSweeping) {
      _sweepAgain = true;
      return;
    }
    _isSweeping = true;

    try {
      do {
        _sweepAgain = false;
        await _runSweepOnce();
      } while (!_disposed && _sweepAgain);
    } on Object catch (e, stackTrace) {
      Log.error(
        'sweep failed: $e',
        name: 'ProfileSaveRetryService',
        category: LogCategory.system,
        error: e,
        stackTrace: stackTrace,
      );
      // A remote signer that timed out or could not be reached is a bad
      // network, not a defect. The slot stays queued, and the next
      // foreground or connectivity trigger drives it again.
      if (!isUnreachableSignerFailure(e)) {
        unawaited(
          _crashReporting.recordError(
            e,
            stackTrace,
            reason: _sweepTopLevelSite,
          ),
        );
      }
    } finally {
      _isSweeping = false;
    }
  }

  /// One pass over the pending-save slot. Bails at every async boundary when
  /// the service was disposed mid-pass, so a resuming sweep can't arm a timer
  /// or mutate the (account-detached) slot after teardown.
  Future<void> _runSweepOnce() async {
    final entry = await _dao.get(_userPubkey);
    if (_disposed) return;
    if (entry == null) {
      _cancelRetryTimer();
      return;
    }

    // A failed slot awaits a manual retry — don't auto-retry it.
    if (entry.status == PendingProfileSaveStatus.failed) {
      _cancelRetryTimer();
      return;
    }

    final generation = entry.generation;

    // Per-row backoff. When a trigger arrives inside the backoff window, arm
    // the timer for the remaining time rather than dropping the attempt.
    final lastAttempt = entry.lastAttemptAt;
    if (lastAttempt != null) {
      final backoff = _retryConfig.backoffFor(entry.retryCount);
      final gap = _now().difference(lastAttempt);
      if (gap < backoff) {
        _scheduleRetry(backoff - gap);
        return;
      }
    }

    // Claim the attempt for this generation. If a newer save replaced the row
    // between the read above and here, this no-ops (false) — re-read and drive
    // whatever is queued now (latest intent wins) on the next loop pass.
    final claimed = await _dao.markStatus(
      userPubkey: _userPubkey,
      status: PendingProfileSaveStatus.syncing,
      generation: generation,
      attemptAt: _now(),
    );
    if (_disposed) return;
    if (!claimed) {
      await _chainIfNewerGeneration(generation);
      return;
    }

    final outcome = await _profileRepository.drivePendingSave(
      _userPubkey,
      expectedGeneration: generation,
    );
    if (_disposed) return;

    switch (outcome) {
      case PendingSaveDriveOutcome.confirmed:
      case PendingSaveDriveOutcome.noPendingSave:
        // Our generation is done: cleared by the repository (confirmed) or
        // already gone / superseded (noPendingSave). If a newer generation
        // slipped in and our generation-guarded clear no-op'd against it,
        // _chainIfNewerGeneration drives that one next pass.
        _cancelRetryTimer();
      case PendingSaveDriveOutcome.permanentFailure:
        await _dao.markStatus(
          userPubkey: _userPubkey,
          status: PendingProfileSaveStatus.failed,
          lastError:
              'Username claim failed permanently '
              '(taken, reserved, or invalid format)',
          generation: generation,
          attemptAt: _now(),
        );
        if (_disposed) return;
        _cancelRetryTimer();
      case PendingSaveDriveOutcome.retryableFailure:
        if (entry.retryCount + 1 >= _retryConfig.maxRetries) {
          await _dao.markStatus(
            userPubkey: _userPubkey,
            status: PendingProfileSaveStatus.failed,
            lastError:
                'Could not publish after ${_retryConfig.maxRetries} attempts',
            generation: generation,
            attemptAt: _now(),
          );
          if (_disposed) return;
          _cancelRetryTimer();
        } else {
          await _dao.incrementRetry(
            _userPubkey,
            generation: generation,
            attemptAt: _now(),
          );
          if (_disposed) return;
          final reverted = await _dao.markStatus(
            userPubkey: _userPubkey,
            status: PendingProfileSaveStatus.pending,
            generation: generation,
            attemptAt: _now(),
          );
          if (_disposed) return;
          // Arm the next attempt so one recovery signal eventually publishes
          // even if the relay pool wasn't ready this pass. Only when the row
          // is still ours — a newer save that slipped in owns its scheduling.
          if (reverted) {
            _scheduleRetry(_retryConfig.backoffFor(entry.retryCount + 1));
          }
        }
    }

    await _chainIfNewerGeneration(generation);
  }

  /// Request a follow-up pass when the slot now holds a **different**
  /// generation than [drivenGeneration] — a newer save landed (or replaced an
  /// older, in-flight one) while we were working, so the older pass's writes
  /// no-op'd against it and it would otherwise sit un-driven. A cleared/empty
  /// slot, a failed slot, or the same generation needs no follow-up, which is
  /// what keeps this from looping.
  Future<void> _chainIfNewerGeneration(String drivenGeneration) async {
    if (_disposed) return;
    final current = await _dao.get(_userPubkey);
    if (_disposed) return;
    if (current != null &&
        current.status != PendingProfileSaveStatus.failed &&
        current.generation != drivenGeneration) {
      _sweepAgain = true;
    }
  }

  /// Slot-watcher callback: wake an idle service when a genuinely new save is
  /// enqueued (a new generation), so a save stranded by a failed editor
  /// fast-path drive is re-driven without waiting for the next
  /// foreground/connectivity event. The service's own status/retry writes keep
  /// the same generation and the priming emission matches [_lastWakeGeneration],
  /// so neither re-wakes it.
  void _onSlotChanged(PendingProfileSaveEntry? entry) {
    if (_disposed) return;
    final generation = entry?.generation;
    if (generation == _lastWakeGeneration) return;
    _lastWakeGeneration = generation;
    if (entry == null || entry.status == PendingProfileSaveStatus.failed) {
      return;
    }
    // A pass in flight will pick this generation up via its coalesced loop; an
    // idle service arms a short backstop sweep. The delay lets the enqueuer's
    // own immediate publish attempt (the editor fast-path) confirm and clear
    // the slot first in the common online case, so the backstop finds nothing
    // to do — it only re-drives a save the fast-path failed to land.
    if (_isSweeping) {
      _sweepAgain = true;
      return;
    }
    _scheduleRetry(_retryConfig.initialDelay);
  }

  /// Arm (replacing any pending) the self-scheduled next attempt for [delay].
  /// A negative delay is clamped to zero. The timer fires a fresh [sweep]; if
  /// one happens to be in progress when it fires (or it was armed from the
  /// enqueue watcher while idle), [sweep]'s own re-entrancy guard coalesces it
  /// into a follow-up pass. No-ops after [dispose].
  void _scheduleRetry(Duration delay) {
    if (_disposed) return;
    _retryTimer?.cancel();
    final clamped = delay.isNegative ? Duration.zero : delay;
    _retryTimer = Timer(clamped, () {
      _retryTimer = null;
      if (_disposed) return;
      unawaited(sweep());
    });
  }

  void _cancelRetryTimer() {
    _retryTimer?.cancel();
    _retryTimer = null;
  }
}
