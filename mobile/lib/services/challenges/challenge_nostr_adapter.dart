import 'dart:convert';

import 'package:challenge_protocol/challenge_protocol.dart';
import 'package:challenges_repository/challenges_repository.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/nostr_sdk.dart';

/// Explicit bounded known-relay reads. EOSE never implies global discovery or
/// a complete entry count. No backend API contract is assumed here.
class ChallengeNostrAdapter {
  ChallengeNostrAdapter({
    required this.client,
    required this.knownRelays,
    required this.checkOwner,
    this.timeout = const Duration(seconds: 8),
  });
  final NostrClient client;
  final List<String> Function() knownRelays;
  final Future<void> Function() checkOwner;
  final Duration timeout;
  static const definitionLimit = 64;
  static const entryLimit = 256;
  static const int maxReadBytes = 4 * 1024 * 1024;
  static const maxKnownRelays = 16;

  List<String> _allowed() => knownRelays()
      .where(client.isRelayAllowed)
      .toSet()
      .take(maxKnownRelays)
      .toList();

  Future<RawChallengeRead> read(String coordinate) async {
    await checkOwner();
    // The pure codec validates the full coordinate, including colon-bearing d.
    AuthenticatedChallengeBatch.verify(const [], coordinate);
    final parts = coordinate.split(':');
    final request = <String, dynamic>{
      'kinds': [31923],
      'authors': [parts[1]],
      '#d': [parts.skip(2).join(':')],
    };
    final relays = _allowed();
    if (relays.isEmpty) {
      return RawChallengeRead(
        records: const [],
        source: ReadSource.relay,
        completeness: ReadCompleteness.unavailable,
        revisionsComplete: false,
      );
    }
    final definitions = await client.readEvents(
      [
        Filter.fromJson({...request, 'limit': definitionLimit}),
      ],
      tempRelays: relays,
      relayTypes: const [RelayType.temp],
      useCache: false,
      timeout: timeout,
      requireAllRelaysSettled: true,
      maxCollectedEvents: definitionLimit,
      maxCollectedBytes: maxReadBytes,
    );
    await checkOwner();
    final entries = await client.readEvents(
      [
        Filter(
          kinds: const [1111],
          uppercaseA: [coordinate],
          limit: entryLimit,
        ),
      ],
      tempRelays: relays,
      relayTypes: const [RelayType.temp],
      useCache: false,
      timeout: timeout,
      requireAllRelaysSettled: true,
      maxCollectedEvents: entryLimit,
      maxCollectedBytes: maxReadBytes,
    );
    await checkOwner();
    final records = definitions.events
        .map((e) => jsonEncode(e.toJson()))
        .toList();
    const limits = ReadLimits();
    var entryLimited = entries.possiblyCapped;
    for (final event in entries.events) {
      final body = jsonEncode(event.toJson());
      if (limits.accepts([...records, body])) {
        records.add(body);
      } else {
        entryLimited = true;
      }
    }
    final normalizedCount = relays.map(normalizeRelayUrl).toSet().length;
    return RawChallengeRead(
      records: records,
      retentionLimited: entryLimited,
      source: ReadSource.relay,
      completeness: ReadCompleteness.partial,
      revisionsComplete:
          relays.length < maxKnownRelays &&
          definitions.isComplete &&
          !definitions.possiblyCapped &&
          definitions.answeredNetworkRelayCount == normalizedCount &&
          definitions.events.length < definitionLimit,
    );
  }

  /// Exact revision lookup, never an addressable latest-video substitution.
  Future<NostrEvent?> exactEvent(String id) async {
    await checkOwner();
    final relays = _allowed();
    if (relays.isEmpty) return null;
    final result = await client.readEvents(
      [
        Filter(ids: [id], limit: 1),
      ],
      tempRelays: relays,
      relayTypes: const [RelayType.temp],
      useCache: false,
      timeout: timeout,
      maxCollectedEvents: 1,
      maxCollectedBytes: 128 * 1024,
    );
    await checkOwner();
    for (final event in result.events) {
      if (event.id == id) return NostrEvent.fromJson(event.toJson());
    }
    return null;
  }

  /// The app signer persists SDK serialization verbatim. Refuse noncanonical
  /// storage instead of silently rewriting it. Normal SDK publication skips
  /// signing when sig is already populated; loopback tests pin the wire bytes.
  Future<Map<String, RelayOutcome>> publish(
    String body,
    List<String> targets,
  ) async {
    await checkOwner();
    final verified = NostrEvent.fromJson(
      jsonDecode(body) as Map<String, dynamic>,
    );
    final event = Event.fromJson(verified.toJson());
    if (jsonEncode(event.toJson()) != body) {
      throw const FormatException('Unexpected signed event serialization');
    }
    final allowed = targets.where(client.isRelayAllowed).toList();
    final outcomes = {
      for (final target in targets) target: RelayOutcome.unreachable,
    };
    // NostrClient falls back to its pool when all explicit targets are
    // filtered. Refuse that call: a fallback ACK cannot acquire authority.
    if (allowed.isEmpty) return outcomes;
    await checkOwner();
    final result = await client.publishEventAwaitOk(
      event,
      targetRelays: allowed,
      timeout: timeout,
    );
    if (result.eventId != verified.id) return outcomes;
    for (final target in allowed) {
      final normalized = normalizeRelayUrl(target);
      bool includes(Iterable<String> relays) =>
          relays.any((relay) => normalizeRelayUrl(relay) == normalized);
      outcomes[target] = includes(result.acceptedBy)
          ? RelayOutcome.accepted
          : includes(result.rejectedBy.keys)
          ? RelayOutcome.rejected
          : includes(result.noResponseFrom)
          ? RelayOutcome.silence
          : RelayOutcome.unreachable;
    }
    return outcomes;
  }
}
