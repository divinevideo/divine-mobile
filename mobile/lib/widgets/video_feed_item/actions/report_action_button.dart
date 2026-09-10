// ABOUTME: Report action button for video feed overlay.
// ABOUTME: Opens the report-content dialog for the current video.

import 'package:divine_ui/divine_ui.dart';
import 'package:material_ui/material_ui.dart';
import 'package:models/models.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/widgets/report_content_dialog.dart';
import 'package:openvine/widgets/video_feed_item/actions/video_action_button.dart';

/// Report action button for the video overlay action column.
///
/// Opens [ReportContentDialog] for the supplied [video] when tapped — the
/// same dialog that used to live behind the share sheet's "Report" entry.
class ReportActionButton extends StatelessWidget {
  const ReportActionButton({
    required this.video,
    super.key,
    this.onInteracted,
  });

  final VideoEvent video;
  final VoidCallback? onInteracted;

  @override
  Widget build(BuildContext context) {
    return VideoActionButton(
      icon: DivineIconName.flag,
      semanticIdentifier: 'report_button',
      semanticLabel: context.l10n.videoActionReport,
      labelWhenZero: context.l10n.videoActionReportLabel,
      onPressed: () {
        onInteracted?.call();
        ReportContentDialog.show(context, video: video);
      },
    );
  }
}
