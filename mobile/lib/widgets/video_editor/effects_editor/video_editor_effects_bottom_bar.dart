// ABOUTME: Bottom bar of the video effects editor: "None" and one preview
// ABOUTME: tile per effect, each showing the effect on the clip thumbnail.

import 'dart:io';
import 'dart:ui' as ui;

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/blocs/video_editor/effects_editor/video_editor_effects_cubit.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/video_editor/drops_effect_settings.dart';
import 'package:openvine/models/video_editor/editor_video_effect.dart';
import 'package:openvine/providers/clip_manager_provider.dart';
import 'package:openvine/utils/detached_future.dart';
import 'package:pro_video_editor/pro_video_editor.dart'
    show VideoEffect, VideoEffectPreview, VideoEffectType;
import 'package:unified_logger/unified_logger.dart';

/// Bottom bar listing "None" and every video effect.
///
/// Each tile shows its effect on the first clip's thumbnail, at full strength
/// and at the start of the effect, where the glitch always bursts.
class VideoEditorEffectsBottomBar extends ConsumerWidget {
  const VideoEditorEffectsBottomBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final thumbnailPath = ref.watch(
      clipManagerProvider.select((s) => s.firstClipOrNull?.thumbnailPath),
    );
    final selectedType = context.select(
      (VideoEditorEffectsCubit c) => c.state.selectedType,
    );
    final textScaler = MediaQuery.textScalerOf(
      context,
    ).clamp(maxScaleFactor: 1.25);
    final types = <EditorEffectType?>[null, ...EditorEffectType.values];

    return MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaler: textScaler),
      child: ListView.separated(
        scrollDirection: .horizontal,
        padding: const .fromLTRB(16, 0, 16, 4),
        itemCount: types.length,
        separatorBuilder: (_, index) {
          if (index == 0) {
            return Padding(
              padding: const .symmetric(horizontal: 8),
              child: VerticalDivider(
                color: VineTheme.onSurface.withValues(alpha: 0.3),
                thickness: 1,
                indent: 12,
                endIndent: 12,
              ),
            );
          }
          return const SizedBox(width: 8);
        },
        itemBuilder: (context, index) {
          final type = types[index];
          return _EffectItem(
            type: type,
            isSelected: type == selectedType,
            thumbnailPath: thumbnailPath,
          );
        },
      ),
    );
  }
}

class _EffectItem extends StatelessWidget {
  const _EffectItem({
    required this.type,
    required this.isSelected,
    required this.thumbnailPath,
  });

  /// A playhead that never moves, so each tile shows a still.
  static final ValueListenable<Duration> _still = ValueNotifier(Duration.zero);

  final EditorEffectType? type;
  final bool isSelected;
  final String? thumbnailPath;

