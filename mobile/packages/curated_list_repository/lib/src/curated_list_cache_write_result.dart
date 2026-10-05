import 'package:models/models.dart';

/// The outcome of a coordinated cache transaction.
enum CuratedCacheWriteStatus {
  /// Every requested delta reached storage.
  saved,

  /// Storage accepted the merge, but a newer writer won some coordinates.
  conflict,

  /// The backing store rejected the write; its read cache is not proof of save.
  storageRejected,

  /// The originating account or service was replaced before completion.
  superseded,
}

/// Immutable snapshots and outcome of one coordinated write.
class CuratedCacheWriteResult<T> {
  /// Creates a result. [persisted] is present only after a confirmed write.
  const CuratedCacheWriteResult({
    required this.status,
    required this.baseline,
    required this.requested,
    this.persisted,
    this.acknowledgedBeforeWrite,
    this.conflictedIds = const {},
  });

  /// Distinguishes a storage rejection from a version conflict.
  final CuratedCacheWriteStatus status;

  /// The originating store's last acknowledged snapshot.
  final T baseline;

  /// This request's immutable deltas rebased on the acknowledged baseline.
  final T requested;

  /// The merged snapshot the backing store confirmed it accepted.
  final T? persisted;

  /// The confirmed state read before a rejected backing-store attempt.
  ///
  /// This remains distinct from [persisted]: a rejected merge did not save its
  /// new deltas, but must not restore a baseline older than another writer.
  final T? acknowledgedBeforeWrite;

  /// Author coordinates whose requested delta lost to a newer stored value.
  final Set<String> conflictedIds;

  /// Whether every requested change reached storage in the active session.
  bool get succeeded => status == CuratedCacheWriteStatus.saved;
}

/// Selectively reconciles a list write without erasing concurrent local edits.
extension CuratedListWriteReconciliation
    on CuratedCacheWriteResult<List<CuratedList>> {
  /// Restores failed coordinates only while they still match this request.
  ///
  /// Unrelated records and edits made after this request remain untouched.
  List<CuratedList> reconcile(List<CuratedList> current) {
    final before = {for (final list in baseline) list.authorScopedId: list};
    final after = {for (final list in requested) list.authorScopedId: list};
    final actual = {
      for (final list in persisted ?? acknowledgedBeforeWrite ?? baseline)
        list.authorScopedId: list,
    };
    final reconciled = {for (final list in current) list.authorScopedId: list};
    for (final id in {...before.keys, ...after.keys}) {
      if (before[id] == after[id] || reconciled[id] != after[id]) continue;
      final saved = actual[id];
      if (saved == null) {
        reconciled.remove(id);
      } else {
        reconciled[id] = saved;
      }
    }
    return List.unmodifiable(reconciled.values);
  }

  /// Advances accepted local deltas without adopting another writer's records.
  ///
  /// A conflict retains its old baseline so an already-queued stale request
  /// cannot overwrite the winning revision as if it had observed that revision.
  List<CuratedList> get nextBaseline {
    if (persisted == null) return baseline;
    final next = {for (final list in baseline) list.authorScopedId: list};
    final after = {for (final list in requested) list.authorScopedId: list};
    for (final id in {...next.keys, ...after.keys}) {
      if (conflictedIds.contains(id)) continue;
      final requestedList = after[id];
      if (requestedList == null) {
        next.remove(id);
      } else {
        next[id] = requestedList;
      }
    }
    return List.unmodifiable(next.values);
  }
}

/// Reconciles only subscription deltas belonging to this transaction.
extension CuratedSubscriptionWriteReconciliation
    on CuratedCacheWriteResult<Set<String>> {
  /// Restores rejected additions/removals while keeping unrelated IDs.
  Set<String> reconcile(Set<String> current) {
    final reconciled = {...current};
    final actual = persisted ?? acknowledgedBeforeWrite ?? baseline;
    for (final id in {...baseline, ...requested}) {
      if (baseline.contains(id) == requested.contains(id) ||
          reconciled.contains(id) != requested.contains(id)) {
        continue;
      }
      if (actual.contains(id)) {
        reconciled.add(id);
      } else {
        reconciled.remove(id);
      }
    }
    return Set.unmodifiable(reconciled);
  }
}

/// Signals that a local mutation must not report success or publish its delta.
class CuratedCacheWriteException implements Exception {
  /// Creates an exception without embedding cached list contents.
  const CuratedCacheWriteException(this.status);

  /// The failed transaction outcome.
  final CuratedCacheWriteStatus status;

  @override
  String toString() => 'Curated cache write: ${status.name}';
}

/// Rebases already-queued snapshot deltas after an earlier save completes.
///
/// A queued request must not replay a previous request's rejected edit merely
/// because that edit was still in memory when the later snapshot was captured.
abstract final class CuratedCacheWriteSnapshots {
  /// Applies only changes between consecutive requests to the saved baseline.
  static List<CuratedList> rebaseLists(
    List<CuratedList> saved,
    List<CuratedList> preceding,
    List<CuratedList> requested,
  ) {
    final result = {for (final list in saved) list.authorScopedId: list};
    final before = {for (final list in preceding) list.authorScopedId: list};
    final after = {for (final list in requested) list.authorScopedId: list};
    for (final id in {...before.keys, ...after.keys}) {
      if (before[id] == after[id]) continue;
      final next = after[id];
      if (next == null) {
        result.remove(id);
      } else {
        result[id] = next;
      }
    }
    return List.unmodifiable(result.values);
  }

  /// Applies only queued follow/unfollow deltas to the saved baseline.
  static Set<String> rebaseSubscriptions(
    Set<String> saved,
    Set<String> preceding,
    Set<String> requested,
  ) => Set.unmodifiable({
    ...saved.difference(preceding.difference(requested)),
    ...requested.difference(preceding),
  });
}
