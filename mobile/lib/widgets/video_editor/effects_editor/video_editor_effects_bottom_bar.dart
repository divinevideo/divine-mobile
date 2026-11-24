// ABOUTME: Bottom bar of the video effects editor: a category picker of
// ABOUTME: preview tiles, each showing its effect on the first clip.

import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/blocs/video_editor/effects_editor/video_editor_effects_cubit.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/video_editor/drops_effect_settings.dart';
import 'package:openvine/models/video_editor/editor_video_effect.dart';
import 'package:openvine/providers/clip_manager_provider.dart';
import 'package:openvine/utils/detached_future.dart';
import 'package:openvine/widgets/video_editor/video_editor_category_picker.dart';
import 'package:pro_video_editor/pro_video_editor.dart'
    show VideoEffect, VideoEffectPreview, VideoEffectType;
import 'package:unified_logger/unified_logger.dart';

/// Bottom bar of the effects editor: a [VideoEditorCategoryPicker] of the
/// effects, one section per [EditorEffectCategory]. Opened on an effect of
/// the timeline, the grid starts at that effect's section.
///
/// Each tile shows its effect on the first clip's thumbnail, at full strength
/// and at the start of the effect, where the glitch always bursts. An intro or
/// outro tile plays it over and over instead, so an intro and the outro of the
/// same look can be told apart; see [IntroOutroTile]. The stutter tile pans in
/// steps, as a still has no frames to hold; see [StutterTile].
class VideoEditorEffectsBottomBar extends ConsumerWidget {
  const VideoEditorEffectsBottomBar({super.key});

  /// The height the editor reserves for the bar above the system navigation
  /// bar.
  static double heightOf(BuildContext context) =>
      VideoEditorCategoryPicker.heightOf(context);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final thumbnailPath = ref.watch(
      clipManagerProvider.select((s) => s.firstClipOrNull?.thumbnailPath),
    );
    final selectedType = context.select(
      (VideoEditorEffectsCubit c) => c.state.selectedType,
    );
    return VideoEditorCategoryPicker<EditorEffectCategory, EditorEffectType>(
      sections: _sections,
      categoryLabel: _categoryLabel,
      initialCategory: selectedType?.category,
      isSelected: (type) => type == selectedType,
      tileBuilder: (context, type, isSelected) => _EffectItem(
        type: type,
        isSelected: isSelected,
        thumbnailPath: thumbnailPath,
      ),
    );
  }
}

/// The effects of each category, in picker order.
final Map<EditorEffectCategory, List<EditorEffectType>> _sections = {
  for (final category in EditorEffectCategory.values) category: category.types,
};

class _EffectItem extends StatelessWidget {
  const _EffectItem({
    required this.type,
    required this.isSelected,
    required this.thumbnailPath,
  });

  /// A playhead that never moves, so each tile shows a still.
  static final ValueListenable<Duration> _still = ValueNotifier(Duration.zero);

  final EditorEffectType type;
  final bool isSelected;
  final String? thumbnailPath;

  @override
  Widget build(BuildContext context) {
    final path = thumbnailPath;
    return VideoEditorCategoryPickerTile(
      label: videoEffectLabel(context, type),
      isSelected: isSelected,
      onTap: () => context.read<VideoEditorEffectsCubit>().selectType(type),
      preview: path == null || path.isEmpty
          ? const SizedBox.expand()
          : type == EditorEffectType.echo
          ? _EchoThumbnail(path: path)
          : type == EditorEffectType.stutter
          ? StutterTile(path: path)
          : type.isIntroOutro
          ? IntroOutroTile(path: path, type: type)
          : switch (shaderTileOf(type)) {
              final tile? => _ShaderThumbnail(
                path: path,
                tile: tile,
                texture: shaderTileTextureOf(type),
              ),
              null => VideoEffectPreview(
                effects: [
                  if (type.builtIn case final builtIn?)
                    VideoEffect(type: builtIn),
                ],
                position: _still,
                child: _Thumbnail(path: path),
              ),
            },
    );
  }
}

class _Thumbnail extends StatelessWidget {
  const _Thumbnail({required this.path});

  final String path;

