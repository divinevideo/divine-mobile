// ABOUTME: Unit tests for classic vines channel priority loading functionality
// ABOUTME: Verifies that classic vines from special channel are loaded first and displayed at top of feed

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nostr_sdk/event.dart';
import 'package:nostr_sdk/filter.dart';
import 'package:openvine/services/nostr_service_interface.dart';
import 'package:openvine/services/subscription_manager.dart';
import 'package:openvine/services/video_event_service.dart';

// Mock classes
class MockNostrService extends Mock implements INostrService {}

class MockVideoEventService extends Mock implements VideoEventService {}

class MockEvent extends Mock implements Event {}

class TestSubscriptionManager extends Mock implements SubscriptionManager {
  TestSubscriptionManager(this.eventStreamController);
  final StreamController<Event> eventStreamController;

  @override
  Future<String> createSubscription({
    required String name,
    required List<Filter> filters,
    required Function(Event) onEvent,
    Function(dynamic)? onError,
    VoidCallback? onComplete,
    Duration? timeout,
    int priority = 5,
  }) async {
    eventStreamController.stream.listen(onEvent);
    return 'mock_sub_$name';
  }

  @override
  Future<void> cancelSubscription(String subscriptionId) async {}
}

// Fake classes for setUpAll
class FakeFilter extends Fake implements Filter {}

