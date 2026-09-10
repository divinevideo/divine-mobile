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
