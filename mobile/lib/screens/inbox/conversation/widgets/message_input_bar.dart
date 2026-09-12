// ABOUTME: Text input bar for composing and sending messages.
// ABOUTME: Matches Figma "commenting v2" component with send button.
// ABOUTME: Selection context menu adds wrap/unwrap actions for inline
// ABOUTME: markdown (bold / italic / strike / code) — #4621.

import 'package:divine_ui/divine_ui.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/l10n/l10n.dart';

/// Markdown delimiters the selection toolbar can wrap selected text
/// with. Kept package-private so the bar's tests can target the
/// individual handlers by delimiter.
@visibleForTesting
const String boldDelimiter = '**';
@visibleForTesting
const String italicDelimiter = '_';
@visibleForTesting
const String strikeDelimiter = '~~';
@visibleForTesting
const String codeDelimiter = '`';

/// Longest message the composer accepts, in characters.
///
/// This is an affordance, not the correctness bound. `maxLength` truncates by
/// grapheme cluster, and one cluster can be many bytes — a ZWJ emoji sequence
/// runs past 25 — so a character limit cannot bound the UTF-8 size that NIP-44
/// actually constrains. `maxDmRumorBytes` in `dm_repository` is what guarantees
/// the send can be built, and it bounds the serialized rumor so tags count too;
/// this stops the ordinary long paste at the keyboard instead of letting it
/// fail after the fact (#7331).
@visibleForTesting
const int dmComposerMaxCharacters = 10000;

/// How close to [dmComposerMaxCharacters] the counter starts showing.
///
/// A chat composer with a permanent counter reads as a form, and the number is
/// noise until it is nearly actionable.
@visibleForTesting
const int dmComposerCounterThreshold = 500;

/// Hides the character counter until the message is within
/// [dmComposerCounterThreshold] of the limit.
///
/// A builder is Flutter's own contract for `TextField.buildCounter`, and
/// returning `null` is how the counter is hidden — the widget itself is a
/// class, per the widgets-over-methods rule.
Widget? _buildCounter(
  BuildContext context, {
  required int currentLength,
  required int? maxLength,
  required bool isFocused,
}) {
  if (maxLength == null) return null;
  final remaining = maxLength - currentLength;
  if (remaining > dmComposerCounterThreshold) return null;
  return _RemainingCounter(remaining: remaining);
}

/// Message input bar at the bottom of the conversation screen.
///
/// Features a text field with surfaceContainer background, 20px radius,
/// and a green send button that appears when text is entered.
class MessageInputBar extends StatefulWidget {
  const MessageInputBar({required this.onSend, this.controller, super.key});

  final ValueChanged<String> onSend;

  /// Optional externally-owned controller.
  ///
  /// The bar clears the field the moment [onSend] fires, before any outcome is
  /// known. A caller that can learn the send was refused — an oversized rumor
  /// leaves no queue row and so no failed bubble (#7331) — passes its own
  /// controller so it can put the text back rather than lose it.
  final TextEditingController? controller;

  @override
  State<MessageInputBar> createState() => _MessageInputBarState();
}

class _MessageInputBarState extends State<MessageInputBar> {
  TextEditingController? _internalController;
  bool _hasText = false;

