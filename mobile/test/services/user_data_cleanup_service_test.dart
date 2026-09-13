// ABOUTME: Tests for UserDataCleanupService identity change detection and cleanup
// ABOUTME: Validates that user-specific data is cleared when switching accounts

import 'package:creator_sync/creator_sync.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/blocs/dm/conversation_mute/conversation_mute_cubit.dart';
import 'package:openvine/services/account_label_service.dart';
import 'package:openvine/services/audio_sharing_preference_service.dart';
import 'package:openvine/services/content_filter_service.dart';
import 'package:openvine/services/creator_sync/prefs_sync_state_store.dart';
import 'package:openvine/services/divine_host_filter_service.dart';
import 'package:openvine/services/language_preference_service.dart';
import 'package:openvine/services/moderation_label_service.dart';
import 'package:openvine/services/saved_sounds_service.dart';
import 'package:openvine/services/seen_videos_service.dart';
import 'package:openvine/services/sound_library_service.dart';
import 'package:openvine/services/user_data_cleanup_service.dart';
import 'package:openvine/services/video_provenance_filter_service.dart';
import 'package:openvine/utils/nostr_key_utils.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockSyncIndexClient extends Mock implements SyncIndexClient {}

/// A [LocalSoundStore] that is always empty, standing in for a device whose
/// saved-sounds bucket has already been wiped by cleanup.
class _EmptyLocalSoundStore implements LocalSoundStore {
  @override
  Future<Map<String, Map<String, dynamic>>> readAll() async => {};

  @override
  Future<void> upsert(String id, Map<String, dynamic> body) async {}

  @override
  Future<void> remove(String id) async {}
}

