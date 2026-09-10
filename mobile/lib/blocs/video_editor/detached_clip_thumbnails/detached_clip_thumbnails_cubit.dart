// ABOUTME: Frames behind a detached clip's bar on the timeline, pooled so
// ABOUTME: selecting the row does not re-extract the whole strip

import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart'
    show ValueListenable, visibleForTesting;
import 'package:openvine/blocs/close_guard.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/models/video_editor/detached_clip_layer.dart';
import 'package:openvine/services/video_editor/clip_thumbnail_manager.dart';
import 'package:openvine/services/video_thumbnail_service.dart'
    show StripThumbnail;
import 'package:openvine/utils/grace_period_registry.dart';
import 'package:openvine/utils/path_resolver.dart';

/// One extracted frame: where it sits in the clip, and the file holding it.
typedef DetachedClipFrame = ({Duration timestamp, String path});

/// One detached clip's extracted frames, kept for as long as anything holds it.
class DetachedClipThumbnails {
  DetachedClipThumbnails._(this._manager, this._clipId);

  /// Wraps an already-built [manager] for [clipId].
  ///
  /// Lets a test drive the strip from a stubbed extraction stream instead of a
  /// platform channel.
  @visibleForTesting
  DetachedClipThumbnails.withManager(
    ClipThumbnailManager manager,
    String clipId,
  ) : this._(manager, clipId);

  /// Replaces [open] in tests.
  @visibleForTesting
  static Future<DetachedClipThumbnails?> Function(
    DivineVideoClip clip,
    double devicePixelRatio,
  )?
  openOverride;

  /// Extracts the frames for [clip] at [devicePixelRatio].
  static Future<DetachedClipThumbnails?> open(
    DivineVideoClip clip,
    double devicePixelRatio,
  ) async {
    final override = openOverride;
    if (override != null) return override(clip, devicePixelRatio);

    final manager = ClipThumbnailManager()
      ..sync(clips: [clip], devicePixelRatio: devicePixelRatio);
    return DetachedClipThumbnails._(manager, clip.id);
  }

  final ClipThumbnailManager _manager;
  final String _clipId;

  /// The frames, filling in as extraction progresses.
  ValueListenable<List<StripThumbnail>> get frames => _manager[_clipId];

  Future<void> dispose() async => _manager.dispose();
}

/// Frames for detached clips, shared and outliving a row's remount.
///
/// Selecting a row wraps its tile, which moves the widget in the tree and
/// recreates its state. A manager owned by that state re-extracts every frame
/// each time the user taps the clip — the whole strip visibly rebuilding on a
/// selection. The pool holds it instead, so the row picks the same frames back
/// up. The window is generous because re-extraction is far more expensive than
/// keeping a finished strip around.
final detachedClipThumbnailPool = GracePeriodRegistry<DetachedClipThumbnails>(
  graceWindow: const Duration(seconds: 30),
  dispose: (thumbnails) => thumbnails.dispose(),
);

/// What the timeline bar needs to draw a detached clip's filmstrip.
class DetachedClipThumbnailsState extends Equatable {
  const DetachedClipThumbnailsState({
    this.aspectRatio,
    this.posterPath,
    this.span = Duration.zero,
    this.frames = const [],
  });

  /// The clip's shape, or `null` while its meta is still being read.
  final double? aspectRatio;

  /// The clip's own poster, shown until the first frames land.
  final String? posterPath;

  /// How long the clip plays, so a frame can be picked per slot.
  final Duration span;

  /// The frames extracted so far, in clip-playback time.
  final List<DetachedClipFrame> frames;

  /// Whether the clip resolved; nothing can be laid out before it does.
  bool get isReady => aspectRatio != null;

  DetachedClipThumbnailsState copyWith({
    double? aspectRatio,
    String? posterPath,
    Duration? span,
    List<DetachedClipFrame>? frames,
  }) => DetachedClipThumbnailsState(
    aspectRatio: aspectRatio ?? this.aspectRatio,
    posterPath: posterPath ?? this.posterPath,
    span: span ?? this.span,
    frames: frames ?? this.frames,
  );

  @override
  List<Object?> get props => [aspectRatio, posterPath, span, frames];
}

/// Resolves a detached clip from its layer meta and follows its frames.
///
/// The clip left the timeline track, so [ClipThumbnailManager] — which retires
/// a strip the moment its clip is no longer in the clip list — no longer keeps
/// one for it. This borrows a manager holding exactly this clip from
/// [detachedClipThumbnailPool]. Nothing else extracts these frames, so the two
/// never duplicate work.
class DetachedClipThumbnailsCubit extends Cubit<DetachedClipThumbnailsState>
    with CloseGuardedEmit<DetachedClipThumbnailsState> {
  DetachedClipThumbnailsCubit({
    required Map<String, dynamic> meta,
    required double devicePixelRatio,
    required String sourceKey,
  }) : _meta = meta,
       _devicePixelRatio = devicePixelRatio,
       _sourceKey = sourceKey,
       super(const DetachedClipThumbnailsState()) {
    // Take an already-extracted strip synchronously where there is one, so a
    // remount shows the frames it had rather than flashing posters.
    final ready = detachedClipThumbnailPool.acquireIfReady(sourceKey);
    if (ready != null) {
      _held = true;
      _thumbnails = ready;
    }
    unawaited(_resolve());
  }

  final Map<String, dynamic> _meta;
  final double _devicePixelRatio;
  final String _sourceKey;

  DetachedClipThumbnails? _thumbnails;
  bool _held = false;

  Future<void> _resolve() async {
    final documentsPath = await getDocumentsPath();
    final clip = DetachedClipLayerData.fromMeta(_meta, documentsPath)?.clip;
    if (clip == null || clip.video == null) return;

    final held = _thumbnails;
    // A pooled strip is published in the same emit as the clip's shape, not one
    // turn later: the widget cannot lay anything out before it knows the shape,
    // so splitting the two would show a bar of posters for a frame on every
    // remount — which is the flash the pool exists to prevent.
    emitIfOpen(
      state.copyWith(
        aspectRatio: clip.originalAspectRatio,
        posterPath: clip.thumbnailPath,
        span: clip.playbackDuration,
        frames: held == null ? null : _asFrames(held.frames.value),
      ),
    );

    final thumbnails =
        held ??
        await detachedClipThumbnailPool.acquire(
          _sourceKey,
          () => DetachedClipThumbnails.open(clip, _devicePixelRatio),
        );
    if (isClosed || thumbnails == null) {
      if (!_held) detachedClipThumbnailPool.release(_sourceKey);
      return;
    }

    _held = true;
    _thumbnails = thumbnails;
    _frames = thumbnails.frames..addListener(_onFrames);
    _onFrames();
  }

  ValueListenable<List<StripThumbnail>>? _frames;

  void _onFrames() =>
      emitIfOpen(state.copyWith(frames: _asFrames(_frames?.value)));

  static List<DetachedClipFrame> _asFrames(List<StripThumbnail>? source) => [
    for (final frame in source ?? const <StripThumbnail>[])
      (timestamp: frame.timestamp, path: frame.path),
  ];

  @override
  Future<void> close() async {
    _frames?.removeListener(_onFrames);
    if (_held) detachedClipThumbnailPool.release(_sourceKey);
    _held = false;
    return super.close();
  }
}
