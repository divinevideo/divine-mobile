// ABOUTME: The until cursor Nostr.readAllEvents walks back through relay
// ABOUTME: history with: what one page means for the next.

import 'package:meta/meta.dart';

import '../../relay/query_outcome.dart';

/// What [nextPagedReadStep] tells a paged read to do after a page.
@internal
sealed class PagedReadStep {
  const PagedReadStep();
}

/// Read another page, at `until: until`.
@internal
final class ReadPageAt extends PagedReadStep {
  const ReadPageAt(this.until);

  final int until;
}

/// End the walk. [isComplete] says whether it has read everything.
@internal
final class EndPagedRead extends PagedReadStep {
  const EndPagedRead({required this.isComplete});

  final bool isComplete;
}

/// Where a paged read goes after a page read at `until: cursor`, null when
/// the walk started without one.
///
/// [relays] are the relays that sent the page an event, cache relays aside,
/// as the relay pool counted them. None sent anything newer than [cursor],
/// since the pool drops what the filter does not match. A relay sends its
/// newest events first, so each one has sent everything it holds after its
/// oldest event. [settled], [confirmedExhaustive] and [possiblyCapped] are
/// the page's `QueryResult.isComplete`, `confirmedExhaustive` and
/// `possiblyCapped`.
///
/// * A page that did not settle ends the walk incomplete; a settled page
///   every relay confirmed exhaustive ends it complete.
/// * A capped relay whose oldest event is in the cursor's second ends the walk
///   incomplete: it may hold more events in that second than any `until` can
///   reach.
/// * Otherwise the next page starts at the latest of the relays' oldest
///   `created_at`, inclusive, so a second the page split is asked for again.
///   An uncapped relay whose oldest event is in the cursor's second counts
///   one second below it: it may still hold more below that second without
///   saying so, and one second back is as far as the cursor can move
///   without passing it.
/// * With no relay to go by, the walk ends, complete unless a relay may be
///   capped, such as one whose every event fell outside the filter.
@internal
PagedReadStep nextPagedReadStep({
  required int? cursor,
  required List<QueryRelaySummary> relays,
  required bool settled,
  required bool confirmedExhaustive,
  required bool possiblyCapped,
}) {
  if (!settled) return const EndPagedRead(isComplete: false);
  if (confirmedExhaustive) return const EndPagedRead(isComplete: true);
  int? next;
  for (final relay in relays) {
    var reach = relay.oldestCreatedAt;
    if (cursor != null && reach >= cursor) {
      if (relay.capped) return const EndPagedRead(isComplete: false);
      reach = cursor - 1;
    }
    if (next == null || reach > next) next = reach;
  }
  if (next == null) return EndPagedRead(isComplete: !possiblyCapped);
  return ReadPageAt(next);
}
