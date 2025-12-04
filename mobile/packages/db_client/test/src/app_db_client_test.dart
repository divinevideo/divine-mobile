// ABOUTME: Unit tests for AppDbClient hybrid database wrapper.
// ABOUTME: Tests typed domain methods for NostrEvents, UserProfiles,
// and VideoMetrics.

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
    // Create a temporary database file for testing
    final tempDir = Directory.systemTemp.createTempSync('db_client_test_');
    tempDbPath = '${tempDir.path}/test.db';

    database = AppDatabase.test(tempDbPath);
    dbClient = DbClient(generatedDatabase: database);
    appDbClient = AppDbClient(dbClient, database);
  });

  tearDown(() async {
    await database.close();
    // Clean up temp file
    final file = File(tempDbPath);
    if (file.existsSync()) {
      file.deleteSync();
    }
    final dir = Directory(tempDbPath).parent;
    if (dir.existsSync()) {
      dir.deleteSync(recursive: true);
    }
  });

  group('AppDbClient', () {
    test('can be instantiated', () {
      expect(appDbClient, isNotNull);
      expect(appDbClient.dbClient, equals(dbClient));
      expect(appDbClient.database, equals(database));
    });

    group('NostrEvents operations', () {
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

      test('getEvent returns event by ID', () async {
        await insertTestEvent(id: 'evt1', pubkey: 'pub1', kind: 34236);

        final result = await appDbClient.getEvent('evt1');

        expect(result, isNotNull);
        expect(result!.id, equals('evt1'));
        expect(result.pubkey, equals('pub1'));
        expect(result.kind, equals(34236));
      });

      test('getEvent returns null for non-existent ID', () async {
        final result = await appDbClient.getEvent('nonexistent');

        expect(result, isNull);
      });

      test('getEventsByIds returns multiple events', () async {
        await insertTestEvent(id: 'evt1', pubkey: 'pub1', kind: 34236);
        await insertTestEvent(id: 'evt2', pubkey: 'pub2', kind: 34236);
        await insertTestEvent(id: 'evt3', pubkey: 'pub3', kind: 34236);

        final results = await appDbClient.getEventsByIds(['evt1', 'evt3']);

        expect(results.length, equals(2));
        expect(results.map((e) => e.id), containsAll(['evt1', 'evt3']));
      });

      test('getEventsByIds returns empty list for empty input', () async {
        final results = await appDbClient.getEventsByIds([]);

        expect(results, isEmpty);
      });

      test('getEventsByKind returns events filtered by kind', () async {
        await insertTestEvent(id: 'video1', pubkey: 'pub1', kind: 34236);
        await insertTestEvent(id: 'video2', pubkey: 'pub2', kind: 34236);
        await insertTestEvent(id: 'profile1', pubkey: 'pub3', kind: 0);

        final results = await appDbClient.getEventsByKind(34236);

        expect(results.length, equals(2));
        expect(results.every((e) => e.kind == 34236), isTrue);
      });

      test('getEventsByKind respects limit and offset', () async {
        for (var i = 0; i < 5; i++) {
          await insertTestEvent(
            id: 'evt$i',
            pubkey: 'pub$i',
            kind: 34236,
            createdAt: 1000 + i, // Ascending timestamps
          );
        }

        final results = await appDbClient.getEventsByKind(
          34236,
          limit: 2,
          offset: 1,
        );

        expect(results.length, equals(2));
        // Results are ordered by createdAt DESC, so offset 1 skips the newest
        expect(results[0].id, equals('evt3'));
        expect(results[1].id, equals('evt2'));
      });

      test('getEventsByAuthor returns events by pubkey', () async {
        await insertTestEvent(id: 'evt1', pubkey: 'author1', kind: 34236);
        await insertTestEvent(id: 'evt2', pubkey: 'author1', kind: 34236);
        await insertTestEvent(id: 'evt3', pubkey: 'author2', kind: 34236);

        final results = await appDbClient.getEventsByAuthor('author1');

        expect(results.length, equals(2));
        expect(results.every((e) => e.pubkey == 'author1'), isTrue);
      });

      test('getEventsByAuthor filters by kind when specified', () async {
        await insertTestEvent(id: 'video1', pubkey: 'author1', kind: 34236);
        await insertTestEvent(id: 'profile1', pubkey: 'author1', kind: 0);

        final results = await appDbClient.getEventsByAuthor(
          'author1',
          kind: 34236,
        );

        expect(results.length, equals(1));
        expect(results[0].kind, equals(34236));
      });

      test('watchEvent emits event changes', () async {
        final stream = appDbClient.watchEvent('watch_evt');

        // Insert event after starting watch
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

      test('watchEventsByKind emits filtered events', () async {
        final stream = appDbClient.watchEventsByKind(34236, limit: 10);

        // Insert events after starting watch
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

      test('watchEventsByAuthor emits author events', () async {
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

      test('deleteEvent removes event', () async {
        await insertTestEvent(id: 'to_delete', pubkey: 'pub1', kind: 34236);

        final deleteCount = await appDbClient.deleteEvent('to_delete');

        expect(deleteCount, equals(1));

        final result = await appDbClient.getEvent('to_delete');
        expect(result, isNull);
      });

      test('countEventsByKind returns correct count', () async {
        await insertTestEvent(id: 'video1', pubkey: 'pub1', kind: 34236);
        await insertTestEvent(id: 'video2', pubkey: 'pub2', kind: 34236);
        await insertTestEvent(id: 'profile1', pubkey: 'pub3', kind: 0);

        final videoCount = await appDbClient.countEventsByKind(34236);
        final profileCount = await appDbClient.countEventsByKind(0);

        expect(videoCount, equals(2));
        expect(profileCount, equals(1));
      });
    });

    group('UserProfiles operations', () {
      test('upsertProfile inserts a new profile', () async {
        final profile = UserProfilesCompanion.insert(
          pubkey: 'pubkey123',
          createdAt: DateTime.now(),
          eventId: 'event123',
          lastFetched: DateTime.timestamp(),
        );

        final result = await appDbClient.upsertProfile(profile);

        expect(result.pubkey, equals('pubkey123'));
        expect(result.eventId, equals('event123'));
      });

      test('getProfile returns profile by pubkey', () async {
        final profile = UserProfilesCompanion.insert(
          pubkey: 'pubkey456',
          name: const Value('Test User'),
          displayName: const Value('Test Display'),
          createdAt: DateTime.now(),
          eventId: 'event456',
          lastFetched: DateTime.timestamp(),
        );
        await appDbClient.upsertProfile(profile);

        final result = await appDbClient.getProfile('pubkey456');

        expect(result, isNotNull);
        expect(result!.pubkey, equals('pubkey456'));
        expect(result.name, equals('Test User'));
        expect(result.displayName, equals('Test Display'));
      });

      test('getProfile returns null for non-existent pubkey', () async {
        final result = await appDbClient.getProfile('nonexistent');

        expect(result, isNull);
      });

      test('getProfilesByPubkeys returns multiple profiles', () async {
        await appDbClient.upsertProfile(
          UserProfilesCompanion.insert(
            pubkey: 'pub1',
            createdAt: DateTime.now(),
            eventId: 'evt1',
            lastFetched: DateTime.timestamp(),
          ),
        );
        await appDbClient.upsertProfile(
          UserProfilesCompanion.insert(
            pubkey: 'pub2',
            createdAt: DateTime.now(),
            eventId: 'evt2',
            lastFetched: DateTime.timestamp(),
          ),
        );
        await appDbClient.upsertProfile(
          UserProfilesCompanion.insert(
            pubkey: 'pub3',
            createdAt: DateTime.now(),
            eventId: 'evt3',
            lastFetched: DateTime.timestamp(),
          ),
        );

        final results = await appDbClient.getProfilesByPubkeys(
          ['pub1', 'pub3'],
        );

        expect(results.length, equals(2));
        expect(results.map((p) => p.pubkey), containsAll(['pub1', 'pub3']));
      });

      test('deleteProfile removes profile', () async {
        await appDbClient.upsertProfile(
          UserProfilesCompanion.insert(
            pubkey: 'to_delete',
            createdAt: DateTime.now(),
            eventId: 'evt_del',
            lastFetched: DateTime.timestamp(),
          ),
        );

        final deleteCount = await appDbClient.deleteProfile('to_delete');

        expect(deleteCount, equals(1));

        final result = await appDbClient.getProfile('to_delete');
        expect(result, isNull);
      });

      test('countProfiles returns correct count', () async {
        await appDbClient.upsertProfile(
          UserProfilesCompanion.insert(
            pubkey: 'count1',
            createdAt: DateTime.now(),
            eventId: 'evt_c1',
            lastFetched: DateTime.timestamp(),
          ),
        );
        await appDbClient.upsertProfile(
          UserProfilesCompanion.insert(
            pubkey: 'count2',
            createdAt: DateTime.now(),
            eventId: 'evt_c2',
            lastFetched: DateTime.timestamp(),
          ),
        );

        final count = await appDbClient.countProfiles();

        expect(count, equals(2));
      });

      test('watchProfile emits profile changes', () async {
        final stream = appDbClient.watchProfile('watch_pubkey');

        // Insert profile after starting watch
        Future.delayed(const Duration(milliseconds: 50), () async {
          await appDbClient.upsertProfile(
            UserProfilesCompanion.insert(
              pubkey: 'watch_pubkey',
              name: const Value('Watched User'),
              createdAt: DateTime.now(),
              eventId: 'evt_watch',
              lastFetched: DateTime.timestamp(),
            ),
          );
        });

        // First emission should be null (profile doesn't exist yet)
        // Second emission should be the profile
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

      test('upsertProfile updates existing profile', () async {
        // Insert initial profile
        await appDbClient.upsertProfile(
          UserProfilesCompanion.insert(
            pubkey: 'update_pubkey',
            name: const Value('Original Name'),
            createdAt: DateTime.now(),
            eventId: 'evt_original',
            lastFetched: DateTime.timestamp(),
          ),
        );

        // Update with new data
        await appDbClient.upsertProfile(
          UserProfilesCompanion.insert(
            pubkey: 'update_pubkey',
            name: const Value('Updated Name'),
            displayName: const Value('New Display'),
            createdAt: DateTime.now(),
            eventId: 'evt_updated',
            lastFetched: DateTime.timestamp(),
          ),
        );

        final result = await appDbClient.getProfile('update_pubkey');

        expect(result, isNotNull);
        expect(result!.name, equals('Updated Name'));
        expect(result.displayName, equals('New Display'));
        expect(result.eventId, equals('evt_updated'));
      });

      test('getAllProfiles returns all profiles with pagination', () async {
        for (var i = 0; i < 5; i++) {
          await appDbClient.upsertProfile(
            UserProfilesCompanion.insert(
              pubkey: 'all_pub$i',
              createdAt: DateTime.now().add(Duration(seconds: i)),
              eventId: 'evt_all$i',
              lastFetched: DateTime.timestamp(),
            ),
          );
        }

        final allProfiles = await appDbClient.getAllProfiles();
        expect(allProfiles.length, equals(5));

        final limitedProfiles = await appDbClient.getAllProfiles(
          limit: 2,
          offset: 1,
        );
        expect(limitedProfiles.length, equals(2));
      });

      test('watchProfilesByPubkeys emits multiple profile changes', () async {
        final stream = appDbClient.watchProfilesByPubkeys(['wp1', 'wp2']);

        Future.delayed(const Duration(milliseconds: 50), () async {
          await appDbClient.upsertProfile(
            UserProfilesCompanion.insert(
              pubkey: 'wp1',
              createdAt: DateTime.now(),
              eventId: 'evt_wp1',
              lastFetched: DateTime.timestamp(),
            ),
          );
          await appDbClient.upsertProfile(
            UserProfilesCompanion.insert(
              pubkey: 'wp2',
              createdAt: DateTime.now(),
              eventId: 'evt_wp2',
              lastFetched: DateTime.timestamp(),
            ),
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

      test('watchProfilesByPubkeys returns empty stream for empty input',
          () async {
        final stream = appDbClient.watchProfilesByPubkeys([]);

        await expectLater(
          stream.first,
          completion(isEmpty),
        );
      });
    });

    group('VideoMetrics operations', () {
      test('upsertVideoMetrics inserts metrics', () async {
        final metrics = VideoMetricsCompanion.insert(
          eventId: 'video123',
          updatedAt: DateTime.now(),
          loopCount: const Value(100),
          likes: const Value(50),
        );

        final result = await appDbClient.upsertVideoMetrics(metrics);

        expect(result.eventId, equals('video123'));
        expect(result.loopCount, equals(100));
        expect(result.likes, equals(50));
      });

      test('getVideoMetrics returns metrics by event ID', () async {
        await appDbClient.upsertVideoMetrics(
          VideoMetricsCompanion.insert(
            eventId: 'video456',
            updatedAt: DateTime.now(),
            loopCount: const Value(200),
            views: const Value(1000),
          ),
        );

        final result = await appDbClient.getVideoMetrics('video456');

        expect(result, isNotNull);
        expect(result!.loopCount, equals(200));
        expect(result.views, equals(1000));
      });

      test('getTopVideosByLoops returns sorted by loop count', () async {
        await appDbClient.upsertVideoMetrics(
          VideoMetricsCompanion.insert(
            eventId: 'low_loops',
            updatedAt: DateTime.now(),
            loopCount: const Value(10),
          ),
        );
        await appDbClient.upsertVideoMetrics(
          VideoMetricsCompanion.insert(
            eventId: 'high_loops',
            updatedAt: DateTime.now(),
            loopCount: const Value(1000),
          ),
        );
        await appDbClient.upsertVideoMetrics(
          VideoMetricsCompanion.insert(
            eventId: 'mid_loops',
            updatedAt: DateTime.now(),
            loopCount: const Value(500),
          ),
        );

        final results = await appDbClient.getTopVideosByLoops(limit: 3);

        expect(results.length, equals(3));
        expect(results[0].eventId, equals('high_loops'));
        expect(results[1].eventId, equals('mid_loops'));
        expect(results[2].eventId, equals('low_loops'));
      });

      test('deleteVideoMetrics removes metrics', () async {
        await appDbClient.upsertVideoMetrics(
          VideoMetricsCompanion.insert(
            eventId: 'to_delete_metrics',
            updatedAt: DateTime.now(),
          ),
        );

        final deleteCount = await appDbClient.deleteVideoMetrics(
          'to_delete_metrics',
        );

        expect(deleteCount, equals(1));

        final result = await appDbClient.getVideoMetrics('to_delete_metrics');
        expect(result, isNull);
      });
    });
  });
}
