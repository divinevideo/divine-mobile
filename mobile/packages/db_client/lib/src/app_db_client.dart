// ABOUTME: Hybrid database client combining generic DbClient
// ABOUTME: with typed domain methods.
// ABOUTME: Provides type-safe access to all application database tables.

import 'package:db_client/db_client.dart';
import 'package:drift/drift.dart';

/// {@template app_db_client}
/// A typed database client that wraps [DbClient] with domain-specific methods.
///
/// Provides type-safe access to the application's database tables:
/// - [NostrEvents] - Nostr events from the embedded relay
/// - [UserProfiles] - Denormalized user profile cache
/// - [VideoMetrics] - Video engagement metrics
///
/// Usage:
/// ```dart
/// final appDbClient = AppDbClient(dbClient, database);
///
/// // Get a single event
/// final event = await appDbClient.getEvent('event_id');
///
/// // Watch profile changes
/// appDbClient.watchProfile('pubkey').listen((profile) {
///   print('Profile updated: $profile');
/// });
///
/// // Query events with filters
/// final videos = await appDbClient.getEventsByKind(34236, limit: 50);
/// ```
/// {@endtemplate}
class AppDbClient {
  /// {@macro app_db_client}
  AppDbClient(this._dbClient, this._db);

  final DbClient _dbClient;
  final AppDatabase _db;

  /// Access to the underlying generic [DbClient] for custom queries.
  DbClient get dbClient => _dbClient;

  /// Access to the underlying [AppDatabase] for direct Drift operations.
  AppDatabase get database => _db;

  // ---------------------------------------------------------------------------
  // NostrEvents operations
  // ---------------------------------------------------------------------------

  /// Get a single Nostr event by ID.
  Future<NostrEventRow?> getEvent(String id) async {
    final result = await _dbClient.getBy(
      _db.nostrEvents,
      filter: (t) => (t as NostrEvents).id.equals(id),
    );
    return result as NostrEventRow?;
  }

  /// Get multiple events by IDs.
  Future<List<NostrEventRow>> getEventsByIds(List<String> ids) async {
    if (ids.isEmpty) return [];

    final results = await _dbClient.getAll(
      _db.nostrEvents,
      filter: (t) => (t as NostrEvents).id.isIn(ids),
    );
    return results.cast<NostrEventRow>();
  }

  /// Get events by kind with optional limit and offset.
  Future<List<NostrEventRow>> getEventsByKind(
    int kind, {
    int? limit,
    int? offset,
  }) async {
    final results = await _dbClient.getAll(
      _db.nostrEvents,
      filter: (t) => (t as NostrEvents).kind.equals(kind),
      orderBy: [(t) => OrderingTerm.desc((t as NostrEvents).createdAt)],
      limit: limit,
      offset: offset,
    );
    return results.cast<NostrEventRow>();
  }

  /// Get events by author (pubkey) with optional kind filter.
  Future<List<NostrEventRow>> getEventsByAuthor(
    String pubkey, {
    int? kind,
    int? limit,
    int? offset,
  }) async {
    final results = await _dbClient.getAll(
      _db.nostrEvents,
      filter: (t) {
        final table = t as NostrEvents;
        if (kind != null) {
          return table.pubkey.equals(pubkey) & table.kind.equals(kind);
        }
        return table.pubkey.equals(pubkey);
      },
      orderBy: [(t) => OrderingTerm.desc((t as NostrEvents).createdAt)],
      limit: limit,
      offset: offset,
    );
    return results.cast<NostrEventRow>();
  }

  /// Watch a single event by ID.
  Stream<NostrEventRow?> watchEvent(String id) {
    return _dbClient
        .watchSingleBy(
          _db.nostrEvents,
          filter: (t) => (t as NostrEvents).id.equals(id),
        )
        .map((result) => result as NostrEventRow?);
  }

  /// Watch events by kind.
  Stream<List<NostrEventRow>> watchEventsByKind(
    int kind, {
    int? limit,
    int? offset,
  }) {
    return _dbClient
        .watchBy(
          _db.nostrEvents,
          filter: (t) => (t as NostrEvents).kind.equals(kind),
          orderBy: [(t) => OrderingTerm.desc((t as NostrEvents).createdAt)],
          limit: limit,
          offset: offset,
        )
        .map((results) => results.cast<NostrEventRow>());
  }

