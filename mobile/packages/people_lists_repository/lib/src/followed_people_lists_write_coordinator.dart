import 'dart:async';

/// Serializes followed-list writes and account cleanup for each viewer.
///
/// Repositories and the account-clear port share one coordinator so cleanup
/// cannot finish while an earlier refresh can still write a followed copy.
/// Relay reads happen outside the queue; their apply step rechecks follows
/// inside it. Different viewers do not block each other.
class FollowedPeopleListsWriteCoordinator {
  final Map<String, Future<void>> _tails = {};
  final Map<String, _FollowedListsRefresh> _refreshes = {};

  /// Shares a relay refresh while at least one caller remains active.
  /// A fully canceled refresh retires permanently; a new caller starts fresh.
  Future<void> refresh({
    required String viewerPubkey,
    required Future<void> Function(bool Function() isCancelled) operation,
    bool Function()? isCancelled,
  }) {
    final active = _refreshes[viewerPubkey];
    if (active != null && !active.isCancelled) {
      active.callers.add(isCancelled ?? _neverCancelled);
      return active.future;
    }
    final pending = _FollowedListsRefresh(isCancelled ?? _neverCancelled);
    _refreshes[viewerPubkey] = pending;
    return pending.future =
        Future<void>.sync(
          () => operation(() => pending.isCancelled),
        ).whenComplete(() {
          if (identical(_refreshes[viewerPubkey], pending)) {
            final _ = _refreshes.remove(viewerPubkey);
          }
        });
  }

  static bool _neverCancelled() => false;

  /// Queues [operation] after earlier writes for [viewerPubkey].
  ///
  /// Errors propagate to the caller without poisoning subsequent writes.
  Future<T> run<T>({
    required String viewerPubkey,
    required Future<T> Function() operation,
  }) async {
    final previous = _tails[viewerPubkey] ?? Future<void>.value();
    final completed = Completer<void>();
    final tail = completed.future;
    _tails[viewerPubkey] = tail;
    await previous;
    try {
      return await operation();
    } finally {
      completed.complete();
      if (identical(_tails[viewerPubkey], tail)) {
        final _ = _tails.remove(viewerPubkey);
      }
    }
  }
}

class _FollowedListsRefresh {
  _FollowedListsRefresh(bool Function() caller) : callers = [caller];

  final List<bool Function()> callers;
  late final Future<void> future;
  bool _retired = false;

  bool get isCancelled {
    if (_retired) return true;
    return _retired = callers.every((caller) => caller());
  }
}
