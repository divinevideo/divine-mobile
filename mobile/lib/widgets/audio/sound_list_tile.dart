// ABOUTME: One sound in a list (cover, title, details, the bars of the one
// ABOUTME: playing) and the action row heading such a list, in the picker and
// ABOUTME: My Sounds.

import 'dart:math';

import 'package:divine_ui/divine_ui.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/sound_cover.dart';
import 'package:openvine/utils/video_editor_utils.dart';
import 'package:openvine/widgets/audio/sound_cover_image.dart';

/// Edge length of the cover leading each row.
const _coverSize = 48.0;

/// A sound as a row, the way the sound picker and My Sounds both list it.
class SoundListTile extends StatelessWidget {
  const SoundListTile({
    required this.title,
    required this.colorSeed,
    required this.onTap,
    this.duration,
    this.details = const [],
    this.caption,
    this.cover,
    this.isCoverPending = false,
    this.isCommunitySound = false,
    this.isActive = false,
    this.isPlaying = false,
    this.unavailableReason,
    this.trailing,
    this.contentPadding,
    super.key,
  });

  final String title;

  /// Length in seconds, shown first under the title; under a second, or
  /// unknown, reads as one second.
  final double? duration;

  /// Shown after [duration] on the same line, which cuts the last one short
  /// when they do not fit.
  final List<String> details;

  /// A line under the details, for what only one list shows.
  final Widget? caption;

  /// Artwork leading the row, or `null` for the colour tile.
  final SoundCover? cover;

  /// Whether [cover] is still being looked up; the row then waits on a plain
  /// tile instead of a colour it may not keep.
  final bool isCoverPending;

  /// Whether someone on Divine published the sound, which a people mark on
  /// the cover says.
  final bool isCommunitySound;

  /// Picks the colour tile's colour; pass the sound's id.
  final String colorSeed;

  /// Whether this is the sound picked or previewing: its title turns green
  /// and bars show beside it.
  final bool isActive;

  /// Whether the [isActive] sound is playing, which moves its bars.
  final bool isPlaying;

  /// Why the sound cannot be played or chosen, or `null` when it can. Set,
  /// the row greys out, says why in place of its details, and takes no tap.
  final String? unavailableReason;

  /// Shown at the row's end, after the bars of an [isActive] row.
  final Widget? trailing;

  /// The [ListTile.contentPadding], or `null` for its default.
  final EdgeInsetsGeometry? contentPadding;

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final unavailableReason = this.unavailableReason;
    final isUnavailable = unavailableReason != null;
    final showsBars = isActive && !isUnavailable;
    final trailing = this.trailing;
    final caption = this.caption;
    final Widget detailsLine = isUnavailable
        ? _UnavailableSubtitle(reason: unavailableReason)
        : _Details(duration: duration, details: details);
    return Padding(
      padding: const .symmetric(vertical: 4),
      child: ListTile(
        onTap: onTap,
        enabled: !isUnavailable,
        minTileHeight: 48,
        contentPadding: contentPadding,
        isThreeLine: caption != null,
        leading: _Cover(
          cover: cover,
          isPending: isCoverPending,
          colorSeed: colorSeed,
          isCommunitySound: isCommunitySound,
        ),
        title: Text(
          title,
          style: VineTheme.titleMediumFont(
            color: isUnavailable
                ? context.vineColors.onSurfaceVariant
                : isActive
                ? context.vineColors.accentPositive
                : context.vineColors.onSurface,
          ),
          maxLines: 1,
          overflow: .ellipsis,
        ),
        subtitle: caption == null
            ? detailsLine
            : Column(
                crossAxisAlignment: .start,
                mainAxisSize: .min,
                children: [detailsLine, caption],
              ),
        trailing: switch ((showsBars, trailing)) {
          (false, null) => null,
          (true, null) => _AudioPlayingIndicator(isPlaying: isPlaying),
          (false, final Widget trailing) => trailing,
          (true, final Widget trailing) => Row(
            mainAxisSize: .min,
            spacing: 4,
            children: [
              _AudioPlayingIndicator(isPlaying: isPlaying),
              trailing,
            ],
          ),
        },
      ),
    );
  }
}

