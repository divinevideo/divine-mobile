import 'package:meta/meta.dart';

/// One page of likers, plus the cursor needed to ask for the next one.
///
/// Funnelcake caps an engagement page at 500, so a popular video needs
/// several requests. Returning `hasMore` without the cursor to continue is a
/// dead end — that is exactly how the Liked-by list came to stop at 500 while
/// claiming thousands (#9358).
@immutable
class LikersPage {
  /// Creates a page of likers.
  const LikersPage({
    required this.pubkeys,
    this.nextCursor,
    this.isComplete = true,
  });

  /// A page with no likers and nothing further to fetch.
  static const empty = LikersPage(pubkeys: []);

  /// Likers in this page, most recent first and deduplicated within the page.
  ///
  /// Deduplication is per page, so a caller accumulating pages must still
  /// drop pubkeys it has already seen.
  final List<String> pubkeys;

  /// Opaque cursor for the next page, or `null` when the list is complete.
  ///
  /// Always `null` on the relay fallback: relays have no cursor, so that path
  /// answers with everything it found in a single page.
  final String? nextCursor;

  /// Whether [pubkeys] can be taken as everyone the source knows about.
  ///
  /// Always `true` for a page from the API, and for a relay fallback page
  /// when every relay finished, or when the API had already listed nobody and
  /// the relays found nobody either. `false` when the relay fallback stopped
  /// first: it ran out of time, a relay was cut off or dropped, or a relay
  /// refused while no other relay answered. [pubkeys] then holds only the
  /// people found so far, and an empty list does not mean nobody (#10846).
  final bool isComplete;

  /// Whether a further page can be requested.
  bool get hasMore => nextCursor != null;

  @override
  String toString() =>
      'LikersPage(count: ${pubkeys.length}, nextCursor: $nextCursor, '
      'isComplete: $isComplete)';
}
