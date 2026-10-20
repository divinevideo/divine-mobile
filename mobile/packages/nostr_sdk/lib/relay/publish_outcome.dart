// ABOUTME: Result type for publishing an event with relay OK confirmation.
// ABOUTME: Tracks per-relay acceptance, rejection, unreachability and silence.

import 'dart:async';

import 'relay_diagnostics.dart';

/// Outcome of a publish operation that awaits relay OK confirmations.
///
/// Per NIP-01, relays respond to `EVENT` messages with `OK` frames indicating
/// acceptance (`true`) or rejection (`false`) with an optional reason.
///
/// ## What acceptance means
///
/// `OK true` means the relay *accepted the event for writing*. It does not
/// mean the event is stored: NIP-01 defines the flag as "accepted by the
/// relay", and its own example of a valid `OK true` carries the reason
/// `duplicate: already have this event` — an acceptance that wrote nothing.
/// Divine's own relay acknowledges from an in-memory queue and commits to
/// storage on a batch interval afterwards. Treat this type as a record of
/// **how broadly a publish was accepted**, never as a durability guarantee.
///
/// ## Partition invariant
///
/// Every relay the publish targeted appears in exactly one of [acceptedBy],
/// [rejectedBy], [noResponseFrom] or [unreachableTargets], and no other relay
/// appears at all. "Targeted" means every relay the fan-out reached, plus the
/// relays it meant to count if a write failed. Configured relays that were
/// plainly disconnected and never attempted normally do not appear — except
/// when the caller named them in `targetRelays`/`tempRelays`, or when the
/// publish reached nothing at all. Relays whose in-flight connection was
/// actually attempted can still be reported as unreachable (see
/// [PublishTracker.countedTargets]).
class PublishOutcome {
  const PublishOutcome({
    required this.eventId,
    this.eventKind,
    required this.acceptedBy,
    required this.rejectedBy,
    required this.noResponseFrom,
    this.unreachableTargets = const [],
  });

  /// The id of the event that was published.
  final String eventId;

  /// The kind of the event that was published, when the caller has it handy.
  final int? eventKind;

  /// Relay URLs that returned `OK true`.
  final List<String> acceptedBy;

  /// Relay URLs that returned `OK false`, mapped to the reason returned.
  final Map<String, String> rejectedBy;

  /// Relays the event reached that did not answer before the publish settled.
  final List<String> noResponseFrom;

  /// Relays the publish targeted but could not write to at all.
  ///
  /// These never received the `EVENT` frame — the send timed out, or the relay
  /// dropped out mid-publish. They are reported separately from
  /// [noResponseFrom] because "we never asked" and "we asked and got silence"
  /// call for different recovery.
  ///
  /// A relay that was already offline when the publish started is normally
  /// *not* listed here: it never counted as a target, so it cannot drag
  /// [acceptedByAll] down. Two exceptions: a relay the caller named in
  /// `targetRelays` or `tempRelays` is never narrowed away, and a publish
  /// that reached nothing at all lists every targeted relay so the outcome
  /// can still say how many there were.
  final List<String> unreachableTargets;

  /// Every relay this publish targeted.
  int get targetCount =>
      acceptedBy.length +
      rejectedBy.length +
      noResponseFrom.length +
      unreachableTargets.length;

  /// `true` when at least one relay confirmed acceptance.
  bool get acceptedByAny => acceptedBy.isNotEmpty;

  /// `true` when every targeted relay confirmed acceptance.
  ///
  /// Returns `false` when the publish had no targets at all — "all of zero" is
  /// a surprising success, so an empty publish is never treated as accepted.
  bool get acceptedByAll =>
      acceptedBy.isNotEmpty &&
      rejectedBy.isEmpty &&
      noResponseFrom.isEmpty &&
      unreachableTargets.isEmpty;

  /// `true` when some but not all targeted relays accepted the event.
  ///
  /// Nothing in the client republishes to the relays that did not accept, so a
  /// partial publish stays partial until the caller acts on it.
  bool get acceptedByPartial => acceptedByAny && !acceptedByAll;

  /// `true` when at least one relay confirmed acceptance.
  ///
  /// Prefer [acceptedByAny] or [acceptedByAll], which say which one they mean.
  bool get confirmed => acceptedByAny;

  /// `true` when no targeted relay accepted the event. Callers should treat
  /// this as a hard failure.
  bool get failed => acceptedBy.isEmpty;

  /// The log-safe form of [rejectedBy]: each relay's refusal category only.
  Map<String, String> get rejectionCategories => {
    for (final MapEntry(key: relay, value: reason) in rejectedBy.entries)
      relay: relayRefusalCategoryForDiagnostics(reason),
  };

