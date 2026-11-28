// ABOUTME: Square artwork beside a sound in lists and cards.
// ABOUTME: Image, its blurhash while loading, or a colour tile when there is none.

import 'package:divine_ui/divine_ui.dart';
import 'package:material_ui/material_ui.dart';
import 'package:models/models.dart' show SoundKind;
import 'package:openvine/extensions/media_query_extensions.dart';
import 'package:openvine/models/sound_cover.dart';
import 'package:openvine/widgets/blurhash_display.dart';
import 'package:openvine/widgets/vine_cached_image.dart';

/// Square artwork beside a sound.
///
/// Shows [cover]'s image, its blurhash while the image loads or when there is
/// no image, and a tile in one of the brand's accent colours with an icon
/// for the sound's [kind] on it when the sound has no cover at all, or while
/// an image without a blurhash loads. Each change fades in. It is
/// decorative: the row it sits in names the sound.
class SoundCoverImage extends StatelessWidget {
  const SoundCoverImage({
    required this.size,
    this.cover,
    this.borderRadius = 8,
    this.colorSeed = '',
    this.kind,
    super.key,
  });

  /// The artwork, or `null` for the colour tile.
  final SoundCover? cover;

  /// Picks the colour tile's icon, the one the sound picker's kind filter
  /// shows: notes for music, a flash for an effect, and a waveform, as for
  /// all sounds, when the kind is unknown.
  final SoundKind? kind;

  /// Picks the colour tile's colour, so a sound keeps the same one wherever
  /// it shows; pass its id.
  final String colorSeed;

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
    if (imageUrl != null && imageUrl.isNotEmpty) {
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
            : _SoundCoverFallback(seed: colorSeed, kind: kind, size: size),
        errorWidget: (_, _, _) => hasBlurhash
            ? _SoundCoverBlurhash(blurhash: blurhash, size: size)
            : _SoundCoverFallback(seed: colorSeed, kind: kind, size: size),
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
        kind: kind,
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

/// A tile in one of the brand's accent colours, chosen by [seed], with an
/// icon for [kind] on it.
class _SoundCoverFallback extends StatelessWidget {
  const _SoundCoverFallback({
    required this.seed,
    required this.kind,
    required this.size,
    super.key,
  });

  final String seed;
  final SoundKind? kind;
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
          icon: switch (kind) {
            SoundKind.music => DivineIconName.musicNotes,
            SoundKind.effect => DivineIconName.lightning,
            null => DivineIconName.waveform,
          },
          size: size * 0.45,
          color: accent,
        ),
      ),
    );
  }
}
