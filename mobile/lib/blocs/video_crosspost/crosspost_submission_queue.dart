// ABOUTME: Owns crosspost submissions after their platform picker closes.
// ABOUTME: Polls jobs without a modal; close() cancels retries and polling.

import 'package:openvine/blocs/video_crosspost/video_crosspost_cubit.dart';
import 'package:openvine/blocs/video_crosspost/video_crosspost_state.dart';
import 'package:openvine/models/crosspost_models.dart';
import 'package:openvine/repositories/crossposting_repository.dart';
import 'package:unified_logger/unified_logger.dart';

/// Account-scoped owner for submissions that outlive the crosspost sheet.
class CrosspostSubmissionQueue {
  CrosspostSubmissionQueue({required CrosspostingRepository repository})
    : _repository = repository;

  final CrosspostingRepository _repository;
  final _pending = <VideoCrosspostCubit>{};
  bool _closed = false;

  /// Submits to the connected [connections] without retaining a widget.
  ///
  /// Returns the last state, or null when [close] ran first.
  Future<VideoCrosspostState?> submit({
    required String eventId,
    required List<CrosspostingConnection> connections,
    void Function(VideoCrosspostState)? onUpdate,
  }) async {
    if (_closed) {
      _log(eventId, 'not started: the account changed');
      return null;
    }
    _log(
      eventId,
      'started for ${[for (final c in connections) c.platform.wireName]}',
    );
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
      final result = cubit.isClosed ? null : cubit.state;
      _logOutcome(eventId, result);
      return result;
    } finally {
      _pending.remove(cubit);
      // Awaiting close delivers the last states, such as an immediate submit
      // failure, to onUpdate before the listener is cancelled.
      await cubit.close();
      await updates?.cancel();
    }
  }

  // The user may not be looking when a background job ends, so its
  // outcome must reach the logs that support exports.
  void _logOutcome(String eventId, VideoCrosspostState? result) {
    if (result == null) {
      _log(eventId, 'cancelled before it finished: the account changed');
      return;
    }
    if (result.status == VideoCrosspostStatus.submitFailed) {
      _log(eventId, 'rejected: ${result.submitError?.name}', warning: true);
      return;
    }
    final jobs = result.jobs.map(_describeJob).join(', ');
    if (result.pollTimedOut) {
      _log(eventId, 'stopped polling with jobs pending: $jobs', warning: true);
      return;
    }
    final unsuccessful = result.jobs.any(
      (job) =>
          job.status == CrosspostJobStatus.failed ||
          job.status == CrosspostJobStatus.needsReauth,
    );
    _log(eventId, 'finished: $jobs', warning: unsuccessful);
  }

  static String _describeJob(CrosspostJob job) {
    final error = job.errorCode == null ? '' : ' (${job.errorCode})';
    return '${job.platform} ${job.status.name}$error job ${job.id}';
  }

  void _log(String eventId, String message, {bool warning = false}) {
    final line = 'Crosspost of event $eventId $message';
    if (warning) {
      Log.warning(line, name: _logName, category: LogCategory.system);
    } else {
      Log.info(line, name: _logName, category: LogCategory.system);
    }
  }

  static const _logName = 'CrosspostSubmissionQueue';

  /// Cancels pending retries and polling; server-side jobs keep running.
  Future<void> close() async {
    _closed = true;
    await Future.wait([for (final cubit in _pending) cubit.close()]);
    _pending.clear();
  }
}
