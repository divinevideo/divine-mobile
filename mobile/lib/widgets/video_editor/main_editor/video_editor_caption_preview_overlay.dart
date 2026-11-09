// ABOUTME: Editor canvas preview of CC-overlay captions during playback.
// ABOUTME: Shows the active cue as the same pill viewers see in the feed.

import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/blocs/video_editor/main_editor/video_editor_main_bloc.dart';
import 'package:openvine/blocs/video_editor/timeline_overlay/timeline_overlay_bloc.dart';
import 'package:openvine/constants/text_scale_limits.dart';
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

    return Positioned.fill(
      child: IgnorePointer(
        child: Padding(
          padding: const EdgeInsets.only(left: 16, right: 16, bottom: 48),
          // The pill floats over the small preview like the toolbar chips,
          // so its text stops growing where theirs does.
          child: MediaQuery.withClampedTextScaling(
            maxScaleFactor: chipLabelTextScaleLimit,
            child: _ActiveCuePill(
              items: items,
              playTime: scope.playTimeNotifier,
            ),
          ),
        ),
      ),
    );
  }
}

/// The pill for the cue active at the play time.
///
/// The play time ticks every frame during playback while a cue stays on screen
/// for seconds, so this listens to it directly and rebuilds only when the
/// active cue text actually changes — not once per frame.
class _ActiveCuePill extends StatefulWidget {
  const _ActiveCuePill({required this.items, required this.playTime});

  final List<TimelineOverlayItem> items;
  final ValueListenable<Duration> playTime;

  @override
  State<_ActiveCuePill> createState() => _ActiveCuePillState();
}

class _ActiveCuePillState extends State<_ActiveCuePill> {
  String? _text;

  @override
  void initState() {
    super.initState();
    widget.playTime.addListener(_onPlayTime);
    _text = _resolveText();
  }

  @override
  void didUpdateWidget(_ActiveCuePill oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.playTime, widget.playTime)) {
      oldWidget.playTime.removeListener(_onPlayTime);
      widget.playTime.addListener(_onPlayTime);
    }
    _text = _resolveText();
  }

  @override
  void dispose() {
    widget.playTime.removeListener(_onPlayTime);
    super.dispose();
  }

  void _onPlayTime() {
    final text = _resolveText();
    if (text == _text) return;
    setState(() => _text = text);
  }

  String? _resolveText() {
    // Prefer the fine play time (smooth, no seek round-trip lag); fall back to
    // the bloc position before the fine notifier has been driven (it stays at
    // zero until the first playback/seek).
    final finePosition = widget.playTime.value;
    final position = finePosition == Duration.zero
        ? context.read<VideoEditorMainBloc>().state.currentPosition
        : finePosition;
    return _activeCueText(widget.items, position);
  }

  @override
  Widget build(BuildContext context) {
    final text = _text;
    return BlocListener<VideoEditorMainBloc, VideoEditorMainState>(
      listenWhen: (previous, current) =>
          previous.currentPosition != current.currentPosition,
      listener: (context, state) => _onPlayTime(),
      child: text == null || text.isEmpty
          ? const SizedBox.shrink()
          : _FittedCaptionPill(text: text),
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

/// The pill at the bottom of the space it is given, wrapping at its width and
/// shrinking to fit its height.
///
/// The preview above the timeline is short on a small phone, so a long cue
/// would otherwise run off its top.
class _FittedCaptionPill extends StatelessWidget {
  const _FittedCaptionPill({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => Align(
        alignment: Alignment.bottomCenter,
        child: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.bottomCenter,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: constraints.maxWidth),
            child: CaptionPill(text: text),
          ),
        ),
      ),
    );
  }
}
