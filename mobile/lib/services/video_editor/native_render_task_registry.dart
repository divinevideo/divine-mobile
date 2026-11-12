// ABOUTME: Tracks in-flight native pro_video_editor tasks started by this app
// ABOUTME: Shared registry so teardown cancellation sees every native render

import 'dart:async';

import 'package:openvine/constants/video_editor_constants.dart';
import 'package:pro_video_editor/pro_video_editor.dart'
    show RenderCanceledException;
import 'package:unified_logger/unified_logger.dart';

/// Registry of in-flight native `pro_video_editor` tasks started by this app.
///
/// Teardown cancellation (`AppLifecycleState.detached`) can only cancel native
/// work it knows about, so every app-owned native render entry point must run
/// inside [track] or [trackExclusively]. Lives apart from the render services
/// themselves because both the composite render service and the stop-motion
/// assembler register here, and the former already imports the latter.
class NativeRenderTaskRegistry {
  NativeRenderTaskRegistry._();

  static final Map<String, _Registration> _registrations =
      <String, _Registration>{};

  /// Ids of the native tasks currently in flight.
  static Set<String> get activeTaskIds => Set.unmodifiable(_registrations.keys);

  /// Runs [operation], tracking it as active under [id] until it settles.
  ///
  /// A task re-registering the same [id] takes ownership of the entry; the
  /// displaced call's cleanup then leaves the newer registration alone (the
  /// token identity check), so it stays cancellable.
  static Future<T> track<T>(String id, Future<T> Function() operation) async {
    final registration = _register(id, exclusive: false);
    try {
      return await operation();
    } finally {
      _release(id, registration);
    }
  }

  /// Runs [operation] as the only task under [id], tracked like [track].
  ///
  /// An earlier [trackExclusively] call still holding [id] is stopped through
  /// [cancel] and waited out before [operation] starts. The native side
  /// refuses a task whose id is still taken with `TASK_ALREADY_RUNNING`, and a
  /// cancel can come back while the earlier task still holds the id: when it
  /// lands before the plugin has handed that task to the platform, or when a
  /// second call already cancelled it and the platform no longer knows the id.
  ///
  /// An earlier [track] registration is cancelled but not waited for: it may
  /// wrap this very call, as the loop alignment's render does, and waiting
  /// for it would wait for good.
  ///
  /// The cancel and the wait together last at most
  /// [VideoEditorConstants.renderTaskHandoverTimeout]. Past that, the
  /// earlier task is treated as stuck and [operation] starts anyway.
  ///
  /// Of several calls waiting on the same [id], only the newest starts. The
  /// others throw [RenderCanceledException] without starting, as they would
  /// once the newest had cancelled them.
  static Future<T> trackExclusively<T>(
    String id,
    Future<T> Function() operation, {
    required Future<void> Function(String id) cancel,
  }) async {
    final previous = _registrations[id];
    final registration = _register(id, exclusive: true);
    try {
      if (previous != null) {
        await _handOver(id, previous, cancel).timeout(
          VideoEditorConstants.renderTaskHandoverTimeout,
          onTimeout: () => Log.warning(
            'Native task $id did not let go of its id within '
            '${VideoEditorConstants.renderTaskHandoverTimeout.inSeconds} s, '
            'starting the next one anyway',
            name: 'NativeRenderTaskRegistry',
            category: LogCategory.video,
          ),
        );
        if (!identical(_registrations[id], registration)) {
          throw const RenderCanceledException();
        }
      }
      return await operation();
    } finally {
      _release(id, registration);
    }
  }

  static Future<void> _handOver(
    String id,
    _Registration previous,
    Future<void> Function(String id) cancel,
  ) async {
    await cancel(id);
    if (previous.exclusive) await previous.settled;
  }

  static _Registration _register(String id, {required bool exclusive}) =>
      _registrations[id] = _Registration(exclusive: exclusive);

  static void _release(String id, _Registration registration) {
    if (identical(_registrations[id], registration)) {
      _registrations.remove(id);
    }
    registration.settle();
  }

  /// Drops all tracking without cancelling anything.
  ///
  /// Test teardown only — the registry has no production reason to forget a
  /// task that is still running natively.
  static void reset() => _registrations.clear();
}

/// One call's claim on a task id, settled once the call has finished.
class _Registration {
  _Registration({required this.exclusive});

  /// Whether the call came through
  /// [NativeRenderTaskRegistry.trackExclusively].
  final bool exclusive;

  final _settled = Completer<void>();

  Future<void> get settled => _settled.future;

  void settle() {
    if (!_settled.isCompleted) _settled.complete();
  }
}
