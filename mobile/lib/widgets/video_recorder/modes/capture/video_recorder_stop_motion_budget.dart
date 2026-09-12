// ABOUTME: Shot budget for the running stop-motion session, shown in the top bar
// ABOUTME: Same bar as capture mode's recording progress, counted in stills

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/blocs/video_recorder/video_recorder_bloc.dart';
import 'package:openvine/constants/semantic_ids.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/stop_motion/stop_motion_frame_ops.dart';
import 'package:openvine/providers/clip_manager_provider.dart';
import 'package:openvine/widgets/video_recorder/video_recorder_progress_bar.dart';

/// How many more stills fit in the running stop-motion session.
///
/// Stop-motion never enters the recording state, so capture mode's
/// duration-based progress bar never appears and the user shoots with no idea
/// how much room is left. This renders the same bar against the session's
/// frame budget instead: each still is held for one output frame, so the
/// ceiling is however many frames fit in the maximum clip length.
///
/// Measured against the same clip-manager total capture mode's bar counts, and
/// at the hold the new stills will actually inherit, so a recorder opened from
/// the editor to top up a clip starts from what that composition has left
/// rather than from a full budget.
///
/// Returns a [Flexible], so it belongs in the top bar's center slot between
/// the close and next buttons — the same slot (and the same shape) lip-sync's
/// audio chip uses.
class VideoRecorderStopMotionBudget extends ConsumerWidget {
  const VideoRecorderStopMotionBudget({super.key});

  /// Gap between the count and the bar. Tighter than the recording bar's,
  /// which has the whole top bar to itself — this has to fit between two
  /// buttons. Also the outer gap to the mirrored spacer below, which only
  /// balances the group while both gaps match.
  static const double _labelSpacing = 2;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final captured = context.select(
      (VideoRecorderBloc b) => b.state.stopMotionFrameCount,
    );
    final (committed, framesPerImage) = ref.watch(
      clipManagerProvider.select(
        (s) => (
          s.totalDuration,
          StopMotionFrameOps.captureFramesPerImageFor(s.clips),
        ),
      ),
    );
    final budget = StopMotionFrameOps.maxCaptureFramesAfter(
      committed,
      framesPerImage: framesPerImage,
    );
    final remaining = StopMotionFrameOps.remainingCaptureFrames(
      captured,
      committed: committed,
      framesPerImage: framesPerImage,
    );
    final label = context.l10n.videoRecorderStopMotionShotsLeft(remaining);

    return Flexible(
      child: Semantics(
        identifier: SemanticIds.cameraStopMotionBudget,
        label: label,
        // The count is announced once, from here. Excluding the subtree drops
        // the duplicate the visible Text would otherwise contribute, and gives
        // the identifier a node carrying something rather than an empty
        // wrapper the platform is free to collapse.
        excludeSemantics: true,
        child: Column(
          mainAxisSize: .min,
          spacing: _labelSpacing,
          children: [
            VideoRecorderProgressBar(
              filled: captured.clamp(0, budget),
              remaining: remaining,
              overflow: (captured - budget).clamp(0, captured),
              label: label,
              labelAbove: true,
              labelSpacing: _labelSpacing,
            ),
            // The row centers its children, which would put the *group* —
            // count plus bar — on the buttons' center line and leave the bar
            // riding low. Mirroring the label below balances the group so the
            // bar itself lands on that line, with the count reading above it.
            // Measured from real text, so it tracks the font and the user's
            // text scale; invisible, so it costs no paint.
            Visibility(
              visible: false,
              maintainSize: true,
              maintainAnimation: true,
              maintainState: true,
              child: Text(label, style: VideoRecorderProgressBar.labelStyle),
            ),
          ],
        ),
      ),
    );
  }
}
