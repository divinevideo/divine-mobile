// ABOUTME: Drift table definitions for OpenVine's shared Nostr database.
// ABOUTME: Defines tables for events, profiles, metrics, stats,
// ABOUTME: notifications, and uploads.

import 'package:drift/drift.dart';

/// Nostr events table storing all cached events from relays.
///
/// Contains all Nostr events including video events (kind 34236), profiles
/// (kind 0), reactions (kind 7), etc.
@DataClassName('NostrEventRow')
class NostrEvents extends Table {
  @override
  String get tableName => 'event';

  TextColumn get id => text()();
  TextColumn get pubkey => text()();
  IntColumn get createdAt => integer().named('created_at')();
  IntColumn get kind => integer()();
  TextColumn get tags => text()(); // JSON-encoded array
  TextColumn get content => text()();
  TextColumn get sig => text()();
  TextColumn get sources => text().nullable()(); // JSON-encoded array

  /// Unix timestamp when this cached event should be considered expired.
  /// Null means the event never expires. Used for cache eviction.
  IntColumn get expireAt => integer().nullable().named('expire_at')();

  /// Denormalized NIP-33 d-tag value for parameterized replaceable events
  /// (kind 30000-39999). Empty string when the event has no d-tag (per
  /// NIP-01); NULL for non-parameterized-replaceable kinds. Lets upserts
  /// find the existing version with an indexed lookup instead of decoding
  /// the tags JSON of every (pubkey, kind) row.
  TextColumn get dTag => text().nullable().named('d_tag')();

  @override
  Set<Column> get primaryKey => {id};

  /// Documents the index set for the event table.
  ///
  /// This getter is not wired through `@DriftDatabase(...)`, so Drift's
  /// `m.createAll()` never creates these indexes. AppDatabase's v1
  /// normalization SQL creates them for fresh, migrated, and repaired
  /// databases; keep both in sync.
  List<Index> get indexes => [
    // Feed queries (WHERE kind = ? ORDER BY created_at DESC); the kind
    // prefix also serves kind-only filters.
    Index(
      'idx_event_kind_created_at',
      'CREATE INDEX IF NOT EXISTS idx_event_kind_created_at '
          'ON event (kind, created_at)',
    ),

    // Author timeline (WHERE pubkey = ? ORDER BY created_at DESC); the
    // pubkey prefix also serves author-only filters.
    Index(
      'idx_event_pubkey_created_at',
      'CREATE INDEX IF NOT EXISTS idx_event_pubkey_created_at '
          'ON event (pubkey, created_at)',
    ),

    // Replaceable-event upserts (WHERE pubkey = ? AND kind = ? AND
    // d_tag = ?); the (pubkey, kind) prefix serves standard replaceable
    // upserts and profile queries. The trailing created_at makes the
    // upsert's MAX(created_at) lookup a covering-index seek — without it
    // SQLite's min/max optimization prefers idx_event_kind_created_at
    // (kind-only equality + residual filters), a reverse scan of the
    // whole kind partition (PR #5957 review).
    Index(
      'idx_event_pubkey_kind_d_tag_created_at',
      'CREATE INDEX IF NOT EXISTS idx_event_pubkey_kind_d_tag_created_at '
          'ON event (pubkey, kind, d_tag, created_at)',
    ),

    // Global recency (ORDER BY created_at DESC LIMIT ?), e.g. the
    // verified-signature seed on cold start.
    Index(
      'idx_event_created_at',
      'CREATE INDEX IF NOT EXISTS idx_event_created_at '
          'ON event (created_at)',
    ),

    // Cache eviction (WHERE expire_at IS NULL OR expire_at < ?)
    Index(
      'idx_event_expire_at',
      'CREATE INDEX IF NOT EXISTS idx_event_expire_at ON event (expire_at)',
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
@TableIndex.sql(
  'CREATE INDEX IF NOT EXISTS idx_metrics_loop_count '
  'ON video_metrics (loop_count)',
)
@TableIndex.sql(
  'CREATE INDEX IF NOT EXISTS idx_metrics_likes ON video_metrics (likes)',
)
@TableIndex.sql(
  'CREATE INDEX IF NOT EXISTS idx_metrics_views ON video_metrics (views)',
)
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
}

/// Cache of profile statistics (followers, following, video counts, etc.)
///
/// Stores aggregated stats for user profiles with a 5-minute expiry.
@DataClassName('ProfileStatRow')
class ProfileStats extends Table {
  @override
  String get tableName => 'profile_statistics';

  TextColumn get pubkey => text()();
  IntColumn get videoCount => integer().nullable().named('video_count')();
  IntColumn get followerCount => integer().nullable().named('follower_count')();
  IntColumn get followingCount =>
      integer().nullable().named('following_count')();
  IntColumn get totalViews => integer().nullable().named('total_views')();
  IntColumn get totalLikes => integer().nullable().named('total_likes')();
  DateTimeColumn get cachedAt => dateTime().named('cached_at')();
  DateTimeColumn get followerCountsUpdatedAt =>
      dateTime().nullable().named('follower_counts_updated_at')();

  @override
  Set<Column> get primaryKey => {pubkey};
}

/// Cache of trending/popular hashtags
///
/// Stores hashtag statistics with a 1-hour expiry.
@TableIndex.sql(
  'CREATE INDEX IF NOT EXISTS idx_hashtag_video_count '
  'ON hashtag_stats (video_count DESC)',
)
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
}

/// Persistent storage for notifications
///
/// Stores notification metadata for offline access.
@TableIndex.sql(
  'CREATE INDEX IF NOT EXISTS idx_notification_timestamp '
  'ON notifications (timestamp DESC)',
)
@TableIndex.sql(
  'CREATE INDEX IF NOT EXISTS idx_notification_is_read '
  'ON notifications (is_read)',
)
@TableIndex.sql(
  'CREATE INDEX IF NOT EXISTS idx_notification_owner_timestamp '
  'ON notifications (owner_pubkey, timestamp DESC)',
)
@DataClassName('NotificationRow')
class Notifications extends Table {
  @override
  String get tableName => 'notifications';

  TextColumn get id => text()();
  TextColumn get type => text()(); // like, repost, follow, comment, mention
  TextColumn get fromPubkey => text().named('from_pubkey')();
  TextColumn get targetEventId => text().nullable().named('target_event_id')();
  TextColumn get videoAddressableId =>
      text().nullable().named('video_addressable_id')();
  BoolColumn get hasCommentTarget => boolean()
      .withDefault(const Constant(false))
      .named('has_comment_target')();
  TextColumn get targetPubkey => text().nullable().named('target_pubkey')();
  TextColumn get content => text().nullable()();
  IntColumn get timestamp => integer()(); // Unix timestamp
  BoolColumn get isRead => boolean().withDefault(const Constant(false))();
  DateTimeColumn get cachedAt => dateTime().named('cached_at')();

  /// Hex public key of the account this notification was delivered to.
  /// NULL for legacy rows created before multi-account support; those are
  /// claimed by the next signed-in account via `claimLegacyRows`.
  ///
  /// Notifications are viewer-scoped — the same relay event produces a row
  /// only for the account it targets — so reads must filter on this column
  /// or one account sees another's inbox.
  TextColumn get ownerPubkey => text().nullable().named('owner_pubkey')();

  @override
  Set<Column> get primaryKey => {id, ownerPubkey};
}

/// Tracks video uploads in progress
///
/// Stores pending upload state for resumption after app restart.
@TableIndex.sql(
  'CREATE INDEX IF NOT EXISTS idx_pending_upload_status '
  'ON pending_uploads (status)',
)
@TableIndex.sql(
  'CREATE INDEX IF NOT EXISTS idx_pending_upload_created '
  'ON pending_uploads (created_at DESC)',
)
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
}

/// Stores the current user's own reaction events (Kind 7 likes).
///
/// This table tracks the mapping between target events (videos) and the
/// user's reaction event IDs. This mapping is essential for unlikes, which
/// require the reaction event ID to create a Kind 5 deletion event.
///
/// Only stores reactions created by the current user, not reactions from
/// others.
@TableIndex.sql(
  'CREATE INDEX IF NOT EXISTS idx_personal_reactions_user '
  'ON personal_reactions (user_pubkey)',
)
@TableIndex.sql(
  'CREATE INDEX IF NOT EXISTS idx_personal_reactions_reaction_id '
  'ON personal_reactions (reaction_event_id)',
)
@TableIndex.sql(
  'CREATE INDEX IF NOT EXISTS idx_personal_reactions_addressable_id '
  'ON personal_reactions (addressable_id)',
)
@DataClassName('PersonalReactionRow')
class PersonalReactions extends Table {
  @override
  String get tableName => 'personal_reactions';

  /// The event ID that was liked (e.g., video event ID)
  TextColumn get targetEventId => text().named('target_event_id')();

