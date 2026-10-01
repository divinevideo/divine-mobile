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
    const types = <VideoEffectType?>[null, ...VideoEffectType.values];

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

  final VideoEffectType? type;
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
                      : VideoEffectPreview(
                          effects: [
                            if (type != null) VideoEffect(type: type),
                          ],
                          position: _still,
                          child: Image.file(
                            File(path),
                            width: 52,
                            height: 52,
                            fit: .cover,
                            excludeFromSemantics: true,
                          ),
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

/// The localized name of [type], or of "no effect" for `null`.
String videoEffectLabel(BuildContext context, VideoEffectType? type) =>
    switch (type) {
      null => context.l10n.videoEditorEffectNone,
      VideoEffectType.glitch => context.l10n.videoEditorEffectGlitch,
      VideoEffectType.rgbSplit => context.l10n.videoEditorEffectRgbSplit,
      VideoEffectType.vhs => context.l10n.videoEditorEffectVhs,
      VideoEffectType.tvStatic => context.l10n.videoEditorEffectTvStatic,
      VideoEffectType.oldFilm => context.l10n.videoEditorEffectOldFilm,
      VideoEffectType.pixelate => context.l10n.videoEditorEffectPixelate,
      VideoEffectType.pixelPulse => context.l10n.videoEditorEffectPixelPulse,
      VideoEffectType.strobe => context.l10n.videoEditorEffectStrobe,
      VideoEffectType.negativeFlash =>
        context.l10n.videoEditorEffectNegativeFlash,
      VideoEffectType.vignette => context.l10n.videoEditorEffectVignette,
    };
