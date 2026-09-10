// ABOUTME: Edit action button for the video overlay action column.
// ABOUTME: Only rendered for own videos; opens the video edit dialog.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:models/models.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/widgets/show_edit_dialog_for_video.dart';
import 'package:openvine/widgets/video_feed_item/actions/video_action_button.dart';
import 'package:unified_logger/unified_logger.dart';

/// Edit action button shown at the top of the action column on the
/// owner's own videos.
///
/// Visibility is decided by [VideoOverlayActionColumn.build] (feature-flag
/// + ownership gate); this widget assumes the button should render and
/// opens the same edit dialog as the app bar's pencil affordance.
class EditActionButton extends StatelessWidget {
  const EditActionButton({
    required this.video,
    super.key,
    this.onInteracted,
  });

  final VideoEvent video;
  final VoidCallback? onInteracted;

  @override
  Widget build(BuildContext context) {
    return VideoActionButton(
      icon: DivineIconName.pencilSimpleLine,
      semanticIdentifier: 'edit_button',
      semanticLabel: context.l10n.videoActionEdit,
      labelWhenZero: context.l10n.videoActionEditLabel,
      onPressed: () {
        onInteracted?.call();
        Log.info(
          '✏️ Edit button tapped for ${video.id}',
          name: 'EditActionButton',
          category: LogCategory.ui,
        );
        showEditDialogForVideo(context, video);
      },
    );
  }
}