  /// The Kind 7 reaction event ID created by the user
  TextColumn get reactionEventId => text().named('reaction_event_id')();

  /// The pubkey of the user who created this reaction
  TextColumn get userPubkey => text().named('user_pubkey')();

  /// Unix timestamp when the reaction was created
  IntColumn get createdAt => integer().named('created_at')();

  /// Addressable coordinate (`kind:pubkey:d-tag`) of the target event, when
  /// the target is a Kind 30000+ addressable event (e.g. a video).
  ///
  /// Null for likes on non-addressable targets (e.g. comments), which have
  /// no `d` tag / coordinate. Lets own-like state survive a target edit
  /// that mints a new [targetEventId] for the same coordinate (#6020).
  TextColumn get addressableId => text().nullable().named('addressable_id')();

  @override
  Set<Column> get primaryKey => {targetEventId, userPubkey};
}

/// Stores pending offline actions (likes, reposts, follows) for sync on
/// reconnect.
///
/// When the user performs a social action while offline, it's queued here
/// and synced when connectivity is restored.
@DataClassName('PendingActionRow')
class PendingActions extends Table {
  @override
  String get tableName => 'pending_actions';

  /// Unique identifier for this action
  TextColumn get id => text()();

  /// Type of action: like, unlike, repost, unrepost, follow, unfollow
  TextColumn get type => text()();

  /// Target event ID (for likes/reposts) or pubkey (for follows)
  TextColumn get targetId => text().named('target_id')();

  /// Pubkey of the original event author (for likes/reposts)
  TextColumn get authorPubkey => text().nullable().named('author_pubkey')();

  /// Addressable ID for reposts (format: "kind:pubkey:d-tag")
  TextColumn get addressableId => text().nullable().named('addressable_id')();

  /// Kind of the target event (e.g., 34236 for videos)
  IntColumn get targetKind => integer().nullable().named('target_kind')();

  /// Current sync status: pending, syncing, completed, failed
  TextColumn get status => text()();

  /// The pubkey of the user who queued this action
  TextColumn get userPubkey => text().named('user_pubkey')();

  /// When the action was queued
  DateTimeColumn get createdAt => dateTime().named('created_at')();

  /// Number of sync attempts
  IntColumn get retryCount =>
      integer().withDefault(const Constant(0)).named('retry_count')();

  /// Last error message if sync failed
  TextColumn get lastError => text().nullable().named('last_error')();

  /// Timestamp of last sync attempt
  DateTimeColumn get lastAttemptAt =>
      dateTime().nullable().named('last_attempt_at')();

  @override
  Set<Column> get primaryKey => {id};

  List<Index> get indexes => [
    // Index on status for fetching pending actions
    Index(
      'idx_pending_action_status',
      'CREATE INDEX IF NOT EXISTS idx_pending_action_status '
          'ON pending_actions (status)',
    ),
    // Index on user_pubkey for user-specific queries
    Index(
      'idx_pending_action_user',
      'CREATE INDEX IF NOT EXISTS idx_pending_action_user '
          'ON pending_actions (user_pubkey)',
    ),
    // Composite index for user + status
    Index(
      'idx_pending_action_user_status',
      'CREATE INDEX IF NOT EXISTS idx_pending_action_user_status '
          'ON pending_actions (user_pubkey, status)',
    ),
    // Index on created_at for ordering
    Index(
      'idx_pending_action_created',
      'CREATE INDEX IF NOT EXISTS idx_pending_action_created '
          'ON pending_actions (created_at)',
    ),
  ];
}

/// Cache of NIP-05 verification results.
///
/// Stores the verification status of NIP-05 addresses for user profiles.
/// Uses TTL-based expiration:
/// - verified: 24 hours (stable, rarely changes)
/// - failed: 1 hour (allow retry for transient issues)
/// - error: 5 minutes (network issues, retry soon)
@DataClassName('Nip05VerificationRow')
class Nip05Verifications extends Table {
  @override
  String get tableName => 'nip05_verifications';

  /// The pubkey of the user whose NIP-05 is being verified
  TextColumn get pubkey => text()();

  /// The claimed NIP-05 address (e.g., "alice@example.com")
  TextColumn get nip05 => text()();

  /// Verification status: 'verified', 'failed', 'error', 'pending'
  TextColumn get status => text()();

  /// When the verification was performed
  DateTimeColumn get verifiedAt => dateTime().named('verified_at')();

  /// When this cache entry expires (TTL-based)
  DateTimeColumn get expiresAt => dateTime().named('expires_at')();

  @override
  Set<Column> get primaryKey => {pubkey};

  List<Index> get indexes => [
    // Index on expires_at for cache eviction queries
    Index(
      'idx_nip05_expires_at',
      'CREATE INDEX IF NOT EXISTS idx_nip05_expires_at '
          'ON nip05_verifications (expires_at)',
    ),
  ];
}

/// Persistent storage for video drafts
///
/// Stores draft metadata and full serialized JSON for offline access.
/// Key fields are indexed columns for efficient queries; the full draft
/// payload (clips, editor state, etc.) lives in the [data] JSON blob.
@DataClassName('DraftRow')
class Drafts extends Table {
  @override
  String get tableName => 'drafts';

  /// Unique draft identifier (e.g. "draft_1700000000000")
  TextColumn get id => text()();

  /// User-provided title (may be empty)
  TextColumn get title => text().withDefault(const Constant(''))();

  /// User-provided description (may be empty)
  TextColumn get description => text().withDefault(const Constant(''))();

  /// Current publish status: draft, publishing, failed, published
  TextColumn get publishStatus =>
      text().withDefault(const Constant('draft')).named('publish_status')();

  /// Number of publish attempts
  IntColumn get publishAttempts =>
      integer().withDefault(const Constant(0)).named('publish_attempts')();

  /// Last publish error message
  TextColumn get publishError => text().nullable().named('publish_error')();

  /// When the draft was originally created
  DateTimeColumn get createdAt => dateTime().named('created_at')();

  /// When the draft was last modified
  DateTimeColumn get lastModified => dateTime().named('last_modified')();

  /// Full JSON-serialized draft payload (clips, hashtags, editor state, etc.)
  TextColumn get data => text()();

  /// Basename of the final rendered video file (for indexed lookups)
  TextColumn get renderedFilePath =>
      text().nullable().named('rendered_file_path')();

  /// Basename of the final rendered thumbnail (for indexed lookups)
  TextColumn get renderedThumbnailPath =>
      text().nullable().named('rendered_thumbnail_path')();

  /// Basename of the selected custom cover thumbnail (for indexed lookups)
  TextColumn get customThumbnailPath =>
      text().nullable().named('custom_thumbnail_path')();

  /// Hex public key of the account that owns this draft.
  /// NULL for legacy drafts created before multi-account support.
  TextColumn get ownerPubkey => text().nullable().named('owner_pubkey')();

  @override
  Set<Column> get primaryKey => {id};

  List<Index> get indexes => [
    Index(
      'idx_draft_owner_pubkey',
      'CREATE INDEX IF NOT EXISTS idx_draft_owner_pubkey '
          'ON drafts (owner_pubkey)',
    ),
    Index(
      'idx_draft_publish_status',
      'CREATE INDEX IF NOT EXISTS idx_draft_publish_status '
          'ON drafts (publish_status)',
    ),
    Index(
      'idx_draft_last_modified',
      'CREATE INDEX IF NOT EXISTS idx_draft_last_modified '
          'ON drafts (last_modified DESC)',
    ),
    Index(
      'idx_draft_created_at',
      'CREATE INDEX IF NOT EXISTS idx_draft_created_at '
          'ON drafts (created_at DESC)',
    ),
    Index(
      'idx_draft_rendered_file_path',
      'CREATE INDEX IF NOT EXISTS idx_draft_rendered_file_path '
          'ON drafts (rendered_file_path)',
    ),
    Index(
      'idx_draft_rendered_thumbnail_path',
      'CREATE INDEX IF NOT EXISTS idx_draft_rendered_thumbnail_path '
          'ON drafts (rendered_thumbnail_path)',
    ),
    Index(
      'idx_draft_custom_thumbnail_path',
      'CREATE INDEX IF NOT EXISTS idx_draft_custom_thumbnail_path '
          'ON drafts (custom_thumbnail_path)',
    ),
  ];
}

/// Persistent storage for video clips belonging to drafts
///
/// Each clip is a recorded video segment that belongs to a single draft.
/// Key fields are indexed columns for efficient queries; the full clip
/// payload (lens metadata, thumbnail info, etc.) lives in the [data]
/// JSON blob.
@DataClassName('ClipRow')
class Clips extends Table {
  @override
  String get tableName => 'clips';

  /// Unique clip identifier
  TextColumn get id => text()();

  /// Foreign key to the parent draft (null for library clips)
  TextColumn get draftId => text().nullable().named('draft_id')();

