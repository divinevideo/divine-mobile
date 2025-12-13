// ABOUTME: Tests for AuthService signOut clearing user-specific data
// ABOUTME: Verifies that explicit logout clears pubkey tracking and user data

import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/user_data_cleanup_service.dart';
import 'package:nostr_key_manager/nostr_key_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../test_setup.dart';
import 'auth_service_signout_cleanup_test.mocks.dart';

// Generate mocks for dependencies
@GenerateMocks([SecureKeyStorage, UserDataCleanupService])
void main() {
  setupTestEnvironment();

  group('AuthService signOut cleanup', () {
    late MockSecureKeyStorage mockKeyStorage;
    late MockUserDataCleanupService mockCleanupService;
    late AuthService authService;
    late SharedPreferences prefs;

    // Test nsec from a known keypair
    const testNsec =
        'nsec1vl029mgpspedva04g90vltkh6fvh240zqtv9k0t9af8935ke9laqsnlfe5';

    setUp(() async {
      SharedPreferences.setMockInitialValues({
        'current_user_pubkey_hex': 'existing_pubkey_hex_123',
        'age_verified_16_plus': true,
        'terms_accepted_at': '2024-01-01T00:00:00Z',
      });
      prefs = await SharedPreferences.getInstance();
      mockKeyStorage = MockSecureKeyStorage();
      mockCleanupService = MockUserDataCleanupService();

      // Create AuthService with mock dependencies
      authService = AuthService(
        userDataCleanupService: mockCleanupService,
        keyStorage: mockKeyStorage,
      );

      // Setup mock behaviors
      when(mockCleanupService.shouldClearDataForUser(any)).thenReturn(false);
      when(
        mockCleanupService.clearUserSpecificData(reason: anyNamed('reason')),
      ).thenAnswer((_) async => 0);
    });

    test('signOut should clear current_user_pubkey_hex', () async {
      // Arrange: Verify pubkey is initially stored
      expect(prefs.getString('current_user_pubkey_hex'), isNotNull);

      // Setup mock to not delete keys (just clearing cache)
      when(mockKeyStorage.clearCache()).thenReturn(null);

      // Act: Sign out without deleting keys
      await authService.signOut(deleteKeys: false);

      // Assert: Pubkey should be cleared
      expect(prefs.getString('current_user_pubkey_hex'), isNull);
    });

    test('signOut should clear TOS acceptance flags', () async {
      // Arrange: Verify TOS flags are initially set
      expect(prefs.getBool('age_verified_16_plus'), isTrue);
      expect(prefs.getString('terms_accepted_at'), isNotNull);

      // Setup mock
      when(mockKeyStorage.clearCache()).thenReturn(null);

      // Act: Sign out
      await authService.signOut(deleteKeys: false);

      // Assert: TOS flags should be cleared
      expect(prefs.getBool('age_verified_16_plus'), isNull);
      expect(prefs.getString('terms_accepted_at'), isNull);
    });

    test(
      'signOut should call cleanup service to clear user-specific data',
      () async {
        // Setup mock
        when(mockKeyStorage.clearCache()).thenReturn(null);

        // Act: Sign out
        await authService.signOut(deleteKeys: false);

        // Assert: Cleanup service should be called with explicit_logout reason
        verify(
          mockCleanupService.clearUserSpecificData(reason: 'explicit_logout'),
        ).called(1);
      },
    );

    test(
      'signOut with deleteKeys should delete keys and call cleanup',
      () async {
        // Arrange
        when(mockKeyStorage.deleteKeys()).thenAnswer((_) async => {});
        when(mockKeyStorage.hasKeys()).thenAnswer((_) async => false);
        when(mockKeyStorage.initialize()).thenAnswer((_) async => {});

        // Auto-create new identity after deletion
        final newKeyContainer = SecureKeyContainer.fromNsec(testNsec);
        when(
          mockKeyStorage.generateAndStoreKeys(
            biometricPrompt: anyNamed('biometricPrompt'),
          ),
        ).thenAnswer((_) async => newKeyContainer);

        // Act: Sign out with key deletion
        await authService.signOut(deleteKeys: true);

        // Assert: Keys should be deleted
        verify(mockKeyStorage.deleteKeys()).called(1);

        // Assert: Cleanup service should be called with explicit_logout reason
        verify(
          mockCleanupService.clearUserSpecificData(reason: 'explicit_logout'),
        ).called(1);

        // Note: After deleteKeys=true, a new identity is auto-created,
        // which sets a new pubkey. So we verify cleanup was called,
        // not that pubkey is null (since new identity sets it).
      },
    );

    test('signOut should set auth state to unauthenticated', () async {
      // Setup mock
      when(mockKeyStorage.clearCache()).thenReturn(null);

      // Act: Sign out
      await authService.signOut(deleteKeys: false);

      // Assert: Auth state should be unauthenticated
      expect(authService.authState, equals(AuthState.unauthenticated));
    });
  });
}
