// ABOUTME: Result types for how a relay read ended, and how complete it is.
// ABOUTME: Every read keeps the events that arrived even when it stopped early.

import '../event.dart';

/// How a one-shot relay read ended.
///
/// When a read fans out to more than one relay, the read's single [QueryEnd]
/// is derived from every relay's individual outcome — see
/// [QueryResult.endedBy] for the precedence rule. Each value below is
/// documented in isolation: what the relay (or the caller) did, and what a
/// caller may safely assume about [QueryResult.events] as a result.
enum QueryEnd {
  /// Every relay in the read sent `EOSE` (or a NIP-67 `finish` hint) before
  /// the caller's deadline, with no relay closing the subscription early and
  /// no socket dropping mid-read.
  ///
  /// The caller may assume this is everything the queried relays were
  /// willing to send for the filter. It can still be capped: a relay may
  /// answer fully within its own result-size limit and call that "done" —
  /// see [QueryResult.possiblyCapped].
  complete,

  /// Some relays answered in full, but at least one relay never answered and
  /// was neither closed nor dropped — it simply stayed silent past the
  /// read's settle window.
  ///
  /// The caller may assume the returned events are missing whatever the
  /// silent relay(s) held. There is no signal for how much that is.
  settledEarly,

  /// A relay refused the subscription before it produced a complete answer:
  /// it sent a `CLOSED` frame — for example a policy rejection, an
  /// unsupported filter, or a rate limit — or its NIP-42 gate shut with the
  /// query parked behind it.
  ///
  /// The caller may assume that relay's contribution stopped at the point it
  /// was closed, and may be missing entirely.
  relayClosed,

  /// A relay's connection dropped while the read was still open.
  ///
  /// The caller may assume that relay's contribution is incomplete, with no
  /// way to tell how much it had already sent versus still held back.
  socketDropped,

  /// The caller's own deadline elapsed before the read settled.
  ///
  /// The caller may assume the read was cut off: relays that had not yet
  /// answered simply stopped being awaited. Events already received from any
  /// relay by that point are still returned in [QueryResult.events].
  deadline,

  /// No relay accepted the `REQ` for this read at all — for example, no
  /// relay was configured or connected.
  ///
  /// The caller may assume nothing was retrieved because nothing was even
  /// attempted.
  noRelay,
}

/// The outcome of a one-shot relay read, independent of the events it
/// returned.
///
/// A read that stops early — any [QueryEnd] other than [QueryEnd.complete] —
/// still returns whatever events had already arrived rather than discarding
/// them; see [events].
class QueryResult {
  const QueryResult({
    required this.events,
    required this.endedBy,
    this.possiblyCapped = false,
    this.confirmedExhaustive = false,
  });

  /// Events that had arrived by the time the read ended.
  ///
  /// Populated even when [endedBy] is not [QueryEnd.complete] — a read that
  /// ends early keeps whatever it collected.
  final List<Event> events;

  /// Why the read ended. See the [QueryEnd] values for what each one implies
  /// about the completeness of [events].
  ///
  /// When more than one applies, the read reports one: [QueryEnd.noRelay]
  /// when no relay took the `REQ`; otherwise [QueryEnd.deadline] when the
  /// caller's deadline fired before the read settled; otherwise the most
  /// severe way a relay that took the `REQ` left it, in the order
  /// [QueryEnd.socketDropped], [QueryEnd.relayClosed],
  /// [QueryEnd.settledEarly], [QueryEnd.complete]. A deadline that fires
  /// before every relay has been asked is [QueryEnd.deadline], since whether
  /// any relay took the `REQ` is still unknown.
  final QueryEnd endedBy;

  /// `true` when a relay may have withheld matching events because the read
  /// reached that relay's own result-size limit, rather than the relay
  /// having no more events to send.
  ///
  /// With no `limit` on a filter and no NIP-11 `max_limit` from the relay,
  /// that limit is unknown, so any relay that sent that filter even one
  /// matching event counts unless it also sent a NIP-67 `finish` hint. On
  /// its own that is weak evidence of a cap; a caller that will act on it
  /// should give the filter a `limit`.
  ///
  /// A relay that sent events outside the read's filters counts too: it did
  /// not honour them, so it may have spent its limit on events nobody asked
  /// for. So does a relay that sent a frame the pool rejected, one that is
  /// not an event or not validly signed. A cache relay never counts, since it
  /// serves the pool's own copies of what relays sent.
  ///
  /// Can be `true` even when [isComplete] is also `true`: a relay can answer
  /// fully within its own cap and still call that "done".
  final bool possiblyCapped;

  /// `true` when every relay that answered explicitly confirmed it had no
  /// further matching events (a NIP-67 `finish` hint), rather than merely
  /// going quiet after its last event. A relay that also sent `more` or
  /// `auth`, answered outside the read's filters, or sent a frame the pool
  /// rejected, has not confirmed it.
  final bool confirmedExhaustive;

  /// `true` only when every relay in the read finished on its own before the
  /// deadline — see [QueryEnd.complete].
  bool get isComplete => endedBy == QueryEnd.complete;
}

/// The outcome of a paged read: a sequence of one-shot reads walking a filter
/// across multiple pages.
///
/// Unlike [QueryResult.isComplete], which derives from
/// [QueryResult.endedBy], [isComplete] here is a plain field — a pager can
/// stop for reasons (running out of pages, hitting a page cap, its own
/// overall deadline) that are not a property of any single page's
/// [QueryEnd].
class PagedQueryResult {
  const PagedQueryResult({
    required this.events,
    required this.isComplete,
    required this.pages,
    this.stoppedBy,
  });

  /// Every event collected across all pages.
  final List<Event> events;

  /// `true` when the pager walked every page it needed — an empty settled
  /// page, or a page confirmed exhaustive — rather than stopping early.
  final bool isComplete;

  /// How many pages the pager issued.
  final int pages;

  /// The [QueryEnd] of the page whose outcome stopped the walk.
  ///
  /// `null` when [isComplete] is `true`, or when the walk stopped for a
  /// pager-level reason that is not a property of any single page.
  final QueryEnd? stoppedBy;
}