  /// Position of this clip within the draft (0-based)
  IntColumn get orderIndex =>
      integer().withDefault(const Constant(0)).named('order_index')();

  /// Duration in milliseconds
  IntColumn get durationMs => integer().named('duration_ms')();

  /// When the clip was recorded
  DateTimeColumn get recordedAt => dateTime().named('recorded_at')();

  /// Full JSON-serialized clip payload (file path, thumbnail, lens metadata,
  /// aspect ratio, etc.)
  TextColumn get data => text()();

  /// Basename of the video file (for indexed lookups)
  TextColumn get filePath => text().nullable().named('file_path')();

  /// Basename of the thumbnail file (for indexed lookups)
  TextColumn get thumbnailPath => text().nullable().named('thumbnail_path')();

  /// Hex public key of the account that owns this clip.
  /// NULL for legacy clips created before multi-account support.
  TextColumn get ownerPubkey => text().nullable().named('owner_pubkey')();

  /// Soft-delete marker. NULL = active; non-NULL = in trash since this time.
  /// Trashed clips are filtered out of normal queries and purged after the
  /// retention window. See `ClipLibraryService.purgeExpiredTrash`.
  DateTimeColumn get deletedAt => dateTime().nullable().named('deleted_at')();

  /// Id of the user-created [ClipCategories] row this clip is filed under.
  /// NULL = uncategorized. Cleared when its category is deleted.
  TextColumn get categoryId => text().nullable().named('category_id')();

  /// Archive marker. NULL = active; non-NULL = archived since this time.
  /// Archived clips are hidden from the library's default view and shown
  /// under its Archive filter and any category they remain filed under.
  DateTimeColumn get archivedAt => dateTime().nullable().named('archived_at')();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<String> get customConstraints => [
    'FOREIGN KEY (draft_id) REFERENCES drafts(id) ON DELETE CASCADE',
  ];

  List<Index> get indexes => [
    Index(
      'idx_clip_owner_pubkey',
      'CREATE INDEX IF NOT EXISTS idx_clip_owner_pubkey '
          'ON clips (owner_pubkey)',
    ),
    // Partial index for library clips (clips without a draft)
    Index(
      'idx_clip_library',
      'CREATE INDEX IF NOT EXISTS idx_clip_library '
          'ON clips (draft_id) WHERE draft_id IS NULL',
    ),
    Index(
      'idx_clip_draft_id',
      'CREATE INDEX IF NOT EXISTS idx_clip_draft_id '
          'ON clips (draft_id)',
    ),
    Index(
      'idx_clip_draft_order',
      'CREATE INDEX IF NOT EXISTS idx_clip_draft_order '
          'ON clips (draft_id, order_index)',
    ),
    Index(
      'idx_clip_recorded_at',
      'CREATE INDEX IF NOT EXISTS idx_clip_recorded_at '
          'ON clips (recorded_at DESC)',
    ),
    Index(
      'idx_clip_file_path',
      'CREATE INDEX IF NOT EXISTS idx_clip_file_path '
          'ON clips (file_path)',
    ),
    Index(
      'idx_clip_thumbnail_path',
      'CREATE INDEX IF NOT EXISTS idx_clip_thumbnail_path '
          'ON clips (thumbnail_path)',
    ),
    Index(
      'idx_clip_deleted_at',
      'CREATE INDEX IF NOT EXISTS idx_clip_deleted_at '
          'ON clips (deleted_at)',
    ),
    Index(
      'idx_clip_category_id',
      'CREATE INDEX IF NOT EXISTS idx_clip_category_id '
          'ON clips (category_id)',
    ),
  ];
}

/// User-created categories for filing library clips.
///
/// The library's All, Archive, and Deleted filters are built in, so they have
/// no row here — this table holds only the categories a user adds themselves.
/// A clip references at most one of them via [Clips.categoryId].
@DataClassName('ClipCategoryRow')
class ClipCategories extends Table {
  @override
  String get tableName => 'clip_categories';

  /// Unique category identifier.
  TextColumn get id => text()();

  /// User-entered display name. Not localized — it is the user's own text.
  TextColumn get name => text()();

  /// Position of this category in the library's chip row (0-based).
  IntColumn get orderIndex =>
      integer().withDefault(const Constant(0)).named('order_index')();

  /// When the category was created.
  DateTimeColumn get createdAt => dateTime().named('created_at')();

  /// Hex public key of the account that owns this category.
  /// NULL for categories created before an account was known.
  TextColumn get ownerPubkey => text().nullable().named('owner_pubkey')();

  @override
  Set<Column> get primaryKey => {id};

  List<Index> get indexes => [
    Index(
      'idx_clip_category_owner_pubkey',
      'CREATE INDEX IF NOT EXISTS idx_clip_category_owner_pubkey '
          'ON clip_categories (owner_pubkey)',
    ),
  ];
}

/// Stores decrypted NIP-17 direct messages (kind 14 rumor content).
///
/// After a gift-wrapped event (kind 1059) is received and decrypted through
/// the seal (kind 13) to the rumor (kind 14), the plaintext message is
/// persisted here for offline access and reactive UI queries.
@DataClassName('DirectMessageRow')
class DirectMessages extends Table {
  @override
  String get tableName => 'direct_messages';

  /// The rumor event ID (kind 14/15 id field).
  TextColumn get id => text()();

  /// Deterministic conversation identifier (SHA-256 of sorted participant
  /// pubkeys). Shared by all messages in the same chat room.
  TextColumn get conversationId => text().named('conversation_id')();

  /// Public key of the message sender.
  TextColumn get senderPubkey => text().named('sender_pubkey')();

  /// For kind 14: decrypted plaintext content.
  /// For kind 15: the encrypted file URL.
  TextColumn get content => text()();

  /// Unix timestamp from the rumor event's created_at.
  IntColumn get createdAt => integer().named('created_at')();

  /// Optional parent message ID (from `e` tag) for threaded replies.
  TextColumn get replyToId => text().nullable().named('reply_to_id')();

  /// The gift-wrap event ID (kind 1059) used for deduplication.
  TextColumn get giftWrapId => text().named('gift_wrap_id')();

  /// Optional conversation subject/title (from `subject` tag).
  TextColumn get subject => text().nullable()();

  /// JSON-encoded tags from the decrypted NIP-17 rumor event.
  TextColumn get tagsJson => text().nullable().named('tags_json')();

  /// The inner event kind: 14 (text) or 15 (file). Defaults to 14.
  IntColumn get messageKind =>
      integer().withDefault(const Constant(14)).named('message_kind')();

  // ---- Kind 15 file metadata (null for kind 14) ----

  /// MIME type of the file before encryption (e.g. `image/jpeg`).
  TextColumn get fileType => text().nullable().named('file_type')();

  /// Encryption algorithm (e.g. `aes-gcm`).
  TextColumn get encryptionAlgorithm =>
      text().nullable().named('encryption_algorithm')();

  /// Hex-encoded AES key for file decryption.
  TextColumn get decryptionKey => text().nullable().named('decryption_key')();

  /// Hex-encoded nonce/IV for file decryption.
  TextColumn get decryptionNonce =>
      text().nullable().named('decryption_nonce')();

  /// SHA-256 hex hash of the encrypted file.
  TextColumn get fileHash => text().nullable().named('file_hash')();

  /// SHA-256 hex hash of the original file before encryption.
  TextColumn get originalFileHash =>
      text().nullable().named('original_file_hash')();

  /// Size of the encrypted file in bytes.
  IntColumn get fileSize => integer().nullable().named('file_size')();

  /// Dimensions in `<width>x<height>` format.
  TextColumn get dimensions => text().nullable()();

  /// BlurHash string for image preview.
  TextColumn get blurhash => text().nullable()();

  /// URL of an encrypted thumbnail (same key/nonce).
  TextColumn get thumbnailUrl => text().nullable().named('thumbnail_url')();

  /// Whether this message has been soft-deleted via a NIP-09 kind 5 event.
  ///
  /// Soft-deleting (rather than hard-deleting) preserves the `giftWrapId` so
  /// the dedup check (`hasGiftWrap`) continues to reject the relay
  /// re-delivering the gift-wrapped event on the next poll cycle.
  BoolColumn get isDeleted =>
      boolean().withDefault(const Constant(false)).named('is_deleted')();

  /// Whether this row has already absorbed its cross-protocol twin.
  ///
  /// A dual-send puts one message on the wire twice — a NIP-17 rumor and a
  /// NIP-04 event with unrelated ids — so nothing but the
  /// `(sender, content, ~time)` window can collapse them. That window matched
  /// on *existence*, so one stored copy absorbed every later same-text arrival
  /// inside it, and a peer's genuine repeat was lost in the NIP-04-first
  /// ordering — the very symptom #7324 was filed for, surviving in the other
  /// direction (#8211).
  ///
  /// A twin is 1:1: one message on the wire twice yields exactly one
  /// counterpart, so a row may absorb exactly one. This marks the row that
  /// already did. Self-send matching does not use it — any number of echoes
  /// may legitimately match the user's own persisted send.
  BoolColumn get twinCollapsed =>
      boolean().withDefault(const Constant(false)).named('twin_collapsed')();

