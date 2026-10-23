// ABOUTME: Runs async tasks one at a time, each once the one before it has
// ABOUTME: settled, so heavy work such as downloads and decodes never overlaps.

/// Runs tasks one at a time, each once the one before it has settled.
class OneAtATime {
  Future<void> _tail = Future<void>.value();

  /// Runs [task] once every task given before it has settled, and completes
  /// with its result. A task that fails fails only its own caller.
  Future<T> run<T>(Future<T> Function() task) {
    final turn = _tail.then((_) => task());
    // The next task waits for this one to settle, failed or not.
    _tail = turn.then<void>((_) {}, onError: (Object _) {});
    return turn;
  }
}