  /// A short, human-readable summary for logs and error messages.
  ///
  /// A refusal is named by its category alone; see [rejectionCategories].
  String get summary {
    if (acceptedByAll) {
      return 'accepted by all ${acceptedBy.length} relay'
          '${acceptedBy.length == 1 ? '' : 's'}';
    }
    if (acceptedByAny) {
      return 'accepted by ${acceptedBy.length} of $targetCount relays';
    }
    if (rejectedBy.isNotEmpty) {
      final first = rejectedBy.entries.first;
      return 'rejected by ${first.key}: '
          '${relayRefusalCategoryForDiagnostics(first.value)}';
    }
    if (noResponseFrom.isNotEmpty) {
      return 'no relay responded (${noResponseFrom.length} timed out)';
    }
    if (unreachableTargets.isNotEmpty) {
      return 'no relay reachable (${unreachableTargets.length} unreachable)';
    }
    return 'no relay reached';
  }

  @override
  String toString() =>
      'PublishOutcome(eventId: $eventId, eventKind: $eventKind, '
      'accepted: $acceptedBy, '
      'rejected: $rejectedBy, noResponse: $noResponseFrom, '
      'unreachable: $unreachableTargets)';
}

/// Internal tracker used by [RelayPool] to correlate OK frames with the
/// original publish call.
///
/// Completion waits for **every** relay the publish reached, so the outcome
/// describes what the relays actually said rather than whichever answered
/// first. It resolves when:
///  * every reached relay has answered, or
///  * [settleWindow] elapses after the first answer, counted no earlier than
///    the [setReachable] call that reports the fan-out's target set, or
///  * [timeout] elapses — deferred until [setReachable] arrives, and by at
///    most [fanOutReportGrace], so a publish that times out mid-fan-out can
///    still tell an unreached target from a silent one.
///
/// The settle window bounds the cost of one wedged relay: waiting the full
/// [timeout] for a silent sibling would stall every publish behind the
/// slowest connection. See [PublishTracker.defaultSettleWindow] for the
/// latency it is sized against.
class PublishTracker {
  PublishTracker({
    required this.eventId,
    this.message,
    this.deadline,
    required Set<String> expectedRelays,
    required Duration timeout,
    Set<String>? countedTargets,
    this.settleWindow = defaultSettleWindow,
  }) : expectedRelays = expectedRelays.toSet(),
       _countedTargets = countedTargets?.toSet() ?? expectedRelays.toSet() {
    _timer = Timer(timeout, _onTimeout);
  }

  /// Grace period granted to the remaining relays after the first answer.
  ///
  /// #6583 sized this against "a few milliseconds" and asked to be revisited
  /// once real publish telemetry existed. It now does. Measured against
  /// production `relay.divine.video` on the shape that stresses this most --
  /// kind-1059 gift wraps, which pay more pre-`OK` ClickHouse round trips than
  /// any other kind on the relay's ingest path (#7442,
  /// 2026-08-31, n=330 over three runs, one connection, sequential sends):
  ///
  ///     p50 245ms   p90 290ms   p95 310ms   p99 1044ms   max 15.9s
  ///
  /// A healthy answer is ~50x the figure this was sized against, so the
  /// headroom is ~3x at p95 rather than orders of magnitude -- and the window
  /// sits *below* the measured p99. A sibling answering in the tail is
  /// therefore recorded in [PublishOutcome.noResponseFrom] even though it
  /// accepted, which is a false negative this constant chooses to accept.
  ///
  /// Left at 1s deliberately: widening it slows every publish that has a
  /// wedged relay in its fan-out, and the error is asymmetric -- a publish
  /// still succeeds on [PublishOutcome.acceptedByAny], so a missed sibling
  /// costs breadth reporting rather than delivery.
  ///
  /// Watch the tail rather than the median. Those runs saw ~0.6% of publishes
  /// hit a relay-wide stall of 4-16s, long enough to miss even the 10s
  /// `DmSendBudget.recipientOkConfirm`. No settle window of this order can
  /// absorb that, and it is not specific to any kind: the auto-allowed
  /// control kind was hit in the same windows.
  static const defaultSettleWindow = Duration(seconds: 1);

  /// How long [timeout] may overrun while waiting for the fan-out's report.
  ///
  /// The report is the statement of which relays were written to, and without
  /// it a timed-out publish cannot tell "we asked and got silence" from "we
  /// never asked". `RelayPool` makes the call in a `finally` immediately after
  /// the fan-out, so this only bounds the pathological case.
  static const fanOutReportGrace = Duration(milliseconds: 250);