  /// Hex public key of the account that received/sent this message.
  ///
  /// Part of the primary key. A NIP-17 group send seals ONE rumor for every
  /// recipient, so two local accounts in the same room receive distinct gift
  /// wraps carrying an identical rumor id, and each must be able to hold its
  /// own row (#6645).
  ///
  /// NOT NULL with an empty-string default rather than nullable, because
  /// SQLite compares NULLs as *distinct* inside a unique constraint: a
  /// nullable owner in the key would stop two legacy rows that share a rumor
  /// id from collapsing, silently weakening the dedup this table relies on.
  /// `''` is already this schema's legacy sentinel — `clearForAccountSwitch`
  /// and `clearUnowned` have always treated `NULL` and `''` alike. Rows
  /// written before multi-account support are backfilled to `''` by the v12
  /// migration.
  TextColumn get ownerPubkey =>
      text().withDefault(const Constant('')).named('owner_pubkey')();

  /// Durable, collision-proof identity of one send invocation. Set on the
  /// sender's local message for 1:1 sends and shared by the single local
  /// message representing a group fan-out. A self-wrap received on another
  /// device preserves it; peer-authored and legacy messages leave it NULL. It
  /// gives same-second 1:1 sends distinct rumor ids and lets group recovery and
  /// optimistic UI grouping match a fan-out by an exact value instead of the
  /// collision-prone `(sender, content, created_at ±5s)` tuple.
  TextColumn get sendBatchId => text().nullable().named('send_batch_id')();

  /// Serialized kind-5 rumor for an own delete-for-everyone that is awaiting
  /// confirmed delivery or was blocked. Null for every other row.
  ///
  /// Stored rather than rebuilt so every retry replays a byte-identical rumor
  /// id, keeping one retraction one kind-5 however many attempts it takes.
  /// Receive-side dedup does not collapse the repeats — it is keyed on
  /// gift-wrap id and NIP-59 gives every wrap a fresh ephemeral key — so what
  /// makes them harmless is that re-applying a deletion is a no-op. Mirrors
  /// `DmReactions.rumorEventJson`, which serves the same purpose for a
  /// reaction removal.
  TextColumn get deletionRumorJson =>
      text().nullable().named('deletion_rumor_json')();

  /// Delivery state of the kind-5 in [deletionRumorJson]; null when the row
  /// carries no own deletion. Values: `deletion_pending` (soft-deleted
  /// locally, wrap awaiting a confirmed relay `OK`), `deletion_sent`
  /// (confirmed, terminal), `deletion_blocked` (send policy blocked every
  /// failed recipient, terminal; other recipients may have succeeded).
  ///
  /// Reaction removals likewise record a distinct `deletion_refused` status
  /// in their publish-status column. A block describes the current attempt,
  /// not whether the original message or reaction was previously delivered.
  /// Both distinct values stop automatic retries without asserting delivery.
  TextColumn get deletionPublishStatus =>
      text().nullable().named('deletion_publish_status')();

  /// Owner-scoped so the same immutable rumor id can be represented once per
  /// local account. NIP-17 seals one rumor per group message and NIP-59 wraps
  /// it separately for each recipient, so on a device holding two accounts in
  /// the same room both wraps decrypt to one id — which a global key could
  /// only store once, dropping the second account's copy (#6645).
  @override
  Set<Column> get primaryKey => {id, ownerPubkey};

  List<Index> get indexes => [
    Index(
      'idx_dm_conversation_id',
      'CREATE INDEX IF NOT EXISTS idx_dm_conversation_id '
          'ON direct_messages (conversation_id)',
    ),
    Index(
      'idx_dm_conversation_created',
      'CREATE INDEX IF NOT EXISTS idx_dm_conversation_created '
          'ON direct_messages (conversation_id, created_at DESC)',
    ),
    Index(
      'idx_dm_gift_wrap_id',
      'CREATE UNIQUE INDEX IF NOT EXISTS idx_dm_gift_wrap_id '
          'ON direct_messages (gift_wrap_id)',
    ),
    Index(
      'idx_dm_sender',
      'CREATE INDEX IF NOT EXISTS idx_dm_sender '
          'ON direct_messages (sender_pubkey)',
    ),
    Index(
      'idx_dm_owner_pubkey',
      'CREATE INDEX IF NOT EXISTS idx_dm_owner_pubkey '
          'ON direct_messages (owner_pubkey)',
    ),
    Index(
      'idx_dm_owner_conversation',
      'CREATE INDEX IF NOT EXISTS idx_dm_owner_conversation '
          'ON direct_messages (owner_pubkey, conversation_id, created_at DESC)',
    ),
  ];
}

/// Stores NIP-25 emoji reactions on NIP-17 direct messages.
///
/// Reactions ride the same seal+gift-wrap envelope as kind 14/15 messages
/// (NIP-17 spec line 14: "kind 7 reactions may be sent to an encrypted
/// chat"). Each row stores one reaction by one user on one target message.
///
/// Dedup is `(id, owner_pubkey)` — the reaction rumor id is stable across
/// the recipient + self gift-wraps; on a multi-device account both wraps
/// can arrive locally and must collapse to one row.
@DataClassName('DmReactionRow')
class DmMessageReactions extends Table {
  @override
  String get tableName => 'dm_message_reactions';

  /// The reaction rumor event id (kind 7). Stable across recipient + self
  /// wraps. Combined with [ownerPubkey] it forms the dedup key.
  TextColumn get id => text()();

  /// Conversation the target message belongs to. Indexed for chip render.
  TextColumn get conversationId => text().named('conversation_id')();

  /// Rumor id of the kind-14/15 message being reacted to.
  TextColumn get targetMessageId => text().named('target_message_id')();

  /// Pubkey of the author of the target message. Carried so future detail
  /// sheets and NIP-25 `p` tag echoes don't need a join.
  TextColumn get targetMessageAuthor => text().named('target_message_author')();

  /// Pubkey of the user who created this reaction.
  TextColumn get reactorPubkey => text().named('reactor_pubkey')();

  /// Reaction content. Almost always an emoji codepoint; per NIP-25 may
  /// also be a NIP-30 `:shortcode:` (rendered as-is at v1, no lookup).
  TextColumn get emoji => text()();

  /// Unix timestamp from the rumor's `created_at`.
  IntColumn get createdAt => integer().named('created_at')();

  /// The first gift-wrap id we observed carrying this reaction. Kept for
  /// dedup-of-incoming and for relay-replay protection. Nullable for
  /// optimistic rows that have not yet been published.
  TextColumn get giftWrapId => text().nullable().named('gift_wrap_id')();

  /// Hex public key of the account viewing this reaction (multi-account
  /// isolation).
  TextColumn get ownerPubkey => text().named('owner_pubkey')();

  /// Soft-delete marker for NIP-09 kind 5 deletions and for own-reaction
  /// supersede (cap-at-one). Soft delete preserves the audit trail and
  /// blocks stale relay re-delivery from "un-deleting" the row.
  BoolColumn get isDeleted =>
      boolean().withDefault(const Constant(false)).named('is_deleted')();

  /// Serialized rumor JSON for pending rows that may need retry.
  /// Null once successfully published.
  TextColumn get rumorEventJson =>
      text().nullable().named('rumor_event_json')();

  /// Publish status for outgoing rows; null for incoming (received from
  /// relay). Values: `pending`, `sent`, `failed`, `blocked` (send-policy
  /// refused, terminal), `deletion_pending` (soft-deleted, kind-5 awaiting
  /// durable delivery), `deletion_sent` (kind-5 confirmed, terminal), and
  /// `deletion_refused` (automatic retries stopped, retained for user retry).
  TextColumn get publishStatus => text().nullable().named('publish_status')();

  @override
  Set<Column> get primaryKey => {id, ownerPubkey};

