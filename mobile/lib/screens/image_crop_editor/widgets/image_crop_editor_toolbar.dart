import 'package:divine_ui/divine_ui.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/l10n/l10n.dart';

/// Top bar for the image crop editor.
///
/// Mirrors the video editor's chrome
/// ([VideoEditorToolbar]): a ghost close (x) button on the left and a done
/// (check) button on the right, on the dark Vine surface. Implements
/// [PreferredSizeWidget] so it can be handed to `pro_image_editor`'s
/// `ReactiveAppbar` app-bar slot.
class ImageCropEditorToolbar extends StatelessWidget
    implements PreferredSizeWidget {
  const ImageCropEditorToolbar({
    required this.onClose,
    this.onDone,
    super.key,
  });

  /// Called when the close button is pressed. Discards the crop and returns
  /// without uploading.
  final VoidCallback onClose;

  /// Called when the done button is pressed. When null the button renders in
  /// its disabled state.
  final VoidCallback? onDone;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AppBar(
      automaticallyImplyLeading: false,
      backgroundColor: VineTheme.transparent,
      surfaceTintColor: VineTheme.transparent,
      leadingWidth: 72,
      leading: Padding(
        padding: const EdgeInsets.only(left: 16),
        child: DivineIconButton(
          icon: DivineIconName.x,
          // `CropRotateEditor` hands this to a plain `Scaffold.appBar` with no
          // `extendBodyBehindAppBar`, so the bar sits above the image on the
          // scaffold's own `colors.surface` — a themed surface, not media.
          type: DivineIconButtonType.ghostSecondary,
          size: DivineIconButtonSize.small,
          semanticLabel: l10n.imageCropEditorCloseSemanticLabel,
          onPressed: onClose,
        ),
      ),
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 16),
          child: DivineIconButton(
            icon: DivineIconName.check,
            size: DivineIconButtonSize.small,
            semanticLabel: l10n.imageCropEditorDoneSemanticLabel,
            onPressed: onDone,
          ),
        ),
      ],
    );
  }
}
