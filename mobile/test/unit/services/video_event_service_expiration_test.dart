// ABOUTME: Test NIP-40 expiration filtering in VideoEventService
// ABOUTME: Ensures expired events are filtered out and not added to feeds

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/nostr_sdk.dart';
import 'package:openvine/observability/crash_reporter.dart';
import 'package:openvine/services/video_event_service.dart';

class _MockNostrService extends Mock implements NostrClient {}

class _FakeFilter extends Fake implements Filter {}

int _secondsFromNow(int offset) =>
    DateTime.now().millisecondsSinceEpoch ~/ 1000 + offset;

Event _videoEvent({required String id, required int expiresAt}) {
  final event = Event(
    'a' * 64,
    NIP71VideoKinds.addressableShortVideo,
    [
      ['d', 'vine_$id'],
      ['url', 'https://example.com/video.mp4'],
      ['m', 'video/mp4'],
      ['expiration', expiresAt.toString()],
    ],
    '',
    createdAt: _secondsFromNow(0),
  );
  event.id = id;
  return event;
}

void main() {
  group('VideoEventService NIP-40 Expiration Filtering', () {
    late VideoEventService service;
    late NostrClient nostrService;
    late StreamController<Event> events;

    setUpAll(() {
      registerFallbackValue(_FakeFilter());
      registerFallbackValue(<Filter>[]);
    });

    setUp(() {
      events = StreamController<Event>.broadcast();
      nostrService = _MockNostrService();
      service = VideoEventService(
        nostrService,
        crashReporter: const SilentCrashReporter(),
      );
    });

    tearDown(() async {
      await events.close();
      service.dispose();
    });

    test('filters out expired events when adding to discovery feed', () async {
      when(() => nostrService.isInitialized).thenReturn(true);
      when(() => nostrService.connectedRelayCount).thenReturn(1);
      when(() => nostrService.connectedRelays).thenReturn(const ['wss://r']);
      when(
        () => nostrService.subscribe(
          any(),
          onEose: any(named: 'onEose'),
          subscriptionId: any(named: 'subscriptionId'),
          tempRelays: any(named: 'tempRelays'),
          targetRelays: any(named: 'targetRelays'),
          relayTypes: any(named: 'relayTypes'),
          sendAfterAuth: any(named: 'sendAfterAuth'),
        ),
      ).thenAnswer((_) => events.stream);

      await service.subscribeToDiscovery();

      // One already expired, one not. Only the live one may reach the feed.
      events
        ..add(_videoEvent(id: 'expired1', expiresAt: _secondsFromNow(-60)))
        ..add(_videoEvent(id: 'live1', expiresAt: _secondsFromNow(3600)));
      await pumpEventQueue();

      final discoveryVideos = service.getVideos(SubscriptionType.discovery);

      expect(
        discoveryVideos.map((v) => v.id),
        equals(['live1']),
        reason: 'an expired event must not reach the discovery feed',
      );
    });

    test('allows non-expired events into discovery feed', () {
      // Create a future-expiring event (1 hour from now)
      final oneHourFromNow = DateTime.now().add(const Duration(hours: 1));
      final expirationTimestamp = oneHourFromNow.millisecondsSinceEpoch ~/ 1000;

      final futureEvent = Event.fromJson({
        'id': 'future123',
        'pubkey': 'pubkey123',
        'created_at': DateTime.now().millisecondsSinceEpoch ~/ 1000,
        'kind': 34236,
        'tags': [
          ['url', 'https://example.com/video.mp4'],
          ['expiration', expirationTimestamp.toString()],
        ],
        'content': 'Future-expiring video',
        'sig': 'sig123',
      });

      final videoEvent = VideoEvent.fromNostrEvent(futureEvent);

      // Non-expired events should pass through the filter
      expect(videoEvent.isExpired, isFalse);
      expect(videoEvent.expirationTimestamp, equals(expirationTimestamp));
    });

    test('allows events without expiration tag', () {
      final normalEvent = Event.fromJson({
        'id': 'normal123',
        'pubkey': 'pubkey123',
        'created_at': DateTime.now().millisecondsSinceEpoch ~/ 1000,
        'kind': 34236,
        'tags': [
          ['url', 'https://example.com/video.mp4'],
        ],
        'content': 'Normal video without expiration',
        'sig': 'sig123',
      });

      final videoEvent = VideoEvent.fromNostrEvent(normalEvent);

      // Events without expiration should never be considered expired
      expect(videoEvent.isExpired, isFalse);
      expect(videoEvent.expirationTimestamp, isNull);
    });
  });
}
