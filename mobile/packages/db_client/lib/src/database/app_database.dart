// ABOUTME: Main Drift database for OpenVine's shared Nostr database.
// ABOUTME: Provides reactive queries for events, profiles, metrics,
// ABOUTME: and uploads.

import 'package:db_client/db_client.dart';
import 'package:drift/drift.dart';
import 'package:meta/meta.dart';

part 'app_database.g.dart';

/// Default retention period for notifications (7 days)
const _notificationRetentionDays = 7;

/// Tables that legacy-v1 normalization creates and the v2 recovery probe
/// checks.
@visibleForTesting
const legacyV1NormalizationRepairTables = <String>[
  'personal_reposts',
  'nip05_verifications',
  'pending_actions',
  'drafts',
  'clips',
  'clip_categories',
  'direct_messages',
  'conversations',
  'outgoing_dms',
  'pending_profile_saves',
  'dm_message_reactions',
  'pending_view_events',
  'pending_product_events',
  'pending_gift_wraps',
  'processed_gift_wraps',
  'identity_events',
  'identity_verifications',
  'vanished_profiles',
  'seen_videos',
];

/// Indexes created by legacy-v1 normalization that the v2 recovery probe
/// checks.
@visibleForTesting
const legacyV1NormalizationRepairIndexes = <String>[
  'idx_event_kind_created_at',
  'idx_event_pubkey_created_at',
  'idx_event_pubkey_kind_d_tag_created_at',
  'idx_event_created_at',
  'idx_event_expire_at',
  'idx_dm_reactions_unique_live',
  'idx_pending_product_events_owner',
  'idx_personal_reactions_addressable_id',
  'idx_notification_owner_timestamp',
  'idx_seen_videos_last_seen_at',
  'idx_clip_category_id',
  'idx_clip_category_owner_pubkey',
];

/// Main application database using Drift
///
/// This database uses SQLite (divine_db.db) to store all Nostr events,
/// user profiles, video metrics, and other app data.
@DriftDatabase(
  tables: [
    // TODO(any): investigate to possibly remove this table if not needed
    NostrEvents,
    UserProfiles,
    VideoMetrics,
    ProfileStats,
    HashtagStats,
    Notifications,
    PendingUploads,
    PersonalReactions,
    PersonalReposts,
    PersonalEvents,
    PendingActions,
    Nip05Verifications,
    Drafts,
    Clips,
    ClipCategories,
    DirectMessages,
    DmMessageReactions,
    Conversations,
    OutgoingDms,
    PendingViewEvents,
    PendingProductEvents,
    PendingGiftWraps,
    ProcessedGiftWraps,
    RemovedConversations,
    PendingProfileSaves,
    IdentityEvents,
    IdentityVerifications,
    SeenVideos,
    VanishedProfiles,
  ],
  daos: [
    UserProfilesDao,
    NostrEventsDao,
    VideoMetricsDao,
    ProfileStatsDao,
    HashtagStatsDao,
    NotificationsDao,
    PendingUploadsDao,
    PersonalEventsDao,
    PersonalReactionsDao,
    PersonalRepostsDao,
    PendingActionsDao,
    Nip05VerificationsDao,
    DraftsDao,
    ClipsDao,
    ClipCategoriesDao,
    DirectMessagesDao,
    DmReactionsDao,
    ConversationsDao,
    OutgoingDmsDao,
    PendingViewEventsDao,
    PendingProductEventsDao,
    PendingGiftWrapsDao,
    ProcessedGiftWrapsDao,
    RemovedConversationsDao,
    PendingProfileSavesDao,
    IdentityEventsDao,
    IdentityVerificationsDao,
    SeenVideosDao,
    VanishedProfilesDao,
  ],
)
class AppDatabase extends _$AppDatabase {
  /// Default constructor - uses platform-appropriate connection
  AppDatabase([QueryExecutor? e]) : super(e ?? openConnection());

  /// Constructor that accepts a custom QueryExecutor (for testing)
  AppDatabase.test(super.e);

