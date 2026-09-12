import 'dart:math';

import 'package:divine_ui/divine_ui.dart';
import 'package:material_ui/material_ui.dart';
import 'package:models/models.dart';
import 'package:openvine/constants/semantic_ids.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/utils/video_editor_utils.dart';
import 'package:openvine/widgets/branded_loading_indicator.dart';
import 'package:sound_service/sound_service.dart';

class AudioEditorSelectionOverlay extends StatelessWidget {
  const AudioEditorSelectionOverlay({
    required this.audio,
    required this.audioService,
    required this.onTogglePlayState,
    required this.onTapDone,
    this.isLoading = false,
    super.key,
  });

  final AudioEvent audio;
  final AudioPlaybackService audioService;
  final VoidCallback onTogglePlayState;
  final VoidCallback onTapDone;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        margin: const .fromLTRB(8, 0, 8, 8),
        constraints: const BoxConstraints(minHeight: 56),
        padding: const .symmetric(horizontal: 16, vertical: 20),
        decoration: ShapeDecoration(
          color: context.vineColors.containerLow,
          shape: RoundedRectangleBorder(borderRadius: .circular(24)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          spacing: 16,
          children: [
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    audio.title ?? context.l10n.videoEditorAudioUntitledSound,
                    style: VineTheme.titleMediumFont(
                      color: context.vineColors.onSurface,
                    ),
                    maxLines: 1,
                    overflow: .ellipsis,
                  ),
                  Text.rich(
                    TextSpan(
                      style: VineTheme.bodyMediumFont(
                        color: context.vineColors.onSurfaceVariant,
                      ),
                      children: [
                        TextSpan(
                          text: Duration(
                            seconds: max((audio.duration ?? 0).toInt(), 1),
                          ).toMmSs(),
                          style: const TextStyle(
                            fontFeatures: [.tabularFigures()],
                          ),
                        ),
                        if (audio.source != null) ...[
                          const TextSpan(text: ' ∙ '),
                          TextSpan(text: audio.source),
                        ],
                      ],
                    ),
                    maxLines: 1,
                    overflow: .ellipsis,
                  ),
                ],
              ),
            ),

            _AudioPlaybackProgressButton(
              audioService: audioService,
              isLoading: isLoading,
              onPressed: onTogglePlayState,
            ),
            DivineIconButton(
              type: .tertiary,
              size: .small,
              icon: .caretRight,
              semanticLabel: context.l10n.videoEditorDoneSemanticLabel,
              semanticIdentifier: SemanticIds.audioSelectionDoneButton,
              onPressed: isLoading ? null : onTapDone,
            ),
          ],
        ),
      ),
    );
  }
}

class _AudioPlaybackProgressButton extends StatefulWidget {
  const _AudioPlaybackProgressButton({
    required this.audioService,
    required this.onPressed,
    this.isLoading = false,
  });

  final AudioPlaybackService audioService;
  final VoidCallback onPressed;
  final bool isLoading;

  @override
  State<_AudioPlaybackProgressButton> createState() =>
      _AudioPlaybackProgressButtonState();
}

