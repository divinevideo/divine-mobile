// ABOUTME: Bakes the key chroma-key takes were recorded with, one at a time,
// ABOUTME: and steps aside whenever the camera is recording.

import 'dart:async';

import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/services/video_editor/chroma_key_bake_service.dart';
import 'package:openvine/services/video_editor/video_editor_render_service.dart';
import 'package:openvine/services/video_thumbnail_service.dart';
import 'package:pro_video_editor/pro_video_editor.dart' show EditorVideo;
import 'package:unified_logger/unified_logger.dart';

/// Takes a poster frame from the video at `videoPath`, near `timestamp`.
typedef ExtractPosterFn = Future<ThumbnailFileResult?> Function({
  required String videoPath,
  required Duration timestamp,
});

/// Asks the renderer to stop the render running under `renderId`.
typedef CancelRenderFn = Future<void> Function(String renderId);

Future<ThumbnailFileResult?> _extractPosterFromFile({
  required String videoPath,
  required Duration timestamp,
}) => VideoThumbnailService.extractThumbnail(
  videoPath: videoPath,
  targetTimestamp: timestamp,
);

/// Turns chroma-key takes into the composite the viewfinder showed.
///
/// The recorder writes the raw camera footage and records the key as
/// [DivineVideoClip.captureChromaKey]; this renders that key into a new file.
/// Bakes run one at a time, and never alongside a recording: [hold] stops the
/// render in flight and keeps new ones from starting, so the camera's encoder
/// never shares the hardware with a bake. A render a hold stopped starts over
/// on [release] — it is only postponed, never dropped.
class CapturedChromaKeyBaker {
  CapturedChromaKeyBaker({
    ChromaKeyBakeFn? render,
    ExtractPosterFn? extractPoster,
    CancelRenderFn? cancelRender,
  }) : _render = render ?? ChromaKeyBakeService.bakeClip,
       _extractPoster = extractPoster ?? _extractPosterFromFile,
       _cancelRender = cancelRender ?? VideoEditorRenderService.cancelTask;

  static const _logName = 'CapturedChromaKeyBaker';

  final ChromaKeyBakeFn _render;
  final ExtractPosterFn _extractPoster;
  final CancelRenderFn _cancelRender;

  /// The tail of the queue; each bake starts once the one before it settled.
  Future<void> _queue = Future<void>.value();

  /// Completes when the current hold is released, or `null` while none is.
  Completer<void>? _released;

  /// Render id of the bake currently rendering, or `null`.
  String? _activeRenderId;

  /// Whether a hold stopped the render in flight, so its failure is a
  /// postponement rather than an error.
  bool _stoppedByHold = false;

  /// Whether bakes are held back for a recording.
  bool get isHeld => _released != null;

  /// Bakes the key [clip] was recorded with, returning [clip] as it is with
  /// that key burned in: the keyed file, the key recorded against the raw
  /// take so it can be re-tuned from clean footage, and a poster taken from
  /// the keyed video — the old one shows the wall the key removed.
  ///
  /// Throws [ArgumentError] when [clip] has no pending key, and whatever the
  /// render throws when it fails for any reason other than a [hold].
  Future<DivineVideoClip> bake(DivineVideoClip clip) {
    if (!clip.hasPendingCaptureChromaKey) {
      throw ArgumentError.value(clip.id, 'clip', 'has no key waiting to bake');
    }
    final run = _queue.then((_) => _bake(clip));
    _queue = run.then<void>((_) {}, onError: (Object _) {});
    return run;
  }

  /// Stops the render in flight and holds back new ones until [release].
  ///
  /// For a recording about to start: the camera's encoder gets the hardware
  /// to itself. The stopped bake starts over on release.
  void hold() {
    if (isHeld) return;
    _released = Completer<void>();
    final renderId = _activeRenderId;
    if (renderId == null) return;
    _stoppedByHold = true;
    Log.info(
      '⏸️ Postponing the chroma-key bake $renderId for a recording',
      name: _logName,
      category: LogCategory.video,
    );
    unawaited(_cancelRender(renderId));
  }

  /// Lets held bakes run again.
  void release() {
    final released = _released;
    if (released == null) return;
    _released = null;
    released.complete();
  }

  Future<DivineVideoClip> _bake(DivineVideoClip clip) async {
    final chromaKey = clip.captureChromaKey!;
    final baked = await _renderAroundHolds(clip);
    final poster = await _posterOf(baked.video, at: clip.thumbnailTimestamp);
    return clip.copyWith(
      video: baked.video,
      chromaKey: chromaKey,
      chromaKeySourcePath: baked.source,
      clearCaptureChromaKey: true,
      clearForwardVideoPath: true,
      clearReversedVideoPath: true,
      thumbnailPath: poster?.path,
      thumbnailTimestamp: poster?.timestamp,
    );
  }

  /// Renders [clip]'s key, waiting out every hold and starting over when one
  /// stopped the render partway.
  Future<({EditorVideo video, String source})> _renderAroundHolds(
    DivineVideoClip clip,
  ) async {
    final renderId = ChromaKeyBakeService.renderIdFor(clip.id);
    while (true) {
      await _untilReleased();
      _activeRenderId = renderId;
      _stoppedByHold = false;
      try {
        return await _render(
          sourceClip: clip,
          chromaKey: clip.captureChromaKey!,
          renderId: renderId,
        );
      } catch (_) {
        if (!_stoppedByHold) rethrow;
      } finally {
        _activeRenderId = null;
      }
    }
  }

  Future<void> _untilReleased() async {
    while (true) {
      final released = _released;
      if (released == null) return;
      await released.future;
    }
  }

  /// A poster frame of [video] near [at], or `null` when none can be taken —
  /// the clip then keeps its old one.
  Future<ThumbnailFileResult?> _posterOf(
    EditorVideo video, {
    required Duration at,
  }) async {
    final path = video.file?.path;
    if (path == null) return null;
    try {
      return await _extractPoster(videoPath: path, timestamp: at);
    } catch (e) {
      Log.warning(
        '⚠️ Could not take a poster frame from $path: $e',
        name: _logName,
        category: LogCategory.video,
      );
      return null;
    }
  }
}
