import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/blocs/video_editor/clip_editor/clip_editor_bloc.dart';
import 'package:openvine/blocs/video_editor/main_editor/video_editor_main_bloc.dart';
import 'package:openvine/blocs/video_editor/timeline_overlay/timeline_overlay_bloc.dart';
import 'package:openvine/constants/video_editor_constants.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/stop_motion/stop_motion_frame_ops.dart';
import 'package:openvine/models/video_editor/transition_geometry.dart';
import 'package:openvine/widgets/video_editor/main_editor/video_editor_scope.dart';
import 'package:openvine/widgets/video_editor/timeline_editor/video_editor_volume_mute_toggle.dart';
import 'package:time_formatter/time_formatter.dart';

class VideoEditorTimelineHeader extends StatelessWidget {
  const VideoEditorTimelineHeader({
    required this.playheadPosition,
    required this.volumePreviewNotifier,
    super.key,
  });

  /// Notifier driven by the scroll offset of the timeline.
  final ValueNotifier<Duration> playheadPosition;
  final ValueNotifier<double?> volumePreviewNotifier;

  static const _padding = EdgeInsets.symmetric(horizontal: 16);

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isVolumeEditMode = context.select(
          (VideoEditorMainBloc b) => b.state.isVolumeEditMode,
        );

        return SingleChildScrollView(
          padding: _padding,
          scrollDirection: .horizontal,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minWidth: constraints.maxWidth - _padding.horizontal,
            ),
            child: Row(
              mainAxisAlignment: .spaceBetween,
              spacing: 8,
              children: [
                const Row(
                  spacing: 8,
                  children: [_PlayPauseButton(), _VolumeButton()],
                ),

                if (isVolumeEditMode)
                  _VolumeTextDisplay(
                    volumePreviewNotifier: volumePreviewNotifier,
                  )
                else
                  _TimeDisplay(playheadPosition: playheadPosition),

                const Row(spacing: 8, children: [_UndoButton(), _RedoButton()]),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _PlayPauseButton extends StatelessWidget {
  const _PlayPauseButton();

  @override
  Widget build(BuildContext context) {
    final isPlaying = context.select(
      (VideoEditorMainBloc b) => b.state.isPlaying,
    );
    final isPlayerReady = context.select(
      (VideoEditorMainBloc b) => b.state.isPlayerReady,
    );
    // A frames-only stop-motion composition has no mp4, so the canvas never
    // creates a native player and `isPlayerReady` stays false forever. Its
    // playback runs off the canvas's own ticker, which the toggle handler
    // branches to before any readiness check — so the button must not wait on
    // a player that will never exist.
    final isStopMotion = context.select(
      (ClipEditorBloc b) => isStopMotionComposition(b.state.clips),
    );
    final canTogglePlayback = isPlayerReady || isStopMotion;

    return DivineIconButton(
      icon: isPlaying ? .pauseFill : .playFill,
      size: .small,
      type: .ghost,
      semanticLabel: isPlaying
          ? context.l10n.videoEditorPauseSemanticLabel
          : context.l10n.videoEditorPlaySemanticLabel,
      onPressed: canTogglePlayback
          ? () => context.read<VideoEditorMainBloc>().add(
              const VideoEditorPlaybackToggleRequested(),
            )
          : null,
    );
  }
}

class _VolumeTextDisplay extends StatelessWidget {
  const _VolumeTextDisplay({required this.volumePreviewNotifier});

  final ValueNotifier<double?> volumePreviewNotifier;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<double?>(
      valueListenable: volumePreviewNotifier,
      builder: (context, preview, _) {
        if (preview != null) {
          return Text(
            context.l10n.videoEditorTimelineVolumePreview(
              (preview * 100).round(),
            ),
            style: VineTheme.labelLargeFont(color: VineTheme.accentYellow),
          );
        }
        return Text(
          context.l10n.videoEditorTimelineSlideToAdjust,
          style: VineTheme.bodyMediumFont(
            color: context.vineColors.onSurfaceMuted,
          ),
        );
      },
    );
  }
}

class _VolumeButton extends StatelessWidget {
  const _VolumeButton();

  @override
  Widget build(BuildContext context) {
    final isVolumeEditMode = context.select(
      (VideoEditorMainBloc b) => b.state.isVolumeEditMode,
    );
    final hasModifiedClipVolume = context.select(
      (ClipEditorBloc b) => b.state.clips.any((c) => c.volume != 1.0),
    );
    final hasModifiedAudioVolume = context.select(
      (TimelineOverlayBloc b) => b.state.audioTracks
          .where((t) => !t.isClipAnchoredOriginalSound)
          .any((t) => t.volume != 1.0),
    );
    final hasModifiedVolume = hasModifiedClipVolume || hasModifiedAudioVolume;

    return DivineIconButton(
      icon: .speakerHigh,
      size: .small,
      type: isVolumeEditMode ? .primary : .ghost,
      foregroundColor: isVolumeEditMode
          ? VineTheme.accentYellowBackground
          : (hasModifiedVolume ? VineTheme.accentYellow : null),
      backgroundColor: isVolumeEditMode ? VineTheme.accentYellow : null,
      semanticLabel: context.l10n.videoEditorVolumeSemanticLabel,
      semanticLongPressHint: context.l10n.videoEditorVolumeLongPressHint,
      onPressed: () => context.read<VideoEditorMainBloc>().add(
        const VideoEditorVolumeEditModeToggled(),
      ),
      onLongPress: () => toggleAllTimelineVolumeMuted(context),
    );
  }
}

class _TimeDisplay extends StatelessWidget {
  const _TimeDisplay({required this.playheadPosition});

  final ValueNotifier<Duration> playheadPosition;

  @override
  Widget build(BuildContext context) {
    final timeStyle = VineTheme.labelLargeFont(
      color: context.vineColors.primaryText,
    ).copyWith(fontFeatures: [const FontFeature.tabularFigures()]);
    // The editor timeline draws clips at full length, but an overlap transition
    // (dissolve/slide/push/wipe) blends two clips so the rendered output is
    // shorter. Show the output length — and the playhead mapped onto it — so the
    // header reflects the final video, not the editing space. The timeline
    // layout itself stays on the editor axis.
    final clips = context.select((ClipEditorBloc b) => b.state.clips);
    final timelineMap = TransitionTimelineMap.fromClips(clips);
    final outputDuration = timelineMap.outputDuration;

    return ValueListenableBuilder<Duration>(
      valueListenable: playheadPosition,
      builder: (context, position, _) {
        final outputPosition = timelineMap.editorToOutput(position);
        final isOver =
            outputPosition.inMilliseconds >
            VideoEditorConstants.maxDuration.inMilliseconds;
        final positionText = TextSpan(
          text: TimeFormatter.formatCompactDuration(outputPosition),
          style: isOver
              ? timeStyle.copyWith(color: VineTheme.warning)
              : timeStyle,
        );
        return Text.rich(
          TextSpan(
            children: [
              positionText,
              TextSpan(text: ' / ', style: timeStyle),
              TextSpan(
                text: TimeFormatter.formatCompactDuration(outputDuration),
                style: timeStyle,
              ),
            ],
          ),
          maxLines: 1,
        );
      },
    );
  }
}

class _UndoButton extends StatelessWidget {
  const _UndoButton();

  @override
  Widget build(BuildContext context) {
    final canUndo = context.select((VideoEditorMainBloc b) => b.state.canUndo);

    return DivineIconButton(
      icon: .arrowUUpLeft,
      size: .small,
      type: .ghost,
      semanticLabel: context.l10n.videoEditorUndoSemanticLabel,
      onPressed: canUndo ? () => _performUndo(context) : null,
    );
  }

  void _performUndo(BuildContext context) {
    VideoEditorScope.of(context).editor?.undoAction();
  }
}

class _RedoButton extends StatelessWidget {
  const _RedoButton();

  @override
  Widget build(BuildContext context) {
    final canRedo = context.select((VideoEditorMainBloc b) => b.state.canRedo);

    return DivineIconButton(
      icon: .arrowUUpRight,
      size: .small,
      type: .ghost,
      semanticLabel: context.l10n.videoEditorRedoSemanticLabel,
      onPressed: canRedo ? () => _performRedo(context) : null,
    );
  }

  void _performRedo(BuildContext context) {
    VideoEditorScope.of(context).editor?.redoAction();
  }
}
