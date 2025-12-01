// ABOUTME: Tests for contact display in share video dialog
// ABOUTME: Verifies npub/nip05 is shown instead of raw hex pubkey

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:openvine/models/video_event.dart';
import 'package:openvine/models/user_profile.dart';
import 'package:openvine/services/social_service.dart';
import 'package:openvine/services/user_profile_service.dart';
import 'package:openvine/services/video_sharing_service.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/widgets/share_video_menu.dart';

@GenerateMocks([SocialService, UserProfileService, VideoSharingService])
import 'share_video_contact_display_test.mocks.dart';

void main() {
  group('Share Video Contact Display Tests', () {
    late MockSocialService mockSocialService;
    late MockUserProfileService mockUserProfileService;
    late MockVideoSharingService mockVideoSharingService;

    final testVideo = VideoEvent(
      id: 'test-video-id',
      pubkey: '1234567890abcdef' * 4, // 64-char hex
      createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      content: 'Test video',
      timestamp: DateTime.now(),
      title: 'Test',
      videoUrl: 'https://example.com/video.mp4',
    );

    final testPubkey =
        '2646f4c01362b3b48d4b4e31d9c96a4eabe06c4eb971e1a482ef651f1bf023b7';

    setUp(() {
      mockSocialService = MockSocialService();
      mockUserProfileService = MockUserProfileService();
      mockVideoSharingService = MockVideoSharingService();

      // Setup default mocks
      when(mockSocialService.followingPubkeys).thenReturn([testPubkey]);
      when(mockSocialService.followSets).thenReturn([]);
      when(mockUserProfileService.hasProfile(any)).thenReturn(false);
      when(mockUserProfileService.getCachedProfile(any)).thenReturn(null);
    });

    testWidgets('Contact display shows npub instead of raw hex', (
      tester,
    ) async {
      // Setup profile with display name but no nip05
      final testProfile = UserProfile(
        pubkey: testPubkey,
        displayName: 'Test User',
        name: 'testuser',
        about: null,
        picture: null,
        banner: null,
        website: null,
        nip05: null,
        lud16: null,
        lud06: null,
        createdAt: DateTime.now(),
        eventId: 'profile-event-id',
        rawData: {},
      );

      when(mockUserProfileService.hasProfile(testPubkey)).thenReturn(true);
      when(
        mockUserProfileService.getCachedProfile(testPubkey),
      ).thenReturn(testProfile);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            socialServiceProvider.overrideWithValue(mockSocialService),
            userProfileServiceProvider.overrideWithValue(
              mockUserProfileService,
            ),
            videoSharingServiceProvider.overrideWithValue(
              mockVideoSharingService,
            ),
          ],
          child: MaterialApp(
            home: Scaffold(body: ShareVideoMenu(video: testVideo)),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Tap "Send to Viner" to open dialog
      await tester.tap(find.text('Send to Viner'));
      await tester.pumpAndSettle();

      // Verify contact list loads
      expect(find.text('Your Contacts'), findsOneWidget);

      // CRITICAL: Verify raw hex is NOT shown
      expect(find.textContaining(testPubkey), findsNothing);

      // CRITICAL: Verify npub format IS shown (starts with npub1)
      expect(find.textContaining('npub1'), findsOneWidget);
    });

    testWidgets('Contact display shows nip05 when available', (tester) async {
      // Setup profile with nip05
      final testProfile = UserProfile(
        pubkey: testPubkey,
        displayName: 'Test User',
        name: 'testuser',
        about: null,
        picture: null,
        banner: null,
        website: null,
        nip05: 'testuser@example.com',
        lud16: null,
        lud06: null,
        createdAt: DateTime.now(),
        eventId: 'profile-event-id',
        rawData: {},
      );

      when(mockUserProfileService.hasProfile(testPubkey)).thenReturn(true);
      when(
        mockUserProfileService.getCachedProfile(testPubkey),
      ).thenReturn(testProfile);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            socialServiceProvider.overrideWithValue(mockSocialService),
            userProfileServiceProvider.overrideWithValue(
              mockUserProfileService,
            ),
            videoSharingServiceProvider.overrideWithValue(
              mockVideoSharingService,
            ),
          ],
          child: MaterialApp(
            home: Scaffold(body: ShareVideoMenu(video: testVideo)),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Tap "Send to Viner" to open dialog
      await tester.tap(find.text('Send to Viner'));
      await tester.pumpAndSettle();

      // Verify contact list loads
      expect(find.text('Your Contacts'), findsOneWidget);

      // CRITICAL: Verify nip05 is shown (preferred over npub)
      expect(find.text('testuser@example.com'), findsOneWidget);

      // CRITICAL: Verify raw hex is NOT shown
      expect(find.textContaining(testPubkey), findsNothing);
    });

    testWidgets('Contact with no profile data shows npub fallback', (
      tester,
    ) async {
      // No profile data - should still show npub, not hex
      when(mockUserProfileService.hasProfile(testPubkey)).thenReturn(false);
      when(
        mockUserProfileService.getCachedProfile(testPubkey),
      ).thenReturn(null);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            socialServiceProvider.overrideWithValue(mockSocialService),
            userProfileServiceProvider.overrideWithValue(
              mockUserProfileService,
            ),
            videoSharingServiceProvider.overrideWithValue(
              mockVideoSharingService,
            ),
          ],
          child: MaterialApp(
            home: Scaffold(body: ShareVideoMenu(video: testVideo)),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Tap "Send to Viner" to open dialog
      await tester.tap(find.text('Send to Viner'));
      await tester.pumpAndSettle();

      // CRITICAL: Even without profile data, verify npub is shown, not raw hex
      expect(find.textContaining('npub1'), findsOneWidget);
      expect(find.textContaining(testPubkey), findsNothing);
    });
  });
}
