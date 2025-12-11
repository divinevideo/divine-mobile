// ABOUTME: Tests for VideoSharingService social features integration
// ABOUTME: Covers getShareableUsers and searchUsersToShareWith with TDD approach

import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:openvine/models/user_profile.dart' as profile_model;
import 'package:openvine/models/video_event.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:openvine/services/social_service.dart';
import 'package:openvine/services/user_profile_service.dart';
import 'package:openvine/services/video_sharing_service.dart';

import 'video_sharing_service_test.mocks.dart';

@GenerateMocks([NostrClient, AuthService, UserProfileService, SocialService])
void main() {
  late VideoSharingService service;
  late MockNostrClient mockNostrService;
  late MockAuthService mockAuthService;
  late MockUserProfileService mockUserProfileService;
  late MockSocialService mockSocialService;

  setUp(() {
    mockNostrService = MockNostrClient();
    mockAuthService = MockAuthService();
    mockUserProfileService = MockUserProfileService();
    mockSocialService = MockSocialService();

    service = VideoSharingService(
      nostrService: mockNostrService,
      authService: mockAuthService,
      userProfileService: mockUserProfileService,
    );
  });

  group('getShareableUsers', () {
    test(
      'returns recently shared users when no following list exists',
      () async {
        // Arrange
        when(mockSocialService.followingPubkeys).thenReturn([]);

        // Act
        final result = await service.getShareableUsers(limit: 20);

        // Assert
        expect(result, isEmpty);
        verify(mockSocialService.followingPubkeys).called(1);
      },
    );

    test('returns following list with profile data', () async {
      // Arrange
      final followingPubkeys = [
        'pubkey1' * 8, // 64 chars
        'pubkey2' * 8,
        'pubkey3' * 8,
      ];

      final profile1 = profile_model.UserProfile(
        pubkey: followingPubkeys[0],
        rawData: const {},
        createdAt: DateTime.now(),
        eventId: 'event1',
        name: 'Alice',
        displayName: 'Alice Smith',
        picture: 'https://example.com/alice.jpg',
      );

      final profile2 = profile_model.UserProfile(
        pubkey: followingPubkeys[1],
        rawData: const {},
        createdAt: DateTime.now(),
        eventId: 'event2',
        name: 'Bob',
        displayName: 'Bob Jones',
      );

      when(mockSocialService.followingPubkeys).thenReturn(followingPubkeys);
      when(mockSocialService.isFollowing(any)).thenReturn(true);
      when(
        mockUserProfileService.getCachedProfile(followingPubkeys[0]),
      ).thenReturn(profile1);
      when(
        mockUserProfileService.getCachedProfile(followingPubkeys[1]),
      ).thenReturn(profile2);
      when(
        mockUserProfileService.getCachedProfile(followingPubkeys[2]),
      ).thenReturn(null);

      // Act
      final result = await service.getShareableUsers(limit: 20);

      // Assert
      expect(result.length, 3);
      expect(result[0].pubkey, followingPubkeys[0]);
      expect(result[0].displayName, 'Alice Smith');
      expect(result[0].picture, 'https://example.com/alice.jpg');
      expect(result[0].isFollowing, true);

      expect(result[1].pubkey, followingPubkeys[1]);
      expect(result[1].displayName, 'Bob Jones');
      expect(result[1].isFollowing, true);

      expect(result[2].pubkey, followingPubkeys[2]);
      expect(result[2].displayName, null);
      expect(result[2].isFollowing, true);
    });

    test('prioritizes recently shared users over following list', () async {
      // Arrange
      final followingPubkeys = ['pubkey1' * 8, 'pubkey2' * 8];

      when(mockSocialService.followingPubkeys).thenReturn(followingPubkeys);
      when(mockSocialService.isFollowing(any)).thenReturn(true);
      when(mockUserProfileService.getCachedProfile(any)).thenReturn(null);

      // Share with one user to add to recent
      final now = DateTime.now();
      final testVideo = VideoEvent(
        id: 'video1',
        pubkey: 'author123',
        createdAt: now.millisecondsSinceEpoch ~/ 1000,
        timestamp: now,
        content: 'Test video',
      );

      when(mockAuthService.isAuthenticated).thenReturn(true);
      when(
        mockAuthService.createAndSignEvent(
          kind: anyNamed('kind'),
          content: anyNamed('content'),
          tags: anyNamed('tags'),
        ),
      ).thenAnswer((_) async => null);

      await service.shareVideoWithUser(
        video: testVideo,
        recipientPubkey: followingPubkeys[0],
      );

      // Act
      final result = await service.getShareableUsers(limit: 20);

      // Assert
      expect(
        result,
        isNotEmpty,
        reason: 'Should return at least one shareable user from following list',
      );
      // Recently shared should appear first
      expect(result.first.pubkey, followingPubkeys[0]);
    });

    test('respects limit parameter', () async {
      // Arrange
      final followingPubkeys = List.generate(25, (i) => 'pubkey$i' * 8);

      when(mockSocialService.followingPubkeys).thenReturn(followingPubkeys);
      when(mockSocialService.isFollowing(any)).thenReturn(true);
      when(mockUserProfileService.getCachedProfile(any)).thenReturn(null);

      // Act
      final result = await service.getShareableUsers(limit: 10);

      // Assert
      expect(result.length, 10);
    });
  });

  group('searchUsersToShareWith', () {
    test('returns empty list for empty query', () async {
      // Act
      final result = await service.searchUsersToShareWith('');

      // Assert
      expect(result, isEmpty);
    });

    test('searches by display name in following list', () async {
      // Arrange
      final followingPubkeys = ['pubkey1' * 8, 'pubkey2' * 8, 'pubkey3' * 8];

      final profile1 = profile_model.UserProfile(
        pubkey: followingPubkeys[0],
        rawData: const {},
        createdAt: DateTime.now(),
        eventId: 'event1',
        displayName: 'Alice Smith',
      );

      final profile2 = profile_model.UserProfile(
        pubkey: followingPubkeys[1],
        rawData: const {},
        createdAt: DateTime.now(),
        eventId: 'event2',
        displayName: 'Bob Jones',
      );

      final profile3 = profile_model.UserProfile(
        pubkey: followingPubkeys[2],
        rawData: const {},
        createdAt: DateTime.now(),
        eventId: 'event3',
        displayName: 'Alice Johnson',
      );

      when(mockSocialService.followingPubkeys).thenReturn(followingPubkeys);
      when(
        mockUserProfileService.getCachedProfile(followingPubkeys[0]),
      ).thenReturn(profile1);
      when(
        mockUserProfileService.getCachedProfile(followingPubkeys[1]),
      ).thenReturn(profile2);
      when(
        mockUserProfileService.getCachedProfile(followingPubkeys[2]),
      ).thenReturn(profile3);

      // Act
      final result = await service.searchUsersToShareWith('alice');

      // Assert
      expect(result.length, 2);
      expect(result[0].displayName, 'Alice Smith');
      expect(result[1].displayName, 'Alice Johnson');
    });

    test('searches by name field if displayName is null', () async {
      // Arrange
      final followingPubkeys = ['pubkey1' * 8];

      final profile = profile_model.UserProfile(
        pubkey: followingPubkeys[0],
        rawData: const {},
        createdAt: DateTime.now(),
        eventId: 'event1',
        name: 'alice',
        displayName: null,
      );

      when(mockSocialService.followingPubkeys).thenReturn(followingPubkeys);
      when(
        mockUserProfileService.getCachedProfile(followingPubkeys[0]),
      ).thenReturn(profile);

      // Act
      final result = await service.searchUsersToShareWith('alice');

      // Assert
      expect(result.length, 1);
      // Implementation falls back to name when displayName is null for better UX
      expect(result[0].displayName, 'alice');
    });

    test('returns user by hex pubkey lookup as fallback', () async {
      // Arrange
      final hexPubkey = 'a' * 64;
      final profile = profile_model.UserProfile(
        pubkey: hexPubkey,
        rawData: const {},
        createdAt: DateTime.now(),
        eventId: 'event1',
        displayName: 'Charlie',
      );

      when(mockSocialService.followingPubkeys).thenReturn([]);
      when(
        mockUserProfileService.fetchProfile(hexPubkey),
      ).thenAnswer((_) async => profile);

      // Act
      final result = await service.searchUsersToShareWith(hexPubkey);

      // Assert
      expect(result.length, 1);
      expect(result[0].pubkey, hexPubkey);
      expect(result[0].displayName, 'Charlie');
      verify(mockUserProfileService.fetchProfile(hexPubkey)).called(1);
    });

    test('is case insensitive for display name search', () async {
      // Arrange
      final followingPubkeys = ['pubkey1' * 8];

      final profile = profile_model.UserProfile(
        pubkey: followingPubkeys[0],
        rawData: const {},
        createdAt: DateTime.now(),
        eventId: 'event1',
        displayName: 'Alice Smith',
      );

      when(mockSocialService.followingPubkeys).thenReturn(followingPubkeys);
      when(
        mockUserProfileService.getCachedProfile(followingPubkeys[0]),
      ).thenReturn(profile);

      // Act
      final result = await service.searchUsersToShareWith('ALICE');

      // Assert
      expect(result.length, 1);
      expect(result[0].displayName, 'Alice Smith');
    });

    test('returns empty list when hex pubkey not found', () async {
      // Arrange
      final hexPubkey = 'a' * 64;

      when(mockSocialService.followingPubkeys).thenReturn([]);
      when(
        mockUserProfileService.fetchProfile(hexPubkey),
      ).thenAnswer((_) async => null);

      // Act
      final result = await service.searchUsersToShareWith(hexPubkey);

      // Assert
      expect(result, isEmpty);
    });
  });
}
