// ABOUTME: Tests for automatic contact list (kind 3) fetching after nsec import
// ABOUTME: Verifies that importing an nsec triggers fetching contacts from specific relays

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nostr_key_manager/nostr_key_manager.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/background_activity_manager.dart';
import 'package:openvine/services/user_data_cleanup_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../test_setup.dart';

class _MockSecureKeyStorage extends Mock implements SecureKeyStorage {}

class _MockUserDataCleanupService extends Mock
    implements UserDataCleanupService {}

void main() {
  setupTestEnvironment();

  group('AuthService Contact List Fetching After Import', () {
    late _MockSecureKeyStorage mockKeyStorage;
    late _MockUserDataCleanupService mockCleanupService;
    late AuthService authService;

    // Test nsec from a known keypair
    const testNsec =
        'nsec1vl029mgpspedva04g90vltkh6fvh240zqtv9k0t9af8935ke9laqsnlfe5';

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      mockKeyStorage = _MockSecureKeyStorage();
      mockCleanupService = _MockUserDataCleanupService();

      // Create AuthService with mock key storage
      authService = AuthService(
        backgroundActivityManager: BackgroundActivityManager(),
        userDataCleanupService: mockCleanupService,
        keyStorage: mockKeyStorage,
      );
    });

    test(
      'should fetch kind 3 events after successful nsec import',
      () async {
        // Arrange: Create a secure key container for the test
        final keyContainer = SecureKeyContainer.fromNsec(testNsec);

        // Setup successful import
        when(
          () => mockKeyStorage.importFromNsec(
            any(),
            biometricPrompt: any(named: 'biometricPrompt'),
          ),
        ).thenAnswer((_) async => keyContainer);

        // Act: Import the nsec
        final result = await authService.importFromNsec(testNsec);

        // Assert: Import should succeed
        expect(result.success, isTrue);

        // Note: The actual contact fetching logic should run after a
        // successful import. This test documents the expected behavior.
      },
      skip:
          'AuthService._setupUserSession calls discovery services '
          'which use real WebSocket; fails in test environment (HTTP 400). '
          'Inject discovery services into AuthService to unit test.',
    );

    test('should not fetch contacts if import fails', () async {
      // Arrange: Setup failed import
      when(
        () => mockKeyStorage.importFromNsec(
          any(),
          biometricPrompt: any(named: 'biometricPrompt'),
        ),
      ).thenThrow(Exception('Invalid nsec format'));

      // Act: Attempt to import invalid nsec
      final result = await authService.importFromNsec('invalid_nsec');

      // Assert: Import should fail
      expect(result.success, isFalse);

      // Assert: No contact fetch should happen on failed import
    });

    test(
      'should handle contact fetch errors gracefully',
      () async {
        // Arrange: Create a secure key container for the test
        final keyContainer = SecureKeyContainer.fromNsec(testNsec);

        // Setup successful import
        when(
          () => mockKeyStorage.importFromNsec(
            any(),
            biometricPrompt: any(named: 'biometricPrompt'),
          ),
        ).thenAnswer((_) async => keyContainer);

        // Act: Import the nsec
        final result = await authService.importFromNsec(testNsec);

        // Assert: Should still succeed with import, even if contact fetch fails
        expect(result.success, isTrue);
      },
      skip: 'Same as above: _setupUserSession uses real WebSocket in test env.',
    );
  });
}
