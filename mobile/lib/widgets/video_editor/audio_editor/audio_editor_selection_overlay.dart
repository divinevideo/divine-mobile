// ABOUTME: The card under the sound picker for the sound picked last: its
// ABOUTME: cover and details, play/pause, how far it played, and Use.

import 'dart:math';

import 'package:divine_ui/divine_ui.dart';
import 'package:material_ui/material_ui.dart';
import 'package:models/models.dart';
import 'package:openvine/constants/semantic_ids.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/sound_cover.dart';
import 'package:openvine/utils/video_editor_utils.dart';
import 'package:openvine/widgets/audio/sound_cover_image.dart';
import 'package:openvine/widgets/branded_loading_indicator.dart';
import 'package:sound_service/sound_service.dart';

/// The picked sound as a small player, shaped like the picker's rows.
class AudioEditorSelectionOverlay extends StatelessWidget {
  const AudioEditorSelectionOverlay({
    required this.audio,
    required this.audioService,
    required this.onTogglePlayState,
    required this.onTapDone,
    this.cover,
    this.isLoading = false,
    super.key,
  });

  final AudioEvent audio;
  final AudioPlaybackService audioService;
  final VoidCallback onTogglePlayState;
  final VoidCallback onTapDone;

  /// The cover the sound's row shows, or `null` for its colour tile.
  final SoundCover? cover;
  final bool isLoading;

  static const _coverSize = 48.0;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        margin: const .fromLTRB(8, 0, 8, 8),
        padding: const .fromLTRB(12, 12, 12, 10),
        decoration: ShapeDecoration(
          color: context.vineColors.containerLow,
          shape: RoundedRectangleBorder(borderRadius: .circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          spacing: 10,
          children: [
            Row(
              spacing: 12,
              children: [
                SoundCoverImage(
                  cover: cover,
                  size: _coverSize,
                  borderRadius: 12,
                  colorSeed: audio.id,
                ),
                Expanded(child: _Details(audio: audio)),
                _PlayPauseButton(
                  audioService: audioService,
                  isLoading: isLoading,
                  onPressed: onTogglePlayState,
                ),
                DivineButton(
                  label: context.l10n.videoEditorAudioUseSound,
                  size: .small,
                  // Named again so the button reports when it is disabled:
                  // the lip-sync E2E waits for it to become enabled.
                  semanticLabel: context.l10n.videoEditorAudioUseSound,
                  semanticIdentifier: SemanticIds.audioSelectionDoneButton,
                  onPressed: isLoading ? null : onTapDone,
                ),
              ],
            ),
            _PlaybackProgressLine(
              audioService: audioService,
              isLoading: isLoading,
            ),
          ],
        ),
      ),
    );
  }
}

class _Details extends StatelessWidget {
  const _Details({required this.audio});

  final AudioEvent audio;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          audio.title ?? context.l10n.videoEditorAudioUntitledSound,
          style: VineTheme.titleMediumFont(color: context.vineColors.onSurface),
          maxLines: 1,
          overflow: .ellipsis,
        ),
        Text.rich(
          TextSpan(
            style: VineTheme.bodySmallFont(
              color: context.vineColors.onSurfaceVariant,
            ),
            children: [
              TextSpan(
                text: Duration(
                  seconds: max((audio.duration ?? 0).toInt(), 1),
                ).toMmSs(),
                style: const TextStyle(fontFeatures: [.tabularFigures()]),
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
    );
  }
}

class _PlayPauseButton extends StatelessWidget {
  const _PlayPauseButton({
    required this.audioService,
    required this.onPressed,
    required this.isLoading,
  });

  final AudioPlaybackService audioService;
  final VoidCallback onPressed;
  final bool isLoading;

  static const double _size = 40;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: VineTheme.defaultAnimationDuration,
      child: isLoading
          ? const BrandedLoadingIndicator(size: _size)
          : StreamBuilder<bool>(
              stream: audioService.playingStream,
              initialData: audioService.isPlaying,
              builder: (context, snapshot) {
                final isPlaying = snapshot.data ?? false;
                return DivineIconButton(
                  type: .ghostSecondary,
                  icon: isPlaying ? .pauseFill : .playFill,
                  semanticLabel: isPlaying
                      ? context.l10n.videoEditorAudioPausePreviewSemanticLabel
                      : context.l10n.videoEditorAudioPlayPreviewSemanticLabel,
                  onPressed: onPressed,
                );
              },
            ),
    );
  }
}

/// How far the sound has played, as a line across the card.
class _PlaybackProgressLine extends StatefulWidget {
  const _PlaybackProgressLine({
    required this.audioService,
    required this.isLoading,
  });

  final AudioPlaybackService audioService;
  final bool isLoading;

  @override
  State<_PlaybackProgressLine> createState() => _PlaybackProgressLineState();
}

class _PlaybackProgressLineState extends State<_PlaybackProgressLine> {
  /// Last drawn progress, not wound back while playback continues.
  ///
  /// just_audio advances the position from the moment `play()` is requested,
  /// but the platform only starts rendering audio a moment later and then
  /// reports the true, smaller, position. Drawing that correction would wind
  /// the line back, so the last value holds until playback catches up. A
  /// position back near the start (a pause, another sound, or the preview
  /// looping) starts the line over.
  double _progress = 0;

  /// How far back a position must jump to count as starting over rather than
  /// as the player correcting itself.
  static const _restartJump = 0.5;

  // The player rebuilds these stream views on every access, so they are bound
  // once instead of per build to avoid resubscribing on each rebuild.
  late Stream<Duration?> _durationStream;
  late Stream<Duration> _positionStream;

  @override
  void initState() {
    super.initState();
    _bindStreams();
  }

  @override
  void didUpdateWidget(covariant _PlaybackProgressLine oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.audioService != widget.audioService) _bindStreams();
  }

  void _bindStreams() {
    _progress = 0;
    _durationStream = widget.audioService.durationStream;
    _positionStream = widget.audioService.positionStream;
  }

  double _resolveProgress(Duration? duration, Duration? position) {
    final durationMs = duration?.inMilliseconds ?? 0;
    final positionMs = position?.inMilliseconds ?? 0;
    final next = durationMs <= 0 || positionMs <= 0
        ? 0.0
        : (positionMs / durationMs).clamp(0.0, 1.0);
    if (next > _progress || next < _progress - _restartJump || next == 0) {
      _progress = next;
    }
    return _progress;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isLoading) {
      _progress = 0;
      return const _ProgressBar(progress: 0);
    }
    return StreamBuilder<Duration?>(
      stream: _durationStream,
      initialData: widget.audioService.duration,
      builder: (context, durationSnapshot) {
        return StreamBuilder<Duration>(
          stream: _positionStream,
          initialData: Duration.zero,
          builder: (context, positionSnapshot) => _ProgressBar(
            progress: _resolveProgress(
              durationSnapshot.data,
              positionSnapshot.data,
            ),
          ),
        );
      },
    );
  }
}

class _ProgressBar extends StatelessWidget {
  const _ProgressBar({required this.progress});

  final double progress;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: ClipRRect(
        borderRadius: .circular(2),
        child: SizedBox(
          key: const Key('audio_selection_progress'),
          height: 3,
          child: Stack(
            fit: StackFit.expand,
            children: [
              ColoredBox(color: context.vineColors.outlineDisabled),
              FractionallySizedBox(
                alignment: AlignmentDirectional.centerStart,
                widthFactor: progress,
                child: ColoredBox(color: context.vineColors.accentPositive),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
