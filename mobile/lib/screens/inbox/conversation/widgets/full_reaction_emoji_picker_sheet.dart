// ABOUTME: Full emoji picker bottom sheet for DM custom reactions. Wraps
// ABOUTME: pro_image_editor's EmojiEditor in a Divine dark-styled sheet.

import 'package:divine_ui/divine_ui.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:pro_image_editor/pro_image_editor.dart';

/// Bottom sheet that lets the user pick any emoji as a DM reaction.
///
/// Wraps [EmojiEditor] from `pro_image_editor` — already a direct
/// dependency for the video editor — so the full emoji set is available
/// beyond the six quick reactions, without adding a new picker package.
/// The picked emoji flows through the same [ConversationReactionToggled]
/// path as a quick reaction.
class FullReactionEmojiPickerSheet {
  /// Visible height of the picker body, excluding the keyboard inset.
  static const double _bodyHeight = 320;

  /// Picker styling for the active appearance mode.
  ///
  /// Paints every sub-surface — grid, search bar, category bar, and bottom
  /// action bar — with the sheet surface color so the picker reads as a
  /// single panel. The package defaults the search/category/emoji views to
  /// light grey, which would otherwise stand out against the sheet.
  /// [VineBottomSheet] supplies the drag handle, so the editor's own is off.
  static EmojiEditorStyle _emojiEditorStyleOf(BuildContext context) =>
      EmojiEditorStyle(
        backgroundColor: context.vineColors.surface,
        showDragHandle: false,
        searchViewConfig: SearchViewConfig(
          backgroundColor: context.vineColors.surface,
          buttonIconColor: context.vineColors.onSurface,
        ),
        bottomActionBarConfig: BottomActionBarConfig(
          backgroundColor: context.vineColors.surface,
          buttonColor: context.vineColors.surface,
          buttonIconColor: context.vineColors.onSurface,
          showBackspaceButton: false,
        ),
        categoryViewConfig: CategoryViewConfig(
          backgroundColor: context.vineColors.surface,
        ),
        emojiViewConfig: EmojiViewConfig(
          backgroundColor: context.vineColors.surface,
        ),
      );

  /// Maps the picker's category / search labels to localized strings.
  ///
  /// [I18nEmojiEditor] defaults to hardcoded English; this wires each label
  /// to its [AppLocalizations] value so the picker follows the app locale.
  @visibleForTesting
  static I18nEmojiEditor buildI18n(AppLocalizations l10n) => I18nEmojiEditor(
    search: l10n.emojiPickerSearchHint,
    categoryRecent: l10n.emojiCategoryRecent,
    categorySmileys: l10n.emojiCategorySmileys,
    categoryAnimals: l10n.emojiCategoryAnimals,
    categoryFood: l10n.emojiCategoryFood,
    categoryActivities: l10n.emojiCategoryActivities,
    categoryTravel: l10n.emojiCategoryTravel,
    categoryObjects: l10n.emojiCategoryObjects,
    categorySymbols: l10n.emojiCategorySymbols,
    categoryFlags: l10n.emojiCategoryFlags,
  );

  /// Shows the picker and resolves to the selected emoji, or `null` if the
  /// sheet was dismissed without a choice.
  static Future<String?> show({required BuildContext context}) async {
    final configs = ProImageEditorConfigs(
      i18n: I18n(emojiEditor: buildI18n(context.l10n)),
      emojiEditor: EmojiEditorConfigs(style: _emojiEditorStyleOf(context)),
    );

    final layer = await VineBottomSheet.show<EmojiLayer>(
      context: context,
      scrollable: false,
      showHeader: false,
      body: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: _bodyHeight + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: EmojiEditor(configs: configs),
      ),
    );
    return layer?.emoji;
  }
}
