// ABOUTME: Unit tests for NostrEventsDao with Event model operations.
// ABOUTME: Tests upsertEvent, upsertEventsBatch, and getVideoEventsByFilter.

import 'dart:io';

import 'package:db_client/db_client.dart';
import 'package:drift/native.dart';
import 'package:nostr_sdk/event.dart';
import 'package:test/test.dart';

void main() {
  late AppDatabase database;
  late DbClient dbClient;
  late AppDbClient appDbClient;
  late NostrEventsDao dao;
  late String tempDbPath;

  /// Valid 64-char hex pubkey for testing
  const testPubkey =
      '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef';
  const testPubkey2 =
      'fedcba9876543210fedcba9876543210fedcba9876543210fedcba9876543210';

  /// Helper to create a valid Nostr Event for testing.
  Event createEvent({
    String pubkey = testPubkey,
    int kind = 1,
    List<List<String>>? tags,
    String content = 'test content',
    int? createdAt,
  }) {
    final event = Event(
      pubkey,
      kind,
      tags ?? [],
      content,
      createdAt: createdAt,
    )..sig = 'testsig$testPubkey';
    return event;
  }

  /// Counter for unique d-tags in video events
  var videoEventCounter = 0;

  /// Helper to create a video event (kind 34236) with metrics tags.
  /// Each video event gets a unique d-tag since kind 34236 is parameterized
  /// replaceable (NIP-01).
  Event createVideoEvent({
    String pubkey = testPubkey,
    int? loops,
    int? likes,
    int? comments,
    List<String>? hashtags,
    int? createdAt,
    String? dTag,
  }) {
    final tags = <List<String>>[];

    // Add unique d-tag for parameterized replaceable events
    final uniqueDTag = dTag ?? 'video_${videoEventCounter++}';
    tags.add(['d', uniqueDTag]);

    if (loops != null) {
      tags.add(['loops', loops.toString()]);
    }
    if (likes != null) {
      tags.add(['likes', likes.toString()]);
    }
    if (comments != null) {
      tags.add(['comments', comments.toString()]);
    }
    if (hashtags != null) {
      for (final tag in hashtags) {
        tags.add(['t', tag.toLowerCase()]);
      }
    }

    // Add required video URL
    tags.add(['url', 'https://example.com/video.mp4']);

    return createEvent(
      pubkey: pubkey,
      kind: 34236,
      tags: tags,
      createdAt: createdAt,
    );
  }

  setUp(() async {
    // Reset counter for unique d-tags
    videoEventCounter = 0;

    final tempDir = Directory.systemTemp.createTempSync('dao_test_');
    tempDbPath = '${tempDir.path}/test.db';

    database = AppDatabase.test(NativeDatabase(File(tempDbPath)));
    dbClient = DbClient(generatedDatabase: database);
    appDbClient = AppDbClient(dbClient, database);
    dao = database.nostrEventsDao;
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

  group('NostrEventsDao', () {
    group('upsertEvent', () {
      test('inserts a new event', () async {
        final event = createEvent();

        await dao.upsertEvent(event);

        final result = await appDbClient.getEvent(event.id);
        expect(result, isNotNull);
        expect(result!.pubkey, equals(testPubkey));
        expect(result.kind, equals(1));
        expect(result.content, equals('test content'));
      });

      test('replaces existing event with same ID', () async {
        final event1 = createEvent(content: 'original content');
        await dao.upsertEvent(event1);

        // Create new event with same properties (same ID)
        final event2 = createEvent(content: 'original content')
          ..sig = 'updated_sig';
        await dao.upsertEvent(event2);

        final result = await appDbClient.getEvent(event1.id);
        expect(result, isNotNull);
        expect(result!.sig, equals('updated_sig'));
      });

      test(
        'also upserts video metrics for video events (kind 34236)',
        () async {
          final event = createVideoEvent(loops: 100, likes: 50, comments: 10);

          await dao.upsertEvent(event);

          final metrics = await appDbClient.getVideoMetrics(event.id);
          expect(metrics, isNotNull);
          expect(metrics!.loopCount, equals(100));
          expect(metrics.likes, equals(50));
          expect(metrics.comments, equals(10));
        },
      );

      test(
        'throws for repost events (kind 16) due to VideoEvent parsing',
        () async {
          final event = createEvent(kind: 16);

          // upsertEvent stores the event first, then tries to parse metrics
          // VideoEvent.fromNostrEvent() throws for non-34236 kinds
          // The event is inserted but the method throws on metrics parsing
          expect(
            () => dao.upsertEvent(event),
            throwsA(isA<ArgumentError>()),
          );
        },
      );

      test('does not upsert video metrics for non-video kinds', () async {
        final event = createEvent(); // text note

        await dao.upsertEvent(event);

        final metrics = await appDbClient.getVideoMetrics(event.id);
        expect(metrics, isNull);
      });
    });

    group('upsertEventsBatch', () {
      test('inserts multiple events in a transaction', () async {
        final events = [
          createEvent(content: 'event 1', createdAt: 1000),
          createEvent(content: 'event 2', createdAt: 2000),
          createEvent(content: 'event 3', createdAt: 3000),
        ];

        await dao.upsertEventsBatch(events);

        for (final event in events) {
          final result = await appDbClient.getEvent(event.id);
          expect(result, isNotNull);
        }
      });

      test('handles empty list gracefully', () async {
        await dao.upsertEventsBatch([]);

        // Should not throw, just return
        expect(true, isTrue);
      });

      test('also upserts video metrics for video events in batch', () async {
        final events = [
          createVideoEvent(loops: 100, createdAt: 1000),
          createVideoEvent(loops: 200, createdAt: 2000),
          createEvent(createdAt: 3000), // non-video event
        ];

        await dao.upsertEventsBatch(events);

        // Video events should have metrics
        final metrics1 = await appDbClient.getVideoMetrics(
          events[0].id,
        );
        expect(metrics1, isNotNull);
        expect(metrics1!.loopCount, equals(100));

        final metrics2 = await appDbClient.getVideoMetrics(
          events[1].id,
        );
        expect(metrics2, isNotNull);
        expect(metrics2!.loopCount, equals(200));

        // Non-video event should not have metrics
        final metrics3 = await appDbClient.getVideoMetrics(
          events[2].id,
        );
        expect(metrics3, isNull);
      });
    });

    group('getVideoEventsByFilter', () {
      test('returns events matching default video kinds', () async {
        final videoEvent = createVideoEvent(createdAt: 1000);
        final textEvent = createEvent(createdAt: 2000);

        await dao.upsertEventsBatch([videoEvent, textEvent]);

        final results = await dao.getVideoEventsByFilter();

        expect(results.length, equals(1));
        expect(results.first.id, equals(videoEvent.id));
      });

      test('filters by specific kinds', () async {
        final events = [
          createEvent(createdAt: 1000),
          createEvent(kind: 7, createdAt: 2000),
          createEvent(kind: 3, createdAt: 3000),
        ];

        await dao.upsertEventsBatch(events);

        final results = await dao.getVideoEventsByFilter(kinds: [1, 7]);

        expect(results.length, equals(2));
        expect(results.map((e) => e.kind).toSet(), equals({1, 7}));
      });

      test('filters by authors', () async {
        final event1 = createVideoEvent(createdAt: 1000);
        final event2 = createVideoEvent(pubkey: testPubkey2, createdAt: 2000);

        await dao.upsertEventsBatch([event1, event2]);

        final results = await dao.getVideoEventsByFilter(authors: [testPubkey]);

        expect(results.length, equals(1));
        expect(results.first.pubkey, equals(testPubkey));
      });

      test('filters by hashtags', () async {
        final event1 = createVideoEvent(
          hashtags: ['flutter', 'dart'],
          createdAt: 1000,
        );
        final event2 = createVideoEvent(
          hashtags: ['nostr', 'web'],
          createdAt: 2000,
        );

        await dao.upsertEventsBatch([event1, event2]);

        final results = await dao.getVideoEventsByFilter(hashtags: ['flutter']);

        expect(results.length, equals(1));
        expect(results.first.id, equals(event1.id));
      });

      test('filters by since timestamp', () async {
        final oldEvent = createVideoEvent(createdAt: 1000);
        final newEvent = createVideoEvent(createdAt: 3000);

        await dao.upsertEventsBatch([oldEvent, newEvent]);

        final results = await dao.getVideoEventsByFilter(since: 2000);

        expect(results.length, equals(1));
        expect(results.first.id, equals(newEvent.id));
      });

      test('filters by until timestamp', () async {
        final oldEvent = createVideoEvent(createdAt: 1000);
        final newEvent = createVideoEvent(createdAt: 3000);

        await dao.upsertEventsBatch([oldEvent, newEvent]);

        final results = await dao.getVideoEventsByFilter(until: 2000);

        expect(results.length, equals(1));
        expect(results.first.id, equals(oldEvent.id));
      });

      test('limits number of returned events', () async {
        final events = List.generate(
          10,
          (i) => createVideoEvent(createdAt: 1000 + i),
        );

        await dao.upsertEventsBatch(events);

        final results = await dao.getVideoEventsByFilter(limit: 5);

        expect(results.length, equals(5));
      });

      test('sorts by created_at descending by default', () async {
        final events = [
          createVideoEvent(createdAt: 1000),
          createVideoEvent(createdAt: 3000),
          createVideoEvent(createdAt: 2000),
        ];

        await dao.upsertEventsBatch(events);

        final results = await dao.getVideoEventsByFilter();

        expect(results[0].createdAt, equals(3000));
        expect(results[1].createdAt, equals(2000));
        expect(results[2].createdAt, equals(1000));
      });

      test('sorts by loop_count when specified', () async {
        final events = [
          createVideoEvent(loops: 10, createdAt: 3000),
          createVideoEvent(loops: 100, createdAt: 1000),
          createVideoEvent(loops: 50, createdAt: 2000),
        ];

        await dao.upsertEventsBatch(events);

        final results = await dao.getVideoEventsByFilter(sortBy: 'loop_count');

        expect(results[0].id, equals(events[1].id)); // 100 loops
        expect(results[1].id, equals(events[2].id)); // 50 loops
        expect(results[2].id, equals(events[0].id)); // 10 loops
      });

      test('sorts by likes when specified', () async {
        final events = [
          createVideoEvent(likes: 5, createdAt: 3000),
          createVideoEvent(likes: 50, createdAt: 1000),
          createVideoEvent(likes: 25, createdAt: 2000),
        ];

        await dao.upsertEventsBatch(events);

        final results = await dao.getVideoEventsByFilter(sortBy: 'likes');

        expect(results[0].id, equals(events[1].id)); // 50 likes
        expect(results[1].id, equals(events[2].id)); // 25 likes
        expect(results[2].id, equals(events[0].id)); // 5 likes
      });

      test('combines multiple filters', () async {
        final matchingEvent = createVideoEvent(
          hashtags: ['flutter'],
          createdAt: 2500,
        );
        final wrongAuthor = createVideoEvent(
          pubkey: testPubkey2,
          hashtags: ['flutter'],
          createdAt: 2500,
        );
        final wrongHashtag = createVideoEvent(
          hashtags: ['nostr'],
          createdAt: 2500,
        );
        final wrongTime = createVideoEvent(
          hashtags: ['flutter'],
          createdAt: 500,
        );

        await dao.upsertEventsBatch([
          matchingEvent,
          wrongAuthor,
          wrongHashtag,
          wrongTime,
        ]);

        final results = await dao.getVideoEventsByFilter(
          authors: [testPubkey],
          hashtags: ['flutter'],
          since: 2000,
          until: 3000,
        );

        expect(results.length, equals(1));
        expect(results.first.id, equals(matchingEvent.id));
      });
    });

    group('replaceable events', () {
      test(
        'kind 0 (profile): newer event replaces older for same pubkey',
        () async {
          final oldProfile = createEvent(
            kind: 0,
            content: '{"name":"old"}',
            createdAt: 1000,
          );
          final newProfile = createEvent(
            kind: 0,
            content: '{"name":"new"}',
            createdAt: 2000,
          );

          await dao.upsertEvent(oldProfile);
          await dao.upsertEvent(newProfile);

          // Should only have one event for this pubkey+kind
          final results = await dao.getVideoEventsByFilter(kinds: [0]);
          expect(results.length, equals(1));
          expect(results.first.content, equals('{"name":"new"}'));
          expect(results.first.createdAt, equals(2000));
        },
      );

      test('kind 0 (profile): older event does not replace newer', () async {
        final newProfile = createEvent(
          kind: 0,
          content: '{"name":"new"}',
          createdAt: 2000,
        );
        final oldProfile = createEvent(
          kind: 0,
          content: '{"name":"old"}',
          createdAt: 1000,
        );

        await dao.upsertEvent(newProfile);
        await dao.upsertEvent(oldProfile); // Should be ignored

        final results = await dao.getVideoEventsByFilter(kinds: [0]);
        expect(results.length, equals(1));
        expect(results.first.content, equals('{"name":"new"}'));
        expect(results.first.createdAt, equals(2000));
      });

      test(
        'kind 3 (contacts): newer event replaces older for same pubkey',
        () async {
          final oldContacts = createEvent(
            kind: 3,
            tags: [
              ['p', 'pubkey1'],
            ],
            createdAt: 1000,
          );
          final newContacts = createEvent(
            kind: 3,
            tags: [
              ['p', 'pubkey1'],
              ['p', 'pubkey2'],
            ],
            createdAt: 2000,
          );

          await dao.upsertEvent(oldContacts);
          await dao.upsertEvent(newContacts);

          final results = await dao.getVideoEventsByFilter(kinds: [3]);
          expect(results.length, equals(1));
          expect(results.first.tags.length, equals(2));
        },
      );

      test(
        'kind 10002 (relay list): newer replaces older for same pubkey',
        () async {
          final oldRelays = createEvent(
            kind: 10002,
            tags: [
              ['r', 'wss://relay1.com'],
            ],
            createdAt: 1000,
          );
          final newRelays = createEvent(
            kind: 10002,
            tags: [
              ['r', 'wss://relay1.com'],
              ['r', 'wss://relay2.com'],
            ],
            createdAt: 2000,
          );

          await dao.upsertEvent(oldRelays);
          await dao.upsertEvent(newRelays);

          final results = await dao.getVideoEventsByFilter(kinds: [10002]);
          expect(results.length, equals(1));
          expect(results.first.tags.length, equals(2));
        },
      );

      test(
        'replaceable events: different pubkeys are stored separately',
        () async {
          final profile1 = createEvent(
            kind: 0,
            content: '{"name":"user1"}',
            createdAt: 1000,
          );
          final profile2 = createEvent(
            pubkey: testPubkey2,
            kind: 0,
            content: '{"name":"user2"}',
            createdAt: 2000,
          );

          await dao.upsertEvent(profile1);
          await dao.upsertEvent(profile2);

          final results = await dao.getVideoEventsByFilter(kinds: [0]);
          expect(results.length, equals(2));
        },
      );

      test(
        'kind 30023 (long-form): newer replaces older for same pubkey+d-tag',
        () async {
          final oldArticle = createEvent(
            kind: 30023,
            tags: [
              ['d', 'my-article'],
            ],
            content: 'old content',
            createdAt: 1000,
          );
          final newArticle = createEvent(
            kind: 30023,
            tags: [
              ['d', 'my-article'],
            ],
            content: 'new content',
            createdAt: 2000,
          );

          await dao.upsertEvent(oldArticle);
          await dao.upsertEvent(newArticle);

          final results = await dao.getVideoEventsByFilter(kinds: [30023]);
          expect(results.length, equals(1));
          expect(results.first.content, equals('new content'));
        },
      );

      test(
        'kind 30023 (long-form): different d-tags are stored separately',
        () async {
          final article1 = createEvent(
            kind: 30023,
            tags: [
              ['d', 'article-1'],
            ],
            content: 'article 1',
            createdAt: 1000,
          );
          final article2 = createEvent(
            kind: 30023,
            tags: [
              ['d', 'article-2'],
            ],
            content: 'article 2',
            createdAt: 2000,
          );

          await dao.upsertEvent(article1);
          await dao.upsertEvent(article2);

          final results = await dao.getVideoEventsByFilter(kinds: [30023]);
          expect(results.length, equals(2));
        },
      );

      test(
        'kind 30023 (long-form): older event does not replace newer',
        () async {
          final newArticle = createEvent(
            kind: 30023,
            tags: [
              ['d', 'my-article'],
            ],
            content: 'new content',
            createdAt: 2000,
          );
          final oldArticle = createEvent(
            kind: 30023,
            tags: [
              ['d', 'my-article'],
            ],
            content: 'old content',
            createdAt: 1000,
          );

          await dao.upsertEvent(newArticle);
          await dao.upsertEvent(oldArticle); // Should be ignored

          final results = await dao.getVideoEventsByFilter(kinds: [30023]);
          expect(results.length, equals(1));
          expect(results.first.content, equals('new content'));
        },
      );

      test(
        'regular events (kind 1): multiple events with same pubkey allowed',
        () async {
          final note1 = createEvent(
            content: 'note 1',
            createdAt: 1000,
          );
          final note2 = createEvent(
            content: 'note 2',
            createdAt: 2000,
          );

          await dao.upsertEvent(note1);
          await dao.upsertEvent(note2);

          final results = await dao.getVideoEventsByFilter(kinds: [1]);
          expect(results.length, equals(2));
        },
      );

      test('upsertEventsBatch handles replaceable events correctly', () async {
        final oldProfile = createEvent(
          kind: 0,
          content: '{"name":"old"}',
          createdAt: 1000,
        );
        final newProfile = createEvent(
          kind: 0,
          content: '{"name":"new"}',
          createdAt: 2000,
        );
        final regularNote = createEvent(
          content: 'note',
          createdAt: 1500,
        );

        await dao.upsertEventsBatch([oldProfile, newProfile, regularNote]);

        final profiles = await dao.getVideoEventsByFilter(kinds: [0]);
        expect(profiles.length, equals(1));
        expect(profiles.first.content, equals('{"name":"new"}'));

        final notes = await dao.getVideoEventsByFilter(kinds: [1]);
        expect(notes.length, equals(1));
      });
    });
  });
}
