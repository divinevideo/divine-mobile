// ABOUTME: Times how long the video editor takes to become usable after entry.
// ABOUTME: Emits one editor_ready trace per open, with fixed-vocabulary fields.

import 'package:clock/clock.dart';
import 'package:openvine/observability/performance_operation.dart';
import 'package:openvine/services/performance_monitoring_service.dart';
import 'package:unified_logger/unified_logger.dart';

/// How the creator reached the video editor.
enum EditorEntry {
  /// Next after recording in the camera.
  recording,

  /// Clips picked on the Library's clips tab.
  clips,

  /// A saved draft reopened from the Library's drafts tab.
  draft;

  /// The entry for an editor opened on [hasDraft] or, without one, from the
  /// Library when [fromLibrary] holds.
  static EditorEntry of({required bool hasDraft, required bool fromLibrary}) {
    if (hasDraft) return draft;
    return fromLibrary ? clips : recording;
  }
}

/// One `editor_ready` trace, from the moment the editor route is entered
/// until the editor can be used.
///
/// The editor is usable once it shows its clips (at once for clips handed
/// over by the recorder or the Library; for a draft, once the draft, its
/// thumbnails and the fonts its text layers use are restored) and, when the
/// clips are video, its preview player has loaded them and shown the first
/// frame. Before that the play button is disabled, the timeline holds its
/// thumbnails back, and the preview shows a still poster. A stop-motion
/// composition has no player, so its editor is usable once it shows them.
///
/// Every method after the first terminal one is ignored, so the trace stops
/// exactly once: `ready`, `failed` (the editor or its preview could not
/// load), or `left` (the editor closed before it became usable).
class EditorReadyTrace {
  EditorReadyTrace(PerformanceTraceMonitor monitor, {required this.entry})
    : _operation = PerformanceOperation(monitor, traceName);

  static const traceName = 'editor_ready';

  final EditorEntry entry;
  final PerformanceOperation _operation;
  final Stopwatch _stopwatch = clock.stopwatch()..start();

  _EditorPreview? _preview;
  int? _clipCount;
  int? _clipsLoadedMs;
  int? _playerReadyMs;
  int? _firstFrameMs;
  bool _finished = false;

  /// Whether the trace still waits for the editor to become usable.
  bool get isPending => !_finished;

  /// Records that the editor shows its [clipCount] clips. Only the first call
  /// counts.
  ///
  /// [stopMotion] says whether every clip is a frames-only stop-motion clip,
  /// which plays without a preview player.
  void clipsLoaded({required int clipCount, required bool stopMotion}) {
    if (_finished || _clipsLoadedMs != null) return;
    _clipsLoadedMs = _elapsedMs;
    _clipCount = clipCount;
    _preview = clipCount == 0
        ? _EditorPreview.none
        : stopMotion
        ? _EditorPreview.stopMotion
        : _EditorPreview.video;
    _finishIfReady();
  }

  /// Records that the preview player loaded the clips and can play them.
  void previewLoaded() {
    if (_finished || _playerReadyMs != null) return;
    _playerReadyMs = _elapsedMs;
    _finishIfReady();
  }

  /// Records that the preview showed its first video frame.
  void previewFirstFrame() {
    if (_finished || _firstFrameMs != null) return;
    _firstFrameMs = _elapsedMs;
    _finishIfReady();
  }

  /// Records that the editor or its preview failed to load.
  void failed() => _finish('failed');

  /// Records that the editor closed. Ends the trace as `left` unless it has
  /// already ended.
  void left() => _finish('left');

  int get _elapsedMs => _stopwatch.elapsedMilliseconds;

  void _finishIfReady() {
    final preview = _preview;
    if (preview == null) return;
    if (preview == _EditorPreview.video &&
        (_playerReadyMs == null || _firstFrameMs == null)) {
      return;
    }
    _finish('ready');
  }

  void _finish(String outcome) {
    if (_finished) return;
    _finished = true;
    _stopwatch.stop();
    final attributes = {
      'entry': entry.name,
      'outcome': outcome,
      'clips': clipCountBucket(_clipCount),
      'preview': _preview?.attribute ?? 'unknown',
    };
    final metrics = {
      'total_ms': _elapsedMs,
      'clips_loaded_ms': ?_clipsLoadedMs,
      'player_ready_ms': ?_playerReadyMs,
      'first_frame_ms': ?_firstFrameMs,
    };
    // Builds that do not report to Firebase still show the sample here.
    Log.info(
      '$traceName $attributes $metrics',
      name: 'EditorReadyTrace',
      category: LogCategory.video,
    );
    _operation.finish(attributes: attributes, metrics: metrics);
  }

  /// The `clips` attribute for [count] clips, or `unknown` when the editor
  /// closed before it knew its clips.
  ///
  /// Buckets follow how many takes a recording has: about seven in ten have
  /// one, and fewer than one in fifty more than six.
  static String clipCountBucket(int? count) => switch (count) {
    null => 'unknown',
    <= 0 => '0',
    1 => '1',
    <= 3 => '2-3',
    <= 6 => '4-6',
    _ => '7+',
  };
}

enum _EditorPreview {
  video('video'),
  stopMotion('stop_motion'),
  none('none');

  const _EditorPreview(this.attribute);

  final String attribute;
}
