// ABOUTME: Retains account-local write drains across provider disposal.
// ABOUTME: Account erasure waits these drains without waiting for relay delivery.

/// Owned by the device scope and shared across account containers. A disposed
/// account provider's
/// close future stays registered until its local writes finish.
class AccountStateWriteBarrier {
  final _writers = <String, Set<_AccountWriter>>{};

  /// Returns the same retained close operation used by provider disposal.
  Future<void> Function() register(
    String owner,
    Future<void> Function() close,
  ) {
    final writers = _writers.putIfAbsent(owner, () => {});
    late final _AccountWriter writer;
    writer = _AccountWriter(close, () {
      writers.remove(writer);
      if (writers.isEmpty) _writers.remove(owner);
    });
    writers.add(writer);
    return writer.close;
  }

  Future<void> stop(String owner) async {
    // Include writers registered while an earlier batch was draining.
    while (_writers[owner]?.isNotEmpty ?? false) {
      await Future.wait(
        _writers[owner]!.toList().map((writer) => writer.close()),
      );
    }
  }
}

class _AccountWriter {
  _AccountWriter(this._close, this._finished);

  final Future<void> Function() _close;
  final void Function() _finished;
  Future<void>? _closing;

  Future<void> close() => _closing ??= Future<void>.sync(_close).then((_) {
    _finished();
  });
}
