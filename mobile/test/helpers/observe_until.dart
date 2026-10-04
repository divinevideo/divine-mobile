// ABOUTME: Observes async conditions with owned deadlines and nonoverlapping probes.
// ABOUTME: Paces live-backend consistency checks and cancels timers when complete.

import 'dart:async';

/// Observes a condition that exposes no completion notification, such as a
/// live backend's eventual consistency. Probes never overlap. Both the retry
/// timer and the deadline are cancelled when the condition resolves or fails.
///
/// Purely local async work should use its completion future or event-queue
/// pumping instead. The interval here paces external probes, not assertions.
Future<T> observeUntil<T>({
  required FutureOr<T> Function() probe,
  required bool Function(T) ready,
  required T initialValue,
  required Duration interval,
  required Duration timeout,
}) async {
  final completion = Completer<T>();
  var latest = initialValue;
  Timer? retry;
  final deadline = Timer(timeout, () => completion.complete(latest));

  Future<void> check() async {
    try {
      final value = await probe();
      if (completion.isCompleted) return;
      latest = value;
      if (ready(value)) {
        completion.complete(value);
      } else {
        retry = Timer(interval, () => unawaited(check()));
      }
    } on Object catch (error, stack) {
      if (!completion.isCompleted) completion.completeError(error, stack);
    }
  }

  unawaited(check());
  try {
    return await completion.future;
  } finally {
    retry?.cancel();
    deadline.cancel();
  }
}