  TextEditingController get _controller =>
      widget.controller ?? (_internalController ??= TextEditingController());

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    // Only the internally-created controller is ours to dispose; an external
    // one outlives this widget.
    _controller.removeListener(_onTextChanged);
    _internalController?.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    final hasText = _controller.text.trim().isNotEmpty;
    if (hasText != _hasText) {
      setState(() => _hasText = hasText);
    }
  }

  void _handleSend() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    widget.onSend(text);
    _controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: context.vineColors.surface,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: SafeArea(
        top: false,
        child: Container(
          constraints: const BoxConstraints(minHeight: 48),
          decoration: BoxDecoration(
            color: context.vineColors.surfaceContainer,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            // Anchor send button to pill bottom as the field grows.
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // Text input
              Expanded(
                // Field honours font scaling (#4620): no withNoTextScaling.
                child: TextField(
                  controller: _controller,
                  style: VineTheme.bodyLargeFont(
                    color: context.vineColors.primaryText,
                  ),
                  cursorColor: context.vineColors.accentPositive,
                  keyboardType: TextInputType.multiline,
                  // Return = newline; send via button only (#4620).
                  textInputAction: TextInputAction.newline,
                  minLines: 1,
                  maxLines: 5,
                  maxLength: dmComposerMaxCharacters,
                  buildCounter: _buildCounter,
                  contextMenuBuilder: _buildContextMenu,
                  decoration: InputDecoration(
                    hintText: context.l10n.dmMessageInputHint,
                    hintStyle: VineTheme.bodyLargeFont(
                      color: context.vineColors.onSurfaceMuted,
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                ),
              ),
              // Send button
              if (_hasText)
                Padding(
                  padding: const EdgeInsetsDirectional.only(end: 4, bottom: 4),
                  child: Semantics(
                    identifier: 'dm_message_send_button',
                    button: true,
                    label: context.l10n.dmMessageSendLabel,
                    child: SizedBox.square(
                      dimension: 40,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: VineTheme.primary,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: IconButton(
                          onPressed: _handleSend,
                          padding: EdgeInsets.zero,
                          icon: DivineIcon(
                            icon: DivineIconName.arrowUp,
                            color: context.vineColors.surface,
                            size: 20,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// Selection toolbar with the platform's default items (cut / copy /
  /// paste / select all) plus four markdown formatting actions when
  /// the user has a non-empty selection. Each action wraps the
  /// selection with the corresponding markdown delimiter, or unwraps
  /// it if the selection is already enclosed by that delimiter.
  Widget _buildContextMenu(
    BuildContext context,
    EditableTextState editableTextState,
  ) {
    final items = <ContextMenuButtonItem>[];
    final selection = editableTextState.textEditingValue.selection;
    if (selection.isValid && !selection.isCollapsed) {
      final l10n = context.l10n;
      items.addAll([
        ContextMenuButtonItem(
          label: l10n.dmFormatBold,
          onPressed: () => _wrapSelection(editableTextState, boldDelimiter),
        ),
        ContextMenuButtonItem(
          label: l10n.dmFormatItalic,
          onPressed: () => _wrapSelection(editableTextState, italicDelimiter),
        ),
        ContextMenuButtonItem(
          label: l10n.dmFormatStrikethrough,
          onPressed: () => _wrapSelection(editableTextState, strikeDelimiter),
        ),
        ContextMenuButtonItem(
          label: l10n.dmFormatCode,
          onPressed: () => _wrapSelection(editableTextState, codeDelimiter),
        ),
      ]);
    }
    items.addAll(editableTextState.contextMenuButtonItems);
    return AdaptiveTextSelectionToolbar.buttonItems(
      anchors: editableTextState.contextMenuAnchors,
      buttonItems: items,
    );
  }

  /// Wraps the current selection in [editableTextState] with
  /// [delimiter] on both sides — or, if the selection is already
  /// surrounded by that delimiter, unwraps it. Updates the underlying
  /// controller via [EditableTextState.userUpdateTextEditingValue] so
  /// the platform's undo / redo stack tracks the change.
  void _wrapSelection(EditableTextState state, String delimiter) {
    final value = state.textEditingValue;
    final selection = value.selection;
    if (!selection.isValid || selection.isCollapsed) return;

    final text = value.text;
    final start = selection.start;
    final end = selection.end;
    final selected = text.substring(start, end);

    final before = text.substring(0, start);
    final after = text.substring(end);

    final hasDelimiterBefore =
        start >= delimiter.length &&
        text.substring(start - delimiter.length, start) == delimiter;
    final hasDelimiterAfter =
        end + delimiter.length <= text.length &&
        text.substring(end, end + delimiter.length) == delimiter;

    final TextEditingValue newValue;
    if (hasDelimiterBefore && hasDelimiterAfter) {
      // Unwrap: drop the surrounding delimiters, keep selection on
      // the original content.
      final newText =
          before.substring(0, before.length - delimiter.length) +
          selected +
          after.substring(delimiter.length);
      newValue = TextEditingValue(
        text: newText,
        selection: TextSelection(
          baseOffset: start - delimiter.length,
          extentOffset: end - delimiter.length,
        ),
      );
    } else {
      // Wrap: insert delimiters around the selection, then keep the
      // (now-wrapped) text selected so a second tap can unwrap.
      final newText = '$before$delimiter$selected$delimiter$after';
      newValue = TextEditingValue(
        text: newText,
        selection: TextSelection(
          baseOffset: start + delimiter.length,
          extentOffset: end + delimiter.length,
        ),
      );
    }

    state
      ..userUpdateTextEditingValue(newValue, SelectionChangedCause.toolbar)
      ..hideToolbar();
  }
}

/// Characters left before the composer stops accepting input.
///
/// Numerals only, so it needs no ARB key and reads the same in every locale.
class _RemainingCounter extends StatelessWidget {
  const _RemainingCounter({required this.remaining});

  final int remaining;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.only(top: 4, end: 4),
      child: Text(
        '$remaining',
        style: VineTheme.labelSmallFont(
          color: remaining <= 0
              ? context.vineColors.onErrorContainer
              : context.vineColors.onSurfaceMuted,
        ),
      ),
    );
  }
}
