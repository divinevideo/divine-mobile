import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';

/// Builds the platform toolbar with replacements tied to the checked text.
Widget buildSpellCheckSuggestionsToolbar(
  BuildContext context,
  EditableTextState state,
) {
  final isApple =
      defaultTargetPlatform == TargetPlatform.iOS ||
      defaultTargetPlatform == TargetPlatform.macOS;
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

  // Flutter keeps the last results when the text is cleared from code or
  // emptied, and results can arrive after another edit. Both platform toolbars
  // apply the result's range to the current value, so the result and the
  // eventual button press must still refer to the checked text.
  final items = !canReplace
      ? null
      : isApple
      ? CupertinoSpellCheckSuggestionsToolbar.buildButtonItems(state)
      : SpellCheckSuggestionsToolbar.buildButtonItems(state);
  final buttonItems = [
    for (final item in items ?? const <ContextMenuButtonItem>[])
      if (item.onPressed case final onPressed?)
        item.copyWith(
          onPressed: () {
            if (!state.mounted) return;
            if (state.currentTextEditingValue.text != checkedText ||
                state.widget.readOnly ||
                state.widget.obscureText) {
              state.hideToolbar();
              return;
            }
            onPressed();
          },
        )
      else
        item,
  ];

  if (isApple) {
    return CupertinoSpellCheckSuggestionsToolbar(
      anchors: state.contextMenuAnchors,
      buttonItems: buttonItems,
    );
  }
  return SpellCheckSuggestionsToolbar(
    anchor: SpellCheckSuggestionsToolbar.getToolbarAnchor(
      state.contextMenuAnchors,
    ),
    buttonItems: buttonItems,
  );
}
