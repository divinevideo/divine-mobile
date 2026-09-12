import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/blocs/video_editor/clip_editor/clip_editor_bloc.dart';
import 'package:openvine/blocs/video_editor/main_editor/video_editor_main_bloc.dart';
import 'package:openvine/blocs/video_editor/timeline_overlay/timeline_overlay_bloc.dart';
import 'package:openvine/l10n/l10n.dart';

/// Action bar shown while the timeline is in marker-placement mode.
///
/// Lets the user drop markers at the playhead repeatedly while playback runs.
/// Add is disabled while the playhead already sits on a marker; Delete is only
/// enabled there, targeting that marker. Done leaves the mode.
///
/// Both the add position and the add/delete gating track [playheadPosition] —
/// the scroll-derived visual playhead that updates on every frame — so the
/// controls stay responsive while the user scrubs the timeline. The player's
/// reported position lags scrubbing badly and would keep Add blocked until the
/// scroll fully settled.
class TimelineMarkerControls extends StatelessWidget {
  const TimelineMarkerControls({required this.playheadPosition, super.key});

  final ValueNotifier<Duration> playheadPosition;

  @override
  Widget build(BuildContext context) {
    final totalDuration = context.select(
      (ClipEditorBloc b) => b.state.totalDuration,
    );
    final markers = context.select(
      (TimelineOverlayBloc b) => b.state.timelineMarkers,
    );

    return DecoratedBox(
      decoration: BoxDecoration(
        color: context.vineColors.surfaceContainerHigh,
        boxShadow: [
          BoxShadow(
            // A cast shadow, not a surface: stays dark in both modes.
            color: VineTheme.backgroundColor.withValues(alpha: 0.4),
            blurRadius: 8,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(0, 16, 0, 8),
        child: SafeArea(
          top: false,
          child: Center(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: ValueListenableBuilder<Duration>(
                valueListenable: playheadPosition,
                builder: (context, position, _) {
                  final markerAtPlayhead = _markerAtPlayhead(markers, position);
                  final canAdd =
                      totalDuration > Duration.zero && markerAtPlayhead == null;

                  return Row(
                    spacing: 16,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _ControlButton(
                        icon: .bookmarkPlus,
                        label: context.l10n.videoEditorAddTitle,
                        semanticLabel: context
                            .l10n
                            .videoEditorAddTimelineMarkerSemanticLabel,
                        onPressed: canAdd
                            ? () => _addMarker(context, position, totalDuration)
                            : null,
                        type: .primary,
                      ),
                      _ControlButton(
                        icon: .trash,
                        label: context.l10n.videoEditorDeleteLabel,
                        semanticLabel: context
                            .l10n
                            .videoEditorRemoveTimelineMarkerAtPlayheadSemanticLabel,
                        onPressed: markerAtPlayhead == null
                            ? null
                            : () => _removeMarker(context, markerAtPlayhead),
                        type: .error,
                      ),
                      _ControlButton(
                        icon: .check,
                        label: context.l10n.videoEditorDoneLabel,
                        semanticLabel: context
                            .l10n
                            .videoEditorFinishTimelineEditingSemanticLabel,
                        onPressed: () =>
                            context.read<VideoEditorMainBloc>().add(
                              const VideoEditorMarkerModeChanged(
                                isActive: false,
                              ),
                            ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Returns the marker the playhead currently sits on, or `null` when it is
  /// not on one, using the same tolerance as add dedup / removal.
  static Duration? _markerAtPlayhead(
    List<Duration> markers,
    Duration position,
  ) {
    final index = TimelineOverlayBloc.markerIndexAt(markers, position);
    return index == -1 ? null : markers[index];
  }

  void _addMarker(
    BuildContext context,
    Duration position,
    Duration totalDuration,
  ) {
    context.read<TimelineOverlayBloc>().add(
      TimelineMarkerAdded(position: position, totalDuration: totalDuration),
    );
  }

  void _removeMarker(BuildContext context, Duration marker) {
    context.read<TimelineOverlayBloc>().add(TimelineMarkerRemoved(marker));
  }
}

class _ControlButton extends StatelessWidget {
  const _ControlButton({
    required this.icon,
    required this.label,
    required this.semanticLabel,
    required this.onPressed,
    this.type = .secondary,
  });

  final DivineIconName icon;
  final String label;
  final String semanticLabel;
  final VoidCallback? onPressed;
  final DivineIconButtonType type;

  @override
  Widget build(BuildContext context) {
    return Column(
      spacing: 8,
      children: [
        DivineIconButton(
          icon: icon,
          semanticLabel: semanticLabel,
          onPressed: onPressed,
          type: type,
          size: .small,
        ),
        Text(
          label,
          style: VineTheme.bodySmallFont(color: context.vineColors.primaryText),
        ),
      ],
    );
  }
}
