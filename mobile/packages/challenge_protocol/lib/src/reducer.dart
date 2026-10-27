part of '../challenge_protocol.dart';

int _newest(NostrEvent a, NostrEvent b) {
  final time = b.createdAt.compareTo(a.createdAt);
  return time != 0 ? time : a.id.compareTo(b.id);
}

int _oldest(NostrEvent a, NostrEvent b) {
  final time = a.createdAt.compareTo(b.createdAt);
  return time != 0 ? time : a.id.compareTo(b.id);
}

/// Reduces a retained set using current visibility policy and an explicit
/// clock.
///
/// The caller must bound transport bytes and batch size. Authenticated
/// malformed
/// definitions, including oversized replacements, prevent stale rules
/// reopening.
/// [isVisible] must apply current deletion, blocking, restrictions and media
/// availability to each source; signed snapshots never grant playback rights.
ChallengeView reduceChallenge(
  List<Object?> events,
  String coordinate,
  int now,
  bool Function(NostrEvent) isVisible,
) {
  _parseCoordinate(coordinate);
  _require(_safeTimestamp(now), 'time', 'Expected integer Unix seconds.');
  final verified = <String, NostrEvent>{};
  for (final input in events) {
    try {
      final event = _verifiedEvent(input, enforceSize: false);
      final existing = verified[event.id];
      if (existing == null || event.sig.compareTo(existing.sig) < 0) {
        verified[event.id] = event;
      }
    } on Object {
      /* Unverified input has no authority. */
    }
  }
  final revisions =
      verified.values
          .where((e) => _definitionCoordinate(e) == coordinate)
          .toList()
        ..sort(_newest);
  if (revisions.isEmpty) {
    return ChallengeView._(coordinate: coordinate, pending: [coordinate]);
  }
  final latest = revisions.first;
  final parsed = parseChallengeEvent(latest);
  if (parsed.value is! ChallengeDefinition || !isVisible(latest)) {
    return ChallengeView._(coordinate: coordinate);
  }
  final definition = parsed.value! as ChallengeDefinition;
  final pending = <String>{};
  final entries = <String, ChallengeEntry>{};
  final withdrawals = <ChallengeWithdrawal>[];
  final results = <ChallengeResult>[];
  for (final event in verified.values) {
    if (event.kind != 1111) continue;
    final parsed = parseChallengeEvent(event).value;
    if (parsed == null || parsed.coordinate != coordinate) continue;
    switch (parsed) {
      case ChallengeEntry():
        entries[event.id] = parsed;
      case ChallengeWithdrawal():
        withdrawals.add(parsed);
      case ChallengeResult():
        results.add(parsed);
      case ChallengeDefinition():
        break;
    }
  }
  final withdrawn = <String>{};
  for (final w in withdrawals) {
    final entry = entries[w.entryId];
    if (entry != null && entry.event.pubkey == w.event.pubkey) {
      withdrawn.add(entry.event.id);
    } else if (!verified.containsKey(w.entryId)) {
      pending.add(w.entryId);
    }
  }
  // Choose duplicates before visibility so hidden revisions are never replaced.
  final canonical = <(String, String), ChallengeEntry>{};
  final orderedEntries = entries.values.toList()
    ..sort((a, b) => _oldest(a.event, b.event));
  for (final entry in orderedEntries) {
    if (withdrawn.contains(entry.event.id)) continue;
    canonical.putIfAbsent((
      entry.event.pubkey,
      entry.videoIdentity,
    ), () => entry);
  }
  final active = <String, ActiveEntry>{};
  for (final entry in canonical.values) {
    if (!isVisible(entry.event) ||
        !isVisible(entry.video) ||
        !isVisible(entry.definition.event)) {
      continue;
    }
    active[entry.event.id] = ActiveEntry._(
      entry,
      entry.definition.event.id != definition.event.id,
    );
  }
  final activeEntries = active.values.toList()
    ..sort((a, b) => _newest(a.event, b.event));
  final resultViews = <ResultView>[];
  ResultView? currentResult;
  results.sort((a, b) => _newest(a.event, b.event));
  for (final result in results) {
    if (!isVisible(result.event) || !isVisible(result.definition.event)) {
      continue;
    }
    var missing = false;
    var invalid = false;
    final winners = result.winners.map((w) {
      if (!entries.containsKey(w.entryId)) {
        if (verified.containsKey(w.entryId)) {
          invalid = true;
        } else {
          missing = true;
          pending.add(w.entryId);
        }
      }
      return ResolvedWinner._(w.entryId, w.label, active[w.entryId]);
    }).toList();
    final eligible =
        definition.status == 'active' &&
        now >= definition.end &&
        result.event.createdAt >= definition.end &&
        result.event.createdAt <= now;
    final status = invalid || !eligible
        ? 'ineligible'
        : missing
        ? 'pending'
        : 'verified';
    final view = ResultView._(result, status, winners);
    resultViews.add(view);
    if (status == 'verified') currentResult ??= view;
  }
  final state = definition.status == 'cancelled'
      ? 'cancelled'
      : currentResult != null
      ? 'result'
      : now < definition.start
      ? 'scheduled'
      : now < definition.end
      ? 'open'
      : 'closed';
  return ChallengeView._(
    coordinate: coordinate,
    state: state,
    definition: definition,
    entries: activeEntries,
    results: resultViews,
    currentResult: currentResult,
    pending: pending.toList()..sort(),
  );
}

