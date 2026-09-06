// ABOUTME: Abstract interface for local storage of repost records.
// ABOUTME: Allows the repository to be decoupled from specific storage
// ABOUTME: implementations (db_client, Hive, etc.).

import 'package:reposts_repository/src/models/repost_record.dart';

/// Abstract interface for local storage of repost records.
///
/// This interface allows the `RepostsRepository` to persist repost records
/// locally without being coupled to a specific storage implementation.
///
/// Implementations can use different storage backends:
/// - Database implementations using db_client
/// - In-memory implementations for testing
abstract class RepostsLocalStorage {
  /// Saves a repost record to local storage.
  ///
  /// If a record with the same [RepostRecord.addressableId] already exists,
  /// it will be replaced.
  Future<void> saveRepostRecord(RepostRecord record);

  /// Saves multiple repost records in a batch operation.
  ///
  /// More efficient than calling [saveRepostRecord] repeatedly.
  Future<void> saveRepostRecordsBatch(List<RepostRecord> records);

  /// Deletes a repost record by addressable ID.
  ///
  /// Returns `true` if a record was deleted, `false` if no record existed.
  Future<bool> deleteRepostRecord(String addressableId);

  /// Gets a repost record by addressable ID.
  ///
  /// Returns `null` if no record exists for the given addressable ID.
  Future<RepostRecord?> getRepostRecord(String addressableId);

  /// Gets the repost event ID for an addressable ID.
  ///
  /// This is a convenience method that returns just the repost event ID,
  /// which is needed for creating deletion events when unreposting.
  ///
  /// Returns `null` if the video is not reposted.
  Future<String?> getRepostEventId(String addressableId);

  /// Gets all repost records.
  Future<List<RepostRecord>> getAllRepostRecords();

  /// Gets the set of all reposted addressable IDs.
  Future<Set<String>> getRepostedAddressableIds();

  /// Checks if a video is reposted.
  Future<bool> isReposted(String addressableId);

  /// Watches all reposted addressable IDs (reactive stream).
  ///
  /// Emits a new set whenever reposts change.
  Stream<Set<String>> watchRepostedAddressableIds();

  /// Clears all repost records belonging to this storage's account.
  ///
  /// Throws if the underlying store cannot be opened or the bulk delete
  /// fails; callers decide whether that is recoverable. Note that erasing a
  /// signed-out account's rows is done by the cleanup in
  /// `social_providers.dart`, not through this method.
  Future<void> clearAll();
}
