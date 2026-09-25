// ABOUTME: Unit tests for ProfileStatsDao with cache expiry logic.
// ABOUTME: Tests upsertStats, getStats with expiry, deleteExpired, clearAll.

import 'dart:io';

import 'package:db_client/db_client.dart';
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase database;
  late DbClient dbClient;
  late AppDbClient appDbClient;
  late ProfileStatsDao dao;
  late String tempDbPath;

  /// Valid 64-char hex pubkey for testing
  const testPubkey =
      '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef';
  const testPubkey2 =
      'fedcba9876543210fedcba9876543210fedcba9876543210fedcba9876543210';

  setUp(() async {
    final tempDir = Directory.systemTemp.createTempSync('dao_test_');
    tempDbPath = '${tempDir.path}/test.db';

    database = AppDatabase.test(NativeDatabase(File(tempDbPath)));
    dbClient = DbClient(generatedDatabase: database);
    appDbClient = AppDbClient(dbClient, database);
    dao = database.profileStatsDao;
  });

  tearDown(() async {
    await database.close();
    final file = File(tempDbPath);
    if (file.existsSync()) {
      file.deleteSync();
    }
    final dir = Directory(tempDbPath).parent;
    if (dir.existsSync()) {
      dir.deleteSync(recursive: true);
    }
  });

  group('ProfileStatsDao', () {
    group('upsertStats', () {
      test('inserts new stats', () async {
        await dao.upsertStats(
          pubkey: testPubkey,
          videoCount: 10,
          followerCount: 100,
          followingCount: 50,
          totalViews: 1000,
          totalLikes: 500,
        );

        final result = await appDbClient.getProfileStatRow(testPubkey);
        expect(result, isNotNull);
        expect(result!.pubkey, equals(testPubkey));
        expect(result.videoCount, equals(10));
        expect(result.followerCount, equals(100));
        expect(result.followingCount, equals(50));
        expect(result.totalViews, equals(1000));
        expect(result.totalLikes, equals(500));
      });

      test('updates existing stats with same pubkey', () async {
        await dao.upsertStats(
          pubkey: testPubkey,
          videoCount: 10,
          followerCount: 100,
        );

        await dao.upsertStats(
          pubkey: testPubkey,
          videoCount: 20,
          followerCount: 200,
        );

        final result = await appDbClient.getProfileStatRow(testPubkey);
        expect(result, isNotNull);
        expect(result!.videoCount, equals(20));
        expect(result.followerCount, equals(200));

        // Verify only one entry exists
        final count = await appDbClient.countProfileStats();
        expect(count, equals(1));
      });

      test('does not replace a known total with an ambiguous zero', () async {
        await dao.upsertStats(pubkey: testPubkey, totalViews: 3);

        // Funnelcake can return zero engagement when its summary source is
        // unavailable. Keep the last known total instead of caching that
        // ambiguous zero as the new value.
        await dao.upsertStats(pubkey: testPubkey, totalViews: 0);

        final result = await appDbClient.getProfileStatRow(testPubkey);
        expect(result!.totalViews, equals(3));
      });

      test('handles null optional fields', () async {
        await dao.upsertStats(pubkey: testPubkey);

        final result = await appDbClient.getProfileStatRow(testPubkey);
        expect(result, isNotNull);
        expect(result!.videoCount, isNull);
        expect(result.followerCount, isNull);
        expect(result.followingCount, isNull);
        expect(result.totalViews, isNull);
        expect(result.totalLikes, isNull);
      });

      test('handles multiple different pubkeys', () async {
        await dao.upsertStats(pubkey: testPubkey, videoCount: 10);
        await dao.upsertStats(pubkey: testPubkey2, videoCount: 20);

        final result1 = await appDbClient.getProfileStatRow(testPubkey);
        final result2 = await appDbClient.getProfileStatRow(testPubkey2);

        expect(result1!.videoCount, equals(10));
        expect(result2!.videoCount, equals(20));

        final count = await appDbClient.countProfileStats();
        expect(count, equals(2));
      });

      test('sets cachedAt timestamp', () async {
        final before = DateTime.now().subtract(const Duration(seconds: 1));
        await dao.upsertStats(pubkey: testPubkey);
        final after = DateTime.now().add(const Duration(seconds: 1));

        final result = await appDbClient.getProfileStatRow(testPubkey);
        expect(result, isNotNull);
        expect(result!.cachedAt.isAfter(before), isTrue);
        expect(result.cachedAt.isBefore(after), isTrue);
      });

      test('does not refresh follower timestamp for unrelated stats', () async {
        await dao.upsertStats(
          pubkey: testPubkey,
          followerCount: 100,
          followingCount: 50,
        );
        final original = await appDbClient.getProfileStatRow(testPubkey);
        expect(original!.followerCountsUpdatedAt, isNotNull);

        await Future<void>.delayed(const Duration(milliseconds: 5));
        await dao.upsertStats(pubkey: testPubkey, videoCount: 10);

        final result = await appDbClient.getProfileStatRow(testPubkey);
        expect(result!.videoCount, equals(10));
        expect(
          result.followerCountsUpdatedAt,
          equals(original.followerCountsUpdatedAt),
        );
      });

      test(
        'a later count write refreshes the stamp both readers rely on',
        () async {
          // Transition 1 (#8259 review). Retention (getStats/deleteExpired)
          // and the relay hysteresis both read followerCountsUpdatedAt, so a
          // write that left an older stamp in place would make a row holding
          // *current* counts look stale to retention — evicting the very
          // fallback baseline the 48h window exists to protect.
          await dao.upsertStats(
            pubkey: testPubkey,
            followerCount: 100,
            followingCount: 50,
          );
          final first = await appDbClient.getProfileStatRow(testPubkey);

          // The column stores unix seconds, so the writes need a real gap.
          await Future<void>.delayed(const Duration(milliseconds: 1200));

          await dao.upsertStats(
            pubkey: testPubkey,
            followerCount: 512,
            followingCount: 430,
          );
          final second = await appDbClient.getProfileStatRow(testPubkey);

          expect(second!.followerCount, equals(512));
          expect(
            second.followerCountsUpdatedAt!.isAfter(
              first!.followerCountsUpdatedAt!,
            ),
            isTrue,
            reason:
                'the counts are current, so the clock both readers share '
                'must say so',
          );
        },
      );

      test(
        'a REST-only row does not stay perpetually fresh for hysteresis',
        () async {
          // Transition 2 (#8259 review): a row that has never had a relay
          // write. If the count stamp were left NULL, _loadPersistedStats
          // would substitute cachedAt — refreshed by every upsert — and the
          // relay hysteresis would never see the baseline age.
          await dao.upsertStats(
            pubkey: testPubkey,
            followerCount: 512,
            followingCount: 430,
          );

          final row = await appDbClient.getProfileStatRow(testPubkey);
          expect(
            row!.followerCountsUpdatedAt,
            isNotNull,
            reason:
                'a REST-only row must carry its own count stamp so the '
                'hysteresis clock can age',
          );
        },
      );

      test('no-ops for a pubkey that requested deletion', () async {
        // The classic-viner seed import re-runs on every manifest bump and
        // writes counters straight to this DAO.
        await database.vanishedProfilesDao.markVanished(testPubkey);

        await dao.upsertStats(pubkey: testPubkey, videoCount: 10);

        expect(await appDbClient.getProfileStatRow(testPubkey), isNull);
      });

      test('writes resume once the vanish is cleared', () async {
        await database.vanishedProfilesDao.markVanished(testPubkey);
        await dao.upsertStats(pubkey: testPubkey, videoCount: 10);

        await database.vanishedProfilesDao.clearVanished(testPubkey);
        await dao.upsertStats(pubkey: testPubkey, videoCount: 20);

        final result = await appDbClient.getProfileStatRow(testPubkey);
        expect(result!.videoCount, equals(20));
      });
    });

    group('getStats', () {
      test('returns stats when not expired', () async {
        await dao.upsertStats(pubkey: testPubkey, videoCount: 10);

        final result = await dao.getStats(
          testPubkey,
        );

        expect(result, isNotNull);
        expect(result!.videoCount, equals(10));
      });

      test('returns null for non-existent pubkey', () async {
        final result = await dao.getStats(testPubkey);
        expect(result, isNull);
      });

      test('returns null and deletes expired stats', () async {
        await dao.upsertStats(pubkey: testPubkey, videoCount: 10);

        // Use a very short expiry to simulate expired data
        final result = await dao.getStats(
          testPubkey,
          expiry: Duration.zero,
        );

        expect(result, isNull);

        // Verify the entry was deleted
        final rawResult = await appDbClient.getProfileStatRow(testPubkey);
        expect(rawResult, isNull);
      });
    });

    group('watchStats', () {
      test('emits null when no row exists', () async {
        final stream = dao.watchStats(testPubkey);
        await expectLater(stream.first, completion(isNull));
      });

      test('emits row when stats are inserted', () async {
        final stream = dao.watchStats(testPubkey);

        Future.delayed(Duration.zero, () async {
          await dao.upsertStats(
            pubkey: testPubkey,
            videoCount: 10,
            followerCount: 100,
          );
        });

        await expectLater(
          stream.take(2),
          emitsInOrder([
            isNull,
            isA<ProfileStatRow>()
                .having((r) => r.videoCount, 'videoCount', equals(10))
                .having(
                  (r) => r.followerCount,
                  'followerCount',
                  equals(100),
                ),
          ]),
        );
      });

      test('emits updated row when stats change', () async {
        await dao.upsertStats(pubkey: testPubkey, videoCount: 10);

        final stream = dao.watchStats(testPubkey);

        Future.delayed(Duration.zero, () async {
          await dao.upsertStats(pubkey: testPubkey, videoCount: 20);
        });

        await expectLater(
          stream.take(2),
          emitsInOrder([
            isA<ProfileStatRow>().having(
              (r) => r.videoCount,
              'videoCount',
              equals(10),
            ),
            isA<ProfileStatRow>().having(
              (r) => r.videoCount,
              'videoCount',
              equals(20),
            ),
          ]),
        );
      });
    });

    group('deleteStats', () {
      test('deletes stats for a pubkey', () async {
        await dao.upsertStats(pubkey: testPubkey, videoCount: 10);
        await dao.upsertStats(pubkey: testPubkey2, videoCount: 20);

        final deleted = await dao.deleteStats(testPubkey);

        expect(deleted, equals(1));

        final result1 = await appDbClient.getProfileStatRow(testPubkey);
        final result2 = await appDbClient.getProfileStatRow(testPubkey2);

        expect(result1, isNull);
        expect(result2, isNotNull);
      });

      test('returns 0 when pubkey does not exist', () async {
        final deleted = await dao.deleteStats(testPubkey);
        expect(deleted, equals(0));
      });
    });

    group('deleteExpired', () {
      test('deletes only expired entries', () async {
        // Insert with old timestamps using direct database insert
        final oldTime = DateTime.now().subtract(const Duration(minutes: 10));
        await database
            .into(database.profileStats)
            .insert(
              ProfileStatsCompanion.insert(
                pubkey: testPubkey,
                videoCount: const Value(10),
                cachedAt: oldTime,
              ),
            );
        await database
            .into(database.profileStats)
            .insert(
              ProfileStatsCompanion.insert(
                pubkey: testPubkey2,
                videoCount: const Value(20),
                cachedAt: oldTime,
              ),
            );

        // Delete with 5 minute expiry - entries are 10 minutes old so
        // should be deleted
        final deleted = await dao.deleteExpired();

        expect(deleted, equals(2));
        expect(await appDbClient.countProfileStats(), equals(0));
      });

      test('keeps fresh entries', () async {
        await dao.upsertStats(pubkey: testPubkey, videoCount: 10);

        // Delete with long expiry should keep the entry
        final deleted = await dao.deleteExpired(
          expiry: const Duration(hours: 1),
        );

        expect(deleted, equals(0));
        expect(await appDbClient.countProfileStats(), equals(1));
      });

      test('keeps rows whose follower counts are still fresh', () async {
        // Startup cleanup runs on every cold start. Dropping this row would
        // destroy the baseline FollowRepository stabilizes lower fresh counts
        // against, so the overnight drop in #6902 would never be caught.
        final oldTime = DateTime.now().subtract(const Duration(minutes: 10));
        await database
            .into(database.profileStats)
            .insert(
              ProfileStatsCompanion.insert(
                pubkey: testPubkey,
                videoCount: const Value(10),
                followerCount: const Value(98),
                cachedAt: oldTime,
                followerCountsUpdatedAt: Value(
                  DateTime.now().subtract(const Duration(minutes: 1)),
                ),
              ),
            );

        final deleted = await dao.deleteExpired();

        expect(deleted, equals(0));
        final row = await appDbClient.getProfileStatRow(testPubkey);
        expect(row, isNotNull);
      });

      test(
        'keeps pre-upgrade rows whose follower timestamp is still NULL',
        () async {
          // Rows written before follower_counts_updated_at existed carry
          // counts with a NULL timestamp. On the first launch after the
          // v1 -> v2 upgrade those are exactly the baselines #6902 needs, so
          // NULL must fall back to cached_at rather than reading as "expired".
          final writtenAt = DateTime.now().subtract(const Duration(hours: 10));
          await database
              .into(database.profileStats)
              .insert(
                ProfileStatsCompanion.insert(
                  pubkey: testPubkey,
                  followerCount: const Value(98),
                  cachedAt: writtenAt,
                ),
              );

          final deleted = await dao.deleteExpired();

          expect(deleted, equals(0));
          final row = await appDbClient.getProfileStatRow(testPubkey);
          expect(row!.followerCount, equals(98));
        },
      );

      test(
        'deletes stats-only rows that never carried follower counts',
        () async {
          // The follower fallback must not turn the 5-minute stats cache into a
          // 48-hour one for rows that hold no counts at all.
          final oldTime = DateTime.now().subtract(const Duration(minutes: 10));
          await database
              .into(database.profileStats)
              .insert(
                ProfileStatsCompanion.insert(
                  pubkey: testPubkey,
                  videoCount: const Value(10),
                  cachedAt: oldTime,
                ),
              );

          final deleted = await dao.deleteExpired();

          expect(deleted, equals(1));
          expect(await appDbClient.countProfileStats(), equals(0));
        },
      );

      test('keeps a following-only count with a NULL timestamp', () async {
        // The other pre-upgrade shape: a row carrying only following_count.
        final writtenAt = DateTime.now().subtract(const Duration(hours: 10));
        await database
            .into(database.profileStats)
            .insert(
              ProfileStatsCompanion.insert(
                pubkey: testPubkey,
                followingCount: const Value(20),
                cachedAt: writtenAt,
              ),
            );

        expect(await dao.deleteExpired(), equals(0));
        final row = await appDbClient.getProfileStatRow(testPubkey);
        expect(row!.followingCount, equals(20));
      });

      test('deletes a NULL-timestamp row once cached_at passes the follower '
          'window', () async {
        // NULL falls back to cached_at, so a pre-upgrade row still expires
        // eventually rather than being retained forever.
        final writtenAt = DateTime.now().subtract(const Duration(hours: 72));
        await database
            .into(database.profileStats)
            .insert(
              ProfileStatsCompanion.insert(
                pubkey: testPubkey,
                followerCount: const Value(98),
                cachedAt: writtenAt,
              ),
            );

        expect(await dao.deleteExpired(), equals(1));
        expect(await appDbClient.countProfileStats(), equals(0));
      });

      test('deletes rows whose follower counts are also expired', () async {
        final oldTime = DateTime.now().subtract(const Duration(hours: 72));
        await database
            .into(database.profileStats)
            .insert(
              ProfileStatsCompanion.insert(
                pubkey: testPubkey,
                videoCount: const Value(10),
                followerCount: const Value(98),
                cachedAt: oldTime,
                followerCountsUpdatedAt: Value(oldTime),
              ),
            );

        final deleted = await dao.deleteExpired();

        expect(deleted, equals(1));
        expect(await appDbClient.countProfileStats(), equals(0));
      });
    });

    group('clearAll', () {
      test('deletes all entries', () async {
        await dao.upsertStats(pubkey: testPubkey, videoCount: 10);
        await dao.upsertStats(pubkey: testPubkey2, videoCount: 20);

        final deleted = await dao.clearAll();

        expect(deleted, equals(2));
        expect(await appDbClient.countProfileStats(), equals(0));
      });

      test('returns 0 when table is empty', () async {
        final deleted = await dao.clearAll();
        expect(deleted, equals(0));
      });
    });
  });
}
