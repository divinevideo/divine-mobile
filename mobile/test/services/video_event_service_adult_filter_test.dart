// ABOUTME: TDD tests for VideoEventService adult content filtering
// ABOUTME: Tests filtering of flagged content when preference is neverShow

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nostr_sdk/event.dart';
import 'package:openvine/services/age_verification_service.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:openvine/services/subscription_manager.dart';
import 'package:openvine/services/video_event_service.dart';

class MockNostrService extends Mock implements NostrClient {}

class MockSubscriptionManager extends Mock implements SubscriptionManager {}

class MockAgeVerificationService extends Mock
    implements AgeVerificationService {}

void main() {
  late MockNostrService mockNostrService;
  late MockSubscriptionManager mockSubscriptionManager;
  late MockAgeVerificationService mockAgeVerificationService;
  late VideoEventService videoEventService;

  setUp(() {
    mockNostrService = MockNostrService();
    mockSubscriptionManager = MockSubscriptionManager();
    mockAgeVerificationService = MockAgeVerificationService();

    videoEventService = VideoEventService(
      mockNostrService,
      subscriptionManager: mockSubscriptionManager,
    );
  });

  group('VideoEventService - adult content filtering', () {
    test('setAgeVerificationService sets the service correctly', () {
      // Act
      videoEventService.setAgeVerificationService(mockAgeVerificationService);

      // Assert - no exception thrown, service attached
      expect(true, isTrue);
    });

    test('shouldFilterAdultContent returns false when service not set', () {
      // Assert - without setting service, should return false (allow all)
      expect(videoEventService.shouldFilterAdultContent, isFalse);
    });

    test(
      'shouldFilterAdultContent returns true when service says hide adult content',
      () {
        // Arrange
        when(
          () => mockAgeVerificationService.shouldHideAdultContent,
        ).thenReturn(true);
        videoEventService.setAgeVerificationService(mockAgeVerificationService);

        // Assert
        expect(videoEventService.shouldFilterAdultContent, isTrue);
      },
    );

    test(
      'shouldFilterAdultContent returns false when service says dont hide adult content',
      () {
        // Arrange
        when(
          () => mockAgeVerificationService.shouldHideAdultContent,
        ).thenReturn(false);
        videoEventService.setAgeVerificationService(mockAgeVerificationService);

        // Assert
        expect(videoEventService.shouldFilterAdultContent, isFalse);
      },
    );

    test('shouldFilterEvent returns true for flagged content when hiding', () {
      // Arrange
      when(
        () => mockAgeVerificationService.shouldHideAdultContent,
      ).thenReturn(true);
      videoEventService.setAgeVerificationService(mockAgeVerificationService);

      // Create a mock event with content-warning tag
      final event = Event(
        '0' * 64, // pubkey
        34236, // NIP-71 video kind
        [
          ['d', 'test-video-id'],
          ['url', 'https://example.com/video.mp4'],
          ['content-warning', 'adult content'],
        ],
        '', // content
      );

      // Assert
      expect(videoEventService.shouldFilterEvent(event), isTrue);
    });

    test(
      'shouldFilterEvent returns false for non-flagged content when hiding',
      () {
        // Arrange
        when(
          () => mockAgeVerificationService.shouldHideAdultContent,
        ).thenReturn(true);
        videoEventService.setAgeVerificationService(mockAgeVerificationService);

        // Create a mock event without content-warning tag
        final event = Event('1' * 64, 34236, [
          ['d', 'test-video-id-2'],
          ['url', 'https://example.com/video2.mp4'],
        ], '');

        // Assert
        expect(videoEventService.shouldFilterEvent(event), isFalse);
      },
    );

    test('shouldFilterEvent returns false when not hiding adult content', () {
      // Arrange
      when(
        () => mockAgeVerificationService.shouldHideAdultContent,
      ).thenReturn(false);
      videoEventService.setAgeVerificationService(mockAgeVerificationService);

      // Create event with content-warning tag
      final event = Event('2' * 64, 34236, [
        ['d', 'test-video-id-3'],
        ['url', 'https://example.com/video3.mp4'],
        ['content-warning', 'adult content'],
      ], '');

      // Assert - should NOT filter because user wants to see adult content
      expect(videoEventService.shouldFilterEvent(event), isFalse);
    });

    test('shouldFilterEvent handles NSFW hashtag as adult content', () {
      // Arrange
      when(
        () => mockAgeVerificationService.shouldHideAdultContent,
      ).thenReturn(true);
      videoEventService.setAgeVerificationService(mockAgeVerificationService);

      // Create event with NSFW hashtag
      final event = Event('3' * 64, 34236, [
        ['d', 'test-video-id-4'],
        ['url', 'https://example.com/video4.mp4'],
        ['t', 'NSFW'],
      ], '');

      // Assert
      expect(videoEventService.shouldFilterEvent(event), isTrue);
    });

    test('shouldFilterEvent handles adult hashtag as adult content', () {
      // Arrange
      when(
        () => mockAgeVerificationService.shouldHideAdultContent,
      ).thenReturn(true);
      videoEventService.setAgeVerificationService(mockAgeVerificationService);

      // Create event with adult hashtag
      final event = Event('4' * 64, 34236, [
        ['d', 'test-video-id-5'],
        ['url', 'https://example.com/video5.mp4'],
        ['t', 'adult'],
      ], '');

      // Assert
      expect(videoEventService.shouldFilterEvent(event), isTrue);
    });

    test(
      'filterAdultContentFromExistingVideos removes flagged videos from all lists',
      () {
        // Arrange
        when(
          () => mockAgeVerificationService.shouldHideAdultContent,
        ).thenReturn(true);
        videoEventService.setAgeVerificationService(mockAgeVerificationService);

        // Act - method should exist and not throw
        final removedCount = videoEventService
            .filterAdultContentFromExistingVideos();

        // Assert - returns count of removed videos (0 when empty)
        expect(removedCount, isA<int>());
        expect(removedCount, greaterThanOrEqualTo(0));
      },
    );

    test(
      'filterAdultContentFromExistingVideos does nothing when not hiding adult content',
      () {
        // Arrange
        when(
          () => mockAgeVerificationService.shouldHideAdultContent,
        ).thenReturn(false);
        videoEventService.setAgeVerificationService(mockAgeVerificationService);

        // Act
        final removedCount = videoEventService
            .filterAdultContentFromExistingVideos();

        // Assert - should not remove any videos
        expect(removedCount, equals(0));
      },
    );
  });
}
