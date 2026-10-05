import 'dart:async';
import 'dart:math' as math;

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/blocs/video_editor/clip_editor/clip_editor_bloc.dart';
import 'package:openvine/blocs/video_editor/timeline_overlay/timeline_overlay_bloc.dart';
import 'package:openvine/constants/video_editor_constants.dart';
import 'package:openvine/constants/video_editor_timeline_constants.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/video_editor/live_volume.dart';
import 'package:openvine/widgets/video_editor/timeline_editor/utils/volume_boost_color.dart';
import 'package:openvine/widgets/video_editor/timeline_editor/video_editor_volume_mute_toggle.dart';

/// Panel shown when the user taps the volume button in the timeline header.
///
/// Displays one arc volume control per video clip and per custom audio
/// track. No labels, percentages, or section headers — just the arcs.
class VideoEditorTimelineVolume extends StatelessWidget {
  const VideoEditorTimelineVolume({
    required this.volumePreviewNotifier,
    this.liveVolumeNotifier,
    super.key,
  });

  final ValueNotifier<double?> volumePreviewNotifier;

  /// Receives the clip or track volume while it is dragged, so the preview
  /// can play it before it is committed on release; null once released.
  final ValueNotifier<LiveVolume?>? liveVolumeNotifier;

  @override
  Widget build(BuildContext context) {
    final clips = context.select(
      (ClipEditorBloc b) => b.state.clips,
    );
    // audioTracksPlayerRevision is included so this widget rebuilds when
    // undo/redo restores volumes. AudioEvent.== ignores volume, so the
    // audioTracks list alone would compare equal across an undo.
    final audioTracks = context
        .select(
          (TimelineOverlayBloc b) => (
            tracks: b.state.audioTracks,
            revision: b.state.audioTracksPlayerRevision,
          ),
        )
        .tracks;

    final customTracks = audioTracks
        .where((t) => !t.isClipAnchoredOriginalSound)
        .toList(growable: false);

    if (clips.isEmpty && customTracks.isEmpty) {
      return const SizedBox.shrink();
    }

    return ConstrainedBox(
      constraints: const BoxConstraints(
        minWidth: TimelineConstants.soundControlWidth,
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.centerRight,
            end: Alignment.centerLeft,
            colors: [
              context.vineColors.surfaceContainerHigh.withValues(alpha: 0),
              context.vineColors.surfaceContainerHigh.withValues(alpha: 0.96),
            ],
            stops: const [0.0, 0.1739],
          ),
        ),
        child: Padding(
          padding: const .only(
            top:
                TimelineConstants.rulerHeight +
                TimelineConstants.rulerToBodyGap,
          ),
          child: Column(
            spacing: 12,
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: .start,
            children: [
              Flexible(
                child: Column(
                  crossAxisAlignment: .start,
                  spacing: TimelineConstants.thumbnailVerticalRowGap,
                  children: [
                    for (var i = 0; i < clips.length; i++)
                      _VolumeArc(
                        height: TimelineConstants.thumbnailStripHeight,
                        semanticLabel: context.l10n.videoEditorClipVolumeLabel(
                          i + 1,
                        ),
                        semanticLongPressHint:
                            context.l10n.videoEditorVolumeLongPressHint,
                        volume: clips[i].volume,
                        volumePreviewNotifier: volumePreviewNotifier,
                        onLivePreview: (v) => liveVolumeNotifier?.value =
                            v == null ? null : LiveVolume.clip(clips[i].id, v),
                        onChanged: (v) => context.read<ClipEditorBloc>().add(
                          ClipEditorClipVolumeChanged(
                            clipId: clips[i].id,
                            volume: v,
                          ),
                        ),
                        onLongPress: () =>
                            toggleAllTimelineVolumeMuted(context),
                      ),
                  ],
                ),
              ),

              Flexible(
                child: Column(
                  spacing: 6,
                  children: [
                    for (var i = 0; i < customTracks.length; i++)
                      _VolumeArc(
                        height:
                            TimelineConstants.soundOverlayRowHeight -
                            TimelineConstants.overlayRowGap,
                        semanticLabel:
                            customTracks[i].title != null &&
                                customTracks[i].title!.isNotEmpty
                            ? customTracks[i].title!
                            : context.l10n.videoEditorAudioUntitledSound,
                        semanticLongPressHint:
                            context.l10n.videoEditorVolumeLongPressHint,
                        volume: customTracks[i].volume,
                        volumePreviewNotifier: volumePreviewNotifier,
                        onLivePreview: (v) =>
                            liveVolumeNotifier?.value = v == null
                            ? null
                            : LiveVolume.track(customTracks[i].id, v),
                        onChanged: (v) =>
                            context.read<TimelineOverlayBloc>().add(
                              TimelineOverlayAudioVolumeChanged(
                                trackId: customTracks[i].id,
                                volume: v,
                              ),
                            ),
                        onLongPress: () =>
                            toggleAllTimelineVolumeMuted(context),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _VolumeArc extends StatefulWidget {
  const _VolumeArc({
    required this.height,
    required this.semanticLabel,
    required this.volume,
    required this.volumePreviewNotifier,
    required this.onChanged,
    this.onLivePreview,
    this.onLongPress,
    this.semanticLongPressHint,
  });

  final double height;
  final String semanticLabel;
  final double volume;
  final ValueNotifier<double?> volumePreviewNotifier;

  /// Called once when the user lifts their finger (drag end), not on every
  /// intermediate move. This avoids dispatching BLoC events during active
  /// pointer tracking, which would trigger the
  /// `!_debugDuringDeviceUpdate` assertion in mouse_tracker.dart.
  final ValueChanged<double> onChanged;

  /// Called with the volume on every move while it is dragged, so it can be
  /// heard before [onChanged] commits it, and with null once released.
  final ValueChanged<double?>? onLivePreview;

  /// Called on long press — mutes/unmutes all clips and audio tracks at once.
  final VoidCallback? onLongPress;

  /// Hint text announced by screen readers for the long-press action.
  final String? semanticLongPressHint;

  @override
  State<_VolumeArc> createState() => _VolumeArcState();
}

class _VolumeArcState extends State<_VolumeArc> {
  static const double _gapSweepDeg = 80; // gap at the bottom, in degrees.

  /// Vertical drag distance that moves the volume by 100 %.
  static const double _pxPerFullVolume = 100;

  /// Volumes this close to 100 % snap onto it, so the neutral level is easy
  /// to land on again after boosting or lowering a track.
  static const double _unitySnap = 0.04;

  // Gesture-local preview state belongs here because it changes every frame
  // while the pointer moves and does not represent persisted editor state.
  late double _localVolume;

  /// Volume to restore when the user un-mutes via tap. Tracks the last
  /// non-zero value the user actually heard.
  double _lastUnmutedVolume = 1.0;

  bool _isDragging = false;

  /// Volume when the current drag began; the drag moves it from there.
  double _dragStartVolume = 1;

  /// Local vertical position where the current drag began.
  double _dragStartDy = 0;

  @override
  void initState() {
    super.initState();
    _localVolume = widget.volume;
    if (widget.volume > 0) {
      _lastUnmutedVolume = widget.volume;
    }
  }

  @override
  void didUpdateWidget(_VolumeArc oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_isDragging && oldWidget.volume != widget.volume) {
      _localVolume = widget.volume;
      if (widget.volume > 0) {
        _lastUnmutedVolume = widget.volume;
      }
    }
  }

  void _onDragStart(DragStartDetails d) {
    _dragStartVolume = _localVolume;
    _dragStartDy = d.localPosition.dy;
    _isDragging = true;
    widget.volumePreviewNotifier.value = _localVolume;
  }

  void _onDragUpdate(DragUpdateDetails d) {
    // Up is louder, down is quieter, relative to the volume the drag
    // started at.
    final raised = (_dragStartDy - d.localPosition.dy) / _pxPerFullVolume;
    var next = (_dragStartVolume + raised).clamp(
      0.0,
      VideoEditorConstants.volumeMax,
    );
    if ((next - 1).abs() < _unitySnap) next = 1;
    next = (next * 100).roundToDouble() / 100;
    if (next != _localVolume) {
      if (_VolumeZone.of(next) != _VolumeZone.of(_localVolume)) {
        unawaited(HapticFeedback.selectionClick());
      }
      setState(() => _localVolume = next);
      widget.onLivePreview?.call(next);
    }
    widget.volumePreviewNotifier.value = next;
  }

  void _onDragEnd(DragEndDetails _) {
    _isDragging = false;
    if (_localVolume > 0) {
      _lastUnmutedVolume = _localVolume;
    }
    widget.onChanged(_localVolume);
    widget.volumePreviewNotifier.value = null;
    widget.onLivePreview?.call(null);
  }

  @override
  Widget build(BuildContext context) {
    final isMuted = _localVolume <= 0.001;
    return Padding(
      padding: const EdgeInsets.only(left: 8),
      child: Semantics(
        label: widget.semanticLabel,
        slider: true,
        value: '${(_localVolume * 100).round()}%',
        onLongPressHint: widget.semanticLongPressHint,
        onLongPress: widget.onLongPress,
        child: SizedBox(
          height: widget.height,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            // Short tap (no drag) toggles mute. GestureDetector only
            // fires onTap when the gesture didn't escalate to a pan, so
            // taps and drags don't conflict.
            onTap: () {
              unawaited(HapticFeedback.lightImpact());
              final next = _localVolume > 0.001
                  ? 0.0
                  : (_lastUnmutedVolume > 0 ? _lastUnmutedVolume : 1.0);
              setState(() => _localVolume = next);
              widget.onChanged(next);
            },
            onLongPress: widget.onLongPress,
            // Vertical drag: up is louder, down is quieter. A vertical
            // recognizer (not a pan) so it wins the arena against the
            // volume panel's own vertical scroll view.
            onVerticalDragStart: _onDragStart,
            onVerticalDragUpdate: _onDragUpdate,
            onVerticalDragEnd: _onDragEnd,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CustomPaint(
                  size: const Size.square(52),
                  painter: _VolumeArcPainter(
                    volume: _localVolume,
                    gapSweepDeg: _gapSweepDeg,
                    trackColor: context.vineColors.disabled,
                    fullColor: context.vineColors.onSurface,
                  ),
                ),
                DivineIcon(
                  icon: isMuted ? .speakerSimpleSlash : .speakerHigh,
                  color:
                      volumeBoostColor(_localVolume) ??
                      (_localVolume >= 1
                          ? context.vineColors.onSurface
                          : VineTheme.accentYellow),
                  size: 16,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _VolumeArcPainter extends CustomPainter {
  _VolumeArcPainter({
    required this.volume,
    required this.gapSweepDeg,
    required this.trackColor,
    required this.fullColor,
  });

  final double volume;
  final double gapSweepDeg;

  /// Unfilled arc colour for the active appearance mode.
  final Color trackColor;

  /// Filled arc colour at full volume; below full the arc uses the fixed
  /// accent yellow that flags a modified track in both modes, and above it
  /// the [volumeBoostColor].
  final Color fullColor;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - 6;
    final rect = Rect.fromCircle(center: center, radius: radius);

    final gapSweep = gapSweepDeg * math.pi / 180;
    final arcSweep = 2 * math.pi - gapSweep;
    final startAngle = math.pi / 2 + gapSweep / 2;

    final track = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.butt;
    canvas.drawArc(rect, startAngle, arcSweep, false, track);

    if (volume <= 0) return;
    if (volume <= 1) {
      canvas.drawArc(
        rect,
        startAngle,
        arcSweep * volume,
        false,
        _fill(volume >= 1 ? fullColor : VineTheme.accentYellow),
      );
      return;
    }

    // Every 100 % above full laps the arc again: the completed lap stays
    // underneath in its own colour, the current one fills over it.
    final completedLaps = volume.ceil() - 1;
    canvas
      ..drawArc(
        rect,
        startAngle,
        arcSweep,
        false,
        _fill(volumeBoostColor(completedLaps.toDouble()) ?? fullColor),
      )
      ..drawArc(
        rect,
        startAngle,
        arcSweep * (volume - completedLaps),
        false,
        _fill(volumeBoostColor(volume)!),
      );
  }

  Paint _fill(Color color) => Paint()
    ..color = color
    ..style = PaintingStyle.stroke
    ..strokeWidth = 4
    ..strokeCap = StrokeCap.butt;

  @override
  bool shouldRepaint(_VolumeArcPainter oldDelegate) =>
      oldDelegate.volume != volume ||
      oldDelegate.gapSweepDeg != gapSweepDeg ||
      oldDelegate.trackColor != trackColor ||
      oldDelegate.fullColor != fullColor;
}

/// Volume ranges a drag crosses with a haptic tick, so 100 % and the
/// boost colours can be felt without looking at the arc.
enum _VolumeZone {
  muted,
  reduced,
  unity,
  boosted,
  highlyBoosted;

  static _VolumeZone of(double volume) {
    if (volume <= 0) return muted;
    if (volume < 1) return reduced;
    if (volume == 1) return unity;
    if (volume <= 2) return boosted;
    return highlyBoosted;
  }
}
