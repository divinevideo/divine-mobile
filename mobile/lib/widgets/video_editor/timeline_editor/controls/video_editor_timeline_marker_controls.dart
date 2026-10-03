import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/blocs/video_editor/clip_editor/clip_editor_bloc.dart';
import 'package:openvine/blocs/video_editor/main_editor/video_editor_main_bloc.dart';
import 'package:openvine/blocs/video_editor/timeline_overlay/timeline_overlay_bloc.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/widgets/video_editor/timeline_editor/controls/video_editor_timeline_action_bar.dart';

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

    return ValueListenableBuilder<Duration>(
      valueListenable: playheadPosition,
      builder: (context, position, _) {
        final markerAtPlayhead = _markerAtPlayhead(markers, position);
        final canAdd =
            totalDuration > Duration.zero && markerAtPlayhead == null;

        return TimelineActionBar(
          actions: [
            TimelineActionButton(
              icon: .bookmarkPlus,
              label: context.l10n.videoEditorAddTitle,
              semanticLabel:
                  context.l10n.videoEditorAddTimelineMarkerSemanticLabel,
              onPressed: canAdd
                  ? () => _addMarker(context, position, totalDuration)
                  : null,
              type: .primary,
            ),
            TimelineActionButton(
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
            TimelineActionButton(
              icon: .check,
              label: context.l10n.videoEditorDoneLabel,
              semanticLabel:
                  context.l10n.videoEditorFinishTimelineEditingSemanticLabel,
              onPressed: () => context.read<VideoEditorMainBloc>().add(
                const VideoEditorMarkerModeChanged(isActive: false),
              ),
            ),
          ],
        );
      },
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
