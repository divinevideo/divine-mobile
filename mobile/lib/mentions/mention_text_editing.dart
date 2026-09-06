import 'package:openvine/models/caption_mention.dart';

/// The result of inserting a picked mention into a text field.
typedef MentionInsertion = ({
  /// Full field text after the insertion.
  String text,

  /// Where the caret belongs afterwards.
  int selection,

  /// Offset of the inserted `@`.
  int start,

  /// Offset just past the inserted `@display`, excluding the trailing space.
  int end,
});

/// The mention being typed immediately before [cursor], without the `@`.
///
/// Returns null when the caret is not inside a mention. A query is active from
/// the nearest `@` before the caret up to the caret itself, and ends at the
/// first space or newline — the same rule the comment composer has always
/// used, so a token like `OG-AB` or `st.allison` stays one query.
String? activeMentionQuery(String text, int cursor) {
  if (cursor < 0 || cursor > text.length) return null;

  final beforeCursor = text.substring(0, cursor);
  final atIndex = beforeCursor.lastIndexOf('@');
  if (atIndex < 0) return null;

  final query = beforeCursor.substring(atIndex + 1);
  if (query.contains(' ') || query.contains('\n')) return null;

  return query;
}

/// Replaces the mention being typed before [cursor] with `@display `.
///
/// Returns null when there is no `@` before the caret to replace.
MentionInsertion? applyMentionSelection({
  required String text,
  required int cursor,
  required String display,
}) {
  if (cursor < 0 || cursor > text.length) return null;

  final beforeCursor = text.substring(0, cursor);
  final atIndex = beforeCursor.lastIndexOf('@');
  if (atIndex < 0) return null;

  final mention = '@$display ';
  final nextText =
      text.substring(0, atIndex) + mention + text.substring(cursor);

  return (
    text: nextText,
    selection: atIndex + mention.length,
    start: atIndex,
    end: atIndex + mention.length - 1,
  );
}

/// Drops mentions the author has since edited out of [text].
///
/// A picked mention is only meaningful while its `@display` is still written
/// somewhere in the caption. Publishing already ignores a mention it cannot
/// locate, so this keeps the stored draft honest rather than changing what is
/// published — without it, every pick-then-delete would accumulate forever.
List<CaptionMention> pruneCaptionMentions(
  List<CaptionMention> mentions,
  String text,
) {
  if (mentions.isEmpty) return mentions;
  final kept = mentions
      .where((mention) => text.contains('@${mention.display}'))
      .toList(growable: false);
  return kept.length == mentions.length ? mentions : kept;
}
