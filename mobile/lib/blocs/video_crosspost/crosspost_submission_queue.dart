// ABOUTME: Owns crosspost submissions after their platform picker closes.
// ABOUTME: Tracks jobs without holding a modal and cancels on account changes.

import 'package:openvine/blocs/video_crosspost/video_crosspost_cubit.dart';
import 'package:openvine/blocs/video_crosspost/video_crosspost_state.dart';
import 'package:openvine/repositories/crossposting_repository.dart';

/// Account-scoped owner for submissions that outlive the crosspost sheet.
class CrosspostSubmissionQueue {
  CrosspostSubmissionQueue({required CrosspostingRepository repository})
    : _repository = repository;

  final CrosspostingRepository _repository;
  final _pending = <VideoCrosspostCubit>{};
  bool _closed = false;

  /// Captures the selected connections and submits without retaining a widget.
  /// A null result means the owning account or provider scope was disposed.
  Future<VideoCrosspostState?> submit({
    required String eventId,
    required List<CrosspostingConnection> connections,
    void Function(VideoCrosspostState)? onUpdate,
  }) async {
    if (_closed) return null;
    final cubit = VideoCrosspostCubit(
      repository: _repository,
      eventId: eventId,
      initialConnections: List.unmodifiable(connections),
    );
    _pending.add(cubit);
    final updates = onUpdate == null
        ? null
        : cubit.stream.listen((state) {
            if (!_closed) onUpdate(state);
          });
    try {
      await cubit.submit();
      if (!cubit.isClosed && cubit.state.hasPendingJobs) {
        await cubit.stream.firstWhere(
          (state) => state.status == VideoCrosspostStatus.finished,
          orElse: () => cubit.state,
        );
      }
      return cubit.isClosed ? null : cubit.state;
    } finally {
      _pending.remove(cubit);
      // Release timers when jobs finish, polling times out, or the owning
      // account goes away. Server-side jobs survive client cancellation.
      // Closing drains queued state events before cancelling the listener,
      // including an immediately rejected submission's final failure.
      await cubit.close();
      await updates?.cancel();
    }
  }

  Future<void> close() async {
    _closed = true;
    await Future.wait([for (final cubit in _pending) cubit.close()]);
    _pending.clear();
  }
}
