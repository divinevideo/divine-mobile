// ABOUTME: Bottom toolbar for the video editor with sub-editor buttons.
// ABOUTME: Provides access to clips, text, draw, volume, and effects editors.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/blocs/video_editor/main_editor/video_editor_main_bloc.dart';
import 'package:openvine/blocs/video_editor/tune_editor/video_editor_tune_bloc.dart';
import 'package:openvine/constants/video_editor_constants.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/widgets/video_editor/main_editor/video_editor_scope.dart';
import 'package:openvine/widgets/video_editor/tune_editor/open_tune_editor.dart';

/// Bottom action bar for the video editor.
///
/// Displays buttons to open sub-editors (text, draw, stickers, effects, music)
/// and dispatches [VideoEditorMainOpenSubEditor] events to the BLoC.
class VideoEditorMainBottomBar extends StatelessWidget {
  const VideoEditorMainBottomBar({super.key});

  @override
  Widget build(BuildContext context) {
    final scope = VideoEditorScope.of(context);
    final textScaler = MediaQuery.textScalerOf(
      context,
    ).clamp(maxScaleFactor: 1.25);

    return MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaler: textScaler),
      child: SizedBox(
        height: VideoEditorConstants.bottomBarHeight,
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
              scrollDirection: Axis.horizontal,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minWidth: constraints.maxWidth - 32,
                ),
                child: Row(
                  spacing: 32,
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    _ActionButton(
                      label: context.l10n.videoEditorLibraryLabel,
                      icon: .images,
                      onTap: scope.onOpenClipsEditor,
                    ),
                    _ActionButton(
                      label: context.l10n.videoEditorTextLabel,
                      icon: .textAa,
                      onTap: () => scope.editor?.openTextEditor(),
                    ),
                    _ActionButton(
                      label: context.l10n.videoEditorDrawLabel,
                      icon: .scribble,
                      onTap: () => scope.editor?.openPaintEditor(),
                    ),
                    _ActionButton(
                      label: context.l10n.videoEditorFilterLabel,
                      icon: .fadersHorizontal,
                      onTap: () => scope.editor?.openFilterEditor(),
                    ),
                    _ActionButton(
                      label: context.l10n.videoEditorTuneLabel,
                      icon: .slidersHorizontal,
                      onTap: () => openTuneEditor(
                        context.read<VideoEditorMainBloc>(),
                        context.read<VideoEditorTuneBloc>(),
                        scope,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// A styled action button with icon and label for the bottom bar.
class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  /// The text label displayed below the icon.
  final String label;

  /// The icon displayed above of the text.
  final DivineIconName icon;

  /// Callback when the button is tapped.
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: .min,
      spacing: 8,
      children: [
        Semantics(
          label: label,
          button: true,
          child: GestureDetector(
            onTap: onTap,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: context.vineColors.surfaceContainer,
                border: .all(width: 2, color: context.vineColors.outlineMuted),
                borderRadius: .circular(16),
              ),
              child: DivineIcon(
                icon: icon,
                color: context.vineColors.accentPositive,
              ),
            ),
          ),
        ),
        ExcludeSemantics(
          child: Text(
            label,
            style: VineTheme.bodySmallFont(
              color: context.vineColors.primaryText,
            ),
            textAlign: .center,
          ),
        ),
      ],
    );
  }
}
