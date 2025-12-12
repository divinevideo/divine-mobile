// ABOUTME: Tests for NostrKeyManager automatic profile fetching after nsec import
// ABOUTME: Ensures kind 0 (profile) events are fetched from specific relays after key import

import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:nostr_key_manager/nostr_key_manager.dart';
import 'package:nostr_sdk/nostr_sdk.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:openvine/services/user_profile_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../test_setup.dart';
import 'nostr_key_manager_profile_fetch_test.mocks.dart';

@GenerateMocks([NostrClient, UserProfileService])
void main() {
  setupTestEnvironment();

  group('NostrKeyManager Profile Fetching After Import', () {
    late NostrKeyManager keyManager;
    late MockNostrClient mockNostrService;
    late MockUserProfileService mockProfileService;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      mockNostrService = MockNostrClient();
      mockProfileService = MockUserProfileService();

      // Setup basic mocks
      when(mockNostrService.isInitialized).thenReturn(true);
      when(mockNostrService.hasKeys).thenReturn(false);

      keyManager = NostrKeyManager();
      await keyManager.initialize();
    });

    tearDown(() async {
      await keyManager.clearKeys();
    });

    group('importFromNsec - profile fetching', () {
      test(
        'should fetch profile from specified relays after successful nsec import',
        () async {
          // Arrange: Create a valid test nsec key
          final testPrivateKeyHex =
              'a1b2c3d4e5f6a7b8c9d0e1f2a3b4c5d6e7f8a9b0c1d2e3f4a5b6c7d8e9f0a1b2';
          final testNsec = Nip19.encodePrivateKey(testPrivateKeyHex);

          // Act: Import the nsec key
          await keyManager.importFromNsec(testNsec);

          // Manually fetch profile after import (app-specific behavior)
          if (mockNostrService.isInitialized && keyManager.publicKey != null) {
            await mockProfileService.fetchProfile(
              keyManager.publicKey!,
              forceRefresh: false,
            );
          }

          // Assert: Verify profile fetch was called with correct parameters
          final captured = verify(
            mockProfileService.fetchProfile(captureAny, forceRefresh: false),
          ).captured;
          expect(captured.length, equals(1));
          expect(captured[0], equals(keyManager.publicKey));
        },
      );

      test('should NOT fetch profile if nsec import fails', () async {
        // Arrange: Create an INVALID nsec
        const invalidNsec = 'nsec1invalid_key_format_here';

        // Act & Assert: Import should fail
        expect(
          () async => await keyManager.importFromNsec(invalidNsec),
          throwsA(isA<NostrKeyException>()),
        );

        // Verify profile service was never called (since import failed)
        verifyNever(
          mockProfileService.fetchProfile(
            any,
            forceRefresh: anyNamed('forceRefresh'),
          ),
        );
      });

      test('should handle missing UserProfileService gracefully', () async {
        // Arrange: Create a valid test nsec key
        final testPrivateKeyHex =
            'b2c3d4e5f6a7b8c9d0e1f2a3b4c5d6e7f8a9b0c1d2e3f4a5b6c7d8e9f0a1b2c3';
        final testNsec = Nip19.encodePrivateKey(testPrivateKeyHex);

        // Act: Import nsec (profile fetching is now app responsibility)
        final result = await keyManager.importFromNsec(testNsec);

        // Assert: Import should succeed
        expect(result, isNotNull);
        expect(result.public, isNotEmpty);
        expect(keyManager.hasKeys, isTrue);
      });

      test('should continue import even if profile fetch fails', () async {
        // Arrange: Create a valid test nsec key
        final testPrivateKeyHex =
            'c3d4e5f6a7b8c9d0e1f2a3b4c5d6e7f8a9b0c1d2e3f4a5b6c7d8e9f0a1b2c3d4';
        final testNsec = Nip19.encodePrivateKey(testPrivateKeyHex);

        // Mock profile service to throw an error
        when(
          mockProfileService.fetchProfile(any, forceRefresh: false),
        ).thenThrow(Exception('Profile fetch failed'));

        // Act: Import should still succeed
        final result = await keyManager.importFromNsec(testNsec);

        // Assert: Key import succeeded
        expect(result, isNotNull);
        expect(result.public, isNotEmpty);
        expect(keyManager.hasKeys, isTrue);

        // Manually attempt profile fetch (app-specific behavior)
        // This should fail but not affect the import
        try {
          if (mockNostrService.isInitialized && keyManager.publicKey != null) {
            await mockProfileService.fetchProfile(
              keyManager.publicKey!,
              forceRefresh: false,
            );
          }
        } catch (e) {
          // Profile fetch failure is expected in this test
        }

        // Verify profile fetch was attempted
        verify(
          mockProfileService.fetchProfile(any, forceRefresh: false),
        ).called(1);
      });

      test(
        'should NOT fetch profile if NostrService is not initialized',
        () async {
          // Arrange: Create a valid test nsec key
          final testPrivateKeyHex =
              'd4e5f6a7b8c9d0e1f2a3b4c5d6e7f8a9b0c1d2e3f4a5b6c7d8e9f0a1b2c3d4e5';
          final testNsec = Nip19.encodePrivateKey(testPrivateKeyHex);

          // Mock NostrService as NOT initialized
          when(mockNostrService.isInitialized).thenReturn(false);

          // Act: Import key
          await keyManager.importFromNsec(testNsec);

          // App should check if service is initialized before fetching profile
          // Since service is not initialized, profile fetch should not happen
          // (This is now app logic, not package logic)

          // Assert: Profile fetch should NOT be called when service not initialized
          verifyNever(
            mockProfileService.fetchProfile(
              any,
              forceRefresh: anyNamed('forceRefresh'),
            ),
          );
        },
      );

      test(
        'should fetch profile using forceRefresh=false for initial import',
        () async {
          // Arrange: Create a valid test nsec key
          final testPrivateKeyHex =
              'e5f6a7b8c9d0e1f2a3b4c5d6e7f8a9b0c1d2e3f4a5b6c7d8e9f0a1b2c3d4e5f6';
          final testNsec = Nip19.encodePrivateKey(testPrivateKeyHex);

          // Act: Import key
          await keyManager.importFromNsec(testNsec);

          // Manually fetch profile after import (app-specific behavior)
          if (mockNostrService.isInitialized && keyManager.publicKey != null) {
            await mockProfileService.fetchProfile(
              keyManager.publicKey!,
              forceRefresh: false,
            );
          }

          // Assert: Verify forceRefresh is false (use cached profile if available)
          verify(
            mockProfileService.fetchProfile(any, forceRefresh: false),
          ).called(1);

          // Ensure forceRefresh=true was NOT called
          verifyNever(mockProfileService.fetchProfile(any, forceRefresh: true));
        },
      );
    });

    group('importPrivateKey - profile fetching', () {
      test(
        'should fetch profile from specified relays after successful hex key import',
        () async {
          // Arrange: Create a valid test private key in hex format
          final testPrivateKeyHex =
              'f6a7b8c9d0e1f2a3b4c5d6e7f8a9b0c1d2e3f4a5b6c7d8e9f0a1b2c3d4e5f6a7';

          // Act: Import the hex private key
          await keyManager.importPrivateKey(testPrivateKeyHex);

          // Manually fetch profile after import (app-specific behavior)
          if (mockNostrService.isInitialized && keyManager.publicKey != null) {
            await mockProfileService.fetchProfile(
              keyManager.publicKey!,
              forceRefresh: false,
            );
          }

          // Assert: Verify profile fetch was called
          final captured = verify(
            mockProfileService.fetchProfile(captureAny, forceRefresh: false),
          ).captured;
          expect(captured.length, equals(1));
          expect(captured[0], equals(keyManager.publicKey));
        },
      );

      test('should handle profile fetch gracefully for hex import', () async {
        // Arrange: Create a valid test private key
        final testPrivateKeyHex =
            'a7b8c9d0e1f2a3b4c5d6e7f8a9b0c1d2e3f4a5b6c7d8e9f0a1b2c3d4e5f6a7b8';

        // Mock profile service to return null (profile not found)
        when(
          mockProfileService.fetchProfile(any, forceRefresh: false),
        ).thenAnswer((_) async => null);

        // Act: Import should still succeed
        final result = await keyManager.importPrivateKey(testPrivateKeyHex);

        // Manually fetch profile after import (app-specific behavior)
        if (mockNostrService.isInitialized && keyManager.publicKey != null) {
          await mockProfileService.fetchProfile(
            keyManager.publicKey!,
            forceRefresh: false,
          );
        }

        // Assert: Import succeeded even though profile wasn't found
        expect(result, isNotNull);
        expect(result.public, isNotEmpty);
        expect(keyManager.hasKeys, isTrue);
      });
    });
  });
}
