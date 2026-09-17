// ABOUTME: Regression tests for purging NIP-09 deleted videos from the local
// ABOUTME: event store, so a restart's cache-first load cannot resurface them.

import 'dart:async';
import 'dart:io';

import 'package:db_client/db_client.dart' hide Filter;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/event.dart';
import 'package:nostr_sdk/filter.dart';
import 'package:openvine/observability/crash_reporter.dart';
import 'package:openvine/services/event_router.dart';
import 'package:openvine/services/video_event_service.dart';
import 'package:path/path.dart' as p;

/// Emits events on demand so a deletion can be delivered after the video.
class _StreamingNostrService implements NostrClient {
  final StreamController<Event> _events = StreamController<Event>.broadcast();

  @override
  bool get isInitialized => true;

  @override
  int get connectedRelayCount => 1;

  @override
  Stream<Event> subscribe(
    List<Filter> filters, {
    String? subscriptionId,
    List<String>? tempRelays,
    List<String>? targetRelays,
    List<int> relayTypes = const [],
    bool sendAfterAuth = false,
    void Function()? onEose,
    bool closeOnEose = false,
  }) {
    if (onEose != null) {
      unawaited(Future.microtask(onEose));
    }
    return _events.stream;
  }

  void emit(Event event) => _events.add(event);

