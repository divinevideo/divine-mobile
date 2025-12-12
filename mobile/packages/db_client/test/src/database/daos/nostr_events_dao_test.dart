// ABOUTME: Unit tests for NostrEventsDao with Event model operations.
// ABOUTME: Tests all DAO methods including cache expiry and replaceable events.

import 'dart:io';

import 'package:db_client/db_client.dart' hide Filter;
import 'package:drift/native.dart';
import 'package:nostr_sdk/nostr_sdk.dart';
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

    group('getEventsByFilter', () {
      test('returns all events when empty filter', () async {
        final events = [
          createEvent(createdAt: 1000),
          createVideoEvent(createdAt: 2000),
          createEvent(kind: 7, createdAt: 3000),
        ];

        await dao.upsertEventsBatch(events);

        final results = await dao.getEventsByFilter(Filter());

        expect(results.length, equals(3));
      });

      test('filters by ids', () async {
        final event1 = createEvent(content: 'event 1', createdAt: 1000);
        final event2 = createEvent(content: 'event 2', createdAt: 2000);
        final event3 = createEvent(content: 'event 3', createdAt: 3000);

        await dao.upsertEventsBatch([event1, event2, event3]);

        final results = await dao.getEventsByFilter(
          Filter(ids: [event1.id, event3.id]),
        );

        expect(results.length, equals(2));
        expect(
          results.map((e) => e.id).toSet(),
          equals({event1.id, event3.id}),
        );
      });

      test('filters by specific kinds', () async {
        final events = [
          createEvent(createdAt: 1000),
          createEvent(kind: 7, createdAt: 2000),
          createEvent(kind: 3, createdAt: 3000),
        ];

        await dao.upsertEventsBatch(events);

        final results = await dao.getEventsByFilter(Filter(kinds: [1, 7]));

        expect(results.length, equals(2));
        expect(results.map((e) => e.kind).toSet(), equals({1, 7}));
      });

      test('filters by authors', () async {
        final event1 = createEvent(createdAt: 1000);
        final event2 = createEvent(pubkey: testPubkey2, createdAt: 2000);

        await dao.upsertEventsBatch([event1, event2]);

        final results = await dao.getEventsByFilter(
          Filter(authors: [testPubkey]),
        );

        expect(results.length, equals(1));
        expect(results.first.pubkey, equals(testPubkey));
      });

      test('filters by hashtags (t tags)', () async {
        final event1 = createVideoEvent(
          hashtags: ['flutter', 'dart'],
          createdAt: 1000,
        );
        final event2 = createVideoEvent(
          hashtags: ['nostr', 'web'],
          createdAt: 2000,
        );

        await dao.upsertEventsBatch([event1, event2]);

        final results = await dao.getEventsByFilter(Filter(t: ['flutter']));

        expect(results.length, equals(1));
        expect(results.first.id, equals(event1.id));
      });

      test('filters by e tags (referenced events)', () async {
        const referencedEventId = 'abc123def456';
        final event1 = createEvent(
          tags: [
            ['e', referencedEventId],
          ],
          createdAt: 1000,
        );
        final event2 = createEvent(
          tags: [
            ['e', 'other_event_id'],
          ],
          createdAt: 2000,
        );

        await dao.upsertEventsBatch([event1, event2]);

        final results = await dao.getEventsByFilter(
          Filter(e: [referencedEventId]),
        );

        expect(results.length, equals(1));
        expect(results.first.id, equals(event1.id));
      });

      test('filters by p tags (mentioned pubkeys)', () async {
        const mentionedPubkey = 'mentioned_pubkey_123';
        final event1 = createEvent(
          tags: [
            ['p', mentionedPubkey],
          ],
          createdAt: 1000,
        );
        final event2 = createEvent(
          tags: [
            ['p', 'other_pubkey'],
          ],
          createdAt: 2000,
        );

        await dao.upsertEventsBatch([event1, event2]);

        final results = await dao.getEventsByFilter(
          Filter(p: [mentionedPubkey]),
        );

        expect(results.length, equals(1));
        expect(results.first.id, equals(event1.id));
      });

      test('filters by d tags (addressable event identifiers)', () async {
        const dTagValue = 'my-unique-identifier';
        final event1 = createEvent(
          kind: 30023,
          tags: [
            ['d', dTagValue],
          ],
          createdAt: 1000,
        );
        final event2 = createEvent(
          kind: 30023,
          tags: [
            ['d', 'other-identifier'],
          ],
          createdAt: 2000,
        );

        await dao.upsertEventsBatch([event1, event2]);

        final results = await dao.getEventsByFilter(Filter(d: [dTagValue]));

        expect(results.length, equals(1));
        expect(results.first.id, equals(event1.id));
      });

      test('filters by search (content text)', () async {
        final event1 = createEvent(
          content: 'Hello world, this is a test',
          createdAt: 1000,
        );
        final event2 = createEvent(
          content: 'Goodbye universe',
          createdAt: 2000,
        );

        await dao.upsertEventsBatch([event1, event2]);

        final results = await dao.getEventsByFilter(Filter(search: 'world'));

        expect(results.length, equals(1));
        expect(results.first.id, equals(event1.id));
      });

      test('search is case insensitive', () async {
        final event1 = createEvent(
          content: 'Hello WORLD',
          createdAt: 1000,
        );

        await dao.upsertEvent(event1);

        final results = await dao.getEventsByFilter(Filter(search: 'world'));

        expect(results.length, equals(1));
        expect(results.first.id, equals(event1.id));
      });

      test('filters by since timestamp', () async {
        final oldEvent = createEvent(createdAt: 1000);
        final newEvent = createEvent(createdAt: 3000);

        await dao.upsertEventsBatch([oldEvent, newEvent]);

        final results = await dao.getEventsByFilter(Filter(since: 2000));

        expect(results.length, equals(1));
        expect(results.first.id, equals(newEvent.id));
      });

      test('filters by until timestamp', () async {
        final oldEvent = createEvent(createdAt: 1000);
        final newEvent = createEvent(createdAt: 3000);

        await dao.upsertEventsBatch([oldEvent, newEvent]);

        final results = await dao.getEventsByFilter(Filter(until: 2000));

        expect(results.length, equals(1));
        expect(results.first.id, equals(oldEvent.id));
      });

      test('limits number of returned events', () async {
        final events = List.generate(
          10,
          (i) => createEvent(createdAt: 1000 + i),
        );

        await dao.upsertEventsBatch(events);

        final results = await dao.getEventsByFilter(Filter(limit: 5));

        expect(results.length, equals(5));
      });

      test('sorts by created_at descending by default', () async {
        final events = [
          createEvent(createdAt: 1000),
          createEvent(createdAt: 3000),
          createEvent(createdAt: 2000),
        ];

        await dao.upsertEventsBatch(events);

        final results = await dao.getEventsByFilter(Filter());

        expect(results[0].createdAt, equals(3000));
        expect(results[1].createdAt, equals(2000));
        expect(results[2].createdAt, equals(1000));
      });

      test('sorts by loop_count when specified (video events)', () async {
        final events = [
          createVideoEvent(loops: 10, createdAt: 3000),
          createVideoEvent(loops: 100, createdAt: 1000),
          createVideoEvent(loops: 50, createdAt: 2000),
        ];

        await dao.upsertEventsBatch(events);

        final results = await dao.getEventsByFilter(
          Filter(kinds: [34236]),
          sortBy: 'loop_count',
        );

        expect(results[0].id, equals(events[1].id)); // 100 loops
        expect(results[1].id, equals(events[2].id)); // 50 loops
        expect(results[2].id, equals(events[0].id)); // 10 loops
      });

      test('sorts by likes when specified (video events)', () async {
        final events = [
          createVideoEvent(likes: 5, createdAt: 3000),
          createVideoEvent(likes: 50, createdAt: 1000),
          createVideoEvent(likes: 25, createdAt: 2000),
        ];

        await dao.upsertEventsBatch(events);

        final results = await dao.getEventsByFilter(
          Filter(kinds: [34236]),
          sortBy: 'likes',
        );

        expect(results[0].id, equals(events[1].id)); // 50 likes
        expect(results[1].id, equals(events[2].id)); // 25 likes
        expect(results[2].id, equals(events[0].id)); // 5 likes
      });

      test('combines multiple filters', () async {
        final matchingEvent = createEvent(
          content: 'matching content here',
          createdAt: 2500,
        );
        final wrongAuthor = createEvent(
          pubkey: testPubkey2,
          content: 'matching content here',
          createdAt: 2500,
        );
        final wrongKind = createEvent(
          kind: 7,
          content: 'matching content here',
          createdAt: 2500,
        );
        final wrongTime = createEvent(
          content: 'matching content here',
          createdAt: 500,
        );
        final wrongContent = createEvent(
          content: 'different text',
          createdAt: 2500,
        );

        await dao.upsertEventsBatch([
          matchingEvent,
          wrongAuthor,
          wrongKind,
          wrongTime,
          wrongContent,
        ]);

        final results = await dao.getEventsByFilter(
          Filter(
            authors: [testPubkey],
            kinds: [1],
            since: 2000,
            until: 3000,
            search: 'matching',
          ),
        );

        expect(results.length, equals(1));
        expect(results.first.id, equals(matchingEvent.id));
      });

      test('returns empty list when no events match', () async {
        final event = createEvent(createdAt: 1000);
        await dao.upsertEvent(event);

        final results = await dao.getEventsByFilter(Filter(kinds: [999]));

        expect(results, isEmpty);
      });

      test('filters by multiple e tags with OR logic', () async {
        const eventId1 = 'referenced_event_1';
        const eventId2 = 'referenced_event_2';
        final event1 = createEvent(
          tags: [
            ['e', eventId1],
          ],
          createdAt: 1000,
        );
        final event2 = createEvent(
          tags: [
            ['e', eventId2],
          ],
          createdAt: 2000,
        );
        final event3 = createEvent(
          tags: [
            ['e', 'other_event'],
          ],
          createdAt: 3000,
        );

        await dao.upsertEventsBatch([event1, event2, event3]);

        final results = await dao.getEventsByFilter(
          Filter(e: [eventId1, eventId2]),
        );

        expect(results.length, equals(2));
        expect(
          results.map((e) => e.id).toSet(),
          equals({event1.id, event2.id}),
        );
      });
    });

    group('getEventById', () {
      test('returns event when found', () async {
        final event = createEvent(content: 'test event');
        await dao.upsertEvent(event);

        final result = await dao.getEventById(event.id);

        expect(result, isNotNull);
        expect(result!.id, equals(event.id));
        expect(result.content, equals('test event'));
      });

      test('returns null when event not found', () async {
        final result = await dao.getEventById('nonexistent_event_id');

        expect(result, isNull);
      });

      test('returns correct event when multiple events exist', () async {
        final event1 = createEvent(content: 'event 1', createdAt: 1000);
        final event2 = createEvent(content: 'event 2', createdAt: 2000);
        final event3 = createEvent(content: 'event 3', createdAt: 3000);

        await dao.upsertEventsBatch([event1, event2, event3]);

        final result = await dao.getEventById(event2.id);

        expect(result, isNotNull);
        expect(result!.id, equals(event2.id));
        expect(result.content, equals('event 2'));
      });
    });

    group('getProfileByPubkey', () {
      test('returns profile event when found', () async {
        final profile = createEvent(
          kind: 0,
          content: '{"name":"testuser","about":"Test bio"}',
        );
        await dao.upsertEvent(profile);

        final result = await dao.getProfileByPubkey(testPubkey);

        expect(result, isNotNull);
        expect(result!.kind, equals(0));
        expect(result.pubkey, equals(testPubkey));
        expect(result.content, contains('testuser'));
      });

      test('returns null when profile not found', () async {
        final result = await dao.getProfileByPubkey('nonexistent_pubkey');

        expect(result, isNull);
      });

      test('returns null when pubkey has events but no profile', () async {
        final textNote = createEvent(content: 'just a note');
        await dao.upsertEvent(textNote);

        final result = await dao.getProfileByPubkey(testPubkey);

        expect(result, isNull);
      });

      test('returns most recent profile when multiple exist', () async {
        // This shouldn't happen with replaceable event logic, but test anyway
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

        final result = await dao.getProfileByPubkey(testPubkey);

        expect(result, isNotNull);
        expect(result!.content, equals('{"name":"new"}'));
      });

      test('returns correct profile for specific pubkey', () async {
        final profile1 = createEvent(
          kind: 0,
          content: '{"name":"user1"}',
        );
        final profile2 = createEvent(
          pubkey: testPubkey2,
          kind: 0,
          content: '{"name":"user2"}',
        );

        await dao.upsertEventsBatch([profile1, profile2]);

        final result = await dao.getProfileByPubkey(testPubkey2);

        expect(result, isNotNull);
        expect(result!.pubkey, equals(testPubkey2));
        expect(result.content, equals('{"name":"user2"}'));
      });
    });

    group('deleteAllEvents', () {
      test('deletes all events and returns count', () async {
        final events = [
          createEvent(content: 'event 1', createdAt: 1000),
          createEvent(content: 'event 2', createdAt: 2000),
          createEvent(content: 'event 3', createdAt: 3000),
        ];
        await dao.upsertEventsBatch(events);

        final deletedCount = await dao.deleteAllEvents();

        expect(deletedCount, equals(3));

        final remaining = await dao.getEventsByFilter(Filter());
        expect(remaining, isEmpty);
      });

      test('returns 0 when no events exist', () async {
        final deletedCount = await dao.deleteAllEvents();

        expect(deletedCount, equals(0));
      });

      test('deletes events of all kinds', () async {
        final events = [
          createEvent(kind: 0, content: 'profile', createdAt: 1000),
          createEvent(content: 'note', createdAt: 2000),
          createVideoEvent(createdAt: 3000),
          createEvent(kind: 7, content: 'reaction', createdAt: 4000),
        ];
        await dao.upsertEventsBatch(events);

        final deletedCount = await dao.deleteAllEvents();

        expect(deletedCount, equals(4));
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
          final results = await dao.getEventsByFilter(Filter(kinds: [0]));
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

        final results = await dao.getEventsByFilter(Filter(kinds: [0]));
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

          final results = await dao.getEventsByFilter(Filter(kinds: [3]));
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

          final results = await dao.getEventsByFilter(Filter(kinds: [10002]));
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

          final results = await dao.getEventsByFilter(Filter(kinds: [0]));
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

          final results = await dao.getEventsByFilter(Filter(kinds: [30023]));
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

          final results = await dao.getEventsByFilter(Filter(kinds: [30023]));
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

          final results = await dao.getEventsByFilter(Filter(kinds: [30023]));
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

          final results = await dao.getEventsByFilter(Filter(kinds: [1]));
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

        final profiles = await dao.getEventsByFilter(Filter(kinds: [0]));
        expect(profiles.length, equals(1));
        expect(profiles.first.content, equals('{"name":"new"}'));

        final notes = await dao.getEventsByFilter(Filter(kinds: [1]));
        expect(notes.length, equals(1));
      });
    });

    group('watchEventsByFilter (reactive queries)', () {
      test('emits initial events matching filter', () async {
        final event1 = createEvent(content: 'event 1', createdAt: 1000);
        final event2 = createEvent(content: 'event 2', createdAt: 2000);
        await dao.upsertEventsBatch([event1, event2]);

        final stream = dao.watchEventsByFilter(Filter(kinds: [1]));

        final events = await stream.first;
        expect(events.length, equals(2));
        expect(events[0].createdAt, equals(2000)); // Most recent first
        expect(events[1].createdAt, equals(1000));
      });

      test('emits new events when inserted', () async {
        final stream = dao.watchEventsByFilter(Filter(kinds: [1]));

        // Collect two emissions
        final emissionsFuture = stream.take(2).toList();

        // Insert an event after a short delay to ensure stream is listening
        await Future<void>.delayed(const Duration(milliseconds: 10));
        final event = createEvent(content: 'new event');
        await dao.upsertEvent(event);

        final emissions = await emissionsFuture;
        expect(emissions.length, equals(2));
        expect(emissions[0], isEmpty); // Initial empty state
        expect(emissions[1].length, equals(1));
        expect(emissions[1][0].id, equals(event.id));
      });

      test('emits updates when events are deleted', () async {
        final event = createEvent(content: 'will be deleted');
        await dao.upsertEvent(event);

        final stream = dao.watchEventsByFilter(Filter(kinds: [1]));

        // Collect two emissions
        final emissionsFuture = stream.take(2).toList();

        // Delete the event after a short delay to ensure stream is listening
        await Future<void>.delayed(const Duration(milliseconds: 10));
        await dao.deleteAllEvents();

        final emissions = await emissionsFuture;
        expect(emissions.length, equals(2));
        expect(emissions[0].length, equals(1)); // Initial has the event
        expect(emissions[1], isEmpty); // After delete, empty
      });

      test('filters by kind in watch query', () async {
        final textNote = createEvent(createdAt: 1000);
        final reaction = createEvent(kind: 7, createdAt: 2000);
        await dao.upsertEventsBatch([textNote, reaction]);

        final stream = dao.watchEventsByFilter(Filter(kinds: [1]));

        final events = await stream.first;
        expect(events.length, equals(1));
        expect(events[0].kind, equals(1));
      });

      test('filters by author in watch query', () async {
        final event1 = createEvent(createdAt: 1000);
        final event2 = createEvent(pubkey: testPubkey2, createdAt: 2000);
        await dao.upsertEventsBatch([event1, event2]);

        final stream = dao.watchEventsByFilter(Filter(authors: [testPubkey]));

        final events = await stream.first;
        expect(events.length, equals(1));
        expect(events[0].pubkey, equals(testPubkey));
      });

      test('respects limit in watch query', () async {
        final events = List.generate(
          10,
          (i) => createEvent(createdAt: 1000 + i),
        );
        await dao.upsertEventsBatch(events);

        final stream = dao.watchEventsByFilter(Filter(limit: 5));

        final result = await stream.first;
        expect(result.length, equals(5));
      });

      test('supports sortBy parameter for video events', () async {
        final events = [
          createVideoEvent(loops: 10, createdAt: 3000),
          createVideoEvent(loops: 100, createdAt: 1000),
          createVideoEvent(loops: 50, createdAt: 2000),
        ];
        await dao.upsertEventsBatch(events);

        final stream = dao.watchEventsByFilter(
          Filter(kinds: [34236]),
          sortBy: 'loop_count',
        );

        final result = await stream.first;
        expect(result[0].id, equals(events[1].id)); // 100 loops
        expect(result[1].id, equals(events[2].id)); // 50 loops
        expect(result[2].id, equals(events[0].id)); // 10 loops
      });

      test('re-emits when video metrics change (sortBy join table)', () async {
        // Insert video events with initial metrics
        final events = [
          createVideoEvent(loops: 10, createdAt: 3000),
          createVideoEvent(loops: 100, createdAt: 1000),
        ];
        await dao.upsertEventsBatch(events);

        final stream = dao.watchEventsByFilter(
          Filter(kinds: [34236]),
          sortBy: 'loop_count',
        );

        // Collect two emissions
        final emissionsFuture = stream.take(2).toList();

        // Wait for stream to be listening
        await Future<void>.delayed(const Duration(milliseconds: 10));

        // Update metrics for first event (10 loops -> 200 loops)
        // This should re-order the results
        final updatedEvent = createVideoEvent(loops: 200, createdAt: 3000)
          ..id = events[0].id;
        await database.videoMetricsDao.upsertVideoMetrics(updatedEvent);

        final emissions = await emissionsFuture;
        expect(emissions.length, equals(2));

        // First emission: 100 loops first, then 10 loops
        expect(emissions[0][0].id, equals(events[1].id)); // 100 loops
        expect(emissions[0][1].id, equals(events[0].id)); // 10 loops

        // Second emission after metrics update: 200 loops first, then 100 loops
        expect(emissions[1][0].id, equals(events[0].id)); // Now 200 loops
        expect(emissions[1][1].id, equals(events[1].id)); // Still 100 loops
      });
    });

    group('cache expiry', () {
      /// Helper to get current Unix timestamp
      int nowUnix() => DateTime.now().millisecondsSinceEpoch ~/ 1000;

      group('upsertEventWithExpiry', () {
        test('inserts event with expiry timestamp', () async {
          final event = createEvent(content: 'expiring event');
          final expireAt = nowUnix() + 3600; // 1 hour from now

          await dao.upsertEventWithExpiry(event, expireAt: expireAt);

          final result = await dao.getEventById(event.id);
          expect(result, isNotNull);
          expect(result!.content, equals('expiring event'));
        });

        test('handles replaceable events with expiry', () async {
          final profile = createEvent(
            kind: 0,
            content: '{"name":"test"}',
            createdAt: 1000,
          );
          final expireAt = nowUnix() + 3600;

          await dao.upsertEventWithExpiry(profile, expireAt: expireAt);

          final result = await dao.getProfileByPubkey(testPubkey);
          expect(result, isNotNull);
          expect(result!.content, equals('{"name":"test"}'));
        });

        test('handles parameterized replaceable events with expiry', () async {
          final video = createVideoEvent(loops: 100);
          final expireAt = nowUnix() + 3600;

          await dao.upsertEventWithExpiry(video, expireAt: expireAt);

          final result = await dao.getEventById(video.id);
          expect(result, isNotNull);
        });
      });

      group('setEventExpiry', () {
        test('sets expiry on existing event', () async {
          final event = createEvent();
          await dao.upsertEvent(event);

          final expireAt = nowUnix() + 3600;
          final success = await dao.setEventExpiry(event.id, expireAt);

          expect(success, isTrue);
        });

        test('returns false for non-existent event', () async {
          final success = await dao.setEventExpiry(
            'nonexistent_id',
            nowUnix() + 3600,
          );

          expect(success, isFalse);
        });
      });

      group('clearEventExpiry', () {
        test('removes expiry from event', () async {
          final event = createEvent();
          final expireAt = nowUnix() + 3600;
          await dao.upsertEventWithExpiry(event, expireAt: expireAt);

          final success = await dao.clearEventExpiry(event.id);

          expect(success, isTrue);
        });

        test('returns false for non-existent event', () async {
          final success = await dao.clearEventExpiry('nonexistent_id');

          expect(success, isFalse);
        });
      });

      group('deleteExpiredEvents', () {
        test(
          'deletes events with expired timestamps using current time',
          () async {
            final pastExpiry = nowUnix() - 100; // Already expired
            final futureExpiry = nowUnix() + 3600; // Not yet expired

            final expiredEvent = createEvent(
              content: 'expired',
              createdAt: 1000,
            );
            final validEvent = createEvent(content: 'valid', createdAt: 2000);
            final noExpiryEvent = createEvent(
              content: 'no expiry',
              createdAt: 3000,
            );

            await dao.upsertEventWithExpiry(expiredEvent, expireAt: pastExpiry);
            await dao.upsertEventWithExpiry(validEvent, expireAt: futureExpiry);
            await dao.upsertEvent(noExpiryEvent);

            final deletedCount = await dao.deleteExpiredEvents(null);

            expect(deletedCount, equals(1));

            // Expired event should be gone
            final expiredResult = await dao.getEventById(expiredEvent.id);
            expect(expiredResult, isNull);

            // Valid and no-expiry events should remain
            final validResult = await dao.getEventById(validEvent.id);
            expect(validResult, isNotNull);

            final noExpiryResult = await dao.getEventById(noExpiryEvent.id);
            expect(noExpiryResult, isNotNull);
          },
        );

        test('deletes events expired before given timestamp', () async {
          final event1 = createEvent(content: 'event 1', createdAt: 1000);
          final event2 = createEvent(content: 'event 2', createdAt: 2000);
          final event3 = createEvent(content: 'event 3', createdAt: 3000);

          await dao.upsertEventWithExpiry(event1, expireAt: 100);
          await dao.upsertEventWithExpiry(event2, expireAt: 200);
          await dao.upsertEventWithExpiry(event3, expireAt: 300);

          // Delete events expiring before 250
          final deletedCount = await dao.deleteExpiredEvents(250);

          expect(deletedCount, equals(2));

          // event3 should remain
          final remaining = await dao.getEventsByFilter(Filter());
          expect(remaining.length, equals(1));
          expect(remaining.first.id, equals(event3.id));
        });

        test('returns 0 when no expired events', () async {
          final futureExpiry = nowUnix() + 3600;
          final event = createEvent();
          await dao.upsertEventWithExpiry(event, expireAt: futureExpiry);

          final deletedCount = await dao.deleteExpiredEvents(null);

          expect(deletedCount, equals(0));
        });

        test('returns 0 when no events exist', () async {
          final deletedCount = await dao.deleteExpiredEvents(null);

          expect(deletedCount, equals(0));
        });
      });

      group('countExpiredEvents', () {
        test('counts events that will expire before timestamp', () async {
          final event1 = createEvent(content: 'event 1', createdAt: 1000);
          final event2 = createEvent(content: 'event 2', createdAt: 2000);
          final event3 = createEvent(content: 'event 3', createdAt: 3000);
          final noExpiry = createEvent(content: 'no expiry', createdAt: 4000);

          await dao.upsertEventWithExpiry(event1, expireAt: 100);
          await dao.upsertEventWithExpiry(event2, expireAt: 200);
          await dao.upsertEventWithExpiry(event3, expireAt: 300);
          await dao.upsertEvent(noExpiry);

          final count = await dao.countExpiredEvents(250);

          expect(count, equals(2));
        });

        test('returns 0 when no events will expire', () async {
          final event = createEvent();
          await dao.upsertEventWithExpiry(event, expireAt: 1000);

          final count = await dao.countExpiredEvents(500);

          expect(count, equals(0));
        });

        test('returns 0 when no events exist', () async {
          final count = await dao.countExpiredEvents(nowUnix());

          expect(count, equals(0));
        });
      });
    });
  });
}
