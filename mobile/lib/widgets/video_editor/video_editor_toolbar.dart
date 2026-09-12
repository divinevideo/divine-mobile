// ABOUTME: Reusable top toolbar for video editor sub-editors.
// ABOUTME: Provides close/done buttons with optional center widgets.

import 'package:divine_ui/divine_ui.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/constants/video_editor_constants.dart';

/// Reusable top bar for video editor sub-editors.
///
/// Displays a close button on the left and a done button on the right.
/// Optional [center] widgets are placed between the two buttons.
///
/// When [center] is empty a single [Spacer] pushes the buttons to opposite
/// ends. When non-empty the caller controls spacing (e.g. wrap items in
/// [Spacer], [Flexible], or [SizedBox] as needed).
class VideoEditorToolbar extends StatelessWidget {
  const VideoEditorToolbar({
    required this.onClose,
    required this.closeSemanticLabel,
    required this.doneSemanticLabel,
    this.onDone,
    this.closeIcon = DivineIconName.x,
    this.doneIcon = DivineIconName.check,
    this.closeType = DivineIconButtonType.ghostSecondary,
    this.center,
    this.padding = const EdgeInsets.fromLTRB(16, 12, 16, 0),
    super.key,
  });

  /// Called when the close button is pressed.
  final VoidCallback onClose;

  /// Called when the done button is pressed.
  ///
  /// When null the done button is rendered in its disabled state.
  final VoidCallback? onDone;

  /// Icon shown on the close button. Defaults to [DivineIconName.x].
  final DivineIconName closeIcon;

  /// Icon shown on the done button. Defaults to [DivineIconName.check].
  final DivineIconName doneIcon;

  /// Visual style of the close button. Defaults to [DivineIconButtonType.ghostSecondary].
  final DivineIconButtonType closeType;

  /// Accessibility label for the close button.
  final String closeSemanticLabel;

  /// Accessibility label for the done button.
  final String doneSemanticLabel;

  /// Optional widgets displayed between the close and done buttons.
  final Widget? center;

  /// Outer padding around the toolbar row.
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: padding,
        child: Row(
          spacing: 12,
          mainAxisAlignment: .spaceBetween,
          children: [
            Hero(
              tag: VideoEditorConstants.heroToolbarLeadingId,
              child: DivineIconButton(
                icon: closeIcon,
                semanticLabel: closeSemanticLabel,
                size: .small,
                type: closeType,
                onPressed: onClose,
              ),
            ),
            ?center,
            Hero(
              tag: VideoEditorConstants.heroToolbarTrailingId,
              child: DivineIconButton(
                icon: doneIcon,
                semanticLabel: doneSemanticLabel,
                size: .small,
                onPressed: onDone,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
