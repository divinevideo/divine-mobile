// ABOUTME: Retires curated-list writers before shared account caches are swept.
// ABOUTME: Drains dispatched storage writes across all account containers.

import 'dart:async';

import 'package:curated_list_repository/curated_list_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:unified_logger/unified_logger.dart';

/// Owns the write barrier for one device preference store.
class CuratedListSessionCoordinator {
  CuratedListSessionCoordinator._(this.writes);

  /// Account containers sharing preferences must also share the write barrier.
  ///
  /// Keeping this attached weakly to the preference instance covers legacy
  /// service constructors as well as injected providers and auth cleanup.
  factory CuratedListSessionCoordinator.forPreferences(
    SharedPreferences preferences, {
    CuratedListCacheWriteCoordinator? writes,
  }) => _coordinators[preferences] ??= CuratedListSessionCoordinator._(
    writes ?? CuratedListCacheWriteCoordinator(),
  );

  static final _coordinators = Expando<CuratedListSessionCoordinator>();

  final CuratedListCacheWriteCoordinator writes;
  final _leases = <CuratedListSessionLease>{};
  int _cleanupDepth = 0;

  /// A service's lease is permanent: returning to the same account cannot
  /// authorize continuations captured before an earlier account switch.
  CuratedListSessionLease acquire() {
    final lease = CuratedListSessionLease._(this);
    if (_cleanupDepth != 0) {
      lease._retired = true;
    } else {
      _leases.add(lease);
    }
    return lease;
  }

  /// Runs auxiliary cache/journal writes on the same queue as list saves.
  Future<T> runCurrent<T>(
    CuratedListSessionLease lease,
    Future<T> Function() operation, {
    required T cancelled,
  }) => writes.runExclusive(() async {
    if (!lease.isCurrent) return cancelled;
    final result = await operation();
    return lease.isCurrent ? result : cancelled;
  });

  /// Invalidates outgoing writers before waiting for already dispatched disk
  /// work. Queued writers inspect their invalid lease before touching storage.
  Future<T> clearCaches<T>(Future<T> Function() clear) {
    _cleanupDepth++;
    for (final lease in _leases.toList(growable: false)) {
      lease.retire();
    }
    return writes.runExclusive(clear).whenComplete(() => _cleanupDepth--);
  }

  /// Retires writers before incoming sign-in can begin its identity sweep.
  Future<void> retireAndDrain() => clearCaches(() async {});
}

/// Captured by one service instance and never renewed after retirement.
class CuratedListSessionLease {
  CuratedListSessionLease._(this._coordinator);
  final CuratedListSessionCoordinator _coordinator;
  bool _retired = false;
  final _listOperationTails = <String, Future<void>>{};

  /// Serializes mutations for one addressable list within this session.
  /// Lease and owner guards cancel queued work before it changes local state.
  Future<T> runListOperation<T>(
    String listId,
    Future<T> Function() operation, {
    required bool Function() isCurrentOwner,
    T? cancelled,
  }) async {
    T superseded() {
      Log.warning(
        'Curated list operation ${CuratedCacheWriteStatus.superseded.name}',
        name: 'CuratedListService',
        category: LogCategory.system,
      );
      return cancelled as T;
    }

    if (!isCurrent || !isCurrentOwner()) return superseded();
    final previous = _listOperationTails[listId] ?? Future<void>.value();
    final completed = Completer<void>();
    final tail = completed.future;
    _listOperationTails[listId] = tail;
    await previous;
    try {
      if (!isCurrent || !isCurrentOwner()) return superseded();
      return await operation();
    } finally {
      completed.complete();
      if (identical(_listOperationTails[listId], tail)) {
        final _ = _listOperationTails.remove(listId);
      }
    }
  }

  bool get isCurrent => !_retired;

  void retire() {
    _retired = true;
    _coordinator._leases.remove(this);
  }
}
