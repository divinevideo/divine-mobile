import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';

/// Builds the platform toolbar with Apple replacements tied to checked text.
Widget buildSpellCheckSuggestionsToolbar(
  BuildContext context,
  EditableTextState state,
) {
  if (defaultTargetPlatform != TargetPlatform.iOS &&
      defaultTargetPlatform != TargetPlatform.macOS) {
    return SpellCheckSuggestionsToolbar.editableText(editableTextState: state);
  }

  final checkedText = state.spellCheckResults?.spellCheckedText;
  final value = state.currentTextEditingValue;
  final span = state.findSuggestionSpanAtCursorIndex(
    value.selection.baseOffset,
  );
  final range = span?.range;
  final canReplace =
      checkedText == value.text &&
      range != null &&
      range.isValid &&
      range.isNormalized &&
      range.end <= value.text.length;

  // Native results may arrive after another edit. The Cupertino callback keeps
  // its original range but applies it to the current value, so both the result
  // and the eventual button press must still refer to the checked text.
  final items = canReplace
      ? CupertinoSpellCheckSuggestionsToolbar.editableText(
          editableTextState: state,
        ).buttonItems
      : <ContextMenuButtonItem>[];
  return CupertinoSpellCheckSuggestionsToolbar(
    anchors: state.contextMenuAnchors,
    buttonItems: [
      for (final item in items)
        ContextMenuButtonItem(
          label: item.label,
          onPressed: item.onPressed == null
              ? null
              : () {
                  if (!state.mounted) return;
                  if (state.currentTextEditingValue.text != checkedText ||
                      state.widget.readOnly ||
                      state.widget.obscureText) {
                    state.hideToolbar();
                    return;
                  }
                  item.onPressed!();
                },
        ),
    ],
  );
}