  /// Watch events by author.
  Stream<List<NostrEventRow>> watchEventsByAuthor(
    String pubkey, {
    int? kind,
    int? limit,
    int? offset,
  }) {
    return _dbClient
        .watchBy(
          _db.nostrEvents,
          filter: (t) {
            final table = t as NostrEvents;
            if (kind != null) {
              return table.pubkey.equals(pubkey) & table.kind.equals(kind);
            }
            return table.pubkey.equals(pubkey);
          },
          orderBy: [(t) => OrderingTerm.desc((t as NostrEvents).createdAt)],
          limit: limit,
          offset: offset,
        )
        .map((results) => results.cast<NostrEventRow>());
  }

  /// Delete an event by ID.
  Future<int> deleteEvent(String id) async {
    return _dbClient.delete(
      _db.nostrEvents,
      filter: (t) => (t as NostrEvents).id.equals(id),
    );
  }

  /// Count events by kind.
  Future<int> countEventsByKind(int kind) async {
    return _dbClient.count(
      _db.nostrEvents,
      filter: (t) => (t as NostrEvents).kind.equals(kind),
    );
  }

  // ---------------------------------------------------------------------------
  // UserProfiles operations
  // ---------------------------------------------------------------------------

  /// Get a user profile by pubkey.
  Future<UserProfileRow?> getProfile(String pubkey) async {
    final result = await _dbClient.getBy(
      _db.userProfiles,
      filter: (t) => (t as UserProfiles).pubkey.equals(pubkey),
    );
    return result as UserProfileRow?;
  }

  /// Get multiple profiles by pubkeys.
  Future<List<UserProfileRow>> getProfilesByPubkeys(
    List<String> pubkeys,
  ) async {
    if (pubkeys.isEmpty) return [];

    final results = await _dbClient.getAll(
      _db.userProfiles,
      filter: (t) => (t as UserProfiles).pubkey.isIn(pubkeys),
    );
    return results.cast<UserProfileRow>();
  }

  /// Get all cached profiles with optional limit.
  Future<List<UserProfileRow>> getAllProfiles({int? limit, int? offset}) async {
    final results = await _dbClient.getAll(
      _db.userProfiles,
      orderBy: [(t) => OrderingTerm.desc((t as UserProfiles).createdAt)],
      limit: limit,
      offset: offset,
    );
    return results.cast<UserProfileRow>();
  }

  /// Insert or update a user profile.
  Future<UserProfileRow> upsertProfile(UserProfilesCompanion profile) async {
    final result = await _dbClient.insert(
      _db.userProfiles,
      entry: profile,
    );
    return result as UserProfileRow;
  }

  /// Watch a single profile by pubkey.
  Stream<UserProfileRow?> watchProfile(String pubkey) {
    return _dbClient
        .watchSingleBy(
          _db.userProfiles,
          filter: (t) => (t as UserProfiles).pubkey.equals(pubkey),
        )
        .map((result) => result as UserProfileRow?);
  }

  /// Watch multiple profiles by pubkeys.
  Stream<List<UserProfileRow>> watchProfilesByPubkeys(List<String> pubkeys) {
    if (pubkeys.isEmpty) return Stream.value([]);

    return _dbClient
        .watchBy(
          _db.userProfiles,
          filter: (t) => (t as UserProfiles).pubkey.isIn(pubkeys),
        )
        .map((results) => results.cast<UserProfileRow>());
  }

  /// Delete a profile by pubkey.
  Future<int> deleteProfile(String pubkey) async {
    return _dbClient.delete(
      _db.userProfiles,
      filter: (t) => (t as UserProfiles).pubkey.equals(pubkey),
    );
  }

  /// Count total cached profiles.
  Future<int> countProfiles() async {
    return _dbClient.count(_db.userProfiles);
  }

  // ---------------------------------------------------------------------------
  // VideoMetrics operations
  // ---------------------------------------------------------------------------

  /// Get video metrics by event ID.
  Future<VideoMetricRow?> getVideoMetrics(String eventId) async {
    final result = await _dbClient.getBy(
      _db.videoMetrics,
      filter: (t) => (t as VideoMetrics).eventId.equals(eventId),
    );
    return result as VideoMetricRow?;
  }

  /// Get video metrics for multiple events.
  Future<List<VideoMetricRow>> getVideoMetricsByIds(
    List<String> eventIds,
  ) async {
    if (eventIds.isEmpty) return [];

    final results = await _dbClient.getAll(
      _db.videoMetrics,
      filter: (t) => (t as VideoMetrics).eventId.isIn(eventIds),
    );
    return results.cast<VideoMetricRow>();
  }

