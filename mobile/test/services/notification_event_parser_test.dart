// ABOUTME: Tests for NotificationEventParser - converts Nostr events to notifications
// ABOUTME: Pure business logic tests without service dependencies

import 'package:flutter_test/flutter_test.dart';
import 'package:nostr_sdk/event.dart';
import 'package:openvine/models/notification_model.dart';
import 'package:openvine/models/user_profile.dart';
import 'package:openvine/models/video_event.dart';
import 'package:openvine/services/notification_event_parser.dart';

void main() {
  group('NotificationEventParser', () {
    late NotificationEventParser parser;

    setUp(() {
      parser = NotificationEventParser();
    });

    group('parseReactionEvent', () {
      test('returns null for non-like reactions', () {
        // Arrange
        final event = Event(
          'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
          7,
          [
            ['e', 'video123'],
          ],
          '-', // Not a like
        );

        // Act
        final result = parser.parseReactionEvent(
          event,
          actorProfile: null,
          videoEvent: null,
        );

        // Assert
        expect(result, isNull);
      });

      test('returns null when no video event ID exists', () {
        // Arrange
        final event = Event(
          'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
          7,
          [], // No tags
          '+',
        );

        // Act
        final result = parser.parseReactionEvent(
          event,
          actorProfile: null,
          videoEvent: null,
        );

        // Assert
        expect(result, isNull);
      });

      test('creates like notification with all fields', () {
        // Arrange
        final actorPubkey =
            'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
        final event = Event(
          actorPubkey,
          7,
          [
            ['e', 'video123'],
          ],
          '+',
          createdAt: 1700000000,
        );

        final profile = UserProfile(
          pubkey: actorPubkey,
          rawData: {},
          createdAt: DateTime.now(),
          eventId: 'profile1',
          name: 'Alice',
          picture: 'https://example.com/alice.jpg',
        );

        final video = VideoEvent.fromNostrEvent(
          Event(
            'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb',
            34236,
            [
              ['url', 'https://example.com/video.mp4'],
              ['thumb', 'https://example.com/thumb.jpg'],
            ],
            'Test video',
          ),
        );

        // Act
        final result = parser.parseReactionEvent(
          event,
          actorProfile: profile,
          videoEvent: video,
        );

        // Assert
        expect(result, isNotNull);
        expect(result!.type, NotificationType.like);
        expect(result.actorPubkey, actorPubkey);
        expect(result.actorName, 'Alice');
        expect(result.actorPictureUrl, 'https://example.com/alice.jpg');
        expect(result.message, 'Alice liked your video');
        expect(result.targetEventId, 'video123');
        expect(result.targetVideoUrl, video.videoUrl);
        expect(result.targetVideoThumbnail, video.thumbnailUrl);
        expect(
          result.timestamp,
          DateTime.fromMillisecondsSinceEpoch(1700000000 * 1000),
        );
      });

      test('uses "Unknown user" when profile is null', () {
        // Arrange
        final event = Event(
          'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
          7,
          [
            ['e', 'video123'],
          ],
          '+',
        );

        // Act
        final result = parser.parseReactionEvent(
          event,
          actorProfile: null,
          videoEvent: null,
        );

        // Assert
        expect(result, isNotNull);
        expect(result!.actorName, 'Unknown user');
        expect(result.message, 'Unknown user liked your video');
      });
    });

    group('parseCommentEvent', () {
      test('returns null when no video event ID exists', () {
        // Arrange
        final event = Event(
          'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
          1,
          [], // No tags
          'Great video!',
        );

        // Act
        final result = parser.parseCommentEvent(
          event,
          actorProfile: null,
          videoEvent: null,
        );

        // Assert
        expect(result, isNull);
      });

      test('creates comment notification with metadata', () {
        // Arrange
        final actorPubkey =
            'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
        final event = Event(
          actorPubkey,
          1,
          [
            ['e', 'video456'],
          ],
          'Great video!',
          createdAt: 1700000000,
        );

        final profile = UserProfile(
          pubkey: actorPubkey,
          rawData: {},
          createdAt: DateTime.now(),
          eventId: 'profile1',
          name: 'Bob',
        );

        // Act
        final result = parser.parseCommentEvent(
          event,
          actorProfile: profile,
          videoEvent: null,
        );

        // Assert
        expect(result, isNotNull);
        expect(result!.type, NotificationType.comment);
        expect(result.actorName, 'Bob');
        expect(result.message, 'Bob commented on your video');
        expect(result.targetEventId, 'video456');
        expect(result.metadata?['comment'], 'Great video!');
      });
    });

    group('parseFollowEvent', () {
      test('creates follow notification without video info', () {
        // Arrange
        final actorPubkey =
            'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
        final event = Event(actorPubkey, 3, [], '', createdAt: 1700000000);

        final profile = UserProfile(
          pubkey: actorPubkey,
          rawData: {},
          createdAt: DateTime.now(),
          eventId: 'profile1',
          name: 'Charlie',
        );

        // Act
        final result = parser.parseFollowEvent(event, actorProfile: profile);

        // Assert
        expect(result, isNotNull);
        expect(result.type, NotificationType.follow);
        expect(result.actorName, 'Charlie');
        expect(result.message, 'Charlie started following you');
        expect(result.targetEventId, isNull);
      });
    });

    group('parseMentionEvent', () {
      test('creates mention notification with text metadata', () {
        // Arrange
        final actorPubkey =
            'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
        final event = Event(
          actorPubkey,
          1,
          [],
          'Hey @user check this out!',
          createdAt: 1700000000,
        );

        final profile = UserProfile(
          pubkey: actorPubkey,
          rawData: {},
          createdAt: DateTime.now(),
          eventId: 'profile1',
          name: 'Dave',
        );

        // Act
        final result = parser.parseMentionEvent(event, actorProfile: profile);

        // Assert
        expect(result, isNotNull);
        expect(result.type, NotificationType.mention);
        expect(result.actorName, 'Dave');
        expect(result.message, 'Dave mentioned you');
        expect(result.metadata?['text'], 'Hey @user check this out!');
      });
    });

    group('parseRepostEvent', () {
      test('returns null when no video event ID exists', () {
        // Arrange
        final event = Event(
          'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
          6,
          [], // No tags
          '',
        );

        // Act
        final result = parser.parseRepostEvent(
          event,
          actorProfile: null,
          videoEvent: null,
        );

        // Assert
        expect(result, isNull);
      });

      test('creates repost notification', () {
        // Arrange
        final actorPubkey =
            'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
        final event = Event(
          actorPubkey,
          6,
          [
            ['e', 'video789'],
          ],
          '',
          createdAt: 1700000000,
        );

        final profile = UserProfile(
          pubkey: actorPubkey,
          rawData: {},
          createdAt: DateTime.now(),
          eventId: 'profile1',
          name: 'Eve',
        );

        // Act
        final result = parser.parseRepostEvent(
          event,
          actorProfile: profile,
          videoEvent: null,
        );

        // Assert
        expect(result, isNotNull);
        expect(result!.type, NotificationType.repost);
        expect(result.actorName, 'Eve');
        expect(result.message, 'Eve reposted your video');
        expect(result.targetEventId, 'video789');
      });
    });
  });
}