class _AudioPlaybackProgressButtonState
    extends State<_AudioPlaybackProgressButton> {
  static const double _buttonVisualSize = 42;
  static const double _buttonBorderRadius = 16;

  /// Last rendered progress, never rewound while playback continues.
  ///
  /// just_audio advances the position from the moment `play()` is requested,
  /// but the platform only starts rendering audio a moment later and then
  /// reports the true — smaller — position. Painting that correction rewinds
  /// the ring, so the last value is held until playback catches up. A position
  /// back at the start (pause, restart, another sound) resets it.
  double _progress = 0;

  // The player rebuilds these stream views on every access, so they are bound
  // once instead of per build to avoid resubscribing on each rebuild.
  late Stream<bool> _playingStream;
  late Stream<Duration?> _durationStream;
  late Stream<Duration> _positionStream;

  @override
  void initState() {
    super.initState();
    _bindStreams();
  }

  @override
  void didUpdateWidget(covariant _AudioPlaybackProgressButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.audioService != widget.audioService) {
      _progress = 0;
      _bindStreams();
    }
  }

  void _bindStreams() {
    _playingStream = widget.audioService.playingStream;
    _durationStream = widget.audioService.durationStream;
    _positionStream = widget.audioService.positionStream;
  }

  double _resolveProgress(Duration? duration, Duration? position) {
    final durationMs = duration?.inMilliseconds ?? 0;
    final positionMs = position?.inMilliseconds ?? 0;
    final next = durationMs <= 0 || positionMs <= 0
        ? 0.0
        : (positionMs / durationMs).clamp(0.0, 1.0);

    if (next == 0 || next > _progress) {
      _progress = next;
    }
    return _progress;
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: VineTheme.defaultAnimationDuration,
      child: widget.isLoading
          ? const BrandedLoadingIndicator(size: _buttonVisualSize)
          : StreamBuilder<bool>(
              stream: _playingStream,
              initialData: widget.audioService.isPlaying,
              builder: (context, playingSnapshot) {
                final isPlaying = playingSnapshot.data ?? false;
                return StreamBuilder<Duration?>(
                  stream: _durationStream,
                  initialData: widget.audioService.duration,
                  builder: (context, durationSnapshot) {
                    return StreamBuilder<Duration>(
                      stream: _positionStream,
                      initialData: Duration.zero,
                      builder: (context, positionSnapshot) {
                        final progress = _resolveProgress(
                          durationSnapshot.data,
                          positionSnapshot.data,
                        );

                        return SizedBox.square(
                          dimension: _buttonVisualSize,
                          child: CustomPaint(
                            foregroundPainter: _CircularProgressBorderPainter(
                              progress: progress,
                              borderRadius: _buttonBorderRadius,
                              color: context.vineColors.accentPositive,
                            ),
                            child: Center(
                              child: DivineIconButton(
                                type: .ghostSecondary,
                                icon: isPlaying ? .pauseFill : .playFill,
                                semanticLabel: isPlaying
                                    ? context
                                          .l10n
                                          .videoEditorAudioPausePreviewSemanticLabel
                                    : context
                                          .l10n
                                          .videoEditorAudioPlayPreviewSemanticLabel,
                                onPressed: widget.onPressed,
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  },
                );
              },
            ),
    );
  }
}

class _CircularProgressBorderPainter extends CustomPainter {
  const _CircularProgressBorderPainter({
    required this.progress,
    required this.borderRadius,
    required this.color,
  });

  final double progress;
  final double borderRadius;
  final Color color;
  static const double _innerInset = 1;

  @override
  void paint(Canvas canvas, Size size) {
    final clampedProgress = progress.clamp(0.0, 1.0);
    if (clampedProgress <= 0) {
      return;
    }

    final strokePaint = Paint()
      ..color = color
      ..style = .stroke
      ..strokeWidth = 2
      ..strokeCap = .round;

    final rect = Offset.zero & size;
    final insetRect = rect.deflate((strokePaint.strokeWidth / 2) + _innerInset);
    final radius = borderRadius.clamp(0.0, insetRect.shortestSide / 2);

    // Build the rounded-rect path manually starting at top-center going
    // clockwise, so path offset 0 is exactly the visual top-center.
    final left = insetRect.left;
    final top = insetRect.top;
    final right = insetRect.right;
    final bottom = insetRect.bottom;
    final centerX = insetRect.center.dx;

    final path = Path()
      ..moveTo(centerX, top)
      // Top edge: top-center -> top-right corner start.
      ..lineTo(right - radius, top)
      // Top-right corner.
      ..arcToPoint(Offset(right, top + radius), radius: Radius.circular(radius))
      // Right edge.
      ..lineTo(right, bottom - radius)
      // Bottom-right corner.
      ..arcToPoint(
        Offset(right - radius, bottom),
        radius: Radius.circular(radius),
      )
      // Bottom edge.
      ..lineTo(left + radius, bottom)
      // Bottom-left corner.
      ..arcToPoint(
        Offset(left, bottom - radius),
        radius: Radius.circular(radius),
      )
      // Left edge.
      ..lineTo(left, top + radius)
      // Top-left corner.
      ..arcToPoint(Offset(left + radius, top), radius: Radius.circular(radius))
      // Back to top-center to close the loop.
      ..lineTo(centerX, top);

    final metric = path.computeMetrics().firstOrNull;
    if (metric == null) {
      return;
    }

    final drawLength = metric.length * clampedProgress;
    final progressPath = metric.extractPath(0, drawLength);

    canvas.drawPath(progressPath, strokePaint);
  }

  @override
  bool shouldRepaint(_CircularProgressBorderPainter oldDelegate) {
    return progress != oldDelegate.progress ||
        borderRadius != oldDelegate.borderRadius ||
        color != oldDelegate.color;
  }
}
