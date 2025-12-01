// ABOUTME: Test suite for VideoEventProcessor service
// ABOUTME: Tests Nostr event processing and stream management for video events

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:nostr_sdk/event.dart';
import 'package:openvine/models/video_event.dart';
import 'package:openvine/services/video_event_processor.dart';

/// Tests for VideoEventProcessor that handles Nostr video event processing
void main() {
  group('VideoEventProcessor', () {
    late VideoEventProcessor processor;

    setUp(() {
      processor = VideoEventProcessor();
    });

    tearDown(() {
      processor.dispose();
    });

    group('Event Processing', () {
      test('should process kind 34236 video events', () async {
        // ARRANGE
        final validEvent = Event(
          '1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef', // pubkey (hex)
          34236, // NIP-71 addressable short video
          [
            ['d', 'test_vine_id'], // Required for addressable events
            ['url', 'https://example.com/video.mp4'],
            ['title', 'Test Video'],
            ['duration', '30'],
          ],
          'Check out this awesome video!',
        );

        // Subscribe to video event stream
        final videoEventCompleter = Completer<VideoEvent>();
        final subscription = processor.videoEventStream.listen((event) {
          videoEventCompleter.complete(event);
        });

        // ACT
        processor.processEvent(validEvent);

        // ASSERT
        final videoEvent = await videoEventCompleter.future;
        expect(videoEvent, isNotNull);
        expect(videoEvent.id, isNotEmpty);
        expect(videoEvent.pubkey, isNotEmpty);
        expect(videoEvent.content, 'Check out this awesome video!');
        expect(videoEvent.title, 'Test Video');
        expect(videoEvent.videoUrl, 'https://example.com/video.mp4');
        expect(videoEvent.duration, 30);

        // Cleanup
        await subscription.cancel();
      });

      test('should ignore non-video events', () async {
        // ARRANGE
        final textEvent = Event(
          '1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef', // pubkey (hex)
          1, // Text note, not video
          [],
          'This is not a video event',
        );

        // Subscribe to video event stream
        bool eventReceived = false;
        final subscription = processor.videoEventStream.listen((event) {
          eventReceived = true;
        });

        // ACT
        processor.processEvent(textEvent);

        // Wait a bit to ensure no event is emitted
        await Future.delayed(const Duration(milliseconds: 100));

        // ASSERT
        expect(eventReceived, isFalse);

        // Cleanup
        await subscription.cancel();
      });

      test('should handle kind 6 repost events', () async {
        // ARRANGE
        final repostEvent = Event(
          '1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef', // pubkey (hex)
          6, // Repost
          [
            ['e', 'original_video_id', 'relay_url'],
          ],
          'Reposting this video',
        );

        // Subscribe to error stream to ensure no errors
        bool errorReceived = false;
        final errorSubscription = processor.errorStream.listen((error) {
          errorReceived = true;
        });

        // ACT
        processor.processEvent(repostEvent);

        // Wait a bit
        await Future.delayed(const Duration(milliseconds: 100));

        // ASSERT - Should not error, just log that it's not implemented
        expect(errorReceived, isFalse);

        // Cleanup
        await errorSubscription.cancel();
      });

      test('should process video events with missing URL gracefully', () async {
        // ARRANGE
        final eventWithoutUrl = Event(
          '1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef', // pubkey (hex)
          34236, // NIP-71 addressable short video
          [
            ['d', 'invalid_vine_id'], // Required for addressable events
            // Missing 'url' tag - should be handled gracefully
            ['title', 'Video without URL'],
          ],
          'This should not fail',
        );

        // Subscribe to video event stream
        final videoEventCompleter = Completer<VideoEvent>();
        final subscription = processor.videoEventStream.listen((event) {
          videoEventCompleter.complete(event);
        });

        // ACT
        processor.processEvent(eventWithoutUrl);

        // ASSERT - Should create VideoEvent with null videoUrl
        final videoEvent = await videoEventCompleter.future;
        expect(videoEvent, isNotNull);
        expect(videoEvent.id, isNotEmpty);
        expect(videoEvent.title, 'Video without URL');
        expect(
          videoEvent.videoUrl,
          isNull,
        ); // URL should be null, not cause error

        // Cleanup
        await subscription.cancel();
      });
    });

    group('Stream Management', () {
      test('should connect to event stream', () async {
        // ARRANGE
        final eventStreamController = StreamController<Event>.broadcast();
        final testEvent = Event(
          '1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef',
          34236, // NIP-71 addressable short video
          [
            ['d', 'stream_test_vine'], // Required for addressable events
            ['url', 'https://example.com/video.mp4'],
          ],
          'Test video',
        );

        // Subscribe to video event stream
        final videoEventCompleter = Completer<VideoEvent>();
        final subscription = processor.videoEventStream.listen((event) {
          videoEventCompleter.complete(event);
        });

        // ACT
        processor.connectToEventStream(eventStreamController.stream);
        eventStreamController.add(testEvent);

        // ASSERT
        final videoEvent = await videoEventCompleter.future;
        expect(videoEvent.videoUrl, 'https://example.com/video.mp4');

        // Cleanup
        await subscription.cancel();
        await eventStreamController.close();
      });

      test('should handle stream errors', () async {
        // ARRANGE
        final eventStreamController = StreamController<Event>.broadcast();

        // Subscribe to error stream
        final errorCompleter = Completer<String>();
        final subscription = processor.errorStream.listen((error) {
          errorCompleter.complete(error);
        });

        // ACT
        processor.connectToEventStream(eventStreamController.stream);
        eventStreamController.addError('Test error');

        // ASSERT
        final error = await errorCompleter.future;
        expect(error, contains('Test error'));

        // Cleanup
        await subscription.cancel();
        await eventStreamController.close();
      });

      test('should disconnect from event stream', () async {
        // ARRANGE
        final eventStreamController = StreamController<Event>.broadcast();
        processor.connectToEventStream(eventStreamController.stream);

        // ACT
        processor.disconnectFromEventStream();

        // Try to add event after disconnection
        bool eventReceived = false;
        final subscription = processor.videoEventStream.listen((event) {
          eventReceived = true;
        });

        eventStreamController.add(
          Event(
            '1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef',
            34236, // NIP-71 addressable short video
            [
              ['d', 'disconnect_test_vine'], // Required for addressable events
              ['url', 'https://example.com/video.mp4'],
            ],
            'Should not be processed',
          ),
        );

        await Future.delayed(const Duration(milliseconds: 100));

        // ASSERT
        expect(eventReceived, isFalse);

        // Cleanup
        await subscription.cancel();
        await eventStreamController.close();
      });
    });

    group('VideoEvent Creation', () {
      test('should handle events with imeta tags', () async {
        // ARRANGE
        final imetaEvent = Event(
          '1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef',
          34236, // NIP-71 addressable short video
          [
            ['d', 'imeta_test_vine'], // Required for addressable events
            [
              'imeta',
              'url https://example.com/imeta_video.mp4',
              'm video/mp4',
              'x abc123def456',
              'size 5242880',
              'dim 1280x720',
              'duration 60',
            ],
            ['title', 'Imeta Video'],
          ],
          'Video with imeta data',
        );

        // Subscribe to video event stream
        final videoEventCompleter = Completer<VideoEvent>();
        final subscription = processor.videoEventStream.listen((event) {
          videoEventCompleter.complete(event);
        });

        // ACT
        processor.processEvent(imetaEvent);

        // ASSERT
        final videoEvent = await videoEventCompleter.future;
        expect(videoEvent.videoUrl, 'https://example.com/imeta_video.mp4');
        expect(videoEvent.mimeType, 'video/mp4');
        expect(videoEvent.sha256, 'abc123def456');
        expect(videoEvent.fileSize, 5242880);
        expect(videoEvent.dimensions, '1280x720');
        expect(videoEvent.duration, 60);

        // Cleanup
        await subscription.cancel();
      });

      test('should handle missing optional fields gracefully', () async {
        // ARRANGE
        final minimalEvent = Event(
          '1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef',
          34236, // NIP-71 addressable short video
          [
            ['d', 'minimal_test_vine'], // Required for addressable events
            ['url', 'https://example.com/minimal.mp4'],
          ],
          'Minimal video event',
        );

        // Subscribe to video event stream
        final videoEventCompleter = Completer<VideoEvent>();
        final subscription = processor.videoEventStream.listen((event) {
          videoEventCompleter.complete(event);
        });

        // ACT
        processor.processEvent(minimalEvent);

        // ASSERT
        final videoEvent = await videoEventCompleter.future;
        expect(videoEvent.id, isNotEmpty);
        expect(videoEvent.videoUrl, 'https://example.com/minimal.mp4');
        expect(videoEvent.title, isNull);
        expect(videoEvent.duration, isNull);
        expect(videoEvent.dimensions, isNull);
        expect(videoEvent.hashtags, isEmpty);

        // Cleanup
        await subscription.cancel();
      });

      test('should process multiple events in sequence', () async {
        // ARRANGE
        final events = List.generate(
          3,
          (i) => Event(
            '1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef',
            34236, // NIP-71 addressable short video
            [
              ['d', 'sequence_test_vine_$i'], // Required for addressable events
              ['url', 'https://example.com/video$i.mp4'],
              ['title', 'Video $i'],
            ],
            'Video content $i',
          ),
        );

        // Subscribe to video event stream
        final receivedEvents = <VideoEvent>[];
        final subscription = processor.videoEventStream.listen((event) {
          receivedEvents.add(event);
        });

        // ACT
        for (final event in events) {
          processor.processEvent(event);
        }

        // Wait for all events to be processed
        await Future.delayed(const Duration(milliseconds: 100));

        // ASSERT
        expect(receivedEvents.length, 3);
        for (var i = 0; i < 3; i++) {
          expect(receivedEvents[i].title, 'Video $i');
          expect(receivedEvents[i].videoUrl, 'https://example.com/video$i.mp4');
        }

        // Cleanup
        await subscription.cancel();
      });
    });
  });
}
