// ABOUTME: RelayPool's per-query bookkeeping: how each relay answered a
// ABOUTME: one-shot query, judged into a QueryOutcome and one diagnostic line.

import 'package:meta/meta.dart';

import '../../event.dart';
import '../../filter.dart';
import '../../relay/query_outcome.dart';
import '../../relay/query_result.dart';
import '../../relay/relay.dart';
import '../../relay/relay_diagnostics.dart';
import '../../relay/relay_type.dart';
import 'relay_answer_tally.dart';

/// What the pool can still expect from a relay that took the `REQ` and has
/// sent no terminal frame for it.
@internal
enum PendingRelayState {
  /// The query is live on a connected socket, so an answer may still come.
  serving,

  /// The relay's NIP-42 gate is shut with the query parked behind it: a
  /// refusal, as the relay's own `CLOSED auth-required` would have said.
  authGateShut,

  /// The relay no longer holds the query, its socket is down, or the socket
  /// is being force-cycled as a zombie.
  connectionLost,
}

/// A relay's terminal frame for the query.
enum _TerminalFrame { eose, closed }

/// Where a relay that took the `REQ` left it, least severe first.
///
/// The order is the precedence behind [QueryOutcome.endedBy]: the most severe
/// relay decides how the whole query ended.
enum _Standing { answered, noAnswer, closed, dropped }

/// A relay's standing, and how the diagnostic line describes it.
typedef _Judgement = ({_Standing standing, String label});

/// One relay's part in a query.
class _RelayTally extends RelayAnswerTally {
  _RelayTally(this.relay, super.filterCount);

  /// The relay object most recently seen under this url.
  Relay relay;

  /// Whether this relay took the `REQ`; null while the fan-out is still
  /// writing it.
  bool? tookReq;

  _TerminalFrame? terminalFrame;

  /// The NIP-01 prefix of the relay's `CLOSED` reason.
  String? closedReason;

  /// Whether the relay took part: it took the `REQ`, may still be taking it,
  /// or answered it.
  bool get tookPart => tookReq != false || terminalFrame != null || events > 0;
}

/// Records how every relay answered one one-shot query, and turns that into
/// the query's [QueryOutcome] and its single
/// [RelayDiagnosticSite.queryCompletion] line.
///
/// `RelayPool` owns every instance: it creates one for each query that asked
/// to hear when it completes, feeds it what each relay sends, and calls
/// [conclude] when the query ends.
@internal
class QueryOutcomeTracker {
  /// Starts the record for query [subscriptionId] over [filters], as the
  /// query's `Subscription` parsed them.
  QueryOutcomeTracker(
    this.subscriptionId,
    List<Filter> filters, {
    this.onOutcome,
  }) : _filters = filters,
       _startedAt = DateTime.now();

  /// The NIP-01 prefix a relay's own `CLOSED` names a NIP-42 refusal with.
  static const _authRequiredReason = 'auth-required';

  static const _authHint = 'auth';

  /// The query's subscription id.
  final String subscriptionId;

  /// Receives the outcome when the pool completes the query.
  final void Function(QueryOutcome outcome)? onOutcome;

  final List<Filter> _filters;
  final DateTime _startedAt;

  /// Keyed by relay url, in the order the relays turned up.
  final Map<String, _RelayTally> _tallies = {};

  bool _fanoutFinished = false;
  bool _reported = false;

  /// Records that the fan-out is writing the `REQ` to [relay].
  void recordDispatch(Relay relay) {
    _tallyFor(relay);
  }

  /// Records whether [relay] took the `REQ` the fan-out wrote to it.
  void recordReqTaken(Relay relay, {required bool taken}) {
    _tallyFor(relay).tookReq = taken;
  }

  /// Records that the fan-out has heard back from every relay it asked.
  void recordFanoutFinished() {
    _fanoutFinished = true;
  }

