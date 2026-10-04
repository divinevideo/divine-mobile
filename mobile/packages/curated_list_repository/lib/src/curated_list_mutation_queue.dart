// ABOUTME: Serializes owned list mutations with stable account identity.
// ABOUTME: Queued work cancels when its author changes before it starts.

import 'dart:async';

/// Writes to one author-qualified list run in order, including privacy flips.
class CuratedListMutationQueue {
  final Map<String, Future<void>> _tails = {};

  /// Runs a mutation only while the account that queued it remains current.
  Future<T> run<T>(
    String listId,
    Future<T> Function() operation, {
    required String? Function() currentOwner,
    T? cancelled,
  }) async {
    final owner = currentOwner();
    final key = '$owner:$listId';
    final previous = _tails[key] ?? Future<void>.value();
    final completed = Completer<void>();
    final tail = completed.future;
    _tails[key] = tail;
    await previous;
    try {
      if (currentOwner() != owner) return cancelled as T;
      return await operation();
    } finally {
      completed.complete();
      if (identical(_tails[key], tail)) {
        final _ = _tails.remove(key);
      }
    }
  }
}
