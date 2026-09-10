// ABOUTME: RelayPool's per-query bookkeeping: how each relay answered a
// ABOUTME: one-shot query, judged into a QueryOutcome and one diagnostic line.

import 'dart:math' as math;

import 'package:meta/meta.dart';

import '../../event.dart';
import '../../filter.dart';
import '../../relay/query_outcome.dart';
import '../../relay/query_result.dart';
import '../../relay/relay.dart';
import '../../relay/relay_diagnostics.dart';

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
class _RelayTally {
  _RelayTally(this.relay, int filterCount)
    : eventsPerFilter = List<int>.filled(filterCount, 0);

  /// The relay object most recently seen under this url.
  Relay relay;

  /// `EVENT` frames that matched each filter, by filter index.
  final List<int> eventsPerFilter;

  /// `EVENT` frames from this relay that matched any filter.
  int events = 0;

  /// Whether this relay took the `REQ`; null while the fan-out is still
  /// writing it.
  bool? tookReq;

  _TerminalFrame? terminalFrame;

  /// The NIP-01 prefix of the relay's `CLOSED` reason.
  String? closedReason;

  /// NIP-67 hints from the relay's latest `EOSE`.
  Set<String> hints = const <String>{};

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

  /// The relay url a line is filed under when the fan-out asked no relay,
  /// after `RelayManager`'s `relay-manager`.
  static const _noRelayUrl = 'relay-pool';

  /// The NIP-01 prefix a relay's own `CLOSED` names a NIP-42 refusal with.
  static const _authRequiredReason = 'auth-required';

  static const _finishHint = 'finish';
  static const _moreHint = 'more';
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
    final tally = _tallyFor(relay)..events += 1;
    if (_filters.length == 1) {
      tally.eventsPerFilter[0] += 1;
      return;
    }
    for (var i = 0; i < _filters.length; i++) {
      if (_filters[i].checkEvent(event)) tally.eventsPerFilter[i] += 1;
    }
  }

  /// Records [relay]'s `EOSE` [frame] for the query, keeping the NIP-67
  /// hints it carries.
  ///
  /// Hints are the string elements of a list in the frame's third position.
  /// A third element that is not a list is ignored, as are elements that are
  /// not strings and hint values nothing here acts on.
  void recordEose(Relay relay, List<dynamic> frame) {
    final hints = frame.length > 2 ? frame[2] : null;
    _tallyFor(relay)
      ..terminalFrame = _TerminalFrame.eose
      ..closedReason = null
      ..hints = hints is List
          ? {...hints.whereType<String>()}
          : const <String>{};
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
      possiblyCapped: judgements.keys.any(_isCapped),
      confirmedExhaustive: _confirmedExhaustive(judgements),
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

  /// Whether [tally]'s relay may have stopped at its result-size limit.
  ///
  /// It has when its events for some filter reached
  /// `min(limit ?? max_limit, max_limit)`, with `max_limit` from the relay's
  /// NIP-11 document. A relay that publishes none has when those events
  /// reached the filter's `limit` or, with no `limit` either, numbered at
  /// least one. A NIP-67 `more` hint settles it as capped, `finish` as not.
  bool _isCapped(_RelayTally tally) {
    if (tally.hints.contains(_moreHint)) return true;
    if (tally.hints.contains(_finishHint)) return false;
    final maxLimit = tally.relay.info?.maxLimit;
    for (var i = 0; i < _filters.length; i++) {
      final limit = _filters[i].limit;
      final events = tally.eventsPerFilter[i];
      if (maxLimit != null) {
        if (events >= math.min(limit ?? maxLimit, maxLimit)) return true;
      } else if (limit != null ? events >= limit : events > 0) {
        return true;
      }
    }
    return false;
  }

  /// NIP-67: `finish` confirms a relay sent every matching stored event.
  /// `more` beside it contradicts that, and `auth` says more may follow a
  /// NIP-42 handshake, so neither counts as confirmation.
  static bool _confirmedExhaustive(Map<_RelayTally, _Judgement> judgements) {
    final answered = [
      for (final MapEntry(key: tally, value: judgement) in judgements.entries)
        if (judgement.standing == _Standing.answered) tally,
    ];
    return answered.isNotEmpty &&
        answered.every(
          (tally) =>
              tally.hints.contains(_finishHint) &&
              !tally.hints.contains(_moreHint) &&
              !tally.hints.contains(_authHint),
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
      return _tallies.isEmpty ? _noRelayUrl : _tallies.values.first.relay.url;
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

  /// The line's text: relay urls, event counts, `CLOSED` reason prefixes and
  /// each filter's kinds and limit. Never a pubkey, an event id, or a
  /// filter's ids, authors or tag values.
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

  static String _listOrNone(List<String> entries) =>
      entries.isEmpty ? 'none' : entries.join(', ');

  static String _describeFilter(Filter filter) {
    final kinds = filter.kinds;
    return '{kinds: ${kinds == null ? 'any' : '[${kinds.join(', ')}]'}, '
        'limit: ${filter.limit ?? 'none'}}';
  }
}
