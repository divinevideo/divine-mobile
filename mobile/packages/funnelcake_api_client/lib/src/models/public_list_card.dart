import 'package:meta/meta.dart';

/// The NIP-51 list kinds FunnelCake indexes for list search.
enum PublicListKind {
  /// People lists (kind 30000).
  people(30000),

  /// Curated video lists (kind 30005).
  videos(30005);

  const PublicListKind(this.value);

  /// The Nostr event kind.
  final int value;
}

/// One public NIP-51 list as FunnelCake's list index summarizes it, the shape
/// `GET /api/v2/search/lists` returns.
///
/// A card is a summary, not the list: it carries the counts and a few
/// previews, never the list's full video references or member set.
@immutable
class PublicListCard {
  /// Creates a [PublicListCard].
  const PublicListCard({
    required this.kind,
    required this.pubkey,
    required this.dTag,
    required this.title,
    required this.updatedAt,
    this.description = '',
    this.itemCount = 0,
    this.memberCount = 0,
    this.videoCount = 0,
    this.loopSum = 0,
    this.members = const [],
    this.thumbnails = const [],
  });

  /// Parses one card of a list search answer.
  ///
  /// Throws a [FormatException] when the card lacks its kind, owner or `d`
  /// tag, which together address the list.
  factory PublicListCard.fromJson(Map<String, dynamic> json) {
    final kind = json['kind'];
    final pubkey = json['pubkey'];
    final dTag = json['d_tag'];
    if (kind is! int || pubkey is! String || dTag is! String) {
      throw const FormatException('List card has no kind, pubkey or d_tag');
    }
    return PublicListCard(
      kind: kind,
      pubkey: pubkey,
      dTag: dTag,
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      itemCount: _count(json['item_count']),
      memberCount: _count(json['member_count']),
      videoCount: _count(json['video_count']),
      loopSum: _count(json['loop_sum']),
      members: _strings(json['members']),
      thumbnails: _strings(json['thumbnails']),
      updatedAt: _timestamp(json['updated_at']),
    );
  }

  /// The list's Nostr kind, 30000 or 30005; see [PublicListKind].
  final int kind;

  /// The list owner's hex pubkey.
  final String pubkey;

  /// The list's `d` tag.
  final String dTag;

  /// The list's title, empty when its event has none.
  final String title;

  /// The list's description, empty when its event has none.
  final String description;

  /// The items the list holds: video references for a video list, members
  /// for a people list.
  final int itemCount;

  /// A people list's public members; 0 for a video list.
  final int memberCount;

  /// Videos a people list's members posted; 0 for a video list.
  final int videoCount;

  /// The loops of the list's videos, or of its members' videos.
  final int loopSum;

  /// Up to five member pubkeys of a people list, in tag order.
  ///
  /// A preview: it can hold fewer than [memberCount] even when that is five
  /// or more, since hidden accounts are left out.
  final List<String> members;

  /// Up to five thumbnail URLs of a video list's leading videos, in tag order.
  ///
  /// Bare URLs: the videos behind them are not named, so a viewer's filters
  /// cannot be applied to them.
  final List<String> thumbnails;

  /// When the list revision this card was built from was published.
  final DateTime updatedAt;

  static int _count(Object? value) => value is num ? value.toInt() : 0;

  static List<String> _strings(Object? value) => value is List
      ? List.unmodifiable(value.whereType<String>())
      : const <String>[];

  // Production sends Unix seconds; the API schema documents an ISO date.
  static DateTime _timestamp(Object? value) {
    if (value is num) {
      return DateTime.fromMillisecondsSinceEpoch(
        value.toInt() * 1000,
        isUtc: true,
      );
    }
    if (value is String) {
      final parsed = DateTime.tryParse(value);
      if (parsed != null) return parsed.toUtc();
    }
    return DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
  }
}

/// One page of a FunnelCake list search, as returned by
/// `GET /api/v2/search/lists`.
@immutable
class ListSearchResponse {
  /// Creates a [ListSearchResponse].
  const ListSearchResponse({required this.cards, this.nextCursor});

  /// Parses the `{data, pagination}` envelope of a v2 list search.
  ///
  /// A malformed card is skipped. Throws a [FormatException] when [json]
  /// holds no `data` list.
  factory ListSearchResponse.fromJson(Map<String, dynamic> json) {
    final data = json['data'];
    if (data is! List) {
      throw const FormatException('List search response has no data list');
    }
    final pagination = json['pagination'];
    final hasMore =
        pagination is Map<String, dynamic> && pagination['has_more'] == true;
    final cursor = pagination is Map<String, dynamic>
        ? pagination['next_cursor']?.toString()
        : null;
    final cards = <PublicListCard>[];
    for (final item in data) {
      if (item is! Map<String, dynamic>) continue;
      try {
        cards.add(PublicListCard.fromJson(item));
      } on FormatException {
        // One unaddressable card must not cost the rest of the page.
        continue;
      }
    }
    return ListSearchResponse(
      cards: List.unmodifiable(cards),
      nextCursor: hasMore && cursor != null && cursor.isNotEmpty
          ? cursor
          : null,
    );
  }

  /// The lists on this page, best match first.
  final List<PublicListCard> cards;

  /// The cursor of the next page, or `null` when this page is the last.
  final String? nextCursor;

  /// Whether a page follows this one.
  bool get hasMore => nextCursor != null;
}
