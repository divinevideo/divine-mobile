// ABOUTME: Simplified characterization tests for NotificationServiceEnhanced
// ABOUTME: Tests core behavior patterns without complex model setup

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:nostr_sdk/event.dart';
import 'package:nostr_sdk/filter.dart';
import 'package:openvine/models/notification_model.dart';
import 'package:openvine/models/user_profile.dart';
import 'package:openvine/models/video_event.dart';
import 'package:openvine/services/notification_service_enhanced.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:openvine/services/user_profile_service.dart';
import 'package:openvine/services/video_event_service.dart';
import '../../helpers/real_integration_test_helper.dart';

/// Fake NostrService for testing
class FakeNostrService implements NostrClient {
  final _eventController = StreamController<Event>.broadcast();
  String? _pubkey;

  void injectEvent(Event event) => _eventController.add(event);

  @override
  Stream<Event> subscribe(
    List<Filter> filters, {
    String? subscriptionId,
    List<String>? tempRelays,
    List<String>? targetRelays,
    List<int> relayTypes = const [],
    bool sendAfterAuth = false,
    void Function()? onEose,
  }) => _eventController.stream;

  @override
  String get publicKey => _pubkey ?? '';

  @override
  bool get hasKeys => _pubkey != null;

  void setPublicKey(String pubkey) => _pubkey = pubkey;

  @override
  bool get isInitialized => true;

  @override
  bool get isDisposed => false;

  @override
  Future<void> initialize({List<String>? customRelays}) async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Fake UserProfileService
class FakeUserProfileService implements UserProfileService {
  final Map<String, UserProfile> _profiles = {};

  void addProfile(String pubkey, UserProfile profile) {
    _profiles[pubkey] = profile;
  }

  @override
  Future<UserProfile?> fetchProfile(
    String pubkey, {
    bool forceRefresh = false,
  }) async => _profiles[pubkey];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Fake VideoEventService
class FakeVideoEventService implements VideoEventService {
  final Map<String, VideoEvent> _videos = {};

  void addVideo(String eventId, VideoEvent video) {
    _videos[eventId] = video;
  }

