// ABOUTME: Unit tests for AppDbClient hybrid database wrapper.
// ABOUTME: Tests typed methods for NostrEvents, UserProfiles, VideoMetrics.

import 'dart:io';

import 'package:db_client/db_client.dart';
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:test/test.dart';

void main() {
  late AppDatabase database;
  late DbClient dbClient;
  late AppDbClient appDbClient;
  late String tempDbPath;

  setUp(() async {
    final tempDir = Directory.systemTemp.createTempSync('db_client_test_');
    tempDbPath = '${tempDir.path}/test.db';

    database = AppDatabase.test(tempDbPath);
    dbClient = DbClient(generatedDatabase: database);
    appDbClient = AppDbClient(dbClient, database);
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

  /// Helper to insert a test Nostr event.
  Future<void> insertTestEvent({
    required String id,
    required String pubkey,
    required int kind,
    int? createdAt,
  }) async {
    await database.into(database.nostrEvents).insert(
      NostrEventsCompanion.insert(
        id: id,
        pubkey: pubkey,
        createdAt: createdAt ?? DateTime.now().millisecondsSinceEpoch ~/ 1000,
        kind: kind,
        tags: '[]',
        content: 'test content',
        sig: 'test_sig_$id',
      ),
    );
  }

  /// Helper to create a UserProfilesCompanion for testing.
  UserProfilesCompanion createProfile({
    required String pubkey,
    required String eventId,
    String? name,
    String? displayName,
  }) {
    return UserProfilesCompanion.insert(
      pubkey: pubkey,
      eventId: eventId,
      name: name != null ? Value(name) : const Value.absent(),
      displayName:
          displayName != null ? Value(displayName) : const Value.absent(),
      createdAt: DateTime.now(),
      lastFetched: DateTime.timestamp(),
    );
  }

  /// Helper to create a VideoMetricsCompanion for testing.
  VideoMetricsCompanion createMetrics({
    required String eventId,
    int? loopCount,
    int? likes,
    int? views,
  }) {
    return VideoMetricsCompanion.insert(
      eventId: eventId,
      updatedAt: DateTime.now(),
      loopCount: loopCount != null ? Value(loopCount) : const Value.absent(),
      likes: likes != null ? Value(likes) : const Value.absent(),
      views: views != null ? Value(views) : const Value.absent(),
    );
  }

  group('AppDbClient', () {
    test('can be instantiated', () {
      expect(appDbClient, isNotNull);
      expect(appDbClient.dbClient, equals(dbClient));
      expect(appDbClient.database, equals(database));
    });

    group('NostrEvents', () {
      group('getEvent', () {
        test('returns event by ID', () async {
          await insertTestEvent(id: 'evt1', pubkey: 'pub1', kind: 34236);

          final result = await appDbClient.getEvent('evt1');

          expect(result, isNotNull);
          expect(result!.id, equals('evt1'));
          expect(result.pubkey, equals('pub1'));
          expect(result.kind, equals(34236));
        });

        test('returns null for non-existent ID', () async {
          final result = await appDbClient.getEvent('nonexistent');

          expect(result, isNull);
        });
      });

      group('getEventsByIds', () {
        test('returns multiple events', () async {
          await insertTestEvent(id: 'evt1', pubkey: 'pub1', kind: 34236);
          await insertTestEvent(id: 'evt2', pubkey: 'pub2', kind: 34236);
          await insertTestEvent(id: 'evt3', pubkey: 'pub3', kind: 34236);

          final results = await appDbClient.getEventsByIds(['evt1', 'evt3']);

          expect(results.length, equals(2));
          expect(results.map((e) => e.id), containsAll(['evt1', 'evt3']));
        });

        test('returns empty list for empty input', () async {
          final results = await appDbClient.getEventsByIds([]);

          expect(results, isEmpty);
        });
      });

      group('getEventsByKind', () {
        test('returns events filtered by kind', () async {
          await insertTestEvent(id: 'video1', pubkey: 'pub1', kind: 34236);
          await insertTestEvent(id: 'video2', pubkey: 'pub2', kind: 34236);
          await insertTestEvent(id: 'profile1', pubkey: 'pub3', kind: 0);

          final results = await appDbClient.getEventsByKind(34236);

          expect(results.length, equals(2));
          expect(results.every((e) => e.kind == 34236), isTrue);
        });

        test('respects limit and offset', () async {
          for (var i = 0; i < 5; i++) {
            await insertTestEvent(
              id: 'evt$i',
              pubkey: 'pub$i',
              kind: 34236,
              createdAt: 1000 + i,
            );
          }

          final results = await appDbClient.getEventsByKind(
            34236,
            limit: 2,
            offset: 1,
          );

          expect(results.length, equals(2));
          expect(results[0].id, equals('evt3'));
          expect(results[1].id, equals('evt2'));
        });
      });

      group('getEventsByAuthor', () {
        test('returns events by pubkey', () async {
          await insertTestEvent(id: 'evt1', pubkey: 'author1', kind: 34236);
          await insertTestEvent(id: 'evt2', pubkey: 'author1', kind: 34236);
          await insertTestEvent(id: 'evt3', pubkey: 'author2', kind: 34236);

          final results = await appDbClient.getEventsByAuthor('author1');

          expect(results.length, equals(2));
          expect(results.every((e) => e.pubkey == 'author1'), isTrue);
        });

        test('filters by kind when specified', () async {
          await insertTestEvent(id: 'video1', pubkey: 'author1', kind: 34236);
          await insertTestEvent(id: 'profile1', pubkey: 'author1', kind: 0);

          final results = await appDbClient.getEventsByAuthor(
            'author1',
            kind: 34236,
          );

          expect(results.length, equals(1));
          expect(results[0].kind, equals(34236));
        });
      });

      group('watchEvent', () {
        test('emits event changes', () async {
          final stream = appDbClient.watchEvent('watch_evt');

          Future.delayed(const Duration(milliseconds: 50), () async {
            await insertTestEvent(
              id: 'watch_evt',
              pubkey: 'watch_pub',
              kind: 34236,
            );
          });

          await expectLater(
            stream.take(2),
            emitsInOrder([
              isNull,
              isA<NostrEventRow>().having((e) => e.id, 'id', 'watch_evt'),
            ]),
          );
        });
      });

      group('watchEventsByKind', () {
        test('emits filtered events', () async {
          final stream = appDbClient.watchEventsByKind(34236, limit: 10);

          Future.delayed(const Duration(milliseconds: 50), () async {
            await insertTestEvent(id: 'video1', pubkey: 'pub1', kind: 34236);
            await insertTestEvent(id: 'profile1', pubkey: 'pub2', kind: 0);
          });

          await expectLater(
            stream.take(2),
            emitsInOrder([
              isEmpty,
              hasLength(1),
            ]),
          );
        });
      });

      group('watchEventsByAuthor', () {
        test('emits author events', () async {
          final stream = appDbClient.watchEventsByAuthor('author1', limit: 10);

          Future.delayed(const Duration(milliseconds: 50), () async {
            await insertTestEvent(id: 'evt1', pubkey: 'author1', kind: 34236);
            await insertTestEvent(id: 'evt2', pubkey: 'author2', kind: 34236);
          });

          await expectLater(
            stream.take(2),
            emitsInOrder([
              isEmpty,
              hasLength(1),
            ]),
          );
        });
      });

      group('deleteEvent', () {
        test('removes event and returns count', () async {
          await insertTestEvent(id: 'to_delete', pubkey: 'pub1', kind: 34236);

          final deleteCount = await appDbClient.deleteEvent('to_delete');

          expect(deleteCount, equals(1));

          final result = await appDbClient.getEvent('to_delete');
          expect(result, isNull);
        });
      });

      group('countEventsByKind', () {
        test('returns correct count', () async {
          await insertTestEvent(id: 'video1', pubkey: 'pub1', kind: 34236);
          await insertTestEvent(id: 'video2', pubkey: 'pub2', kind: 34236);
          await insertTestEvent(id: 'profile1', pubkey: 'pub3', kind: 0);

          final videoCount = await appDbClient.countEventsByKind(34236);
          final profileCount = await appDbClient.countEventsByKind(0);

          expect(videoCount, equals(2));
          expect(profileCount, equals(1));
        });
      });
    });

    group('UserProfiles', () {
      group('upsertProfile', () {
        test('inserts a new profile', () async {
          final profile = createProfile(
            pubkey: 'pubkey123',
            eventId: 'event123',
          );

          final result = await appDbClient.upsertProfile(profile);

          expect(result.pubkey, equals('pubkey123'));
          expect(result.eventId, equals('event123'));
        });

        test('updates existing profile', () async {
          await appDbClient.upsertProfile(
            createProfile(
              pubkey: 'update_pubkey',
              eventId: 'evt_original',
              name: 'Original Name',
            ),
          );

          await appDbClient.upsertProfile(
            createProfile(
              pubkey: 'update_pubkey',
              eventId: 'evt_updated',
              name: 'Updated Name',
              displayName: 'New Display',
            ),
          );

          final result = await appDbClient.getProfile('update_pubkey');

          expect(result, isNotNull);
          expect(result!.name, equals('Updated Name'));
          expect(result.displayName, equals('New Display'));
          expect(result.eventId, equals('evt_updated'));
        });
      });

      group('getProfile', () {
        test('returns profile by pubkey', () async {
          await appDbClient.upsertProfile(
            createProfile(
              pubkey: 'pubkey456',
              eventId: 'event456',
              name: 'Test User',
              displayName: 'Test Display',
            ),
          );

          final result = await appDbClient.getProfile('pubkey456');

          expect(result, isNotNull);
          expect(result!.pubkey, equals('pubkey456'));
          expect(result.name, equals('Test User'));
          expect(result.displayName, equals('Test Display'));
        });

        test('returns null for non-existent pubkey', () async {
          final result = await appDbClient.getProfile('nonexistent');

          expect(result, isNull);
        });
      });

      group('getProfilesByPubkeys', () {
        test('returns multiple profiles', () async {
          await appDbClient.upsertProfile(
            createProfile(pubkey: 'pub1', eventId: 'evt1'),
          );
          await appDbClient.upsertProfile(
            createProfile(pubkey: 'pub2', eventId: 'evt2'),
          );
          await appDbClient.upsertProfile(
            createProfile(pubkey: 'pub3', eventId: 'evt3'),
          );

          final results = await appDbClient.getProfilesByPubkeys(
            ['pub1', 'pub3'],
          );

          expect(results.length, equals(2));
          expect(results.map((p) => p.pubkey), containsAll(['pub1', 'pub3']));
        });
      });

      group('getAllProfiles', () {
        test('returns all profiles', () async {
          for (var i = 0; i < 5; i++) {
            await appDbClient.upsertProfile(
              createProfile(pubkey: 'all_pub$i', eventId: 'evt_all$i'),
            );
          }

          final allProfiles = await appDbClient.getAllProfiles();

          expect(allProfiles.length, equals(5));
        });

        test('respects limit and offset', () async {
          for (var i = 0; i < 5; i++) {
            await appDbClient.upsertProfile(
              createProfile(pubkey: 'all_pub$i', eventId: 'evt_all$i'),
            );
          }

          final limitedProfiles = await appDbClient.getAllProfiles(
            limit: 2,
            offset: 1,
          );

          expect(limitedProfiles.length, equals(2));
        });
      });

      group('watchProfile', () {
        test('emits profile changes', () async {
          final stream = appDbClient.watchProfile('watch_pubkey');

          Future.delayed(const Duration(milliseconds: 50), () async {
            await appDbClient.upsertProfile(
              createProfile(
                pubkey: 'watch_pubkey',
                eventId: 'evt_watch',
                name: 'Watched User',
              ),
            );
          });

          await expectLater(
            stream.take(2),
            emitsInOrder([
              isNull,
              isA<UserProfileRow>().having(
                (p) => p.name,
                'name',
                'Watched User',
              ),
            ]),
          );
        });
      });

      group('watchProfilesByPubkeys', () {
        test('emits multiple profile changes', () async {
          final stream = appDbClient.watchProfilesByPubkeys(['wp1', 'wp2']);

          Future.delayed(const Duration(milliseconds: 50), () async {
            await appDbClient.upsertProfile(
              createProfile(pubkey: 'wp1', eventId: 'evt_wp1'),
            );
            await appDbClient.upsertProfile(
              createProfile(pubkey: 'wp2', eventId: 'evt_wp2'),
            );
          });

          await expectLater(
            stream.take(3),
            emitsInOrder([
              isEmpty,
              hasLength(1),
              hasLength(2),
            ]),
          );
        });

        test('returns empty stream for empty input', () async {
          final stream = appDbClient.watchProfilesByPubkeys([]);

          await expectLater(
            stream.first,
            completion(isEmpty),
          );
        });
      });

      group('deleteProfile', () {
        test('removes profile and returns count', () async {
          await appDbClient.upsertProfile(
            createProfile(pubkey: 'to_delete', eventId: 'evt_del'),
          );

          final deleteCount = await appDbClient.deleteProfile('to_delete');

          expect(deleteCount, equals(1));

          final result = await appDbClient.getProfile('to_delete');
          expect(result, isNull);
        });
      });

      group('countProfiles', () {
        test('returns correct count', () async {
          await appDbClient.upsertProfile(
            createProfile(pubkey: 'count1', eventId: 'evt_c1'),
          );
          await appDbClient.upsertProfile(
            createProfile(pubkey: 'count2', eventId: 'evt_c2'),
          );

          final count = await appDbClient.countProfiles();

          expect(count, equals(2));
        });
      });
    });

    group('VideoMetrics', () {
      group('upsertVideoMetrics', () {
        test('inserts metrics', () async {
          final metrics = createMetrics(
            eventId: 'video123',
            loopCount: 100,
            likes: 50,
          );

          final result = await appDbClient.upsertVideoMetrics(metrics);

          expect(result.eventId, equals('video123'));
          expect(result.loopCount, equals(100));
          expect(result.likes, equals(50));
        });

        test('updates existing metrics', () async {
          await appDbClient.upsertVideoMetrics(
            createMetrics(eventId: 'update_metrics', loopCount: 100),
          );

          await appDbClient.upsertVideoMetrics(
            createMetrics(eventId: 'update_metrics', loopCount: 200, likes: 50),
          );

          final result = await appDbClient.getVideoMetrics('update_metrics');

          expect(result, isNotNull);
          expect(result!.loopCount, equals(200));
          expect(result.likes, equals(50));
        });
      });

      group('getVideoMetrics', () {
        test('returns metrics by event ID', () async {
          await appDbClient.upsertVideoMetrics(
            createMetrics(eventId: 'video456', loopCount: 200, views: 1000),
          );

          final result = await appDbClient.getVideoMetrics('video456');

          expect(result, isNotNull);
          expect(result!.loopCount, equals(200));
          expect(result.views, equals(1000));
        });

        test('returns null for non-existent ID', () async {
          final result = await appDbClient.getVideoMetrics('nonexistent');

          expect(result, isNull);
        });
      });

      group('getVideoMetricsByIds', () {
        test('returns multiple metrics', () async {
          await appDbClient.upsertVideoMetrics(
            createMetrics(eventId: 'metrics1', loopCount: 100),
          );
          await appDbClient.upsertVideoMetrics(
            createMetrics(eventId: 'metrics2', loopCount: 200),
          );
          await appDbClient.upsertVideoMetrics(
            createMetrics(eventId: 'metrics3', loopCount: 300),
          );

          final results = await appDbClient.getVideoMetricsByIds(
            ['metrics1', 'metrics3'],
          );

          expect(results.length, equals(2));
          expect(
            results.map((m) => m.eventId),
            containsAll(['metrics1', 'metrics3']),
          );
        });

        test('returns empty list for empty input', () async {
          final results = await appDbClient.getVideoMetricsByIds([]);

          expect(results, isEmpty);
        });
      });

      group('getTopVideosByLoops', () {
        test('returns sorted by loop count descending', () async {
          await appDbClient.upsertVideoMetrics(
            createMetrics(eventId: 'low_loops', loopCount: 10),
          );
          await appDbClient.upsertVideoMetrics(
            createMetrics(eventId: 'high_loops', loopCount: 1000),
          );
          await appDbClient.upsertVideoMetrics(
            createMetrics(eventId: 'mid_loops', loopCount: 500),
          );

          final results = await appDbClient.getTopVideosByLoops(limit: 3);

          expect(results.length, equals(3));
          expect(results[0].eventId, equals('high_loops'));
          expect(results[1].eventId, equals('mid_loops'));
          expect(results[2].eventId, equals('low_loops'));
        });
      });

      group('getTopVideosByLikes', () {
        test('returns sorted by likes descending', () async {
          await appDbClient.upsertVideoMetrics(
            createMetrics(eventId: 'low_likes', likes: 10),
          );
          await appDbClient.upsertVideoMetrics(
            createMetrics(eventId: 'high_likes', likes: 1000),
          );
          await appDbClient.upsertVideoMetrics(
            createMetrics(eventId: 'mid_likes', likes: 500),
          );

          final results = await appDbClient.getTopVideosByLikes(limit: 3);

          expect(results.length, equals(3));
          expect(results[0].eventId, equals('high_likes'));
          expect(results[1].eventId, equals('mid_likes'));
          expect(results[2].eventId, equals('low_likes'));
        });
      });

      group('watchVideoMetrics', () {
        test('emits metrics changes', () async {
          final stream = appDbClient.watchVideoMetrics('watch_metrics');

          Future.delayed(const Duration(milliseconds: 50), () async {
            await appDbClient.upsertVideoMetrics(
              createMetrics(eventId: 'watch_metrics', loopCount: 999),
            );
          });

          await expectLater(
            stream.take(2),
            emitsInOrder([
              isNull,
              isA<VideoMetricRow>().having(
                (m) => m.loopCount,
                'loopCount',
                999,
              ),
            ]),
          );
        });
      });

      group('watchTopVideosByLoops', () {
        test('emits sorted list', () async {
          final stream = appDbClient.watchTopVideosByLoops(limit: 10);

          Future.delayed(const Duration(milliseconds: 50), () async {
            await appDbClient.upsertVideoMetrics(
              createMetrics(eventId: 'watch_loops1', loopCount: 100),
            );
            await appDbClient.upsertVideoMetrics(
              createMetrics(eventId: 'watch_loops2', loopCount: 200),
            );
          });

          await expectLater(
            stream.take(3),
            emitsInOrder([
              isEmpty,
              hasLength(1),
              hasLength(2),
            ]),
          );
        });
      });

      group('deleteVideoMetrics', () {
        test('removes metrics and returns count', () async {
          await appDbClient.upsertVideoMetrics(
            createMetrics(eventId: 'to_delete_metrics'),
          );

          final deleteCount = await appDbClient.deleteVideoMetrics(
            'to_delete_metrics',
          );

          expect(deleteCount, equals(1));

          final result = await appDbClient.getVideoMetrics('to_delete_metrics');
          expect(result, isNull);
        });
      });

      group('countVideoMetrics', () {
        test('returns correct count', () async {
          await appDbClient.upsertVideoMetrics(
            createMetrics(eventId: 'count1'),
          );
          await appDbClient.upsertVideoMetrics(
            createMetrics(eventId: 'count2'),
          );
          await appDbClient.upsertVideoMetrics(
            createMetrics(eventId: 'count3'),
          );

          final count = await appDbClient.countVideoMetrics();

          expect(count, equals(3));
        });
      });
    });
  });
}
