// ABOUTME: Bottom sheet listing every caption font, each rendered in its own
// ABOUTME: face; resolves with the chosen font index.

import 'package:divine_ui/divine_ui.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/constants/video_editor_constants.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/widgets/video_editor/text_editor/video_editor_text_extensions.dart';

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
    buildScrollBody: (scrollController) => ListView.builder(
      controller: scrollController,
      padding: EdgeInsets.only(
        bottom: MediaQuery.viewPaddingOf(context).bottom,
      ),
      itemCount: VideoEditorConstants.textFonts.length,
      itemBuilder: (context, index) => _FontListItem(
        index: index,
        selected: index == selectedIndex,
        onTap: () => Navigator.of(context).pop(index),
      ),
    ),
  );
}

class _FontListItem extends StatelessWidget {
  const _FontListItem({
    required this.index,
    required this.selected,
    required this.onTap,
  });

  final int index;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final font = VideoEditorConstants.textFonts[index];
    return Semantics(
      button: true,
      selected: selected,
      value: font.localizedDisplayName(l10n),
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  font.localizedDisplayName(l10n),
                  overflow: TextOverflow.ellipsis,
                  style: font(
                    fontSize: 24,
                    color: selected
                        ? context.vineColors.primaryText
                        : context.vineColors.onSurfaceVariant,
                  ),
                ),
              ),
              if (selected)
                DivineIcon(
                  icon: DivineIconName.check,
                  color: context.vineColors.accentPositive,
                  size: 28,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