/// Authenticated retained envelopes for a known coordinate. This boundary
/// deliberately authenticates oversized/malformed definitions too: they can
/// invalidate older rules, although they can never authorize participation.
/// Callers must bound input bytes before calling this CPU-intensive operation.
final class AuthenticatedChallengeBatch {
  AuthenticatedChallengeBatch._(
    this.records,
    this.events,
    this.policyEvents,
    this.invalidInput,
  );

  /// Deduplicates by verified ID, never by an untrusted claimed identifier.
  factory AuthenticatedChallengeBatch.verify(
    List<String> records,
    String coordinate,
  ) {
    _parseCoordinate(coordinate);
    final verified = <String, (String, NostrEvent)>{};
    var invalid = false;
    for (final body in records) {
      try {
        final decoded = jsonDecode(body);
        if (decoded is! Map<String, Object?>) {
          invalid = true;
          continue;
        }
        final event = _verifiedEvent(decoded, enforceSize: false);
        final existing = verified[event.id];
        if (existing == null || event.sig.compareTo(existing.$2.sig) < 0) {
          verified[event.id] = (body, event);
        }
      } on FormatException {
        invalid = true;
      } on ContractError {
        // Unauthenticated objects never have replacement authority.
      }
    }
    final retained = <String>[];
    final events = <NostrEvent>[];
    final policy = <String, NostrEvent>{};
    final revisions =
        verified.values
            .where((item) => _definitionCoordinate(item.$2) == coordinate)
            .toList()
          ..sort((a, b) => _newest(a.$2, b.$2));
    // Embedded exact definitions carry historical consent. Only the newest
    // top-level revision controls current rules, including malformed ones.
    if (revisions.isNotEmpty) {
      retained.add(revisions.first.$1);
      events.add(revisions.first.$2);
      policy[revisions.first.$2.id] = revisions.first.$2;
    }
    for (final (body, event) in verified.values) {
      if (event.kind != 1111) continue;
      final parsed = parseChallengeEvent(event).value;
      if (parsed == null || parsed.coordinate != coordinate) continue;
      retained.add(body);
      events.add(event);
      policy[event.id] = event;
      switch (parsed) {
        case ChallengeEntry():
          policy[parsed.video.id] = parsed.video;
          policy[parsed.definition.event.id] = parsed.definition.event;
        case ChallengeResult():
          policy[parsed.definition.event.id] = parsed.definition.event;
        case ChallengeWithdrawal():
        case ChallengeDefinition():
          break;
      }
    }
    return AuthenticatedChallengeBatch._(
      List.unmodifiable(retained),
      List.unmodifiable(events),
      List.unmodifiable(policy.values),
      invalid,
    );
  }

  /// Original wire bodies, authenticated and deduplicated.
  final List<String> records;

  /// Authenticated top-level events.
  final List<NostrEvent> events;

  /// Sources, including exact embedded snapshots, needing current policy.
  final List<NostrEvent> policyEvents;

  /// At least one record was not a JSON object. Unauthenticated objects are
  /// discarded without replacement authority.
  final bool invalidInput;
}
