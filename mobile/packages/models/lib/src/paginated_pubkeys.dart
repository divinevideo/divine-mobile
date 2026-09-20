import 'package:meta/meta.dart';

/// A paginated list of pubkeys from the Funnelcake API.
///
/// Used for follower/following list responses which may be paginated.
@immutable
class PaginatedPubkeys {
  /// Creates a new [PaginatedPubkeys] instance.
  const PaginatedPubkeys({
    required this.pubkeys,
    this.total = 0,
    this.hasMore = false,
    this.nextCursor,
    this.appliedQuery,
  });

  /// Creates a [PaginatedPubkeys] from JSON response.
  ///
  /// Tolerates both the legacy shape and the post-funnelcake#238 envelope:
  /// - Legacy: `{"following": [...], "total": int, "has_more": bool}`
  ///   (key varies: `following`, `followers`, or `pubkeys`)
  /// - Envelope: `{"data": [...], "pagination": {"has_more": bool,
  ///   "next_cursor": string}}`
  ///
  /// Entries may be bare pubkey strings or objects carrying a `pubkey` key
  /// alongside other fields — the engagement endpoints
  /// (`/api/videos/{id}/likers`, `/reposters`) return
  /// `{"pubkey": …, "created_at": …, "event_id": …}`. Objects without a
  /// string `pubkey` are dropped rather than stringified, so a shape change
  /// surfaces as a short list instead of rows of `{pubkey: …}` garbage.
  factory PaginatedPubkeys.fromJson(Map<String, dynamic> json) {
    final pagination = json['pagination'] as Map<String, dynamic>?;

    // Prefer the envelope `data` key; fall back to endpoint-specific keys.
    final pubkeysData =
        json['data'] as List<dynamic>? ??
        json['following'] as List<dynamic>? ??
        json['followers'] as List<dynamic>? ??
        json['pubkeys'] as List<dynamic>? ??
        <dynamic>[];

    final hasMore =
        json['has_more'] as bool? ?? pagination?['has_more'] as bool? ?? false;
    // Normalise '' to null: an empty cursor would be re-sent forever, each
    // request answering with the same page.
    final rawCursor = pagination?['next_cursor'] as String?;
    final nextCursor = (rawCursor == null || rawCursor.isEmpty)
        ? null
        : rawCursor;

    final pubkeys = <String>[];
    for (final entry in pubkeysData) {
      if (entry is Map<String, dynamic>) {
        final pubkey = entry['pubkey'];
        if (pubkey is String && pubkey.isNotEmpty) pubkeys.add(pubkey);
        continue;
      }
      pubkeys.add(entry.toString());
    }

    return PaginatedPubkeys(
      pubkeys: pubkeys,
      total: json['total'] as int? ?? pubkeys.length,
      hasMore: hasMore,
      nextCursor: nextCursor,
      appliedQuery: json['query'] as String?,
    );
  }

  /// An empty [PaginatedPubkeys] with no results.
  static const empty = PaginatedPubkeys(pubkeys: []);

  /// The list of public keys.
  final List<String> pubkeys;

  /// Total number of results available (may exceed [pubkeys] length).
  final int total;

  /// Whether more results are available for pagination.
  final bool hasMore;

  /// Opaque cursor for the next page, or `null` when there is none.
  ///
  /// [hasMore] without this is a dead end — the caller knows more exists and
  /// cannot ask for it. Pass it back as the `cursor` query parameter. Absent
  /// on the legacy non-envelope shape, which paginates by `offset` instead.
  final String? nextCursor;

  /// The search filter the server reports having applied, if any.
  ///
  /// `null` means the response is unfiltered — including on a deployment that
  /// predates the filter parameter, which ignores the unknown query key and
  /// answers with the plain page. Never read an unfiltered page as a set of
  /// search matches: check this first.
  final String? appliedQuery;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! PaginatedPubkeys) return false;
    if (other.total != total || other.hasMore != hasMore) return false;
    if (other.nextCursor != nextCursor) return false;
    if (other.appliedQuery != appliedQuery) return false;
    if (other.pubkeys.length != pubkeys.length) return false;
    for (var i = 0; i < pubkeys.length; i++) {
      if (other.pubkeys[i] != pubkeys[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(
    Object.hashAll(pubkeys),
    total,
    hasMore,
    nextCursor,
    appliedQuery,
  );

  @override
  String toString() =>
      'PaginatedPubkeys(count: ${pubkeys.length}, '
      'total: $total, hasMore: $hasMore, nextCursor: $nextCursor, '
      'appliedQuery: $appliedQuery)';
}
