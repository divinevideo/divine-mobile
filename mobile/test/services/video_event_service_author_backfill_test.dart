// ABOUTME: Tests VideoEventService.subscribeToUserVideos author-bucket backfill
// ABOUTME: Verifies cross-feed inclusion + case-insensitive dedup (O(M) refactor)

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/nostr_sdk.dart';
import 'package:openvine/observability/crash_reporter.dart';
import 'package:openvine/services/video_event_service.dart';

class _MockNostrClient extends Mock implements NostrClient {}

const _authorA =
    'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
const _authorB =
    'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';

Event _videoEvent(
  String id, {
  required String pubkey,
  int createdAt = 1000,
  String? dTag,
}) {
  // Kind 34236 = addressable short video, the only kind the app accepts.
  final event = Event(
    pubkey,
    34236,
    [
      ['d', dTag ?? id],
      ['url', 'https://example.com/$id.mp4'],
      ['title', 'Video $id'],
    ],
    'content',
    createdAt: createdAt,
  );
  event.id = id;
  return event;
}

void main() {
  setUpAll(() {
    registerFallbackValue(<Filter>[]);
  });

  group('VideoEventService.subscribeToUserVideos backfill', () {
    late VideoEventService service;
    late _MockNostrClient nostr;
    late StreamController<Event> eventStream;

    setUp(() {
      nostr = _MockNostrClient();
      eventStream = StreamController<Event>.broadcast();

      when(() => nostr.isInitialized).thenReturn(true);
      when(() => nostr.connectedRelayCount).thenReturn(1);
      when(() => nostr.connectedRelays).thenReturn(['wss://relay.example.com']);
      when(() => nostr.subscribe(any())).thenAnswer((_) => eventStream.stream);
      when(
        () => nostr.subscribe(
          any(),
          subscriptionId: any(named: 'subscriptionId'),
          onEose: any(named: 'onEose'),
        ),
      ).thenAnswer((_) => eventStream.stream);

      service = VideoEventService(
        nostr,
        crashReporter: const SilentCrashReporter(),
      );
    });

    tearDown(() async {
      await eventStream.close();
      service.dispose();
    });

    test('backfills only this author across feeds, newest first', () async {
      service
        ..handleEventForTesting(
          _videoEvent('a-old', pubkey: _authorA, createdAt: 500),
          SubscriptionType.discovery,
        )
        ..handleEventForTesting(
          _videoEvent('a-new', pubkey: _authorA, createdAt: 3000),
          SubscriptionType.homeFeed,
        )
        ..handleEventForTesting(
          _videoEvent('b-1', pubkey: _authorB, createdAt: 2000),
          SubscriptionType.discovery,
        );

      expect(service.discoveryVideos.length, 2, reason: 'discovery seeded');
      expect(service.homeFeedVideos.length, 1, reason: 'home seeded');

      await service.subscribeToUserVideos(_authorA);

      final authored = service.authorVideos(_authorA);
      expect(authored.map((v) => v.id), ['a-new', 'a-old']);
    });

    test('dedupes the same video present in multiple feeds', () async {
      // Same event id (case-insensitive) seeded into two feeds under
      // distinct d-tags, so both feeds retain it and the backfill must
      // collapse them to a single bucket entry.
      service
        ..handleEventForTesting(
          _videoEvent('dup', pubkey: _authorA, dTag: 'd1'),
          SubscriptionType.discovery,
        )
        ..handleEventForTesting(
          _videoEvent('DUP', pubkey: _authorA, dTag: 'd2'),
          SubscriptionType.homeFeed,
        );

      await service.subscribeToUserVideos(_authorA);

      final authored = service.authorVideos(_authorA);
      expect(authored, hasLength(1));
      expect(authored.single.id.toLowerCase(), 'dup');
    });

    test(
      'skips stale profile unsubscribe after another author is active',
      () async {
        final authorAStream = StreamController<Event>.broadcast();
        final authorBStream = StreamController<Event>.broadcast();

        when(
          () => nostr.subscribe(
            any(),
            subscriptionId: any(named: 'subscriptionId'),
            onEose: any(named: 'onEose'),
          ),
        ).thenAnswer((invocation) {
          final filters = invocation.positionalArguments.single as List<Filter>;
          final authors = filters.first.authors;
          if (authors?.contains(_authorA) ?? false) {
            return authorAStream.stream;
          }
          return authorBStream.stream;
        });

        await service.subscribeToUserVideos(_authorA);
        expect(authorAStream.hasListener, isTrue);

        await service.subscribeToUserVideos(_authorB);
        expect(authorAStream.hasListener, isFalse);
        expect(authorBStream.hasListener, isTrue);

        await service.unsubscribeFromUserVideos(_authorA);

        expect(authorBStream.hasListener, isTrue);

        await authorAStream.close();
        await authorBStream.close();
      },
    );
  });
}
