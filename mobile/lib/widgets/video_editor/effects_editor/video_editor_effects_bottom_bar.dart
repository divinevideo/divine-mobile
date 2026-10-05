// ABOUTME: Bottom bar of the video effects editor: "None" and one preview
// ABOUTME: tile per effect, each showing the effect on the clip thumbnail.

import 'dart:io';

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/blocs/video_editor/effects_editor/video_editor_effects_cubit.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/video_editor/editor_video_effect.dart';
import 'package:openvine/providers/clip_manager_provider.dart';
import 'package:pro_video_editor/pro_video_editor.dart'
    show VideoEffect, VideoEffectPreview, VideoEffectType;

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
                      : VideoEffectPreview(
                          effects: [
                            if (type?.builtIn case final builtIn?)
                              VideoEffect(type: builtIn),
                          ],
                          position: _still,
                          child: _Thumbnail(path: path),
                        ),
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

/// The localized name of [type], or of "no effect" for `null`.
String videoEffectLabel(BuildContext context, EditorEffectType? type) {
  if (type == null) return context.l10n.videoEditorEffectNone;
  final builtIn = type.builtIn;
  // The echo trail is the only effect Divine renders itself so far.
  if (builtIn == null) return context.l10n.videoEditorEffectEcho;
  return builtInVideoEffectLabel(context, builtIn);
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