  @override
  VideoEvent? getVideoEventById(String eventId) => _videos[eventId];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('NotificationServiceEnhanced - Basic Behavior', () {
    late NotificationServiceEnhanced service;
    late FakeNostrService fakeNostrService;
    late FakeUserProfileService fakeProfileService;
    late FakeVideoEventService fakeVideoService;

    setUpAll(() async {
      // Setup test environment with platform channel mocks
      await RealIntegrationTestHelper.setupTestEnvironment();
      // Initialize Hive for testing
      await Hive.initFlutter('test_notification_simple');
    });

    setUp(() async {
      service = NotificationServiceEnhanced.instance;
      fakeNostrService = FakeNostrService();
      fakeProfileService = FakeUserProfileService();
      fakeVideoService = FakeVideoEventService();

      fakeNostrService.setPublicKey('user123');

      await service.initialize(
        nostrService: fakeNostrService,
        profileService: fakeProfileService,
        videoService: fakeVideoService,
      );
    });

    tearDown(() async {
      service.dispose();
      try {
        await Hive.deleteBoxFromDisk('notifications');
      } catch (e) {
        // Box might not exist, that's fine
      }
    });

    test('initialization sets up service correctly', () {
      expect(service.hasPermissions, isTrue); // Simulated permission grant
      expect(service.notifications, isEmpty);
      expect(service.unreadCount, 0);
    });

    test('reaction event with "+" creates like notification', () async {
      // Arrange
      final actorPubkey =
          '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef';
      final videoEventId = 'video123';

      // Add profile (use factory method)
      final profileEvent = Event(
        actorPubkey,
        0,
        [],
        '{"name":"TestUser"}',
        createdAt: 1700000000,
      );
      fakeProfileService.addProfile(
        actorPubkey,
        UserProfile.fromNostrEvent(profileEvent),
      );

      // Add video (use factory method)
      final videoNostrEvent = Event(
        'user123',
        34236,
        [
          ['url', 'https://example.com/video.mp4'],
        ],
        'Test video',
        createdAt: 1700000000,
      );
      fakeVideoService.addVideo(
        videoEventId,
        VideoEvent.fromNostrEvent(videoNostrEvent),
      );

      // Create reaction event
      final reactionEvent = Event(
        actorPubkey,
        7,
        [
          ['e', videoEventId],
        ],
        '+',
        createdAt: 1700000000,
      );

      // Act
      fakeNostrService.injectEvent(reactionEvent);
      await Future.delayed(Duration(milliseconds: 200)); // Let handlers run

      // Assert
      expect(service.notifications.length, 1);
      final notification = service.notifications.first;
      expect(notification.type, NotificationType.like);
      expect(notification.actorPubkey, actorPubkey);
      expect(notification.message, contains('liked your video'));
    });

    test('reaction event with non-"+" content is ignored', () async {
      // Arrange
      final reactionEvent = Event(
        '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef',
        7,
        [
          ['e', 'video123'],
        ],
        '-', // Not a like
        createdAt: 1700000000,
      );

      // Act
      fakeNostrService.injectEvent(reactionEvent);
      await Future.delayed(Duration(milliseconds: 200));

      // Assert
      expect(service.notifications, isEmpty);
    });

    test('reaction event without video ID tag is ignored', () async {
      // Arrange
      final reactionEvent = Event(
        '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef',
        7,
        [], // No 'e' tag
        '+',
        createdAt: 1700000000,
      );

      // Act
      fakeNostrService.injectEvent(reactionEvent);
      await Future.delayed(Duration(milliseconds: 200));

      // Assert
      expect(service.notifications, isEmpty);
    });

    test('comment event creates comment notification', () async {
      // Arrange
      final actorPubkey =
          '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef';
      final videoEventId = 'video_comment';

      // Add profile
      final profileEvent = Event(
        actorPubkey,
        0,
        [],
        '{"name":"Commenter"}',
        createdAt: 1700000000,
      );
      fakeProfileService.addProfile(
        actorPubkey,
        UserProfile.fromNostrEvent(profileEvent),
      );

      // Add video
      final videoNostrEvent = Event(
        'user123',
        34236,
        [
          ['url', 'https://example.com/video.mp4'],
        ],
        'Test video',
        createdAt: 1700000000,
      );
      fakeVideoService.addVideo(
        videoEventId,
        VideoEvent.fromNostrEvent(videoNostrEvent),
      );

      // Create comment event
      final commentEvent = Event(
        actorPubkey,
        1,
        [
          ['e', videoEventId],
        ],
        'Great video!',
        createdAt: 1700000000,
      );

      // Act
      fakeNostrService.injectEvent(commentEvent);
      await Future.delayed(Duration(milliseconds: 200));

      // Assert
      expect(service.notifications.length, 1);
      final notification = service.notifications.first;
      expect(notification.type, NotificationType.comment);
      expect(notification.message, contains('commented on your video'));
      expect(notification.metadata?['comment'], 'Great video!');
    });

    test('follow event creates follow notification', () async {
      // Arrange
      final actorPubkey =
          '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef';

      // Add profile
      final profileEvent = Event(
        actorPubkey,
        0,
        [],
        '{"name":"Follower"}',
        createdAt: 1700000000,
      );
      fakeProfileService.addProfile(
        actorPubkey,
        UserProfile.fromNostrEvent(profileEvent),
      );

      // Create follow event
      final followEvent = Event(actorPubkey, 3, [], '', createdAt: 1700000000);

      // Act
      fakeNostrService.injectEvent(followEvent);
      await Future.delayed(Duration(milliseconds: 200));

      // Assert
      expect(service.notifications.length, 1);
      final notification = service.notifications.first;
      expect(notification.type, NotificationType.follow);
      expect(notification.message, contains('started following you'));
    });

    test('duplicate notifications are not added', () async {
      // Arrange
      final actorPubkey =
          '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef';

      // Add profile
      final profileEvent = Event(
        actorPubkey,
        0,
        [],
        '{"name":"TestUser"}',
        createdAt: 1700000000,
      );
      fakeProfileService.addProfile(
        actorPubkey,
        UserProfile.fromNostrEvent(profileEvent),
      );

      // Create follow event with same ID
      final followEvent = Event(actorPubkey, 3, [], '', createdAt: 1700000000);

      // Act - inject same event twice
      fakeNostrService.injectEvent(followEvent);
      await Future.delayed(Duration(milliseconds: 200));
      fakeNostrService.injectEvent(followEvent);
      await Future.delayed(Duration(milliseconds: 200));

      // Assert - only one notification
      expect(service.notifications.length, 1);
    });

    test('markAsRead marks notification as read', () async {
      // Arrange
      final actorPubkey =
          '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef';

      final profileEvent = Event(
        actorPubkey,
        0,
        [],
        '{"name":"TestUser"}',
        createdAt: 1700000000,
      );
      fakeProfileService.addProfile(
        actorPubkey,
        UserProfile.fromNostrEvent(profileEvent),
      );

      final followEvent = Event(actorPubkey, 3, [], '', createdAt: 1700000000);

      fakeNostrService.injectEvent(followEvent);
      await Future.delayed(Duration(milliseconds: 200));

      expect(
        service.notifications,
        isNotEmpty,
        reason: 'Should have at least one notification after follow event',
      );
      final notificationId = service.notifications.first.id;

      // Act
      await service.markAsRead(notificationId);

      // Assert
      expect(
        service.notifications,
        isNotEmpty,
        reason: 'Notifications should still exist after marking as read',
      );
      expect(service.notifications.first.isRead, isTrue);
      expect(service.unreadCount, 0);
    });

    test('markAllAsRead marks all notifications as read', () async {
      // Arrange - create multiple notifications
      final actorPubkey =
          '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef';

      final profileEvent = Event(
        actorPubkey,
        0,
        [],
        '{"name":"TestUser"}',
        createdAt: 1700000000,
      );
      fakeProfileService.addProfile(
        actorPubkey,
        UserProfile.fromNostrEvent(profileEvent),
      );

      // Create two different follow events
      final followEvent1 = Event(actorPubkey, 3, [], '', createdAt: 1700000000);

      final followEvent2 = Event(
        actorPubkey,
        3,
        [],
        '',
        createdAt: 1700000001, // Different timestamp
      );

      fakeNostrService.injectEvent(followEvent1);
      await Future.delayed(Duration(milliseconds: 100));
      fakeNostrService.injectEvent(followEvent2);
      await Future.delayed(Duration(milliseconds: 100));

      expect(service.notifications.length, 2);
      expect(service.unreadCount, 2);

      // Act
      await service.markAllAsRead();

      // Assert
      expect(service.notifications.every((n) => n.isRead), isTrue);
      expect(service.unreadCount, 0);
    });

    test('clearAll removes all notifications', () async {
      // Arrange
      final actorPubkey =
          '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef';

      final profileEvent = Event(
        actorPubkey,
        0,
        [],
        '{"name":"TestUser"}',
        createdAt: 1700000000,
      );
      fakeProfileService.addProfile(
        actorPubkey,
        UserProfile.fromNostrEvent(profileEvent),
      );

      final followEvent = Event(actorPubkey, 3, [], '', createdAt: 1700000000);

      fakeNostrService.injectEvent(followEvent);
      await Future.delayed(Duration(milliseconds: 200));

      expect(service.notifications, isNotEmpty);

      // Act
      await service.clearAll();

      // Assert
      expect(service.notifications, isEmpty);
      expect(service.unreadCount, 0);
    });

    test(
      'actor name resolution priority: name > displayName > nip05 > Unknown user',
      () async {
        // Test 1: name is used
        final pubkey1 =
            '1111111111111111111111111111111111111111111111111111111111111111';
        final profileEvent1 = Event(
          pubkey1,
          0,
          [],
          '{"name":"NameValue","display_name":"DisplayValue","nip05":"nip@example.com"}',
          createdAt: 1700000000,
        );
        fakeProfileService.addProfile(
          pubkey1,
          UserProfile.fromNostrEvent(profileEvent1),
        );

        final followEvent1 = Event(pubkey1, 3, [], '', createdAt: 1700000000);
        fakeNostrService.injectEvent(followEvent1);
        await Future.delayed(Duration(milliseconds: 200));

        expect(
          service.notifications,
          isNotEmpty,
          reason: 'Should have notification for first follow event',
        );
        expect(service.notifications.last.actorName, 'NameValue');

        // Test 2: displayName is used when name is missing
        final pubkey2 =
            '2222222222222222222222222222222222222222222222222222222222222222';
        final profileEvent2 = Event(
          pubkey2,
          0,
          [],
          '{"display_name":"DisplayValue","nip05":"nip@example.com"}',
          createdAt: 1700000000,
        );
        fakeProfileService.addProfile(
          pubkey2,
          UserProfile.fromNostrEvent(profileEvent2),
        );

        final followEvent2 = Event(pubkey2, 3, [], '', createdAt: 1700000001);
        fakeNostrService.injectEvent(followEvent2);
        await Future.delayed(Duration(milliseconds: 200));

        expect(service.notifications.last.actorName, 'DisplayValue');

        // Test 3: nip05 username is used when name and displayName are missing
        final pubkey3 =
            '3333333333333333333333333333333333333333333333333333333333333333';
        final profileEvent3 = Event(
          pubkey3,
          0,
          [],
          '{"nip05":"username@example.com"}',
          createdAt: 1700000000,
        );
        fakeProfileService.addProfile(
          pubkey3,
          UserProfile.fromNostrEvent(profileEvent3),
        );

        final followEvent3 = Event(pubkey3, 3, [], '', createdAt: 1700000002);
        fakeNostrService.injectEvent(followEvent3);
        await Future.delayed(Duration(milliseconds: 200));

        expect(service.notifications.last.actorName, 'username');

        // Test 4: "Unknown user" is used when no profile data exists
        final pubkey4 =
            '4444444444444444444444444444444444444444444444444444444444444444';
        // No profile added for pubkey4

        final followEvent4 = Event(pubkey4, 3, [], '', createdAt: 1700000003);
        fakeNostrService.injectEvent(followEvent4);
        await Future.delayed(Duration(milliseconds: 200));

        expect(service.notifications.last.actorName, 'Unknown user');
      },
    );
  });
}