  List<Index> get indexes => [
    Index(
      'idx_dm_reactions_target_live',
      'CREATE INDEX IF NOT EXISTS idx_dm_reactions_target_live '
          'ON dm_message_reactions '
          '(conversation_id, target_message_id) '
          'WHERE is_deleted = 0',
    ),
    Index(
      'idx_dm_reactions_reactor',
      'CREATE INDEX IF NOT EXISTS idx_dm_reactions_reactor '
          'ON dm_message_reactions '
          '(target_message_id, reactor_pubkey) '
          'WHERE is_deleted = 0',
    ),
    Index(
      'idx_dm_reactions_owner_created',
      'CREATE INDEX IF NOT EXISTS idx_dm_reactions_owner_created '
          'ON dm_message_reactions (owner_pubkey, created_at)',
    ),
    // Cap-at-one storage invariant (#5419): at most one LIVE reaction per
    // (target_message_id, reactor_pubkey, owner_pubkey). Applied by
    // AppDatabase's v1 normalization SQL after a dedup pass; mirrored here for
    // documentation parity. The getter is not wired through
    // @DriftDatabase(indexes:), so the customStatement is the source of truth.
    Index(
      'idx_dm_reactions_unique_live',
      'CREATE UNIQUE INDEX IF NOT EXISTS idx_dm_reactions_unique_live '
          'ON dm_message_reactions '
          '(target_message_id, reactor_pubkey, owner_pubkey) '
          'WHERE is_deleted = 0',
    ),
  ];
}

/// Denormalized conversation metadata for fast list queries.
///
/// Each row represents a unique chat room defined by the set of participant
/// pubkeys. Updated whenever a new message arrives in the conversation.
@DataClassName('ConversationRow')
class Conversations extends Table {
  @override
  String get tableName => 'conversations';

  /// Deterministic conversation identifier (SHA-256 of sorted participant
  /// pubkeys).
  TextColumn get id => text()();

  /// JSON-encoded list of participant pubkeys (sorted).
  TextColumn get participantPubkeys => text().named('participant_pubkeys')();

  /// Whether this is a group conversation (more than 2 participants).
  BoolColumn get isGroup =>
      boolean().withDefault(const Constant(false)).named('is_group')();

  /// Preview text of the last message.
  TextColumn get lastMessageContent =>
      text().nullable().named('last_message_content')();

  /// Unix timestamp of the last message.
  IntColumn get lastMessageTimestamp =>
      integer().nullable().named('last_message_timestamp')();

  /// Pubkey of the last message sender.
  TextColumn get lastMessageSenderPubkey =>
      text().nullable().named('last_message_sender_pubkey')();

  /// Optional conversation title (from `subject` tag).
  TextColumn get subject => text().nullable()();

  /// Whether the conversation has unread messages.
  BoolColumn get isRead =>
      boolean().withDefault(const Constant(true)).named('is_read')();

  /// Per-conversation read cursor (unix seconds) for cross-device read-state
  /// sync (#4977). Monotonic high-water mark of the newest message the user
  /// has read; published encrypted-to-self over Nostr and restored on
  /// reinstall. NULL until the conversation is first read. Ingest never writes
  /// it — only `ConversationsDao.markAsRead` / `applyReadCursor` advance it,
  /// and only ever forward (`max`).
  IntColumn get lastReadTimestamp =>
      integer().nullable().named('last_read_timestamp')();

  /// Whether the current user has sent a message in this conversation.
  BoolColumn get currentUserHasSent => boolean()
      .withDefault(const Constant(false))
      .named('current_user_has_sent')();

  /// Unix timestamp when the conversation was first created.
  IntColumn get createdAt => integer().named('created_at')();

  /// Hex public key of the account that owns this conversation view.
  ///
  /// Part of the primary key, for the same reason as
  /// [DirectMessages.ownerPubkey]: the conversation id is derived from the
  /// participant set, which is owner-independent, so two local accounts in one
  /// room compute the same id. With a global key the second account's upsert
  /// did not merely fail — `ownerPubkey` merged as `coalesce(excluded, old)`,
  /// so the incoming owner won and the room disappeared from the first
  /// account's inbox (#6645).
  ///
  /// NOT NULL with an empty-string default; see [DirectMessages.ownerPubkey]
  /// for why a nullable column cannot carry this invariant.
  TextColumn get ownerPubkey =>
      text().withDefault(const Constant('')).named('owner_pubkey')();

  /// The DM protocol used for this conversation: 'nip04' or 'nip17'.
  /// NULL when the protocol is unknown (e.g. conversation created before
  /// protocol tracking was added).
  TextColumn get dmProtocol => text().nullable().named('dm_protocol')();

  /// Owner-scoped for the same reason as [DirectMessages]: the id is a hash of
  /// the participant set and carries no owner, so two local accounts in one
  /// room derive the same value (#6645).
  @override
  Set<Column> get primaryKey => {id, ownerPubkey};

  List<Index> get indexes => [
    Index(
      'idx_conversation_last_message',
      'CREATE INDEX IF NOT EXISTS idx_conversation_last_message '
          'ON conversations (last_message_timestamp DESC)',
    ),
    Index(
      'idx_conversation_is_read',
      'CREATE INDEX IF NOT EXISTS idx_conversation_is_read '
          'ON conversations (is_read)',
    ),
    Index(
      'idx_conversation_owner_pubkey',
      'CREATE INDEX IF NOT EXISTS idx_conversation_owner_pubkey '
          'ON conversations (owner_pubkey)',
    ),
  ];
}

/// Stores the current user's own repost events (Kind 16 generic reposts).
///
/// This table tracks the mapping between addressable video IDs and the
/// user's repost event IDs. This mapping is essential for unreposts, which
/// require the repost event ID to create a Kind 5 deletion event.
///
/// Only stores reposts created by the current user, not reposts from others.
@TableIndex.sql(
  'CREATE INDEX IF NOT EXISTS idx_personal_reposts_user '
  'ON personal_reposts (user_pubkey)',
)
@TableIndex.sql(
  'CREATE INDEX IF NOT EXISTS idx_personal_reposts_repost_id '
  'ON personal_reposts (repost_event_id)',
)
@TableIndex.sql(
  'CREATE INDEX IF NOT EXISTS idx_personal_reposts_user_created '
  'ON personal_reposts (user_pubkey, created_at DESC)',
)
@DataClassName('PersonalRepostRow')
class PersonalReposts extends Table {
  @override
  String get tableName => 'personal_reposts';

  /// The addressable ID of the video that was reposted.
  /// Format: `34236:<author_pubkey>:<d-tag>`
  TextColumn get addressableId => text().named('addressable_id')();

  /// The Kind 16 repost event ID created by the user
  TextColumn get repostEventId => text().named('repost_event_id')();

  /// The pubkey of the original video author
  TextColumn get originalAuthorPubkey =>
      text().named('original_author_pubkey')();

  /// The pubkey of the user who created this repost
  TextColumn get userPubkey => text().named('user_pubkey')();

  /// Unix timestamp when the repost was created
  IntColumn get createdAt => integer().named('created_at')();

  @override
  Set<Column> get primaryKey => {addressableId, userPubkey};
}

/// The signed-in user's own Nostr events, replacing the hand-rolled
/// `personal_events` / `personal_events_metadata` Hive boxes (#6986).
///
/// Deliberately has **no `expire_at` column**. `deleteExpiredEvents` on the
/// shared [NostrEvents] table removes rows whose `expire_at` IS NULL as well
/// as past-dated ones, so a personal event stored there would be destroyed on
/// the next cold start. Keeping this data in its own table means the sweep
/// cannot reach it by construction, rather than by exclusion logic that has to
/// stay correct forever.
///
/// Retention is decided per row by [retention] and applied on write:
///
/// * Replaceable kinds (0, 3, 10000-19999) collapse — writing one deletes the
///   previous `(pubkey, kind)` row, so contact-list history cannot accumulate.
///   Before #6986 every follow/unfollow appended a full 42.5 KiB kind-3 row
///   that was never evicted.
/// * Everything else is durable and trimmed to the newest rows per owner. The
///   load-bearing members are the signed-but-unpublished video event that
///   "Try Again" reuses, and the raw tags `sourceOriginalVideoTags` recovers
///   before a metadata edit.
@TableIndex.sql(
  'CREATE INDEX IF NOT EXISTS idx_personal_events_pubkey_kind_created_at '
  'ON personal_events (pubkey, kind, created_at DESC)',
)
@TableIndex.sql(
  'CREATE INDEX IF NOT EXISTS idx_personal_events_pubkey_created_at '
  'ON personal_events (pubkey, created_at DESC)',
)
@DataClassName('PersonalEventRow')
class PersonalEvents extends Table {
  @override
  String get tableName => 'personal_events';

  /// The Nostr event id (64-char hex).
  TextColumn get id => text()();

  /// Author pubkey (64-char hex). Always the signed-in user; the column
  /// exists so reads are an indexed predicate rather than a post-hoc filter,
  /// and so one device can hold several accounts' rows without their costs
  /// leaking into each other.
  TextColumn get pubkey => text()();

  IntColumn get kind => integer()();

  IntColumn get createdAt => integer().named('created_at')();

  /// JSON-encoded array of tag arrays.
  TextColumn get tags => text()();

  TextColumn get content => text()();

  TextColumn get sig => text()();

