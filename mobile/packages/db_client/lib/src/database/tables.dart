// ABOUTME: Drift table definitions for OpenVine's shared Nostr database.
// ABOUTME: Defines tables for events, profiles, metrics, stats,
// ABOUTME: notifications, and uploads.

import 'package:drift/drift.dart';

/// Maps to nostr_sdk's existing 'event' table (read-only for now)
///
/// This table is managed by nostr_sdk's embedded relay and contains all
/// Nostr events.
/// We map to it for querying but don't create/modify it.
@DataClassName('NostrEventRow')
class NostrEvents extends Table {
  @override
  String get tableName => 'event'; // Use existing table from nostr_sdk

  TextColumn get id => text()();
  TextColumn get pubkey => text()();
  IntColumn get createdAt => integer().named('created_at')();
  IntColumn get kind => integer()();
  TextColumn get tags => text()(); // JSON-encoded array
  TextColumn get content => text()();
  TextColumn get sig => text()();
  TextColumn get sources => text().nullable()(); // JSON-encoded array

  @override
  Set<Column> get primaryKey => {id};

  List<Index> get indexes => [
    // Index on kind for filtering video events (kind IN (34236, 6))
    Index(
      'idx_event_kind',
      'CREATE INDEX IF NOT EXISTS idx_event_kind ON event (kind)',
    ),

    // Index on created_at for sorting by timestamp (ORDER BY created_at DESC)
    Index(
      'idx_event_created_at',
      'CREATE INDEX IF NOT EXISTS idx_event_created_at '
          'ON event (created_at)',
    ),

    // Composite index for optimal video queries
    // (WHERE kind = ? ORDER BY created_at DESC)
    Index(
      'idx_event_kind_created_at',
      'CREATE INDEX IF NOT EXISTS idx_event_kind_created_at '
          'ON event (kind, created_at)',
    ),

    // Index on pubkey for author queries (WHERE pubkey = ?)
    Index(
      'idx_event_pubkey',
      'CREATE INDEX IF NOT EXISTS idx_event_pubkey ON event (pubkey)',
    ),

    // Composite index for profile page video queries
    // (WHERE kind = ? AND pubkey = ?)
    Index(
      'idx_event_kind_pubkey',
      'CREATE INDEX IF NOT EXISTS idx_event_kind_pubkey '
          'ON event (kind, pubkey)',
    ),

    // Composite index for author video timeline
    // (WHERE pubkey = ? ORDER BY created_at DESC)
    Index(
      'idx_event_pubkey_created_at',
      'CREATE INDEX IF NOT EXISTS idx_event_pubkey_created_at '
          'ON event (pubkey, created_at)',
    ),
  ];
}

/// Denormalized cache of user profiles extracted from kind 0 events
///
/// Profiles are parsed from kind 0 events and stored here for fast reactive
/// queries.
/// This avoids having to parse JSON for every profile display.
@DataClassName('UserProfileRow')
class UserProfiles extends Table {
  @override
  String get tableName => 'user_profiles';

  TextColumn get pubkey => text()();
  TextColumn get displayName => text().nullable().named('display_name')();
  TextColumn get name => text().nullable()();
  TextColumn get about => text().nullable()();
  TextColumn get picture => text().nullable()();
  TextColumn get banner => text().nullable()();
  TextColumn get website => text().nullable()();
  TextColumn get nip05 => text().nullable()();
  TextColumn get lud16 => text().nullable()();
  TextColumn get lud06 => text().nullable()();
  TextColumn get rawData =>
      text().nullable().named('raw_data')(); // JSON-encoded map
  DateTimeColumn get createdAt => dateTime().named('created_at')();
  TextColumn get eventId => text().named('event_id')();
  DateTimeColumn get lastFetched => dateTime().named('last_fetched')();

  @override
  Set<Column> get primaryKey => {pubkey};
}

/// Denormalized cache of video engagement metrics extracted from video
/// event tags.
///
/// Metrics are parsed from video events (kind 34236, etc.) and stored here
/// for fast sorted queries. This avoids having to parse JSON tags for every
/// sort/filter operation.
@DataClassName('VideoMetricRow')
class VideoMetrics extends Table {
  @override
  String get tableName => 'video_metrics';

  TextColumn get eventId => text().named('event_id')();
  IntColumn get loopCount => integer().nullable().named('loop_count')();
  IntColumn get likes => integer().nullable()();
  IntColumn get views => integer().nullable()();
  IntColumn get comments => integer().nullable()();
  RealColumn get avgCompletion => real().nullable().named('avg_completion')();
  IntColumn get hasProofmode => integer().nullable().named('has_proofmode')();
  IntColumn get hasDeviceAttestation =>
      integer().nullable().named('has_device_attestation')();
  IntColumn get hasPgpSignature =>
      integer().nullable().named('has_pgp_signature')();
  DateTimeColumn get updatedAt => dateTime().named('updated_at')();

  @override
  Set<Column> get primaryKey => {eventId};

  @override
  List<String> get customConstraints => [
    'FOREIGN KEY (event_id) REFERENCES event(id) ON DELETE CASCADE',
  ];

  List<Index> get indexes => [
    // Index on loop_count for trending/popular queries
    // (ORDER BY loop_count DESC)
    Index(
      'idx_metrics_loop_count',
      'CREATE INDEX IF NOT EXISTS idx_metrics_loop_count '
          'ON video_metrics (loop_count)',
    ),

    // Index on likes for sorting by popularity (ORDER BY likes DESC)
    Index(
      'idx_metrics_likes',
      'CREATE INDEX IF NOT EXISTS idx_metrics_likes ON video_metrics (likes)',
    ),

    // Index on views for sorting by view count (ORDER BY views DESC)
    Index(
      'idx_metrics_views',
      'CREATE INDEX IF NOT EXISTS idx_metrics_views ON video_metrics (views)',
    ),
  ];
}

