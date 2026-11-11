// ABOUTME: Serializes native resource operations independently of UI flow state.
class ConsentOperationQueue {
  Future<void> _pending = Future<void>.value();

  Future<void> get settled => _pending;

  Future<void> run(Future<void> Function() operation) =>
      _pending = _pending.then((_) => operation());
}
