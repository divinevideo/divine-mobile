// ABOUTME: Square artwork beside a sound in lists and cards.
// ABOUTME: Image, its blurhash while loading, or a colour tile when there is none.

import 'package:divine_ui/divine_ui.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/extensions/media_query_extensions.dart';
import 'package:openvine/models/sound_cover.dart';
import 'package:openvine/widgets/blurhash_display.dart';
import 'package:openvine/widgets/vine_cached_image.dart';

/// Square artwork beside a sound.
///
/// Shows [cover]'s image, its blurhash while the image loads or when there is
/// no image, and a tile in one of the brand's accent colours with a note on
/// it when the sound has no cover at all. While [isPending] it is a plain
/// tile, so a cover that is still being looked up does not flash a colour it
/// then replaces. Each change fades in. It is decorative: the row it sits in
/// names the sound.
class SoundCoverImage extends StatelessWidget {
  const SoundCoverImage({
    required this.size,
    this.cover,
    this.isPending = false,
    this.borderRadius = 8,
    this.colorSeed = '',
    super.key,
  });

  /// The artwork, or `null` for the colour tile.
  final SoundCover? cover;

  /// Picks the colour tile's colour, so a sound keeps the same one wherever
  /// it shows; pass its id.
  final String colorSeed;

  /// Whether the cover is still being looked up.
  final bool isPending;

  /// Edge length of the square.
  final double size;

  final double borderRadius;

  /// Long enough to read as a fade, short enough not to hold a row back.
  static const _fadeDuration = Duration(milliseconds: 250);

  @override
  Widget build(BuildContext context) {
    final fade = _fadeDuration.autoReduceMotion(context);
    final blurhash = cover?.blurhash;
    final hasBlurhash = blurhash != null && blurhash.isNotEmpty;
    final imageUrl = cover?.imageUrl;
    final Widget content;
    if (isPending) {
      content = const _SoundCoverPending(key: ValueKey('pending'));
    } else if (imageUrl != null && imageUrl.isNotEmpty) {
      content = VineCachedImage(
        key: ValueKey(imageUrl),
        imageUrl: imageUrl,
        width: size,
        height: size,
        // Width alone, so the frame keeps its shape and the square crops it;
        // both would squash a portrait frame into the square. Video frames
        // are portrait or square, so the width is the side that fills it.
        memCacheWidth: (size * MediaQuery.devicePixelRatioOf(context)).round(),
        fadeInDuration: fade,
        fadeOutDuration: fade,
        placeholder: (_, _) => hasBlurhash
            ? _SoundCoverBlurhash(blurhash: blurhash, size: size)
            : const _SoundCoverPending(),
        errorWidget: (_, _, _) => hasBlurhash
            ? _SoundCoverBlurhash(blurhash: blurhash, size: size)
            : _SoundCoverFallback(seed: colorSeed, size: size),
      );
    } else if (hasBlurhash) {
      content = _SoundCoverBlurhash(
        key: ValueKey(blurhash),
        blurhash: blurhash,
        size: size,
      );
    } else {
      content = _SoundCoverFallback(
        key: const ValueKey('fallback'),
        seed: colorSeed,
        size: size,
      );
    }

    return ExcludeSemantics(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: SizedBox.square(
          dimension: size,
          child: AnimatedSwitcher(
            duration: fade,
            layoutBuilder: (current, previous) => Stack(
              fit: StackFit.expand,
              children: [...previous, ?current],
            ),
            child: content,
          ),
        ),
      ),
    );
  }
}

class _SoundCoverBlurhash extends StatelessWidget {
  const _SoundCoverBlurhash({
    required this.blurhash,
    required this.size,
    super.key,
  });

  final String blurhash;
  final double size;

  @override
  Widget build(BuildContext context) {
    return BlurhashDisplay(
      key: const Key('sound_cover_blurhash'),
      blurhash: blurhash,
      width: size,
      height: size,
    );
  }
}

/// A plain tile in the waveform's colour, without the waveform.
class _SoundCoverPending extends StatelessWidget {
  const _SoundCoverPending({super.key});

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      key: const Key('sound_cover_pending'),
      color: context.vineColors.surfaceContainer,
    );
  }
}

/// A tile in one of the brand's accent colours, chosen by [seed], with a
/// note on it.
class _SoundCoverFallback extends StatelessWidget {
  const _SoundCoverFallback({
    required this.seed,
    required this.size,
    super.key,
  });

  final String seed;
  final double size;

  /// Each accent on its own dark ground, as the brand pairs them.
  static const List<(Color, Color)> _palette = [
    (VineTheme.accentOrange, VineTheme.accentOrangeBackground),
    (VineTheme.accentYellow, VineTheme.accentYellowBackground),
    (VineTheme.accentBlue, VineTheme.accentBlueBackground),
    (VineTheme.accentLime, VineTheme.accentLimeBackground),
    (VineTheme.accentPink, VineTheme.accentPinkBackground),
    (VineTheme.accentViolet, VineTheme.accentVioletBackground),
  ];

  @override
  Widget build(BuildContext context) {
    // A hash of our own: String.hashCode may differ between platforms and
    // releases, and the colour should not.
    final hash = seed.codeUnits.fold(0, (h, c) => (h * 31 + c) & 0x7fffffff);
    final (accent, ground) = _palette[hash % _palette.length];
    return ColoredBox(
      key: const Key('sound_cover_fallback'),
      color: ground,
      child: Center(
        child: DivineIcon(
          icon: DivineIconName.musicNotes,
          size: size * 0.45,
          color: accent,
        ),
      ),
    );
  }
}
