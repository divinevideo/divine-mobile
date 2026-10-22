part of '../challenge_protocol.dart';

/// A protocol error with the canonical TypeScript error code.
final class ContractError implements Exception {
  /// Creates a validation error.
  const ContractError(this.code, this.message);

  /// Stable machine-readable error code.
  final String code;

  /// Human-readable explanation (not an authority decision).
  final String message;
  @override
  String toString() => 'ContractError($code): $message';
}

void _require(bool condition, String code, String message) {
  if (!condition) throw ContractError(code, message);
}

/// Parser outcome. Exactly one of [value] and [code] is populated.
final class ParseResult {
  const ParseResult._(this.value, this.code, this.message);

  /// Whether this event is a verified challenge action.
  bool get ok => value != null;

  /// Verified domain projection, when successful.
  final ChallengeEvent? value;

  /// Canonical failure code, when unsuccessful.
  final String? code;

  /// Failure explanation, when unsuccessful.
  final String? message;
}

/// An immutable projection of authenticated signed fields.
sealed class ChallengeEvent {
  const ChallengeEvent(this.event, this.coordinate);

  /// Signed source; a DTO alone never grants authority.
  final NostrEvent event;

  /// Full challenge coordinate.
  final String coordinate;

  /// Application convention action.
  String get action;
}

/// Challenge rules projected from a signed definition.
final class ChallengeDefinition extends ChallengeEvent {
  /// Creates a projection. Builders reparse [event] rather than trust fields.
  ChallengeDefinition({
    required NostrEvent event,
    required String coordinate,
    required this.identifier,
    required this.title,
    required this.start,
    required this.end,
    required this.timeZone,
    required this.endTimeZone,
    required List<String> relays,
    required this.status,
  }) : relays = List.unmodifiable(relays),
       super(event, coordinate);
  @override
  String get action => 'definition';

  /// Signed d-tag, including any colons.
  final String identifier;

  /// Display title.
  final String title;

  /// Inclusive opening time.
  final int start;

  /// Exclusive closing time.
  final int end;

  /// Original signed start timezone spelling.
  final String timeZone;

  /// Original signed end timezone spelling (defaults to start).
  final String endTimeZone;

  /// Advertised relay URLs.
  final List<String> relays;

  /// Signed active/cancelled flag, distinct from derived lifecycle state.
  final String status;
}

/// Entrant consent to submit an exact video revision under exact rules.
final class ChallengeEntry extends ChallengeEvent {
  /// Creates a projection. Builders reparse the signed source.
  const ChallengeEntry({
    required NostrEvent event,
    required String coordinate,
    required this.definition,
    required this.video,
    required this.videoIdentity,
  }) : super(event, coordinate);
  @override
  String get action => 'entry';

  /// Signed rules snapshot.
  final ChallengeDefinition definition;

  /// Exact signed video snapshot; never a playback permission.
  final NostrEvent video;

  /// Stable addressable coordinate or regular event ID.
  final String videoIdentity;
}

/// Author-signed permanent withdrawal of one exact entry.
final class ChallengeWithdrawal extends ChallengeEvent {
  const ChallengeWithdrawal._(super.event, super.coordinate, this.entryId);
  @override
  String get action => 'withdraw';

  /// Target entry ID.
  final String entryId;
}

/// An organizer's named selection.
final class Winner {
  /// Creates a selection.
  const Winner({required this.entryId, required this.label});

  /// Exact entry ID, not the video ID.
  final String entryId;

  /// Display label.
  final String label;
}

/// Signed organizer result; dependencies and current eligibility are separate.
final class ChallengeResult extends ChallengeEvent {
  ChallengeResult._(
    super.event,
    super.coordinate,
    this.definition,
    List<Winner> winners,
  ) : winners = List.unmodifiable(winners);
  @override
  String get action => 'result';

  /// Referenced signed rules.
  final ChallengeDefinition definition;

  /// Immutable presentation order.
  final List<Winner> winners;
}

/// A visibility-checked entry selected by deterministic duplicate resolution.
final class ActiveEntry {
  const ActiveEntry._(this.entry, this.rulesChanged);

  /// Verified entry projection.
  final ChallengeEntry entry;

  /// Whether current rules differ from the submitted snapshot.
  final bool rulesChanged;

  /// Entry's signed source.
  NostrEvent get event => entry.event;

  /// Pinned video revision.
  NostrEvent get video => entry.video;

  /// Pinned rules revision.
  ChallengeDefinition get definition => entry.definition;

  /// Full challenge coordinate.
  String get coordinate => entry.coordinate;

  /// Stable video identity used for duplicate resolution.
  String get videoIdentity => entry.videoIdentity;
}

/// A selected winner, with optional current playable projection.
final class ResolvedWinner {
  const ResolvedWinner._(this.entryId, this.label, this.entry);

  /// Named entry, preserved when hidden or withdrawn.
  final String entryId;

  /// Organizer's label.
  final String label;

  /// Visibility-checked active projection, if available.
  final ActiveEntry? entry;

  /// Whether this winner has an available entry projection.
  bool get available => entry != null;
}

/// Current dependency and eligibility assessment for a historical result.
final class ResultView {
  ResultView._(this.result, this.status, List<ResolvedWinner> winners)
    : winners = List.unmodifiable(winners);

  /// Signed organizer result.
  final ChallengeResult result;

  /// One of verified, pending, ineligible.
  final String status;

  /// Selections in signed presentation order.
  final List<ResolvedWinner> winners;
}

/// Immutable reduction of the supplied retained event set and current policy.
///
/// This is not a claim of complete discovery across relays.
final class ChallengeView {
  ChallengeView._({
    required this.coordinate,
    this.state = 'unavailable',
    this.definition,
    List<ActiveEntry> entries = const [],
    List<ResultView> results = const [],
    this.currentResult,
    List<String> pending = const [],
  }) : entries = List.unmodifiable(entries),
       results = List.unmodifiable(results),
       pending = List.unmodifiable(pending);

  /// Full challenge coordinate.
  final String coordinate;

  /// unavailable, cancelled, result, scheduled, open, or closed.
  final String state;

  /// Latest usable signed definition, if available.
  final ChallengeDefinition? definition;

  /// Available entries, newest first.
  final List<ActiveEntry> entries;

  /// Visible result history, newest first.
  final List<ResultView> results;

  /// Latest verified and currently eligible result.
  final ResultView? currentResult;

  /// Sorted unresolved entry IDs, or the missing definition coordinate.
  final List<String> pending;
}