  /// Records an `EVENT` frame [relay] sent for the query.
  ///
  /// [event] has already passed the query's filters, so a single-filter query
  /// counts it without matching it again.
  void recordEvent(Relay relay, Event event) {
    _tallyFor(relay).recordEvent(event, _filters);
  }

  /// Records an `EVENT` frame [relay] sent for the query that matched none of
  /// its filters.
  ///
  /// Only a field `Filter.checkEvent` judges can put an event here. It judges
  /// neither NIP-50 `search` nor a tag filter it does not parse, so an event
  /// the relay returned for one of those still counts as matching.
  void recordOffFilterEvent(Relay relay) {
    _tallyFor(relay).outsideFilter += 1;
  }

  /// Records an `EVENT` frame [relay] sent for the query that the pool
  /// rejected: its payload is not an event, its id does not match its
  /// content, or its signature is missing or does not verify.
  void recordRejectedEvent(Relay relay) {
    _tallyFor(relay).rejected += 1;
  }

  /// Records [relay]'s `EOSE` [frame] for the query, keeping the NIP-67
  /// hints it carries; see [RelayAnswerTally.recordEoseHints].
  void recordEose(Relay relay, List<dynamic> frame) {
    _tallyFor(relay)
      ..terminalFrame = _TerminalFrame.eose
      ..closedReason = null
      ..recordEoseHints(frame);
  }

  /// Records [relay]'s `CLOSED` for the query. [reasonCategory] is the
  /// reason's NIP-01 prefix, never the relay's own text.
  void recordClosed(Relay relay, String reasonCategory) {
    _tallyFor(relay)
      ..terminalFrame = _TerminalFrame.closed
      ..closedReason = reasonCategory
      ..hints = const <String>{};
  }

  /// Judges how the query ended, returning the outcome and, when one is due,
  /// the query's [RelayDiagnosticSite.queryCompletion] line.
  ///
  /// Set [atDeadline] when the caller's own deadline ended the query rather
  /// than the pool. [pendingStateOf] says what a relay that has sent no
  /// terminal frame can still be expected to do. A line is due once per
  /// query, when it did not end [QueryEnd.complete] or may be capped: the
  /// call that produces it marks the query reported, and later calls return
  /// none.
  ({QueryOutcome outcome, RelayDiagnostic? diagnostic}) conclude({
    required bool atDeadline,
    required PendingRelayState Function(Relay relay) pendingStateOf,
  }) {
    final judgements = <_RelayTally, _Judgement>{
      for (final tally in _tallies.values)
        if (tally.tookPart) tally: _judge(tally, pendingStateOf),
    };
    final outcome = QueryOutcome(
      endedBy: _endedBy(judgements, atDeadline: atDeadline),
      answeredNetworkRelayCount: judgements.entries
          .where(
            (entry) =>
                entry.value.standing == _Standing.answered &&
                entry.key.relay.relayStatus.relayType != RelayType.cache,
          )
          .length,
      unansweredRelayCount: judgements.values
          .where((judgement) => judgement.standing == _Standing.noAnswer)
          .length,
      rateLimitedRelayCount: judgements.entries
          .where(
            (entry) =>
                entry.value.standing == _Standing.closed &&
                entry.key.closedReason == 'rate-limited',
          )
          .length,
      closedRelayReasons: {
        for (final tally in _tallies.values)
          if (tally.terminalFrame == _TerminalFrame.closed &&
              tally.closedReason != null &&
              tally.relay.relayStatus.relayType != RelayType.cache)
            tally.relay.url: tally.closedReason!,
      },
      possiblyCapped: judgements.keys.any(_isCapped),
      confirmedExhaustive: _confirmedExhaustive(judgements),
      relays: [
        for (final tally in _tallies.values)
          if (tally.oldestCreatedAt case final oldest?
              when tally.relay.relayStatus.relayType != RelayType.cache)
            QueryRelaySummary(
              url: tally.relay.url,
              oldestCreatedAt: oldest,
              capped: _isCapped(tally),
            ),
      ],
      // No event means no summary above, so nothing else would report that
      // this relay may be holding matching events back. `_isCapped` leaves
      // out cache relays, as the summaries do.
      cappedWithoutEvents: [
        for (final tally in _tallies.values)
          if (tally.oldestCreatedAt == null && _isCapped(tally))
            tally.relay.url,
      ],
    );
    if (_reported ||
        (outcome.endedBy == QueryEnd.complete && !outcome.possiblyCapped)) {
      return (outcome: outcome, diagnostic: null);
    }
    _reported = true;
    return (
      outcome: outcome,
      diagnostic: RelayDiagnostic(
        site: RelayDiagnosticSite.queryCompletion,
        level: _levelFor(outcome.endedBy),
        relayUrl: _lineRelayUrl(judgements),
        message: _describe(outcome, judgements),
      ),
    );
  }