  @override
  Widget build(BuildContext context) {
    return Image.file(
      File(path),
      width: double.infinity,
      height: double.infinity,
      fit: .cover,
      excludeFromSemantics: true,
    );
  }
}

/// The echo tile: a still has no motion to trail, so the thumbnail is shown
/// with fading copies of itself shifted to the left instead.
class _EchoThumbnail extends StatelessWidget {
  const _EchoThumbnail({required this.path});

  final String path;

  /// Shift, as a share of the thumbnail's width inside the tile's border,
  /// and opacity of each copy, oldest first.
  static const List<(double, double)> _copies = [
    (-12 / 48, 0.22),
    (-8 / 48, 0.35),
    (-4 / 48, 0.5),
  ];

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: .expand,
      children: [
        _Thumbnail(path: path),
        for (final (dx, opacity) in _copies)
          FractionalTranslation(
            translation: Offset(dx, 0),
            child: Opacity(
              opacity: opacity,
              child: _Thumbnail(path: path),
            ),
          ),
      ],
    );
  }
}

/// The stutter tile: a still has no frames to hold, so the thumbnail pans
/// back and forth in steps instead, as a moving picture plays under the
/// stutter, a few frames a second.
///
/// With reduced motion it stands still.
@visibleForTesting
class StutterTile extends StatefulWidget {
  const StutterTile({required this.path, super.key});

  /// How long one round of the pan takes.
  static const loop = Duration(milliseconds: 2400);

  final String path;

  @override
  State<StutterTile> createState() => _StutterTileState();
}

class _StutterTileState extends State<StutterTile>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: StutterTile.loop,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.stop();
      return;
    }
    if (!_controller.isAnimating) _controller.repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final thumbnail = Transform.scale(
      scale: _stutterTileZoom,
      child: _Thumbnail(path: widget.path),
    );
    if (MediaQuery.disableAnimationsOf(context)) return thumbnail;
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) => FractionalTranslation(
        translation: Offset(stutterTileShift(_controller.value), 0),
        child: child,
      ),
      child: thumbnail,
    );
  }
}

/// How much the stutter tile zooms into the thumbnail, so its pan never shows
/// an edge.
const _stutterTileZoom = 1.2;

/// How many steps one round of the stutter tile's pan takes: 7.5 a second,
/// in the middle of what the stutter plays at.
const _stutterTileSteps = 18;

/// Where the stutter tile's thumbnail stands, as a share of its width,
/// [loopValue] of the way through its round: a sway from side to side, held
/// at each of [_stutterTileSteps] steps.
@visibleForTesting
double stutterTileShift(double loopValue) {
  final step = (loopValue * _stutterTileSteps).floor() / _stutterTileSteps;
  return 0.08 * math.sin(2 * math.pi * step);
}

/// How the tile of an effect Divine draws itself shows it: the thumbnail
/// through [asset], the same shader the native effect runs, with [values] for
/// the uniforms after the texture size.
typedef ShaderTile = ({String asset, List<double> values});

/// Seconds into the particles at which their tiles show them.
const _particlesTileSeconds = 3.0;

/// Seconds into the prism at which its tile shows it, when the rainbow lies
/// well inside the corner.
const _prismTileSeconds = 6.0;

/// The lightning tile: its first bolt at full brightness, with the picture
/// half lit by the flash, as just after a strike.
final List<double> _lightningTileValues = [0.45, 1.0, ...lightningBolt(0)];