  @override
  int get schemaVersion => 13;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
      await _normalizeLegacyV1Schema();
      await _createClipCategoryIndexes();
    },
    onUpgrade: (m, from, to) async {
      if (from < 2) {
        await _normalizeLegacyV1Schema();
      }
      if (from < 3) {
        // Rebuilds the table from the current definition, so it lands on the
        // same shape whether normalization above created the legacy
        // three-column table or the current one.
        await m.alterTable(
          TableMigration(
            identityEvents,
            newColumns: [
              identityEvents.sourceCreatedAt,
              identityEvents.sourceEventId,
            ],
          ),
        );
        await _addColumnIfMissing(
          'profile_statistics',
          'follower_counts_updated_at',
          'INTEGER NULL',
        );
        await _backfillFollowerCountTimestamps();
      }
      if (from < 4) {
        await _migrateToV4ClipCategories(m);
      }
      if (from < 5) {
        // hadUpgrade suppresses the beforeOpen repair on this open, so every
        // earlier idempotent repair has to re-run here or a damaged pre-v5
        // database silently keeps its damage. from == 3 covers databases cut
        // at the original v3, before #6911 folded the follower columns into
        // it; from == 4 covers a clips table mutated out of shape.
        await _repairSchemaV3();
        await _migrateToV4ClipCategories(m);
        await _repairSchemaV5();
      }
      if (from < 6) {
        await _repairSchemaV6();
      }
      if (from < 7) {
        await _createConsolidatedIndexes();
      }
      if (from < 8) {
        // hadUpgrade suppresses the beforeOpen repair on this open, so the
        // whole idempotent chain re-runs here for the same reason the
        // from < 5 block re-runs it: a damaged older database upgrading
        // straight to v8 would otherwise keep its damage until a later
        // launch that happens to perform no upgrade.
        await _repairSchemaV3();
        await _repairSchemaV5();
        await _repairSchemaV6();
        await _createConsolidatedIndexes();
        await _repairSchemaV8();
      }
      if (from < 9) {
        await m.createTable(removedConversations);
      }
      if (from < 10) {
        await _repairSchemaV10();
      }
      if (from < 11) {
        await _repairSchemaV11();
      }
      if (from < 12) {
        await _migrateToV12OwnerScopedDmKeys(m);
      }
      if (from < 13) {
        await m.createTable(personalEvents);
        // `createTable` does not emit `@TableIndex.sql` indexes, so a fresh
        // install and an upgraded database would otherwise disagree on the
        // index set — the same divergence #7040 had to backfill at v7.
        await _createPersonalEventIndexes();
      }
    },
    beforeOpen: (details) async {
      // v1 databases are normalized by onUpgrade. This guarded path remains
      // only as recovery for damaged or manually-mutated databases.
      if (!details.wasCreated &&
          !details.hadUpgrade &&
          await _needsSchemaRepair()) {
        await _normalizeLegacyV1Schema();
        await _repairSchemaV3();
        await _repairSchemaV5();
        await _repairSchemaV6();
        await _createConsolidatedIndexes();
        await _repairSchemaV8();
        await _repairSchemaV10();
        await _repairSchemaV11();
        await _migrateToV12OwnerScopedDmKeys();
      }

      // Run cleanup of expired data on every app startup
      await runStartupCleanup();
    },
  );

  /// Owner-scopes the DM message and conversation keys (#6645).
  ///
  /// A NIP-17 group send seals ONE rumor for every recipient, so a device
  /// holding two local accounts in the same room receives distinct gift wraps
  /// that decrypt to an identical rumor id. Under the previous global keys the
  /// second account's `INSERT OR IGNORE` was a no-op and its copy was lost, and
  /// `conversations` was worse: the id is a hash of the participant set, so the
  /// second account's upsert took the row and the thread vanished from the
  /// first account's inbox.
  ///
  /// Two steps, in this order, and idempotent throughout:
  ///
  /// 1. Backfill `NULL` owners to `''`. This must precede the rebuild, because
  ///    the new column is NOT NULL. `''` is not a new concept — the
  ///    account-switch deletes have always treated `NULL` and `''` alike — and
  ///    it is what keeps legacy dedup working: SQLite compares NULLs as
  ///    *distinct* inside a unique constraint, so leaving the column nullable
  ///    would let two legacy rows sharing a rumor id both insert.
  /// 2. Rebuild both tables so the new composite primary key takes effect, then
  ///    recreate their indexes — SQLite's table-rebuild drops them with the old
  ///    table, and these are declared outside Drift's own index handling.
  /// Processed-wrap ledger rows are deliberately preserved. An unmatched row
  /// can represent a reaction, deletion, unsupported kind, tombstone-suppressed
  /// event, or collapsed protocol twin; v11 stored no outcome that would let a
  /// migration distinguish those legitimate terminal results from a stranded
  /// message. Absence of a message row is therefore not recovery evidence.
  Future<void> _migrateToV12OwnerScopedDmKeys([Migrator? migrator]) async {
    final m = migrator ?? createMigrator();

    await customStatement(
      "UPDATE direct_messages SET owner_pubkey = '' "
      'WHERE owner_pubkey IS NULL',
    );
    await customStatement(
      "UPDATE conversations SET owner_pubkey = '' "
      'WHERE owner_pubkey IS NULL',
    );

    await m.alterTable(TableMigration(directMessages));
    await m.alterTable(TableMigration(conversations));

    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_dm_conversation_id '
      'ON direct_messages (conversation_id)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_dm_conversation_created '
      'ON direct_messages (conversation_id, created_at DESC)',
    );
    await customStatement(
      'CREATE UNIQUE INDEX IF NOT EXISTS idx_dm_gift_wrap_id '
      'ON direct_messages (gift_wrap_id)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_dm_sender '
      'ON direct_messages (sender_pubkey)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_dm_owner_pubkey '
      'ON direct_messages (owner_pubkey)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_dm_owner_conversation '
      'ON direct_messages (owner_pubkey, conversation_id, created_at DESC)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_conversation_last_message '
      'ON conversations (last_message_timestamp DESC)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_conversation_is_read '
      'ON conversations (is_read)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_conversation_owner_pubkey '
      'ON conversations (owner_pubkey)',
    );
  }

  /// Adds the durable delete-for-everyone columns to `direct_messages`.
  ///
  /// A soft-deleted own message now carries the kind-5 rumor it must still
  /// deliver, so an unconfirmed retraction survives a restart and is re-driven
  /// by the retry sweep instead of being dropped (#8165).
  Future<void> _repairSchemaV10() async {
    await _addColumnIfMissing(
      'direct_messages',
      'deletion_rumor_json',
      'TEXT NULL',
    );
    await _addColumnIfMissing(
      'direct_messages',
      'deletion_publish_status',
      'TEXT NULL',
    );
  }

  /// Adds the cross-protocol twin marker to stored DMs (#8211).
  ///
  /// Existing rows default to "no twin absorbed yet". That is the safe
  /// direction: at worst one already-collapsed row absorbs a second twin that
  /// will never arrive, whereas defaulting to collapsed would let a genuine
  /// duplicate through on every historical row.
  Future<void> _repairSchemaV11() async {
    await _addColumnIfMissing(
      'direct_messages',
      'twin_collapsed',
      'INTEGER NOT NULL DEFAULT 0 CHECK ("twin_collapsed" IN (0, 1))',
    );
  }

  /// Adds the two-phase reporting column to the queued view-event outbox.
  Future<void> _repairSchemaV8() async {
    await _addColumnIfMissing('pending_view_events', 'phase', 'TEXT NULL');
  }

  Future<void> _repairSchemaV3() async {
    await _addColumnIfMissing(
      'profile_statistics',
      'follower_counts_updated_at',
      'INTEGER NULL',
    );
    await _backfillFollowerCountTimestamps();
  }

  /// Adds the queued view-event `d` tag column and recovers stuck rows.
  ///
  /// Pre-v4 rows stored a parsed `d` tag only as `video_vine_id`. Copying it
  /// when it is not the event-id fallback lets the stuck backlog publish
  /// (#7169); true nulls stay null so a vine_id-only row cannot mint an
  /// `a` tag.
  Future<void> _repairSchemaV5() async {
    await _addColumnIfMissing(
      'pending_view_events',
      'video_addressable_d_tag',
      'TEXT NULL',
    );
    await customStatement('''
      UPDATE pending_view_events
      SET video_addressable_d_tag = video_vine_id
      WHERE video_addressable_d_tag IS NULL
        AND video_vine_id IS NOT NULL
        AND video_vine_id != ''
        AND video_vine_id != video_id
    ''');
  }

  Future<void> _repairSchemaV6() async {
    await _addColumnIfMissing(
      'pending_view_events',
      'video_event_kind',
      'INTEGER NULL',
    );
  }

  /// Anchors pre-v3 follower counts to the time they were written.
  ///
  /// Rows that predate `follower_counts_updated_at` carry counts with a NULL
  /// timestamp. Backfilling during the v3 upgrade gives the follower freshness
  /// clock a stable anchor without running an UPDATE on every database open.
  Future<void> _backfillFollowerCountTimestamps() async {
    await customStatement(
      'UPDATE profile_statistics '
      'SET follower_counts_updated_at = cached_at '
      'WHERE follower_counts_updated_at IS NULL '
      'AND (follower_count IS NOT NULL OR following_count IS NOT NULL)',
    );
  }

  /// Adds the v4 entities: user-created clip categories and the clip
  /// archive marker.
  Future<void> _migrateToV4ClipCategories(Migrator m) async {
    if (!await _tableExists('clip_categories')) {
      await m.createTable(clipCategories);
    }

    final clipColumns = await _columnNames('clips');
    if (!clipColumns.contains('category_id')) {
      await m.addColumn(clips, clips.categoryId);
    }
    if (!clipColumns.contains('archived_at')) {
      await m.addColumn(clips, clips.archivedAt);
    }
    await _createClipCategoryIndexes();
  }

  Future<void> _createClipCategoriesTableIfMissing() async {
    await customStatement('''
      CREATE TABLE IF NOT EXISTS clip_categories (
        id TEXT NOT NULL,
        name TEXT NOT NULL,
        order_index INTEGER NOT NULL DEFAULT 0,
        created_at INTEGER NOT NULL,
        owner_pubkey TEXT NULL,
        PRIMARY KEY (id)
      )
    ''');
  }

  /// Creates the indexes backing category lookups. Kept out of
  /// [_migrateToV4ClipCategories] so `onCreate` — which builds the tables
  /// through `createAll` rather than the migration steps — gets them too.
  Future<void> _createClipCategoryIndexes() async {
    await customStatement('''
      CREATE INDEX IF NOT EXISTS idx_clip_category_id
      ON clips (category_id)
    ''');
    await customStatement('''
      CREATE INDEX IF NOT EXISTS idx_clip_category_owner_pubkey
      ON clip_categories (owner_pubkey)
    ''');
  }

  /// Creates the `personal_events` indexes (#6986).
  ///
  /// Kept beside the table's `@TableIndex.sql` annotations, which Drift uses
  /// for `createAll()` on a fresh install but not for `createTable()` during
  /// an upgrade.
  Future<void> _createPersonalEventIndexes() async {
    await customStatement(
      'CREATE INDEX IF NOT EXISTS '
      'idx_personal_events_pubkey_kind_created_at '
      'ON personal_events (pubkey, kind, created_at DESC)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_personal_events_pubkey_created_at '
      'ON personal_events (pubkey, created_at DESC)',
    );
  }

  /// Creates all indexes consolidated from explicit `List<Index>` getters.
  ///
  /// The `List<Index> get indexes` getters these replace were never read by
  /// Drift, so none of these indexes exist on any shipped database (#7040).
  /// v7 moves the definitions into `@TableIndex.sql()` annotations, which
  /// `createAll` honours; this backfills them for every database that already
  /// exists.
  Future<void> _createConsolidatedIndexes() async {
    // VideoMetrics indices
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_metrics_loop_count '
      'ON video_metrics (loop_count)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_metrics_likes ON video_metrics (likes)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_metrics_views ON video_metrics (views)',
    );

    // HashtagStats indices
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_hashtag_video_count '
      'ON hashtag_stats (video_count DESC)',
    );

    // Notifications indices
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_notification_timestamp '
      'ON notifications (timestamp DESC)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_notification_is_read '
      'ON notifications (is_read)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_notification_owner_timestamp '
      'ON notifications (owner_pubkey, timestamp DESC)',
    );

    // PendingUploads indices
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_pending_upload_status '
      'ON pending_uploads (status)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_pending_upload_created '
      'ON pending_uploads (created_at DESC)',
    );

    // PersonalReactions indices
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_personal_reactions_user '
      'ON personal_reactions (user_pubkey)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_personal_reactions_reaction_id '
      'ON personal_reactions (reaction_event_id)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_personal_reactions_addressable_id '
      'ON personal_reactions (addressable_id)',
    );

    // PersonalReposts indices
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_personal_reposts_user '
      'ON personal_reposts (user_pubkey)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_personal_reposts_repost_id '
      'ON personal_reposts (repost_event_id)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_personal_reposts_user_created '
      'ON personal_reposts (user_pubkey, created_at DESC)',
    );
  }

  /// Normalizes all historical schema drift from version 1 to version 2.
  ///
  /// Before v2, new tables, columns, indexes, and data backfills were added
  /// through startup repair SQL while the Drift user-version stayed at 1. All
  /// shipped legacy databases therefore report version 1 regardless of which
  /// subset of this schema they already have. This idempotent migration brings
  /// those databases to the current schema before Drift records version 2.
  Future<void> _normalizeLegacyV1Schema() async {
    // Check if personal_reposts table exists, create if missing
    final repostsResult = await customSelect(
      "SELECT name FROM sqlite_master WHERE type='table' "
      "AND name='personal_reposts'",
    ).get();

    if (repostsResult.isEmpty) {
      await customStatement('''
        CREATE TABLE personal_reposts (
          addressable_id TEXT NOT NULL,
          repost_event_id TEXT NOT NULL,
          original_author_pubkey TEXT NOT NULL,
          user_pubkey TEXT NOT NULL,
          created_at INTEGER NOT NULL,
          PRIMARY KEY (addressable_id, user_pubkey)
        )
      ''');
    }

    // Check if nip05_verifications table exists, create if missing
    final nip05Result = await customSelect(
      "SELECT name FROM sqlite_master WHERE type='table' "
      "AND name='nip05_verifications'",
    ).get();

    if (nip05Result.isEmpty) {
      await customStatement('''
        CREATE TABLE nip05_verifications (
          pubkey TEXT NOT NULL PRIMARY KEY,
          nip05 TEXT NOT NULL,
          status TEXT NOT NULL,
          verified_at INTEGER NOT NULL,
          expires_at INTEGER NOT NULL
        )
      ''');
      await customStatement('''
        CREATE INDEX IF NOT EXISTS idx_nip05_expires_at
        ON nip05_verifications (expires_at)
      ''');
    }

    // Check if pending_actions table exists, create if missing
    final pendingActionsResult = await customSelect(
      "SELECT name FROM sqlite_master WHERE type='table' "
      "AND name='pending_actions'",
    ).get();

    if (pendingActionsResult.isEmpty) {
      await customStatement('''
        CREATE TABLE pending_actions (
          id TEXT NOT NULL PRIMARY KEY,
          type TEXT NOT NULL,
          target_id TEXT NOT NULL,
          author_pubkey TEXT,
          addressable_id TEXT,
          target_kind INTEGER,
          status TEXT NOT NULL,
          user_pubkey TEXT NOT NULL,
          created_at INTEGER NOT NULL,
          retry_count INTEGER NOT NULL DEFAULT 0,
          last_error TEXT,
          last_attempt_at INTEGER
        )
      ''');
      await customStatement('''
        CREATE INDEX IF NOT EXISTS idx_pending_action_status
        ON pending_actions (status)
      ''');
      await customStatement('''
        CREATE INDEX IF NOT EXISTS idx_pending_action_user
        ON pending_actions (user_pubkey)
      ''');
      await customStatement('''
        CREATE INDEX IF NOT EXISTS idx_pending_action_user_status
        ON pending_actions (user_pubkey, status)
      ''');
      await customStatement('''
        CREATE INDEX IF NOT EXISTS idx_pending_action_created
        ON pending_actions (created_at)
      ''');
    }

    // Check if drafts table exists, create if missing
    final draftsResult = await customSelect(
      "SELECT name FROM sqlite_master WHERE type='table' "
      "AND name='drafts'",
    ).get();

    if (draftsResult.isEmpty) {
      await customStatement('''
        CREATE TABLE drafts (
          id TEXT NOT NULL PRIMARY KEY,
          title TEXT NOT NULL DEFAULT '',
          description TEXT NOT NULL DEFAULT '',
          publish_status TEXT NOT NULL DEFAULT 'draft',
          publish_attempts INTEGER NOT NULL DEFAULT 0,
          publish_error TEXT,
          created_at INTEGER NOT NULL,
          last_modified INTEGER NOT NULL,
          data TEXT NOT NULL
        )
      ''');
      await customStatement('''
        CREATE INDEX IF NOT EXISTS idx_draft_publish_status
        ON drafts (publish_status)
      ''');
      await customStatement('''
        CREATE INDEX IF NOT EXISTS idx_draft_last_modified
        ON drafts (last_modified DESC)
      ''');
      await customStatement('''
        CREATE INDEX IF NOT EXISTS idx_draft_created_at
        ON drafts (created_at DESC)
      ''');
    }

    // Check if clips table exists, create if missing
    final clipsResult = await customSelect(
      "SELECT name FROM sqlite_master WHERE type='table' "
      "AND name='clips'",
    ).get();

    if (clipsResult.isEmpty) {
      await customStatement('''
        CREATE TABLE clips (
          id TEXT NOT NULL PRIMARY KEY,
          draft_id TEXT,
          order_index INTEGER NOT NULL DEFAULT 0,
          duration_ms INTEGER NOT NULL,
          recorded_at INTEGER NOT NULL,
          data TEXT NOT NULL,
          FOREIGN KEY (draft_id) REFERENCES drafts(id) ON DELETE CASCADE
        )
      ''');
      await customStatement('''
        CREATE INDEX IF NOT EXISTS idx_clip_draft_id
        ON clips (draft_id)
      ''');
      await customStatement('''
        CREATE INDEX IF NOT EXISTS idx_clip_draft_order
        ON clips (draft_id, order_index)
      ''');
      await customStatement('''
        CREATE INDEX IF NOT EXISTS idx_clip_recorded_at
        ON clips (recorded_at DESC)
      ''');
    }

    // Create partial index unconditionally (for new and existing databases)
    await customStatement('''
      CREATE INDEX IF NOT EXISTS idx_clip_library
      ON clips (draft_id) WHERE draft_id IS NULL
    ''');

    // Add file_path / thumbnail_path columns to clips (if missing)
    await _addColumnIfMissing('clips', 'file_path', 'TEXT');
    await _addColumnIfMissing('clips', 'thumbnail_path', 'TEXT');
    await customStatement('''
      CREATE INDEX IF NOT EXISTS idx_clip_file_path
      ON clips (file_path)
    ''');
    await customStatement('''
      CREATE INDEX IF NOT EXISTS idx_clip_thumbnail_path
      ON clips (thumbnail_path)
    ''');

    // Add indexed draft-owned file reference columns (if missing)
    await _addColumnIfMissing('drafts', 'rendered_file_path', 'TEXT');
    await _addColumnIfMissing('drafts', 'rendered_thumbnail_path', 'TEXT');
    await _addColumnIfMissing('drafts', 'custom_thumbnail_path', 'TEXT');
    await customStatement('''
      CREATE INDEX IF NOT EXISTS idx_draft_rendered_file_path
      ON drafts (rendered_file_path)
    ''');
    await customStatement('''
      CREATE INDEX IF NOT EXISTS idx_draft_rendered_thumbnail_path
      ON drafts (rendered_thumbnail_path)
    ''');
    await customStatement('''
      CREATE INDEX IF NOT EXISTS idx_draft_custom_thumbnail_path
      ON drafts (custom_thumbnail_path)
    ''');

    // Add owner_pubkey columns for multi-account isolation
    await _addColumnIfMissing('drafts', 'owner_pubkey', 'TEXT');
    await _addColumnIfMissing('clips', 'owner_pubkey', 'TEXT');
    await customStatement('''
      CREATE INDEX IF NOT EXISTS idx_draft_owner_pubkey
      ON drafts (owner_pubkey)
    ''');
    await customStatement('''
      CREATE INDEX IF NOT EXISTS idx_clip_owner_pubkey
      ON clips (owner_pubkey)
    ''');

    // Notifications are viewer-scoped but shipped without an owner column,
    // so every signed-in account read one shared inbox. Existing rows stay
    // NULL and are claimed by the next session setup, matching drafts/clips.
    await _addColumnIfMissing('notifications', 'owner_pubkey', 'TEXT');
    await _ensureNotificationsCompositePrimaryKey();
    await customStatement('''
      CREATE INDEX IF NOT EXISTS idx_notification_owner_timestamp
      ON notifications (owner_pubkey, timestamp DESC)
    ''');

    // Soft-delete marker for clip trash bin. NULL = active; non-NULL =
    // trashed at that timestamp. Purged after the retention window.
    await _addColumnIfMissing('clips', 'deleted_at', 'INTEGER');
    await customStatement('''
      CREATE INDEX IF NOT EXISTS idx_clip_deleted_at
      ON clips (deleted_at)
    ''');

    await _addColumnIfMissing('clips', 'category_id', 'TEXT NULL');
    await _addColumnIfMissing('clips', 'archived_at', 'INTEGER NULL');
    await _createClipCategoriesTableIfMissing();
    await _createClipCategoryIndexes();

    // Check if direct_messages table exists, create if missing
    final dmResult = await customSelect(
      "SELECT name FROM sqlite_master WHERE type='table' "
      "AND name='direct_messages'",
    ).get();

    if (dmResult.isEmpty) {
      await customStatement('''
        CREATE TABLE direct_messages (
          id TEXT NOT NULL PRIMARY KEY,
          conversation_id TEXT NOT NULL,
          sender_pubkey TEXT NOT NULL,
          content TEXT NOT NULL,
          created_at INTEGER NOT NULL,
          reply_to_id TEXT,
          gift_wrap_id TEXT NOT NULL,
          subject TEXT,
          tags_json TEXT,
          message_kind INTEGER NOT NULL DEFAULT 14,
          file_type TEXT,
          encryption_algorithm TEXT,
          decryption_key TEXT,
          decryption_nonce TEXT,
          file_hash TEXT,
          original_file_hash TEXT,
          file_size INTEGER,
          dimensions TEXT,
          blurhash TEXT,
          thumbnail_url TEXT
        )
      ''');
      await customStatement('''
        CREATE INDEX IF NOT EXISTS idx_dm_conversation_id
        ON direct_messages (conversation_id)
      ''');
      await customStatement('''
        CREATE INDEX IF NOT EXISTS idx_dm_conversation_created
        ON direct_messages (conversation_id, created_at DESC)
      ''');
      await customStatement('''
        CREATE UNIQUE INDEX IF NOT EXISTS idx_dm_gift_wrap_id
        ON direct_messages (gift_wrap_id)
      ''');
      await customStatement('''
        CREATE INDEX IF NOT EXISTS idx_dm_sender
        ON direct_messages (sender_pubkey)
      ''');
    }

    // Add Kind 15 file metadata columns to direct_messages (if missing)
    await _addColumnIfMissing(
      'direct_messages',
      'message_kind',
      'INTEGER NOT NULL DEFAULT 14',
    );
    await _addColumnIfMissing('direct_messages', 'file_type', 'TEXT');
    await _addColumnIfMissing(
      'direct_messages',
      'encryption_algorithm',
      'TEXT',
    );
    await _addColumnIfMissing('direct_messages', 'decryption_key', 'TEXT');
    await _addColumnIfMissing('direct_messages', 'decryption_nonce', 'TEXT');
    await _addColumnIfMissing('direct_messages', 'file_hash', 'TEXT');
    await _addColumnIfMissing('direct_messages', 'original_file_hash', 'TEXT');
    await _addColumnIfMissing('direct_messages', 'file_size', 'INTEGER');
    await _addColumnIfMissing('direct_messages', 'dimensions', 'TEXT');
    await _addColumnIfMissing('direct_messages', 'blurhash', 'TEXT');
    await _addColumnIfMissing('direct_messages', 'thumbnail_url', 'TEXT');
    await _addColumnIfMissing('direct_messages', 'tags_json', 'TEXT');

    // Check if conversations table exists, create if missing
    final convResult = await customSelect(
      "SELECT name FROM sqlite_master WHERE type='table' "
      "AND name='conversations'",
    ).get();

    if (convResult.isEmpty) {
      await customStatement('''
        CREATE TABLE conversations (
          id TEXT NOT NULL PRIMARY KEY,
          participant_pubkeys TEXT NOT NULL,
          is_group INTEGER NOT NULL DEFAULT 0,
          last_message_content TEXT,
          last_message_timestamp INTEGER,
          last_message_sender_pubkey TEXT,
          subject TEXT,
          is_read INTEGER NOT NULL DEFAULT 1,
          current_user_has_sent INTEGER NOT NULL DEFAULT 0,
          created_at INTEGER NOT NULL
        )
      ''');
      await customStatement('''
        CREATE INDEX IF NOT EXISTS idx_conversation_last_message
        ON conversations (last_message_timestamp DESC)
      ''');
      await customStatement('''
        CREATE INDEX IF NOT EXISTS idx_conversation_is_read
        ON conversations (is_read)
      ''');
    }

    // Add current_user_has_sent column to existing conversations tables.
    await _addColumnIfMissing(
      'conversations',
      'current_user_has_sent',
      'INTEGER NOT NULL DEFAULT 0',
    );

    // Add owner_pubkey columns for multi-account DM isolation
    await _addColumnIfMissing('direct_messages', 'owner_pubkey', 'TEXT');
    await _addColumnIfMissing('conversations', 'owner_pubkey', 'TEXT');

    // Add dm_protocol column for NIP-04/NIP-17 protocol tracking
    await _addColumnIfMissing('conversations', 'dm_protocol', 'TEXT');

    // Add last_read_timestamp read cursor for cross-device read-state sync
    // (#4977). Backfill already-read rows once so the upgrade doesn't surface
    // a one-time unread bump. The WHERE clause makes it self-idempotent: once
    // a row has a non-null cursor (set here or by markAsRead) it is skipped on
    // subsequent launches.
    await _addColumnIfMissing(
      'conversations',
      'last_read_timestamp',
      'INTEGER',
    );
    await customStatement(
      'UPDATE conversations SET last_read_timestamp = last_message_timestamp '
      'WHERE last_read_timestamp IS NULL AND is_read = 1 '
      'AND last_message_timestamp IS NOT NULL',
    );

    // Add is_deleted column for NIP-09 kind 5 soft-delete support
    await _addColumnIfMissing(
      'direct_messages',
      'is_deleted',
      'INTEGER NOT NULL DEFAULT 0',
    );
    // Ensure the UNIQUE index on gift_wrap_id exists unconditionally.
    // It was originally inside the "if table missing" block, so databases
    // created by Drift's m.createAll() were missing it.
    await customStatement('''
      CREATE UNIQUE INDEX IF NOT EXISTS idx_dm_gift_wrap_id
      ON direct_messages (gift_wrap_id)
    ''');
    await customStatement('''
      CREATE INDEX IF NOT EXISTS idx_dm_owner_pubkey
      ON direct_messages (owner_pubkey)
    ''');
    await customStatement('''
      CREATE INDEX IF NOT EXISTS idx_dm_owner_conversation
      ON direct_messages (owner_pubkey, conversation_id, created_at DESC)
    ''');
    await customStatement('''
      CREATE INDEX IF NOT EXISTS idx_conversation_owner_pubkey
      ON conversations (owner_pubkey)
    ''');

    // Check if outgoing_dms table exists, create if missing.
    // Added for #3909 (durable outgoing-DM queue + self-wrap retry).
    final outgoingDmsResult = await customSelect(
      "SELECT name FROM sqlite_master WHERE type='table' "
      "AND name='outgoing_dms'",
    ).get();

    if (outgoingDmsResult.isEmpty) {
      await customStatement('''
        CREATE TABLE outgoing_dms (
          id TEXT NOT NULL PRIMARY KEY,
          conversation_id TEXT NOT NULL,
          recipient_pubkey TEXT NOT NULL,
          content TEXT NOT NULL,
          created_at INTEGER NOT NULL,
          rumor_event_json TEXT NOT NULL,
          message_kind INTEGER NOT NULL DEFAULT 14,
          reply_to_id TEXT,
          recipient_wrap_status TEXT NOT NULL,
          self_wrap_status TEXT NOT NULL,
          recipient_wrap_event_id TEXT,
          self_wrap_event_id TEXT,
          retry_count INTEGER NOT NULL DEFAULT 0,
          recipient_wrap_last_error TEXT,
          self_wrap_last_error TEXT,
          last_attempt_at INTEGER,
          queued_at INTEGER NOT NULL,
          owner_pubkey TEXT NOT NULL
        )
      ''');
    }
    // Create indexes unconditionally (for new and existing databases).
    // Drift's `m.createAll()` doesn't register the `List<Index> get
    // indexes` getter on `OutgoingDms` (the project doesn't wire them
    // through `@DriftDatabase(indexes: ...)`), so a Drift-created fresh
    // install would otherwise have the table but none of its indexes,
    // and `getRetryableForOwner` / `getStillPendingForOwner` would fall
    // back to a full table scan. Hoisting the CREATE INDEX statements
    // outside the "if table missing" block makes the runtime path the
    // single source of truth for the index set on both new and existing
    // databases — and makes the fresh-install vs runtime-create paths
    // emit identical schemas, which the schema-parity test in
    // `app_database_test.dart` pins.
    await customStatement('''
      CREATE INDEX IF NOT EXISTS idx_outgoing_dms_owner_conversation
      ON outgoing_dms (owner_pubkey, conversation_id, created_at DESC)
    ''');
    await customStatement('''
      CREATE INDEX IF NOT EXISTS idx_outgoing_dms_owner_recipient_status
      ON outgoing_dms (owner_pubkey, recipient_wrap_status)
    ''');
    await customStatement('''
      CREATE INDEX IF NOT EXISTS idx_outgoing_dms_owner_self_status
      ON outgoing_dms (owner_pubkey, self_wrap_status)
    ''');
    await customStatement('''
      CREATE INDEX IF NOT EXISTS idx_outgoing_dms_queued_at
      ON outgoing_dms (queued_at)
    ''');

    // Check if pending_profile_saves table exists, create if missing.
    // Added for #3161 (durable profile/username save + background re-drive).
    // Column order/types/defaults must match Drift's
    // `m.createAll()` output (pinned by the pending_profile_saves schema-parity
    // test in app_database_test.dart): bool → INTEGER DEFAULT 0 with a
    // CHECK (x IN (0,1)); DateTime columns → INTEGER (seconds codec).
    final pendingProfileSavesResult = await customSelect(
      "SELECT name FROM sqlite_master WHERE type='table' "
      "AND name='pending_profile_saves'",
    ).get();

    if (pendingProfileSavesResult.isEmpty) {
      await customStatement('''
        CREATE TABLE pending_profile_saves (
          user_pubkey TEXT NOT NULL PRIMARY KEY,
          payload_json TEXT NOT NULL,
          claim_confirmed INTEGER NOT NULL DEFAULT 0 CHECK ("claim_confirmed" IN (0, 1)),
          status TEXT NOT NULL DEFAULT 'pending',
          retry_count INTEGER NOT NULL DEFAULT 0,
          last_attempt_at INTEGER,
          queued_at INTEGER NOT NULL,
          last_error TEXT,
          generation TEXT NOT NULL DEFAULT ''
        )
      ''');
    }

    // Check if dm_message_reactions table exists, create if missing.
    // Added for #4633 (DM emoji reactions).
    final dmReactionsResult = await customSelect(
      "SELECT name FROM sqlite_master WHERE type='table' "
      "AND name='dm_message_reactions'",
    ).get();

    if (dmReactionsResult.isEmpty) {
      await customStatement('''
        CREATE TABLE dm_message_reactions (
          id TEXT NOT NULL,
          conversation_id TEXT NOT NULL,
          target_message_id TEXT NOT NULL,
          target_message_author TEXT NOT NULL,
          reactor_pubkey TEXT NOT NULL,
          emoji TEXT NOT NULL,
          created_at INTEGER NOT NULL,
          gift_wrap_id TEXT,
          owner_pubkey TEXT NOT NULL,
          is_deleted INTEGER NOT NULL DEFAULT 0,
          rumor_event_json TEXT,
          publish_status TEXT,
          PRIMARY KEY (id, owner_pubkey)
        )
      ''');
    }
    // Create indexes unconditionally so the runtime path matches Drift's
    // m.createAll() output (the dm_message_reactions schema-parity test in
    // app_database_test.dart pins this).
    await customStatement('''
      CREATE INDEX IF NOT EXISTS idx_dm_reactions_target_live
      ON dm_message_reactions (conversation_id, target_message_id)
      WHERE is_deleted = 0
    ''');
    await customStatement('''
      CREATE INDEX IF NOT EXISTS idx_dm_reactions_reactor
      ON dm_message_reactions (target_message_id, reactor_pubkey)
      WHERE is_deleted = 0
    ''');
    await customStatement('''
      CREATE INDEX IF NOT EXISTS idx_dm_reactions_owner_created
      ON dm_message_reactions (owner_pubkey, created_at)
    ''');

    // Cap-at-one storage invariant (#5419): at most one LIVE reaction per
    // (target_message_id, reactor_pubkey, owner_pubkey). The dedup UPDATE
    // MUST run before CREATE UNIQUE INDEX — SQLite refuses to build a unique
    // index over rows that already violate it. It soft-deletes every live row
    // that has a strictly-newer live sibling in its tuple, keeping the single
    // MAX(created_at, id) row. The created_at half matches the read-side
    // DmReactionsRepository._collapsePerReactor keep-rule; the id tie-break is
    // an extra deterministic guard the read side lacks, and only diverges on
    // equal-created_at distinct ids — impossible once the unique index caps
    // each tuple to one live row. The statement is idempotent: once converged
    // (and once the unique index self-enforces) no row has a newer sibling, so
    // subsequent startups match nothing.
    await customStatement('''
      UPDATE dm_message_reactions
      SET is_deleted = 1
      WHERE is_deleted = 0
        AND EXISTS (
          SELECT 1 FROM dm_message_reactions AS newer
          WHERE newer.target_message_id = dm_message_reactions.target_message_id
            AND newer.reactor_pubkey = dm_message_reactions.reactor_pubkey
            AND newer.owner_pubkey = dm_message_reactions.owner_pubkey
            AND newer.is_deleted = 0
            AND (newer.created_at > dm_message_reactions.created_at
              OR (newer.created_at = dm_message_reactions.created_at
                  AND newer.id > dm_message_reactions.id))
        )
    ''');
    await customStatement('''
      CREATE UNIQUE INDEX IF NOT EXISTS idx_dm_reactions_unique_live
      ON dm_message_reactions (target_message_id, reactor_pubkey, owner_pubkey)
      WHERE is_deleted = 0
    ''');

    final pendingViewEventsResult = await customSelect(
      "SELECT name FROM sqlite_master WHERE type='table' "
      "AND name='pending_view_events'",
    ).get();

    if (pendingViewEventsResult.isEmpty) {
      await customStatement('''
        CREATE TABLE pending_view_events (
          id TEXT NOT NULL PRIMARY KEY,
          video_id TEXT NOT NULL,
          video_pubkey TEXT NOT NULL,
          video_vine_id TEXT,
          video_addressable_d_tag TEXT,
          video_event_kind INTEGER,
          user_pubkey TEXT NOT NULL,
          watch_duration_ms INTEGER NOT NULL,
          total_duration_ms INTEGER,
          loop_count INTEGER,
          phase TEXT,
          traffic_source TEXT NOT NULL,
          source_detail TEXT,
          status TEXT NOT NULL,
          retry_count INTEGER NOT NULL DEFAULT 0,
          last_error TEXT,
          last_attempt_at INTEGER,
          created_at INTEGER NOT NULL
        )
      ''');
    }
    await customStatement('''
      CREATE INDEX IF NOT EXISTS idx_pending_view_events_user_status
      ON pending_view_events (user_pubkey, status)
    ''');
    await customStatement('''
      CREATE INDEX IF NOT EXISTS idx_pending_view_events_created_at
      ON pending_view_events (created_at)
    ''');

    final pendingProductEventsResult = await customSelect(
      "SELECT name FROM sqlite_master WHERE type='table' "
      "AND name='pending_product_events'",
    ).get();

    if (pendingProductEventsResult.isEmpty) {
      await customStatement('''
        CREATE TABLE pending_product_events (
          id TEXT NOT NULL PRIMARY KEY,
          event_name TEXT NOT NULL,
          payload_json TEXT NOT NULL,
          status TEXT NOT NULL,
          attempt_count INTEGER NOT NULL DEFAULT 0,
          next_attempt_at INTEGER,
          last_error TEXT,
          created_at INTEGER NOT NULL
        )
      ''');
    }
    await customStatement('''
      CREATE INDEX IF NOT EXISTS idx_pending_product_events_status_next_attempt
      ON pending_product_events (status, next_attempt_at)
    ''');
    await customStatement('''
      CREATE INDEX IF NOT EXISTS idx_pending_product_events_created_at
      ON pending_product_events (created_at)
    ''');
    // Owner scoping so the flush only publishes the current account's queued
    // events (see PendingProductEvents.ownerPubkey). Legacy rows stay NULL.
    await _addColumnIfMissing('pending_product_events', 'owner_pubkey', 'TEXT');
    await customStatement('''
      CREATE INDEX IF NOT EXISTS idx_pending_product_events_owner
      ON pending_product_events (owner_pubkey, status, next_attempt_at)
    ''');

    // Check if pending_gift_wraps table exists, create if missing.
    // Added for #5202 (durable failed-decrypt gift-wrap retry queue).
    final pendingGiftWrapsResult = await customSelect(
      "SELECT name FROM sqlite_master WHERE type='table' "
      "AND name='pending_gift_wraps'",
    ).get();

    if (pendingGiftWrapsResult.isEmpty) {
      await customStatement('''
        CREATE TABLE pending_gift_wraps (
          gift_wrap_id TEXT NOT NULL,
          owner_pubkey TEXT NOT NULL,
          raw_json TEXT NOT NULL,
          created_at INTEGER NOT NULL,
          attempts INTEGER NOT NULL DEFAULT 0,
          last_attempt_at INTEGER,
          PRIMARY KEY (gift_wrap_id, owner_pubkey)
        )
      ''');
    }
    // Create the index unconditionally so the runtime path matches Drift's
    // m.createAll() output (the schema-parity test pins this).
    await customStatement('''
      CREATE INDEX IF NOT EXISTS idx_pending_gift_wraps_owner_attempts
      ON pending_gift_wraps (owner_pubkey, attempts)
    ''');

    // Check if processed_gift_wraps table exists, create if missing.
    // Added for #5452 (dedup ledger so DM reaction/deletion gift wraps are not
    // re-decrypted on every launch). No index: the only access is a primary-key
    // lookup on gift_wrap_id.
    final processedGiftWrapsResult = await customSelect(
      "SELECT name FROM sqlite_master WHERE type='table' "
      "AND name='processed_gift_wraps'",
    ).get();

    if (processedGiftWrapsResult.isEmpty) {
      await customStatement('''
        CREATE TABLE processed_gift_wraps (
          gift_wrap_id TEXT NOT NULL,
          processed_at INTEGER NOT NULL,
          owner_pubkey TEXT,
          PRIMARY KEY (gift_wrap_id)
        )
      ''');
    }

    // Check if identity_events table exists, create if missing.
    // Added for #3936 (NIP-39 kind-10011 source + verification cache).
    // Column order/types must match Drift's
    // m.createAll() output (pinned by the schema-parity tests in
    // app_database_test.dart).
    final identityEventsResult = await customSelect(
      "SELECT name FROM sqlite_master WHERE type='table' "
      "AND name='identity_events'",
    ).get();

    if (identityEventsResult.isEmpty) {
      await customStatement('''
        CREATE TABLE identity_events (
          pubkey TEXT NOT NULL PRIMARY KEY,
          tags_json TEXT NOT NULL,
          source_kind INTEGER NOT NULL,
          source_created_at INTEGER NULL,
          source_event_id TEXT NULL
        )
      ''');
    }

    // The staleness stamps arrived in v3 on an already-existing table, so a
    // damaged database can carry identity_events without them. Recreating the
    // table above only covers the missing-table case; these two cover the
    // missing-column case that the v3 upgrade would otherwise be the only
    // path to.
    await _addColumnIfMissing(
      'identity_events',
      'source_created_at',
      'INTEGER NULL',
    );
    await _addColumnIfMissing(
      'identity_events',
      'source_event_id',
      'TEXT NULL',
    );

    // Check if identity_verifications table exists, create if missing.
    // Added for #3936 — same pattern as identity_events above. No index:
    // the only access is a primary-key lookup on pubkey.
    final identityVerificationsResult = await customSelect(
      "SELECT name FROM sqlite_master WHERE type='table' "
      "AND name='identity_verifications'",
    ).get();

    if (identityVerificationsResult.isEmpty) {
      await customStatement('''
        CREATE TABLE identity_verifications (
          pubkey TEXT NOT NULL PRIMARY KEY,
          verified_claims_json TEXT NOT NULL,
          checked_at_floor INTEGER NOT NULL
        )
      ''');
    }

    // Check if vanished_profiles table exists, create if missing.
    // Column order/types must match Drift's
    // m.createAll() output (pinned by the schema-parity tests in
    // app_database_test.dart). No index: the only access is a primary-key
    // lookup on pubkey.
    final vanishedProfilesResult = await customSelect(
      "SELECT name FROM sqlite_master WHERE type='table' "
      "AND name='vanished_profiles'",
    ).get();

    if (vanishedProfilesResult.isEmpty) {
      await customStatement('''
        CREATE TABLE vanished_profiles (
          pubkey TEXT NOT NULL PRIMARY KEY,
          detected_at INTEGER NOT NULL
        )
      ''');
    }

    // Check if seen_videos table exists, create if missing.
    // Added for client-seen filtering (unbounded id+lastSeen, ~1yr TTL).
    // Schema version stays at 1 — same runtime CREATE-IF-NOT-EXISTS pattern
    // as vanished_profiles above. Column order/types must match Drift's
    // m.createAll() output. Single index on last_seen_at for TTL pruning.
    final seenVideosResult = await customSelect(
      "SELECT name FROM sqlite_master WHERE type='table' "
      "AND name='seen_videos'",
    ).get();

    if (seenVideosResult.isEmpty) {
      await customStatement('''
        CREATE TABLE seen_videos (
          video_id TEXT NOT NULL,
          first_seen_at INTEGER NOT NULL,
          last_seen_at INTEGER NOT NULL,
          PRIMARY KEY (video_id)
        )
      ''');
    }
    await customStatement('''
      CREATE INDEX IF NOT EXISTS idx_seen_videos_last_seen_at
      ON seen_videos (last_seen_at DESC)
    ''');

    // Denormalized NIP-33 d-tag column so replaceable-event upserts can use
    // an indexed lookup instead of decoding the tags JSON of every
    // (pubkey, kind) row (on-device profiling: ~23% of main-isolate CPU).
    await _addColumnIfMissing('event', 'd_tag', 'TEXT');

    // Durable group-send batch identity (PR #6046). Nullable TEXT on both DM
    // tables. Fresh installs get it from Drift's createAll(); this ALTER only
    // fires for DBs created before the column existed. See tables.dart for the
    // semantics.
    await _addColumnIfMissing('outgoing_dms', 'send_batch_id', 'TEXT');
    await _addColumnIfMissing('direct_messages', 'send_batch_id', 'TEXT');

    // Addressable coordinate for own-like state, so it survives a target
    // edit that mints a new event id for the same coordinate (#6020).
    await _addColumnIfMissing('personal_reactions', 'addressable_id', 'TEXT');
    await customStatement('''
      CREATE INDEX IF NOT EXISTS idx_personal_reactions_addressable_id
      ON personal_reactions (addressable_id)
    ''');

    // Stable video route for cached notification placeholders. Video-sourced
    // mention rows and edited NIP-33 videos should not jump row type or route
    // through stale event ids while waiting for the first REST refresh.
    await _addColumnIfMissing('notifications', 'video_addressable_id', 'TEXT');
    await _addColumnIfMissing(
      'notifications',
      'has_comment_target',
      'INTEGER NOT NULL DEFAULT 0',
    );

    // Create the event indexes unconditionally. The `List<Index> get
    // indexes` getter on NostrEvents is not wired through
    // `@DriftDatabase(...)`, so Drift's m.createAll() never creates them —
    // this runtime path is the source of truth for the index set (same
    // pattern as outgoing_dms above; keep in sync with tables.dart).
    await customStatement('''
      CREATE INDEX IF NOT EXISTS idx_event_kind_created_at
      ON event (kind, created_at)
    ''');
    await customStatement('''
      CREATE INDEX IF NOT EXISTS idx_event_pubkey_created_at
      ON event (pubkey, created_at)
    ''');
    // The trailing created_at makes the replaceable-upsert MAX(created_at)
    // lookup a covering-index seek; without it SQLite's min/max
    // optimization picks idx_event_kind_created_at and reverse-scans the
    // kind partition (PR #5957 review). The DROP cleans up the narrower
    // predecessor index from pre-release builds of this change.
    await customStatement('DROP INDEX IF EXISTS idx_event_pubkey_kind_d_tag');
    await customStatement('''
      CREATE INDEX IF NOT EXISTS idx_event_pubkey_kind_d_tag_created_at
      ON event (pubkey, kind, d_tag, created_at)
    ''');
    await customStatement('''
      CREATE INDEX IF NOT EXISTS idx_event_created_at
      ON event (created_at)
    ''');
    await customStatement('''
      CREATE INDEX IF NOT EXISTS idx_event_expire_at
      ON event (expire_at)
    ''');

    // Populate new columns from existing JSON data blobs
    await _backfillFilePathColumns();
    await _backfillEventDTagColumn();
  }

  /// Returns true when a v2 database is missing schema that v1 normalization
  /// would have supplied. This is deliberately a recovery probe, not the
  /// primary migration mechanism for future schema changes.
  Future<bool> _needsSchemaRepair() async {
    for (final table in legacyV1NormalizationRepairTables) {
      if (!await _tableExists(table)) {
        return true;
      }
    }

    const requiredColumns = <String, List<String>>{
      'event': ['d_tag'],
      'clips': [
        'file_path',
        'thumbnail_path',
        'owner_pubkey',
        'deleted_at',
        'category_id',
        'archived_at',
      ],
      'drafts': [
        'rendered_file_path',
        'rendered_thumbnail_path',
        'custom_thumbnail_path',
        'owner_pubkey',
      ],
      'notifications': [
        'owner_pubkey',
        'video_addressable_id',
        'has_comment_target',
      ],
      'direct_messages': [
        'message_kind',
        'file_type',
        'encryption_algorithm',
        'decryption_key',
        'decryption_nonce',
        'file_hash',
        'original_file_hash',
        'file_size',
        'dimensions',
        'blurhash',
        'thumbnail_url',
        'tags_json',
        'owner_pubkey',
        'is_deleted',
        'send_batch_id',
      ],
      'conversations': [
        'current_user_has_sent',
        'owner_pubkey',
        'dm_protocol',
        'last_read_timestamp',
      ],
      'pending_product_events': ['owner_pubkey'],
      'outgoing_dms': ['send_batch_id'],
      'personal_reactions': ['addressable_id'],
      'profile_statistics': ['follower_counts_updated_at'],
      'identity_events': ['source_created_at', 'source_event_id'],
      'pending_view_events': [
        'video_addressable_d_tag',
        'video_event_kind',
        'phase',
      ],
    };

    for (final entry in requiredColumns.entries) {
      final columns = await _columnNames(entry.key);
      if (entry.value.any((column) => !columns.contains(column))) {
        return true;
      }
    }

    for (final index in legacyV1NormalizationRepairIndexes) {
      if (!await _indexExists(index)) {
        return true;
      }
    }

    return false;
  }

  Future<bool> _tableExists(String table) async {
    final rows = await customSelect(
      "SELECT name FROM sqlite_master WHERE type='table' AND name = ?",
      variables: [Variable.withString(table)],
    ).get();
    return rows.isNotEmpty;
  }

  Future<bool> _indexExists(String index) async {
    final rows = await customSelect(
      "SELECT name FROM sqlite_master WHERE type='index' AND name = ?",
      variables: [Variable.withString(index)],
    ).get();
    return rows.isNotEmpty;
  }

  Future<Set<String>> _columnNames(String table) async {
    final columns = await customSelect('PRAGMA table_info($table)').get();
    return columns.map((row) => row.read<String>('name')).toSet();
  }

  /// Adds a column to a table if it does not already exist.
  Future<void> _addColumnIfMissing(
    String table,
    String column,
    String type,
  ) async {
    final columns = await customSelect('PRAGMA table_info($table)').get();
    final exists = columns.any((row) => row.read<String>('name') == column);
    if (!exists) {
      await customStatement('ALTER TABLE $table ADD COLUMN $column $type');
    }
  }

  /// Rebuilds old `notifications` tables that were keyed only by `id`.
  Future<void> _ensureNotificationsCompositePrimaryKey() async {
    final columns = await customSelect(
      'PRAGMA table_info(notifications)',
    ).get();
    if (columns.isEmpty) return;

    int? ownerPk;
    for (final row in columns) {
      if (row.read<String>('name') == 'owner_pubkey') {
        ownerPk = row.read<int>('pk');
        break;
      }
    }
    if (ownerPk != null && ownerPk > 0) return;

    await customStatement('DROP INDEX IF EXISTS idx_notification_timestamp');
    await customStatement('DROP INDEX IF EXISTS idx_notification_is_read');
    await customStatement(
      'DROP INDEX IF EXISTS idx_notification_owner_timestamp',
    );
    await customStatement(
      'ALTER TABLE notifications RENAME TO notifications_old_pk',
    );
    await customStatement('''
      CREATE TABLE notifications (
        id TEXT NOT NULL,
        type TEXT NOT NULL,
        from_pubkey TEXT NOT NULL,
        target_event_id TEXT NULL,
        target_pubkey TEXT NULL,
        content TEXT NULL,
        timestamp INTEGER NOT NULL,
        is_read INTEGER NOT NULL DEFAULT 0 CHECK (is_read IN (0, 1)),
        cached_at INTEGER NOT NULL,
        owner_pubkey TEXT NULL,
        PRIMARY KEY (id, owner_pubkey)
      )
    ''');
    await customStatement('''
      INSERT OR IGNORE INTO notifications (
        id,
        type,
        from_pubkey,
        target_event_id,
        target_pubkey,
        content,
        timestamp,
        is_read,
        cached_at,
        owner_pubkey
      )
      SELECT
        id,
        type,
        from_pubkey,
        target_event_id,
        target_pubkey,
        content,
        timestamp,
        is_read,
        cached_at,
        owner_pubkey
      FROM notifications_old_pk
    ''');
    await customStatement('DROP TABLE notifications_old_pk');
  }

  /// Populates file_path / thumbnail_path columns from JSON data blobs
  /// for rows where they are still NULL.
  Future<void> _backfillFilePathColumns() async {
    // Clips: backfill file_path where missing
    await customStatement(r'''
      UPDATE clips
      SET file_path = json_extract(data, '$.filePath')
      WHERE file_path IS NULL
    ''');

    // Clips: backfill thumbnail_path where missing
    await customStatement(r'''
      UPDATE clips
      SET thumbnail_path = json_extract(data, '$.thumbnailPath')
      WHERE thumbnail_path IS NULL
    ''');

    // Drafts: backfill rendered_file_path where missing
    await customStatement(r'''
      UPDATE drafts
      SET rendered_file_path = json_extract(
            data, '$.finalRenderedClip.filePath'
          )
      WHERE rendered_file_path IS NULL
    ''');

    // Drafts: backfill rendered_thumbnail_path where missing
    await customStatement(r'''
      UPDATE drafts
      SET rendered_thumbnail_path = json_extract(
            data, '$.finalRenderedClip.thumbnailPath'
          )
      WHERE rendered_thumbnail_path IS NULL
    ''');

    // Drafts: backfill custom_thumbnail_path where missing
    await customStatement(r'''
      UPDATE drafts
      SET custom_thumbnail_path = json_extract(data, '$.customThumbnailPath')
      WHERE custom_thumbnail_path IS NULL
    ''');
  }

  /// Populates the denormalized d_tag column for parameterized replaceable
  /// events (kind 30000-39999) that were written before the column existed.
  ///
  /// Matches NostrEventsDao's d-tag semantics: the value of the first 'd'
  /// tag, '' when the tag has no value or the event has no d-tag (NIP-01).
  /// Idempotent — once a row has a non-NULL d_tag it is skipped.
  Future<void> _backfillEventDTagColumn() async {
    await customStatement(r'''
      UPDATE event
      SET d_tag = COALESCE(
        (
          SELECT COALESCE(json_extract(tag.value, '$[1]'), '')
          FROM json_each(event.tags) AS tag
          WHERE json_extract(tag.value, '$[0]') = 'd'
          ORDER BY tag.key
          LIMIT 1
        ),
        ''
      )
      WHERE d_tag IS NULL AND kind >= 30000 AND kind < 40000
    ''');
  }

  /// Runs cleanup of expired data from all tables.
  ///
  /// This method should be called during app startup to remove:
  /// - Expired Nostr events (based on expire_at timestamp, including NULL)
  /// - Expired profile stats (older than 5 minutes)
  /// - Expired hashtag stats (older than 1 hour)
  /// - Notification cache rows written more than 7 days ago
  ///
  /// Returns a [CleanupResult] with counts of deleted records.
  Future<CleanupResult> runStartupCleanup() async {
    // Delete expired events (also deletes events with NULL expire_at)
    final expiredEventsDeleted = await nostrEventsDao.deleteExpiredEvents(null);

    // Delete expired profile stats (5 minute expiry)
    final expiredProfileStatsDeleted = await profileStatsDao.deleteExpired();

    // Delete expired hashtag stats (1 hour expiry)
    final expiredHashtagStatsDeleted = await hashtagStatsDao.deleteExpired();

    // Delete notification cache rows written more than 7 days ago. Retention
    // is keyed on when the row was cached, not the notification's own age, so
    // still-current notifications about older events survive to hydrate the
    // next cold start.
    final notificationCutoff = DateTime.now().subtract(
      const Duration(days: _notificationRetentionDays),
    );
    final oldNotificationsDeleted = await notificationsDao.deleteCachedBefore(
      notificationCutoff,
    );

    return CleanupResult(
      expiredEventsDeleted: expiredEventsDeleted,
      expiredProfileStatsDeleted: expiredProfileStatsDeleted,
      expiredHashtagStatsDeleted: expiredHashtagStatsDeleted,
      oldNotificationsDeleted: oldNotificationsDeleted,
    );
  }
}
