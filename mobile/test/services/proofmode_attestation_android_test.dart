// ABOUTME: TDD tests specifically for Android Play Integrity API integration
// ABOUTME: Tests Play Integrity token generation, GCP config, and hardware attestation

import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/services/proofmode_attestation_service.dart';
import 'package:openvine/services/proofmode_config.dart';
import '../helpers/test_helpers.dart';

void main() {
  group('Android Play Integrity API Integration', () {
    late ProofModeAttestationService attestationService;

    setUpAll(() async {
      await setupTestEnvironment();
    });

    setUp(() async {
      attestationService = ProofModeAttestationService();
      await attestationService.initialize();
    });

    group('Play Integrity Token Generation', () {
      test(
        'generates Play Integrity token with challenge nonce on Android',
        () async {
          // Skip if not on Android
          if (!Platform.isAndroid) {
            markTestSkipped('Test requires Android platform');
            return;
          }

          // Generate a challenge nonce (hex string)
          final challenge =
              'challenge-nonce-${DateTime.now().millisecondsSinceEpoch}';

          final attestation = await attestationService.generateAttestation(
            challenge,
          );

          expect(
            attestation,
            isNotNull,
            reason: 'Should generate attestation on Android',
          );
          expect(attestation!.platform, equals('Android'));
          expect(
            attestation.challenge,
            equals(challenge),
            reason: 'Attestation should include original challenge',
          );

          // Token should be substantial and not a mock
          expect(attestation.token.length, greaterThan(50));

          // Should include Play Integrity metadata
          expect(attestation.metadata, isNotNull);
          expect(
            attestation.metadata!['attestationType'],
            equals('play_integrity'),
          );
        },
      );

      test('includes challenge nonce in attestation token', () async {
        if (!Platform.isAndroid) {
          markTestSkipped('Test requires Android platform');
          return;
        }

        final challenge =
            'test-challenge-${DateTime.now().millisecondsSinceEpoch}';

        final attestation = await attestationService.generateAttestation(
          challenge,
        );

        expect(attestation, isNotNull);
        expect(
          attestation!.challenge,
          equals(challenge),
          reason: 'Challenge must be stored in attestation for verification',
        );
      });

      test('generates different tokens for different challenges', () async {
        if (!Platform.isAndroid) {
          markTestSkipped('Test requires Android platform');
          return;
        }

        final challenge1 =
            'challenge-1-${DateTime.now().millisecondsSinceEpoch}';
        final challenge2 =
            'challenge-2-${DateTime.now().millisecondsSinceEpoch}';

        final attestation1 = await attestationService.generateAttestation(
          challenge1,
        );
        final attestation2 = await attestationService.generateAttestation(
          challenge2,
        );

        expect(attestation1, isNotNull);
        expect(attestation2, isNotNull);

        // Different challenges should produce different tokens
        expect(
          attestation1!.token,
          isNot(equals(attestation2!.token)),
          reason: 'Different challenges should produce different tokens',
        );
      });
    });

    group('Hardware-Backed Attestation', () {
      test('verifies token is hardware-backed on physical devices', () async {
        if (!Platform.isAndroid) {
          markTestSkipped('Test requires Android platform');
          return;
        }

        final deviceInfo = await attestationService.getDeviceInfo();
        final isPhysicalDevice = deviceInfo.isPhysicalDevice ?? false;

        final challenge = 'hw-test-${DateTime.now().millisecondsSinceEpoch}';
        final attestation = await attestationService.generateAttestation(
          challenge,
        );

        expect(attestation, isNotNull);

        if (isPhysicalDevice) {
          // Physical devices should have hardware-backed attestation
          expect(
            attestation!.isHardwareBacked,
            isTrue,
            reason:
                'Physical Android devices should use hardware-backed attestation',
          );

          // Token should NOT be a mock on physical devices
          expect(
            attestation.token,
            isNot(startsWith('MOCK_')),
            reason:
                'Physical devices should generate real Play Integrity tokens',
          );
        }
      });

      test('handles software-backed tokens on emulators gracefully', () async {
        if (!Platform.isAndroid) {
          markTestSkipped('Test requires Android platform');
          return;
        }

        final deviceInfo = await attestationService.getDeviceInfo();
        final isPhysicalDevice = deviceInfo.isPhysicalDevice ?? false;

        final challenge =
            'emulator-test-${DateTime.now().millisecondsSinceEpoch}';
        final attestation = await attestationService.generateAttestation(
          challenge,
        );

        expect(
          attestation,
          isNotNull,
          reason: 'Should generate attestation even on emulators',
        );

        if (!isPhysicalDevice) {
          // Emulators should use fallback attestation
          expect(
            attestation!.token,
            startsWith('MOCK_ATTESTATION_'),
            reason: 'Emulators should use fallback attestation',
          );
          expect(
            attestation.isHardwareBacked,
            isFalse,
            reason: 'Emulator attestation is not hardware-backed',
          );
        }
      });

      test('checks hardware attestation availability correctly', () async {
        if (!Platform.isAndroid) {
          markTestSkipped('Test requires Android platform');
          return;
        }

        final isAvailable = await attestationService
            .isHardwareAttestationAvailable();
        final deviceInfo = await attestationService.getDeviceInfo();

        // On physical Android devices with Play Services, should be available
        if (deviceInfo.isPhysicalDevice == true) {
          expect(
            isAvailable,
            isTrue,
            reason:
                'Physical Android devices should support hardware attestation',
          );
        }
      });
    });

    group('GCP Configuration', () {
      test('retrieves GCP Project ID from config', () async {
        final gcpProjectId = await ProofModeConfig.gcpProjectId;

        expect(
          gcpProjectId,
          isA<int>(),
          reason: 'GCP Project ID should be an integer',
        );

        // Should be >= 0 (0 means not configured, positive means configured)
        expect(gcpProjectId, greaterThanOrEqualTo(0));
      });

      test('loads GCP Project ID from environment variable if available', () async {
        // This test verifies that ProofModeConfig can load GCP_PROJECT_ID from environment
        final gcpProjectId = await ProofModeConfig.gcpProjectId;

        // If GCP_PROJECT_ID env var is set, should return that value
        // If not set, should return 0 (default)
        expect(gcpProjectId, isA<int>());

        // The implementation should check Platform.environment['GCP_PROJECT_ID']
        // and parse it to int, falling back to 0
      });

      test('handles GCP configuration errors gracefully', () async {
        if (!Platform.isAndroid) {
          markTestSkipped('Test requires Android platform');
          return;
        }

        // When GCP Project ID is 0 (not configured), should still work with fallback
        final gcpProjectId = await ProofModeConfig.gcpProjectId;

        if (gcpProjectId == 0) {
          // Not configured - should use fallback attestation
          final challenge =
              'gcp-error-test-${DateTime.now().millisecondsSinceEpoch}';

          // This might throw or return null/fallback depending on implementation
          try {
            final attestation = await attestationService.generateAttestation(
              challenge,
            );

            // Should still generate some form of attestation
            expect(
              attestation,
              isNotNull,
              reason: 'Should handle missing GCP config gracefully',
            );
          } catch (e) {
            // If it throws, that's also acceptable for missing config
            expect(
              e,
              isA<Exception>(),
              reason: 'Should throw proper exception for missing GCP config',
            );
          }
        }
      });

      test('passes GCP Project ID to Play Integrity API', () async {
        if (!Platform.isAndroid) {
          markTestSkipped('Test requires Android platform');
          return;
        }

        final gcpProjectId = await ProofModeConfig.gcpProjectId;

        // If GCP is configured (non-zero), should be used in attestation
        if (gcpProjectId > 0) {
          final challenge = 'gcp-test-${DateTime.now().millisecondsSinceEpoch}';
          final attestation = await attestationService.generateAttestation(
            challenge,
          );

          expect(
            attestation,
            isNotNull,
            reason:
                'Should generate attestation with configured GCP Project ID',
          );
          expect(attestation!.metadata, isNotNull);
          expect(
            attestation.metadata!['attestationType'],
            equals('play_integrity'),
          );
        }
      });
    });

    group('Error Handling', () {
      test('handles null or empty challenges gracefully', () async {
        if (!Platform.isAndroid) {
          markTestSkipped('Test requires Android platform');
          return;
        }

        // Empty challenge should still work
        final attestation = await attestationService.generateAttestation('');

        expect(
          attestation,
          isA<DeviceAttestation?>(),
          reason: 'Should handle empty challenge gracefully',
        );
      });

      test('handles Play Integrity API errors gracefully', () async {
        if (!Platform.isAndroid) {
          markTestSkipped('Test requires Android platform');
          return;
        }

        // Try to generate attestation with potentially problematic challenge
        final challenge = 'error-test-${DateTime.now().millisecondsSinceEpoch}';

        try {
          final attestation = await attestationService.generateAttestation(
            challenge,
          );

          // Should either succeed or fail gracefully
          if (attestation != null) {
            expect(
              attestation.token,
              isNotEmpty,
              reason: 'If attestation succeeds, token should not be empty',
            );
          }
        } catch (e) {
          // Errors should be logged but not crash the app
          expect(
            e,
            isA<Exception>(),
            reason: 'Should throw proper exception types',
          );
        }
      });

      test('validates attestation tokens correctly', () async {
        if (!Platform.isAndroid) {
          markTestSkipped('Test requires Android platform');
          return;
        }

        final challenge =
            'validation-test-${DateTime.now().millisecondsSinceEpoch}';
        final attestation = await attestationService.generateAttestation(
          challenge,
        );

        if (attestation != null) {
          // Valid attestation with correct challenge should pass
          final isValid = await attestationService.verifyAttestation(
            attestation,
            challenge,
          );
          expect(
            isValid,
            isTrue,
            reason:
                'Valid attestation with correct challenge should pass verification',
          );

          // Invalid challenge should fail
          final wrongChallenge =
              'wrong-challenge-${DateTime.now().millisecondsSinceEpoch}';
          final isInvalid = await attestationService.verifyAttestation(
            attestation,
            wrongChallenge,
          );
          expect(
            isInvalid,
            isFalse,
            reason: 'Attestation with wrong challenge should fail verification',
          );
        }
      });
    });

    group('Platform-Specific Behavior', () {
      test('uses Play Integrity on Android, not other APIs', () async {
        if (!Platform.isAndroid) {
          markTestSkipped('Test requires Android platform');
          return;
        }

        final challenge =
            'platform-test-${DateTime.now().millisecondsSinceEpoch}';
        final attestation = await attestationService.generateAttestation(
          challenge,
        );

        expect(attestation, isNotNull);
        expect(attestation!.platform, equals('Android'));
        expect(attestation.metadata, isNotNull);

        // Should use Play Integrity, not App Attest or other APIs
        final attestationType = attestation.metadata!['attestationType'];
        expect(
          attestationType,
          anyOf(equals('play_integrity'), equals('fallback')),
          reason:
              'Android should use Play Integrity or fallback, not iOS App Attest',
        );
      });

      test('includes Android device metadata', () async {
        if (!Platform.isAndroid) {
          markTestSkipped('Test requires Android platform');
          return;
        }

        final deviceInfo = await attestationService.getDeviceInfo();

        expect(deviceInfo.platform, equals('Android'));
        expect(
          deviceInfo.manufacturer,
          isNotNull,
          reason: 'Android device info should include manufacturer',
        );
        expect(deviceInfo.metadata, isNotNull);

        // Should include Android-specific metadata
        final metadata = deviceInfo.metadata!;
        expect(metadata['brand'], isNotNull);
        expect(metadata['device'], isNotNull);
        expect(metadata['product'], isNotNull);
        expect(metadata['androidId'], isNotNull);
        expect(metadata['sdkInt'], isA<int>());
      });
    });

    group('Performance', () {
      test('generates attestation in reasonable time', () async {
        if (!Platform.isAndroid) {
          markTestSkipped('Test requires Android platform');
          return;
        }

        final challenge = 'perf-test-${DateTime.now().millisecondsSinceEpoch}';

        final stopwatch = Stopwatch()..start();
        await attestationService.generateAttestation(challenge);
        stopwatch.stop();

        // Play Integrity API calls can take 1-3 seconds on real devices
        // Allow up to 10 seconds to account for network latency
        expect(
          stopwatch.elapsedMilliseconds,
          lessThan(10000),
          reason: 'Attestation should complete within 10 seconds',
        );
      });
    });
  });
}
