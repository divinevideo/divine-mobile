// ABOUTME: Covers the preview frame around a timeline clip's shape mask, in
// ABOUTME: the clip's mask background color, while that clip plays, as the
// ABOUTME: export does.

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/blocs/video_editor/clip_editor/clip_editor_bloc.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/models/video_editor/clip_mask_window.dart';
import 'package:openvine/widgets/video_editor/main_editor/video_editor_scope.dart';
import 'package:pro_image_editor/pro_image_editor.dart'
    show LayerMask, LayerMaskBox;

/// Lays [child], the preview frame, under the cover of every timeline clip
/// mask the playhead is in.
///
/// The frame is the part of the canvas the export keeps, which is what a
/// clip's mask is measured in. Its box registers with
/// [VideoEditorScope.clipFrameTracker], so the mask editor can draw over
/// exactly this area.
class VideoEditorClipMaskPreview extends StatelessWidget {
  /// Creates a [VideoEditorClipMaskPreview].
  const VideoEditorClipMaskPreview({required this.child, super.key});

  /// The preview frame.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scope = VideoEditorScope.of(context);
    return Stack(
      fit: .expand,
      children: [
        child,
        IgnorePointer(
          child: VideoEditorFrameAnchor(
            tracker: scope.clipFrameTracker,
            child:
                BlocSelector<
                  ClipEditorBloc,
                  ClipEditorState,
                  List<DivineVideoClip>
                >(
                  selector: (state) => state.clips,
                  builder: (context, clips) => ClipMaskCover(
                    clips: clips,
                    playTime: scope.playTimeNotifier,
                    liveMask: scope.liveClipMaskNotifier,
                  ),
                ),
          ),
        ),
      ],
    );
  }
}

/// The cover of the clip masks [playTime] is in, drawn over its box in each
/// clip's mask background color.
@visibleForTesting
class ClipMaskCover extends StatefulWidget {
  /// Creates a [ClipMaskCover].
  const ClipMaskCover({
    required this.clips,
    required this.playTime,
    this.liveMask,
    super.key,
  });

  /// The timeline clips.
  final List<DivineVideoClip> clips;

  /// The editor timeline position of the frame on screen.
  final ValueListenable<Duration> playTime;

  /// A mask being changed in the mask editor, shown in place of its clip's.
  final ValueListenable<LiveClipMask?>? liveMask;

  @override
  State<ClipMaskCover> createState() => _ClipMaskCoverState();
}

class _ClipMaskCoverState extends State<ClipMaskCover> {
  List<ClipMaskWindow> _windows = const [];
  List<(LayerMask, Color, double)> _covers = const [];

  @override
  void initState() {
    super.initState();
    widget.playTime.addListener(_onPlayTimeChanged);
    widget.liveMask?.addListener(_onLiveMaskChanged);
    _windows = _computeWindows();
    _covers = _computeCovers();
  }

  @override
  void didUpdateWidget(ClipMaskCover oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.playTime != widget.playTime) {
      oldWidget.playTime.removeListener(_onPlayTimeChanged);
      widget.playTime.addListener(_onPlayTimeChanged);
    }
    if (oldWidget.liveMask != widget.liveMask) {
      oldWidget.liveMask?.removeListener(_onLiveMaskChanged);
      widget.liveMask?.addListener(_onLiveMaskChanged);
    }
    _windows = _computeWindows();
    _covers = _computeCovers();
  }

  @override
  void dispose() {
    widget.playTime.removeListener(_onPlayTimeChanged);
    widget.liveMask?.removeListener(_onLiveMaskChanged);
    super.dispose();
  }

  List<ClipMaskWindow> _computeWindows() {
    return clipMaskWindows(widget.clips, live: widget.liveMask?.value);
  }

  List<(LayerMask, Color, double)> _computeCovers() {
    final time = widget.playTime.value;
    return [
      for (final window in _windows)
        if (window.weightAt(time) case final weight when weight > 0)
          (window.mask, window.color, weight),
    ];
  }

  void _onLiveMaskChanged() {
    _windows = _computeWindows();
    setState(() => _covers = _computeCovers());
  }

  /// Rebuilds only when what is drawn changes: during playback the playhead
  /// moves every frame, but the covers only while a fade runs.
  void _onPlayTimeChanged() {
    final covers = _computeCovers();
    if (listEquals(covers, _covers)) return;
    setState(() => _covers = covers);
  }

  @override
  Widget build(BuildContext context) {
    if (_covers.isEmpty) return const SizedBox.shrink();
    return ClipMaskCoverBleed(
      child: Stack(
        fit: .expand,
        children: [
          for (final (mask, color, weight) in _covers)
            Opacity(
              opacity: weight.clamp(0.0, 1.0),
              child: LayerMaskBox(
                // The cover is what the mask hides, so it is the mask turned
                // inside out.
                mask: mask.copyWith(invert: !mask.invert),
                // The clip's own color, which the export covers with too,
                // whatever the appearance.
                child: ColoredBox(color: color),
              ),
            ),
        ],
      ),
    );
  }
}