/// A row shaped like a [SoundListTile] that starts an action: [icon] on a
/// tile where a sound's cover sits, then [title] and [subtitle].
///
/// Heads a list of sounds, as importing does in the picker and adding a sound
/// does in My Sounds.
class SoundListActionTile extends StatelessWidget {
  const SoundListActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    super.key,
  });

  final DivineIconName icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.vineColors;
    return Padding(
      padding: const .symmetric(vertical: 4),
      child: ListTile(
        onTap: onTap,
        minTileHeight: 48,
        leading: SizedBox.square(
          dimension: _coverSize,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: colors.surfaceContainer,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: DivineIcon(icon: icon, color: colors.accentPositive),
            ),
          ),
        ),
        // Long compounds such as German "importieren" would split mid-word at
        // the largest text sizes.
        title: DivineWordFitText(
          title,
          style: VineTheme.titleMediumFont(color: colors.accentPositive),
        ),
        subtitle: Text(
          subtitle,
          style: VineTheme.bodyMediumFont(color: colors.onSurfaceVariant),
        ),
      ),
    );
  }
}

/// The duration, then each detail, on one line.
class _Details extends StatelessWidget {
  const _Details({required this.duration, required this.details});

  final double? duration;
  final List<String> details;

  @override
  Widget build(BuildContext context) {
    final style = VineTheme.bodyMediumFont(
      color: context.vineColors.onSurfaceVariant,
    );
    return Text.rich(
      TextSpan(
        style: style,
        children: [
          TextSpan(
            text: Duration(seconds: max((duration ?? 0).toInt(), 1)).toMmSs(),
            // Tabular, so the durations of a list line up.
            style: style.copyWith(fontFeatures: const [.tabularFigures()]),
          ),
          for (final detail in details) ...[
            const TextSpan(text: ' ∙ '),
            TextSpan(text: detail),
          ],
        ],
      ),
      maxLines: 1,
      overflow: .ellipsis,
    );
  }
}

/// The row's cover, with a people mark on its corner for a sound someone on
/// Divine published.
class _Cover extends StatelessWidget {
  const _Cover({
    required this.cover,
    required this.isPending,
    required this.isCommunitySound,
    required this.colorSeed,
  });

  final SoundCover? cover;
  final bool isPending;
  final bool isCommunitySound;
  final String colorSeed;

  @override
  Widget build(BuildContext context) {
    final image = SoundCoverImage(
      cover: cover,
      isPending: isPending,
      size: _coverSize,
      colorSeed: colorSeed,
    );
    if (!isCommunitySound) return image;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        image,
        const Positioned(right: -4, bottom: -4, child: _CommunityMark()),
      ],
    );
  }
}

class _CommunityMark extends StatelessWidget {
  const _CommunityMark();

  /// Diameter of the mark, its ring included.
  static const _size = 20.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.vineColors;
    return Semantics(
      label: context.l10n.videoEditorAudioCategoryCommunity,
      child: SizedBox.square(
        key: const Key('audio_community_badge'),
        dimension: _size,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: colors.surfaceContainerHigh,
            shape: BoxShape.circle,
            // The sheet's own colour, so the mark reads as cut out of the
            // cover rather than stuck on top of it.
            border: Border.all(color: colors.surface, width: 2),
          ),
          child: Center(
            child: DivineIcon(
              icon: DivineIconName.users,
              size: 11,
              color: colors.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }
}

/// Says why a sound cannot be played or chosen.
class _UnavailableSubtitle extends StatelessWidget {
  const _UnavailableSubtitle({required this.reason});

  final String reason;

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
            reason,
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
