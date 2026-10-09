// ABOUTME: Publish result vocabulary for PeopleListsRepository operations.
// ABOUTME: Models relay submission outcome without claiming relay OK.

import 'package:equatable/equatable.dart';

/// Outcome of a repository publish or delete operation.
///
/// `submitted` retains the public API name, but the people-list repository
/// now waits for at least one relay's `OK true`. Acceptance is not a guarantee
/// of durable storage: a relay may acknowledge before committing its queue.
enum PeopleListPublishStatus {
  /// The event was submitted according to the owning repository's contract.
  /// People-list edits require relay acceptance; notify subscriptions retain
  /// socket-submission semantics.
  submitted,

  /// The publish failed or the relay layer returned no event.
  failed,

  /// The operation was a no-op (e.g. removing a pubkey that is not a member).
  noop,
}

/// Value type returned by publish/delete operations on the people-lists
/// repository.
///
/// Carries the [status], the [eventId] of the submitted event when available,
/// and any [error] thrown from the underlying relay client for diagnostics.
class PeopleListPublishResult extends Equatable {
  /// Creates a result describing the publish outcome.
  const PeopleListPublishResult({
    required this.status,
    this.eventId,
    this.error,
  });

  /// Convenience constructor for submitted results.
  const PeopleListPublishResult.submitted({required this.eventId})
    : status = PeopleListPublishStatus.submitted,
      error = null;

  /// Convenience constructor for failed results.
  const PeopleListPublishResult.failed({this.error})
    : status = PeopleListPublishStatus.failed,
      eventId = null;

  /// Convenience constructor for no-op results.
  const PeopleListPublishResult.noop()
    : status = PeopleListPublishStatus.noop,
      eventId = null,
      error = null;

  /// The submission outcome.
  final PeopleListPublishStatus status;

  /// The submitted event ID when [status] is
  /// [PeopleListPublishStatus.submitted], otherwise `null`.
  final String? eventId;

  /// Optional underlying error when [status] is
  /// [PeopleListPublishStatus.failed].
  final Object? error;

  /// Whether submission succeeded according to the repository contract.
  bool get submitted => status == PeopleListPublishStatus.submitted;

  @override
  List<Object?> get props => [status, eventId, error];
}
