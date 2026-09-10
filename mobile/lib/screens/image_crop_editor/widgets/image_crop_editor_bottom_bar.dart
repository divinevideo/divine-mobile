import 'package:divine_ui/divine_ui.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/l10n/l10n.dart';

/// Bottom action bar for the image crop editor.
///
/// Exposes the crop-frame tools as Vine-styled icon + label buttons. Takes
/// plain callbacks so it stays decoupled from `pro_image_editor`'s editor
/// state and is testable in isolation.
class ImageCropEditorBottomBar extends StatelessWidget {
  const ImageCropEditorBottomBar({
    required this.onRotate,
    required this.onFlip,
    required this.onReset,
    super.key,
  });

  /// Rotates the image 90 degrees.
  final VoidCallback onRotate;

  /// Mirrors the image horizontally.
  final VoidCallback onFlip;

  /// Reverts all crop, rotate and flip changes.
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return ColoredBox(
      color: context.vineColors.surface,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _CropAction(
                icon: DivineIconName.arrowClockwise,
                label: l10n.imageCropEditorRotateLabel,
                onTap: onRotate,
              ),
              _CropAction(
                icon: DivineIconName.flipHorizontal,
                label: l10n.imageCropEditorFlipLabel,
                onTap: onFlip,
              ),
              _CropAction(
                icon: DivineIconName.arrowCounterClockwise,
                label: l10n.imageCropEditorResetLabel,
                onTap: onReset,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CropAction extends StatelessWidget {
  const _CropAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final DivineIconName icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 64, minHeight: 56),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              spacing: 4,
              children: [
                DivineIcon(icon: icon, color: context.vineColors.mutedText),
                Text(
                  label,
                  style: VineTheme.labelSmallFont(
                    color: context.vineColors.mutedText,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
