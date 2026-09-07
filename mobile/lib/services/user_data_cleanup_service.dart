// ABOUTME: Service to clear user-specific cached data when identity changes
// ABOUTME: Prevents data leakage between different Nostr accounts after reinstall

import 'package:creator_sync/creator_sync.dart';
import 'package:nostr_sdk/nip19/pubkey_for_logs.dart';
import 'package:openvine/services/age_verification_service.dart';
import 'package:openvine/services/creator_sync/prefs_sync_state_store.dart';
import 'package:openvine/services/saved_sounds_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:unified_logger/unified_logger.dart';

/// Service to clean up user-specific data from SharedPreferences.
///
/// When a user reinstalls the app (without proper logout) and creates a new
/// identity, cached data from the previous user may persist. This service
/// detects identity changes and clears user-specific data to prevent
/// data leakage between accounts.
class UserDataCleanupService {
  UserDataCleanupService(this._prefs);

  final SharedPreferences _prefs;

  /// Optional callback invoked during cleanup to clear user-specific
  /// database tables (DMs, conversations, notifications, per-user DAOs).
  /// Set by the provider layer which has access to DAOs.
  ///
  /// Parameters:
  /// - [userPubkey]: the signing-out user's pubkey for scoped deletion.
  /// - [deleteUserData]: when true, per-user DAO rows (drafts, clips,
  ///   uploads, reactions, reposts, pending actions) are deleted.
  ///   False on non-destructive sign-out (account switch) to preserve data.
  /// - [preserveActiveSession]: skips device-wide teardown while deleting a
  ///   different account from the device.
  Future<void> Function({
    String? userPubkey,
    bool deleteUserData,
    bool preserveActiveSession,
  })?
  onDatabaseCleanup;

  /// Optional callback invoked during session setup to claim legacy
  /// database rows (NULL ownerPubkey) for the current user.
  /// This prevents pre-multi-account rows from leaking across accounts.
  /// Set by the provider layer which has access to DAOs.
  Future<void> Function(String userPubkey)? onClaimLegacyRows;

  /// Keys that store user-specific data and should be cleared on identity change.
  /// Device/app settings like relay URLs, analytics preferences are NOT included.
  static const List<String> userSpecificKeys = [
    // List services
    'curated_lists',
    'curated_lists_default_deleted',
    'subscribed_list_ids',
    'user_lists',
    // Bookmark services
    'bookmark_sets',
    'global_bookmarks',
    'global_bookmarks_revision',
    'bookmark_published_hashes',
    'bookmark_pending_changes',
    // Mute/moderation services
    'muted_items',
    'content_moderation_local_mutes',
    'content_moderation_subscribed_lists',
    // Content history
    'content_reports_history',
    'content_deletions_history',
    // Viewing history
    'seen_video_ids',
    'seen_video_metrics',
    // Labeler subscriptions
    'subscribed_labelers',
    'label_cache',
    // Report aggregation
    'trusted_reporters',
    'report_cache',
    // TOS acceptance (user must re-accept on new account)
    'age_verified_16_plus',
    'terms_accepted_at',
  ];

  /// Legacy owner-scoped preference keys that contain user data but may still
  /// need to survive a same-user non-destructive logout.
  static const List<String> ownerScopedLegacyKeys = ['vine_drafts'];

  static const String legacyDraftOwnerKey = 'vine_drafts_owner_pubkey_hex';

  /// Key prefixes for dynamic user-specific data (keys that embed pubkey/npub).
  /// Only cleared on identity change (different user), NOT on same-user logout.
  /// These caches are keyed by pubkey so they can't leak between users, and the
  /// redirect logic needs following_list_ at login time before relay responds.
  static const List<String> identityChangePrefixes = [
    'following_list_', // follow cache per pubkey
    'following_prefetch_complete_', // successful auth prefetch per pubkey
    'relay_discovery_', // relay discovery cache per npub
  ];

  /// Checks if user-specific data should be cleared for the given pubkey.
  ///
  /// Returns true if:
  /// - A different user was previously logged in (pubkey mismatch)
  /// - No pubkey stored but user-specific data exists (orphaned data)
  ///
  /// Returns false if:
  /// - Same user is logging in (pubkey matches)
  /// - Fresh install with no existing data
  bool shouldClearDataForUser(String currentPubkeyHex) {
    final storedPubkey = _prefs.getString('current_user_pubkey_hex');

    // If same user, no cleanup needed
    if (storedPubkey == currentPubkeyHex) {
      return false;
    }

    // If different user was stored, cleanup needed
    if (storedPubkey != null && storedPubkey != currentPubkeyHex) {
      return true;
    }

    // No stored pubkey - check if orphaned user data exists. Owner-scoped
    // legacy data may belong to the same account after Remove from Device; keep
    // it only when the preserved owner marker matches the logging-in pubkey.
    for (final key in userSpecificKeys) {
      if (_prefs.containsKey(key)) {
        return true;
      }
    }
    for (final key in ownerScopedLegacyKeys) {
      if (!_prefs.containsKey(key)) continue;
      if (key == 'vine_drafts' &&
          _prefs.getString(legacyDraftOwnerKey) == currentPubkeyHex) {
        continue;
      }
      return true;
    }

    // Fresh install, no cleanup needed
    return false;
  }

