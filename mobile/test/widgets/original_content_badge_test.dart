// ABOUTME: Tests for Original Content badge display logic
// ABOUTME: Verifies badge shows for original content (non-reposts) but not for reposts or vintage vines

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nostr_sdk/event.dart';
import 'package:openvine/models/video_event.dart';
import 'package:openvine/widgets/proofmode_badge.dart';
import 'package:openvine/widgets/proofmode_badge_row.dart';

void main() {
  group('Original Content Badge Tests (TDD)', () {
    testWidgets('OriginalContentBadge renders with correct styling', (
      WidgetTester tester,
    ) async {
      // Arrange & Act
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: OriginalContentBadge(size: BadgeSize.medium)),
        ),
      );

      // Assert - verify badge displays "Original" text
      expect(find.text('Original'), findsOneWidget);

      // Assert - verify check_circle icon is present
      expect(find.byIcon(Icons.check_circle), findsOneWidget);
    });

    test('VideoEvent.isOriginalContent returns true for non-repost', () {
      // Arrange - Create a non-repost video event
      final event = Event.fromJson({
        'id': 'test1234567890abcdef',
        'pubkey': 'pubkey1234567890abcdef',
        'created_at': 1234567890,
        'kind': 34236,
        'content': 'Test video',
        'tags': [
          ['url', 'https://example.com/video.mp4'],
        ],
        'sig': 'sig1234567890abcdef',
      });

      final videoEvent = VideoEvent.fromNostrEvent(event);

      // Assert
      expect(videoEvent.isOriginalContent, true);
      expect(videoEvent.isRepost, false);
    });

    test(
      'VideoEvent.shouldShowOriginalBadge returns true for original user content',
      () {
        // Arrange - Create a normal user video (no repost, no vintage vine metrics)
        final event = Event.fromJson({
          'id': 'test1234567890abcdef',
          'pubkey': 'pubkey1234567890abcdef',
          'created_at': 1234567890,
          'kind': 34236,
          'content': 'Test video',
          'tags': [
            ['url', 'https://example.com/video.mp4'],
          ],
          'sig': 'sig1234567890abcdef',
        });

        final videoEvent = VideoEvent.fromNostrEvent(event);

        // Assert - should show Original badge (not a repost, not a vintage vine)
        expect(videoEvent.shouldShowOriginalBadge, true);
      },
    );

    test('VideoEvent.shouldShowOriginalBadge returns false for reposts', () {
      // Arrange - Create a repost event
      final originalEvent = Event.fromJson({
        'id': 'original1234567890abcdef',
        'pubkey': 'pubkey1234567890abcdef',
        'created_at': 1234567890,
        'kind': 34236,
        'content': 'Original video',
        'tags': [
          ['url', 'https://example.com/video.mp4'],
        ],
        'sig': 'sig1234567890abcdef',
      });

      final videoEvent = VideoEvent.createRepostEvent(
        originalEvent: VideoEvent.fromNostrEvent(originalEvent),
        repostEventId: 'repost1234567890abcdef',
        reposterPubkey: 'reposter1234567890abcdef',
        repostedAt: DateTime.now(),
      );

      // Assert - should NOT show Original badge (this is a repost)
      expect(videoEvent.shouldShowOriginalBadge, false);
      expect(videoEvent.isRepost, true);
    });

    test(
      'VideoEvent.shouldShowOriginalBadge returns false for vintage vines',
      () {
        // Arrange - Create a vintage recovered vine with loop count
        final event = Event.fromJson({
          'id': 'vintage1234567890abcdef',
          'pubkey': 'pubkey1234567890abcdef',
          'created_at': 1234567890,
          'kind': 34236,
          'content': 'Vintage vine',
          'tags': [
            ['url', 'https://example.com/video.mp4'],
            ['loops', '10000'], // Has loop count = vintage vine
          ],
          'sig': 'sig1234567890abcdef',
        });

        final videoEvent = VideoEvent.fromNostrEvent(event);

        // Assert - should NOT show Original badge (vintage vines get their own badge)
        expect(videoEvent.shouldShowOriginalBadge, false);
        expect(videoEvent.isOriginalVine, true);
      },
    );

    testWidgets(
      'ProofModeBadgeRow shows OriginalContentBadge for original user content',
      (WidgetTester tester) async {
        // Arrange - Create original user video
        final event = Event.fromJson({
          'id': 'test1234567890abcdef',
          'pubkey': 'pubkey1234567890abcdef',
          'created_at': 1234567890,
          'kind': 34236,
          'content': 'Test video',
          'tags': [
            ['url', 'https://example.com/video.mp4'],
          ],
          'sig': 'sig1234567890abcdef',
        });

        final videoEvent = VideoEvent.fromNostrEvent(event);

        // Act
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(body: ProofModeBadgeRow(video: videoEvent)),
          ),
        );

        // Assert - Original badge should be visible
        expect(find.text('Original'), findsOneWidget);
        expect(find.byType(OriginalContentBadge), findsOneWidget);
      },
    );

    testWidgets(
      'ProofModeBadgeRow does NOT show OriginalContentBadge for reposts',
      (WidgetTester tester) async {
        // Arrange - Create repost
        final originalEvent = Event.fromJson({
          'id': 'original1234567890abcdef',
          'pubkey': 'pubkey1234567890abcdef',
          'created_at': 1234567890,
          'kind': 34236,
          'content': 'Original video',
          'tags': [
            ['url', 'https://example.com/video.mp4'],
          ],
          'sig': 'sig1234567890abcdef',
        });

        final videoEvent = VideoEvent.createRepostEvent(
          originalEvent: VideoEvent.fromNostrEvent(originalEvent),
          repostEventId: 'repost1234567890abcdef',
          reposterPubkey: 'reposter1234567890abcdef',
          repostedAt: DateTime.now(),
        );

        // Act
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(body: ProofModeBadgeRow(video: videoEvent)),
          ),
        );

        // Assert - Original badge should NOT be visible
        expect(find.byType(OriginalContentBadge), findsNothing);
      },
    );

    testWidgets(
      'ProofModeBadgeRow does NOT show OriginalContentBadge for vintage vines',
      (WidgetTester tester) async {
        // Arrange - Create vintage vine
        final event = Event.fromJson({
          'id': 'vintage1234567890abcdef',
          'pubkey': 'pubkey1234567890abcdef',
          'created_at': 1234567890,
          'kind': 34236,
          'content': 'Vintage vine',
          'tags': [
            ['url', 'https://example.com/video.mp4'],
            ['loops', '10000'],
          ],
          'sig': 'sig1234567890abcdef',
        });

        final videoEvent = VideoEvent.fromNostrEvent(event);

        // Act
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(body: ProofModeBadgeRow(video: videoEvent)),
          ),
        );

        // Assert - Original Content badge should NOT be visible (vintage vines show their own badge)
        expect(find.byType(OriginalContentBadge), findsNothing);

        // But OriginalVineBadge should be visible
        expect(find.byType(OriginalVineBadge), findsOneWidget);
      },
    );
  });
}