  /// Get top videos by loop count.
  Future<List<VideoMetricRow>> getTopVideosByLoops({
    int? limit,
    int? offset,
  }) async {
    final results = await _dbClient.getAll(
      _db.videoMetrics,
      orderBy: [(t) => OrderingTerm.desc((t as VideoMetrics).loopCount)],
      limit: limit,
      offset: offset,
    );
    return results.cast<VideoMetricRow>();
  }

  /// Get top videos by likes.
  Future<List<VideoMetricRow>> getTopVideosByLikes({
    int? limit,
    int? offset,
  }) async {
    final results = await _dbClient.getAll(
      _db.videoMetrics,
      orderBy: [(t) => OrderingTerm.desc((t as VideoMetrics).likes)],
      limit: limit,
      offset: offset,
    );
    return results.cast<VideoMetricRow>();
  }

  /// Insert or update video metrics.
  Future<VideoMetricRow> upsertVideoMetrics(
    VideoMetricsCompanion metrics,
  ) async {
    final result = await _dbClient.insert(
      _db.videoMetrics,
      entry: metrics,
    );
    return result as VideoMetricRow;
  }

  /// Watch video metrics by event ID.
  Stream<VideoMetricRow?> watchVideoMetrics(String eventId) {
    return _dbClient
        .watchSingleBy(
          _db.videoMetrics,
          filter: (t) => (t as VideoMetrics).eventId.equals(eventId),
        )
        .map((result) => result as VideoMetricRow?);
  }

  /// Watch top videos by loop count.
  Stream<List<VideoMetricRow>> watchTopVideosByLoops({
    int? limit,
    int? offset,
  }) {
    return _dbClient
        .watchAll(
          _db.videoMetrics,
          orderBy: [(t) => OrderingTerm.desc((t as VideoMetrics).loopCount)],
          limit: limit,
          offset: offset,
        )
        .map((results) => results.cast<VideoMetricRow>());
  }

  /// Delete video metrics by event ID.
  Future<int> deleteVideoMetrics(String eventId) async {
    return _dbClient.delete(
      _db.videoMetrics,
      filter: (t) => (t as VideoMetrics).eventId.equals(eventId),
    );
  }

  /// Count total video metrics entries.
  Future<int> countVideoMetrics() async {
    return _dbClient.count(_db.videoMetrics);
  }

  // ---------------------------------------------------------------------------
  // Notifications operations
  // ---------------------------------------------------------------------------

  /// Get a notification by ID.
  Future<NotificationRow?> getNotification(String id) async {
    final result = await _dbClient.getBy(
      _db.notifications,
      filter: (t) => (t as Notifications).id.equals(id),
    );
    return result as NotificationRow?;
  }

  /// Get all notifications sorted by timestamp (newest first).
  Future<List<NotificationRow>> getAllNotifications({
    int? limit,
    int? offset,
  }) async {
    final results = await _dbClient.getAll(
      _db.notifications,
      orderBy: [(t) => OrderingTerm.desc((t as Notifications).timestamp)],
      limit: limit,
      offset: offset,
    );
    return results.cast<NotificationRow>();
  }

  /// Get unread notifications.
  Future<List<NotificationRow>> getUnreadNotifications({
    int? limit,
    int? offset,
  }) async {
    final results = await _dbClient.getAll(
      _db.notifications,
      filter: (t) => (t as Notifications).isRead.equals(false),
      orderBy: [(t) => OrderingTerm.desc((t as Notifications).timestamp)],
      limit: limit,
      offset: offset,
    );
    return results.cast<NotificationRow>();
  }

  /// Watch a single notification by ID.
  Stream<NotificationRow?> watchNotification(String id) {
    return _dbClient
        .watchSingleBy(
          _db.notifications,
          filter: (t) => (t as Notifications).id.equals(id),
        )
        .map((result) => result as NotificationRow?);
  }

  /// Watch all notifications sorted by timestamp (newest first).
  Stream<List<NotificationRow>> watchAllNotifications({
    int? limit,
    int? offset,
  }) {
    return _dbClient
        .watchBy(
          _db.notifications,
          filter: (t) => const Constant(true),
          orderBy: [(t) => OrderingTerm.desc((t as Notifications).timestamp)],
          limit: limit,
          offset: offset,
        )
        .map((results) => results.cast<NotificationRow>());
  }

