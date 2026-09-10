// ABOUTME: Editor canvas preview of CC-overlay captions during playback.
// ABOUTME: Shows the active cue as the same pill viewers see in the feed.

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/blocs/video_editor/main_editor/video_editor_main_bloc.dart';
import 'package:openvine/blocs/video_editor/timeline_overlay/timeline_overlay_bloc.dart';
import 'package:openvine/models/timeline_overlay_item.dart';
import 'package:openvine/widgets/caption_pill.dart';
import 'package:openvine/widgets/video_editor/main_editor/video_editor_scope.dart';

/// Previews CC-overlay caption cues on the editor canvas.
///
/// Renders the active cue as the pill viewers see in the feed. Suppressed
/// when the track is burned in — then the real caption layers render on the
/// canvas and the pill would double up — and while a layer is being moved, so
/// it doesn't sit over the layer the user is transforming (matching the rest
/// of the editor UI). The active cue tracks the fine-grained play time that
/// drives the burned layers, so it stays in step with playback.
class VideoEditorCaptionPreviewOverlay extends StatelessWidget {
  /// Creates the preview overlay.
  const VideoEditorCaptionPreviewOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    final hiddenForInteraction = context.select(
      (VideoEditorMainBloc b) => b.state.isLayerInteractionActive,
    );

    final scope = VideoEditorScope.of(context);
    // Read from the overlay bloc (not the editor's state manager directly) so
    // the pill hides reactively the instant burn-in is toggled, rather than
    // waiting for the next scroll-driven rebuild.
    final burnIn = context.select(
      (TimelineOverlayBloc b) => b.state.captionsBurnIn,
    );

    if (hiddenForInteraction || burnIn) return const SizedBox.shrink();

    final items = context.select((TimelineOverlayBloc b) => b.state.items);
    final blocPosition = context.select(
      (VideoEditorMainBloc b) => b.state.currentPosition,
    );

    return Positioned.fill(
      child: IgnorePointer(
        child: Align(
          alignment: Alignment.bottomCenter,
          child: Padding(
            padding: const EdgeInsets.only(left: 16, right: 16, bottom: 48),
            child: ValueListenableBuilder<Duration>(
              valueListenable: scope.playTimeNotifier,
              builder: (context, finePosition, _) {
                // Prefer the fine play time (smooth, no seek round-trip lag);
                // fall back to the bloc position before the fine notifier has
                // been driven (it stays at zero until the first playback/seek).
                final position = finePosition == Duration.zero
                    ? blocPosition
                    : finePosition;
                final text = _activeCueText(items, position);
                if (text == null || text.isEmpty) {
                  return const SizedBox.shrink();
                }
                return CaptionPill(text: text);
              },
            ),
          ),
        ),
      ),
    );
  }

  /// The text of the CC-overlay cue (layer-less caption item) active at
  /// [position], or `null` when none is.
  String? _activeCueText(List<TimelineOverlayItem> items, Duration position) {
    for (final item in items) {
      if (item.type == TimelineOverlayType.captions &&
          item.layer == null &&
          position >= item.startTime &&
          position <= item.endTime) {
        return item.label;
      }
    }
    return null;
  }
}
