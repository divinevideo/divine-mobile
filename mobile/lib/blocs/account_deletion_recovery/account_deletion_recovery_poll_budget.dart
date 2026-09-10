// ABOUTME: Durable start time for the deletion-recovery polling budget.
// ABOUTME: Keyed per attempt so relaunching cannot hand the user a fresh one.

import 'package:shared_preferences/shared_preferences.dart';

/// Remembers when polling for one deletion attempt began.
///
/// The recovery screen polls the server for a bounded time and then offers
/// "contact support". Measuring that bound by accumulating timer delays in a
/// field spends it only while the process lives, so a user who backgrounds the
/// app — the likely thing to do while waiting — restarts the budget at zero on
/// every launch and can never reach the support message however long they
/// wait. Recording a wall-clock start instead makes the bound mean elapsed
/// time.
///
/// Keyed by attempt id, so a genuinely new deletion attempt starts a fresh
/// budget while a relaunch against the same attempt continues the old one.
abstract class AccountDeletionRecoveryPollBudgetStore {
  /// When polling for [attemptId] began, or `null` if it has not yet.
  Future<DateTime?> startedAt(String attemptId);

  /// Records [at] as the start for [attemptId], keeping any existing value so
  /// a relaunch cannot push the deadline out.
  Future<void> recordStartIfAbsent(String attemptId, DateTime at);

  /// Forgets [attemptId]'s budget once the attempt is resolved.
  Future<void> clear(String attemptId);
}

/// Process-local store.
///
/// Deliberately NOT a default on the cubit: the whole point of this type is
/// that the budget outlives the process, and a store that silently forgets is
/// exactly the bug being fixed. Production must pass the durable store, which
/// the constructor now requires. This exists for tests.
class InMemoryAccountDeletionRecoveryPollBudgetStore
    implements AccountDeletionRecoveryPollBudgetStore {
  final Map<String, DateTime> _startedAt = <String, DateTime>{};

  @override
  Future<DateTime?> startedAt(String attemptId) async => _startedAt[attemptId];

  @override
  Future<void> recordStartIfAbsent(String attemptId, DateTime at) async {
    _startedAt.putIfAbsent(attemptId, () => at);
  }

  @override
  Future<void> clear(String attemptId) async {
    _startedAt.remove(attemptId);
  }
}

/// Durable store. This is the one that makes the budget survive a relaunch.
class SharedPreferencesAccountDeletionRecoveryPollBudgetStore
    implements AccountDeletionRecoveryPollBudgetStore {
  SharedPreferencesAccountDeletionRecoveryPollBudgetStore(this._prefs);

  final SharedPreferences _prefs;

  /// Interpolated with the attempt id, so each attempt owns its own slot and
  /// no fixed key can carry one account's budget into another's session.
  static const keyPrefix = 'account_deletion.pollBudgetStartedAt.';

  @override
  Future<DateTime?> startedAt(String attemptId) async {
    final millis = _prefs.getInt('$keyPrefix$attemptId');
    return millis == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(millis, isUtc: true);
  }

  @override
  Future<void> recordStartIfAbsent(String attemptId, DateTime at) async {
    final key = '$keyPrefix$attemptId';
    if (_prefs.containsKey(key)) return;
    await _prefs.setInt(key, at.toUtc().millisecondsSinceEpoch);
  }

  @override
  Future<void> clear(String attemptId) async {
    await _prefs.remove('$keyPrefix$attemptId');
  }
}

/// Anchors on the durable deletion receipt when this install has one for the
/// attempt, and falls back to [fallback] when it does not.
///
/// The receipt is the better home: it already exists, is already cleaned up
/// with the attempt, and needs no preference key of its own. But the recovery
/// screen is reachable *without* a receipt — the router gates on the server's
/// attempt status, not on local state, so a reinstall mid-deletion, a receipt
/// cleared as corrupt, or a deletion submitted from another device all land on
/// the screen with nothing stored locally. Those are exactly the long waits
/// this budget exists for, so they get a keyed fallback rather than a
/// process-local anchor that restarts every launch.
class ReceiptAnchoredPollBudgetStore
    implements AccountDeletionRecoveryPollBudgetStore {
  ReceiptAnchoredPollBudgetStore({
    required this.readReceiptAnchor,
    required this.fallback,
  });

  /// The receipt's attempt id and anchor, or `null` when none is stored.
  final ({String attemptId, DateTime startedAt})? Function() readReceiptAnchor;

  final AccountDeletionRecoveryPollBudgetStore fallback;

  ({String attemptId, DateTime startedAt})? _anchorFor(String attemptId) {
    final anchor = readReceiptAnchor();
    return anchor != null && anchor.attemptId == attemptId ? anchor : null;
  }

  @override
  Future<DateTime?> startedAt(String attemptId) async =>
      _anchorFor(attemptId)?.startedAt ?? await fallback.startedAt(attemptId);

  @override
  Future<void> recordStartIfAbsent(String attemptId, DateTime at) async {
    // A receipt always carries an anchor once read, so there is nothing to
    // record on that path.
    if (_anchorFor(attemptId) != null) return;
    await fallback.recordStartIfAbsent(attemptId, at);
  }

  @override
  Future<void> clear(String attemptId) async {
    // The receipt's anchor goes when the receipt does, so only the fallback
    // key needs clearing here.
    await fallback.clear(attemptId);
  }
}