/// Cache of profile statistics (followers, following, video counts, etc.)
///
/// Stores aggregated stats for user profiles with a 5-minute expiry.
@DataClassName('ProfileStatRow')
class ProfileStats extends Table {
  @override
  String get tableName => 'profile_stats';

  TextColumn get pubkey => text()();
  IntColumn get videoCount => integer().nullable().named('video_count')();
  IntColumn get followerCount => integer().nullable().named('follower_count')();
  IntColumn get followingCount =>
      integer().nullable().named('following_count')();
  IntColumn get totalViews => integer().nullable().named('total_views')();
  IntColumn get totalLikes => integer().nullable().named('total_likes')();
  DateTimeColumn get cachedAt => dateTime().named('cached_at')();

  @override
  Set<Column> get primaryKey => {pubkey};
}

/// Cache of trending/popular hashtags
///
/// Stores hashtag statistics with a 1-hour expiry.
@DataClassName('HashtagStatRow')
class HashtagStats extends Table {
  @override
  String get tableName => 'hashtag_stats';

  TextColumn get hashtag => text()();
  IntColumn get videoCount => integer().nullable().named('video_count')();
  IntColumn get totalViews => integer().nullable().named('total_views')();
  IntColumn get totalLikes => integer().nullable().named('total_likes')();
  DateTimeColumn get cachedAt => dateTime().named('cached_at')();

  @override
  Set<Column> get primaryKey => {hashtag};

  List<Index> get indexes => [
    Index(
      'idx_hashtag_video_count',
      'CREATE INDEX IF NOT EXISTS idx_hashtag_video_count '
          'ON hashtag_stats (video_count DESC)',
    ),
  ];
}

/// Persistent storage for notifications
///
/// Stores notification metadata for offline access.
@DataClassName('NotificationRow')
class Notifications extends Table {
  @override
  String get tableName => 'notifications';

  TextColumn get id => text()();
  TextColumn get type => text()(); // like, repost, follow, comment, mention
  TextColumn get fromPubkey => text().named('from_pubkey')();
  TextColumn get targetEventId => text().nullable().named('target_event_id')();
  TextColumn get targetPubkey => text().nullable().named('target_pubkey')();
  TextColumn get content => text().nullable()();
  IntColumn get timestamp => integer()(); // Unix timestamp
  BoolColumn get isRead => boolean().withDefault(const Constant(false))();
  DateTimeColumn get cachedAt => dateTime().named('cached_at')();

  @override
  Set<Column> get primaryKey => {id};

  List<Index> get indexes => [
    Index(
      'idx_notification_timestamp',
      'CREATE INDEX IF NOT EXISTS idx_notification_timestamp '
          'ON notifications (timestamp DESC)',
    ),
    Index(
      'idx_notification_is_read',
      'CREATE INDEX IF NOT EXISTS idx_notification_is_read '
          'ON notifications (is_read)',
    ),
  ];
}

/// Tracks video uploads in progress
///
/// Stores pending upload state for resumption after app restart.
@DataClassName('PendingUploadRow')
class PendingUploads extends Table {
  @override
  String get tableName => 'pending_uploads';

  TextColumn get id => text()();
  TextColumn get localVideoPath => text().named('local_video_path')();
  TextColumn get nostrPubkey => text().named('nostr_pubkey')();
  TextColumn get status => text()(); // pending, uploading, processing, etc.
  DateTimeColumn get createdAt => dateTime().named('created_at')();
  TextColumn get cloudinaryPublicId =>
      text().nullable().named('cloudinary_public_id')();
  TextColumn get videoId => text().nullable().named('video_id')();
  TextColumn get cdnUrl => text().nullable().named('cdn_url')();
  TextColumn get errorMessage => text().nullable().named('error_message')();
  RealColumn get uploadProgress =>
      real().nullable().named('upload_progress')(); // 0.0 to 1.0
  TextColumn get thumbnailPath => text().nullable().named('thumbnail_path')();
  TextColumn get title => text().nullable()();
  TextColumn get description => text().nullable()();
  TextColumn get hashtags =>
      text().nullable()(); // JSON-encoded array of strings
  TextColumn get nostrEventId => text().nullable().named('nostr_event_id')();
  DateTimeColumn get completedAt =>
      dateTime().nullable().named('completed_at')();
  IntColumn get retryCount =>
      integer().withDefault(const Constant(0)).named('retry_count')();
  IntColumn get videoWidth => integer().nullable().named('video_width')();
  IntColumn get videoHeight => integer().nullable().named('video_height')();
  IntColumn get videoDurationMillis =>
      integer().nullable().named('video_duration_millis')();
  TextColumn get proofManifestJson =>
      text().nullable().named('proof_manifest_json')();
  TextColumn get streamingMp4Url =>
      text().nullable().named('streaming_mp4_url')();
  TextColumn get streamingHlsUrl =>
      text().nullable().named('streaming_hls_url')();
  TextColumn get fallbackUrl => text().nullable().named('fallback_url')();

  @override
  Set<Column> get primaryKey => {id};

  List<Index> get indexes => [
    Index(
      'idx_pending_upload_status',
      'CREATE INDEX IF NOT EXISTS idx_pending_upload_status '
          'ON pending_uploads (status)',
    ),
    Index(
      'idx_pending_upload_created',
      'CREATE INDEX IF NOT EXISTS idx_pending_upload_created '
          'ON pending_uploads (created_at DESC)',
    ),
  ];
}