  /// Retention policy applied when this row was written. See
  /// `PersonalEventRetention` in the DAO.
  IntColumn get retention => integer()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Durable queue of outgoing NIP-17 direct messages.
///
/// Holds rows for messages that the user has attempted to send but whose
/// publish to relays is not yet fully confirmed. NIP-17 is **two**
/// independent kind-1059 publishes (recipient gift wrap + self gift
/// wrap), tracked separately so a partial-delivery state can be retried
/// without re-publishing the recipient wrap and double-delivering.
///
/// Lifecycle:
/// - Insert with both statuses = `pending` immediately before
///   `NIP17MessageService.sendPrivateMessage`.
/// - On result: update each status to `sent` or `failed` based on the
///   per-wrap publish outcome (`NIP17SendResult.success` for recipient,
///   `NIP17SendResult.selfWrapPublished` for self).
/// - When **both** statuses are `sent`: delete the row in the same
///   transaction that inserts the corresponding `direct_messages` row.
///   Atomicity prevents the watcher from observing a window where the
///   message is in neither table.
/// - When **either** status is `failed`: keep the row, populate
///   `last_error` and `last_attempt_at`, increment `retry_count`.
///   Background retry service replays only the still-failed wrap.
///
/// `rumor_event_json` stores the serialized rumor (kind 14/15 unsigned
/// event) so retries re-wrap the **same** rumor — preserves the
/// rumor's `id` (a hash of its fields) so the receiver's gift-wrap
/// dedup correctly drops the duplicate publish on retry.
@DataClassName('OutgoingDmRow')
class OutgoingDms extends Table {
  @override
  String get tableName => 'outgoing_dms';

  /// Opaque durable queue-row handle. It equals the rumor event id for 1:1
  /// and legacy sends. Group sends append the recipient pubkey because one
  /// shared wire rumor needs separate delivery state for each recipient.
  TextColumn get id => text()();

  /// Deterministic conversation identifier (SHA-256 of sorted
  /// participant pubkeys). Same shape as `direct_messages.conversation_id`
  /// so the BLoC can `Rx.combineLatest2(watchMessages, watchOutgoing)`
  /// for a conversation view.
  TextColumn get conversationId => text().named('conversation_id')();

  /// Recipient's hex pubkey for the 1:1 path. (Group sends file one row
  /// per participant — `conversation_id` is the group conversation, but
  /// each row is targeted at one recipient.)
  TextColumn get recipientPubkey => text().named('recipient_pubkey')();

  /// Plaintext message content. Stored alongside `rumor_event_json` so
  /// the UI can render the bubble without re-parsing the rumor on every
  /// rebuild. Authoritative source for retries is `rumor_event_json`.
  TextColumn get content => text()();

  /// Unix timestamp from the rumor event's `created_at`. Stable across
  /// retries because the rumor itself is reused.
  IntColumn get createdAt => integer().named('created_at')();

  /// Serialized JSON of the unsigned NIP-17 rumor (kind 14 or 15). Used
  /// on retry so we re-wrap the same rumor — preserving `rumor.id`,
  /// which is what the receiver's gift-wrap dedup keys on.
  TextColumn get rumorEventJson => text().named('rumor_event_json')();

  /// The rumor event kind (14 = text, 15 = file). Defaults to 14.
  IntColumn get messageKind =>
      integer().withDefault(const Constant(14)).named('message_kind')();

  /// Optional reply target rumor id.
  TextColumn get replyToId => text().nullable().named('reply_to_id')();

  /// Status of the recipient gift-wrap publish: `pending` | `sent` |
  /// `failed`. Stored as a string (rather than an int-coded enum) so a
  /// dump of the table is human-readable. Adding a new state requires a
  /// matching update to `OutgoingWrapStatus` in the DAO — the read
  /// path throws on unknown values rather than silently coercing them
  /// back to `pending` (which would put corrupt or future-schema rows
  /// back into the retry service's active set and risk double-delivery).
  TextColumn get recipientWrapStatus => text().named('recipient_wrap_status')();

  /// Status of the self-addressed gift-wrap publish: same enum as
  /// `recipient_wrap_status`. The `false` value of
  /// `NIP17SendResult.selfWrapPublished` flips this to `failed`; a row
  /// with `recipient: sent, self: failed` is the partial-delivery state
  /// from #3909 / #3902.
  TextColumn get selfWrapStatus => text().named('self_wrap_status')();

  /// Recipient gift-wrap event id (kind 1059) once published. Null while
  /// `recipient_wrap_status` is `pending` or `failed`.
  TextColumn get recipientWrapEventId =>
      text().nullable().named('recipient_wrap_event_id')();

  /// Self gift-wrap event id (kind 1059) once published. Null while
  /// `self_wrap_status` is `pending` or `failed`.
  TextColumn get selfWrapEventId =>
      text().nullable().named('self_wrap_event_id')();

  /// How many publish attempts this row has survived. Caps growth at the
  /// retry policy's max; once exhausted the UI surfaces a manual retry
  /// affordance.
  IntColumn get retryCount =>
      integer().withDefault(const Constant(0)).named('retry_count')();

  /// Last error message from the most recent failed **recipient** wrap
  /// publish. `null` when the recipient wrap has never failed or when the
  /// most recent recipient transition was a success.
  ///
  /// Stored independently of [selfWrapLastError] because the two wraps
  /// fail for different reasons (e.g. recipient relay rejected the
  /// kind-1059 vs ephemeral self-relay timeout) — collapsing both into a
  /// single column would silently overwrite one cause with the other on
  /// the second failure and starve the retry service of useful diagnostics.
  TextColumn get recipientWrapLastError =>
      text().nullable().named('recipient_wrap_last_error')();

  /// Last error message from the most recent failed **self** wrap
  /// publish. Same lifecycle and rationale as [recipientWrapLastError];
  /// kept in its own column so a recipient failure followed by a self
  /// failure preserves both reasons.
  TextColumn get selfWrapLastError =>
      text().nullable().named('self_wrap_last_error')();

  /// Wall-clock timestamp of the most recent publish attempt. Drives
  /// the retry service's backoff scheduling.
  DateTimeColumn get lastAttemptAt =>
      dateTime().nullable().named('last_attempt_at')();

  /// Wall-clock timestamp of the row's creation. Used to order the queue
  /// when retrying.
  DateTimeColumn get queuedAt => dateTime().named('queued_at')();

  /// Hex pubkey of the account that queued this send. Mirrors
  /// `direct_messages.owner_pubkey` for multi-account isolation.
  TextColumn get ownerPubkey => text().named('owner_pubkey')();

  /// Durable, collision-proof identity of one send invocation. A 1:1 send has
  /// one unique value; `sendGroupMessage` stamps one shared value on every
  /// per-recipient sibling. It separates same-second identical sends and lets
  /// group persistence dedup, optimistic grouping, sibling lookup, and
  /// cancellation use an exact value. NULL only for legacy rows. See
  /// `DirectMessages.sendBatchId`.
  TextColumn get sendBatchId => text().nullable().named('send_batch_id')();

  @override
  Set<Column> get primaryKey => {id};

  List<Index> get indexes => [
    Index(
      'idx_outgoing_dms_owner_conversation',
      'CREATE INDEX IF NOT EXISTS idx_outgoing_dms_owner_conversation '
          'ON outgoing_dms (owner_pubkey, conversation_id, created_at DESC)',
    ),
    Index(
      'idx_outgoing_dms_owner_recipient_status',
      'CREATE INDEX IF NOT EXISTS idx_outgoing_dms_owner_recipient_status '
          'ON outgoing_dms (owner_pubkey, recipient_wrap_status)',
    ),
    Index(
      'idx_outgoing_dms_owner_self_status',
      'CREATE INDEX IF NOT EXISTS idx_outgoing_dms_owner_self_status '
          'ON outgoing_dms (owner_pubkey, self_wrap_status)',
    ),
    Index(
      'idx_outgoing_dms_queued_at',
      'CREATE INDEX IF NOT EXISTS idx_outgoing_dms_queued_at '
          'ON outgoing_dms (queued_at)',
    ),
  ];
}

/// Durable, single-row-per-user slot for a profile/username save whose
/// kind-0 publish has not yet been confirmed by a relay.
///
/// Kind 0 is replaceable and one-per-user, so at most one row exists per
/// account — a re-save replaces the row (latest intent wins). The
/// `ProfileSaveRetryService` re-drives this slot on app-foreground and on
/// connectivity/relay-reconnect until a relay confirms the publish, then
/// deletes the row. Fixes #3161: a save attempted while the relay pool is
/// disconnected is delivered when connectivity returns, instead of failing
/// permanently and stranding a claimed-but-unadvertised divine.video username.
@DataClassName('PendingProfileSaveRow')
class PendingProfileSaves extends Table {
  @override
  String get tableName => 'pending_profile_saves';

  /// Owner hex pubkey. Primary key → exactly one pending save per account.
  TextColumn get userPubkey => text().named('user_pubkey')();