  @override
  Widget build(BuildContext context) {
    final type = this.type;
    final label = videoEffectLabel(context, type);
    final path = thumbnailPath;
    return Semantics(
      label: label,
      button: true,
      selected: isSelected,
      child: GestureDetector(
        onTap: () => context.read<VideoEditorEffectsCubit>().selectType(type),
        child: SizedBox(
          width: 68,
          child: Column(
            mainAxisAlignment: .end,
            spacing: 4,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: context.vineColors.surfaceContainer,
                  borderRadius: .circular(20),
                  border: .all(
                    color: isSelected
                        ? context.vineColors.accentPositive
                        : context.vineColors.outlineMuted,
                    width: 2,
                  ),
                ),
                child: ClipRRect(
                  borderRadius: .circular(18),
                  child: path == null || path.isEmpty
                      ? const SizedBox.expand()
                      : type == EditorEffectType.echo
                      ? _EchoThumbnail(path: path)
                      : switch (shaderTileOf(type)) {
                          final tile? => _ShaderThumbnail(
                            path: path,
                            tile: tile,
                          ),
                          null => VideoEffectPreview(
                            effects: [
                              if (type?.builtIn case final builtIn?)
                                VideoEffect(type: builtIn),
                            ],
                            position: _still,
                            child: _Thumbnail(path: path),
                          ),
                        },
                ),
              ),
              // The tile's Semantics already carries the name.
              ExcludeSemantics(
                child: Text(
                  label,
                  style: VineTheme.bodySmallFont(
                    color: context.vineColors.onSurface,
                  ),
                  maxLines: 1,
                  textAlign: .center,
                  overflow: .ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
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
      width: 52,
      height: 52,
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

  /// Shift and opacity of each copy, oldest first.
  static const _copies = [(-12.0, 0.22), (-8.0, 0.35), (-4.0, 0.5)];

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: .expand,
      children: [
        _Thumbnail(path: path),
        for (final (dx, opacity) in _copies)
          Transform.translate(
            offset: Offset(dx, 0),
            child: Opacity(
              opacity: opacity,
              child: _Thumbnail(path: path),
            ),
          ),
      ],
    );
  }
}

/// How the tile of an effect Divine draws itself shows it: the thumbnail
/// through [asset], the same shader the native effect runs, with [values] for
/// the uniforms after the texture size.
typedef ShaderTile = ({String asset, List<double> values});

/// Seconds into the particles at which their tiles show them.
const _particlesTileSeconds = 3.0;

/// The tile of [type], or `null` for an effect whose tile is drawn otherwise.
///
/// Each shows the effect at full strength. The fisheye's value is the
/// `CIBumpDistortion` scale `FisheyeVideoEffect` uses at intensity 1; the
/// drops show the default settings at a moment where two of them flow into
/// each other; the particles' last value is the style the native
/// `ParticlesVideoEffect` draws.
@visibleForTesting
ShaderTile? shaderTileOf(EditorEffectType? type) => switch (type?.customId) {
  fisheyeVideoEffectId => (asset: 'shaders/fisheye.frag', values: const [0.8]),
  dropsVideoEffectId => (asset: 'shaders/drops.frag', values: _dropsTileValues),
  lightLeakVideoEffectId => (
    asset: 'shaders/light_leak.frag',
    values: const [1.0, 0.0],
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
  tiltShiftVideoEffectId => (
    asset: 'shaders/tilt_shift.frag',
    values: const [1.0],
  ),
  zoomBlurVideoEffectId => (
    asset: 'shaders/zoom_blur.frag',
    values: const [1.0],
  ),
  comicVideoEffectId => (asset: 'shaders/comic.frag', values: const [1.0]),
  _ => null,
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
/// [tile]'s shader.
///
/// Shows the plain thumbnail where the backend has no shader image filter
/// (Skia), as the chroma-key preview does.
class _ShaderThumbnail extends StatefulWidget {
  const _ShaderThumbnail({required this.path, required this.tile});

  final String path;
  final ShaderTile tile;

  @override
  State<_ShaderThumbnail> createState() => _ShaderThumbnailState();
}

class _ShaderThumbnailState extends State<_ShaderThumbnail> {
  /// Each shader is read once, whichever tiles show it.
  static final _programs = <String, Future<ui.FragmentProgram>>{};

  ui.FragmentShader? _shader;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(_ShaderThumbnail oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.tile.asset != widget.tile.asset) {
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
    runDetached(
      (_programs[asset] ??= ui.FragmentProgram.fromAsset(asset)).then((
        program,
      ) {
        if (!mounted || widget.tile.asset != asset) return;
        setState(() => _shader = _configure(program.fragmentShader()));
      }),
      'load the effect tile shader',
      logName: 'VideoEditorEffectsBottomBar',
      category: LogCategory.video,
    );
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
    fisheyeVideoEffectId => context.l10n.videoEditorEffectFisheye,
    dropsVideoEffectId => context.l10n.videoEditorEffectDrops,
    lightLeakVideoEffectId => context.l10n.videoEditorEffectLightLeak,
    snowVideoEffectId => context.l10n.videoEditorEffectSnow,
    confettiVideoEffectId => context.l10n.videoEditorEffectConfetti,
    heartsVideoEffectId => context.l10n.videoEditorEffectHearts,
    sparklesVideoEffectId => context.l10n.videoEditorEffectSparkles,
    tiltShiftVideoEffectId => context.l10n.videoEditorEffectTiltShift,
    zoomBlurVideoEffectId => context.l10n.videoEditorEffectZoomBlur,
    comicVideoEffectId => context.l10n.videoEditorEffectComic,
    _ => context.l10n.videoEditorEffectEcho,
  };
}

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