void main() {
  setUpAll(() {
    registerFallbackValue(FakeFilter());
  });

  group('Classic Vines Priority Loading Tests', () {
    const classicVinesPubkey =
        '25315276cbaeb8f2ed998ed55d15ef8c9cf2027baea191d1253d9a5c69a2b856';
    const editorPicksPubkey =
        '70ed6c56d6fb355f102a1e985741b5ee65f6ae9f772e028894b321bc74854082';
    const regularUserPubkey =
        'd0aa74d68e414f0305db9f7dc96ec32e616502e6ccf5bbf5739de19a96b67f3e';

    late VideoEventService videoEventService;
    late MockNostrService mockNostrService;
    late StreamController<Event> eventStreamController;

    setUp(() {
      mockNostrService = MockNostrService();
      eventStreamController = StreamController<Event>.broadcast();

      when(() => mockNostrService.isInitialized).thenReturn(true);
      when(() => mockNostrService.connectedRelayCount).thenReturn(1);
      when(
        () =>
            mockNostrService.subscribeToEvents(filters: any(named: 'filters')),
      ).thenAnswer((_) => eventStreamController.stream);

      final testSubscriptionManager = TestSubscriptionManager(
        eventStreamController,
      );
      videoEventService = VideoEventService(
        mockNostrService,
        subscriptionManager: testSubscriptionManager,
      );
    });

    tearDown(() async {
      await eventStreamController.close();
    });

    test('should identify classic vines pubkey correctly', () {
      // Create a classic vine event
      final classicVineEvent = Event(
        classicVinesPubkey,
        22,
        [
          ['url', 'https://example.com/classic-vine.mp4'],
          ['m', 'video/mp4'],
        ],
        'Classic Vine content',
        createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      );
      classicVineEvent.id = 'classic-vine-1';

      // Create a regular video event
      final regularEvent = Event(
        regularUserPubkey,
        22,
        [
          ['url', 'https://example.com/regular.mp4'],
          ['m', 'video/mp4'],
        ],
        'Regular video content',
        createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      );
      regularEvent.id = 'regular-video-1';

      // Verify pubkey detection
      expect(classicVineEvent.pubkey, equals(classicVinesPubkey));
      expect(regularEvent.pubkey, isNot(equals(classicVinesPubkey)));
    });

    test('should prioritize classic vines at top of feed', () async {
      // Create events with different timestamps and sources
      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;

      // Regular video (newest)
      final regularVideo = Event(
        regularUserPubkey,
        22,
        [
          ['url', 'https://example.com/regular.mp4'],
          ['m', 'video/mp4'],
        ],
        'Regular video',
        createdAt: now + 100,
      );
      regularVideo.id = 'regular-1';

      // Classic vine (older)
      final classicVine1 = Event(
        classicVinesPubkey,
        22,
        [
          ['url', 'https://example.com/classic1.mp4'],
          ['m', 'video/mp4'],
        ],
        'Classic vine 1',
        createdAt: now,
      );
      classicVine1.id = 'classic-1';

      // Another classic vine (even older)
      final classicVine2 = Event(
        classicVinesPubkey,
        22,
        [
          ['url', 'https://example.com/classic2.mp4'],
          ['m', 'video/mp4'],
        ],
        'Classic vine 2',
        createdAt: now - 100,
      );
      classicVine2.id = 'classic-2';

      // Editor's pick (middle timestamp)
      final editorPick = Event(
        editorPicksPubkey,
        22,
        [
          ['url', 'https://example.com/editor.mp4'],
          ['m', 'video/mp4'],
        ],
        'Editor pick',
        createdAt: now + 50,
      );
      editorPick.id = 'editor-1';

      // Subscribe and add events
      await videoEventService.subscribeToVideoFeed(
        subscriptionType: SubscriptionType.discovery,
      );
      await Future.delayed(const Duration(milliseconds: 10));

      // Add events in random order
      eventStreamController.add(regularVideo);
      await Future.delayed(const Duration(milliseconds: 10));

      eventStreamController.add(classicVine1);
      await Future.delayed(const Duration(milliseconds: 10));

      eventStreamController.add(editorPick);
      await Future.delayed(const Duration(milliseconds: 10));

      eventStreamController.add(classicVine2);
      await Future.delayed(const Duration(milliseconds: 10));

      // Verify order: Classic vines should be first, despite being older
      expect(videoEventService.discoveryVideos.length, equals(4));

      // Classic vines should be at top (sorted by timestamp among themselves)
      expect(
        videoEventService.discoveryVideos[0].id,
        equals('classic-1'),
      ); // Newer classic vine
      expect(
        videoEventService.discoveryVideos[1].id,
        equals('classic-2'),
      ); // Older classic vine

      // Editor's pick should come after classic vines
      expect(videoEventService.discoveryVideos[2].id, equals('editor-1'));

      // Regular video should be last despite being newest
      expect(videoEventService.discoveryVideos[3].id, equals('regular-1'));
    });

    test(
      'should maintain classic vines priority when adding new regular videos',
      () async {
        final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;

        // Add a classic vine first
        final classicVine = Event(
          classicVinesPubkey,
          22,
          [
            ['url', 'https://example.com/classic.mp4'],
            ['m', 'video/mp4'],
          ],
          'Classic vine',
          createdAt: now - 1000, // Old classic vine
        );
        classicVine.id = 'classic-old';

        await videoEventService.subscribeToVideoFeed(
          subscriptionType: SubscriptionType.discovery,
        );
        await Future.delayed(const Duration(milliseconds: 10));

        eventStreamController.add(classicVine);
        await Future.delayed(const Duration(milliseconds: 10));

        // Add multiple new regular videos
        for (var i = 0; i < 5; i++) {
          final newVideo = Event(
            regularUserPubkey,
            22,
            [
              ['url', 'https://example.com/new$i.mp4'],
              ['m', 'video/mp4'],
            ],
            'New video $i',
            createdAt: now + i * 10, // Progressively newer
          );
          newVideo.id = 'new-$i';

          eventStreamController.add(newVideo);
          await Future.delayed(const Duration(milliseconds: 10));
        }

        // Classic vine should still be first despite being oldest
        expect(videoEventService.discoveryVideos.length, equals(6));
        expect(
          videoEventService.discoveryVideos.first.id,
          equals('classic-old'),
        );
        expect(
          videoEventService.discoveryVideos.first.pubkey,
          equals(classicVinesPubkey),
        );
      },
    );

    test(
      'should handle multiple classic vines with correct internal ordering',
      () async {
        final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;

        // Create classic vines with different timestamps
        final classicVines = List.generate(5, (index) {
          final event = Event(
            classicVinesPubkey,
            22,
            [
              ['url', 'https://example.com/classic$index.mp4'],
              ['m', 'video/mp4'],
            ],
            'Classic vine $index',
            createdAt: now - index * 100, // Each one older than the last
          );
          event.id = 'classic-$index';
          return event;
        });

        await videoEventService.subscribeToVideoFeed(
          subscriptionType: SubscriptionType.discovery,
        );
        await Future.delayed(const Duration(milliseconds: 10));

        // Add in random order
        eventStreamController.add(classicVines[2]);
        eventStreamController.add(classicVines[0]);
        eventStreamController.add(classicVines[4]);
        eventStreamController.add(classicVines[1]);
        eventStreamController.add(classicVines[3]);

        await Future.delayed(const Duration(milliseconds: 50));

        // All should be classic vines
        expect(videoEventService.discoveryVideos.length, equals(5));

        // Should be ordered by timestamp (newest first) within classic vines
        expect(
          videoEventService.discoveryVideos[0].id,
          equals('classic-0'),
        ); // Newest
        expect(videoEventService.discoveryVideos[1].id, equals('classic-1'));
        expect(videoEventService.discoveryVideos[2].id, equals('classic-2'));
        expect(videoEventService.discoveryVideos[3].id, equals('classic-3'));
        expect(
          videoEventService.discoveryVideos[4].id,
          equals('classic-4'),
        ); // Oldest
      },
    );

    test('should correctly order all priority levels', () async {
      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;

      // Create events of each priority type
      final classicVine = Event(
        classicVinesPubkey,
        22,
        [
          ['url', 'https://example.com/classic.mp4'],
          ['m', 'video/mp4'],
        ],
        'Classic',
        createdAt: now - 1000,
      );
      classicVine.id = 'classic';

      final editorPick = Event(
        editorPicksPubkey,
        22,
        [
          ['url', 'https://example.com/editor.mp4'],
          ['m', 'video/mp4'],
        ],
        'Editor',
        createdAt: now + 1000, // Newer than classic
      );
      editorPick.id = 'editor';

      final regularVideo = Event(
        regularUserPubkey,
        22,
        [
          ['url', 'https://example.com/regular.mp4'],
          ['m', 'video/mp4'],
        ],
        'Regular',
        createdAt: now + 2000, // Newest
      );
      regularVideo.id = 'regular';

      await videoEventService.subscribeToVideoFeed(
        subscriptionType: SubscriptionType.discovery,
      );
      await Future.delayed(const Duration(milliseconds: 10));

      // Add in reverse priority order
      eventStreamController.add(regularVideo);
      eventStreamController.add(editorPick);
      eventStreamController.add(classicVine);

      await Future.delayed(const Duration(milliseconds: 30));

      // Verify priority ordering
      expect(videoEventService.discoveryVideos.length, equals(3));
      expect(
        videoEventService.discoveryVideos[0].id,
        equals('classic'),
      ); // Classic vine first
      expect(
        videoEventService.discoveryVideos[1].id,
        equals('editor'),
      ); // Editor pick second
      expect(
        videoEventService.discoveryVideos[2].id,
        equals('regular'),
      ); // Regular last
    });
  });
}
