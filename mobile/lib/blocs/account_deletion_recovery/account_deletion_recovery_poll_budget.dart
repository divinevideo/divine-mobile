// ABOUTME: Durable start time for the deletion-recovery polling budget.
// ABOUTME: Keyed per attempt so relaunching cannot renew the support timeout.

import 'package:shared_preferences/shared_preferences.dart';

abstract class AccountDeletionRecoveryPollBudgetStore {
  Future<DateTime?> startedAt(String attemptId);

  /// Records [at] for [attemptId] only when no start exists yet.
  Future<void> recordStartIfAbsent(String attemptId, DateTime at);

  Future<void> clear(String attemptId);
}

/// Process-local implementation for tests.
///
/// This is deliberately not a Cubit default: production must provide the
/// durable implementation or relaunching would recreate the original bug.
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

class SharedPreferencesAccountDeletionRecoveryPollBudgetStore
    implements AccountDeletionRecoveryPollBudgetStore {
  SharedPreferencesAccountDeletionRecoveryPollBudgetStore(this._prefs);

  final SharedPreferences _prefs;

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
    if (!await _prefs.setInt(key, at.toUtc().millisecondsSinceEpoch)) {
      throw StateError('Could not persist account deletion polling budget');
    }
  }

  @override
  Future<void> clear(String attemptId) async {
    if (!await _prefs.remove('$keyPrefix$attemptId')) {
      throw StateError('Could not clear account deletion polling budget');
    }
  }
}