  /// The event id we are waiting on.
  final String eventId;

  /// Original EVENT frame for SDK-internal retry paths.
  final List<dynamic>? message;

  /// Hard publish deadline shared with SDK-internal retry paths.
  final DateTime? deadline;

  /// Every relay this publish may write to, and therefore every relay allowed
  /// to answer it — see [isTarget].
  ///
  /// Computed before the fan-out starts, so it covers relays the pool later
  /// fails to write to. Deliberately wider than [countedTargets]: a relay that
  /// looks unwritable up front can still be reached (`send` waits out a
  /// handshake in progress), and its `OK` must not be discarded.
  final Set<String> expectedRelays;

  /// The relays an unwritten target is reported against.
  ///
  /// Defaults to [expectedRelays]. A caller narrows it up front to exclude
  /// relays that were never going to be reached, then may add back relays the
  /// fan-out actually attempted. Only [PublishOutcome.unreachableTargets]
  /// consults this; anything the fan-out wrote to counts through [setReachable]
  /// regardless.
  Set<String> get countedTargets => Set.unmodifiable(_countedTargets);
  Set<String> _countedTargets;

  /// Grace period granted to the remaining relays after the first answer.
  final Duration settleWindow;

  /// Relays the fan-out actually wrote to, once it has reported.
  ///
  /// `null` until [setReachable] is called, which means "assume every target
  /// can answer". The fan-out narrows it, which is what lets an unreachable
  /// target stop blocking completion. [setReachable] is its only writer, so
  /// the set always means exactly "what the fan-out wrote".
  Set<String>? _reachable;

  /// Whether the fan-out has reported which relays it wrote to.
  ///
  /// Gates the settle window and the hard timeout. The tracker is registered
  /// *before* the sequential fan-out starts, so a connected relay can answer
  /// while a later target has not been written to yet. Settling on that
  /// answer would let the window expire mid-fan-out: [setReachable] would
  /// find the tracker closed, and targets the publish never reached would be
  /// reported as silent instead of unreachable.
  bool _fanOutReported = false;

  /// Whether the hard timeout fired before the fan-out reported.
  ///
  /// The fan-out is bounded by the same deadline as this tracker, so the two
  /// finish together and either can win. [setReachable] settles the publish
  /// when this is set — see [_onTimeout].
  bool _timedOutBeforeFanOut = false;

  final Map<String, String> _rejected = {};
  final Map<String, String> _deferredRejections = {};
  final Set<String> _accepted = {};
  final Completer<PublishOutcome> _completer = Completer<PublishOutcome>();
  late final Timer _timer;
  Timer? _settleTimer;
  Timer? _fanOutGraceTimer;
  bool _closed = false;

  Future<PublishOutcome> get future => _completer.future;

  /// Relays that may still answer this publish.
  Set<String> get _awaitable => _reachable ?? expectedRelays;

  /// Whether [relayUrl] is allowed to speak for this publish.
  ///
  /// Frames are routed by event id alone, so without this check any connected
  /// relay could accept or reject a publish it was never sent.
  bool isTarget(String relayUrl) =>
      expectedRelays.contains(relayUrl) ||
      (_reachable?.contains(relayUrl) ?? false);

  /// Record which relays the fan-out managed to write to.
  ///
  /// Relays that were targeted but not reached stop being awaited and are
  /// reported as unreachable.
  void setReachable(
    Iterable<String> reachable, {
    Iterable<String>? countedTargets,
  }) {
    if (_closed) return;
    _reachable = reachable.toSet();
    if (countedTargets != null) {
      _countedTargets = countedTargets.toSet();
    }
    _fanOutReported = true;
    if (_timedOutBeforeFanOut) {
      _complete();
      return;
    }
    // Answers that landed during the fan-out could not start the settle
    // window; now that the target set is final, they can.
    _armSettleWindow();
    _maybeComplete();
  }

  /// Call when the relay returned `OK true`.
  void onAccepted(String relayUrl) {
    if (_closed) return;
    _deferredRejections.remove(relayUrl);
    _accepted.add(relayUrl);
    _onAnswered();
  }

  /// Call when the relay returned `OK false` with a reason.
  void onRejected(String relayUrl, String reason) {
    if (_closed) return;
    _deferredRejections.remove(relayUrl);
    _rejected[relayUrl] = reason;
    _onAnswered();
  }