/// The tile of [type], or `null` for an effect whose tile is drawn otherwise.
///
/// Each shows the effect at full strength, except an intro or outro: its
/// still is the one [IntroOutroTile] stands at with reduced motion, half
/// covered at its look's starting structure. The fisheye's value is the
/// `CIBumpDistortion` scale `FisheyeVideoEffect` uses at intensity 1; night
/// vision shows its first noise pattern; the drops show the default settings at
/// a moment where two of them flow into each other; disco and laser show their
/// first colours with the ball or the fan where it starts; the Time effects
/// stand the thumbnail in for their earlier frames, shifted as if the picture
/// moved to the right by their last value, a share of its width each frame;
/// lightning shows its
/// first bolt (see [lightningBolt]) just after it strikes; the particles' last
/// value is the style the native `ParticlesVideoEffect` draws; watercolour and oil
/// paint share one shader, told apart by their last value. The looks share one
/// shader, which reads the look's table from [lookTableAssets]; the ASCII
/// shader reads its glyphs from [asciiGlyphsAsset] (see [shaderTileTextureOf]).
@visibleForTesting
ShaderTile? shaderTileOf(EditorEffectType type) => switch (type.customId) {
  timeSplitVideoEffectId => (
    asset: 'shaders/time_split.frag',
    values: const [1.0, 0.012],
  ),
  longExposureVideoEffectId => (
    asset: 'shaders/long_exposure.frag',
    values: const [1.0, 0.008],
  ),
  motionOnlyVideoEffectId => (
    asset: 'shaders/motion_only.frag',
    values: const [1.0, 0.03],
  ),
  timeWarpVideoEffectId => (
    asset: 'shaders/time_warp.frag',
    values: const [7.0, 0.009],
  ),
  fisheyeVideoEffectId => (asset: 'shaders/fisheye.frag', values: const [0.8]),
  dropsVideoEffectId => (asset: 'shaders/drops.frag', values: _dropsTileValues),
  lightLeakVideoEffectId => (
    asset: 'shaders/light_leak.frag',
    values: const [1.0, 0.0],
  ),
  lightRaysVideoEffectId => (
    asset: 'shaders/light_rays.frag',
    values: const [1.0, 0.0],
  ),
  anamorphicVideoEffectId => (
    asset: 'shaders/anamorphic.frag',
    values: const [1.0],
  ),
  prismVideoEffectId => (
    asset: 'shaders/prism.frag',
    values: const [1.0, _prismTileSeconds],
  ),
  windowLightVideoEffectId => (
    asset: 'shaders/window_light.frag',
    values: const [1.0, 0.0],
  ),
  spotlightVideoEffectId => (
    asset: 'shaders/spotlight.frag',
    values: const [1.0, 0.0],
  ),
  discoVideoEffectId => (
    asset: 'shaders/disco.frag',
    values: const [1.0, 0.0, 1.0, 1.0],
  ),
  laserVideoEffectId => (
    asset: 'shaders/laser.frag',
    values: const [1.0, 0.0, 1.0, 1.0],
  ),
  lightningVideoEffectId => (
    asset: 'shaders/lightning.frag',
    values: _lightningTileValues,
  ),
  snowVideoEffectId => (
    asset: 'shaders/particles.frag',
    values: const [1.0, _particlesTileSeconds, 0.0],
  ),
  confettiVideoEffectId => (
    asset: 'shaders/particles.frag',
    values: const [1.0, _particlesTileSeconds, 1.0],
  ),
  heartsVideoEffectId => (
    asset: 'shaders/particles.frag',
    values: const [1.0, _particlesTileSeconds, 2.0],
  ),
  sparklesVideoEffectId => (
    asset: 'shaders/particles.frag',
    values: const [1.0, _particlesTileSeconds, 3.0],
  ),
  rainVideoEffectId => (
    asset: 'shaders/particles.frag',
    values: const [1.0, _particlesTileSeconds, 4.0],
  ),
  leavesVideoEffectId => (
    asset: 'shaders/particles.frag',
    values: const [1.0, _particlesTileSeconds, 5.0],
  ),
  blossomsVideoEffectId => (
    asset: 'shaders/particles.frag',
    values: const [1.0, _particlesTileSeconds, 6.0],
  ),
  bubblesVideoEffectId => (
    asset: 'shaders/particles.frag',
    values: const [1.0, _particlesTileSeconds, 7.0],
  ),
  bokehVideoEffectId => (
    asset: 'shaders/particles.frag',
    values: const [1.0, _particlesTileSeconds, 8.0],
  ),
  notesVideoEffectId => (
    asset: 'shaders/particles.frag',
    values: const [1.0, _particlesTileSeconds, 9.0],
  ),
  starsVideoEffectId => (
    asset: 'shaders/particles.frag',
    values: const [1.0, _particlesTileSeconds, 10.0],
  ),
  firefliesVideoEffectId => (
    asset: 'shaders/particles.frag',
    values: const [1.0, _particlesTileSeconds, 11.0],
  ),
  embersVideoEffectId => (
    asset: 'shaders/particles.frag',
    values: const [1.0, _particlesTileSeconds, 12.0],
  ),
  moneyVideoEffectId => (
    asset: 'shaders/particles.frag',
    values: const [1.0, _particlesTileSeconds, 13.0],
  ),
  balloonsVideoEffectId => (
    asset: 'shaders/particles.frag',
    values: const [1.0, _particlesTileSeconds, 14.0],
  ),
  tiltShiftVideoEffectId => (
    asset: 'shaders/tilt_shift.frag',
    values: const [1.0],
  ),
  swirlVideoEffectId => (asset: 'shaders/swirl.frag', values: const [1.0]),
  rippleVideoEffectId => (
    asset: 'shaders/ripple.frag',
    values: const [1.0, 0.0],
  ),
  flutedGlassVideoEffectId => (
    asset: 'shaders/fluted_glass.frag',
    values: const [1.0],
  ),
  tunnelVideoEffectId => (
    asset: 'shaders/tunnel.frag',
    values: const [1.0, 0.0, 0.0],
  ),
  spiralTunnelVideoEffectId => (
    asset: 'shaders/tunnel.frag',
    values: const [1.0, 0.0, 1.0],
  ),
  zoomBlurVideoEffectId => (
    asset: 'shaders/zoom_blur.frag',
    values: const [1.0],
  ),
  spinBlurVideoEffectId => (
    asset: 'shaders/spin_blur.frag',
    values: const [1.0],
  ),
  comicVideoEffectId => (asset: 'shaders/comic.frag', values: const [1.0]),
  eightBitVideoEffectId => (
    asset: 'shaders/eight_bit.frag',
    values: const [1.0],
  ),
  anaglyphVideoEffectId => (
    asset: 'shaders/anaglyph.frag',
    values: const [1.0],
  ),
  risoVideoEffectId => (asset: 'shaders/riso.frag', values: const [1.0]),
  watercolorVideoEffectId => (
    asset: 'shaders/paint.frag',
    values: const [1.0, 0.0],
  ),
  oilPaintVideoEffectId => (
    asset: 'shaders/paint.frag',
    values: const [1.0, 1.0],
  ),
  pencilSketchVideoEffectId => (
    asset: 'shaders/pencil_sketch.frag',
    values: const [1.0],
  ),
  neonEdgesVideoEffectId => (
    asset: 'shaders/neon_edges.frag',
    values: const [1.0],
  ),
  asciiVideoEffectId => (asset: 'shaders/ascii.frag', values: const [1.0]),
  stainedGlassVideoEffectId => (
    asset: 'shaders/stained_glass.frag',
    values: const [1.0],
  ),
  thermalVideoEffectId => (asset: 'shaders/thermal.frag', values: const [1.0]),
  nightVisionVideoEffectId => (
    asset: 'shaders/night_vision.frag',
    values: const [1.0, 0.0],
  ),
  xRayVideoEffectId => (asset: 'shaders/x_ray.frag', values: const [1.0]),
  popArtVideoEffectId => (asset: 'shaders/pop_art.frag', values: const [1.0]),
  paperCutVideoEffectId => (
    asset: 'shaders/paper_cut.frag',
    values: const [1.0],
  ),
  crossStitchVideoEffectId => (
    asset: 'shaders/cross_stitch.frag',
    values: const [1.0],
  ),
  bricksVideoEffectId => (asset: 'shaders/bricks.frag', values: const [1.0]),
  final id? when lookTableAssets.containsKey(id) => (
    asset: 'shaders/look.frag',
    values: const [1.0],
  ),
  _ when type.introOutroLook != null => (
    asset: _introOutroShader,
    values: introOutroTileValues(type, amount: _introOutroStillAmount),
  ),
  _ => null,
};