  /// Marks preserved legacy owner-scoped data as belonging to [userPubkey].
  ///
  /// Remove-from-device clears the current-session pubkey while intentionally
  /// preserving local drafts. This marker lets the next same-user login migrate
  /// those drafts without treating them as foreign orphaned data.
  Future<void> markOwnerScopedLegacyDataForUser(String userPubkey) async {
    if (_prefs.containsKey('vine_drafts')) {
      await _prefs.setString(legacyDraftOwnerKey, userPubkey);
    }
  }

  /// Deletes only data whose ownership can be attributed to [userPubkey].
  ///
  /// [preserveActiveSession] is false when no other account session needs
  /// device-wide state preserved.
  ///
  /// Throws [StateError] when a preference cannot be removed and propagates
  /// database cleanup failures so callers can retry the incomplete deletion.
  Future<int> deleteAccountData(
    String userPubkey, {
    required String userNpub,
    required bool preserveActiveSession,
  }) async {
    var clearedCount = 0;

    Future<void> remove(String key) async {
      if (!_prefs.containsKey(key)) return;
      if (!await _prefs.remove(key)) {
        throw StateError('Could not remove account data');
      }
      clearedCount++;
    }

    if (!preserveActiveSession) {
      for (final key in userSpecificKeys) {
        await remove(key);
      }
      final draftOwner = _prefs.getString(legacyDraftOwnerKey);
      if (draftOwner == null || draftOwner == userPubkey) {
        for (final key in ownerScopedLegacyKeys) {
          await remove(key);
        }
        await remove(legacyDraftOwnerKey);
      }
    }

    if (_prefs.getString(legacyDraftOwnerKey) == userPubkey) {
      for (final key in ownerScopedLegacyKeys) {
        await remove(key);
      }
      await remove(legacyDraftOwnerKey);
    }

    await remove(SavedSoundsService.accountStorageKey(userPubkey));
    for (final kind in SyncItemKind.values) {
      await remove(PrefsSyncStateStore.appliedStorageKey(kind, userPubkey));
    }
    for (final key in AgeVerificationService.accountKeys(userPubkey)) {
      await remove(key);
    }
    await remove('following_list_$userPubkey');
    await remove('following_prefetch_complete_$userPubkey');
    await remove('relay_discovery_$userNpub');

    await onDatabaseCleanup?.call(
      userPubkey: userPubkey,
      deleteUserData: true,
      preserveActiveSession: preserveActiveSession,
    );
    return clearedCount;
  }

