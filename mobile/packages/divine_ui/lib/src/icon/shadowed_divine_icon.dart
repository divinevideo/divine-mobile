import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:divine_ui/src/icon/divine_icon.dart';
import 'package:divine_ui/src/theme/vine_theme.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// One glyph-shaped drop shadow behind a [ShadowedDivineIcon].
///
/// The shadow is the icon's own silhouette, tinted [color], offset by
/// [offset] and blurred with a gaussian of [blurSigma] — so it follows the
/// glyph rather than its bounding box.
@immutable
class DivineIconShadow {
  /// Creates a glyph drop shadow.
  const DivineIconShadow({
    required this.offset,
    required this.blurSigma,
    this.color = VineTheme.innerShadow,
  });

  /// Where the shadow copy sits relative to the glyph, in logical pixels.
  final Offset offset;

  /// Gaussian blur sigma applied to the shadow copy, in logical pixels.
  final double blurSigma;

  /// Tint of the shadow copy.
  final Color color;

  /// How far the blurred copy can reach past the glyph's own bounds.
  ///
  /// Three sigmas cover 99.7 % of a gaussian; anything beyond is invisible.
  double get reach =>
      math.max(offset.dx.abs(), offset.dy.abs()) + 3 * blurSigma;

  @override
  bool operator ==(Object other) =>
      other is DivineIconShadow &&
      other.offset == offset &&
      other.blurSigma == blurSigma &&
      other.color == color;

  @override
  int get hashCode => Object.hash(offset, blurSigma, color);
}

/// The Figma `effects/shadow-10` drop-shadow pair for icons drawn over
/// video, matching [VineTheme.buttonShadows] in offset and spread.
const List<DivineIconShadow> divineIconButtonShadows = [
  DivineIconShadow(offset: Offset(1, 1), blurSigma: 1),
  DivineIconShadow(offset: Offset(0.4, 0.4), blurSigma: 0.6),
];

/// A [DivineIcon] with glyph-shaped drop shadows, rasterised once and
/// painted as a single image.
///
/// Drawn as live layers, this icon costs three colour-filtered SVG
/// `saveLayer`s and two gaussian blur passes on **every frame** — Impeller
/// has no raster cache, so a `RepaintBoundary` around the layers only
/// spares the recording, never the rasterisation. The feed's action rail and
/// the bottom nav together put ~60 such passes and ~22 blurs under a
/// playing video, which was most of the raster thread's frame budget on
/// Android. Baking the composite into a [ui.Image] the first time a given
/// (icon, colour, size, pixel ratio) is shown turns each icon into one
/// `drawImage`.
///
/// Until the raster is ready — the first frame or two after a cold start —
/// the icon renders through the live-layer path so nothing flashes; every
/// later mount of the same key paints the cached image on its first frame.
/// Cached images are process-wide and capped at
/// [ShadowedIconRasterCache.maxEntries] baked bitmaps; the least recently
/// drawn entry is dropped when the cap is hit, and the engine frees the
/// dropped bitmap once no widget is drawing it. The cap matters because the
/// key includes the tint: an appearance switch lerps the nav's `onNav`
/// through every intermediate value, so without a bound one theme toggle
/// would retain a bitmap per intermediate tint for the process lifetime.
class ShadowedDivineIcon extends StatefulWidget {
  /// Creates a shadowed icon.
  const ShadowedDivineIcon({
    required this.icon,
    required this.color,
    this.size = 24,
    this.shadows = divineIconButtonShadows,
    this.cache,
    super.key,
  });

  /// The icon to draw.
  final DivineIconName icon;

  /// Tint of the foreground glyph.
  final Color color;

  /// Unscaled icon dimension; see [DivineIcon.size].
  final double size;

  /// Shadows painted under the glyph, first entry lowest.
  final List<DivineIconShadow> shadows;

  /// Raster cache to draw from. Defaults to [ShadowedIconRasterCache.instance];
  /// tests inject one whose loader needs no asset bundle.
  final ShadowedIconRasterCache? cache;

  @override
  State<ShadowedDivineIcon> createState() => _ShadowedDivineIconState();
}

class _ShadowedDivineIconState extends State<ShadowedDivineIcon> {
  ShadowedIconRasterKey? _key;
  ui.Image? _image;

