import 'dart:async';

import 'package:curated_list_repository/src/curated_list_cache_write_result.dart';
import 'package:models/models.dart';

/// Serializes shared-cache changes across service/account replacements.
///
/// Each writer contributes only its own deltas. Optimistic read-cache values
/// from a rejected backing write are never treated as acknowledged storage.
class CuratedListCacheWriteCoordinator {
  Future<void> _tail = Future<void>.value();
  final _rejectedLists = <Object, _RejectedSnapshot<List<CuratedList>>>{};
  final _rejectedSubscriptions = <Object, _RejectedSnapshot<Set<String>>>{};

  /// Forgets refused read-cache overlays when the backing key was removed.
  ///
  /// An absent key must stay distinct from a refused empty value, especially
  /// when an account sweep clears the old account's cache.
  void cacheKeyRemoved(Object cacheKey) {
    _rejectedLists.remove(cacheKey);
    _rejectedSubscriptions.remove(cacheKey);
  }

  /// Compatibility wrapper reporting whether every list delta was saved.
  Future<bool> saveLists({
    required List<CuratedList> baseline,
    required List<CuratedList> current,
    required List<CuratedList> Function() read,
    required Future<bool> Function(List<CuratedList>) write,
  }) async => (await saveListsWithResult(
    baseline: baseline,
    current: current,
    read: read,
    write: write,
  )).succeeded;

  /// Merges author coordinates and reports storage rejection separately.
  Future<CuratedCacheWriteResult<List<CuratedList>>> saveListsWithResult({
    required List<CuratedList> baseline,
    required List<CuratedList> current,
    required List<CuratedList> Function() read,
    required Future<bool> Function(List<CuratedList>) write,
    Object? cacheKey,
    bool Function()? isCurrent,
  }) {
    final beforeSnapshot = List<CuratedList>.unmodifiable(baseline);
    final requested = List<CuratedList>.unmodifiable(current);
    return _serialize(() async {
      CuratedCacheWriteResult<List<CuratedList>> result(
        CuratedCacheWriteStatus status, {
        List<CuratedList>? persisted,
        List<CuratedList>? acknowledgedBeforeWrite,
        Set<String> conflicts = const {},
      }) => CuratedCacheWriteResult(
        status: status,
        baseline: beforeSnapshot,
        requested: requested,
        persisted: persisted,
        acknowledgedBeforeWrite: acknowledgedBeforeWrite,
        conflictedIds: Set.unmodifiable(conflicts),
      );
      if (isCurrent != null && !isCurrent()) {
        return result(CuratedCacheWriteStatus.superseded);
      }
      var observed = List<CuratedList>.unmodifiable(read());
      final rejected = _rejectedLists[cacheKey];
      if (rejected != null && _sameLists(observed, rejected.attempted)) {
        observed = rejected.before;
      } else {
        _rejectedLists.remove(cacheKey);
      }
      final before = {
        for (final list in beforeSnapshot) list.authorScopedId: list,
      };
      final after = {for (final list in requested) list.authorScopedId: list};
      final latest = {for (final list in observed) list.authorScopedId: list};
      final conflicts = <String>{};
      for (final entry in before.entries) {
        if (!after.containsKey(entry.key) && latest[entry.key] == entry.value) {
          latest.remove(entry.key);
        } else if (!after.containsKey(entry.key) &&
            latest.containsKey(entry.key)) {
          conflicts.add(entry.key);
        }
      }
      for (final entry in after.entries) {
        if (before[entry.key] == entry.value) continue;
        final stored = latest[entry.key];
        if (stored == entry.value) continue;
        if (stored == null ||
            stored == before[entry.key] ||
            entry.value.updatedAt.isAfter(stored.updatedAt)) {
          latest[entry.key] = entry.value;
        } else {
          conflicts.add(entry.key);
        }
      }
      final merged = List<CuratedList>.unmodifiable(latest.values);
      final bool saved;
      try {
        saved = await write(merged);
      } on Object {
        if (cacheKey != null) {
          _rejectedLists[cacheKey] = _RejectedSnapshot(observed, merged);
        }
        rethrow;
      }
      if (cacheKey != null) {
        if (saved) {
          _rejectedLists.remove(cacheKey);
        } else {
          _rejectedLists[cacheKey] = _RejectedSnapshot(observed, merged);
        }
      }
      if (isCurrent != null && !isCurrent()) {
        return result(CuratedCacheWriteStatus.superseded);
      }
      if (!saved) {
        return result(
          CuratedCacheWriteStatus.storageRejected,
          acknowledgedBeforeWrite: observed,
        );
      }
      return result(
        conflicts.isEmpty
            ? CuratedCacheWriteStatus.saved
            : CuratedCacheWriteStatus.conflict,
        persisted: merged,
        conflicts: conflicts,
      );
    });
  }