/// Paints its child reaching one device pixel past its box on every side.
///
/// The frame's edges seldom fall on whole device pixels. Where one does not,
/// the video and the cover over it each cover part of the pixel the edge
/// cuts through, and one over the other they leave a faint line of the video
/// along that edge. Reaching past it, the cover hides that pixel whole.
@visibleForTesting
class ClipMaskCoverBleed extends SingleChildRenderObjectWidget {
  /// Creates a [ClipMaskCoverBleed].
  const ClipMaskCoverBleed({super.child, super.key});

  @override
  RenderClipMaskCoverBleed createRenderObject(BuildContext context) =>
      RenderClipMaskCoverBleed(MediaQuery.devicePixelRatioOf(context));

  @override
  void updateRenderObject(
    BuildContext context,
    RenderClipMaskCoverBleed renderObject,
  ) {
    renderObject.devicePixelRatio = MediaQuery.devicePixelRatioOf(context);
  }
}

/// The render object of a [ClipMaskCoverBleed].
class RenderClipMaskCoverBleed extends RenderProxyBox {
  /// Creates a [RenderClipMaskCoverBleed].
  RenderClipMaskCoverBleed(this._devicePixelRatio);

  double _devicePixelRatio;

  /// How many device pixels make one logical pixel.
  double get devicePixelRatio => _devicePixelRatio;
  set devicePixelRatio(double value) {
    if (value == _devicePixelRatio) return;
    _devicePixelRatio = value;
    markNeedsPaint();
  }

  /// Stretches the child around the centre of the box by one device pixel on
  /// every side, however far the canvas is zoomed.
  Matrix4 _bleed() {
    final pixels = getTransformTo(null).getMaxScaleOnAxis() * _devicePixelRatio;
    if (pixels <= 0 || size.isEmpty) return Matrix4.identity();
    final bleed = 1 / pixels;
    final center = size.center(Offset.zero);
    return Matrix4.identity()
      ..translateByDouble(center.dx, center.dy, 0, 1)
      ..scaleByDouble(
        (size.width + 2 * bleed) / size.width,
        (size.height + 2 * bleed) / size.height,
        1,
        1,
      )
      ..translateByDouble(-center.dx, -center.dy, 0, 1);
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    if (child == null) {
      layer = null;
      return;
    }
    layer = context.pushTransform(
      needsCompositing,
      offset,
      _bleed(),
      super.paint,
      oldLayer: layer as TransformLayer?,
    );
  }

  @override
  void applyPaintTransform(RenderBox child, Matrix4 transform) {
    transform.multiply(_bleed());
  }
}

/// Knows where the preview frame is on screen.
///
/// The preview player is built more than once while a sub-editor is open — the
/// draw, filter and tune editors show it behind themselves — so a global key
/// on it would be claimed twice. Each frame registers here instead, and the
/// one mounted last is the one on top.
class VideoEditorFrameTracker {
  final List<RenderBox> _boxes = [];

  /// The box of the frame on top, or `null` when none is laid out.
  RenderBox? get box {
    for (final box in _boxes.reversed) {
      if (box.attached && box.hasSize) return box;
    }
    return null;
  }

  void _add(RenderBox box) => _boxes.add(box);

  void _remove(RenderBox box) => _boxes.remove(box);
}

/// Registers its box with [tracker] while it is in the tree.
@visibleForTesting
class VideoEditorFrameAnchor extends SingleChildRenderObjectWidget {
  /// Creates a [VideoEditorFrameAnchor].
  const VideoEditorFrameAnchor({
    required this.tracker,
    super.child,
    super.key,
  });

  /// Where the box registers, or `null` to register nowhere.
  final VideoEditorFrameTracker? tracker;

  @override
  RenderVideoEditorFrameAnchor createRenderObject(BuildContext context) =>
      RenderVideoEditorFrameAnchor(tracker);

  @override
  void updateRenderObject(
    BuildContext context,
    RenderVideoEditorFrameAnchor renderObject,
  ) {
    renderObject.tracker = tracker;
  }
}

/// The render object of a [VideoEditorFrameAnchor].
class RenderVideoEditorFrameAnchor extends RenderProxyBox {
  /// Creates a [RenderVideoEditorFrameAnchor].
  RenderVideoEditorFrameAnchor(this._tracker);

  VideoEditorFrameTracker? _tracker;

  /// Where this box registers, or `null` for nowhere.
  VideoEditorFrameTracker? get tracker => _tracker;
  set tracker(VideoEditorFrameTracker? value) {
    if (identical(value, _tracker)) return;
    if (attached) {
      _tracker?._remove(this);
      value?._add(this);
    }
    _tracker = value;
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _tracker?._add(this);
  }

  @override
  void detach() {
    _tracker?._remove(this);
    super.detach();
  }
}
