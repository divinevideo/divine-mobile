import 'package:meta/meta.dart';

/// A user the author picked from the caption's mention autocomplete.
///
/// The caption keeps the human-readable `@display` the author saw, and this
/// record remembers which account it meant. Publishing needs that: two people
/// can share a display name, and resolving the typed text alone cannot tell
/// them apart, so an ambiguous mention would silently produce no `p` tag.
///
/// [start] and [end] are offsets into the draft description at the moment of
/// selection. They are a hint, not a contract — the author keeps editing after
/// picking, so the publisher falls back to locating `@display` in the text and
/// drops the mention when it is no longer there.
@immutable
class CaptionMention {
  const CaptionMention({
    required this.display,
    required this.pubkey,
    this.start,
    this.end,
  });

  /// Returns null when [json] carries no usable display/pubkey pair, so a
  /// draft written by a newer build cannot break restore on an older one.
  static CaptionMention? tryFromJson(Map<String, dynamic> json) {
    final display = json['display'];
    final pubkey = json['pubkey'];
    if (display is! String || display.isEmpty) return null;
    if (pubkey is! String || pubkey.isEmpty) return null;

    return CaptionMention(
      display: display,
      pubkey: pubkey,
      start: _intOrNull(json['start']),
      end: _intOrNull(json['end']),
    );
  }

  static List<CaptionMention> listFromJson(Object? raw) {
    if (raw is! List) return const [];
    return raw
        .whereType<Map<dynamic, dynamic>>()
        .map(
          (mention) =>
              CaptionMention.tryFromJson(Map<String, dynamic>.from(mention)),
        )
        .nonNulls
        .toList(growable: false);
  }

  static int? _intOrNull(Object? value) => value is int ? value : null;

  /// Label shown in the caption after the `@`, without the `@` itself.
  final String display;

  /// Hex public key of the mentioned account.
  final String pubkey;

  /// Offset of the `@` in the description when the mention was picked.
  final int? start;

  /// Offset just past the mention in the description when it was picked.
  final int? end;

  Map<String, dynamic> toJson() => {
    'display': display,
    'pubkey': pubkey,
    if (start != null) 'start': start,
    if (end != null) 'end': end,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CaptionMention &&
          display == other.display &&
          pubkey == other.pubkey &&
          start == other.start &&
          end == other.end;

  @override
  int get hashCode => Object.hash(display, pubkey, start, end);

  @override
  String toString() =>
      'CaptionMention(display: $display, pubkey: $pubkey, '
      'start: $start, end: $end)';
}
