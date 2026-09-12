// ABOUTME: Shared app bar / bottom bar chrome for the crop-rotate editors
// ABOUTME: Used by the clip (video) and the stop-motion frame (image) screens

import 'package:divine_ui/divine_ui.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:pro_image_editor/pro_image_editor.dart'
    show CropRotateEditorState;

/// Top bar for a [CropRotateEditorState]: back (cancel) and done (apply).
class TransformEditorAppBar extends StatelessWidget
    implements PreferredSizeWidget {
  const TransformEditorAppBar({required this.editorState, super.key});

  final CropRotateEditorState editorState;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: SizedBox(
        height: kToolbarHeight,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              DivineIconButton(
                icon: .arrowLeft,
                type: .secondary,
                size: .small,
                semanticLabel:
                    context.l10n.videoEditorTransformCancelSemanticLabel,
                onPressed: editorState.close,
              ),
              DivineIconButton(
                icon: .check,
                size: .small,
                semanticLabel:
                    context.l10n.videoEditorTransformApplySemanticLabel,
                onPressed: editorState.done,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Bottom bar for a [CropRotateEditorState]: rotate, flip and reset, with an
/// optional [leading] action (the clip editor puts play/pause there; a still
/// has nothing to play).
class TransformEditorBottomBar extends StatelessWidget {
  const TransformEditorBottomBar({
    required this.editorState,
    this.leading,
    super.key,
  });

  final CropRotateEditorState editorState;

  /// Action rendered before Rotate — typically a [TransformEditorAction].
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: context.vineColors.surfaceContainerHigh,
        boxShadow: const [
          BoxShadow(
            color: VineTheme.shadow25,
            blurRadius: 8,
            offset: Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              ?leading,
              TransformEditorAction(
                icon: .arrowArcLeft,
                label: context.l10n.videoEditorTransformRotateLabel,
                onPressed: editorState.rotate,
              ),
              TransformEditorAction(
                icon: .cameraRotate,
                label: context.l10n.videoEditorTransformFlipLabel,
                onPressed: editorState.flip,
              ),
              TransformEditorAction(
                icon: .arrowsCounterClockwise,
                label: context.l10n.videoEditorTransformResetLabel,
                onPressed: editorState.reset,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One labelled icon action in a [TransformEditorBottomBar].
class TransformEditorAction extends StatelessWidget {
  const TransformEditorAction({
    required this.icon,
    required this.label,
    required this.onPressed,
    super.key,
  });

  final DivineIconName icon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      spacing: 8,
      children: [
        DivineIconButton(
          icon: icon,
          semanticLabel: label,
          onPressed: onPressed,
          type: .secondary,
          size: .small,
        ),
        ExcludeSemantics(
          child: Text(
            label,
            style: VineTheme.bodySmallFont(
              color: context.vineColors.primaryText,
            ),
          ),
        ),
      ],
    );
  }
}