  /// Compatibility wrapper reporting whether subscription deltas were saved.
  Future<bool> saveSubscriptions({
    required Set<String> baseline,
    required Set<String> current,
    required Set<String> Function() read,
    required Future<bool> Function(Set<String>) write,
  }) async => (await saveSubscriptionsWithResult(
    baseline: baseline,
    current: current,
    read: read,
    write: write,
  )).succeeded;

  /// Reads acknowledged set values without adopting a refused optimistic cache.
  ///
  /// A replacement or cleared cache supersedes the rejected attempt. This
  /// also lets deletion-record readers use the same state as queued writers.
  Set<String> readAcknowledgedSubscriptions({
    required Object? cacheKey,
    required Set<String> Function() read,
  }) {
    final observed = Set<String>.unmodifiable(read());
    final rejected = _rejectedSubscriptions[cacheKey];
    if (rejected != null &&
        observed.length == rejected.attempted.length &&
        observed.containsAll(rejected.attempted)) {
      return rejected.before;
    }
    _rejectedSubscriptions.remove(cacheKey);
    return observed;
  }

  /// Merges subscription deltas without removing another writer's follows.
  Future<CuratedCacheWriteResult<Set<String>>> saveSubscriptionsWithResult({
    required Set<String> baseline,
    required Set<String> current,
    required Set<String> Function() read,
    required Future<bool> Function(Set<String>) write,
    Object? cacheKey,
    bool Function()? isCurrent,
  }) {
    final beforeSnapshot = Set<String>.unmodifiable(baseline);
    final requested = Set<String>.unmodifiable(current);
    return _serialize(() async {
      CuratedCacheWriteResult<Set<String>> result(
        CuratedCacheWriteStatus status, {
        Set<String>? persisted,
        Set<String>? acknowledgedBeforeWrite,
      }) => CuratedCacheWriteResult(
        status: status,
        baseline: beforeSnapshot,
        requested: requested,
        persisted: persisted,
        acknowledgedBeforeWrite: acknowledgedBeforeWrite,
      );
      if (isCurrent != null && !isCurrent()) {
        return result(CuratedCacheWriteStatus.superseded);
      }
      final observed = readAcknowledgedSubscriptions(
        cacheKey: cacheKey,
        read: read,
      );
      final merged = Set<String>.unmodifiable({
        ...observed.difference(beforeSnapshot.difference(requested)),
        ...requested.difference(beforeSnapshot),
      });
      final bool saved;
      try {
        saved = await write(merged);
      } on Object {
        if (cacheKey != null) {
          _rejectedSubscriptions[cacheKey] = _RejectedSnapshot(
            observed,
            merged,
          );
        }
        rethrow;
      }
      if (cacheKey != null) {
        if (saved) {
          _rejectedSubscriptions.remove(cacheKey);
        } else {
          _rejectedSubscriptions[cacheKey] = _RejectedSnapshot(
            observed,
            merged,
          );
        }
      }
      if (isCurrent != null && !isCurrent()) {
        return result(CuratedCacheWriteStatus.superseded);
      }
      return result(
        saved
            ? CuratedCacheWriteStatus.saved
            : CuratedCacheWriteStatus.storageRejected,
        persisted: saved ? merged : null,
        acknowledgedBeforeWrite: saved ? null : observed,
      );
    });
  }

  bool _sameLists(List<CuratedList> first, List<CuratedList> second) {
    if (first.length != second.length) return false;
    for (var index = 0; index < first.length; index++) {
      if (first[index] != second[index]) return false;
    }
    return true;
  }

  Future<T> _serialize<T>(Future<T> Function() operation) async {
    final previous = _tail;
    final completed = Completer<void>();
    _tail = completed.future;
    try {
      await previous;
      return await operation();
    } finally {
      completed.complete();
    }
  }
}

class _RejectedSnapshot<T> {
  const _RejectedSnapshot(this.before, this.attempted);
  final T before;
  final T attempted;
}
