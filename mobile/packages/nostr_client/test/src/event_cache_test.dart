// ABOUTME: Tests for EventCache wrapper class.
// ABOUTME: Verifies caching and NIP-01 replaceable event handling.

import 'dart:io';

import 'package:db_client/db_client.dart' hide Filter;
// ignore: depend_on_referenced_packages, drift is a transitive dep via db_client
import 'package:drift/native.dart';
import 'package:nostr_client/src/event_cache.dart';
import 'package:nostr_sdk/nostr_sdk.dart';
import 'package:test/test.dart';

void main() {
  late AppDatabase database;
  late DbClient dbClient;
  late AppDbClient appDbClient;
  late EventCache eventCache;
  late String tempDbPath;

  // Valid 64-char hex pubkey for testing
  const testPubkey =
      'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';

  /// Helper to create a test event
  Event createEvent({
    String pubkey = testPubkey,
    int kind = 1,
    List<List<String>> tags = const [],
    String content = 'test content',
    int? createdAt,
  }) {
    final event = Event(
      pubkey,
      kind,
      tags,
      content,
      createdAt: createdAt ?? DateTime.now().millisecondsSinceEpoch ~/ 1000,
    )
      // Sign with a dummy signature for testing
      ..sig = 'b' * 128;
    return event;
  }

  setUp(() async {
    final tempDir = Directory.systemTemp.createTempSync('event_cache_test_');
    tempDbPath = '${tempDir.path}/test.db';

    database = AppDatabase.test(NativeDatabase(File(tempDbPath)));
    dbClient = DbClient(generatedDatabase: database);
    appDbClient = AppDbClient(dbClient, database);
    eventCache = EventCache(appDbClient);
  });

  tearDown(() async {
    await database.close();
    final dbFile = File(tempDbPath);
    if (dbFile.existsSync()) {
      dbFile.deleteSync();
    }
  });

  group('EventCache', () {
    group('cacheEvent', () {
      test('stores a single event', () async {
        final event = createEvent(content: 'hello world');

        await eventCache.cacheEvent(event);

        final cached = await eventCache.getCachedEvent(event.id);
        expect(cached, isNotNull);
        expect(cached!.id, equals(event.id));
        expect(cached.content, equals('hello world'));
      });

      test('handles replaceable events (kind 0)', () async {
        final older = createEvent(
          kind: 0,
          content: 'old profile',
          createdAt: 1000,
        );
        final newer = createEvent(
          kind: 0,
          content: 'new profile',
          createdAt: 2000,
        );

        await eventCache.cacheEvent(older);
        await eventCache.cacheEvent(newer);

        // Should only have one event (newer replaces older)
        final cached = await eventCache.getCachedProfile(testPubkey);
        expect(cached, isNotNull);
        expect(cached!.content, equals('new profile'));
      });

      test(
        'does not replace newer with older for replaceable events',
        () async {
        final newer = createEvent(
          kind: 0,
          content: 'new profile',
          createdAt: 2000,
        );
        final older = createEvent(
          kind: 0,
          content: 'old profile',
          createdAt: 1000,
        );

        await eventCache.cacheEvent(newer);
        await eventCache.cacheEvent(older);

        // Should still have newer event
        final cached = await eventCache.getCachedProfile(testPubkey);
        expect(cached, isNotNull);
        expect(cached!.content, equals('new profile'));
      });
    });

    group('cacheEvents', () {
      test('stores multiple events in batch', () async {
        final events = [
          createEvent(content: 'event 1', createdAt: 1000),
          createEvent(content: 'event 2', createdAt: 2000),
          createEvent(content: 'event 3', createdAt: 3000),
        ];

        await eventCache.cacheEvents(events);

        for (final event in events) {
          final cached = await eventCache.getCachedEvent(event.id);
          expect(cached, isNotNull);
          expect(cached!.id, equals(event.id));
        }
      });
    });

    group('getCachedEvent', () {
      test('returns null for non-existent event', () async {
        final cached = await eventCache.getCachedEvent('nonexistent');
        expect(cached, isNull);
      });

      test('returns cached event by ID', () async {
        final event = createEvent(content: 'find me');
        await eventCache.cacheEvent(event);

        final cached = await eventCache.getCachedEvent(event.id);
        expect(cached, isNotNull);
        expect(cached!.content, equals('find me'));
      });
    });

    group('getCachedProfile', () {
      test('returns null for non-existent profile', () async {
        final cached = await eventCache.getCachedProfile('nonexistent');
        expect(cached, isNull);
      });

      test('returns cached profile (kind 0) by pubkey', () async {
        final profile = createEvent(
          kind: 0,
          content: '{"name": "Alice"}',
        );
        await eventCache.cacheEvent(profile);

        final cached = await eventCache.getCachedProfile(testPubkey);
        expect(cached, isNotNull);
        expect(cached!.kind, equals(0));
        expect(cached.content, equals('{"name": "Alice"}'));
      });
    });

    group('getCachedEvents', () {
      test('returns events matching filter by kind', () async {
        final note1 = createEvent(content: 'note 1');
        final note2 = createEvent(content: 'note 2');
        final reaction = createEvent(kind: 7, content: '+');

        await eventCache.cacheEvents([note1, note2, reaction]);

        final filter = Filter(kinds: [1]);
        final cached = await eventCache.getCachedEvents(filter);

        expect(cached.length, equals(2));
        expect(cached.every((e) => e.kind == 1), isTrue);
      });

      test('returns events matching filter by author', () async {
        final pubkey2 = 'b' * 64;
        final event1 = createEvent(content: 'from alice');
        final event2 = createEvent(pubkey: pubkey2, content: 'from bob');

        await eventCache.cacheEvents([event1, event2]);

        final filter = Filter(authors: [testPubkey]);
        final cached = await eventCache.getCachedEvents(filter);

        expect(cached.length, equals(1));
        expect(cached.first.pubkey, equals(testPubkey));
      });

      test('respects limit parameter', () async {
        final events = List.generate(
          10,
          (i) => createEvent(content: 'event $i', createdAt: 1000 + i),
        );
        await eventCache.cacheEvents(events);

        final filter = Filter(kinds: [1], limit: 5);
        final cached = await eventCache.getCachedEvents(filter);

        expect(cached.length, equals(5));
      });

      test('returns empty list when no events match', () async {
        final event = createEvent();
        await eventCache.cacheEvent(event);

        final filter = Filter(kinds: [7]); // Different kind
        final cached = await eventCache.getCachedEvents(filter);

        expect(cached, isEmpty);
      });
    });

    group('clearAll', () {
      test('removes all cached events', () async {
        final events = [
          createEvent(content: 'event 1'),
          createEvent(content: 'event 2'),
        ];
        await eventCache.cacheEvents(events);

        await eventCache.clearAll();

        for (final event in events) {
          final cached = await eventCache.getCachedEvent(event.id);
          expect(cached, isNull);
        }
      });
    });
  });
}
