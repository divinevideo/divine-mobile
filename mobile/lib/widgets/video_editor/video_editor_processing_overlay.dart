// ABOUTME: Overlay widget showing processing indicator for video clips
// ABOUTME: Displays circular progress indicator while clip is being processed/rendered

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/models/video_editor/video_render_failure_reason.dart';
import 'package:openvine/providers/video_editor_provider.dart';
import 'package:openvine/widgets/branded_loading_indicator.dart';

class VideoEditorProcessingOverlay extends StatelessWidget {
  const VideoEditorProcessingOverlay({
    required this.clip,
    super.key,
    this.inactivePlaceholder,
    this.isCurrentClip = false,
    this.isProcessing = false,
    this.hasFailed = false,
    this.failureReason,
    this.onRetry,
  });

  /// The clip to show processing status for.
  final DivineVideoClip clip;
  final bool isProcessing;

  /// Whether the render failed. Takes precedence over [isProcessing] so a
  /// failed generation shows a retry affordance instead of an endless spinner
  /// (#6058).
  final bool hasFailed;

  /// Why the render failed, when known.
  ///
  /// Only [VideoRenderFailureReason.insufficientStorage] changes the copy: it
  /// is the one failure a retry cannot fix, so the overlay says what will
  /// (#7125). Ignored unless [hasFailed].
  final VideoRenderFailureReason? failureReason;

  /// Invoked when the user taps retry on the failure overlay.
  final VoidCallback? onRetry;
  final bool isCurrentClip;
  final Widget? inactivePlaceholder;

  @override
  Widget build(BuildContext context) {
    final Widget child;
    if (hasFailed) {
      child = _RenderFailedOverlay(
        key: ValueKey('Failed-Clip-Overlay-${clip.id}-$isCurrentClip'),
        reason: failureReason,
        onRetry: onRetry,
      );
    } else if (isProcessing || clip.isProcessing) {
      child = ColoredBox(
        key: ValueKey('Processing-Clip-Overlay-${clip.id}-$isCurrentClip'),
        color: const Color.fromARGB(180, 0, 0, 0),
        child: Center(
          child: Column(
            mainAxisSize: .min,
            spacing: 12,
            children: [
              const BrandedLoadingIndicator(size: 44),

              // Without RepaintBoundary, the progress indicator repaints
              // the entire screen while it's running.
              RepaintBoundary(
                child: Consumer(
                  builder: (context, ref, _) {
                    // No reading yet is not 0% — collapsing the two is what
                    // made a healthy export read as a hang (#8796). The
                    // indicator above already says work is in flight, so show
                    // the ring only once there is a real value to draw.
                    final reading = ref
                        .watch(videoEditorCompositeProgressProvider)
                        .asData
                        ?.value
                        .progress;
                    if (reading == null) return const SizedBox.shrink();
                    return PartialCircleSpinner(
                      progress: reading.clamp(0.0, 1.0),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      );
    } else {
      child = inactivePlaceholder ?? const SizedBox.shrink();
    }

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 220),
      child: child,
    );
  }
}

class _RenderFailedOverlay extends StatefulWidget {
  const _RenderFailedOverlay({
    required this.reason,
    required this.onRetry,
    super.key,
  });

  final VideoRenderFailureReason? reason;
  final VoidCallback? onRetry;

  /// The user-facing explanation for [reason].
  String message(AppLocalizations l10n) => switch (reason) {
    VideoRenderFailureReason.insufficientStorage => l10n.publishErrorLowStorage,
    _ => l10n.videoMetadataGenerationFailed,
  };

  @override
  State<_RenderFailedOverlay> createState() => _RenderFailedOverlayState();
}

class _RenderFailedOverlayState extends State<_RenderFailedOverlay> {
  @override
  void initState() {
    super.initState();
    // The failure surface swaps in via AnimatedSwitcher (no route push), so
    // screen readers get no automatic signal — announce it explicitly (#6058).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      SemanticsService.sendAnnouncement(
        View.of(context),
        widget.message(context.l10n),
        Directionality.of(context),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color.fromARGB(180, 0, 0, 0),
      child: Center(
        // The capture-mode preview is only 200px tall and the storage copy
        // wraps to three or more lines once translated, which overflowed the
        // full-size spacing (#7125). Tighten the chrome when the box is small
        // instead of clipping the message or the retry button.
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxHeight < 220;
            return Padding(
              padding: EdgeInsets.all(compact ? 8 : 12),
              child: Column(
                mainAxisSize: .min,
                spacing: compact ? 8 : 12,
                children: [
                  ExcludeSemantics(
                    child: DivineIcon(
                      icon: .warning,
                      size: compact ? 24 : 36,
                      color: VineTheme.error,
                    ),
                  ),
                  // The default 9:16 capture card is only ~112px wide, so the
                  // translated storage copy wraps past the card's height. Let
                  // the message take the space that is left and scroll inside
                  // it rather than pushing the retry button out of the box
                  // (#7125).
                  Flexible(
                    child: SingleChildScrollView(
                      child: Text(
                        widget.message(context.l10n),
                        textAlign: TextAlign.center,
                        style: VineTheme.bodyMediumFont(
                          color: context.vineColors.primaryText,
                        ),
                      ),
                    ),
                  ),
                  if (widget.onRetry != null)
                    DivineIconButton(
                      icon: .arrowsClockwise,
                      type: .secondary,
                      onPressed: widget.onRetry,
                      semanticLabel: context.l10n.videoErrorRetry,
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