/// The shader every intro and outro tile draws with, the one the native
/// `IntroOutroVideoEffect` runs.
const _introOutroShader = 'shaders/intro_outro.frag';

/// How far a still intro or outro tile is covered: halfway, as where reduced
/// motion stops it from playing.
const _introOutroStillAmount = 0.5;

/// The uniforms of the intro or outro [type]'s tile, covered by [amount]:
/// how far it is covered, the structure of its look at the look's starting
/// intensity, the look, which the shader branches on, and how far a moving
/// curtain's bottom trails behind, [swing] (see [introOutroSwing]).
@visibleForTesting
List<double> introOutroTileValues(
  EditorEffectType type, {
  required double amount,
  double swing = 0,
}) {
  final look = type.introOutroLook!;
  return [amount, look.startingIntensity, look.index.toDouble(), swing];
}

/// How far through its effect an intro or outro tile is, [loopValue] of the
/// way through its loop: it holds where the effect starts for a moment, plays
/// it, as the native effect does over its window, and holds where it ends.
@visibleForTesting
double introOutroTileProgress(double loopValue) {
  final seconds = loopValue * IntroOutroTile.loop.inMicroseconds / 1e6;
  return ((seconds - _introOutroTileHold) / _introOutroTilePlay).clamp(
    0.0,
    1.0,
  );
}

