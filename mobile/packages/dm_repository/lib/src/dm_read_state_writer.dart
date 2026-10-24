// ABOUTME: Fences stale DM read captures and drains issued local persistence.
// ABOUTME: Owner drains survive provider disposal without waiting on relays.

import 'package:db_client/db_client.dart';
import 'package:dm_repository/src/dm_sync_state.dart';

/// Tracks local read journal and dismissal writes independently of delivery.
class DmReadStateWriter {
  /// Creates the local writer and optional device-lifetime owner registration.
  DmReadStateWriter({
    required this.conversations,
    required this.syncState,
    this.onOwnerCreated,
  });

  /// Disposable conversation cache used to capture exact read boundaries.
  final ConversationsDao conversations;

  /// Durable owner journal, when available.
  final DmSyncState? syncState;

  /// Retains an owner's local drain outside the repository's provider lifetime.
  final void Function(String owner, Future<void> Function() close)?
  onOwnerCreated;
  final _owners = <String, _OwnerWrites>{};
  bool _closed = false;

  /// Captures permission before asynchronous boundary reads begin.
  DmReadWriteLease lease(String owner, bool Function() isCurrent) {
    final writes = _owners.putIfAbsent(owner, () {
      final writes = _OwnerWrites();
      onOwnerCreated?.call(owner, writes.close);
      return writes;
    });
    return DmReadWriteLease._(
      owner,
      writes,
      () => !_closed && isCurrent(),
    );
  }

  /// Waits only for writes already issued; captured reads are fenced by caller.
  Future<void> drain() => Future.wait(
    _owners.values.map((writes) => writes.drain()),
  );

  /// Permanently closes this provider instance, including all retained owners.
  Future<void> close() async {
    _closed = true;
    await Future.wait(_owners.values.map((writes) => writes.close()));
  }

  /// Persists captured read boundaries before changing disposable cache rows.
  Future<Map<String, int>> remember(
    DmReadWriteLease lease,
    Set<String> ids,
    String? Function(String) tupleKey,
  ) async {
    final sync = syncState;
    if (sync == null || !lease.isCurrent) return {};
    final rows = await conversations.getAllConversations(
      ownerPubkey: lease.owner,
    );
    final cursors = <String, int>{};
    final boundaries = <String, int>{};
    final knownIds = <String, Set<String>>{};
    for (final row in rows) {
      if (!lease.isCurrent) return {};
      if (!ids.contains(row.id)) continue;
      final tuple = tupleKey(row.participantPubkeys);
      if (tuple == null) continue;
      final read = row.lastReadTimestamp ?? 0;
      final captured = await conversations.captureDismissalBoundary(
        row.id,
        ownerPubkey: lease.owner,
      );
      if (!lease.isCurrent) return {};
      if (captured == null) continue;
      cursors[tuple] = captured.timestamp > read ? captured.timestamp : read;
      knownIds[tuple] = captured.knownMessageIds;
      boundaries[row.id] = cursors[tuple]!;
    }
    if (cursors.isNotEmpty && lease.isCurrent) {
      await lease.write(
        () => sync.rememberReadCursors(
          lease.owner,
          cursors,
          boundaryMessageIds: knownIds,
        ),
      );
    }
    return boundaries;
  }
}

/// Owner and session permission for a captured local action.
class DmReadWriteLease {
  DmReadWriteLease._(this.owner, this._writes, this._isCurrent);

  /// The initiating owner, never sampled again after an await.
  final String owner;
  final _OwnerWrites _writes;
  final bool Function() _isCurrent;

  /// False after teardown, account replacement, or explicit owner erasure.
  bool get isCurrent => !_writes.closed && _isCurrent();

  /// Registers only local storage work, never signer or publication futures.
  Future<T> write<T>(Future<T> Function() action) {
    if (!isCurrent) throw StateError('DM local write session ended');
    return _writes.write(action);
  }
}

class _OwnerWrites {
  bool closed = false;
  final _pending = <Future<void>>{};

  Future<T> write<T>(Future<T> Function() action) {
    final operation = Future<T>.sync(action);
    late final Future<void> settled;
    settled = operation
        .then<void>((_) {}, onError: (Object _, StackTrace _) {})
        .whenComplete(() => _pending.remove(settled));
    _pending.add(settled);
    return operation;
  }

  Future<void> drain() async {
    while (_pending.isNotEmpty) {
      await Future.wait(_pending.toList());
    }
  }

  Future<void> close() {
    closed = true;
    return drain();
  }
}