  _RelayTally _tallyFor(Relay relay) =>
      (_tallies[relay.url] ??= _RelayTally(relay, _filters.length))
        ..relay = relay;

  static _Judgement _judge(
    _RelayTally tally,
    PendingRelayState Function(Relay relay) pendingStateOf,
  ) {
    switch (tally.terminalFrame) {
      case _TerminalFrame.eose:
        return (standing: _Standing.answered, label: 'answered');
      case _TerminalFrame.closed:
        return (
          standing: _Standing.closed,
          label: 'closed: ${tally.closedReason}',
        );
      case null:
        // Nothing can have been lost yet: the fan-out is still writing it.
        if (tally.tookReq == null) {
          return (standing: _Standing.noAnswer, label: 'REQ in flight');
        }
        return switch (pendingStateOf(tally.relay)) {
          PendingRelayState.serving => (
            standing: _Standing.noAnswer,
            label: 'no answer',
          ),
          PendingRelayState.authGateShut => (
            standing: _Standing.closed,
            label: 'closed: $_authRequiredReason',
          ),
          PendingRelayState.connectionLost => (
            standing: _Standing.dropped,
            label: 'dropped',
          ),
        };
    }
  }

  QueryEnd _endedBy(
    Map<_RelayTally, _Judgement> judgements, {
    required bool atDeadline,
  }) {
    // A deadline that beats the fan-out leaves participation unknown: only a
    // finished fan-out proves that no relay took the REQ.
    if (judgements.isEmpty && (_fanoutFinished || !atDeadline)) {
      return QueryEnd.noRelay;
    }
    if (atDeadline) return QueryEnd.deadline;
    return switch (_worst(judgements.values)) {
      _Standing.answered => QueryEnd.complete,
      _Standing.noAnswer => QueryEnd.settledEarly,
      _Standing.closed => QueryEnd.relayClosed,
      _Standing.dropped => QueryEnd.socketDropped,
    };
  }

  static _Standing _worst(Iterable<_Judgement> judgements) => judgements
      .map((judgement) => judgement.standing)
      .reduce((a, b) => a.index >= b.index ? a : b);

  /// Whether [tally]'s relay may have stopped at its result-size limit; see
  /// [RelayAnswerTally.mayBeCapped].
  bool _isCapped(_RelayTally tally) => tally.mayBeCapped(tally.relay, _filters);

  /// NIP-67: `finish` confirms a relay sent every matching stored event.
  /// `more` beside it contradicts that, `auth` says more may follow a NIP-42
  /// handshake, a relay that answered outside the filter did not honour it,
  /// and one that sent a frame the pool rejected sent something nobody can
  /// use, so none of them counts as confirmation.
  static bool _confirmedExhaustive(Map<_RelayTally, _Judgement> judgements) {
    final answered = [
      for (final MapEntry(key: tally, value: judgement) in judgements.entries)
        if (judgement.standing == _Standing.answered) tally,
    ];
    return answered.isNotEmpty &&
        answered.every(
          (tally) =>
              tally.hints.contains(RelayAnswerTally.finishHint) &&
              !tally.hints.contains(RelayAnswerTally.moreHint) &&
              !tally.hints.contains(_authHint) &&
              tally.outsideFilter == 0 &&
              tally.rejected == 0,
        );
  }