  @override
  Future<void> dispose() async => _events.close();

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

const _authorPubkey =
    'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
const _otherPubkey =
    'eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee';
const _videoId =
    'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';
const _editedVideoId =
    'baaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaab';
const _deletionId =
    'cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc';
const _sig =
    'dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd'
    'dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd';

Event _videoEvent({
  String? id,
  String pubkey = _authorPubkey,
  int createdAt = 1000,
  String? publishedAt,
}) =>
    Event(
        pubkey,
        34236,
        [
          ['d', 'clip-1'],
          ['url', 'https://example.com/video.mp4'],
          ['title', 'Deleted clip'],
          if (publishedAt != null) ['published_at', publishedAt],
        ],
        'a video that gets deleted',
        createdAt: createdAt,
      )
      ..id = id ?? _videoId
      ..sig = _sig;

Event _deletionEvent({String pubkey = _authorPubkey}) =>
    Event(
        pubkey,
        5,
        [
          ['e', _videoId],
        ],
        'deleted by author',
        createdAt: 2000,
      )
      ..id = _deletionId
      ..sig = _sig;

Event _addressableDeletionEvent({bool uppercaseTagPubkey = false}) {
  final tagPubkey = uppercaseTagPubkey
      ? _authorPubkey.toUpperCase()
      : _authorPubkey;
  return Event(
      _authorPubkey,
      5,
      [
        ['a', '34236:$tagPubkey:clip-1'],
      ],
      'deleted by author',
      createdAt: 2000,
    )
    ..id = _deletionId
    ..sig = _sig;
}

void main() {
  group('VideoEventService NIP-09 local cache purge', () {
    late AppDatabase db;
    late String dbPath;
    late Directory tempDir;
    late EventRouter eventRouter;
    late _StreamingNostrService nostrService;
    late VideoEventService service;

    setUp(() async {
      tempDir = Directory.systemTemp.createTempSync('openvine_purge_test_');
      dbPath = p.join(tempDir.path, 'test.db');
      db = AppDatabase.test(NativeDatabase(File(dbPath)));
      eventRouter = EventRouter(
        db,
        config: const EventRouterConfig(autoStart: false),
      );
      nostrService = _StreamingNostrService();
      service = VideoEventService(
        nostrService,
        crashReporter: const SilentCrashReporter(),
        eventRouter: eventRouter,
      );
    });

    tearDown(() async {
      service.dispose();
      await db.close();
      if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
    });

    /// Lets the broadcast stream forward pending events into the router, then
    /// persists them. Replaces wall-clock waits.
    Future<void> settle() async {
      await pumpEventQueue();
      await eventRouter.drainForTesting();
    }

    Future<int> cachedVideoRowCount() async {
      final rows = await db.nostrEventsDao.getEventsByFilter(
        Filter(kinds: const [34236], authors: const [_authorPubkey]),
      );
      return rows.length;
    }

    test('deletes the target event row from the local store', () async {
      await service.subscribeToVideoFeed(
        subscriptionType: SubscriptionType.discovery,
      );
      nostrService.emit(_videoEvent());
      await settle();
      expect(
        await cachedVideoRowCount(),
        1,
        reason: 'the video should be cached before the deletion arrives',
      );

      nostrService.emit(_deletionEvent());
      await settle();

      expect(await cachedVideoRowCount(), 0);
    });

    test('the cache-first read does not write the row back', () async {
      // A row already in the store, as after a restart.
      await db.nostrEventsDao.upsertEvent(_videoEvent());
      expect(await cachedVideoRowCount(), 1);

      // Cache-first picks it up and hands it to the same handler the relay
      // path uses. Deliberately no drain here: that write-back is what used to
      // land after the purge and resurrect the row on every single launch.
      await service.subscribeToVideoFeed(
        subscriptionType: SubscriptionType.discovery,
        authors: const [_authorPubkey],
      );

      nostrService.emit(_deletionEvent());
      await pumpEventQueue();
      await pumpEventQueue();
      await eventRouter.drainForTesting();

      expect(await cachedVideoRowCount(), 0);
    });

    test('deletes the row on a locally initiated delete too', () async {
      await service.subscribeToVideoFeed(
        subscriptionType: SubscriptionType.discovery,
      );
      nostrService.emit(_videoEvent());
      await settle();
      expect(await cachedVideoRowCount(), 1);

      service.removeVideoCompletely(_videoId);
      await pumpEventQueue();

      expect(await cachedVideoRowCount(), 0);
    });

    test(
      'does not re-persist a tombstoned video the relay redelivers',
      () async {
        await service.subscribeToVideoFeed(
          subscriptionType: SubscriptionType.discovery,
        );
        nostrService.emit(_videoEvent());
        await settle();
        nostrService.emit(_deletionEvent());
        await settle();
        expect(await cachedVideoRowCount(), 0);

        // A relay that never received the Kind 5 — or a second subscription —
        // serves the deleted clip again.
        nostrService.emit(_videoEvent());
        await settle();

        expect(await cachedVideoRowCount(), 0);
      },
    );

    test(
      'does not re-persist an edit of a tombstoned addressable video',
      () async {
        await service.subscribeToVideoFeed(
          subscriptionType: SubscriptionType.discovery,
        );
        nostrService.emit(_videoEvent());
        await settle();
        nostrService.emit(_addressableDeletionEvent());
        await settle();
        expect(await cachedVideoRowCount(), 0);

        // An edit mints a new event id for the same `pubkey:d-tag` clip, so only
        // the coordinate half of the tombstone can catch it.
        nostrService.emit(_videoEvent(id: _editedVideoId));
        await settle();

        expect(await cachedVideoRowCount(), 0);
      },
    );

    test('a deletion arriving in the same burst still wins', () async {
      await service.subscribeToVideoFeed(
        subscriptionType: SubscriptionType.discovery,
      );

      // Video and its Kind 5 share one REQ, so the video is still queued in
      // the router — unflushed — when the deletion is applied. The purge must
      // evict that pending write, not just DELETE a row that isn't there yet.
      nostrService.emit(_videoEvent());
      await pumpEventQueue();
      nostrService.emit(_deletionEvent());
      await settle();

      expect(await cachedVideoRowCount(), 0);
    });

    test('purges a stored row that no feed has loaded into memory', () async {
      await db.nostrEventsDao.upsertEvent(_videoEvent());
      expect(await cachedVideoRowCount(), 1);

      // A feed for a different author: the row stays in the store, unloaded.
      await service.subscribeToVideoFeed(
        subscriptionType: SubscriptionType.homeFeed,
        authors: const [_otherPubkey],
      );
      nostrService.emit(_deletionEvent());
      await settle();

      expect(await cachedVideoRowCount(), 0);
    });

    test(
      'sweeps a copy admitted while the store purge was in flight',
      () async {
        await db.nostrEventsDao.upsertEvent(_videoEvent());

        // A feed for a different author, so the row stays in the store and the
        // deletion finds nothing in memory to validate against.
        await service.subscribeToVideoFeed(
          subscriptionType: SubscriptionType.homeFeed,
          authors: const [_otherPubkey],
        );
        nostrService.emit(_deletionEvent());
        // The copy lands while the purge is still suspended on its DAO round
        // trip, so it clears the ingestion guard and a feed takes it.
        nostrService.emit(_videoEvent());
        await settle();

        expect(await cachedVideoRowCount(), 0);
        expect(
          service.homeFeedVideos.where((v) => v.id == _videoId),
          isEmpty,
          reason: 'the tombstone must also evict what the window let in',
        );
      },
    );

    test('purges a stored row signed in the deletion second', () async {
      // NIP-09 deletes "up to the created_at timestamp" — inclusive — and the
      // DAO maps `until` to `created_at <= ?`. Off by one here strands the row
      // on disk for the cache-first read to re-serve, while the in-memory
      // guards would still treat the clip as deleted.
      await db.nostrEventsDao.upsertEvent(
        _videoEvent(id: _editedVideoId, createdAt: 2000),
      );

      await service.subscribeToVideoFeed(
        subscriptionType: SubscriptionType.homeFeed,
        authors: const [_otherPubkey],
      );
      nostrService.emit(_addressableDeletionEvent());
      await settle();

      expect(await cachedVideoRowCount(), 0);
    });

    test('purges a stored row when the `a` tag uses uppercase hex', () async {
      await db.nostrEventsDao.upsertEvent(_videoEvent());
      expect(await cachedVideoRowCount(), 1);

      // The author gate lowercases before comparing, so an uppercase tag is
      // accepted; the SQL `pubkey IN (...)` behind the purge is case-sensitive
      // and would match nothing if the tag's own casing were bound.
      await service.subscribeToVideoFeed(
        subscriptionType: SubscriptionType.homeFeed,
        authors: const [_otherPubkey],
      );
      nostrService.emit(_addressableDeletionEvent(uppercaseTagPubkey: true));
      await settle();

      expect(await cachedVideoRowCount(), 0);
    });

    test('ignores a deletion that does not come from the row author', () async {
      await db.nostrEventsDao.upsertEvent(_videoEvent());
      expect(await cachedVideoRowCount(), 1);

      await service.subscribeToVideoFeed(
        subscriptionType: SubscriptionType.discovery,
      );
      // Forged `e` tag: a relay cannot delete another author's cached rows.
      nostrService.emit(_deletionEvent(pubkey: _otherPubkey));
      await settle();

      expect(await cachedVideoRowCount(), 1);
    });

    test(
      'keeps a coordinate version published after the deletion request',
      () async {
        // NIP-09 scopes an `a` deletion to versions up to its own created_at.
        // Relays redeliver old Kind 5s on every launch, so an unbounded purge
        // would wipe a clip the author has since republished.
        await db.nostrEventsDao.upsertEvent(
          _videoEvent(id: _editedVideoId, createdAt: 5000),
        );
        expect(await cachedVideoRowCount(), 1);

        // Cache-first loads the row, so this covers the in-memory coordinate
        // tombstone and the store purge together.
        await service.subscribeToVideoFeed(
          subscriptionType: SubscriptionType.discovery,
        );
        nostrService.emit(_addressableDeletionEvent());
        await settle();

        expect(await cachedVideoRowCount(), 1);
      },
    );

    test('keeps the republished version visible in the feed', () async {
      await service.subscribeToVideoFeed(
        subscriptionType: SubscriptionType.discovery,
      );
      // Same coordinate, published after the deletion request below.
      nostrService.emit(_videoEvent(id: _editedVideoId, createdAt: 5000));
      await settle();

      nostrService.emit(_addressableDeletionEvent());
      await settle();

      expect(
        service.discoveryVideos.where((v) => v.id == _editedVideoId),
        isNotEmpty,
        reason: 'a version newer than the deletion is not covered by it',
      );
    });

    test(
      'caches a version the author republishes after the deletion',
      () async {
        await service.subscribeToVideoFeed(
          subscriptionType: SubscriptionType.discovery,
        );
        nostrService.emit(_addressableDeletionEvent());
        await settle();

        // The tombstone now exists, so this arrival is what the ingestion guard
        // inspects — and a version newer than the deletion is not covered.
        nostrService.emit(_videoEvent(id: _editedVideoId, createdAt: 5000));
        await settle();

        expect(await cachedVideoRowCount(), 1);
      },
    );

    test(
      'keeps an edited clip whose published_at predates the deletion',
      () async {
        // An edit keeps the `d` tag and re-emits the original published_at, so
        // VideoEvent.createdAt reports the first publication. Comparing that
        // against the deletion would hide a clip republished after it — the row
        // survives on disk while every feed drops it.
        await service.subscribeToVideoFeed(
          subscriptionType: SubscriptionType.discovery,
        );
        nostrService.emit(_addressableDeletionEvent());
        await settle();

        nostrService.emit(
          _videoEvent(id: _editedVideoId, createdAt: 3000, publishedAt: '1000'),
        );
        await settle();

        expect(
          service.discoveryVideos.where((v) => v.id == _editedVideoId),
          isNotEmpty,
          reason: 'the edit was published after the deletion request',
        );
        expect(await cachedVideoRowCount(), 1);
      },
    );

    test('tombstones a purged row so a relay cannot write it back', () async {
      await db.nostrEventsDao.upsertEvent(_videoEvent());

      // Never loaded into memory, so only the store purge sees it.
      await service.subscribeToVideoFeed(
        subscriptionType: SubscriptionType.homeFeed,
        authors: const [_otherPubkey],
      );
      nostrService.emit(_deletionEvent());
      await settle();
      expect(await cachedVideoRowCount(), 0);

      // Without a recorded tombstone the ingestion guard stays false here.
      nostrService.emit(_videoEvent());
      await settle();

      expect(await cachedVideoRowCount(), 0);
    });
  });
}
