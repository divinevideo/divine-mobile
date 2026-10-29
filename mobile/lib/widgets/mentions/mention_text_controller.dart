import 'package:material_ui/material_ui.dart';
import 'package:openvine/mentions/mention_text_editing.dart';
import 'package:openvine/services/mention_resolution_service.dart';

/// Keeps picked accounts attached to their exact token as a draft is edited.
class MentionTextController extends TextEditingController {
  final _bindings = <MentionBinding>[];

  List<MentionBinding> get bindings => List.unmodifiable(_bindings);

  bool selectMention({required String pubkey, required String display}) {
    final insertion = applyMentionSelection(
      text: text,
      cursor: selection.baseOffset,
      display: display,
    );
    if (insertion == null) return false;
    value = TextEditingValue(
      text: insertion.text,
      selection: TextSelection.collapsed(offset: insertion.selection),
    );
    _bindings.add(
      MentionBinding(
        display: display,
        pubkey: pubkey,
        start: insertion.start,
        end: insertion.end,
      ),
    );
    return true;
  }

  @override
  set value(TextEditingValue next) {
    final previous = super.value;
    if (previous.text != next.text && _bindings.isNotEmpty) {
      final edit = _editRange(previous, next);
      final (start, oldEnd, newEnd) = edit;
      final delta = newEnd - oldEnd;
      final updated = <MentionBinding>[];
      for (final binding in _bindings) {
        var tokenStart = binding.start!;
        var tokenEnd = binding.end!;
        if (oldEnd <= tokenStart) {
          tokenStart += delta;
          tokenEnd += delta;
        } else if (start < tokenEnd) {
          continue;
        }
        if (tokenStart >= 0 &&
            tokenEnd <= next.text.length &&
            next.text.substring(tokenStart, tokenEnd) ==
                '@${binding.display}' &&
            isMentionTokenBoundary(next.text, tokenEnd)) {
          updated.add(
            MentionBinding(
              display: binding.display,
              pubkey: binding.pubkey,
              start: tokenStart,
              end: tokenEnd,
            ),
          );
        }
      }
      _bindings
        ..clear()
        ..addAll(updated);
    }
    super.value = next;
  }
}

/// Uses the platform's selection to disambiguate edits of repeated tokens.
(int, int, int) _editRange(TextEditingValue previous, TextEditingValue next) {
  final oldText = previous.text;
  final newText = next.text;
  (int, int, int)? replacement(int start, int end) {
    final newEnd = end + newText.length - oldText.length;
    if (start < 0 ||
        end > oldText.length ||
        newEnd < start ||
        newEnd > newText.length) {
      return null;
    }
    if (oldText.substring(0, start) != newText.substring(0, start) ||
        oldText.substring(end) != newText.substring(newEnd)) {
      return null;
    }
    if (next.selection.baseOffset != newEnd) return null;
    return (start, end, newEnd);
  }

  if (previous.selection.isValid &&
      next.selection.isValid &&
      next.selection.isCollapsed) {
    if (!previous.selection.isCollapsed) {
      final edit = replacement(
        previous.selection.start,
        previous.selection.end,
      );
      if (edit != null) return edit;
    } else {
      final cursor = previous.selection.baseOffset;
      final delta = newText.length - oldText.length;
      final start = delta < 0 && next.selection.baseOffset < cursor
          ? next.selection.baseOffset
          : cursor;
      final end = delta < 0 ? start - delta : cursor;
      final edit = replacement(start, end);
      if (edit != null) return edit;
    }
  }

  var prefix = 0;
  final shorter = oldText.length < newText.length
      ? oldText.length
      : newText.length;
  while (prefix < shorter && oldText[prefix] == newText[prefix]) {
    prefix++;
  }
  var suffix = 0;
  while (suffix < shorter &&
      oldText[oldText.length - suffix - 1] ==
          newText[newText.length - suffix - 1]) {
    suffix++;
  }
  // An ambiguous edit invalidates tokens across every possible changed range.
  // Tokens outside that range still have a single, reliable offset mapping.
  final start = prefix + suffix > shorter ? shorter - suffix : prefix;
  final oldEnd = prefix + suffix > shorter
      ? prefix +
            (oldText.length > newText.length
                ? oldText.length - newText.length
                : 0)
      : oldText.length - suffix;
  return (start, oldEnd, oldEnd + newText.length - oldText.length);
}