  ShadowedIconRasterCache get _cache =>
      widget.cache ?? ShadowedIconRasterCache.instance;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _resolve();
  }

  @override
  void didUpdateWidget(ShadowedDivineIcon oldWidget) {
    super.didUpdateWidget(oldWidget);
    _resolve();
  }

  void _resolve() {
    final key = ShadowedIconRasterKey(
      icon: widget.icon,
      color: widget.color,
      dimension: DivineIcon.scaleSize(context, widget.size),
      devicePixelRatio: MediaQuery.devicePixelRatioOf(context),
      shadows: widget.shadows,
    );
    if (key == _key) return;
    _key = key;
    _image = _cache.imageFor(key);
    if (_image != null) return;
    unawaited(
      _cache.rasterize(key, context).then((image) {
        if (!mounted || image == null || key != _key) return;
        setState(() => _image = image);
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final key = _key!;
    final image = _image;
    if (image == null) {
      return _LayeredShadowedIcon(
        icon: widget.icon,
        color: widget.color,
        size: widget.size,
        shadows: widget.shadows,
      );
    }
    final extent = key.extent;
    return SizedBox.square(
      dimension: key.dimension,
      child: OverflowBox(
        minWidth: extent,
        maxWidth: extent,
        minHeight: extent,
        maxHeight: extent,
        child: RawImage(
          image: image,
          width: extent,
          height: extent,
          filterQuality: FilterQuality.low,
        ),
      ),
    );
  }
}

/// The live-layer rendering: shadow copies as blurred, tinted [DivineIcon]s
/// under the foreground glyph. Costs a `saveLayer` per copy and a blur pass
/// per shadow on every frame, so it only bridges the gap until the raster
/// cache has an image — or, when a bake cannot complete, serves that icon for
/// the process lifetime. The [RepaintBoundary] keeps those blurs off the
/// video's layer on backends with a raster cache, which is what the original
/// call sites relied on before the bake existed.
class _LayeredShadowedIcon extends StatelessWidget {
  const _LayeredShadowedIcon({
    required this.icon,
    required this.color,
    required this.size,
    required this.shadows,
  });

  final DivineIconName icon;
  final Color color;
  final double size;
  final List<DivineIconShadow> shadows;

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: Stack(
        alignment: Alignment.center,
        children: [
          for (final shadow in shadows)
            Transform.translate(
              offset: shadow.offset,
              child: ImageFiltered(
                imageFilter: ui.ImageFilter.blur(
                  sigmaX: shadow.blurSigma,
                  sigmaY: shadow.blurSigma,
                ),
                // Decorative copies; the foreground glyph is the only node a
                // screen reader should meet.
                child: ExcludeSemantics(
                  child: DivineIcon(
                    icon: icon,
                    color: shadow.color,
                    size: size,
                  ),
                ),
              ),
            ),
          DivineIcon(icon: icon, color: color, size: size),
        ],
      ),
    );
  }
}

/// Identity of one baked icon bitmap.
@immutable
class ShadowedIconRasterKey {
  /// Creates a raster key.
  ShadowedIconRasterKey({
    required this.icon,
    required this.color,
    required this.dimension,
    required this.devicePixelRatio,
    required List<DivineIconShadow> shadows,
  }) : shadows = List.unmodifiable(shadows);

  /// The icon.
  final DivineIconName icon;

  /// Foreground tint.
  final Color color;

  /// Glyph dimension in logical pixels, after text scaling.
  final double dimension;

  /// Pixel ratio the bitmap is baked at.
  final double devicePixelRatio;

  /// Shadows under the glyph.
  final List<DivineIconShadow> shadows;

  /// Logical margin on every side so the blurred shadows are not clipped.
  double get margin => shadows.isEmpty
      ? 0
      : shadows.map((s) => s.reach).reduce(math.max).ceilToDouble();

  /// Logical edge length of the bitmap: the glyph plus margin on each side.
  double get extent => dimension + 2 * margin;

  /// Bitmap edge length in device pixels.
  int get pixelExtent => (extent * devicePixelRatio).ceil();

  @override
  bool operator ==(Object other) =>
      other is ShadowedIconRasterKey &&
      other.icon == icon &&
      other.color == color &&
      other.dimension == dimension &&
      other.devicePixelRatio == devicePixelRatio &&
      listEquals(other.shadows, shadows);

  @override
  int get hashCode => Object.hash(
    icon,
    color,
    dimension,
    devicePixelRatio,
    Object.hashAll(shadows),
  );
}

/// Resolves an icon's SVG to something a canvas can draw.
typedef DivineIconLoader = BytesLoader Function(DivineIconName icon);

/// Process-wide cache of baked [ShadowedDivineIcon] bitmaps.
class ShadowedIconRasterCache {
  /// Creates a cache. [loaderFor] resolves an icon to its SVG bytes and
  /// defaults to the same asset lookup [DivineIcon] uses.
  ShadowedIconRasterCache({DivineIconLoader? loaderFor})
    : _loaderFor = loaderFor ?? assetLoaderFor;

