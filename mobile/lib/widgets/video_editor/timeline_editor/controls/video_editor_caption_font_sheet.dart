// ABOUTME: Bottom sheet listing every caption font, grouped by category and
// ABOUTME: each rendered in its own face; resolves with the chosen font index.

import 'package:divine_ui/divine_ui.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/constants/video_editor_constants.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/widgets/video_editor/text_editor/video_editor_font_list.dart';

/// Shows the caption font picker seeded with [selectedIndex]; resolves with
/// the chosen index into [VideoEditorConstants.textFonts], or `null` when
/// dismissed.
Future<int?> showCaptionFontSheet(
  BuildContext context, {
  required int selectedIndex,
}) {
  return VineBottomSheet.show<int>(
    context: context,
    title: Text(
      context.l10n.videoEditorCaptionsCustomFont,
      style: VineTheme.titleMediumFont(color: context.vineColors.primaryText),
    ),
    // The Builder's context sits inside the sheet's route, so pop closes the
    // sheet even when the caller lives in a nested navigator.
    buildScrollBody: (scrollController) => Builder(
      builder: (sheetContext) => VideoEditorFontList(
        controller: scrollController,
        selectedIndex: selectedIndex,
        onSelected: (index) => Navigator.of(sheetContext).pop(index),
      ),
    ),
  );
}