  /// Record a relay rejection that should be reported if the publish times out,
  /// without counting the relay as answered yet.
  void deferRejection(String relayUrl, String reason) {
    if (_closed ||
        _accepted.contains(relayUrl) ||
        _rejected.containsKey(relayUrl)) {
      return;
    }
    _deferredRejections[relayUrl] = reason;
  }

  /// Clear a previously deferred rejection when the relay is retried or
  /// otherwise no longer represents the original rejection.
  void clearDeferredRejection(String relayUrl) {
    if (_closed) return;
    _deferredRejections.remove(relayUrl);
  }

  /// Start the settle window on the first answer, then re-test completion.
  void _onAnswered() {
    _armSettleWindow();
    _maybeComplete();
  }

  /// Start the grace period for the relays that have not answered yet.
  ///
  /// No-op until the fan-out has reported its target set — see
  /// [_fanOutReported].
  void _armSettleWindow() {
    if (!_fanOutReported) return;
    if (_accepted.isEmpty && _rejected.isEmpty) return;
    _settleTimer ??= Timer(settleWindow, _onSettleWindowElapsed);
  }

  void _maybeComplete() {
    // Tested over the awaitable set rather than as a total, because a relay
    // the fan-out reported as unwritten can still answer — its frame may have
    // gone out just before the per-relay send timeout fired. Comparing totals
    // let that answer fill an awaited relay's quota and settle the publish
    // while that relay was still silent.
    final allAnswered = _awaitable.every(
      (relay) => _accepted.contains(relay) || _rejected.containsKey(relay),
    );
    if (allAnswered) {
      _complete();
    }
  }

  void _onSettleWindowElapsed() {
    if (_closed) return;
    _complete();
  }

  void _onTimeout() {
    if (_closed) return;
    if (!_fanOutReported) {
      // The fan-out shares this tracker's deadline, so when it consumes the
      // whole budget both fire together and the timer wins the tie. Settling
      // here would close the tracker before [setReachable] lands, and every
      // target the fan-out never got to would be reported as silent — which
      // is what makes the pool force-reconnect relays the publish never
      // wrote to. Hand over to [setReachable], but keep the resolution
      // bounded: a driver that never reports must not hang the publish.
      _timedOutBeforeFanOut = true;
      _fanOutGraceTimer ??= Timer(fanOutReportGrace, _complete);
      return;
    }
    _complete();
  }

  void _complete() {
    if (_closed) return;
    _closed = true;
    _timer.cancel();
    _settleTimer?.cancel();
    _fanOutGraceTimer?.cancel();
    final effectiveRejected = Map<String, String>.from(_rejected);
    if (_accepted.isEmpty) {
      effectiveRejected.addAll(_deferredRejections);
    }
    final awaitable = _awaitable;
    bool answered(String relay) =>
        _accepted.contains(relay) || effectiveRejected.containsKey(relay);
    final noResponse = awaitable
        .where((r) => !answered(r))
        .toList(growable: false);
    // A relay that answered is never unreachable, even if the fan-out reported
    // its write as failed — the answer proves it got the frame.
    var unreachable = _countedTargets
        .where((r) => !awaitable.contains(r) && !answered(r))
        .toList(growable: false);
    // A publish that reached nothing must still say how many relays it had.
    // `_countedTargets` excludes relays that were offline before the fan-out,
    // so when *every* relay drops it is empty and the outcome collapses to
    // `targetCount: 0` / "no relay reached" — indistinguishable from having no
    // relays configured at all. This floor only fires when nothing answered and
    // nothing was counted, so it can never widen the denominator of a publish
    // that partly succeeded.
    //
    // It applies to unfiltered publishes only. A caller-named publish puts
    // every `targetRelays`/`tempRelays` entry into `_countedTargets`
    // unconditionally, so `unreachable` is already non-empty and the floor is
    // unreachable. In practice this fires when a connect momentarily succeeds
    // and the socket drops before the live status is read.
    if (unreachable.isEmpty &&
        noResponse.isEmpty &&
        _accepted.isEmpty &&
        effectiveRejected.isEmpty &&
        expectedRelays.isNotEmpty) {
      unreachable = expectedRelays.toList(growable: false);
    }
    _completer.complete(
      PublishOutcome(
        eventId: eventId,
        acceptedBy: _accepted.toList(growable: false),
        rejectedBy: Map<String, String>.unmodifiable(effectiveRejected),
        noResponseFrom: noResponse,
        unreachableTargets: unreachable,
      ),
    );
  }

  /// Cancel the tracker without waiting. Used when the pool is shut down.
  ///
  /// Reports whatever has arrived so far, using the same partitioning as a
  /// normal completion so a relay can never appear in two buckets.
  void cancel() => _complete();
}
