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
  /// An unavailable operation client also retires its query. Live joiners
  /// retry using their own operation instead of accepting that no-op result.
  Future<void> refresh({
    required String viewerPubkey,
    required Future<void> Function(bool Function() isCancelled) operation,
    bool Function()? isCancelled,
    bool Function()? isOperationUnavailable,
  }) {
    final active = _refreshes[viewerPubkey];
    if (active != null && !active.isCancelled) {
      active.callers.add(isCancelled ?? _neverCancelled);
      return _joinRefresh(
        active,
        viewerPubkey: viewerPubkey,
        operation: operation,
        isCancelled: isCancelled,
        isOperationUnavailable: isOperationUnavailable,
      );
    }
    final pending = _FollowedListsRefresh(
      isCancelled ?? _neverCancelled,
      isOperationUnavailable ?? _neverCancelled,
    );
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

  // A joining repository may have a live client even if the client which
  // started the shared query retires while that query is in flight.
  Future<void> _joinRefresh(
    _FollowedListsRefresh active, {
    required String viewerPubkey,
    required Future<void> Function(bool Function() isCancelled) operation,
    bool Function()? isCancelled,
    bool Function()? isOperationUnavailable,
  }) async {
    await active.future;
    if (!active.isOperationUnavailable ||
        (isCancelled?.call() ?? false) ||
        (isOperationUnavailable?.call() ?? false)) {
      return;
    }
    await refresh(
      viewerPubkey: viewerPubkey,
      operation: operation,
      isCancelled: isCancelled,
      isOperationUnavailable: isOperationUnavailable,
    );
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
  _FollowedListsRefresh(bool Function() caller, this._isOperationUnavailable)
    : callers = [caller];

  final bool Function() _isOperationUnavailable;
  bool get isOperationUnavailable => _isOperationUnavailable();

  final List<bool Function()> callers;
  late final Future<void> future;
  bool _retired = false;

  bool get isCancelled {
    if (_retired) return true;
    return _retired =
        isOperationUnavailable || callers.every((caller) => caller());
  }
}
