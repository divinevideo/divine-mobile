// ABOUTME: The motion editor of a timeline clip, over the canvas: the clip is
// ABOUTME: panned, zoomed and turned at keyframes, and written as one undo step.

import 'dart:math' as math;

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/blocs/video_editor/clip_editor/clip_editor_bloc.dart';
import 'package:openvine/blocs/video_editor/clip_motion/clip_motion_editor_cubit.dart';
import 'package:openvine/blocs/video_editor/main_editor/video_editor_main_bloc.dart';
import 'package:openvine/constants/video_editor_constants.dart';
import 'package:openvine/extensions/clip_keyframes.dart';
import 'package:openvine/extensions/video_editor_extensions.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/utils/mounted_post_frame.dart';
import 'package:openvine/widgets/video_editor/main_editor/video_editor_scope.dart';
import 'package:openvine/widgets/video_editor/timeline_editor/controls/animation_picker_components.dart';
import 'package:pro_video_editor/pro_video_editor.dart'
    show AnimationCurve, SegmentKeyframe;
import 'package:time_formatter/time_formatter.dart';

/// How tall the motion editor's panel is above the bottom safe area: the
/// editor keeps that much free below the canvas while it is open.
const double videoEditorClipMotionPanelHeight = 304;

/// Owns the playback the motion editor loops over the clip, so it ends only
/// that audition.
const _auditionOwner = 'clip_motion_editor';

/// The exported frame on screen: its box's size, its transform to the
/// screen and the radius the canvas rounds its corners by, in the box.
typedef ClipMotionFrameGeometry = ({
  Size size,
  Matrix4 transform,
  double cornerRadius,
});

/// Opens the motion editor for the timeline clip [clipId].
///
/// A playhead outside the clip is moved onto its start first. The timeline
/// steps aside while the editor is open and playback pauses; the editor loops
/// the clip when it plays. The keyframes preview through
/// [VideoEditorScope.liveClipKeyframesNotifier] and are written to the clip,
/// as one history step, only when they are confirmed.
Future<void> editClipMotion(BuildContext context, String clipId) async {
  final scope = VideoEditorScope.of(context);
  final editor = scope.editor;
  if (editor == null) return;
  final clipBloc = context.read<ClipEditorBloc>();
  final mainBloc = context.read<VideoEditorMainBloc>();

  final clips = clipBloc.state.clips;
  final index = clips.indexWhere((clip) => clip.id == clipId);
  if (index < 0) return;
  final clip = clips[index];
  var clipStart = Duration.zero;
  for (final previous in clips.take(index)) {
    clipStart += previous.playbackDuration;
  }
  final time = scope.playTimeNotifier.value;
  if (time < clipStart || time >= clipStart + clip.playbackDuration) {
    mainBloc.add(VideoEditorSeekRequested(clipStart));
  }

  final wasPlaying = mainBloc.state.isPlaying;
  if (wasPlaying) {
    mainBloc.add(const VideoEditorExternalPauseRequested(isPaused: true));
  }
  // Set before the editor makes room for the panel, so it makes as much as
  // the panel takes from the start.
  scope.canvasToolPanelHeightNotifier?.value = videoEditorClipMotionPanelHeight;
  mainBloc.add(const VideoEditorClipMotionEditingChanged(isEditing: true));

  final live = scope.liveClipKeyframesNotifier;
  final result = await Navigator.of(context).push<List<SegmentKeyframe>>(
    PageRouteBuilder<List<SegmentKeyframe>>(
      opaque: false,
      barrierColor: VineTheme.transparent,
      settings: const RouteSettings(name: 'video_editor_clip_motion_editor'),
      transitionDuration: const Duration(milliseconds: 150),
      reverseTransitionDuration: const Duration(milliseconds: 150),
      pageBuilder: (_, _, _) => MultiBlocProvider(
        providers: [
          BlocProvider<VideoEditorMainBloc>.value(value: mainBloc),
          BlocProvider<ClipMotionEditorCubit>(
            create: (_) => ClipMotionEditorCubit(clip: clip),
          ),
        ],
        child: VideoEditorClipMotionEditorView(
          clip: clip,
          clipStart: clipStart,
          playTime: scope.playTimeNotifier,
          resolveFrame: () => _frameGeometry(
            scope.clipFrameTracker?.box,
            bodySize: scope.bodySizeNotifier.value,
          ),
          // The canvas resizes as the timeline collapses, and with the
          // canvas zoom.
          canvasChanges: Listenable.merge([
            scope.bodySizeNotifier,
            scope.zoomMatrixNotifier,
          ]),
          onChanged: (keyframes) =>
              live?.value = (clipId: clipId, keyframes: keyframes),
        ),
      ),
      transitionsBuilder: (_, animation, _, child) =>
          FadeTransition(opacity: animation, child: child),
    ),
  );

  // Guarded on the bloc rather than on `context.mounted`, as the mask editor
  // does: the editor giving up the screen is exactly what this restores.
  if (!mainBloc.isClosed) {
    mainBloc
      ..add(const VideoEditorAuditionEnded(owner: _auditionOwner))
      ..add(const VideoEditorClipMotionEditingChanged(isEditing: false));
    if (wasPlaying) {
      mainBloc.add(const VideoEditorExternalPauseRequested(isPaused: false));
    }
  }
  // The notifier goes with the editor, which can be torn down meanwhile.
  if (!editor.mounted) return;
  live?.value = null;

  // Re-read after the editor closed, as the mask editor does: the clip list
  // may have changed meanwhile.
  if (result == null || clipBloc.isClosed) return;
  final currentClips = clipBloc.state.clips;
  final currentIndex = currentClips.indexWhere((c) => c.id == clipId);
  if (currentIndex < 0) return;
  final current = currentClips[currentIndex];
  if (listEquals(result, current.keyframes)) return;

  final updated = current.copyWith(keyframes: result);
  final newClips = List.of(currentClips)..[currentIndex] = updated;
  clipBloc.add(ClipEditorClipUpdated(clipId: clipId, clip: updated));
  editor.setClipState(newClips);
}

