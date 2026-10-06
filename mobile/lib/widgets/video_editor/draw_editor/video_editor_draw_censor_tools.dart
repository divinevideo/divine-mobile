// ABOUTME: Bottom bar of the draw editor while it hides areas: a hint and the
// ABOUTME: blur and pixelate tools, each previewed on the first clip's thumbnail.

import 'dart:io';
import 'dart:ui' show ImageFilter;

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/blocs/video_editor/draw_editor/video_editor_draw_bloc.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/clip_manager_provider.dart';

/// The tools of the draw editor while it hides areas of the video.
///
/// Pixelate is only offered where the renderer can preview it: it needs
/// shader image filters, which Impeller has and Skia does not.
class VideoEditorDrawCensorTools extends ConsumerWidget {
  const VideoEditorDrawCensorTools({required this.onToolSelected, super.key});

  /// Called with the tool the user picks.
  final ValueChanged<DrawToolType> onToolSelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final thumbnailPath = ref.watch(
      clipManagerProvider.select((s) => s.firstClipOrNull?.thumbnailPath),
    );
    final selectedTool = context.select(
      (VideoEditorDrawBloc b) => b.state.selectedTool,
    );
    final textScaler = MediaQuery.textScalerOf(
      context,
    ).clamp(maxScaleFactor: 1.25);

    return MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaler: textScaler),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const .fromLTRB(16, 0, 16, 4),
          child: Row(
            crossAxisAlignment: .end,
            spacing: 8,
            children: [
              Expanded(
                child: Padding(
                  padding: const .only(bottom: 20),
                  child: Text(
                    context.l10n.videoEditorCensorHint,
                    style: VineTheme.bodyMediumFont(
                      color: context.vineColors.onSurfaceMuted,
                    ),
                    maxLines: 3,
                    overflow: .ellipsis,
                  ),
                ),
              ),
              for (final tool in [
                DrawToolType.blur,
                if (ImageFilter.isShaderFilterSupported) DrawToolType.pixelate,
              ])
                _CensorToolItem(
                  tool: tool,
                  isSelected: tool == selectedTool,
                  thumbnailPath: thumbnailPath,
                  onTap: () => onToolSelected(tool),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CensorToolItem extends StatelessWidget {
  const _CensorToolItem({
    required this.tool,
    required this.isSelected,
    required this.thumbnailPath,
    required this.onTap,
  });

  final DrawToolType tool;
  final bool isSelected;
  final String? thumbnailPath;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final label = censorToolLabel(context, tool);
    return Semantics(
      label: label,
      button: true,
      selected: isSelected,
      child: GestureDetector(
        onTap: onTap,
        behavior: .opaque,
        child: SizedBox(
          width: 84,
          child: Column(
            mainAxisSize: .min,
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
                  child: _CensorToolPreview(
                    tool: tool,
                    thumbnailPath: thumbnailPath,
                  ),
                ),
              ),
              // The item's Semantics already carries the name.
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

/// The first clip's thumbnail the way [tool] hides it, or the tool's icon
/// when there is no thumbnail yet.
class _CensorToolPreview extends StatelessWidget {
  const _CensorToolPreview({required this.tool, required this.thumbnailPath});

  final DrawToolType tool;
  final String? thumbnailPath;

  @override
  Widget build(BuildContext context) {
    final path = thumbnailPath;
    if (path == null || path.isEmpty) {
      return Center(
        child: DivineIcon(
          icon: tool == .pixelate ? .gridNine : .dropHalf,
          color: context.vineColors.onSurface,
        ),
      );
    }
    final file = File(path);
    if (tool == .pixelate) {
      // Decoded a few pixels wide and scaled up without filtering, so every
      // decoded pixel shows as one block.
      return Image.file(
        file,
        width: 52,
        height: 52,
        fit: .cover,
        cacheWidth: 7,
        filterQuality: .none,
        excludeFromSemantics: true,
      );
    }
    return ImageFiltered(
      imageFilter: ImageFilter.blur(sigmaX: 3, sigmaY: 3, tileMode: .clamp),
      child: Image.file(
        file,
        width: 52,
        height: 52,
        fit: .cover,
        excludeFromSemantics: true,
      ),
    );
  }
}

/// The localized name of a tool that hides an area.
String censorToolLabel(BuildContext context, DrawToolType tool) =>
    tool == .pixelate
    ? context.l10n.videoEditorEffectPixelate
    : context.l10n.videoEditorBlurLabel;
