// ABOUTME: Info action button for video feed overlay.
// ABOUTME: Opens the expanded metadata bottom sheet showing video details.

import 'package:divine_ui/divine_ui.dart';
import 'package:material_ui/material_ui.dart';
import 'package:models/models.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/widgets/video_feed_item/actions/video_action_button.dart';
import 'package:openvine/widgets/video_feed_item/metadata/metadata_expanded_sheet.dart';
import 'package:unified_logger/unified_logger.dart';

/// Info action button for the video overlay.
///
/// Opens the expanded metadata sheet showing title, stats, creator, tags,
/// collaborators, inspired-by, reposted-by, and sounds.
///
/// Built on top of [VideoActionButton] to share the exact 48x48 tap target,
/// 24 icon + 8 px gap + label/small caption layout, and Figma-spec drop
/// shadows with the other buttons in the column.
class MoreActionButton extends StatelessWidget {
  const MoreActionButton({required this.video, this.onInteracted, super.key});

  final VideoEvent video;
  final VoidCallback? onInteracted;

  @override
  Widget build(BuildContext context) {
    return VideoActionButton(
      icon: DivineIconName.info,
      semanticIdentifier: 'more_button',
      semanticLabel: context.l10n.videoActionMoreOptions,
      caption: context.l10n.videoActionAboutLabel,
      onPressed: () {
        onInteracted?.call();
        Log.info(
          'More button tapped for ${video.id}',
          name: 'MoreActionButton',
          category: LogCategory.ui,
        );
        MetadataExpandedSheet.show(context, video);
      },
    );
  }
}