/// [box]'s size, its transform to the screen and its corner radius, which
/// the canvas scales with the frame against [bodySize] as the player clips
/// it.
ClipMotionFrameGeometry? _frameGeometry(
  RenderObject? box, {
  required Size bodySize,
}) {
  if (box is! RenderBox || !box.attached || !box.hasSize) return null;
  return (
    size: box.size,
    transform: box.getTransformTo(null),
    cornerRadius: bodySize.width > 0
        ? VideoEditorConstants.canvasRadius * box.size.width / bodySize.width
        : 0,
  );
}

/// The motion editor over the canvas: gestures on the video move the clip's
/// picture at the playhead, and the panel below sets keyframes and the curve
/// between them.
///
/// Moving the picture sets the keyframe at the playhead, adding one when
/// there is none, as moving a layer does once it has keyframes.
class VideoEditorClipMotionEditorView extends StatefulWidget {
  /// Creates a [VideoEditorClipMotionEditorView].
  @visibleForTesting
  const VideoEditorClipMotionEditorView({
    required this.clip,
    required this.clipStart,
    required this.playTime,
    required this.resolveFrame,
    required this.canvasChanges,
    required this.onChanged,
    super.key,
  });

  /// The clip as the editor opened on it.
  final DivineVideoClip clip;

  /// Where [clip] starts on the editor timeline.
  final Duration clipStart;

  /// The editor timeline position of the frame on screen.
  final ValueListenable<Duration> playTime;

  /// Where the exported frame is on screen, or `null` while it is not laid
  /// out.
  final ClipMotionFrameGeometry? Function() resolveFrame;

  /// Notifies when the canvas moves or resizes.
  final Listenable canvasChanges;

  /// Called with the keyframes after every change, to preview them.
  final ValueChanged<List<SegmentKeyframe>> onChanged;

  @override
  State<VideoEditorClipMotionEditorView> createState() =>
      _VideoEditorClipMotionEditorViewState();
}

