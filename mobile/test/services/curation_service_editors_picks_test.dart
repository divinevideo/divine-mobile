// ABOUTME: Tests for CurationService Editor's Picks functionality and randomization
// ABOUTME: Verifies Editor's Picks shows Classic Vines videos in random order

import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:nostr_sdk/event.dart';
import 'package:openvine/constants/app_constants.dart';
import 'package:openvine/models/curation_set.dart';
import 'package:openvine/models/video_event.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/curation_service.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:openvine/services/social_service.dart';
import 'package:openvine/services/video_event_service.dart';

import 'curation_service_test.mocks.dart';

@GenerateMocks([NostrClient, VideoEventService, SocialService, AuthService])
void main() {
  group("CurationService Editor's Picks", () {
    late MockNostrClient mockNostrService;
    late MockVideoEventService mockVideoEventService;
    late MockSocialService mockSocialService;
    late MockAuthService mockAuthService;

    setUp(() {
      mockNostrService = MockNostrClient();
      mockVideoEventService = MockVideoEventService();
      mockSocialService = MockSocialService();
      mockAuthService = MockAuthService();

      // Mock the getCachedLikeCount method to return 0 for all videos
      when(mockSocialService.getCachedLikeCount(any)).thenReturn(0);
      // Mock discoveryVideos to avoid MissingStubError during CurationService initialization
      when(mockVideoEventService.discoveryVideos).thenReturn([]);
      // Mock subscribeToEvents to avoid MissingStubError when fetching Editor's Picks list
      when(
        mockNostrService.subscribe(argThat(anything)),
      ).thenAnswer((_) => Stream<Event>.empty());
    });

    test("should show videos from Classic Vines pubkey in Editor's Picks", () {
      // Given: Mix of Classic Vines and regular videos
      final classicVineVideos = List.generate(
        5,
        (index) => VideoEvent(
          id: 'classic_$index',
          pubkey: AppConstants.classicVinesPubkey,
          createdAt: DateTime.now()
              .subtract(Duration(days: index))
              .millisecondsSinceEpoch,
          content: 'Classic Vine $index',
          timestamp: DateTime.now().subtract(Duration(days: index)),
          videoUrl: 'https://example.com/classic_$index.mp4',
        ),
      );

      final regularVideos = List.generate(
        3,
        (index) => VideoEvent(
          id: 'regular_$index',
          pubkey: 'other_pubkey_$index',
          createdAt: DateTime.now()
              .subtract(Duration(hours: index))
              .millisecondsSinceEpoch,
          content: 'Regular video $index',
          timestamp: DateTime.now().subtract(Duration(hours: index)),
          videoUrl: 'https://example.com/regular_$index.mp4',
        ),
      );

      final allVideos = [...classicVineVideos, ...regularVideos];
      when(mockVideoEventService.videoEvents).thenReturn(allVideos);

      final curationService = CurationService(
        nostrService: mockNostrService,
        videoEventService: mockVideoEventService,
        socialService: mockSocialService,
        authService: mockAuthService,
      );

      // When: Getting Editor's Picks
      final editorsPicks = curationService.getVideosForSetType(
        CurationSetType.editorsPicks,
      );

      // Then: Should contain only Classic Vines videos
      expect(editorsPicks.length, equals(5));
      expect(
        editorsPicks.every(
          (video) => video.pubkey == AppConstants.classicVinesPubkey,
        ),
        isTrue,
      );
      expect(
        editorsPicks.every((video) => video.id.startsWith('classic_')),
        isTrue,
      );

      curationService.dispose();
    });

    test("should randomize Classic Vines order in Editor's Picks", () {
      // Given: Multiple Classic Vines videos
      final classicVineVideos = List.generate(
        10,
        (index) => VideoEvent(
          id: 'classic_$index',
          pubkey: AppConstants.classicVinesPubkey,
          createdAt: DateTime.now()
              .subtract(Duration(days: index))
              .millisecondsSinceEpoch,
          content: 'Classic Vine $index',
          timestamp: DateTime.now().subtract(Duration(days: index)),
          videoUrl: 'https://example.com/classic_$index.mp4',
        ),
      );

      when(mockVideoEventService.videoEvents).thenReturn(classicVineVideos);

      // When: Creating multiple CurationService instances
      final orders = <List<String>>[];
      for (var i = 0; i < 5; i++) {
        final service = CurationService(
          nostrService: mockNostrService,
          videoEventService: mockVideoEventService,
          socialService: mockSocialService,
          authService: mockAuthService,
        );

        final editorsPicks = service.getVideosForSetType(
          CurationSetType.editorsPicks,
        );
        orders.add(editorsPicks.map((v) => v.id).toList());

        service.dispose();
      }

      // Then: At least one order should be different (high probability with 10 items)
      final firstOrder = orders.first;
      final hasDifferentOrder = orders.any(
        (order) =>
            order.length == firstOrder.length &&
            !order.asMap().entries.every(
              (entry) => entry.value == firstOrder[entry.key],
            ),
      );

      expect(
        hasDifferentOrder,
        isTrue,
        reason: 'Videos should be in random order, not chronological',
      );
    });

    test('should show default video when no Classic Vines available', () {
      // Given: No Classic Vines videos
      final regularVideos = List.generate(
        3,
        (index) => VideoEvent(
          id: 'regular_$index',
          pubkey: 'other_pubkey_$index',
          createdAt: DateTime.now()
              .subtract(Duration(hours: index))
              .millisecondsSinceEpoch,
          content: 'Regular video $index',
          timestamp: DateTime.now().subtract(Duration(hours: index)),
          videoUrl: 'https://example.com/regular_$index.mp4',
        ),
      );

      when(mockVideoEventService.videoEvents).thenReturn(regularVideos);

      final curationService = CurationService(
        nostrService: mockNostrService,
        videoEventService: mockVideoEventService,
        socialService: mockSocialService,
        authService: mockAuthService,
      );

      // When: Getting Editor's Picks
      final editorsPicks = curationService.getVideosForSetType(
        CurationSetType.editorsPicks,
      );

      // Then: Should contain at least one video (default fallback)
      expect(editorsPicks.isNotEmpty, isTrue);
      expect(editorsPicks.first.id, isNotEmpty);

      curationService.dispose();
    });

    test('should handle empty video list gracefully', () {
      // Given: No videos at all
      when(mockVideoEventService.videoEvents).thenReturn([]);

      final curationService = CurationService(
        nostrService: mockNostrService,
        videoEventService: mockVideoEventService,
        socialService: mockSocialService,
        authService: mockAuthService,
      );

      // When: Getting Editor's Picks
      final editorsPicks = curationService.getVideosForSetType(
        CurationSetType.editorsPicks,
      );

      // Then: Should still return at least the default video
      expect(editorsPicks.isNotEmpty, isTrue);
      expect(editorsPicks.first.title, isNotNull);

      curationService.dispose();
    });
  });
}
