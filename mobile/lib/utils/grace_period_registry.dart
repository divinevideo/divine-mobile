// ABOUTME: A keyed pool that keeps a shared value alive for a grace period
// ABOUTME: after its last holder lets go, so a remount can pick it back up

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:unified_logger/unified_logger.dart';

const _logName = 'GracePeriodRegistry';

/// Lends out one shared value per key and keeps it for a grace period after the
/// last holder lets go.
///
/// Built for the editor's detached clips. Its layer stack renders `LayerWidget`
/// without a key, so dragging a layer re-parents it and Flutter cannot match
/// the old subtree: the widget is rebuilt at a new position and the old element
/// discarded, about once a second. Anything owned by that `State` — a video
/// decoder above all — is torn down and stood back up just as often.
///
/// A release therefore *schedules* teardown instead of performing it, and a
/// remount inside [graceWindow] takes the very same value back.
class GracePeriodRegistry<T extends Object> {
  GracePeriodRegistry({required this.graceWindow, required this.dispose});

  /// How long a released value is kept before it is torn down.
  ///
  /// Only has to outlast a remount, which lands in the same frame. Seconds of
  /// slack cost one idle value for a moment; too little brings the churn back.
  final Duration graceWindow;

  /// Tears a value down once nothing holds it any more.
  final Future<void> Function(T value) dispose;

  final Map<String, _Entry<T>> _entries = {};

  /// Live entries, for tests to assert nothing is leaked.
  @visibleForTesting
  int get entryCount => _entries.length;

  /// The value for [key] when it is already built, taking a reference.
  ///
  /// Synchronous on purpose: a remount must render in its very first frame.
  /// Awaiting the resolve leaves the widget drawing nothing for a frame or
  /// two, and at once a second that gap *is* the flicker — even when the value
  /// itself was preserved.
  ///
  /// Returns `null` when nothing is built for [key] yet; the caller then falls
  /// back to [acquire].
  T? acquireIfReady(String key) {
    final entry = _entries[key];
    final resolved = entry?.resolved;
    if (entry == null || resolved == null) return null;
    entry
      ..cancelReaper()
      ..refs += 1;
    return resolved;
  }

  /// The value for [key], building it with [create] on first use.
  ///
  /// Concurrent callers share the one in-flight build rather than racing two.
  Future<T?> acquire(String key, Future<T?> Function() create) {
    final existing = _entries[key];
    if (existing != null) {
      existing
        ..cancelReaper()
        ..refs += 1;
      return existing.value;
    }

    final entry = _Entry<T>(create())..refs = 1;
    _entries[key] = entry;
    return entry.value;
  }

  /// Gives back the value for [key], tearing it down once nothing holds it and
  /// [graceWindow] has passed.
  void release(String key) {
    final entry = _entries[key];
    if (entry == null) return;

    entry.refs -= 1;
    if (entry.refs > 0) return;

    entry.cancelReaper();
    // Held, not discarded: a holder that comes back within the window cancels
    // this and keeps the value.
    entry.reaper = Timer(graceWindow, () => _reap(key));
  }

  void _reap(String key) {
    final entry = _entries[key];
    // A late re-acquire wins: it cancelled the timer and bumped refs, and this
    // callback can still be queued behind that.
    if (entry == null || entry.refs > 0) return;
    _entries.remove(key);
    unawaited(_dispose(entry));
  }

  Future<void> _dispose(_Entry<T> entry) async {
    try {
      final value = await entry.value;
      if (value != null) await dispose(value);
    } catch (error, stackTrace) {
      Log.error(
        'Failed to release a pooled value',
        name: _logName,
        error: error,
        stackTrace: stackTrace,
        category: LogCategory.video,
      );
    }
  }

  /// Drops every entry without disposing, for test isolation.
  @visibleForTesting
  void resetForTesting() {
    for (final entry in _entries.values) {
      entry.cancelReaper();
    }
    _entries.clear();
  }
}

class _Entry<T extends Object> {
  _Entry(this.value) {
    unawaited(value.then((built) => resolved = built));
  }

  final Future<T?> value;

  /// The built value once it exists, so [GracePeriodRegistry.acquireIfReady]
  /// can hand it over without an await.
  T? resolved;

  int refs = 0;
  Timer? reaper;

  void cancelReaper() {
    reaper?.cancel();
    reaper = null;
  }
}