class _VideoEditorClipMotionEditorViewState
    extends State<VideoEditorClipMotionEditorView> {
  bool _refreshScheduled = false;

  /// The picture's motion, the focal point in frame pixels from its center,
  /// the number of fingers and the recognizer's scale and turn when the
  /// current gesture started, or was last rebased.
  ClipMotion? _gestureBase;
  Offset _gestureFocal = Offset.zero;
  int _gesturePointers = 0;
  double _scaleBase = 1;
  double _rotationBase = 0;

  @override
  void initState() {
    super.initState();
    widget.canvasChanges.addListener(_scheduleRefresh);
    // The canvas is mid-resize when the editor opens: the timeline is still
    // collapsing, so the first measurable frame comes after this one.
    addPostFrameCallbackIfMounted(() => setState(() {}));
  }

  @override
  void dispose() {
    widget.canvasChanges.removeListener(_scheduleRefresh);
    super.dispose();
  }

  void _scheduleRefresh() {
    if (_refreshScheduled) return;
    _refreshScheduled = true;
    addPostFrameCallbackIfMounted(() {
      _refreshScheduled = false;
      setState(() {});
    });
  }

  /// The timestamp in the clip's file of the frame the playhead shows.
  Duration get _sourceTime {
    var offset = widget.playTime.value - widget.clipStart;
    if (offset.isNegative) offset = Duration.zero;
    if (offset > widget.clip.playbackDuration) {
      offset = widget.clip.playbackDuration;
    }
    return widget.clip.sourceTimeAt(offset);
  }

  /// The clip's whole frame, laid out to cover [frame] as the preview lays it
  /// out, and the share of it [frame] keeps.
  ({Size surface, Size share}) _surfaceOf(Size frame) {
    final videoRatio = widget.clip.videoAspectRatio;
    final surface = videoRatio > frame.width / frame.height
        ? Size(frame.height * videoRatio, frame.height)
        : Size(frame.width, frame.width / videoRatio);
    return (
      surface: surface,
      share: Size(frame.width / surface.width, frame.height / surface.height),
    );
  }

  /// [global] in pixels from the center of the frame [geometry] places.
  Offset? _fromCenter(ClipMotionFrameGeometry geometry, Offset global) {
    final inverse = Matrix4.tryInvert(geometry.transform);
    if (inverse == null) return null;
    final local = MatrixUtils.transformPoint(inverse, global);
    return local - geometry.size.center(Offset.zero);
  }

  void _onScaleStart(ScaleStartDetails details) {
    final geometry = widget.resolveFrame();
    if (geometry == null) return;
    final focal = _fromCenter(geometry, details.focalPoint);
    if (focal == null) return;
    _rebase(focal, details.pointerCount, scale: 1, rotation: 0);
  }

  /// Starts measuring the gesture again from what the picture shows now, at
  /// [focal]: when it begins, and whenever a finger lands or lifts, which
  /// jumps the focal point and restarts the recognizer's scale and turn.
  void _rebase(
    Offset focal,
    int pointers, {
    required double scale,
    required double rotation,
  }) {
    final keyframes = context.read<ClipMotionEditorCubit>().state.keyframes;
    _gestureBase = clipMotionAt(keyframes, _sourceTime) ?? stillClipMotion;
    _gestureFocal = focal;
    _gesturePointers = pointers;
    _scaleBase = scale;
    _rotationBase = rotation;
  }

  void _onScaleUpdate(ScaleUpdateDetails details) {
    final base = _gestureBase;
    final geometry = widget.resolveFrame();
    if (base == null || geometry == null) return;
    final focal = _fromCenter(geometry, details.focalPoint);
    if (focal == null) return;
    if (details.pointerCount != _gesturePointers) {
      _rebase(
        focal,
        details.pointerCount,
        scale: details.scale,
        rotation: details.rotation,
      );
      return;
    }
    final pinched = details.pointerCount >= 2 && _scaleBase > 0;
    final (:surface, :share) = _surfaceOf(geometry.size);
    final moved = movedClipMotion(
      base,
      surface: surface,
      focalStart: _gestureFocal,
      focal: focal,
      scale: pinched ? details.scale / _scaleBase : 1,
      rotation: pinched ? details.rotation - _rotationBase : 0,
    );
    context.read<ClipMotionEditorCubit>().moveAt(
      _sourceTime,
      clampedClipMotion(moved, frame: share),
    );
  }

  void _onScaleEnd(ScaleEndDetails details) => _gestureBase = null;

  void _seek(Duration offset) => context.read<VideoEditorMainBloc>().add(
    VideoEditorSeekRequested(widget.clipStart + offset),
  );

  void _togglePlayback() {
    final mainBloc = context.read<VideoEditorMainBloc>();
    if (mainBloc.state.isPlaying) {
      mainBloc.add(const VideoEditorAuditionEnded(owner: _auditionOwner));
      return;
    }
    mainBloc.add(
      VideoEditorAuditionStarted(
        start: widget.clipStart,
        end: widget.clipStart + widget.clip.playbackDuration,
        owner: _auditionOwner,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final frame = widget.resolveFrame();
    return BlocListener<ClipMotionEditorCubit, ClipMotionEditorState>(
      listenWhen: (previous, current) =>
          previous.keyframes != current.keyframes,
      listener: (context, state) => widget.onChanged(state.keyframes),
      child: Scaffold(
        backgroundColor: VineTheme.transparent,
        body: Stack(
          fit: .expand,
          children: [
            Semantics(
              label: l10n.videoEditorClipKeyframesHint,
              child: GestureDetector(
                behavior: .opaque,
                dragStartBehavior: .down,
                onScaleStart: _onScaleStart,
                onScaleUpdate: _onScaleUpdate,
                onScaleEnd: _onScaleEnd,
              ),
            ),
            // The picture can be moved off the frame, and what it leaves is
            // as black as the canvas around it: the outline shows where the
            // export ends.
            if (frame != null)
              IgnorePointer(
                child: CustomPaint(
                  painter: ClipFrameOutlinePainter(
                    frame: frame,
                    lineColor: VineTheme.whiteText,
                    shadowColor: VineTheme.scrim50,
                  ),
                  child: const SizedBox.expand(),
                ),
              ),
            Align(
              alignment: .topCenter,
              child: _ClipMotionToolbar(
                onCancel: () => Navigator.of(context).pop(),
                onDone: () => Navigator.of(context).pop<List<SegmentKeyframe>>(
                  context.read<ClipMotionEditorCubit>().state.keyframes,
                ),
              ),
            ),
            Align(
              alignment: .bottomCenter,
              child: _ClipMotionPanel(
                clip: widget.clip,
                clipStart: widget.clipStart,
                playTime: widget.playTime,
                sourceTimeOf: () => _sourceTime,
                onSeek: _seek,
                onTogglePlayback: _togglePlayback,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// [base] moved by a gesture on a frame whose whole picture is [surface]
/// large: zoomed [scale] times and turned [rotation] radians around where it
/// started, [focalStart], and carried along to [focal], both in pixels from
/// the frame's center.
@visibleForTesting
ClipMotion movedClipMotion(
  ClipMotion base, {
  required Size surface,
  required Offset focalStart,
  required Offset focal,
  required double scale,
  required double rotation,
}) {
  // The shift in pixels, turned and scaled about the focal point with the
  // picture, then carried with the fingers.
  final shift = Offset(
    base.offset.dx * surface.width,
    base.offset.dy * surface.height,
  );
  final fromFocal = (shift - focalStart) * scale;
  final cos = math.cos(rotation);
  final sin = math.sin(rotation);
  final turned = Offset(
    fromFocal.dx * cos - fromFocal.dy * sin,
    fromFocal.dx * sin + fromFocal.dy * cos,
  );
  final moved = turned + focal;
  return (
    offset: Offset(moved.dx / surface.width, moved.dy / surface.height),
    scale: base.scale * scale,
    rotation: base.rotation + rotation,
  );
}

/// Outlines [frame], the exported frame, on screen.
@visibleForTesting
class ClipFrameOutlinePainter extends CustomPainter {
  /// Creates a [ClipFrameOutlinePainter].
  const ClipFrameOutlinePainter({
    required this.frame,
    required this.lineColor,
    required this.shadowColor,
  });

  /// Where the exported frame is on screen.
  final ClipMotionFrameGeometry frame;

  /// The outline's color.
  final Color lineColor;

  /// A wider line under the outline, so it reads on light footage too.
  final Color shadowColor;

  @override
  void paint(Canvas canvas, Size size) {
    final outline =
        (Path()..addRRect(
              RRect.fromRectAndRadius(
                Offset.zero & frame.size,
                Radius.circular(frame.cornerRadius),
              ),
            ))
            .transform(frame.transform.storage);
    canvas
      ..drawPath(
        outline,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4
          ..color = shadowColor,
      )
      ..drawPath(
        outline,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = lineColor,
      );
  }

  @override
  bool shouldRepaint(ClipFrameOutlinePainter oldDelegate) =>
      oldDelegate.frame != frame ||
      oldDelegate.lineColor != lineColor ||
      oldDelegate.shadowColor != shadowColor;
}

/// Cancel and done along the top. Only the two buttons catch touches:
/// everything else of the bar's width belongs to the video beneath.
class _ClipMotionToolbar extends StatelessWidget {
  const _ClipMotionToolbar({required this.onCancel, required this.onDone});

  final VoidCallback onCancel;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const .fromSTEB(16, 12, 16, 0),
        child: Row(
          mainAxisAlignment: .spaceBetween,
          children: [
            DivineIconButton(
              icon: .x,
              semanticLabel: l10n.commonCancel,
              size: .small,
              type: .ghostSecondary,
              onPressed: onCancel,
            ),
            DivineIconButton(
              icon: .check,
              semanticLabel: l10n.videoEditorDoneLabel,
              size: .small,
              onPressed: onDone,
            ),
          ],
        ),
      ),
    );
  }
}

/// The panel below the canvas: a hint, the clip's own playhead with its
/// keyframes, the keyframe and reset buttons, and the curve of the motion the
/// playhead is in.
class _ClipMotionPanel extends StatelessWidget {
  const _ClipMotionPanel({
    required this.clip,
    required this.clipStart,
    required this.playTime,
    required this.sourceTimeOf,
    required this.onSeek,
    required this.onTogglePlayback,
  });

  final DivineVideoClip clip;
  final Duration clipStart;
  final ValueListenable<Duration> playTime;

  /// The timestamp in the clip's file of the frame the playhead shows.
  final Duration Function() sourceTimeOf;

  /// Moves the playhead to an offset into the clip.
  final ValueChanged<Duration> onSeek;
  final VoidCallback onTogglePlayback;

  static const Duration _tolerance = VideoEditorConstants.keyframeTolerance;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cubit = context.read<ClipMotionEditorCubit>();
    final state = context.watch<ClipMotionEditorCubit>().state;
    return ColoredBox(
      color: context.vineColors.surfaceContainerHigh,
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: videoEditorClipMotionPanelHeight,
          child: SingleChildScrollView(
            padding: const .fromLTRB(16, 16, 16, 12),
            child: ValueListenableBuilder<Duration>(
              valueListenable: playTime,
              builder: (context, _, _) {
                final time = sourceTimeOf();
                final keyframes = state.keyframes;
                final isOnKeyframe =
                    keyframes.indexAt(time, tolerance: _tolerance) >= 0;
                final segment = keyframes.segmentIndexAt(
                  time,
                  tolerance: _tolerance,
                );
                return Column(
                  crossAxisAlignment: .stretch,
                  spacing: 12,
                  children: [
                    Text(
                      l10n.videoEditorClipKeyframesHint,
                      style: VineTheme.bodyMediumFont(
                        color: context.vineColors.secondaryText,
                      ),
                    ),
                    Row(
                      spacing: 8,
                      children: [
                        _PlayPauseButton(onPressed: onTogglePlayback),
                        Expanded(
                          child: _ClipMotionScrubber(
                            clip: clip,
                            playedOffset: playTime.value - clipStart,
                            keyframes: keyframes,
                            onSeek: onSeek,
                          ),
                        ),
                      ],
                    ),
                    Row(
                      spacing: 8,
                      children: [
                        Expanded(
                          child: DivineButton(
                            label: isOnKeyframe
                                ? l10n.videoEditorKeyframeRemove
                                : l10n.videoEditorKeyframeAdd,
                            leadingIcon: isOnKeyframe ? .trash : .diamond,
                            type: isOnKeyframe ? .secondary : .primary,
                            size: .small,
                            expanded: true,
                            onPressed: () => cubit.toggleKeyframeAt(time),
                          ),
                        ),
                        DivineIconButton(
                          icon: .arrowCounterClockwise,
                          semanticLabel: l10n.videoEditorTransformResetLabel,
                          size: .small,
                          type: .secondary,
                          onPressed: keyframes.isEmpty ? null : cubit.reset,
                        ),
                      ],
                    ),
                    if (segment != null) ...[
                      Text(
                        // The numbers name keyframes; they are not a count.
                        l10n.videoEditorKeyframeCurveSegment(
                          '${segment + 1}',
                          '${segment + 2}',
                        ),
                        style: VineTheme.titleSmallFont(
                          color: context.vineColors.primaryText,
                        ),
                      ),
                      CurvePickerRow(
                        selected: keyframes[segment].curve,
                        onChanged: (AnimationCurve curve) =>
                            cubit.setCurveAt(time, curve),
                      ),
                    ],
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

/// Plays the clip in a loop, or pauses it.
class _PlayPauseButton extends StatelessWidget {
  const _PlayPauseButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final isPlaying = context.select(
      (VideoEditorMainBloc bloc) => bloc.state.isPlaying,
    );
    return DivineIconButton(
      icon: isPlaying ? .pauseFill : .playFill,
      semanticLabel: isPlaying
          ? l10n.videoEditorPauseSemanticLabel
          : l10n.videoEditorPlaySemanticLabel,
      size: .small,
      type: .secondary,
      onPressed: onPressed,
    );
  }
}

/// The clip from start to end as a [DivineSlider]: the playhead, at
/// [playedOffset] into it, and a diamond at every keyframe within it.
/// Dragging or tapping moves the playhead, onto a keyframe when it lands on
/// its diamond.
class _ClipMotionScrubber extends StatelessWidget {
  const _ClipMotionScrubber({
    required this.clip,
    required this.playedOffset,
    required this.keyframes,
    required this.onSeek,
  });

  final DivineVideoClip clip;
  final Duration playedOffset;
  final List<SegmentKeyframe> keyframes;
  final ValueChanged<Duration> onSeek;

  static const double _height = 40;
  static const double _diamondSize = 16;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final length = clip.playbackDuration;
    final lengthUs = length.inMicroseconds;
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        double shareOf(Duration offset) => lengthUs <= 0
            ? 0
            : (offset.inMicroseconds / lengthUs).clamp(0.0, 1.0);
        final keyframeOffsets = [
          for (final keyframe in keyframes)
            if (clip.playbackOffsetOf(keyframe.time) case final offset
                when offset >= Duration.zero && offset <= length)
              offset,
        ];
        // A touch on a diamond lands on its keyframe exactly, which editing
        // that keyframe needs.
        Duration snapped(double share) {
          for (final offset in keyframeOffsets) {
            if ((shareOf(offset) - share).abs() * width <= _diamondSize / 2) {
              return offset;
            }
          }
          return length * share;
        }

        return SizedBox(
          width: width,
          height: _height,
          child: Stack(
            alignment: .center,
            children: [
              DivineSlider(
                value: shareOf(playedOffset),
                onChanged: (share) => onSeek(snapped(share)),
                semanticLabel:
                    l10n.videoEditorClipKeyframesScrubberSemanticLabel,
                semanticValue: (share) =>
                    TimeFormatter.formatCompactDuration(length * share),
              ),
              for (final offset in keyframeOffsets)
                Positioned(
                  left: shareOf(offset) * width - _diamondSize / 2,
                  width: _diamondSize,
                  height: _diamondSize,
                  // Touches go through to the slider, so the playhead can be
                  // dragged off a keyframe; a screen reader taps the diamond.
                  child: Semantics(
                    button: true,
                    label: l10n.videoEditorKeyframeMarkerSemanticLabel(
                      TimeFormatter.formatCompactDuration(offset),
                    ),
                    onTap: () => onSeek(offset),
                    child: const IgnorePointer(
                      child: DivineIcon(
                        icon: .diamondFill,
                        size: _diamondSize,
                        color: VineTheme.accentYellow,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
