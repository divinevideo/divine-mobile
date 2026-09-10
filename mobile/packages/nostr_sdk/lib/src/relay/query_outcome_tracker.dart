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

/// A relay's terminal frame for the query.
enum _TerminalFrame { eose, closed }

/// Where a relay that took the `REQ` left it, least severe first.
///
/// The order is the precedence behind [QueryOutcome.endedBy]: the most severe
/// relay decides how the whole query ended.
enum _Standing { answered, noAnswer, closed, dropped }

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

  /// Whether this relay took the `REQ`, according to the fan-out.
  bool tookReq = false;

  _TerminalFrame? terminalFrame;

  /// The NIP-01 prefix of the relay's `CLOSED` reason.
  String? closedReason;

  /// NIP-67 hints from the relay's latest `EOSE`.
  Set<String> hints = const <String>{};

  /// Whether the relay took part: it took the `REQ`, or answered it.
  bool get tookPart => tookReq || terminalFrame != null || events > 0;
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
  /// Starts the record for query [subscriptionId] over [filters].
  QueryOutcomeTracker(
    this.subscriptionId,
    List<Map<String, dynamic>> filters, {
    this.onOutcome,
  }) : _filters = filters,
       _limits = [for (final filter in filters) _intOrNull(filter['limit'])],
       _startedAt = DateTime.now();

  /// The relay url a line is filed under when the fan-out asked no relay,
  /// after `RelayManager`'s `relay-manager`.
  static const _noRelayUrl = 'relay-pool';

  static const _finishHint = 'finish';
  static const _moreHint = 'more';
  static const _authHint = 'auth';

  /// The query's subscription id.
  final String subscriptionId;

  /// Receives the outcome when the pool completes the query.
  final void Function(QueryOutcome outcome)? onOutcome;

  final List<Map<String, dynamic>> _filters;
  final List<int?> _limits;
  final DateTime _startedAt;

  /// Parsed on first use, which only a multi-filter query reaches: there an
  /// event has to be matched against each filter to know whose `limit` it
  /// used up.
  late final List<Filter> _parsedFilters = [
    for (final filter in _filters) Filter.fromJson(filter),
  ];

  /// Keyed by relay url, in the order the relays turned up.
  final Map<String, _RelayTally> _tallies = {};

  bool _fanoutFinished = false;
  bool _reported = false;

  /// Records the finished fan-out: every relay it [asked], and the urls of
  /// those that took the `REQ` ([sentTo]).
  void recordFanout({
    required List<Relay> asked,
    required List<String> sentTo,
  }) {
    _fanoutFinished = true;
    for (final relay in asked) {
      _tallyFor(relay).tookReq = sentTo.contains(relay.url);
    }
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
      if (_parsedFilters[i].checkEvent(event)) tally.eventsPerFilter[i] += 1;
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
  /// than the pool. [hasLostConnection] says whether a relay that has sent no
  /// terminal frame can no longer send one. A line is due once per query,
  /// when it did not end [QueryEnd.complete] or may be capped: the call that
  /// produces it marks the query reported, and later calls return none.
  ({QueryOutcome outcome, RelayDiagnostic? diagnostic}) conclude({
    required bool atDeadline,
    required bool Function(Relay relay) hasLostConnection,
  }) {
    final standings = <_RelayTally, _Standing>{
      for (final tally in _tallies.values)
        if (tally.tookPart) tally: _standingOf(tally, hasLostConnection),
    };
    final outcome = QueryOutcome(
      endedBy: _endedBy(standings, atDeadline: atDeadline),
      possiblyCapped: standings.keys.any(_isCapped),
      confirmedExhaustive: _confirmedExhaustive(standings),
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
        relayUrl: _lineRelayUrl(standings),
        message: _describe(outcome, standings),
      ),
    );
  }

  _RelayTally _tallyFor(Relay relay) =>
      (_tallies[relay.url] ??= _RelayTally(relay, _filters.length))
        ..relay = relay;

  static _Standing _standingOf(
    _RelayTally tally,
    bool Function(Relay relay) hasLostConnection,
  ) => switch (tally.terminalFrame) {
    _TerminalFrame.eose => _Standing.answered,
    _TerminalFrame.closed => _Standing.closed,
    null =>
      hasLostConnection(tally.relay) ? _Standing.dropped : _Standing.noAnswer,
  };

  QueryEnd _endedBy(
    Map<_RelayTally, _Standing> standings, {
    required bool atDeadline,
  }) {
    // A deadline that beats the fan-out leaves participation unknown: only a
    // finished fan-out proves that no relay took the REQ.
    if (standings.isEmpty && (_fanoutFinished || !atDeadline)) {
      return QueryEnd.noRelay;
    }
    if (atDeadline) return QueryEnd.deadline;
    return switch (_worst(standings.values)) {
      _Standing.answered => QueryEnd.complete,
      _Standing.noAnswer => QueryEnd.settledEarly,
      _Standing.closed => QueryEnd.relayClosed,
      _Standing.dropped => QueryEnd.socketDropped,
    };
  }

  static _Standing _worst(Iterable<_Standing> standings) =>
      standings.reduce((a, b) => a.index >= b.index ? a : b);

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
    for (var i = 0; i < _limits.length; i++) {
      final limit = _limits[i];
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
  static bool _confirmedExhaustive(Map<_RelayTally, _Standing> standings) {
    final answered = [
      for (final MapEntry(key: tally, value: standing) in standings.entries)
        if (standing == _Standing.answered) tally,
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
  String _lineRelayUrl(Map<_RelayTally, _Standing> standings) {
    if (standings.isEmpty) {
      return _tallies.isEmpty ? _noRelayUrl : _tallies.values.first.relay.url;
    }
    final worst = _worst(standings.values);
    if (worst == _Standing.answered) {
      for (final tally in standings.keys) {
        if (_isCapped(tally)) return tally.relay.url;
      }
    }
    return standings.entries
        .firstWhere((entry) => entry.value == worst)
        .key
        .relay
        .url;
  }

  /// The line's text: relay urls, event counts, `CLOSED` reason prefixes and
  /// each filter's kinds and limit. Never a pubkey, an event id, or a
  /// filter's ids, authors or tag values.
  String _describe(
    QueryOutcome outcome,
    Map<_RelayTally, _Standing> standings,
  ) {
    final elapsedMs = DateTime.now().difference(_startedAt).inMilliseconds;
    final events = _tallies.values.fold(0, (sum, tally) => sum + tally.events);
    final answered = <String>[];
    final notAnswered = <String>[];
    for (final MapEntry(key: tally, value: standing) in standings.entries) {
      final details = [
        if (standing != _Standing.answered) _standingLabel(standing, tally),
        'events=${tally.events}',
        if (_isCapped(tally)) 'capped',
      ];
      (standing == _Standing.answered ? answered : notAnswered).add(
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

  static String _standingLabel(_Standing standing, _RelayTally tally) =>
      switch (standing) {
        _Standing.answered => 'answered',
        _Standing.noAnswer => 'no answer',
        _Standing.closed => 'closed: ${tally.closedReason}',
        _Standing.dropped => 'dropped',
      };

  static String _listOrNone(List<String> entries) =>
      entries.isEmpty ? 'none' : entries.join(', ');

  static String _describeFilter(Map<String, dynamic> filter) {
    final kinds = filter['kinds'];
    final limit = _intOrNull(filter['limit']);
    final kindList = kinds is List
        ? '[${kinds.whereType<int>().join(', ')}]'
        : 'any';
    return '{kinds: $kindList, limit: ${limit ?? 'none'}}';
  }

  static int? _intOrNull(Object? value) => value is int ? value : null;
}
