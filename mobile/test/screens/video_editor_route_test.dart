// ABOUTME: Tests for video editor route navigation and edit button visibility
// ABOUTME: Verifies edit button appears for owned videos and navigates correctly

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/features/feature_flags/models/feature_flag.dart';
import 'package:openvine/features/feature_flags/providers/feature_flag_providers.dart';
import 'package:openvine/features/feature_flags/services/build_configuration.dart';
import 'package:openvine/features/feature_flags/services/feature_flag_service.dart';
import 'package:openvine/models/video_event.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/social_providers.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/state/social_state.dart';
import 'package:openvine/ui/overlay_policy.dart';
import 'package:openvine/widgets/video_feed_item.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('VideoEditorRoute - Edit Button Tests', () {
    late VideoEvent testVideo;
    late String testUserPubkey;

    setUp(() {
      testUserPubkey = 'abc123testpubkey';

      // Create a test video event owned by test user (using the fromNostrEvent factory would require full Event setup)
      // For testing purposes, use the constructor directly
      testVideo = VideoEvent(
        id: 'test-video-id',
        pubkey: testUserPubkey,
        createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
        content: 'Test video content',
        timestamp: DateTime.now(),
        title: 'Test Video',
        videoUrl: 'https://example.com/video.mp4',
      );
    });

    testWidgets(
      'Edit button appears when video is owned by current user and feature flag is enabled',
      (tester) async {
        // Arrange: Create a ProviderContainer with overrides
        final container = ProviderContainer(
          overrides: [
            // Override auth service to return our test user as authenticated
            authServiceProvider.overrideWith((ref) {
              return _MockAuthService(
                pubkey: testUserPubkey,
                authenticated: true,
              );
            }),
            // Override feature flag service to enable video editor
            featureFlagServiceProvider.overrideWith((ref) {
              return _MockFeatureFlagService(enableVideoEditor: true);
            }),
            // Override social provider
            socialProvider.overrideWith(() => _MockSocialNotifier()),
            // Force overlay to always be visible
            overlayPolicyProvider.overrideWith((ref) => OverlayPolicy.alwaysOn),
          ],
        );

        // Act: Build the widget
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              home: Scaffold(
                body: VideoOverlayActions(
                  video: testVideo,
                  isVisible: true,
                  isActive: true,
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Assert: Edit button should be visible
        expect(find.byIcon(Icons.edit), findsOneWidget);

        container.dispose();
      },
    );

    testWidgets(
      'Edit button does NOT appear when video is owned by different user',
      (tester) async {
        // Arrange: Create a ProviderContainer with different user authenticated
        final container = ProviderContainer(
          overrides: [
            authServiceProvider.overrideWith((ref) {
              return _MockAuthService(
                pubkey: 'different-user-pubkey', // Different user!
                authenticated: true,
              );
            }),
            featureFlagServiceProvider.overrideWith((ref) {
              return _MockFeatureFlagService(enableVideoEditor: true);
            }),
            socialProvider.overrideWith(() => _MockSocialNotifier()),
            overlayPolicyProvider.overrideWith((ref) => OverlayPolicy.alwaysOn),
          ],
        );

        // Act: Build the widget
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              home: Scaffold(
                body: VideoOverlayActions(
                  video: testVideo,
                  isVisible: true,
                  isActive: true,
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Assert: Edit button should NOT be visible
        expect(find.byIcon(Icons.edit), findsNothing);

        container.dispose();
      },
    );

    testWidgets('Edit button does NOT appear when feature flag is disabled', (
      tester,
    ) async {
      // Arrange: Feature flag disabled
      final container = ProviderContainer(
        overrides: [
          authServiceProvider.overrideWith((ref) {
            return _MockAuthService(
              pubkey: testUserPubkey,
              authenticated: true,
            );
          }),
          // Feature flag DISABLED
          featureFlagServiceProvider.overrideWith((ref) {
            return _MockFeatureFlagService(enableVideoEditor: false);
          }),
          socialProvider.overrideWith(() => _MockSocialNotifier()),
          overlayPolicyProvider.overrideWith((ref) => OverlayPolicy.alwaysOn),
        ],
      );

      // Act: Build the widget
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Scaffold(
              body: VideoOverlayActions(
                video: testVideo,
                isVisible: true,
                isActive: true,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Assert: Edit button should NOT be visible
      expect(find.byIcon(Icons.edit), findsNothing);

      container.dispose();
    });
  });
}

// Mock classes for testing

class _MockAuthService extends AuthService {
  _MockAuthService({required this.pubkey, required this.authenticated});

  final String? pubkey;
  final bool authenticated;

  @override
  bool get isAuthenticated => authenticated;

  @override
  String? get currentPublicKeyHex => pubkey;

  @override
  AuthState get authState =>
      authenticated ? AuthState.authenticated : AuthState.unauthenticated;
}

class _MockFeatureFlagService extends FeatureFlagService {
  _MockFeatureFlagService({required this.enableVideoEditor})
    : super(_MockSharedPreferences._(), const BuildConfiguration());

  final bool enableVideoEditor;

  @override
  bool isEnabled(FeatureFlag flag) {
    if (flag == FeatureFlag.enableVideoEditorV1) {
      return enableVideoEditor;
    }
    return false;
  }
}

class _MockSharedPreferences implements SharedPreferences {
  _MockSharedPreferences._();

  @override
  bool? getBool(String key) => null;

  @override
  Future<bool> setBool(String key, bool value) async => true;

  @override
  Future<bool> remove(String key) async => true;

  @override
  bool containsKey(String key) => false;

  @override
  Future<bool> clear() async => true;

  @override
  Future<bool> commit() async => true;

  @override
  double? getDouble(String key) => null;

  @override
  int? getInt(String key) => null;

  @override
  Set<String> getKeys() => {};

  @override
  String? getString(String key) => null;

  @override
  List<String>? getStringList(String key) => null;

  @override
  Future<void> reload() async {}

  @override
  Future<bool> setDouble(String key, double value) async => true;

  @override
  Future<bool> setInt(String key, int value) async => true;

  @override
  Future<bool> setString(String key, String value) async => true;

  @override
  Future<bool> setStringList(String key, List<String> value) async => true;

  @override
  Object? get(String key) => null;
}

class _MockSocialNotifier extends SocialNotifier {
  @override
  SocialState build() => SocialState.initial;
}