  /// Serialized `PendingProfileSave` payload (every `saveProfileEvent` field
  /// the user submitted). Authoritative source for the re-drive.
  TextColumn get payloadJson => text().named('payload_json')();

  /// Whether the divine.video username claim already returned 200 for this
  /// payload, so re-drives skip the (idempotent) HTTP claim round-trip.
  /// Always `true` for saves with no divine.video username to claim
  /// (external NIP-05, or no NIP-05 change).
  BoolColumn get claimConfirmed =>
      boolean().withDefault(const Constant(false)).named('claim_confirmed')();

  /// `pending` | `syncing` | `failed`. Stored as a string for readable
  /// dumps; the DAO throws on an unrecognised value rather than coercing it
  /// back to `pending`.
  TextColumn get status => text().withDefault(const Constant('pending'))();

  /// Publish attempts survived. Backoff caps growth at the policy max; once
  /// exhausted the row moves to `failed` and the UI surfaces a retry.
  IntColumn get retryCount =>
      integer().withDefault(const Constant(0)).named('retry_count')();

  /// Wall-clock timestamp of the most recent publish attempt. Drives the
  /// retry service's backoff scheduling. Null until the first attempt.
  DateTimeColumn get lastAttemptAt =>
      dateTime().nullable().named('last_attempt_at')();

  /// Wall-clock timestamp the row was queued.
  DateTimeColumn get queuedAt => dateTime().named('queued_at')();

  /// Last publish error message, for diagnostics. Null when the most recent
  /// transition was not a failure.
  TextColumn get lastError => text().nullable().named('last_error')();

  /// Immutable per-enqueue token stamped fresh on every `upsert` (a new save
  /// or a manual retry). A background re-drive captures it at read time and
  /// guards every mutation with it, so a newer save that replaces this row
  /// while an older drive is awaiting relay work is never cleared or
  /// reclassified by that stale drive — latest intent wins (#3161 review).
  /// Empty string only on legacy rows written before this column existed.
  TextColumn get generation => text().withDefault(const Constant(''))();

  @override
  Set<Column> get primaryKey => {userPubkey};
}

/// Durable queue of finalized video view events awaiting relay publish.
@DataClassName('PendingViewEventRow')
class PendingViewEvents extends Table {
  @override
  String get tableName => 'pending_view_events';

  TextColumn get id => text()();

  TextColumn get videoId => text().named('video_id')();

  TextColumn get videoPubkey => text().named('video_pubkey')();

  TextColumn get videoVineId => text().nullable().named('video_vine_id')();

  /// The video's addressable `d` tag.
  ///
  /// A kind 22236 view event addresses its subject by `kind:pubkey:d-tag`, so
  /// a queued row without this can never be published. Schema v4 copies a
  /// distinct pre-existing `video_vine_id` into this column; later nulls stay
  /// null and the sweep discards them.
  TextColumn get videoAddressableDTag =>
      text().nullable().named('video_addressable_d_tag')();

  /// The original NIP-71 video event kind, when known.
  IntColumn get videoEventKind =>
      integer().nullable().named('video_event_kind')();

  TextColumn get userPubkey => text().named('user_pubkey')();

  IntColumn get watchDurationMs => integer().named('watch_duration_ms')();

  IntColumn get totalDurationMs =>
      integer().nullable().named('total_duration_ms')();

  IntColumn get loopCount => integer().nullable().named('loop_count')();

  /// Two-phase reporting phase: `start` or `end`.
  ///
  /// NULL marks a pre-phase queued row: a legacy end-of-session event that
  /// must replay WITHOUT a phase tag so the relay still counts its view.
  /// A `start` row carries no watch time; an `end` row contributes loops
  /// only — the relay counts the view on the matching `start` row.
  TextColumn get phase => text().nullable().named('phase')();

  TextColumn get trafficSource => text().named('traffic_source')();

  TextColumn get sourceDetail => text().nullable().named('source_detail')();

  TextColumn get status => text()();

  IntColumn get retryCount =>
      integer().withDefault(const Constant(0)).named('retry_count')();

  TextColumn get lastError => text().nullable().named('last_error')();

  DateTimeColumn get lastAttemptAt =>
      dateTime().nullable().named('last_attempt_at')();

  DateTimeColumn get createdAt => dateTime().named('created_at')();

  @override
  Set<Column> get primaryKey => {id};

  List<Index> get indexes => [
    Index(
      'idx_pending_view_events_user_status',
      'CREATE INDEX IF NOT EXISTS idx_pending_view_events_user_status '
          'ON pending_view_events (user_pubkey, status)',
    ),
    Index(
      'idx_pending_view_events_created_at',
      'CREATE INDEX IF NOT EXISTS idx_pending_view_events_created_at '
          'ON pending_view_events (created_at)',
    ),
  ];
}

/// Durable queue of product analytics events awaiting ingest publish.
@DataClassName('PendingProductEventRow')
class PendingProductEvents extends Table {
  @override
  String get tableName => 'pending_product_events';

  TextColumn get id => text()();

  TextColumn get eventName => text().named('event_name')();

  TextColumn get payloadJson => text().named('payload_json')();

  TextColumn get status => text()();

  IntColumn get attemptCount =>
      integer().withDefault(const Constant(0)).named('attempt_count')();

  DateTimeColumn get nextAttemptAt =>
      dateTime().nullable().named('next_attempt_at')();

  TextColumn get lastError => text().nullable().named('last_error')();

  DateTimeColumn get createdAt => dateTime().named('created_at')();

  /// Hex pubkey of the account that produced this event.
  ///
  /// The flush signs the batch with the *current* account's NIP-98 token, so
  /// events are filtered to the current owner at flush time — otherwise a
  /// logout/login as a different account would publish the prior account's
  /// queued events under the new account's signature. NULL for legacy rows
  /// enqueued before this column existed; those flush under whoever is active.
  TextColumn get ownerPubkey => text().nullable().named('owner_pubkey')();

  @override
  Set<Column> get primaryKey => {id};

  List<Index> get indexes => [
    Index(
      'idx_pending_product_events_status_next_attempt',
      'CREATE INDEX IF NOT EXISTS '
          'idx_pending_product_events_status_next_attempt '
          'ON pending_product_events (status, next_attempt_at)',
    ),
    Index(
      'idx_pending_product_events_owner',
      'CREATE INDEX IF NOT EXISTS idx_pending_product_events_owner '
          'ON pending_product_events (owner_pubkey, status, next_attempt_at)',
    ),
    Index(
      'idx_pending_product_events_created_at',
      'CREATE INDEX IF NOT EXISTS idx_pending_product_events_created_at '
          'ON pending_product_events (created_at)',
    ),
  ];
}

/// Durable queue of gift-wrap (kind 1059) events that failed NIP-44
/// decryption — e.g. a transient Keycast RPC failure while the one-time
/// history drain processes a burst of gift wraps for a remote-signer
/// account. Persisting the raw, still-encrypted event lets a later
/// `DmRepository.retryPendingDecryptions` pass recover the conversation
/// without re-fetching from the relay, so flaky remote-signer decryption
/// never permanently loses a chat. See #5202.
@DataClassName('PendingGiftWrapRow')
class PendingGiftWraps extends Table {
  @override
  String get tableName => 'pending_gift_wraps';

  /// The kind 1059 gift-wrap event id (outer). Dedup key with [ownerPubkey].
  TextColumn get giftWrapId => text().named('gift_wrap_id')();

  /// Recipient pubkey this wrap was addressed to (multi-account scope).
  TextColumn get ownerPubkey => text().named('owner_pubkey')();

  /// The raw gift-wrap event JSON, replayed through the decrypt pipeline.
  TextColumn get rawJson => text().named('raw_json')();

  /// Outer gift-wrap `created_at` (unix seconds). Ordering only — NIP-17
  /// randomizes it, so it is not the true message time.
  IntColumn get createdAt => integer().named('created_at')();

  /// Number of decryption attempts so far. Retries stop at a cap so a
  /// permanently-undecryptable wrap cannot loop forever.
  IntColumn get attempts => integer().withDefault(const Constant(0))();

  /// Last attempt time (unix seconds), informational.
  IntColumn get lastAttemptAt =>
      integer().nullable().named('last_attempt_at')();

  @override
  Set<Column> get primaryKey => {giftWrapId, ownerPubkey};

