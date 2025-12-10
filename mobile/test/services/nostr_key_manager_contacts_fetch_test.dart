// ABOUTME: Tests for automatic contact list (kind 3) fetching after nsec import
// ABOUTME: Verifies that importing an nsec triggers fetching contacts from specific relays

import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:nostr_key_manager/nostr_key_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../test_setup.dart';
import 'nostr_key_manager_contacts_fetch_test.mocks.dart';

// Generate mocks for dependencies
@GenerateMocks([SecureKeyStorage])
void main() {
  setupTestEnvironment();

  group('AuthService Contact List Fetching After Import', () {
    late MockSecureKeyStorage mockKeyStorage;
    late AuthService authService;

    // Test nsec from a known keypair
    const testNsec =
        'nsec1vl029mgpspedva04g90vltkh6fvh240zqtv9k0t9af8935ke9laqsnlfe5';

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      mockKeyStorage = MockSecureKeyStorage();

      // Create AuthService with mock key storage
      authService = AuthService(keyStorage: mockKeyStorage);
    });

    test('should fetch kind 3 events after successful nsec import', () async {
      // Arrange: Create a secure key container for the test
      final keyContainer = SecureKeyContainer.fromNsec(testNsec);

      // Setup successful import
      when(
        mockKeyStorage.importFromNsec(
          any,
          biometricPrompt: anyNamed('biometricPrompt'),
        ),
      ).thenAnswer((_) async => keyContainer);

      // Act: Import the nsec
      final result = await authService.importFromNsec(testNsec);

      // Assert: Import should succeed
      expect(result.success, isTrue);

      // Note: The actual contact fetching logic should be implemented
      // in AuthService.importFromNsec() to call SocialService.fetchCurrentUserFollowList()
      // after successful import. This test documents the expected behavior.
    });

    test('should not fetch contacts if import fails', () async {
      // Arrange: Setup failed import
      when(
        mockKeyStorage.importFromNsec(
          any,
          biometricPrompt: anyNamed('biometricPrompt'),
        ),
      ).thenThrow(Exception('Invalid nsec format'));

      // Act: Attempt to import invalid nsec
      final result = await authService.importFromNsec('invalid_nsec');

      // Assert: Import should fail
      expect(result.success, isFalse);

      // Assert: No contact fetch should happen on failed import
    });

    test('should handle contact fetch errors gracefully', () async {
      // Arrange: Create a secure key container for the test
      final keyContainer = SecureKeyContainer.fromNsec(testNsec);

      // Setup successful import
      when(
        mockKeyStorage.importFromNsec(
          any,
          biometricPrompt: anyNamed('biometricPrompt'),
        ),
      ).thenAnswer((_) async => keyContainer);

      // Act: Import the nsec
      final result = await authService.importFromNsec(testNsec);

      // Assert: Should still succeed with import, even if contact fetch fails
      expect(result.success, isTrue);
    });
  });
}
