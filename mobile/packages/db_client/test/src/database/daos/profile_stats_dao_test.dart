// ABOUTME: Unit tests for ProfileStatsDao with cache expiry logic.
// ABOUTME: Tests upsertStats, getStats freshness, 30-day retention, clearAll.

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
    group('getStatsRawMany', () {
      test(
        'returns only requested existing rows without expiry checking',
        () async {
          final old = DateTime(2020);
          await database
              .into(database.profileStats)
              .insert(
                ProfileStatsCompanion.insert(
                  pubkey: testPubkey,
                  videoCount: const Value(12),
                  cachedAt: old,
                ),
              );
          await dao.upsertStats(pubkey: testPubkey2, videoCount: 99);

          final result = await dao.getStatsRawMany([testPubkey, 'missing']);

          expect(result.keys, [testPubkey]);
          expect(result[testPubkey]!.videoCount, 12);
          expect(result[testPubkey]!.cachedAt, old);
          expect(await dao.getStatsRaw(testPubkey), isNotNull);
        },
      );

      test('returns empty for no pubkeys', () async {
        expect(await dao.getStatsRawMany([]), isEmpty);
      });

      test('reads rows across the 500-key boundary', () async {
        final pubkeys = List.generate(
          501,
          (i) => i.toRadixString(16).padLeft(64, '0'),
        );
        await database.batch((batch) {
          batch.insertAll(database.profileStats, [
            for (final pubkey in pubkeys)
              ProfileStatsCompanion.insert(
                pubkey: pubkey,
                videoCount: const Value(7),
                cachedAt: DateTime(2026),
              ),
          ]);
        });

        final result = await dao.getStatsRawMany(pubkeys);

        expect(result, hasLength(501));
        expect(result.keys, unorderedEquals(pubkeys));
        expect(result[pubkeys.last]!.videoCount, 7);
      });
    });

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

      test('returns null for a stale row but leaves it in place', () async {
        await dao.upsertStats(pubkey: testPubkey, videoCount: 10);

        // Use a very short expiry to simulate stale data
        final result = await dao.getStats(
          testPubkey,
          expiry: Duration.zero,
        );

        expect(result, isNull);

        // The row is a freshness miss, not a deletion.
        final rawResult = await appDbClient.getProfileStatRow(testPubkey);
        expect(rawResult, isNotNull);
        expect(rawResult!.videoCount, equals(10));
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
      Future<void> insertRow({
        required String pubkey,
        required DateTime cachedAt,
        int? videoCount,
        int? followerCount,
        int? followingCount,
        DateTime? followerCountsUpdatedAt,
      }) {
        return database
            .into(database.profileStats)
            .insert(
              ProfileStatsCompanion.insert(
                pubkey: pubkey,
                videoCount: Value(videoCount),
                followerCount: Value(followerCount),
                followingCount: Value(followingCount),
                cachedAt: cachedAt,
                followerCountsUpdatedAt: Value(followerCountsUpdatedAt),
              ),
            );
      }

      test('keeps a 6-day-old row with only a video count', () async {
        await insertRow(
          pubkey: testPubkey,
          videoCount: 10,
          cachedAt: DateTime.now().subtract(const Duration(days: 6)),
        );

        final deleted = await dao.deleteExpired();

        expect(deleted, equals(0));
        final row = await appDbClient.getProfileStatRow(testPubkey);
        expect(row!.videoCount, equals(10));
      });

      test('removes a 31-day-old row', () async {
        await insertRow(
          pubkey: testPubkey,
          videoCount: 10,
          cachedAt: DateTime.now().subtract(const Duration(days: 31)),
        );

        final deleted = await dao.deleteExpired();

        expect(deleted, equals(1));
        expect(await appDbClient.countProfileStats(), equals(0));
      });

      test('deletes only the rows past the window', () async {
        await insertRow(
          pubkey: testPubkey,
          videoCount: 10,
          cachedAt: DateTime.now().subtract(const Duration(days: 40)),
        );
        await insertRow(
          pubkey: testPubkey2,
          videoCount: 20,
          cachedAt: DateTime.now().subtract(const Duration(days: 2)),
        );

        final deleted = await dao.deleteExpired();

        expect(deleted, equals(1));
        expect(await appDbClient.getProfileStatRow(testPubkey), isNull);
        expect(await appDbClient.getProfileStatRow(testPubkey2), isNotNull);
      });

      test('keeps fresh entries', () async {
        await dao.upsertStats(pubkey: testPubkey, videoCount: 10);

        final deleted = await dao.deleteExpired(
          retention: const Duration(hours: 1),
        );

        expect(deleted, equals(0));
        expect(await appDbClient.countProfileStats(), equals(1));
      });

      test('honours a custom retention window', () async {
        await insertRow(
          pubkey: testPubkey,
          videoCount: 10,
          cachedAt: DateTime.now().subtract(const Duration(days: 6)),
        );

        final deleted = await dao.deleteExpired(
          retention: const Duration(days: 5),
        );

        expect(deleted, equals(1));
        expect(await appDbClient.countProfileStats(), equals(0));
      });

      test('keeps an old stats row whose follower counts are newer', () async {
        // cached_at is past the window but the counts were written recently,
        // so the follower baseline survives.
        await insertRow(
          pubkey: testPubkey,
          videoCount: 10,
          followerCount: 98,
          cachedAt: DateTime.now().subtract(const Duration(days: 40)),
          followerCountsUpdatedAt: DateTime.now().subtract(
            const Duration(days: 3),
          ),
        );

        final deleted = await dao.deleteExpired();

        expect(deleted, equals(0));
        expect(await appDbClient.getProfileStatRow(testPubkey), isNotNull);
      });

      test('keeps a NULL-timestamp row judged by cached_at alone', () async {
        // Rows written before follower_counts_updated_at existed carry counts
        // with a NULL timestamp; cached_at is their only clock.
        await insertRow(
          pubkey: testPubkey,
          followerCount: 98,
          cachedAt: DateTime.now().subtract(const Duration(days: 10)),
        );
        await insertRow(
          pubkey: testPubkey2,
          followingCount: 20,
          cachedAt: DateTime.now().subtract(const Duration(days: 35)),
        );

        final deleted = await dao.deleteExpired();

        expect(deleted, equals(1));
        final kept = await appDbClient.getProfileStatRow(testPubkey);
        expect(kept!.followerCount, equals(98));
        expect(await appDbClient.getProfileStatRow(testPubkey2), isNull);
      });

      test(
        'deletes rows whose follower counts are also past the window',
        () async {
          final oldTime = DateTime.now().subtract(const Duration(days: 45));
          await insertRow(
            pubkey: testPubkey,
            videoCount: 10,
            followerCount: 98,
            cachedAt: oldTime,
            followerCountsUpdatedAt: oldTime,
          );

          final deleted = await dao.deleteExpired();

          expect(deleted, equals(1));
          expect(await appDbClient.countProfileStats(), equals(0));
        },
      );
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
