// ABOUTME: Custom exceptions for video-related services
// ABOUTME: Provides specific error types for subscription and network operations

/// Exception thrown when trying to subscribe without relay connections
class ConnectionException implements Exception {
  ConnectionException(this.message);
  final String message;

  @override
  String toString() => 'ConnectionException: $message';
}

/// Exception thrown when attempting duplicate subscriptions
class DuplicateSubscriptionException implements Exception {
  DuplicateSubscriptionException(this.message);
  final String message;

  @override
  String toString() => 'DuplicateSubscriptionException: $message';
}

/// Exception thrown when a video's selected sound is not cleared for reuse.
///
/// Thrown after the media has already uploaded, so it is not an upload or
/// relay failure: only the Nostr event is withheld. It exists as a distinct
/// type so the publish layer can classify it and tell the user the *sound* is
/// the blocker instead of pointing them at their relay settings.
///
/// Raised only for a refusal carried on the sound's own event, where no relay
/// lookup is involved. The legacy source-video resolver cannot produce
/// evidence this strong — its `false` also covers an unreachable relay, a
/// source video outside the query window, and one the viewer's filters
/// dropped — so that path stays an ordinary publish failure.
class AudioReuseNotPermittedException implements Exception {
  AudioReuseNotPermittedException(this.audioEventId);

  /// The selected sound's Nostr event id, or `null` when the sound carries no
  /// referenceable event id.
  final String? audioEventId;

  @override
  String toString() =>
      'AudioReuseNotPermittedException: the selected sound does not grant '
      'reuse consent (audio: $audioEventId)';
}

/// The authoritative Divine publish surface rejected the signed-in account.
/// A signer returned a scheduled event stamped with a different
/// `created_at` than the publish time it was asked for (#3538).
///
/// The event is self-consistent — its id hashes its own timestamp — so
/// neither the id check nor the signature check catches it. Publishing it
/// would either be refused by the relay as "not far enough in the future"
/// or, worse, go out now.
class ScheduledSignatureTimestampException implements Exception {
  const ScheduledSignatureTimestampException({
    required this.requestedCreatedAt,
    required this.signedCreatedAt,
  });

  /// The publish time the app asked the signer for, in unix seconds.
  final int requestedCreatedAt;

  /// The timestamp the signer actually stamped, in unix seconds.
  final int signedCreatedAt;

  @override
  String toString() =>
      'ScheduledSignatureTimestampException: signer stamped $signedCreatedAt '
      'instead of $requestedCreatedAt';
}

class AccountRestrictedPublishException implements Exception {
  const AccountRestrictedPublishException({
    required this.reason,
    required this.source,
  });

  /// The exact authoritative rejection reason, retained for diagnostics.
  final String reason;

  /// Which first-party publish transport supplied [reason].
  final AccountRestrictionSource source;

  @override
  String toString() =>
      'AccountRestrictedPublishException: ${source.name} rejected the account '
      '($reason)';
}

/// First-party source that established an account-level publish restriction.
enum AccountRestrictionSource { rest, webSocket }