  List<Index> get indexes => [
    Index(
      'idx_pending_gift_wraps_owner_attempts',
      'CREATE INDEX IF NOT EXISTS idx_pending_gift_wraps_owner_attempts '
          'ON pending_gift_wraps (owner_pubkey, attempts)',
    ),
  ];
}

/// Ledger of gift-wrap ids that have already been terminally processed, so a
/// relay re-delivering the same kind-1059 wrap never re-decrypts it.
///
/// Text/file messages (kind 14/15) already dedup via
/// [DirectMessages.giftWrapId]; this table covers the outcomes that write no
/// message row — reactions (kind 7), reaction/deletion (kind 5), unsupported
/// kinds, cross-protocol duplicates, and degenerate participant sets — which
/// otherwise re-decrypted on every launch (a serial remote-signer RPC each).
/// See #5452.
class ProcessedGiftWraps extends Table {
  @override
  String get tableName => 'processed_gift_wraps';

  /// The kind 1059 gift-wrap event id (outer). Dedup key.
  ///
  /// Intentionally NOT scoped by owner: gift-wrap event ids are globally unique
  /// per the Nostr protocol, so cross-account dedup prevents re-processing the
  /// same relay event for multiple local accounts — matching
  /// [DirectMessages.giftWrapId] dedup semantics.
  TextColumn get giftWrapId => text().named('gift_wrap_id')();

  /// When the wrap was terminally processed (unix seconds). Informational and
  /// available for any future time-based retention.
  IntColumn get processedAt => integer().named('processed_at')();

  /// Recipient pubkey this wrap was processed for. Not part of the global
  /// gift-wrap dedup key, but used to scope account cleanup without deleting
  /// another saved account's ledger entries.
  TextColumn get ownerPubkey => text().nullable().named('owner_pubkey')();

  @override
  Set<Column> get primaryKey => {giftWrapId};
}

/// Owner-scoped record of a conversation the user removed locally.
///
/// Relay history is replayable, so deleting the conversation and message rows
/// alone would make old NIP-17 and NIP-04 events eligible for ingestion again.
/// The timestamp suppresses history through the removal instant while still
/// allowing a genuinely newer message to reopen the conversation.
class RemovedConversations extends Table {
  @override
  String get tableName => 'removed_conversations';

  TextColumn get conversationId => text().named('conversation_id')();

  TextColumn get ownerPubkey => text().named('owner_pubkey')();

  /// Unix timestamp when the user removed the conversation.
  IntColumn get removedAt => integer().named('removed_at')();

  @override
  Set<Column> get primaryKey => {conversationId, ownerPubkey};
}

/// Cache of the NIP-39 identity-claims source event per profile.
///
/// One row per viewed profile, mirroring the latest identity event seen on
/// relays. Claims live in kind 10011 since the 2026-02 NIP-39 revision; the
/// verifier web UI publishes kind 10011 only, so kind 0 `i` tags are a
/// legacy fallback for pre-migration profiles (#3936). Rows are refreshed on
/// every profile open (cache+fresh, like `user_profiles`), never expire, and
/// survive logout — same class of viewer-independent public data as
/// [UserProfiles].
@DataClassName('IdentityEventRow')
class IdentityEvents extends Table {
  @override
  String get tableName => 'identity_events';

  /// Hex pubkey of the profile the identity event belongs to.
  TextColumn get pubkey => text()();

  /// JSON-encoded `List<List<String>>` of the event's `i` tags only.
  TextColumn get tagsJson => text().named('tags_json')();

  /// Which event kind the tags came from: 10011 (current spec) or 0
  /// (legacy fallback).
  IntColumn get sourceKind => integer().named('source_kind')();

  /// `created_at` of the kind-10011 event [tagsJson] was taken from.
  ///
  /// Null for a kind-0 fallback row and for rows written before this column
  /// existed. Kind 10011 is replaceable, so this is what lets a later read be
  /// recognised as behind: an event older than the one a row was built from
  /// cannot be the current state of the profile, it is a relay that has not
  /// caught up. The write path refuses to publish on such a base instead of
  /// replacing the event with a set that predates what this device has
  /// already seen (#7081).
  IntColumn get sourceCreatedAt =>
      integer().nullable().named('source_created_at')();

  /// Event id that goes with [sourceCreatedAt], for the NIP-01 same-second
  /// tie (lowest id wins). Null under exactly the same conditions.
  TextColumn get sourceEventId => text().nullable().named('source_event_id')();

  @override
  Set<Column> get primaryKey => {pubkey};
}

/// Persistent cache of NIP-39 identity-claim verification verdicts.
///
/// One row per profile holding the set of claims the verifier confirmed,
/// as a JSON list of `{platform, identity, proof}` tuples. Only
/// `verified: true` results are ever persisted — negative results are not
/// cached because the verifier returns rate-limit rejections as HTTP-200
/// `verified: false` bodies that must never be frozen locally (#3936).
///
/// Freshness is anchored on the verifier's own `checked_at`:
/// [checkedAtFloor] is the minimum `checked_at` across the batch, and the
/// entry counts as fresh until `checkedAtFloor + 24h` — the verifier's
/// server-side TTL for verified results. Stale entries are re-verified on
/// the next profile open (stale-while-revalidate), not deleted. Rows
/// survive logout, like [Nip05Verifications].
@DataClassName('IdentityVerificationRow')
class IdentityVerifications extends Table {
  @override
  String get tableName => 'identity_verifications';

  /// Hex pubkey of the profile the verified claims belong to.
  TextColumn get pubkey => text()();

  /// JSON-encoded list of verified claim objects
  /// `{"platform": ..., "identity": ..., "proof": ...}`.
  ///
  /// Proof participates in cache matching: a rotated proof no longer
  /// matches its snapshot entry, so the claim re-verifies instead of
  /// serving a stale verdict.
  TextColumn get verifiedClaimsJson => text().named('verified_claims_json')();

  /// Minimum verifier `checked_at` (unix seconds) across the verified
  /// batch. Freshness = `checkedAtFloor + 24h > now`.
  IntColumn get checkedAtFloor => integer().named('checked_at_floor')();

  @override
  Set<Column> get primaryKey => {pubkey};
}

/// Unbounded seen-video set — id + last-seen timestamp only.
///
/// Rich engagement metrics (loops, watch durations) stay in the bounded
/// SharedPreferences `seen_video_metrics` JSON blob (1000 entries). This
/// table holds the minimal membership needed for `wasSeenRecently` so heavy
/// viewers (p90 6,458 distinct/30d, max 19,867) don't truncate history and
/// don't pay multi-MB SharedPreferences rewrites on every watch. Indexed
/// on id (PK) for O(1) membership; `lastSeenAt` lets `wasSeenRecently`
/// answer recency without decoding metrics. TTL pruning (~1yr) keeps the
/// table bounded without a hard cap.
///
/// Write path is idempotent upsert (INSERT OR REPLACE) from
/// `SeenVideosService`; read path is `wasSeenRecently(id, within)` via
/// direct lookup. No foreign key — videos may be deleted from the event
/// table but seen history survives.
@DataClassName('SeenVideoRow')
class SeenVideos extends Table {
  @override
  String get tableName => 'seen_videos';

  /// Nostr event id of the seen video (hex).
  TextColumn get videoId => text().named('video_id')();

  /// Unix milliseconds of first-seen (for diagnostics, not filtering).
  IntColumn get firstSeenAt => integer().named('first_seen_at')();

  /// Unix milliseconds of last-seen — the recency signal.
  IntColumn get lastSeenAt => integer().named('last_seen_at')();

  @override
  Set<Column> get primaryKey => {videoId};

  List<Index> get indexes => [
    Index(
      'idx_seen_videos_last_seen_at',
      'CREATE INDEX IF NOT EXISTS idx_seen_videos_last_seen_at '
          'ON seen_videos (last_seen_at DESC)',
    ),
  ];
}

/// Pubkeys the server has reported as having a NIP-62 request to vanish.

///
/// Exists to *honour* an erasure request rather than to retain data about one:
/// it holds an already-public pubkey and a local timestamp, and it is what
/// keeps a deleted account from re-rendering from cache after a restart. The
/// in-memory equivalent would be session-scoped, and the profile row it guards
/// has been deleted, so there is nothing else left to remember the fact.
///
/// Deliberately **not** cleared by `runStartupCleanup` — a vanish does not
/// expire — and deliberately **not** cleared on logout or account switch, since
/// it is a global network fact rather than per-viewer state. Clearing it on an
/// account switch would resurrect vanished profiles for the other account.
///
/// Rows are removed only when the server reports the account as live again
/// (`ProfileRepository._clearVanish`), so a wrong vanish classification is
/// recoverable rather than permanent.
@DataClassName('VanishedProfileRow')
class VanishedProfiles extends Table {
  @override
  String get tableName => 'vanished_profiles';

  /// Hex pubkey of the account that requested deletion.
  TextColumn get pubkey => text()();

  /// When this device first learned the account had vanished.
  ///
  /// First-seen and stable: re-marking an already-recorded pubkey keeps this
  /// value rather than refreshing it.
  DateTimeColumn get detectedAt => dateTime().named('detected_at')();

  @override
  Set<Column> get primaryKey => {pubkey};
}