/// Seconds an intro or outro tile holds where the effect starts, then plays
/// it for; it holds where it ends for the rest of [IntroOutroTile.loop].
const _introOutroTileHold = 0.3;
const _introOutroTilePlay = 1.2;

/// The tile of an intro or outro: the thumbnail revealed or covered over and
/// over, so an intro and the outro of the same look, which would be the same
/// still, can be told apart.
///
/// With reduced motion it stands still, halfway covered.
@visibleForTesting
class IntroOutroTile extends StatefulWidget {
  const IntroOutroTile({required this.path, required this.type, super.key});

  /// How long one round of the tile takes.
  static const loop = Duration(milliseconds: 2400);

  final String path;
  final EditorEffectType type;

  @override
  State<IntroOutroTile> createState() => _IntroOutroTileState();
}

class _IntroOutroTileState extends State<IntroOutroTile>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: IntroOutroTile.loop,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.stop();
      return;
    }
    if (!_controller.isAnimating) _controller.repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final still = MediaQuery.disableAnimationsOf(context);
    final ending = widget.type.placement == EditorEffectPlacement.ending;
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final progress = introOutroTileProgress(_controller.value);
        return _ShaderThumbnail(
          path: widget.path,
          tile: still
              ? shaderTileOf(widget.type)!
              : (
                  asset: _introOutroShader,
                  values: introOutroTileValues(
                    widget.type,
                    amount: introOutroCoverage(progress, ending: ending),
                    swing: introOutroSwing(progress, ending: ending),
                  ),
                ),
        );
      },
    );
  }
}

/// The asset [type]'s tile shader reads as its second texture, after the
/// thumbnail: a look's table or the ASCII glyphs. `null` for the others.
@visibleForTesting
String? shaderTileTextureOf(EditorEffectType type) => switch (type.customId) {
  asciiVideoEffectId => asciiGlyphsAsset,
  final id? => lookTableAssets[id],
  null => null,
};

/// The drops' tile values: the intensity, the scale, the frost, the fringes
/// and each drop, seven seconds in.
final List<double> _dropsTileValues = () {
  const settings = DropsEffectSettings();
  return List<double>.unmodifiable([
    1.0,
    dropsScale(settings),
    settings.frost,
    settings.fringes,
    for (final drop in dropsLayout(settings, seconds: 7)) ...[
      drop.x,
      drop.y,
      drop.radius,
    ],
  ]);
}();

/// The tile of an effect Divine draws itself: the thumbnail through the
/// [tile]'s shader, which for a look or the ASCII effect also reads a
/// [texture].
///
/// Shows the plain thumbnail where the backend has no shader image filter
/// (Skia), as the chroma-key preview does.
class _ShaderThumbnail extends StatefulWidget {
  const _ShaderThumbnail({
    required this.path,
    required this.tile,
    this.texture,
  });

  final String path;
  final ShaderTile tile;

  /// The asset bound as the shader's second texture: a look's lookup table
  /// or the ASCII glyphs; `null` for the other effects.
  final String? texture;

  @override
  State<_ShaderThumbnail> createState() => _ShaderThumbnailState();
}

class _ShaderThumbnailState extends State<_ShaderThumbnail> {
  /// Each shader and each texture is read once, whichever tiles show it.
  static final _programs = <String, Future<ui.FragmentProgram>>{};
  static final _textures = <String, Future<ui.Image>>{};

