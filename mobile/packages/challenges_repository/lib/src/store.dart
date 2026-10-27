part of '../challenges_repository.dart';

/// Retains raw records, including authenticated malformed definitions.
abstract interface class RetainedChallengeStore {
  /// Loads retained wire strings. Throws on storage failure.
  Future<List<String>> load(String coordinate);

  /// Atomically unions records without deleting older dependencies.
  /// Completion must mean durable persistence; throws on failure.
  Future<void> retain(String coordinate, List<String> records);
}

/// Durable owner isolation. Adapters must never query an unscoped outbox.
abstract interface class ChallengeSubmissionStore {
  /// Durably persists reviewed context before returning; throws on failure.
  Future<void> saveReview(String owner, SubmissionReview review);

  /// Loads the exact owner-scoped handoff; null means absent.
  Future<SubmissionReview?> loadReview(String owner, String reviewId);

  /// Lists durable signed work for one owner, without deleting retryable work.
  Future<List<PendingChallengeAction>> listActions(String owner);

  /// Restores signed work by owner and consent ID; null means absent.
  Future<PendingChallengeAction?> loadAction(String owner, String reviewId);

  /// Atomically inserts if absent; returns the existing exact action on races.
  /// Must finish durable storage before returning; throws on failure.
  Future<PendingChallengeAction> insertAction(
    String owner,
    PendingChallengeAction action,
  );

  /// Durably updates acknowledgement/indexing evidence, preserving the body.
  Future<void> saveAction(String owner, PendingChallengeAction action);
}

/// A bounded app store can replace verified replay and persist capacity loss.
/// Once limited, retained entries cannot claim a complete historical reduction.
abstract interface class BoundedRetainedChallengeStore
    implements RetainedChallengeStore {
  /// Whether historical entries exceeded the durable replay budget.
  Future<bool> isLimited(String coordinate);

  /// Atomically replaces authenticated records and capacity evidence.
  Future<void> replace(
    String coordinate,
    List<String> records, {
    required bool limited,
  });
}
