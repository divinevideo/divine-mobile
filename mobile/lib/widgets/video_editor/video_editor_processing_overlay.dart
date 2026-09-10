// ABOUTME: Overlay widget showing processing indicator for video clips
// ABOUTME: Displays circular progress indicator while clip is being processed/rendered

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/divine_video_clip.dart';
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
    this.onRetry,
  });

  /// The clip to show processing status for.
  final DivineVideoClip clip;
  final bool isProcessing;

  /// Whether the render failed. Takes precedence over [isProcessing] so a
  /// failed generation shows a retry affordance instead of an endless spinner
  /// (#6058).
  final bool hasFailed;

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
  const _RenderFailedOverlay({required this.onRetry, super.key});

  final VoidCallback? onRetry;

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
        context.l10n.videoMetadataGenerationFailed,
        Directionality.of(context),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color.fromARGB(180, 0, 0, 0),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisSize: .min,
            spacing: 12,
            children: [
              const ExcludeSemantics(
                child: DivineIcon(
                  icon: .warning,
                  size: 36,
                  color: VineTheme.error,
                ),
              ),
              Text(
                context.l10n.videoMetadataGenerationFailed,
                textAlign: TextAlign.center,
                style: VineTheme.bodyMediumFont(
                  color: context.vineColors.primaryText,
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
        ),
      ),
    );
  }
}