  ui.FragmentShader? _shader;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(_ShaderThumbnail oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.tile.asset != widget.tile.asset ||
        oldWidget.texture != widget.texture) {
      _shader?.dispose();
      _shader = null;
      _load();
    } else if (!listEquals(oldWidget.tile.values, widget.tile.values)) {
      final shader = _shader;
      if (shader != null) _configure(shader);
    }
  }

  void _load() {
    if (!ui.ImageFilter.isShaderFilterSupported) return;
    final asset = widget.tile.asset;
    final texture = widget.texture;
    Future<void> load() async {
      final program = await (_programs[asset] ??= ui.FragmentProgram.fromAsset(
        asset,
      ));
      final image = texture == null
          ? null
          : await (_textures[texture] ??= _decodeTexture(texture));
      if (!mounted || widget.tile.asset != asset || widget.texture != texture) {
        return;
      }
      final shader = _configure(program.fragmentShader());
      // Sampler 0 is the thumbnail, which the engine binds. Bilinear
      // filtering interpolates red and green within a slice of a look's
      // table, and scales the ASCII glyphs to their cells, as the native
      // renderers do.
      if (image != null) {
        shader.setImageSampler(1, image, filterQuality: ui.FilterQuality.low);
      }
      setState(() => _shader = shader);
    }

    runDetached(
      load(),
      'load the effect tile shader',
      logName: 'VideoEditorEffectsBottomBar',
      category: LogCategory.video,
    );
  }

  /// Decodes a look's table or the ASCII glyphs, whose PNGs carry no colour
  /// profile, so the shader reads exactly the values the native renderers
  /// do.
  static Future<ui.Image> _decodeTexture(String asset) async {
    final data = await rootBundle.load(asset);
    final codec = await ui.instantiateImageCodec(
      data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
    );
    try {
      return (await codec.getNextFrame()).image;
    } finally {
      codec.dispose();
    }
  }

  /// Uniforms 0 and 1 are the bound texture's size, which the engine sets.
  ui.FragmentShader _configure(ui.FragmentShader shader) {
    var index = 2;
    for (final value in widget.tile.values) {
      shader.setFloat(index++, value);
    }
    return shader;
  }

  @override
  void dispose() {
    _shader?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final shader = _shader;
    final thumbnail = _Thumbnail(path: widget.path);
    if (shader == null) return thumbnail;
    return ImageFiltered(
      imageFilter: ui.ImageFilter.shader(shader),
      child: thumbnail,
    );
  }
}

