// ABOUTME: The until cursor Nostr.readAllEvents walks back through relay
// ABOUTME: history with: what a settled page means for the next one.

import 'package:meta/meta.dart';

import '../../event.dart';

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

/// Where a paged read goes after a page that settled without NIP-67
/// confirming it exhaustive.
///
/// [cursor] is the page's `until`, null when the walk started without one.
/// [events] is what the page delivered, each naming the relays that sent it;
/// none is newer than [cursor], since the pool drops what a filter does not
/// match. [broughtNew] says whether any of them had not been collected
/// before, and [possiblyCapped] is the page's `QueryResult.possiblyCapped`.
///
/// A relay sends its newest events first, so each one has sent everything it
/// holds after the oldest `created_at` it sent. The frontier is the latest of
/// those, so every relay in [events] has sent all it holds after it. An event
/// counts for each relay that sent it. Cached copies do not count: they name
/// the relays they first came from, not this page's.
///
/// * No relay sent an event: the walk ends, complete unless a relay may be
///   capped.
/// * The page brought something new: the next page starts at the frontier,
///   inclusive, so a second the page split is asked for again.
/// * Nothing new, with the frontier below the cursor: the cursor drops to it.
/// * Nothing new at the cursor's own second: the cursor steps one second
///   back, unless a relay may be capped. A capped relay may hold more events
///   in that second than any `until` can reach, so the walk ends incomplete.
@internal
PagedReadStep nextPagedReadStep({
  required int? cursor,
  required List<Event> events,
  required bool broughtNew,
  required bool possiblyCapped,
}) {
  final frontier = _frontier(events);
  if (frontier == null) return EndPagedRead(isComplete: !possiblyCapped);
  if (broughtNew || cursor == null || frontier < cursor) {
    return ReadPageAt(frontier);
  }
  if (possiblyCapped) return const EndPagedRead(isComplete: false);
  return ReadPageAt(cursor - 1);
}

/// The latest of the oldest `created_at` each relay sent, or null when no
/// relay sent an event.
int? _frontier(List<Event> events) {
  final oldestByRelay = <String, int>{};
  for (final event in events) {
    if (event.cacheEvent) continue;
    for (final url in event.sources) {
      final oldest = oldestByRelay[url];
      if (oldest == null || event.createdAt < oldest) {
        oldestByRelay[url] = event.createdAt;
      }
    }
  }
  int? frontier;
  for (final oldest in oldestByRelay.values) {
    if (frontier == null || oldest > frontier) frontier = oldest;
  }
  return frontier;
}
