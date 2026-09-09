import 'dart:math';

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:models/models.dart' show AudioEvent;
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/utils/video_editor_utils.dart';

class AudioListTile extends StatelessWidget {
  const AudioListTile({
    required this.audio,
    required this.isSelected,
    required this.onTap,
    this.isPlaying = false,
    this.isUnavailable = false,
    this.semanticIdentifier,
    super.key,
  });

  final AudioEvent audio;
  final bool isSelected;
  final bool isPlaying;
  final VoidCallback onTap;

  /// Whether this sound cannot be attached because its device-local audio
  /// file is gone.
  ///
  /// The row stays listed and says why, rather than disappearing from a
  /// library the user knows they saved to — but it cannot be selected,
  /// because attaching it would put a dead source on the draft (#8023).
  final bool isUnavailable;

  /// Stable `Semantics(identifier:)` anchor for E2E tests. Never announced, so
  /// it carries no meaning for a screen-reader user — that is the title below.
  final String? semanticIdentifier;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      identifier: semanticIdentifier,
      child: _Tile(
        audio: audio,
        isSelected: isSelected,
        isPlaying: isPlaying,
        isUnavailable: isUnavailable,
        onTap: onTap,
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({
    required this.audio,
    required this.isSelected,
    required this.isPlaying,
    required this.isUnavailable,
    required this.onTap,
  });

  final AudioEvent audio;
  final bool isSelected;
  final bool isPlaying;
  final bool isUnavailable;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const .symmetric(vertical: 20.0),
      child: ListTile(
        onTap: onTap,
        enabled: !isUnavailable,
        minTileHeight: 48,
        title: Text(
          audio.title ?? context.l10n.videoEditorAudioUntitledSound,
          style: VineTheme.titleMediumFont(
            color: isUnavailable
                ? context.vineColors.onSurfaceVariant
                : isSelected
                ? context.vineColors.accentPositive
                : context.vineColors.onSurface,
          ),
          maxLines: 1,
          overflow: .ellipsis,
        ),
        subtitle: isUnavailable
            ? const _UnavailableSubtitle()
            : Text.rich(
                TextSpan(
                  style: VineTheme.bodyMediumFont(
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
              ),
        trailing: isSelected && !isUnavailable
            ? _AudioPlayingIndicator(isPlaying: isPlaying)
            : null,
      ),
    );
  }
}

/// Says why a saved sound in the picker cannot be chosen.
///
/// Mirrors the My Sounds card so the same condition reads the same way in
/// both places.
class _UnavailableSubtitle extends StatelessWidget {
  const _UnavailableSubtitle();

  @override
  Widget build(BuildContext context) {
    return Row(
      spacing: 6,
      children: [
        DivineIcon(
          icon: .warning,
          size: 14,
          color: context.vineColors.onErrorContainer,
        ),
        Expanded(
          child: Text(
            context.l10n.videoEditorAudioFileMissing,
            style: VineTheme.bodyMediumFont(
              color: context.vineColors.onErrorContainer,
            ),
            maxLines: 2,
            overflow: .ellipsis,
          ),
        ),
      ],
    );
  }
}

class _AudioPlayingIndicator extends StatefulWidget {
  const _AudioPlayingIndicator({required this.isPlaying});

  final bool isPlaying;

  @override
  State<_AudioPlayingIndicator> createState() => _AudioPlayingIndicatorState();
}

class _AudioPlayingIndicatorState extends State<_AudioPlayingIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncAnimation();
  }

  @override
  void didUpdateWidget(_AudioPlayingIndicator oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isPlaying != oldWidget.isPlaying) {
      _syncAnimation();
    }
  }

  void _syncAnimation() {
    if (widget.isPlaying && !MediaQuery.disableAnimationsOf(context)) {
      if (!_controller.isAnimating) {
        _controller.repeat();
      }
    } else {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    if (reduceMotion || !widget.isPlaying) {
      return _AudioBars(progress: _controller.value);
    }

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return _AudioBars(progress: _controller.value);
      },
    );
  }
}

class _AudioBars extends StatelessWidget {
  const _AudioBars({required this.progress});

  final double progress;

  // Per bar: [freqA, phaseA, freqB, phaseB, mixB].
  // Frequencies are integers so the loop stays seamless.
  // Phases are intentionally non-monotonic to break left-right wave look.
  static const List<List<double>> _tracks = [
    [1, 0.0, 3, 2.5, 0.30],
    [2, 4.2, 1, 1.8, 0.35],
    [3, 0.7, 1, 3.3, 0.40],
    [1, 5.5, 2, 0.2, 0.30],
    [2, 2.9, 3, 4.7, 0.35],
  ];

  double _heightFactorFor(int index) {
    final track = _tracks[index];
    final t = progress * 2 * pi;
    final a = sin((t * track[0]) + track[1]);
    final b = sin((t * track[2]) + track[3]);
    final mixB = track[4];
    final mixed = (a * (1 - mixB)) + (b * mixB);
    final normalized = (mixed + 1) / 2;

    return 0.28 + (normalized * 0.66);
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 24,
      height: 16,
      child: Row(
        spacing: 2,
        mainAxisSize: MainAxisSize.min,
        children: List.generate(5, (index) {
          final height = 16 * _heightFactorFor(index);

          return DecoratedBox(
            decoration: BoxDecoration(
              color: context.vineColors.accentPositive,
              borderRadius: BorderRadius.circular(999),
            ),
            child: SizedBox(width: 2, height: height),
          );
        }),
      ),
    );
  }
}