void main() {
  group('UserDataCleanupService', () {
    late SharedPreferences prefs;
    late UserDataCleanupService service;

    setUpAll(() {
      registerFallbackValue(const SyncItemRef(SyncItemKind.sound, 'x'));
      registerFallbackValue(SyncIndexEntry.tombstone());
    });

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
      service = UserDataCleanupService(prefs);
    });

    group('shouldClearDataForUser', () {
      test('returns false when same user is logging in', () async {
        const pubkey = 'abc123def456';
        await prefs.setString('current_user_pubkey_hex', pubkey);

        expect(service.shouldClearDataForUser(pubkey), isFalse);
      });

      test('returns true when different user was stored', () async {
        const oldPubkey = 'old_user_pubkey';
        const newPubkey = 'new_user_pubkey';
        await prefs.setString('current_user_pubkey_hex', oldPubkey);

        expect(service.shouldClearDataForUser(newPubkey), isTrue);
      });

      test('returns false on fresh install with no data', () {
        const pubkey = 'brand_new_user';

        expect(service.shouldClearDataForUser(pubkey), isFalse);
      });

      test(
        'returns true when orphaned user data exists without stored pubkey',
        () async {
          // No pubkey stored, but user-specific data exists
          await prefs.setStringList('curated_lists', ['list1', 'list2']);

          expect(service.shouldClearDataForUser('any_pubkey'), isTrue);
        },
      );

      test(
        'returns true when any user-specific key exists without pubkey',
        () async {
          // Test with a different user-specific key
          await prefs.setString('seen_video_ids', 'video1,video2');

          expect(service.shouldClearDataForUser('any_pubkey'), isTrue);
        },
      );

      test('keeps preserved legacy drafts for same-user re-login', () async {
        const pubkey = 'same_user_pubkey';
        await prefs.setString('vine_drafts', '[{"id":"draft1"}]');
        await service.markOwnerScopedLegacyDataForUser(pubkey);

        expect(service.shouldClearDataForUser(pubkey), isFalse);
      });

      test('clears preserved legacy drafts for a different user', () async {
        await prefs.setString('vine_drafts', '[{"id":"draft1"}]');
        await service.markOwnerScopedLegacyDataForUser('old_user_pubkey');

        expect(service.shouldClearDataForUser('new_user_pubkey'), isTrue);
      });

      test('clears unmarked legacy drafts as orphaned data', () async {
        await prefs.setString('vine_drafts', '[{"id":"draft1"}]');

        expect(service.shouldClearDataForUser('any_pubkey'), isTrue);
      });
    });

    group('clearUserSpecificData', () {
      const verificationPubkey =
          'dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd';

      test('destructive delete purges only that account verification', () async {
        const otherPubkey =
            'eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee';
        await prefs.setBool('adult_content_verified_$verificationPubkey', true);
        await prefs.setBool('adult_content_verified_$otherPubkey', true);

        await service.clearUserSpecificData(
          deleteUserData: true,
          userPubkey: verificationPubkey,
        );

        expect(
          prefs.containsKey('adult_content_verified_$verificationPubkey'),
          isFalse,
        );
        expect(prefs.getBool('adult_content_verified_$otherPubkey'), isTrue);
      });

      test(
        'destructive sign-out purges only that account following cache',
        () async {
          const otherPubkey =
              'eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee';
          await prefs.setString(
            'following_list_$verificationPubkey',
            '["followed"]',
          );
          await prefs.setBool(
            'following_prefetch_complete_$verificationPubkey',
            true,
          );
          await prefs.setString('following_list_$otherPubkey', '["other"]');
          await prefs.setBool('following_prefetch_complete_$otherPubkey', true);

          await service.clearUserSpecificData(
            deleteUserData: true,
            userPubkey: verificationPubkey,
          );

          expect(
            prefs.containsKey('following_list_$verificationPubkey'),
            isFalse,
          );
          expect(
            prefs.containsKey(
              'following_prefetch_complete_$verificationPubkey',
            ),
            isFalse,
          );
          expect(prefs.getString('following_list_$otherPubkey'), '["other"]');
          expect(
            prefs.getBool('following_prefetch_complete_$otherPubkey'),
            isTrue,
          );
        },
      );

      test('account switch preserves scoped verification', () async {
        await prefs.setBool('adult_content_verified_$verificationPubkey', true);

        await service.clearUserSpecificData(
          isIdentityChange: true,
          userPubkey: verificationPubkey,
        );

        expect(
          prefs.getBool('adult_content_verified_$verificationPubkey'),
          isTrue,
        );
      });

      test('clears all user-specific keys from SharedPreferences', () async {
        // Set up some user-specific data
        await prefs.setStringList('curated_lists', ['list1']);
        await prefs.setStringList('subscribed_list_ids', ['sub1']);
        await prefs.setString('seen_video_ids', 'video1');
        await prefs.setBool('age_verified_16_plus', true);

        // Also set some device/app settings that should NOT be cleared
        await prefs.setString('relay_url', 'wss://relay.example.com');
        await prefs.setBool('analytics_enabled', false);

        await service.clearUserSpecificData();

        // User-specific data should be gone
        expect(prefs.containsKey('curated_lists'), isFalse);
        expect(prefs.containsKey('subscribed_list_ids'), isFalse);
        expect(prefs.containsKey('seen_video_ids'), isFalse);
        expect(prefs.containsKey('age_verified_16_plus'), isFalse);

        // Device/app settings should remain
        expect(prefs.getString('relay_url'), 'wss://relay.example.com');
        expect(prefs.getBool('analytics_enabled'), isFalse);
      });

      test('clears bookmark-related keys', () async {
        await prefs.setString('global_bookmarks', 'bookmark_data');
        await prefs.setInt('global_bookmarks_revision', 3);

        await service.clearUserSpecificData();

        expect(prefs.containsKey('global_bookmarks'), isFalse);
        expect(prefs.containsKey('global_bookmarks_revision'), isFalse);
      });

      // Each entry is a key a live service writes that the account-switch
      // sweep did not name. They are grouped because the failure is one
      // defect, not eight: the sweep list was never linked to the code that
      // writes these keys, so a key added later was never added here.
      final unsweptUserKeys = <String, String>{
        'account self-labels applied to new uploads':
            AccountLabelService.accountLabelStorageKey,
        'per-category content filter choices':
            ContentFilterService.filterPrefsStorageKey,
        'the content-filter migration flag guarding those choices':
            ContentFilterService.filterMigratedStorageKey,
        'the legacy adult-content preference used by that migration':
            ContentFilterService.legacyAdultContentPreferenceStorageKey,
        'muted DM conversations': mutedConversationsStorageKey,
        'the seen-videos migration flag guarding watch history':
            SeenVideosService.seenVideosMigratedStorageKey,
        'declared content language published on videos':
            LanguagePreferenceService.prefsKey,
        'the unscoped custom sound library':
            SoundLibraryService.customSoundsStorageKey,
        'whether this account audio is reusable by others':
            AudioSharingPreferenceService.prefsKey,
        'the Divine-hosted-only feed filter':
            DivineHostFilterService.showDivineHostedOnlyStorageKey,
        'the verified-only feed filter':
            VideoProvenanceFilterService.showVerifiedOnlyStorageKey,
      };

      for (final entry in unsweptUserKeys.entries) {
        test('identity change clears ${entry.key}', () async {
          await prefs.setString(entry.value, 'value_from_departing_account');

          await service.clearUserSpecificData(isIdentityChange: true);

          expect(
            prefs.containsKey(entry.value),
            isFalse,
            reason:
                'the incoming account must not inherit "${entry.value}" '
                'from the account that just signed out',
          );
        });
      }

      test(
        'clears the labelers the departing account chose to trust',
        () async {
          await prefs.setStringList(
            ModerationLabelService.subscribedLabelersStorageKey,
            ['labeler_chosen_by_departing_account'],
          );

          await service.clearUserSpecificData(isIdentityChange: true);

          expect(
            prefs.getStringList(
              ModerationLabelService.subscribedLabelersStorageKey,
            ),
            isNull,
            reason:
                'the incoming account must not inherit moderation '
                'subscriptions chosen by the previous account (#6985)',
          );
        },
      );

      test('clears the departing account follow-as-labeler choice', () async {
        await prefs.setBool(
          ModerationLabelService.followingModerationEnabledStorageKey,
          true,
        );

        await service.clearUserSpecificData(isIdentityChange: true);

        expect(
          prefs.getBool(
            ModerationLabelService.followingModerationEnabledStorageKey,
          ),
          isNull,
          reason:
              'the incoming account must not inherit the choice to '
              'trust followed accounts as labelers (#6985)',
        );
      });

      test(
        'preserves legacy drafts on same-user non-destructive cleanup',
        () async {
          await prefs.setString('vine_drafts', '{"drafts": []}');

          await service.clearUserSpecificData();

          expect(prefs.containsKey('vine_drafts'), isTrue);
        },
      );

      test('clears legacy drafts on destructive cleanup', () async {
        await prefs.setString('vine_drafts', '{"drafts": []}');
        await service.markOwnerScopedLegacyDataForUser('abc123');

        await service.clearUserSpecificData(deleteUserData: true);

        expect(prefs.containsKey('vine_drafts'), isFalse);
        expect(
          prefs.containsKey(UserDataCleanupService.legacyDraftOwnerKey),
          isFalse,
        );
      });

      test('clears legacy drafts on identity change', () async {
        await prefs.setString('vine_drafts', '{"drafts": []}');
        await service.markOwnerScopedLegacyDataForUser('abc123');

        await service.clearUserSpecificData(isIdentityChange: true);

        expect(prefs.containsKey('vine_drafts'), isFalse);
        expect(
          prefs.containsKey(UserDataCleanupService.legacyDraftOwnerKey),
          isFalse,
        );
      });

      test(
        'clears the saved-sounds bucket on destructive account delete',
        () async {
          const pubkey =
              'a1b2c3d4e5f6789012345678901234567890abcdef1234567890abcdef123456';
          final bucketKey = SavedSoundsService.accountStorageKey(pubkey);
          await prefs.setString(bucketKey, '[{"id":"sound1"}]');

          await service.clearUserSpecificData(
            deleteUserData: true,
            userPubkey: pubkey,
          );

          expect(prefs.containsKey(bucketKey), isFalse);
        },
      );

      test('keeps the saved-sounds bucket on a plain account switch', () async {
        const pubkey =
            'a1b2c3d4e5f6789012345678901234567890abcdef1234567890abcdef123456';
        final bucketKey = SavedSoundsService.accountStorageKey(pubkey);
        await prefs.setString(bucketKey, '[{"id":"sound1"}]');

        await service.clearUserSpecificData(
          isIdentityChange: true,
          userPubkey: pubkey,
        );

        // A switch (not a delete) preserves the library for switching back.
        expect(prefs.containsKey(bucketKey), isTrue);
      });

      test('clears the creator-sync cursor alongside the saved-sounds bucket '
          'on destructive account delete', () async {
        const pubkey =
            'a1b2c3d4e5f6789012345678901234567890abcdef1234567890abcdef123456';
        final cursorKey = PrefsSyncStateStore.appliedStorageKey(
          SyncItemKind.sound,
          pubkey,
        );
        await prefs.setString(
          cursorKey,
          '{"divine:sync:sound:s1":'
          '{"createdAt":1000,"bodyHash":"h"}}',
        );

        await service.clearUserSpecificData(
          deleteUserData: true,
          userPubkey: pubkey,
        );

        expect(prefs.containsKey(cursorKey), isFalse);
      });

      test('keeps the creator-sync cursor on a plain account switch', () async {
        const pubkey =
            'a1b2c3d4e5f6789012345678901234567890abcdef1234567890abcdef123456';
        final cursorKey = PrefsSyncStateStore.appliedStorageKey(
          SyncItemKind.sound,
          pubkey,
        );
        await prefs.setString(
          cursorKey,
          '{"divine:sync:sound:s1":'
          '{"createdAt":1000,"bodyHash":"h"}}',
        );

        await service.clearUserSpecificData(
          isIdentityChange: true,
          userPubkey: pubkey,
        );

        expect(prefs.containsKey(cursorKey), isTrue);
      });

      test('does not let a reconcile after destructive cleanup mistake a '
          'wiped local cache for a mass delete', () async {
        const pubkey =
            'a1b2c3d4e5f6789012345678901234567890abcdef1234567890abcdef123456';
        // This device had already fully synced a 3-sound library before
        // the destructive cleanup below wipes its saved-sounds bucket.
        await PrefsSyncStateStore(prefs, pubkeyHex: pubkey).writeApplied(
          SyncItemKind.sound,
          {
            for (final id in ['s1', 's2', 's3'])
              'divine:sync:sound:$id': SyncItemState(
                createdAt: 1000,
                bodyHash: syncBodyHash({'label': id}),
              ),
          },
        );

        await service.clearUserSpecificData(
          deleteUserData: true,
          userPubkey: pubkey,
        );

        final index = _MockSyncIndexClient();
        when(
          () => index.fetch(SyncItemKind.sound, since: any(named: 'since')),
        ).thenAnswer((_) async => []);
        final repository = SoundSyncRepository(
          index: index,
          state: PrefsSyncStateStore(prefs, pubkeyHex: pubkey),
          local: _EmptyLocalSoundStore(),
        );

        await repository.reconcile();

        verifyNever(
          () => index.publish(
            any(),
            any(),
            latestKnownRemote: any(named: 'latestKnownRemote'),
          ),
        );
      });

      test('marks legacy draft owner only when legacy drafts exist', () async {
        await service.markOwnerScopedLegacyDataForUser('abc123');
        expect(
          prefs.containsKey(UserDataCleanupService.legacyDraftOwnerKey),
          isFalse,
        );

        await prefs.setString('vine_drafts', '{"drafts": []}');
        await service.markOwnerScopedLegacyDataForUser('abc123');

        expect(
          prefs.getString(UserDataCleanupService.legacyDraftOwnerKey),
          equals('abc123'),
        );
      });

      test('returns count of cleared keys', () async {
        // Set up some user-specific data
        await prefs.setStringList('curated_lists', ['list1']);
        await prefs.setString('seen_video_ids', 'video1');
        await prefs.setBool('age_verified_16_plus', true);

        final clearedCount = await service.clearUserSpecificData();

        expect(clearedCount, equals(3));
      });

      test('returns zero when no data to clear', () async {
        final clearedCount = await service.clearUserSpecificData();

        expect(clearedCount, equals(0));
      });

      test('accepts reason parameter for tracking', () async {
        await prefs.setStringList('curated_lists', ['list1']);

        // Should complete without error with various reasons
        final count1 = await service.clearUserSpecificData(
          reason: 'explicit_logout',
        );
        expect(count1, equals(1));

        // Reset data
        await prefs.setStringList('curated_lists', ['list1']);

        final count2 = await service.clearUserSpecificData(
          reason: 'identity_change',
        );
        expect(count2, equals(1));
      });

      test(
        'does NOT clear dynamic prefix keys without isIdentityChange',
        () async {
          // Set up dynamic pubkey-keyed caches
          await prefs.setString(
            'following_list_abc123',
            '["pubkey1","pubkey2"]',
          );
          await prefs.setString('relay_discovery_npub1abc', 'relay_data');
          // Also set a static user-specific key
          await prefs.setStringList('curated_lists', ['list1']);

          // Default isIdentityChange=false (same-user logout)
          await service.clearUserSpecificData(reason: 'explicit_logout');

          // Static keys should be cleared
          expect(prefs.containsKey('curated_lists'), isFalse);

          // Dynamic prefix keys should be PRESERVED
          expect(prefs.containsKey('following_list_abc123'), isTrue);
          expect(prefs.containsKey('relay_discovery_npub1abc'), isTrue);
        },
      );

      test('preserves every account-scoped cache on identity change', () async {
        for (final account in ['abc123', 'def456']) {
          await prefs.setString(
            'following_list_$account',
            '["pubkey1","pubkey2"]',
          );
          await prefs.setBool('following_prefetch_complete_$account', true);
          await prefs.setString('relay_discovery_npub1$account', 'relay_data');
        }
        // DM sync cursors are cleared by DmSyncState for the leaving pubkey,
        // not by preference cleanup.
        await prefs.setInt('dm.newestSyncedAt.abc123', 1700000000);
        await prefs.setInt('dm.oldestSyncedAt.abc123', 1699000000);

        await service.clearUserSpecificData(
          reason: 'identity_change',
          isIdentityChange: true,
        );

        for (final account in ['abc123', 'def456']) {
          expect(prefs.containsKey('following_list_$account'), isTrue);
          expect(
            prefs.containsKey('following_prefetch_complete_$account'),
            isTrue,
          );
          expect(prefs.containsKey('relay_discovery_npub1$account'), isTrue);
        }
        expect(prefs.containsKey('dm.newestSyncedAt.abc123'), isTrue);
        expect(prefs.containsKey('dm.oldestSyncedAt.abc123'), isTrue);
      });

      test(
        'does not include scoped cache keys in identity-change count',
        () async {
          await prefs.setStringList('curated_lists', ['list1']);
          await prefs.setString('vine_drafts', '{"drafts": []}');
          await prefs.setString('following_list_abc123', '["pubkey1"]');
          await prefs.setString('relay_discovery_npub1abc', 'data');

          final count = await service.clearUserSpecificData(
            reason: 'identity_change',
            isIdentityChange: true,
          );

          // 1 static + 1 owner-scoped legacy key.
          expect(count, equals(2));
          expect(prefs.containsKey('following_list_abc123'), isTrue);
          expect(prefs.containsKey('relay_discovery_npub1abc'), isTrue);
        },
      );

      test(
        'preserves scoped and unrelated caches on identity change',
        () async {
          await prefs.setString('some_other_cache_abc', 'data');
          await prefs.setString('following_list_abc123', '["pubkey1"]');

          await service.clearUserSpecificData(
            reason: 'identity_change',
            isIdentityChange: true,
          );

          expect(prefs.containsKey('some_other_cache_abc'), isTrue);
          expect(prefs.containsKey('following_list_abc123'), isTrue);
        },
      );

      test(
        'passes userPubkey and deleteUserData to onDatabaseCleanup',
        () async {
          String? receivedPubkey;
          var receivedDeleteUserData = false;
          service.onDatabaseCleanup =
              ({
                String? userPubkey,
                bool deleteUserData = false,
                bool preserveActiveSession = false,
              }) async {
                receivedPubkey = userPubkey;
                receivedDeleteUserData = deleteUserData;
              };

          await service.clearUserSpecificData(
            reason: 'explicit_logout',
            userPubkey: 'abc123',
            deleteUserData: true,
          );

          expect(receivedPubkey, equals('abc123'));
          expect(receivedDeleteUserData, isTrue);
        },
      );

      test(
        'passes deleteUserData=false by default to onDatabaseCleanup',
        () async {
          var receivedDeleteUserData = true;
          service.onDatabaseCleanup =
              ({
                String? userPubkey,
                bool deleteUserData = false,
                bool preserveActiveSession = false,
              }) async {
                receivedDeleteUserData = deleteUserData;
              };

          await service.clearUserSpecificData(reason: 'explicit_logout');

          expect(receivedDeleteUserData, isFalse);
        },
      );

      test(
        'does not throw database cleanup failure on non-destructive cleanup',
        () async {
          service.onDatabaseCleanup =
              ({
                String? userPubkey,
                bool deleteUserData = false,
                bool preserveActiveSession = false,
              }) async {
                throw StateError('cleanup failed');
              };

          await expectLater(service.clearUserSpecificData(), completes);
        },
      );

      test('throws database cleanup failure on destructive cleanup', () async {
        service.onDatabaseCleanup =
            ({
              String? userPubkey,
              bool deleteUserData = false,
              bool preserveActiveSession = false,
            }) async {
              throw StateError('cleanup failed');
            };

        await expectLater(
          service.clearUserSpecificData(deleteUserData: true),
          throwsA(isA<StateError>()),
        );
      });

      test('throws database cleanup failure on identity change', () async {
        service.onDatabaseCleanup =
            ({
              String? userPubkey,
              bool deleteUserData = false,
              bool preserveActiveSession = false,
            }) async {
              throw StateError('cleanup failed');
            };

        await expectLater(
          service.clearUserSpecificData(isIdentityChange: true),
          throwsA(isA<StateError>()),
        );
      });

      test('claimLegacyRows calls onClaimLegacyRows callback', () async {
        String? receivedPubkey;
        service.onClaimLegacyRows = (String pubkey) async {
          receivedPubkey = pubkey;
        };

        await service.claimLegacyRows('abc123');

        expect(receivedPubkey, equals('abc123'));
      });

      test('claimLegacyRows is safe when callback not set', () async {
        // Should not throw
        await service.claimLegacyRows('abc123');
      });
    });

    group('deleteAccountData', () {
      test(
        'deletes owner-scoped data without clearing shared preferences',
        () async {
          final deletedPubkey = 'a' * 64;
          final otherPubkey = 'b' * 64;
          final deletedNpub = NostrKeyUtils.encodePubKey(deletedPubkey);
          await prefs.setStringList('global_bookmarks', ['other-bookmark']);
          await prefs.setString('vine_drafts', '{"drafts": []}');
          await service.markOwnerScopedLegacyDataForUser(deletedPubkey);
          await prefs.setString(
            SavedSoundsService.accountStorageKey(deletedPubkey),
            '[{"id":"deleted-sound"}]',
          );
          await prefs.setString(
            SavedSoundsService.accountStorageKey(otherPubkey),
            '[{"id":"other-sound"}]',
          );
          await prefs.setString('following_list_$deletedPubkey', '[]');
          await prefs.setBool(
            'following_prefetch_complete_$deletedPubkey',
            true,
          );
          await prefs.setString('relay_discovery_$deletedNpub', '{}');
          final otherNpub = NostrKeyUtils.encodePubKey(otherPubkey);
          await prefs.setString('following_list_$otherPubkey', '["other"]');
          await prefs.setBool('following_prefetch_complete_$otherPubkey', true);
          await prefs.setString('relay_discovery_$otherNpub', '{"other":true}');

          await service.deleteAccountData(
            deletedPubkey,
            userNpub: deletedNpub,
            preserveActiveSession: true,
          );

          expect(prefs.getStringList('global_bookmarks'), ['other-bookmark']);
          expect(prefs.containsKey('vine_drafts'), isFalse);
          expect(
            prefs.containsKey(
              SavedSoundsService.accountStorageKey(deletedPubkey),
            ),
            isFalse,
          );
          expect(
            prefs.containsKey(
              SavedSoundsService.accountStorageKey(otherPubkey),
            ),
            isTrue,
          );
          expect(prefs.containsKey('following_list_$deletedPubkey'), isFalse);
          expect(
            prefs.containsKey('following_prefetch_complete_$deletedPubkey'),
            isFalse,
          );
          expect(prefs.containsKey('relay_discovery_$deletedNpub'), isFalse);
          expect(prefs.getString('following_list_$otherPubkey'), '["other"]');
          expect(
            prefs.getBool('following_prefetch_complete_$otherPubkey'),
            isTrue,
          );
          expect(
            prefs.getString('relay_discovery_$otherNpub'),
            '{"other":true}',
          );
        },
      );

      test('deletes device-wide user data when no session is active', () async {
        final deletedPubkey = 'a' * 64;
        final deletedNpub = NostrKeyUtils.encodePubKey(deletedPubkey);
        await prefs.setStringList('global_bookmarks', ['bookmark']);
        await prefs.setString('content_reports_history', '[]');
        await prefs.setString('vine_drafts', '{"drafts": []}');

        await service.deleteAccountData(
          deletedPubkey,
          userNpub: deletedNpub,
          preserveActiveSession: false,
        );

        expect(prefs.containsKey('global_bookmarks'), isFalse);
        expect(prefs.containsKey('content_reports_history'), isFalse);
        expect(prefs.containsKey('vine_drafts'), isFalse);
      });

      test('preserves legacy drafts owned by another account', () async {
        final deletedPubkey = 'a' * 64;
        final otherPubkey = 'b' * 64;
        final deletedNpub = NostrKeyUtils.encodePubKey(deletedPubkey);
        await prefs.setString('vine_drafts', '{"drafts": []}');
        await service.markOwnerScopedLegacyDataForUser(otherPubkey);

        await service.deleteAccountData(
          deletedPubkey,
          userNpub: deletedNpub,
          preserveActiveSession: false,
        );

        expect(prefs.containsKey('vine_drafts'), isTrue);
        expect(
          prefs.getString(UserDataCleanupService.legacyDraftOwnerKey),
          otherPubkey,
        );
      });

      test('propagates database cleanup failures', () async {
        final deletedPubkey = 'a' * 64;
        final deletedNpub = NostrKeyUtils.encodePubKey(deletedPubkey);
        var preservedActiveSession = false;
        service.onDatabaseCleanup =
            ({
              userPubkey,
              deleteUserData = false,
              preserveActiveSession = false,
            }) async {
              preservedActiveSession = preserveActiveSession;
              throw StateError('database unavailable');
            };

        await expectLater(
          service.deleteAccountData(
            deletedPubkey,
            userNpub: deletedNpub,
            preserveActiveSession: true,
          ),
          throwsA(isA<StateError>()),
        );
        expect(preservedActiveSession, isTrue);
      });
    });

    group('userSpecificKeys', () {
      // Asserting membership by literal is what let this list rot: the
      // previous version of this test pinned three keys no code had written
      // for months, so deleting them turned the suite red. Assert instead
      // that the list is composed from the constants the writing services
      // own, which is a property a renamed key cannot satisfy silently.
      test('is composed from the constants the writing services own', () {
        const keys = UserDataCleanupService.userSpecificKeys;

        expect(
          keys,
          containsAll(<String>[
            ModerationLabelService.subscribedLabelersStorageKey,
            ModerationLabelService.followingModerationEnabledStorageKey,
            AccountLabelService.accountLabelStorageKey,
            ContentFilterService.filterPrefsStorageKey,
            ContentFilterService.filterMigratedStorageKey,
            LanguagePreferenceService.prefsKey,
            AudioSharingPreferenceService.prefsKey,
            DivineHostFilterService.showDivineHostedOnlyStorageKey,
            VideoProvenanceFilterService.showVerifiedOnlyStorageKey,
            SoundLibraryService.customSoundsStorageKey,
            mutedConversationsStorageKey,
          ]),
        );
      });

      test('contains no key that nothing in the app writes', () {
        // Every entry below is a literal whose owning service has no
        // constant to reference yet. They are the remaining conversion work;
        // a key that reaches this list without a writer is the #8314 defect.
        expect(
          UserDataCleanupService.userSpecificKeys,
          isNot(
            anyElement(
              isIn(<String>[
                'user_lists',
                'bookmark_sets',
                'bookmark_published_hashes',
                'bookmark_pending_changes',
                'muted_items',
                'content_moderation_local_mutes',
                'content_moderation_subscribed_lists',
                'subscribed_labelers',
                'label_cache',
                'trusted_reporters',
                'report_cache',
              ]),
            ),
          ),
          reason:
              'these keys had no writer when they were removed; '
              'reintroducing one would be a silent no-op again',
        );
      });

      test('does NOT contain device/app settings', () {
        const keys = UserDataCleanupService.userSpecificKeys;

        // These should NOT be in the cleanup list
        expect(keys, isNot(contains('relay_url')));
        expect(keys, isNot(contains('analytics_enabled')));
        expect(keys, isNot(contains('current_user_pubkey_hex')));
      });
    });

    group('ownerScopedLegacyKeys', () {
      test('contains legacy draft storage', () {
        const keys = UserDataCleanupService.ownerScopedLegacyKeys;

        expect(keys, contains('vine_drafts'));
      });
    });

    group('identityChangePrefixes', () {
      test('contains only account-scoped cache categories', () {
        const prefixes = UserDataCleanupService.identityChangePrefixes;

        expect(prefixes, contains('following_list_'));
        expect(prefixes, contains('relay_discovery_'));
        expect(prefixes, isNot(contains('dm.newestSyncedAt.')));
        expect(prefixes, isNot(contains('dm.oldestSyncedAt.')));
      });

      test('does NOT contain non-dynamic prefixes', () {
        const prefixes = UserDataCleanupService.identityChangePrefixes;

        // Static keys should not be in prefix list
        expect(prefixes, isNot(contains('curated_lists')));
        expect(prefixes, isNot(contains('seen_video_ids')));
      });
    });
  });
}