/// The localized name of [type], or of "no effect" for `null`.
String videoEffectLabel(BuildContext context, EditorEffectType? type) {
  if (type == null) return context.l10n.videoEditorEffectNone;
  if (type.builtIn case final builtIn?) {
    return builtInVideoEffectLabel(context, builtIn);
  }
  // The others Divine renders itself.
  return switch (type.customId) {
    timeSplitVideoEffectId => context.l10n.videoEditorEffectTimeSplit,
    longExposureVideoEffectId => context.l10n.videoEditorEffectLongExposure,
    motionOnlyVideoEffectId => context.l10n.videoEditorEffectMotionOnly,
    stutterVideoEffectId => context.l10n.videoEditorEffectStutter,
    timeWarpVideoEffectId => context.l10n.videoEditorEffectTimeWarp,
    fisheyeVideoEffectId => context.l10n.videoEditorEffectFisheye,
    dropsVideoEffectId => context.l10n.videoEditorEffectDrops,
    lightLeakVideoEffectId => context.l10n.videoEditorEffectLightLeak,
    lightRaysVideoEffectId => context.l10n.videoEditorEffectLightRays,
    anamorphicVideoEffectId => context.l10n.videoEditorEffectAnamorphic,
    prismVideoEffectId => context.l10n.videoEditorEffectPrism,
    windowLightVideoEffectId => context.l10n.videoEditorEffectWindowLight,
    spotlightVideoEffectId => context.l10n.videoEditorEffectSpotlight,
    discoVideoEffectId => context.l10n.videoEditorEffectDisco,
    laserVideoEffectId => context.l10n.videoEditorEffectLaser,
    lightningVideoEffectId => context.l10n.videoEditorEffectLightning,
    snowVideoEffectId => context.l10n.videoEditorEffectSnow,
    confettiVideoEffectId => context.l10n.videoEditorEffectConfetti,
    heartsVideoEffectId => context.l10n.videoEditorEffectHearts,
    sparklesVideoEffectId => context.l10n.videoEditorEffectSparkles,
    rainVideoEffectId => context.l10n.videoEditorEffectRain,
    leavesVideoEffectId => context.l10n.videoEditorEffectLeaves,
    blossomsVideoEffectId => context.l10n.videoEditorEffectBlossoms,
    bubblesVideoEffectId => context.l10n.videoEditorEffectBubbles,
    bokehVideoEffectId => context.l10n.videoEditorEffectBokeh,
    notesVideoEffectId => context.l10n.videoEditorEffectMusicNotes,
    starsVideoEffectId => context.l10n.videoEditorEffectStars,
    firefliesVideoEffectId => context.l10n.videoEditorEffectFireflies,
    embersVideoEffectId => context.l10n.videoEditorEffectEmbers,
    moneyVideoEffectId => context.l10n.videoEditorEffectMoney,
    balloonsVideoEffectId => context.l10n.videoEditorEffectBalloons,
    tiltShiftVideoEffectId => context.l10n.videoEditorEffectTiltShift,
    swirlVideoEffectId => context.l10n.videoEditorEffectSwirl,
    rippleVideoEffectId => context.l10n.videoEditorEffectRipple,
    flutedGlassVideoEffectId => context.l10n.videoEditorEffectFlutedGlass,
    tunnelVideoEffectId => context.l10n.videoEditorEffectTunnel,
    spiralTunnelVideoEffectId => context.l10n.videoEditorEffectSpiralTunnel,
    zoomBlurVideoEffectId => context.l10n.videoEditorEffectZoomBlur,
    spinBlurVideoEffectId => context.l10n.videoEditorEffectSpinBlur,
    comicVideoEffectId => context.l10n.videoEditorEffectComic,
    eightBitVideoEffectId => context.l10n.videoEditorEffectEightBit,
    anaglyphVideoEffectId => context.l10n.videoEditorEffectAnaglyph,
    risoVideoEffectId => context.l10n.videoEditorEffectRiso,
    watercolorVideoEffectId => context.l10n.videoEditorEffectWatercolor,
    oilPaintVideoEffectId => context.l10n.videoEditorEffectOilPaint,
    pencilSketchVideoEffectId => context.l10n.videoEditorEffectPencilSketch,
    neonEdgesVideoEffectId => context.l10n.videoEditorEffectNeonEdges,
    asciiVideoEffectId => context.l10n.videoEditorEffectAscii,
    stainedGlassVideoEffectId => context.l10n.videoEditorEffectStainedGlass,
    thermalVideoEffectId => context.l10n.videoEditorEffectThermal,
    nightVisionVideoEffectId => context.l10n.videoEditorEffectNightVision,
    xRayVideoEffectId => context.l10n.videoEditorEffectXRay,
    popArtVideoEffectId => context.l10n.videoEditorEffectPopArt,
    paperCutVideoEffectId => context.l10n.videoEditorEffectPaperCut,
    crossStitchVideoEffectId => context.l10n.videoEditorEffectCrossStitch,
    bricksVideoEffectId => context.l10n.videoEditorEffectBricks,
    tealOrangeLookId => context.l10n.videoEditorEffectTealOrange,
    warmFilmLookId => context.l10n.videoEditorEffectWarmFilm,
    slideFilmLookId => context.l10n.videoEditorEffectSlideFilm,
    coolFilmLookId => context.l10n.videoEditorEffectCoolFilm,
    matteLookId => context.l10n.videoEditorEffectMatte,
    bleachBypassLookId => context.l10n.videoEditorEffectBleachBypass,
    crossProcessLookId => context.l10n.videoEditorEffectCrossProcess,
    goldenHourLookId => context.l10n.videoEditorEffectGoldenHour,
    moonlightLookId => context.l10n.videoEditorEffectMoonlight,
    silverLookId => context.l10n.videoEditorEffectSilver,
    introFadeVideoEffectId => context.l10n.videoEditorEffectFadeIn,
    outroFadeVideoEffectId => context.l10n.videoEditorEffectFadeOut,
    introCircleVideoEffectId => context.l10n.videoEditorEffectCircleOpen,
    outroCircleVideoEffectId => context.l10n.videoEditorEffectCircleClose,
    introCinemaVideoEffectId => context.l10n.videoEditorEffectCinemaOpen,
    outroCinemaVideoEffectId => context.l10n.videoEditorEffectCinemaClose,
    introCurtainVideoEffectId => context.l10n.videoEditorEffectCurtainOpen,
    outroCurtainVideoEffectId => context.l10n.videoEditorEffectCurtainClose,
    introFocusVideoEffectId => context.l10n.videoEditorEffectFocusIn,
    outroFocusVideoEffectId => context.l10n.videoEditorEffectFocusOut,
    _ => context.l10n.videoEditorEffectEcho,
  };
}

