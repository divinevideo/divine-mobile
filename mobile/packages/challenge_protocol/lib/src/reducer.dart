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