  static RelayDiagnosticLevel _levelFor(QueryEnd endedBy) => switch (endedBy) {
    QueryEnd.complete || QueryEnd.settledEarly => RelayDiagnosticLevel.info,
    QueryEnd.relayClosed ||
    QueryEnd.socketDropped ||
    QueryEnd.deadline ||
    QueryEnd.noRelay => RelayDiagnosticLevel.warning,
  };

  /// The relay a line is filed under: the one whose standing decided the
  /// query or, when every relay answered, the first that may be capped.
  /// Downstream bounding is per relay, so one relay's repeated trouble stays
  /// bounded without hiding another's.
  String _lineRelayUrl(Map<_RelayTally, _Judgement> judgements) {
    if (judgements.isEmpty) {
      return _tallies.isEmpty
          ? RelayDiagnostic.poolScope
          : _tallies.values.first.relay.url;
    }
    final worst = _worst(judgements.values);
    if (worst == _Standing.answered) {
      for (final tally in judgements.keys) {
        if (_isCapped(tally)) return tally.relay.url;
      }
    }
    return judgements.entries
        .firstWhere((entry) => entry.value.standing == worst)
        .key
        .relay
        .url;
  }

  /// The line's text: relay urls, event counts including events outside the
  /// filter and rejected ones, `CLOSED` reason prefixes and each filter's
  /// kinds and limit. Never a pubkey, an event id, or a filter's ids,
  /// authors or tag values.
  String _describe(
    QueryOutcome outcome,
    Map<_RelayTally, _Judgement> judgements,
  ) {
    final elapsedMs = DateTime.now().difference(_startedAt).inMilliseconds;
    final events = _tallies.values.fold(0, (sum, tally) => sum + tally.events);
    final answered = <String>[];
    final notAnswered = <String>[];
    for (final MapEntry(key: tally, value: judgement) in judgements.entries) {
      final answeredIt = judgement.standing == _Standing.answered;
      final details = [
        if (!answeredIt) judgement.label,
        'events=${tally.events}',
        if (tally.outsideFilter > 0) _outsideFilter(tally.outsideFilter),
        if (tally.rejected > 0) _rejected(tally.rejected),
        if (_isCapped(tally)) 'capped',
      ];
      (answeredIt ? answered : notAnswered).add(
        '${tally.relay.url} (${details.join(', ')})',
      );
    }
    final notTaken = [
      for (final tally in _tallies.values)
        if (!tally.tookPart) tally.relay.url,
    ];
    return [
      'Query $subscriptionId ended ${outcome.endedBy.name} after '
          '${elapsedMs}ms (events=$events, '
          'possiblyCapped=${outcome.possiblyCapped}, '
          'confirmedExhaustive=${outcome.confirmedExhaustive})',
      'answered: ${_listOrNone(answered)}',
      'not answered: ${_listOrNone(notAnswered)}',
      if (notTaken.isNotEmpty) 'did not take the REQ: ${notTaken.join(', ')}',
      'filters: ${_filters.map(_describeFilter).join(', ')}',
    ].join('; ');
  }

  static String _outsideFilter(int count) =>
      '$count ${count == 1 ? 'event' : 'events'} outside the filter';

  static String _rejected(int count) =>
      '$count ${count == 1 ? 'event' : 'events'} rejected';

  static String _listOrNone(List<String> entries) =>
      entries.isEmpty ? 'none' : entries.join(', ');

  static String _describeFilter(Filter filter) {
    final kinds = filter.kinds;
    return '{kinds: ${kinds == null ? 'any' : '[${kinds.join(', ')}]'}, '
        'limit: ${filter.limit ?? 'none'}}';
  }
}
