// ABOUTME: Keeps each picked chat account attached to its own edited text range.
import 'package:openvine/mentions/mention_text_editing.dart';
import 'package:openvine/models/caption_mention.dart';

/// Shifts unaffected bindings and drops any token touched by an edit.
/// The caret disambiguates deletion of identical neighboring display names.
List<CaptionMention> updateChatMentionBindings({
  required String before,
  required String after,
  required int cursor,
  required List<CaptionMention> mentions,
}) {
  if (before == after) return List.of(mentions);
  var start = 0;
  while (start < before.length &&
      start < after.length &&
      before[start] == after[start]) {
    start++;
  }
  if (cursor >= 0 && cursor <= after.length && cursor < start) start = cursor;
  var oldEnd = before.length;
  var newEnd = after.length;
  while (oldEnd > start &&
      newEnd > start &&
      before[oldEnd - 1] == after[newEnd - 1]) {
    oldEnd--;
    newEnd--;
  }
  final delta = newEnd - oldEnd;
  final kept = <CaptionMention>[];
  for (final mention in mentions) {
    final previousStart = mention.start;
    final previousEnd = mention.end;
    if (previousStart == null || previousEnd == null) continue;
    int nextStart;
    int nextEnd;
    if (previousEnd <= start) {
      nextStart = previousStart;
      nextEnd = previousEnd;
    } else if (previousStart >= oldEnd) {
      nextStart = previousStart + delta;
      nextEnd = previousEnd + delta;
    } else {
      continue;
    }
    if (nextStart < 0 ||
        nextEnd > after.length ||
        after.substring(nextStart, nextEnd) != '@${mention.display}' ||
        !isMentionTokenBoundary(after, nextEnd)) {
      continue;
    }
    kept.add(
      CaptionMention(
        display: mention.display,
        pubkey: mention.pubkey,
        start: nextStart,
        end: nextEnd,
      ),
    );
  }
  return kept;
}
