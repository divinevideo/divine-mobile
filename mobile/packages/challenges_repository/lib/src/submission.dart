part of '../challenges_repository.dart';

/// Exact immutable fields reviewed before asking the app signer to sign.
final class UnsignedChallengeAction {
  /// Copies every tag, including pre-consent NIP-89 client metadata.
  UnsignedChallengeAction({
    required this.kind,
    required this.createdAt,
    required this.content,
    required List<List<String>> tags,
  }) : tags = List.unmodifiable(tags.map(List<String>.unmodifiable));

  /// Event kind.
  final int kind;

  /// Reviewed creation time.
  final int createdAt;

  /// Reviewed content.
  final String content;

  /// Reviewed tag order and values.
  final List<List<String>> tags;

  /// Fresh signer input. Mutating it cannot mutate consent.
  Map<String, Object?> toJson() => {
    'kind': kind,
    'created_at': createdAt,
    'content': content,
    'tags': tags.map((tag) => tag.toList()).toList(),
  };
}

/// Durable handoff binding owner, rules, video and exact unsigned fields.
final class SubmissionReview {
  /// Stores immutable sources; submit always authenticates them again.
  const SubmissionReview({
    required this.owner,
    required this.definition,
    required this.video,
    required this.fields,
    this.withdrawalEntry,
  });

  /// Full signer identity, never a display label.
  final String owner;

  /// Exact signed reviewed rules.
  final NostrEvent definition;

  /// Exact published video revision.
  final NostrEvent video;

  /// Exact reviewed action.
  final UnsignedChallengeAction fields;

  /// Exact entry to withdraw, when this is withdrawal consent.
  final NostrEvent? withdrawalEntry;

  /// Stable consent identity, also the owner-scoped durable outbox key.
  String get id => sha256
      .convert(
        utf8.encode(
          jsonEncode([
            owner,
            definition.id,
            video.id,
            withdrawalEntry?.id,
            fields.toJson(),
          ]),
        ),
      )
      .toString();
}

/// Individual target's acknowledgement, not API indexing or organizer approval.
enum RelayOutcome {
  /// Relay accepted this exact event.
  accepted,

  /// Relay explicitly rejected this event.
  rejected,

  /// No acknowledgement; acceptance may have happened.
  silence,

  /// Relay could not be reached.
  unreachable,
}

/// Durable exact bytes plus independent delivery and indexing evidence.
final class PendingChallengeAction {
  /// Copies target/outcome collections for persistence and restart.
  PendingChallengeAction({
    required this.review,
    required this.signedBody,
    required List<String> challengeRelays,
    required List<String> targets,
    Map<String, RelayOutcome> outcomes = const {},
    this.echoed = false,
    this.indexed = false,
    this.deliveryDefinition,
  }) : challengeRelays = List.unmodifiable(challengeRelays),
       targets = List.unmodifiable(targets),
       outcomes = Map.unmodifiable(outcomes);

  /// Owner-scoped reviewed context.
  final SubmissionReview review;

  /// Original signer response bytes; retries must use this string verbatim.
  final String signedBody;

  /// Verified advertised challenge relays at signing time.
  final List<String> challengeRelays;

  /// Authenticated later advertised-relay revision used for delivery only.
  /// Original entry consent and signed bytes remain bound to [review].
  final NostrEvent? deliveryDefinition;

  /// Challenge relays plus configured writable relays.
  final List<String> targets;

  /// Latest per-target outcome; prior acceptance is never erased.
  final Map<String, RelayOutcome> outcomes;

  /// A verified matching echo from a challenge relay has been observed.
  final bool echoed;

  /// An independently verified API observation of the exact event ID.
  final bool indexed;

  /// Challenge relay acceptance alone determines submitted status.
  bool get submitted =>
      echoed ||
      challengeRelays.any((relay) => outcomes[relay] == RelayOutcome.accepted);
}

/// Observable delivery decision; no UI strings or video pipeline failures.
enum SubmissionStatus {
  /// Reviewed snapshots/client metadata exceed the signed-record size limit.
  eventTooLarge,

  /// Consent, current rules, window, or current video revision differs, or
  /// the reviewed sources cannot form a valid action.
  reviewRequired,

  /// Current cancellation pauses persisted entry delivery. Keep the signed
  /// action and retry it when allowed; this does not request new consent.
  deliveryPaused,

  /// The active full signer identity changed.
  ownerChanged,

  /// Current policy denies the source or pinned video.
  blocked,

  /// Current rules are unavailable or incomplete. Retain any signed action
  /// and retry delivery when the read recovers; do not replace its consent.
  readUnavailable,

  /// A signer response, stored action or observation fails signature or
  /// protocol validation.
  invalidSignedEvent,

  /// Signing failed without producing durable work.
  signerFailed,

  /// Persistence failed. Any prior durable action remains retryable.
  persistenceFailed,

  /// Unknown, unreachable, or rejected delivery; same signed bytes can retry.
  retryable,

  /// A challenge relay accepted or echoed this exact event.
  submitted,
}

/// Preparation failures carry a machine-readable reason.
final class SubmissionException implements Exception {
  /// Creates a domain failure.
  const SubmissionException(this.status);

  /// Reason to localize in the app layer.
  final SubmissionStatus status;
}

/// Submission assessment with any retained signed work.
final class SubmissionResult {
  /// Creates a result.
  const SubmissionResult(this.status, [this.action]);

  /// Current action outcome.
  final SubmissionStatus status;

  /// Durable work when available, even on an account switch or failure.
  final PendingChallengeAction? action;
}

/// Transport must associate responses with the exact published event ID.
/// Do not await reconcile inside transport: it returns retryable while an
/// attempt is active. Queue echoes for ingestion after transport settles.
typedef ChallengeRelayTransport = Future<Map<String, RelayOutcome>> Function(
  String signedBody,
  List<String> targets,
);
