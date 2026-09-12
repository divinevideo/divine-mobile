import 'dart:math' as math;

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/blocs/video_editor/clip_editor/clip_editor_bloc.dart';
import 'package:openvine/blocs/video_editor/timeline_overlay/timeline_overlay_bloc.dart';
import 'package:openvine/constants/video_editor_timeline_constants.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/widgets/video_editor/timeline_editor/video_editor_volume_mute_toggle.dart';

/// Panel shown when the user taps the volume button in the timeline header.
///
/// Displays one arc volume control per video clip and per custom audio
/// track. No labels, percentages, or section headers — just the arcs.
class VideoEditorTimelineVolume extends StatelessWidget {
  const VideoEditorTimelineVolume({
    required this.volumePreviewNotifier,
    super.key,
  });

  final ValueNotifier<double?> volumePreviewNotifier;

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

  /// Called on long press — mutes/unmutes all clips and audio tracks at once.
  final VoidCallback? onLongPress;

  /// Hint text announced by screen readers for the long-press action.
  final String? semanticLongPressHint;

  @override
  State<_VolumeArc> createState() => _VolumeArcState();
}

class _VolumeArcState extends State<_VolumeArc> {
  static const double _gapSweepDeg = 80; // gap at the bottom, in degrees.
  static const double _maxDragRangePx = 160;
  static const double _maxDeadZonePx = 24;

  // Gesture-local preview state belongs here because it changes every frame
  // while the pointer moves and does not represent persisted editor state.
  late double _localVolume;

  /// Volume to restore when the user un-mutes via tap. Tracks the last
  /// non-zero value the user actually heard.
  double _lastUnmutedVolume = 1.0;

  bool _isDragging = false;

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

  /// Pixels of drag distance that cover the full 0..1 range.
  ///
  /// Set once at pan-start to 90 % of the current screen width so the gesture
  /// scales with the device rather than using a fixed pixel value.
  double _dragRangePx = _maxDragRangePx;

  /// Local position where the current pan gesture began.
  Offset _panStart = Offset.zero;

  void _onPanStart(DragStartDetails d) {
    _dragRangePx = math.min(
      _maxDragRangePx,
      MediaQuery.sizeOf(context).width * 0.9,
    );
    _panStart = d.localPosition;
    _isDragging = true;
    // Snap to full volume immediately so the gesture starts from a known
    // reference point: finger down = 100%.
    if (_localVolume != 1.0) {
      setState(() => _localVolume = 1);
    }
    widget.volumePreviewNotifier.value = 1.0;
  }

  void _onPanUpdate(DragUpdateDetails d) {
    // Finger on (or near) the tile = 100%. The further away the finger is
    // from the press point, the quieter it gets. Coming back to the start
    // pushes it back up to full volume.
    final dx = d.localPosition.dx - _panStart.dx;
    final dy = d.localPosition.dy - _panStart.dy;
    final distance = math.sqrt(dx * dx + dy * dy);
    final effective = (distance - _maxDeadZonePx).clamp(0.0, double.infinity);
    final next = (1 - effective / _dragRangePx).clamp(0.0, 1.0);
    if (next != _localVolume) {
      setState(() => _localVolume = next);
    }
    widget.volumePreviewNotifier.value = next;
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
              HapticFeedback.lightImpact();
              final next = _localVolume > 0.001
                  ? 0.0
                  : (_lastUnmutedVolume > 0 ? _lastUnmutedVolume : 1.0);
              setState(() => _localVolume = next);
              widget.onChanged(next);
            },
            onLongPress: widget.onLongPress,
            // Press-and-drag: relative gesture. Up = louder, down =
            // quieter. The arc itself is not directly hit-tested.
            onPanStart: _onPanStart,
            onPanUpdate: _onPanUpdate,
            onPanEnd: (_) {
              _isDragging = false;
              if (_localVolume > 0) {
                _lastUnmutedVolume = _localVolume;
              }
              widget.onChanged(_localVolume);
              widget.volumePreviewNotifier.value = null;
            },
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
                  color: _localVolume >= 1
                      ? context.vineColors.onSurface
                      : VineTheme.accentYellow,
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
  /// accent yellow that flags a modified track in both modes.
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

    if (volume > 0) {
      final fill = Paint()
        ..color = volume >= 1 ? fullColor : VineTheme.accentYellow
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.butt;
      canvas.drawArc(rect, startAngle, arcSweep * volume, false, fill);
    }
  }

  @override
  bool shouldRepaint(_VolumeArcPainter oldDelegate) =>
      oldDelegate.volume != volume ||
      oldDelegate.gapSweepDeg != gapSweepDeg ||
      oldDelegate.trackColor != trackColor ||
      oldDelegate.fullColor != fullColor;
}
