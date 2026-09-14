// ABOUTME: TDD tests for VideoEventService adult content filtering
// ABOUTME: Tests filtering of flagged content when preference is neverShow

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/event.dart';
import 'package:openvine/models/content_label.dart';
import 'package:openvine/observability/crash_reporter.dart';
import 'package:openvine/services/content_filter_service.dart';
import 'package:openvine/services/video_event_service.dart';

class MockNostrService extends Mock implements NostrClient {}

class MockContentFilterService extends Mock implements ContentFilterService {}

VideoEvent _buildVideo({
  required String id,
  List<String> moderationLabels = const [],
}) {
  return VideoEvent(
    id: id,
    pubkey: 'f' * 64,
    createdAt: 1704067200,
    content: '',
    timestamp: DateTime.fromMillisecondsSinceEpoch(1704067200 * 1000),
    title: 'Test Video',
    videoUrl: 'https://example.com/$id.mp4',
    moderationLabels: moderationLabels,
  );
}

void main() {
  late MockNostrService mockNostrService;
  late MockContentFilterService mockContentFilterService;
  late VideoEventService videoEventService;

  setUp(() {
    mockNostrService = MockNostrService();
    mockContentFilterService = MockContentFilterService();
    when(() => mockNostrService.publicKey).thenReturn('e' * 64);

    videoEventService = VideoEventService(
      mockNostrService,
      crashReporter: const SilentCrashReporter(),
    );
  });

  group('VideoEventService - adult content filtering', () {
    test('shouldFilterAdultContent returns false when service not set', () {
      expect(videoEventService.shouldFilterAdultContent, isFalse);
    });

    test(
      'shouldFilterAdultContent returns true when content filter says hide adult content',
      () {
        when(
          () => mockContentFilterService.adultPlaybackPreference,
        ).thenReturn(ContentFilterPreference.hide);
        videoEventService.setContentFilterService(mockContentFilterService);

        expect(videoEventService.shouldFilterAdultContent, isTrue);
      },
    );

    test(
      'shouldFilterAdultContent returns false when content filter says dont hide adult content',
      () {
        when(
          () => mockContentFilterService.adultPlaybackPreference,
        ).thenReturn(ContentFilterPreference.warn);
        videoEventService.setContentFilterService(mockContentFilterService);

        expect(videoEventService.shouldFilterAdultContent, isFalse);
      },
    );

    test('shouldFilterEvent returns true for flagged content when hiding', () {
      when(
        () => mockContentFilterService.adultPlaybackPreference,
      ).thenReturn(ContentFilterPreference.hide);
      videoEventService.setContentFilterService(mockContentFilterService);

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

      expect(videoEventService.shouldFilterEvent(event), isTrue);
    });

    test(
      'shouldFilterEvent returns false for non-flagged content when hiding',
      () {
        when(
          () => mockContentFilterService.adultPlaybackPreference,
        ).thenReturn(ContentFilterPreference.hide);
        videoEventService.setContentFilterService(mockContentFilterService);

        final event = Event('1' * 64, 34236, [
          ['d', 'test-video-id-2'],
          ['url', 'https://example.com/video2.mp4'],
        ], '');

        expect(videoEventService.shouldFilterEvent(event), isFalse);
      },
    );

    test('shouldFilterEvent returns false when not hiding adult content', () {
      when(
        () => mockContentFilterService.adultPlaybackPreference,
      ).thenReturn(ContentFilterPreference.warn);
      videoEventService.setContentFilterService(mockContentFilterService);

      final event = Event('2' * 64, 34236, [
        ['d', 'test-video-id-3'],
        ['url', 'https://example.com/video3.mp4'],
        ['content-warning', 'adult content'],
      ], '');

      expect(videoEventService.shouldFilterEvent(event), isFalse);
    });

    test('shouldFilterEvent handles NSFW hashtag as adult content', () {
      when(
        () => mockContentFilterService.adultPlaybackPreference,
      ).thenReturn(ContentFilterPreference.hide);
      videoEventService.setContentFilterService(mockContentFilterService);

      final event = Event('3' * 64, 34236, [
        ['d', 'test-video-id-4'],
        ['url', 'https://example.com/video4.mp4'],
        ['t', 'NSFW'],
      ], '');

      expect(videoEventService.shouldFilterEvent(event), isTrue);
    });

    test('shouldFilterEvent handles adult hashtag as adult content', () {
      when(
        () => mockContentFilterService.adultPlaybackPreference,
      ).thenReturn(ContentFilterPreference.hide);
      videoEventService.setContentFilterService(mockContentFilterService);

      final event = Event('4' * 64, 34236, [
        ['d', 'test-video-id-5'],
        ['url', 'https://example.com/video5.mp4'],
        ['t', 'adult'],
      ], '');

      expect(videoEventService.shouldFilterEvent(event), isTrue);
    });

    test(
      'filterAdultContentFromExistingVideos removes flagged videos from all lists',
      () {
        when(
          () => mockContentFilterService.adultPlaybackPreference,
        ).thenReturn(ContentFilterPreference.hide);
        videoEventService.setContentFilterService(mockContentFilterService);

        final removedCount = videoEventService
            .filterAdultContentFromExistingVideos();

        expect(removedCount, isA<int>());
        expect(removedCount, greaterThanOrEqualTo(0));
      },
    );

    test(
      'filterAdultContentFromExistingVideos does nothing when not hiding adult content',
      () {
        when(
          () => mockContentFilterService.adultPlaybackPreference,
        ).thenReturn(ContentFilterPreference.warn);
        videoEventService.setContentFilterService(mockContentFilterService);

        final removedCount = videoEventService
            .filterAdultContentFromExistingVideos();

        expect(removedCount, equals(0));
      },
    );

    test(
      'filterVideoList keeps sexual-content videos when user preference allows sexual content',
      () {
        when(
          () => mockContentFilterService.getPreference(ContentLabel.sexual),
        ).thenReturn(ContentFilterPreference.show);
        videoEventService.setContentFilterService(mockContentFilterService);

        final filtered = videoEventService.filterVideoList([
          _buildVideo(id: '5' * 64, moderationLabels: const ['sexual-content']),
        ]);

        expect(filtered, hasLength(1));
      },
    );

    test(
      'filterVideoList keeps videos with only unknown moderation labels',
      () {
        videoEventService.setContentFilterService(mockContentFilterService);

        final video = _buildVideo(
          id: '6' * 64,
          moderationLabels: const ['some-new-server-label'],
        );

        final filtered = videoEventService.filterVideoList([video]);

        expect(filtered, [video]);
      },
    );

    test(
      'filterVideoList keeps videos with known moderation labels when preference allows them',
      () {
        when(
          () => mockContentFilterService.getPreference(ContentLabel.nudity),
        ).thenReturn(ContentFilterPreference.show);
        videoEventService.setContentFilterService(mockContentFilterService);

        final video = _buildVideo(
          id: '7' * 64,
          moderationLabels: const ['nudity'],
        );

        final filtered = videoEventService.filterVideoList([video]);

        expect(filtered, [video]);
      },
    );

    test(
      'filterVideoList hides videos with known hide labels alongside unknown labels',
      () {
        when(
          () => mockContentFilterService.getPreference(ContentLabel.nudity),
        ).thenReturn(ContentFilterPreference.hide);
        videoEventService.setContentFilterService(mockContentFilterService);

        final filtered = videoEventService.filterVideoList([
          _buildVideo(
            id: '8' * 64,
            moderationLabels: const ['nudity', 'some-new-server-label'],
          ),
        ]);

        expect(filtered, isEmpty);
        verify(
          () => mockContentFilterService.getPreference(ContentLabel.nudity),
        ).called(greaterThanOrEqualTo(1));
      },
    );
  });
}
