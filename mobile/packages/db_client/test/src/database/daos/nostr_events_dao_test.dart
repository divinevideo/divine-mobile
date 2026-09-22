// ABOUTME: Unit tests for NostrEventsDao with Event model operations.
// ABOUTME: Tests all DAO methods including cache expiry and replaceable events.

import 'dart:io';

import 'package:db_client/db_client.dart' hide Filter;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nostr_sdk/nostr_sdk.dart';

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
        // Pin createdAt so both events always compute the same ID
        final fixedCreatedAt =
            DateTime.now().millisecondsSinceEpoch ~/ 1000 - 60;
        final event1 = createEvent(
          content: 'original content',
          createdAt: fixedCreatedAt,
        );
        await dao.upsertEvent(event1);

        // Create new event with same properties (same ID)
        final event2 = createEvent(
          content: 'original content',
          createdAt: fixedCreatedAt,
        )..sig = 'updated_sig';
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
        'does not upsert video metrics for repost events (kind 16)',
        () async {
          final event = createEvent(kind: 16);

          // Kind 16 reposts reference videos but don't contain video metadata
          // So they should be inserted without video metrics (no error thrown)
          await dao.upsertEvent(event);

          // Event should be inserted
          final retrieved = await dao.getEventById(event.id);
          expect(retrieved, isNotNull);
          expect(retrieved!.kind, equals(16));

          // But no video metrics should be created
          final metrics = await appDbClient.getVideoMetrics(event.id);
          expect(metrics, isNull);
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
      test(
        'persists a stable snapshot when the caller mutates its list',
        () async {
          final first = createEvent(content: 'first', createdAt: 1000);
          final second = createEvent(content: 'second', createdAt: 2000);
          final addedLater = createEvent(
            content: 'added later',
            createdAt: 3000,
          );
          final events = [first, second];

          final persistence = dao.upsertEventsBatch(events);
          events.add(addedLater);

          await expectLater(persistence, completes);
          expect(await appDbClient.getEvent(first.id), isNotNull);
          expect(await appDbClient.getEvent(second.id), isNotNull);
          expect(await appDbClient.getEvent(addedLater.id), isNull);
        },
      );

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

      test('serializes concurrent replaceable-event batches', () async {
        await dao.upsertEventsBatch([
          createEvent(kind: 0, content: 'v1', createdAt: 1000),
        ]);
        final newest = createEvent(kind: 0, content: 'v3', createdAt: 3000);
        final middle = createEvent(kind: 0, content: 'v2', createdAt: 2000);

        await Future.wait([
          dao.upsertEventsBatch([newest]),
          dao.upsertEventsBatch([middle]),
        ]);

        final results = await dao.getEventsByFilter(Filter(kinds: [0]));
        expect(results, hasLength(1));
        expect(results.single.id, newest.id);
      });

      test('handles an empty batch without error', () async {
        await expectLater(dao.upsertEventsBatch([]), completes);
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

      test('filters by multiple hashtags with OR logic', () async {
        final flutterEvent = createVideoEvent(
          hashtags: ['flutter'],
          createdAt: 1000,
        );
        final dartEvent = createVideoEvent(hashtags: ['dart'], createdAt: 2000);
        final rustEvent = createVideoEvent(hashtags: ['rust'], createdAt: 3000);

        await dao.upsertEventsBatch([flutterEvent, dartEvent, rustEvent]);

        final results = await dao.getEventsByFilter(
          Filter(t: ['flutter', 'dart']),
        );

        expect(results.length, equals(2));
        expect(
          results.map((event) => event.id).toSet(),
          equals({flutterEvent.id, dartEvent.id}),
        );
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

      test('filters by a tags (referenced addressable events)', () async {
        const referencedAddress = '34236:author_pubkey_hex:video_d_tag';
        final event1 = createEvent(
          kind: 6,
          tags: [
            ['a', referencedAddress],
          ],
          createdAt: 1000,
        );
        final event2 = createEvent(
          kind: 6,
          tags: [
            ['a', '34236:author_pubkey_hex:other_d_tag'],
          ],
          createdAt: 2000,
        );

        await dao.upsertEventsBatch([event1, event2]);

        final results = await dao.getEventsByFilter(
          Filter(kinds: [6], a: [referencedAddress]),
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

      test('filters by h tags (relay-specific values)', () async {
        const relayValue = 'vine.hol.is';
        final event1 = createEvent(
          tags: [
            ['h', relayValue],
          ],
          createdAt: 1000,
        );
        final event2 = createEvent(
          tags: [
            ['h', 'other-relay-value'],
          ],
          createdAt: 2000,
        );

        await dao.upsertEventsBatch([event1, event2]);

        final results = await dao.getEventsByFilter(Filter(h: [relayValue]));

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

      test('tag filters require exact case-sensitive tag names', () async {
        const eventId = 'root_video_event_id_123';
        final lowercaseE = createEvent(
          tags: [
            ['e', eventId],
          ],
          content: 'lowercase e',
          createdAt: 1000,
        );
        final uppercaseE = createEvent(
          tags: [
            ['E', eventId],
          ],
          content: 'uppercase E',
          createdAt: 2000,
        );

        await dao.upsertEventsBatch([lowercaseE, uppercaseE]);

        final lowercaseResults = await dao.getEventsByFilter(
          Filter(e: [eventId]),
        );
        final uppercaseResults = await dao.getEventsByFilter(
          Filter(uppercaseE: [eventId]),
        );

        expect(lowercaseResults.map((event) => event.id), [lowercaseE.id]);
        expect(uppercaseResults.map((event) => event.id), [uppercaseE.id]);
      });

      test('tag filters only match the second tag element', () async {
        const eventId = 'referenced_event_123';
        final matchingEvent = createEvent(
          tags: [
            ['e', eventId],
          ],
          content: 'matching second element',
          createdAt: 1000,
        );
        final wrongPosition = createEvent(
          tags: [
            ['e', 'different_event', eventId],
          ],
          content: 'matching value in third element',
          createdAt: 2000,
        );

        await dao.upsertEventsBatch([matchingEvent, wrongPosition]);

        final results = await dao.getEventsByFilter(Filter(e: [eventId]));

        expect(results.map((event) => event.id), [matchingEvent.id]);
      });

      test('tag filters do not match values across serialized JSON', () async {
        const eventId = 'referenced_event_456';
        final matchingEvent = createEvent(
          tags: [
            ['e', eventId],
          ],
          content: 'matching e tag',
          createdAt: 1000,
        );
        final splitAcrossTags = createEvent(
          tags: [
            ['e', 'different_event'],
            ['p', eventId],
          ],
          content: 'e tag name and value in separate tags',
          createdAt: 2000,
        );

        await dao.upsertEventsBatch([matchingEvent, splitAcrossTags]);

        final results = await dao.getEventsByFilter(Filter(e: [eventId]));

        expect(results.map((event) => event.id), [matchingEvent.id]);
      });

      test('tag values are matched case-sensitively', () async {
        final lowercaseTag = createEvent(
          tags: [
            ['t', 'flutter'],
          ],
          content: 'lowercase hashtag',
          createdAt: 1000,
        );
        final uppercaseTag = createEvent(
          tags: [
            ['t', 'Flutter'],
          ],
          content: 'uppercase hashtag',
          createdAt: 2000,
        );

        await dao.upsertEventsBatch([lowercaseTag, uppercaseTag]);

        final lowercaseResults = await dao.getEventsByFilter(
          Filter(t: ['flutter']),
        );
        final uppercaseResults = await dao.getEventsByFilter(
          Filter(t: ['Flutter']),
        );

        expect(lowercaseResults.map((event) => event.id), [lowercaseTag.id]);
        expect(uppercaseResults.map((event) => event.id), [uppercaseTag.id]);
      });

      test(
        'filters by uppercase E tags (NIP-22 root event reference)',
        () async {
          const rootEventId = 'root_video_event_id_123';
          // NIP-22 comment (kind 1111) referencing a video
          final comment1 = createEvent(
            kind: 1111,
            tags: [
              ['E', rootEventId, '', testPubkey], // Uppercase E = root scope
              ['K', '34236'],
            ],
            content: 'Great video!',
            createdAt: 1000,
          );
          // Comment referencing a different root event
          final comment2 = createEvent(
            kind: 1111,
            tags: [
              ['E', 'other_root_event', '', testPubkey],
              ['K', '34236'],
            ],
            content: 'Another comment',
            createdAt: 2000,
          );
          // Regular event with lowercase e tag (not an uppercase E)
          final regularEvent = createEvent(
            tags: [
              ['e', rootEventId],
            ],
            createdAt: 3000,
          );

          await dao.upsertEventsBatch([comment1, comment2, regularEvent]);

          final results = await dao.getEventsByFilter(
            Filter(uppercaseE: [rootEventId]),
          );

          expect(results.length, equals(1));
          expect(results.first.id, equals(comment1.id));
          expect(results.first.content, equals('Great video!'));
        },
      );

      test('filters by uppercase K tags (NIP-22 root event kind)', () async {
        // NIP-22 comment referencing a video (kind 34236)
        final commentOnVideo = createEvent(
          kind: 1111,
          tags: [
            ['E', 'video_event_id', '', testPubkey],
            ['K', '34236'], // Uppercase K = root event kind
          ],
          content: 'Comment on video',
          createdAt: 1000,
        );
        // NIP-22 comment referencing a different kind
        final commentOnArticle = createEvent(
          kind: 1111,
          tags: [
            ['E', 'article_event_id', '', testPubkey],
            ['K', '30023'], // Long-form content kind
          ],
          content: 'Comment on article',
          createdAt: 2000,
        );

        await dao.upsertEventsBatch([commentOnVideo, commentOnArticle]);

        final results = await dao.getEventsByFilter(
          Filter(uppercaseK: ['34236']),
        );

        expect(results.length, equals(1));
        expect(results.first.id, equals(commentOnVideo.id));
      });

      test('filters by m tags (NIP-94 file MIME type)', () async {
        final audioFile = createEvent(
          kind: 1063,
          tags: [
            ['url', 'https://example.com/sound.wav'],
            ['m', 'audio/wav'],
          ],
          content: '',
          createdAt: 1000,
        );
        final pdfFile = createEvent(
          kind: 1063,
          tags: [
            ['url', 'https://example.com/flyer.pdf'],
            ['m', 'application/pdf'],
          ],
          content: '',
          createdAt: 2000,
        );

        await dao.upsertEventsBatch([audioFile, pdfFile]);

        final results = await dao.getEventsByFilter(
          Filter(kinds: [1063], m: ['audio/wav', 'audio/mpeg']),
        );

        expect(results.length, equals(1));
        expect(results.first.id, equals(audioFile.id));
      });

      test(
        'filters by uppercase A tags (NIP-22 root addressable event reference)',
        () async {
          const addressableId = '34236:$testPubkey:unique_video_dtag_123';
          // NIP-22 comment referencing a video via A tag
          final commentWithA = createEvent(
            kind: 1111,
            tags: [
              ['A', addressableId, ''], // Uppercase A = root addressable scope
              ['K', '34236'],
            ],
            content: 'Comment via A tag',
            createdAt: 1000,
          );
          // Comment referencing a different addressable event
          final commentOtherA = createEvent(
            kind: 1111,
            tags: [
              ['A', '34236:$testPubkey2:other_dtag', ''],
              ['K', '34236'],
            ],
            content: 'Other addressable comment',
            createdAt: 2000,
          );
          // Event with lowercase a tag (not uppercase A)
          final lowercaseAEvent = createEvent(
            kind: 1111,
            tags: [
              ['a', addressableId, ''],
            ],
            content: 'Lowercase a tag event',
            createdAt: 3000,
          );

          await dao.upsertEventsBatch(
            [commentWithA, commentOtherA, lowercaseAEvent],
          );

          final results = await dao.getEventsByFilter(
            Filter(uppercaseA: [addressableId]),
          );

          expect(results.length, equals(1));
          expect(results.first.id, equals(commentWithA.id));
          expect(results.first.content, equals('Comment via A tag'));
        },
      );

      test(
        'combines uppercaseA and kinds filters for NIP-22 comments',
        () async {
          const addressableId = '34236:$testPubkey:video_dtag_456';
          // Kind 1111 comment with A tag
          final comment = createEvent(
            kind: 1111,
            tags: [
              ['A', addressableId, ''],
              ['K', '34236'],
            ],
            content: 'Comment on video',
            createdAt: 1000,
          );
          // Non-comment event with same A tag (different kind)
          final nonComment = createEvent(
            kind: 7,
            tags: [
              ['A', addressableId, ''],
            ],
            content: '+',
            createdAt: 2000,
          );

          await dao.upsertEventsBatch([comment, nonComment]);

          final results = await dao.getEventsByFilter(
            Filter(kinds: [1111], uppercaseA: [addressableId]),
          );

          expect(results.length, equals(1));
          expect(results.first.id, equals(comment.id));
        },
      );

      test(
        'combines uppercaseE and uppercaseK filters for NIP-22 comments',
        () async {
          const rootEventId = 'specific_video_id';
          // Comment on the specific video
          final targetComment = createEvent(
            kind: 1111,
            tags: [
              ['E', rootEventId, '', testPubkey],
              ['K', '34236'],
            ],
            content: 'Target comment',
            createdAt: 1000,
          );
          // Comment on different video
          final otherVideoComment = createEvent(
            kind: 1111,
            tags: [
              ['E', 'other_video_id', '', testPubkey],
              ['K', '34236'],
            ],
            content: 'Other video comment',
            createdAt: 2000,
          );
          // Comment with right E but wrong K
          final wrongKindComment = createEvent(
            kind: 1111,
            tags: [
              ['E', rootEventId, '', testPubkey],
              ['K', '30023'],
            ],
            content: 'Wrong kind comment',
            createdAt: 3000,
          );

          await dao.upsertEventsBatch([
            targetComment,
            otherVideoComment,
            wrongKindComment,
          ]);

          final results = await dao.getEventsByFilter(
            Filter(
              kinds: [1111],
              uppercaseE: [rootEventId],
              uppercaseK: ['34236'],
            ),
          );

          expect(results.length, equals(1));
          expect(results.first.id, equals(targetComment.id));
        },
      );
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

      test('cacheEventsBatch preserves raw replaceable events by id', () async {
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

        await dao.cacheEventsBatch([oldProfile, newProfile]);

        expect(await dao.getEventById(oldProfile.id), isNotNull);
        expect(await dao.getEventById(newProfile.id), isNotNull);
      });

      test(
        'upsert collapses duplicate standard-replaceable versions left by '
        'cacheEventsBatch when a newer version arrives',
        () async {
          // event_router routes every non-parameterized kind to
          // cacheEventsBatch, so several rows per (pubkey, kind) is the normal
          // case for kind 0 and kind 3 — the same precondition the kind 30023
          // tests below rely on.
          final v1 = createEvent(kind: 0, content: 'v1', createdAt: 1000);
          final v2 = createEvent(kind: 0, content: 'v2', createdAt: 2000);
          await dao.cacheEventsBatch([v1, v2]);

          final v3 = createEvent(kind: 0, content: 'v3', createdAt: 3000);
          await dao.upsertEvent(v3);

          final results = await dao.getEventsByFilter(Filter(kinds: [0]));
          expect(results, hasLength(1));
          expect(results.first.content, equals('v3'));
        },
      );

      test(
        'upsert collapses duplicate contact lists left by cacheEventsBatch',
        () async {
          final v1 = createEvent(kind: 3, content: 'v1', createdAt: 1000);
          final v2 = createEvent(kind: 3, content: 'v2', createdAt: 2000);
          final v3 = createEvent(kind: 3, content: 'v3', createdAt: 3000);
          await dao.cacheEventsBatch([v1, v2, v3]);

          final v4 = createEvent(kind: 3, content: 'v4', createdAt: 4000);
          await dao.upsertEvent(v4);

          final results = await dao.getEventsByFilter(Filter(kinds: [3]));
          expect(results, hasLength(1));
          expect(results.first.content, equals('v4'));
        },
      );

      test(
        'upsert of a standard-replaceable compares against the newest cached '
        'duplicate, not an arbitrary one',
        () async {
          final v1 = createEvent(kind: 0, content: 'v1', createdAt: 1000);
          final v3 = createEvent(kind: 0, content: 'v3', createdAt: 3000);
          await dao.cacheEventsBatch([v1, v3]);

          // Older than v3 — must be rejected even though v1 is older still.
          final v2 = createEvent(kind: 0, content: 'v2', createdAt: 2000);
          await dao.upsertEvent(v2);

          expect(await dao.getEventById(v2.id), isNull);
          expect(await dao.getEventById(v3.id), isNotNull);
        },
      );

      test(
        'concurrent standard-replaceable upserts keep only the newest event',
        () async {
          final v1 = createEvent(kind: 0, content: 'v1', createdAt: 1000);
          await dao.upsertEvent(v1);

          final v3 = createEvent(kind: 0, content: 'v3', createdAt: 3000);
          final v2 = createEvent(kind: 0, content: 'v2', createdAt: 2000);
          await Future.wait([dao.upsertEvent(v3), dao.upsertEvent(v2)]);

          final results = await dao.getEventsByFilter(Filter(kinds: [0]));
          expect(results, hasLength(1));
          expect(results.single.id, v3.id);
        },
      );

      test(
        'kind 30023 without d-tag: newer replaces older via empty-string '
        'identifier (NIP-01 default)',
        () async {
          final oldArticle = createEvent(
            kind: 30023,
            content: 'old content',
            createdAt: 1000,
          );
          final newArticle = createEvent(
            kind: 30023,
            content: 'new content',
            createdAt: 2000,
          );

          await dao.upsertEvent(oldArticle);
          await dao.upsertEvent(newArticle);

          final results = await dao.getEventsByFilter(Filter(kinds: [30023]));
          expect(results, hasLength(1));
          expect(results.first.content, equals('new content'));
        },
      );

      test(
        'upsert collapses duplicate versions left by cacheEventsBatch when '
        'a newer version arrives',
        () async {
          final v1 = createEvent(
            kind: 30023,
            tags: [
              ['d', 'my-article'],
            ],
            content: 'v1',
            createdAt: 1000,
          );
          final v2 = createEvent(
            kind: 30023,
            tags: [
              ['d', 'my-article'],
            ],
            content: 'v2',
            createdAt: 2000,
          );
          // Raw ingestion keeps both versions side by side.
          await dao.cacheEventsBatch([v1, v2]);

          final v3 = createEvent(
            kind: 30023,
            tags: [
              ['d', 'my-article'],
            ],
            content: 'v3',
            createdAt: 3000,
          );
          await dao.upsertEvent(v3);

          final results = await dao.getEventsByFilter(Filter(kinds: [30023]));
          expect(results, hasLength(1));
          expect(results.first.content, equals('v3'));
        },
      );

      test(
        'upsert compares against the newest cached duplicate, not an '
        'arbitrary one',
        () async {
          final v1 = createEvent(
            kind: 30023,
            tags: [
              ['d', 'my-article'],
            ],
            content: 'v1',
            createdAt: 1000,
          );
          final v3 = createEvent(
            kind: 30023,
            tags: [
              ['d', 'my-article'],
            ],
            content: 'v3',
            createdAt: 3000,
          );
          await dao.cacheEventsBatch([v1, v3]);

          // Older than v3 — must be rejected even though v1 is older.
          final v2 = createEvent(
            kind: 30023,
            tags: [
              ['d', 'my-article'],
            ],
            content: 'v2',
            createdAt: 2000,
          );
          await dao.upsertEvent(v2);

          expect(await dao.getEventById(v2.id), isNull);
          expect(await dao.getEventById(v3.id), isNotNull);
        },
      );

      test(
        'concurrent parameterized-replaceable upserts keep only the newest '
        'event',
        () async {
          final tags = [
            ['d', 'my-article'],
          ];
          final v1 = createEvent(
            kind: 30023,
            tags: tags,
            content: 'v1',
            createdAt: 1000,
          );
          await dao.upsertEvent(v1);

          final v3 = createEvent(
            kind: 30023,
            tags: tags,
            content: 'v3',
            createdAt: 3000,
          );
          final v2 = createEvent(
            kind: 30023,
            tags: tags,
            content: 'v2',
            createdAt: 2000,
          );
          await Future.wait([dao.upsertEvent(v3), dao.upsertEvent(v2)]);

          final results = await dao.getEventsByFilter(Filter(kinds: [30023]));
          expect(results, hasLength(1));
          expect(results.single.id, v3.id);
        },
      );

      test(
        'upsert stores the denormalized d_tag column used for the indexed '
        'lookup',
        () async {
          final article = createEvent(
            kind: 30023,
            tags: [
              ['d', 'my-article'],
            ],
            content: 'content',
            createdAt: 1000,
          );
          final note = createEvent(createdAt: 1000);

          await dao.upsertEvent(article);
          await dao.upsertEvent(note);

          final rows = await database
              .customSelect('SELECT id, d_tag FROM event')
              .get();
          final dTagsById = {
            for (final row in rows)
              row.read<String>('id'): row.readNullable<String>('d_tag'),
          };
          expect(dTagsById[article.id], equals('my-article'));
          expect(dTagsById[note.id], isNull);
        },
      );

      test(
        'upsert MAX(created_at) lookup uses the covering d_tag index',
        () async {
          // Pins the query plan: without the trailing created_at column
          // SQLite's min/max optimization picks idx_event_kind_created_at
          // (kind-only equality) and reverse-scans the whole kind
          // partition instead of seeking — the regression this index
          // shape exists to prevent (PR #5957 review).
          final plan = await database
              .customSelect(
                'EXPLAIN QUERY PLAN '
                'SELECT MAX(created_at) FROM event '
                "WHERE pubkey = 'p' AND kind = 30023 AND d_tag = 'd'",
              )
              .get();
          final detail = plan
              .map((row) => row.read<String>('detail'))
              .join('; ');
          expect(
            detail,
            contains('COVERING INDEX idx_event_pubkey_kind_d_tag_created_at'),
          );
        },
      );
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

      group('upsertEvent with expiry', () {
        test('inserts event with expiry timestamp', () async {
          final event = createEvent(content: 'expiring event');
          final expireAt = nowUnix() + 3600; // 1 hour from now

          await dao.upsertEvent(event, expireAt: expireAt);

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

          await dao.upsertEvent(profile, expireAt: expireAt);

          final result = await dao.getProfileByPubkey(testPubkey);
          expect(result, isNotNull);
          expect(result!.content, equals('{"name":"test"}'));
        });

        test('handles parameterized replaceable events with expiry', () async {
          final video = createVideoEvent(loops: 100);
          final expireAt = nowUnix() + 3600;

          await dao.upsertEvent(video, expireAt: expireAt);

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

      group('deleteExpiredEvents', () {
        test('deletes legacy events with a null expiry', () async {
          await database.customStatement('''
            INSERT INTO event
              (id, pubkey, created_at, kind, tags, content, sig, expire_at)
            VALUES
              ('legacy-null-expiry', '$testPubkey', 1000, 1, '[]',
               'legacy', 'sig', NULL)
          ''');

          final deletedCount = await dao.deleteExpiredEvents(null);

          expect(deletedCount, 1);
          expect(await dao.getEventById('legacy-null-expiry'), isNull);
        });

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

            await dao.upsertEvent(expiredEvent, expireAt: pastExpiry);
            await dao.upsertEvent(validEvent, expireAt: futureExpiry);
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

          await dao.upsertEvent(event1, expireAt: 100);
          await dao.upsertEvent(event2, expireAt: 200);
          await dao.upsertEvent(event3, expireAt: 300);

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
          await dao.upsertEvent(event, expireAt: futureExpiry);

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

          await dao.upsertEvent(event1, expireAt: 100);
          await dao.upsertEvent(event2, expireAt: 200);
          await dao.upsertEvent(event3, expireAt: 300);
          await dao.upsertEvent(noExpiry);

          final count = await dao.countExpiredEvents(250);

          expect(count, equals(2));
        });

        test('returns 0 when no events will expire', () async {
          final event = createEvent();
          await dao.upsertEvent(event, expireAt: 1000);

          final count = await dao.countExpiredEvents(500);

          expect(count, equals(0));
        });

        test('returns 0 when no events exist', () async {
          final count = await dao.countExpiredEvents(nowUnix());

          expect(count, equals(0));
        });
      });
    });

    group('getRecentEventIdSigs', () {
      test(
        'returns (id, sig) pairs ordered by created_at descending',
        () async {
          final older = createEvent(content: 'older', createdAt: 1000);
          final newer = createEvent(content: 'newer', createdAt: 2000);
          await dao.upsertEvent(older);
          await dao.upsertEvent(newer);

          final pairs = await dao.getRecentEventIdSigs();

          expect(pairs, [
            (id: newer.id, sig: newer.sig),
            (id: older.id, sig: older.sig),
          ]);
        },
      );

      test('respects the limit', () async {
        for (var i = 0; i < 5; i++) {
          await dao.upsertEvent(
            createEvent(content: 'e$i', createdAt: 1000 + i),
          );
        }

        final pairs = await dao.getRecentEventIdSigs(limit: 2);

        expect(pairs, hasLength(2));
      });

      test('returns empty when no events exist', () async {
        expect(await dao.getRecentEventIdSigs(), isEmpty);
      });
    });
  });
}
