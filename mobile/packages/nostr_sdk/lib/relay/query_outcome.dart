// ABOUTME: How a one-shot query ended, as RelayPool reports it to a caller:
// ABOUTME: the end reason, caps and NIP-67 finish, and what each relay sent.

import 'query_result.dart';

/// How a one-shot query ended, as far as the relay pool can tell.
///
/// `RelayPool.query` hands one to its `onOutcome` callback when the pool
/// completes the query, and `RelayPool.reportQueryDeadline` returns one when
/// the caller's own deadline ends the query first. The events are not part of
/// it: they reach the caller through the query's `onEvent` callback.
class QueryOutcome {
  /// Creates a query outcome.
  const QueryOutcome({
    required this.endedBy,
    this.possiblyCapped = false,
    this.confirmedExhaustive = false,
    this.relays = const [],
  });

  /// Why the query ended.
  ///
  /// [QueryEnd.noRelay] when no relay took the `REQ`. Otherwise, when the
  /// pool completed the query, the most severe way a relay that took the
  /// `REQ` left it: [QueryEnd.socketDropped], then [QueryEnd.relayClosed],
  /// then [QueryEnd.settledEarly], then [QueryEnd.complete]. The pool never
  /// reaches [QueryEnd.deadline] on its own, because it does not own the
  /// caller's deadline; only `RelayPool.reportQueryDeadline` reports it.
  final QueryEnd endedBy;

  /// Whether a relay may have withheld matching events because the query
  /// reached that relay's result-size limit; see [QueryResult.possiblyCapped].
  final bool possiblyCapped;

  /// Whether every relay that answered confirmed, with a NIP-67 `finish`
  /// hint, that it sent every matching stored event; see
  /// [QueryResult.confirmedExhaustive].
  final bool confirmedExhaustive;

  /// Every relay that sent an event matching the query's filters, cache
  /// relays aside.
  final List<QueryRelaySummary> relays;
}

/// What one relay sent for a one-shot query, as the relay pool counted it.
class QueryRelaySummary {
  /// Creates the summary of one relay's part in a query.
  const QueryRelaySummary({
    required this.url,
    required this.oldestCreatedAt,
    required this.capped,
  });

  /// The relay's url.
  final String url;

  /// The oldest `created_at` among the relay's `EVENT` frames that matched
  /// the query's filters, block-listed ones included.
  final int oldestCreatedAt;

  /// Whether the relay may have stopped at its result-size limit rather than
  /// run out of matching events; see [QueryResult.possiblyCapped].
  final bool capped;
}