  /// Watch unread notifications.
  Stream<List<NotificationRow>> watchUnreadNotifications({
    int? limit,
    int? offset,
  }) {
    return _dbClient
        .watchBy(
          _db.notifications,
          filter: (t) => (t as Notifications).isRead.equals(false),
          orderBy: [(t) => OrderingTerm.desc((t as Notifications).timestamp)],
          limit: limit,
          offset: offset,
        )
        .map((results) => results.cast<NotificationRow>());
  }

  /// Delete a notification by ID.
  Future<int> deleteNotification(String id) async {
    return _dbClient.delete(
      _db.notifications,
      filter: (t) => (t as Notifications).id.equals(id),
    );
  }

  /// Delete all notifications.
  Future<int> clearAllNotifications() async {
    return _dbClient.deleteAll(_db.notifications);
  }

  /// Count total notifications.
  Future<int> countNotifications() async {
    return _dbClient.count(_db.notifications);
  }

  /// Count unread notifications.
  Future<int> countUnreadNotifications() async {
    return _dbClient.count(
      _db.notifications,
      filter: (t) => (t as Notifications).isRead.equals(false),
    );
  }

  // ---------------------------------------------------------------------------
  // ProfileStats operations (cache table - most logic in DAO)
  // ---------------------------------------------------------------------------

  /// Get profile stats by pubkey (raw row, no expiry check).
  Future<ProfileStatRow?> getProfileStatRow(String pubkey) async {
    final result = await _dbClient.getBy(
      _db.profileStats,
      filter: (t) => (t as ProfileStats).pubkey.equals(pubkey),
    );
    return result as ProfileStatRow?;
  }

  /// Delete profile stats by pubkey.
  Future<int> deleteProfileStat(String pubkey) async {
    return _dbClient.delete(
      _db.profileStats,
      filter: (t) => (t as ProfileStats).pubkey.equals(pubkey),
    );
  }

  /// Delete all profile stats.
  Future<int> clearAllProfileStats() async {
    return _dbClient.deleteAll(_db.profileStats);
  }

  /// Count total profile stats entries.
  Future<int> countProfileStats() async {
    return _dbClient.count(_db.profileStats);
  }

  // ---------------------------------------------------------------------------
  // HashtagStats operations (cache table - most logic in DAO)
  // ---------------------------------------------------------------------------

  /// Get hashtag stats by hashtag (raw row, no expiry check).
  Future<HashtagStatRow?> getHashtagStatRow(String hashtag) async {
    final result = await _dbClient.getBy(
      _db.hashtagStats,
      filter: (t) => (t as HashtagStats).hashtag.equals(hashtag),
    );
    return result as HashtagStatRow?;
  }

  /// Delete hashtag stats by hashtag.
  Future<int> deleteHashtagStat(String hashtag) async {
    return _dbClient.delete(
      _db.hashtagStats,
      filter: (t) => (t as HashtagStats).hashtag.equals(hashtag),
    );
  }

  /// Delete all hashtag stats.
  Future<int> clearAllHashtagStats() async {
    return _dbClient.deleteAll(_db.hashtagStats);
  }

  /// Count total hashtag stats entries.
  Future<int> countHashtagStats() async {
    return _dbClient.count(_db.hashtagStats);
  }

  // ---------------------------------------------------------------------------
  // PendingUploads operations (domain model in DAO - minimal here)
  // ---------------------------------------------------------------------------

  /// Get pending upload row by ID (raw row, use DAO for domain model).
  Future<PendingUploadRow?> getPendingUploadRow(String id) async {
    final result = await _dbClient.getBy(
      _db.pendingUploads,
      filter: (t) => (t as PendingUploads).id.equals(id),
    );
    return result as PendingUploadRow?;
  }

  /// Delete pending upload by ID.
  Future<int> deletePendingUpload(String id) async {
    return _dbClient.delete(
      _db.pendingUploads,
      filter: (t) => (t as PendingUploads).id.equals(id),
    );
  }

  /// Delete all pending uploads.
  Future<int> clearAllPendingUploads() async {
    return _dbClient.deleteAll(_db.pendingUploads);
  }

  /// Count total pending uploads.
  Future<int> countPendingUploads() async {
    return _dbClient.count(_db.pendingUploads);
  }
}
