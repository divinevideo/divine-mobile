// ABOUTME: Owns account-choice observation and stale-apply protection for moderation.
// ABOUTME: Delivers distinct typed snapshots to the label-cache owner for reconciliation.

import 'dart:async';

import 'package:openvine/services/account_preference_store.dart';
import 'package:unified_logger/unified_logger.dart';

class ModerationAccountPreferenceSnapshot {
  ModerationAccountPreferenceSnapshot({
    required Set<String> labelers,
    required this.followingEnabled,
  }) : labelers = Set.unmodifiable(labelers);

  final Set<String> labelers;
  final bool followingEnabled;

  bool sameAs(ModerationAccountPreferenceSnapshot other) =>
      followingEnabled == other.followingEnabled &&
      labelers.length == other.labelers.length &&
      labelers.containsAll(other.labelers);
}

/// The service owns label caches and relay subscriptions; this binding owns
/// observing account choices, deduplicating snapshots and invalidating work
/// after a different choice or disposal. An unrelated preference event cannot
/// cancel an in-flight reconciliation of unchanged moderation choices.
class ModerationAccountPreferences {
  ModerationAccountPreferences({
    required AccountPreferenceStore preferences,
    required String labelersStorageKey,
    required String followingEnabledStorageKey,
    required Future<void> Function(
      ModerationAccountPreferenceSnapshot snapshot,
      bool Function() isCurrent,
    )
    reconcile,
  }) : _preferences = preferences,
       _labelersStorageKey = labelersStorageKey,
       _followingEnabledStorageKey = followingEnabledStorageKey,
       _reconcile = reconcile {
    _subscription = preferences.changes.listen((_) => _refresh());
  }

  final AccountPreferenceStore _preferences;
  final String _labelersStorageKey;
  final String _followingEnabledStorageKey;
  final Future<void> Function(
    ModerationAccountPreferenceSnapshot,
    bool Function(),
  )
  _reconcile;
  StreamSubscription<void>? _subscription;
  ModerationAccountPreferenceSnapshot? _previous;
  int _generation = 0;
  bool _closed = false;

  void _refresh() {
    if (_closed) return;
    final snapshot = ModerationAccountPreferenceSnapshot(
      labelers:
          (_preferences.read(_labelersStorageKey) as List?)
              ?.cast<String>()
              .toSet() ??
          {},
      followingEnabled:
          _preferences.read(_followingEnabledStorageKey) as bool? ?? false,
    );
    if (_previous?.sameAs(snapshot) ?? false) return;
    _previous = snapshot;
    final generation = ++_generation;
    unawaited(
      _reconcile(
        snapshot,
        () => !_closed && generation == _generation,
      ).catchError((Object error, StackTrace stack) {
        if (!_closed && generation == _generation) _previous = null;
        Log.warning(
          'Unable to refresh trusted account labelers',
          name: 'ModerationAccountPreferences',
          category: LogCategory.system,
        );
      }),
    );
  }

  void close() {
    _closed = true;
    ++_generation;
    unawaited(_subscription?.cancel());
  }
}
