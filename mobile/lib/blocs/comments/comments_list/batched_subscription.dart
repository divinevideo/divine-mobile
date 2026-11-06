// ABOUTME: Listens to a stream and hands its events over in windows, so a
// ABOUTME: burst becomes one batch instead of one UI update per event.
// ABOUTME: Nothing is dropped.

import 'dart:async';

/// Listens to [stream] and hands its events to [onBatch] in groups.
///
/// The first event after a batch opens a [window]; every event that arrives
/// before it closes joins the same batch. A burst of any size is therefore
/// one call, and a steady stream is at most one call per [window]: the UI
/// updates at a bounded rate without losing an event, which a rate limit that
/// discards the excess does (#6744).
///
/// The returned [BatchedSubscription.flush] hands over what is held without
/// waiting for the window, and [BatchedSubscription.cancel] discards it.
BatchedSubscription<T> batchedListen<T>(
  Stream<T> stream, {
  required Duration window,
  required void Function(List<T> batch) onBatch,
  void Function(Object error)? onError,
}) => BatchedSubscription<T>._(stream, window, onBatch, onError);

/// A subscription that batches the events of its stream.
///
/// Created by [batchedListen].
class BatchedSubscription<T> implements StreamSubscription<T> {
  BatchedSubscription._(
    Stream<T> stream,
    this._window,
    this._onBatch,
    void Function(Object error)? onError,
  ) {
    _inner = stream.listen(
      _hold,
      onError: (Object error) => onError?.call(error),
      onDone: flush,
    );
  }

  final Duration _window;
  final void Function(List<T> batch) _onBatch;
  late final StreamSubscription<T> _inner;
  final List<T> _held = [];
  Timer? _timer;

  void _hold(T event) {
    _held.add(event);
    _timer ??= Timer(_window, flush);
  }

  /// Hands over the events held so far, if any, and closes the window.
  void flush() {
    _timer?.cancel();
    _timer = null;
    if (_held.isEmpty) return;
    final batch = List<T>.of(_held);
    _held.clear();
    _onBatch(batch);
  }

  @override
  Future<void> cancel() {
    _timer?.cancel();
    _timer = null;
    _held.clear();
    return _inner.cancel();
  }

  @override
  void onData(void Function(T data)? handleData) => _inner.onData(handleData);

  @override
  void onError(Function? handleError) => _inner.onError(handleError);

  @override
  void onDone(void Function()? handleDone) => _inner.onDone(handleDone);

  @override
  bool get isPaused => _inner.isPaused;

  @override
  void pause([Future<void>? resumeSignal]) => _inner.pause(resumeSignal);

  @override
  void resume() => _inner.resume();

  @override
  Future<E> asFuture<E>([E? futureValue]) => _inner.asFuture<E>(futureValue);
}