  /// The cache production widgets share.
  static final ShadowedIconRasterCache instance = ShadowedIconRasterCache();

  /// How many baked bitmaps a cache keeps before dropping the least recently
  /// drawn one.
  ///
  /// The key includes the tint, and the theme framework lerps the nav's
  /// `onNav` through every intermediate value during an appearance switch, so
  /// an unbounded keyed cache would retain a bitmap per intermediate tint per
  /// icon for the process lifetime. Dropping the map's reference is enough:
  /// any widget still drawing a dropped bitmap holds its own reference, and
  /// the engine frees the bitmap once the last one lets go.
  static const int maxEntries = 64;

  /// The default loader: the same asset lookup [DivineIcon] renders through.
  static BytesLoader assetLoaderFor(DivineIconName icon) =>
      SvgAssetLoader(icon.assetPath);

  final DivineIconLoader _loaderFor;
  final Map<ShadowedIconRasterKey, ui.Image> _images = {};
  final Map<ShadowedIconRasterKey, Future<ui.Image?>> _pending = {};

  /// The baked bitmap for [key], or `null` when it has not been baked yet.
  ///
  /// A hit counts as a use for the [maxEntries] bound.
  ui.Image? imageFor(ShadowedIconRasterKey key) {
    final image = _images.remove(key);
    if (image != null) {
      _images[key] = image;
    }
    return image;
  }

  /// Bakes the bitmap for [key], sharing one in-flight bake per key.
  ///
  /// Resolves to `null` when the SVG cannot be loaded or rasterised; the
  /// caller keeps drawing the live layers and a later mount retries.
  Future<ui.Image?> rasterize(ShadowedIconRasterKey key, BuildContext context) {
    final cached = imageFor(key);
    if (cached != null) return Future.value(cached);
    return _pending.putIfAbsent(key, () async {
      try {
        final info = await vg.loadPicture(_loaderFor(key.icon), context);
        final image = await _bake(key, info);
        _images[key] = image;
        _dropOverflow();
        return image;
      } on Object {
        // A missing asset or a failed rasterisation only means this icon
        // stays on the live-layer path; there is nothing to recover.
        return null;
      } finally {
        unawaited(_pending.remove(key));
      }
    });
  }

  /// Drops the least recently drawn bakes down to [maxEntries].
  ///
  /// The map is insertion-ordered and [imageFor] reinserts on every hit, so
  /// its first key is the least recently used.
  void _dropOverflow() {
    while (_images.length > maxEntries) {
      _images.remove(_images.keys.first);
    }
  }

  Future<ui.Image> _bake(ShadowedIconRasterKey key, PictureInfo info) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final pixels = key.pixelExtent;
    // Map logical space onto the bitmap so the glyph lands at exact device
    // pixels rather than at the rounded ratio.
    canvas.scale(pixels / key.extent);
    final bounds = Offset.zero & Size.square(key.extent);
    // Fit the SVG's own viewbox into the glyph box the way BoxFit.contain
    // does, which is what DivineIcon asks of SvgPicture.
    final scale = math.min(
      key.dimension / info.size.width,
      key.dimension / info.size.height,
    );
    final glyphOrigin = Offset(
      key.margin + (key.dimension - info.size.width * scale) / 2,
      key.margin + (key.dimension - info.size.height * scale) / 2,
    );

    void drawGlyph(Offset offset, Paint layerPaint) {
      canvas
        ..saveLayer(bounds, layerPaint)
        ..translate(glyphOrigin.dx + offset.dx, glyphOrigin.dy + offset.dy)
        ..scale(scale)
        ..drawPicture(info.picture)
        ..restore();
    }

    for (final shadow in key.shadows) {
      drawGlyph(
        shadow.offset,
        Paint()
          ..colorFilter = ColorFilter.mode(shadow.color, BlendMode.srcIn)
          ..imageFilter = ui.ImageFilter.blur(
            sigmaX: shadow.blurSigma,
            sigmaY: shadow.blurSigma,
          ),
      );
    }
    drawGlyph(
      Offset.zero,
      Paint()..colorFilter = ColorFilter.mode(key.color, BlendMode.srcIn),
    );

    final picture = recorder.endRecording();
    try {
      return await picture.toImage(pixels, pixels);
    } finally {
      // Both pictures have been consumed by toImage: the recorder's own, and
      // the SVG's decoded picture, which vg.loadPicture hands to the caller
      // to dispose.
      picture.dispose();
      info.picture.dispose();
    }
  }

  /// Drops every baked bitmap so a test starts from an empty cache.
  @visibleForTesting
  void clear() {
    _images.clear();
    _pending.clear();
  }
}
