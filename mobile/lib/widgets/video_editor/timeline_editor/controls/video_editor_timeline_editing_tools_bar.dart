import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/widgets/video_editor/main_editor/video_editor_main_actions_sheet.dart';

/// Opens the editing tools sheet while nothing in the timeline is selected.
///
/// It sits in the same slot as the clip and overlay bars and overlays the
/// timeline like them, so swapping one for the other never resizes the
/// preview above. Unlike them it is only as wide as its button, so the strips
/// on either side stay visible and tappable.
class TimelineEditingToolsBar extends StatelessWidget {
  const TimelineEditingToolsBar({super.key});

  static const _borderRadius = BorderRadius.all(Radius.circular(20));

  @override
  Widget build(BuildContext context) {
    return Center(
      heightFactor: 1,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: context.vineColors.surfaceContainerHigh,
              borderRadius: _borderRadius,
              boxShadow: [
                BoxShadow(
                  // A cast shadow, not a surface: stays dark in both modes.
                  color: VineTheme.backgroundColor.withValues(alpha: 0.4),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: DivineButton(
              label: context.l10n.videoActionEdit,
              leadingIcon: .slidersHorizontal,
              trailingIcon: .caretUp,
              type: .quiet,
              maxLines: 2,
              onPressed: () => VideoEditorMainActionsSheet.show(context),
            ),
          ),
        ),
      ),
    );
  }
}