  /// Clears all user-specific data from SharedPreferences.
  ///
  /// This removes cached lists, bookmarks, mutes, viewing history,
  /// and other user-specific data while preserving device/app settings
  /// like relay URLs, analytics preferences, etc.
  ///
  /// Returns the number of keys that were cleared for tracking purposes.
  /// Clears user-specific data from SharedPreferences.
  ///
  /// When [isIdentityChange] is true (different user logging in), also clears
  /// dynamic pubkey-keyed caches (following_list_, relay/blossom discovery).
  /// On same-user logout these are preserved so the redirect logic can use them
  /// at login time before relay data is available.
  Future<int> clearUserSpecificData({
    String? reason,
    bool isIdentityChange = false,
    String? userPubkey,
    bool deleteUserData = false,
  }) async {
    final cleanupReason = reason ?? 'unspecified';
    Log.info(
      'Starting user data cleanup (reason: $cleanupReason, '
      'identityChange: $isIdentityChange, '
      'deleteUserData: $deleteUserData, '
      'userPubkey: ${pubkeyForLogs(userPubkey, whenNull: "null")}, '
      'checking ${userSpecificKeys.length} keys'
      '${isIdentityChange ? ' + ${identityChangePrefixes.length} prefixes' : ''})',
      name: 'UserDataCleanupService',
      category: LogCategory.auth,
    );

    int clearedCount = 0;
    final clearedKeys = <String>[];

    // Clear exact-match keys (always)
    for (final key in userSpecificKeys) {
      if (_prefs.containsKey(key)) {
        await _prefs.remove(key);
        clearedCount++;
        clearedKeys.add(key);
      }
    }

    if (deleteUserData || isIdentityChange) {
      for (final key in ownerScopedLegacyKeys) {
        if (_prefs.containsKey(key)) {
          await _prefs.remove(key);
          clearedCount++;
          clearedKeys.add(key);
        }
      }
      if (_prefs.containsKey(legacyDraftOwnerKey)) {
        await _prefs.remove(legacyDraftOwnerKey);
        clearedCount++;
        clearedKeys.add(legacyDraftOwnerKey);
      }
    }

    // The per-account saved-sounds bucket holds audio ids, urls, and metadata.
    // Drop it only on a destructive delete of a known account — a plain account
    // switch keeps it so the user's library survives switching back.
    if (deleteUserData && userPubkey != null && userPubkey.isNotEmpty) {
      final savedSoundsKey = SavedSoundsService.accountStorageKey(userPubkey);
      if (_prefs.containsKey(savedSoundsKey)) {
        await _prefs.remove(savedSoundsKey);
        clearedCount++;
        clearedKeys.add(savedSoundsKey);
      }

      // The creator-sync cursor records, per item, what this device last
      // applied or published — it only makes sense paired with the local
      // bucket above. If the bucket is cleared but the cursor survives, the
      // next reconcile sees every previously-synced item as absent locally
      // and reads that as this device having deleted them, publishing
      // tombstones that wipe the account's synced library on every other
      // device. Clearing both together makes the next reconcile a fresh
      // pull from remote instead.
      for (final kind in SyncItemKind.values) {
        final cursorKey = PrefsSyncStateStore.appliedStorageKey(
          kind,
          userPubkey,
        );
        if (_prefs.containsKey(cursorKey)) {
          await _prefs.remove(cursorKey);
          clearedCount++;
          clearedKeys.add(cursorKey);
        }
      }

      for (final key in AgeVerificationService.accountKeys(userPubkey)) {
        if (_prefs.containsKey(key)) {
          await _prefs.remove(key);
          clearedCount++;
          clearedKeys.add(key);
        }
      }
    }

    // Clear user-specific database tables (DMs, conversations, notifications,
    // and optionally per-user DAO rows when deleteUserData is true)
    if (onDatabaseCleanup != null) {
      try {
        await onDatabaseCleanup!(
          userPubkey: userPubkey,
          deleteUserData: deleteUserData,
          preserveActiveSession: false,
        );
        Log.info(
          'Database cleanup complete',
          name: 'UserDataCleanupService',
          category: LogCategory.auth,
        );
      } catch (e, stackTrace) {
        Log.error(
          'Database cleanup failed: $e\n$stackTrace',
          name: 'UserDataCleanupService',
          category: LogCategory.auth,
        );
        // An account switch must fail closed: proceeding after its shared
        // database cleanup fails can expose the departing account's local DM
        // state to the incoming session. Ordinary same-account logout remains
        // best-effort unless it is explicitly destructive.
        if (deleteUserData || isIdentityChange) {
          rethrow;
        }
      }
    }

    // Clear prefix-matched dynamic keys only on identity change
    // These are keyed by pubkey so they can't leak, and the redirect
    // logic needs following_list_ at login time before relay responds
    if (isIdentityChange) {
      final allKeys = _prefs.getKeys();
      for (final key in allKeys) {
        for (final prefix in identityChangePrefixes) {
          if (key.startsWith(prefix)) {
            await _prefs.remove(key);
            clearedCount++;
            clearedKeys.add(key);
            break;
          }
        }
      }
    }

    // Log detailed cleanup results for observability
    if (clearedCount > 0) {
      Log.info(
        'User data cleanup complete: cleared $clearedCount entries',
        name: 'UserDataCleanupService',
        category: LogCategory.auth,
      );
      Log.debug(
        'Cleared keys: ${clearedKeys.join(", ")}',
        name: 'UserDataCleanupService',
        category: LogCategory.auth,
      );
    } else {
      Log.debug(
        'User data cleanup: no data to clear',
        name: 'UserDataCleanupService',
        category: LogCategory.auth,
      );
    }

    return clearedCount;
  }

  /// Claims legacy database rows (NULL ownerPubkey) for [userPubkey].
  ///
  /// Should be called during session setup so pre-multi-account data is
  /// attributed to the current user and no longer visible to other accounts.
  Future<void> claimLegacyRows(String userPubkey) async {
    if (onClaimLegacyRows == null) return;
    try {
      await onClaimLegacyRows!(userPubkey);
      Log.info(
        'Legacy row claim complete for ${pubkeyForLogs(userPubkey)}',
        name: 'UserDataCleanupService',
        category: LogCategory.auth,
      );
    } catch (e) {
      Log.error(
        'Legacy row claim failed: $e',
        name: 'UserDataCleanupService',
        category: LogCategory.auth,
      );
    }
  }
}

class UserDataCleanupException implements Exception {
  const UserDataCleanupException(this.message, [this.cause]);

  final String message;
  final Object? cause;

  @override
  String toString() => cause == null ? message : '$message: $cause';
}