/// The localized name of [category].
String _categoryLabel(
  BuildContext context,
  EditorEffectCategory category,
) => switch (category) {
  EditorEffectCategory.retro => context.l10n.videoEditorEffectCategoryRetro,
  EditorEffectCategory.art => context.l10n.videoEditorEffectCategoryArt,
  EditorEffectCategory.glitch => context.l10n.videoEditorEffectCategoryGlitch,
  EditorEffectCategory.distort => context.l10n.videoEditorEffectCategoryDistort,
  EditorEffectCategory.light => context.l10n.videoEditorEffectCategoryLight,
  EditorEffectCategory.motion => context.l10n.videoEditorEffectCategoryMotion,
  EditorEffectCategory.time => context.l10n.videoEditorEffectCategoryTime,
  EditorEffectCategory.particles =>
    context.l10n.videoEditorEffectCategoryParticles,
  EditorEffectCategory.looks => context.l10n.videoEditorEffectCategoryLooks,
  EditorEffectCategory.intro => context.l10n.videoEditorEffectCategoryIntro,
  EditorEffectCategory.outro => context.l10n.videoEditorEffectCategoryOutro,
};

/// The localized name of the built-in effect [type].
String builtInVideoEffectLabel(
  BuildContext context,
  VideoEffectType type,
) => switch (type) {
  VideoEffectType.glitch => context.l10n.videoEditorEffectGlitch,
  VideoEffectType.rgbSplit => context.l10n.videoEditorEffectRgbSplit,
  VideoEffectType.vhs => context.l10n.videoEditorEffectVhs,
  VideoEffectType.tvStatic => context.l10n.videoEditorEffectTvStatic,
  VideoEffectType.oldFilm => context.l10n.videoEditorEffectOldFilm,
  VideoEffectType.pixelate => context.l10n.videoEditorEffectPixelate,
  VideoEffectType.pixelPulse => context.l10n.videoEditorEffectPixelPulse,
  VideoEffectType.strobe => context.l10n.videoEditorEffectStrobe,
  VideoEffectType.negativeFlash => context.l10n.videoEditorEffectNegativeFlash,
  VideoEffectType.vignette => context.l10n.videoEditorEffectVignette,
  VideoEffectType.blockGlitch => context.l10n.videoEditorEffectBlockGlitch,
  VideoEffectType.filmGrain => context.l10n.videoEditorEffectFilmGrain,
  VideoEffectType.signalInterference =>
    context.l10n.videoEditorEffectSignalInterference,
  VideoEffectType.crt => context.l10n.videoEditorEffectCrt,
  VideoEffectType.shake => context.l10n.videoEditorEffectShake,
  VideoEffectType.zoomPulse => context.l10n.videoEditorEffectZoomPulse,
  VideoEffectType.mirror => context.l10n.videoEditorEffectMirror,
  VideoEffectType.kaleidoscope => context.l10n.videoEditorEffectKaleidoscope,
  VideoEffectType.splitScreen => context.l10n.videoEditorEffectSplitScreen,
  VideoEffectType.wave => context.l10n.videoEditorEffectWave,
  VideoEffectType.glow => context.l10n.videoEditorEffectGlow,
};
