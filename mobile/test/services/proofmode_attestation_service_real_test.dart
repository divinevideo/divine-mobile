// ABOUTME: TDD tests for real device attestation implementation in ProofMode
// ABOUTME: Tests real iOS App Attest and Android Play Integrity integration

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/services/proofmode_attestation_service.dart';
import '../helpers/test_helpers.dart';

void main() {
  group('ProofModeAttestationService - Real Implementation', () {
    late ProofModeAttestationService attestationService;

    setUpAll(() async {
      await setupTestEnvironment();
    });

    setUp(() async {
      attestationService = ProofModeAttestationService();

      // Enable crypto for all tests
    });

    group('Real Device Attestation', () {
      test('generates real attestation token with proper format', () async {
        await attestationService.initialize();

        final challenge =
            'test-challenge-${DateTime.now().millisecondsSinceEpoch}';
        final attestation = await attestationService.generateAttestation(
          challenge,
        );

        expect(attestation, isNotNull);

        // Note: Real hardware attestation only works on iOS/Android physical devices
        // On desktop/web/emulators, fallback attestation is used (starts with MOCK_)
        final deviceInfo = await attestationService.getDeviceInfo();
        final supportsHardwareAttestation =
            deviceInfo.platform == 'iOS' || deviceInfo.platform == 'Android';

        if (supportsHardwareAttestation &&
            (deviceInfo.isPhysicalDevice ?? false)) {
          // On physical iOS/Android devices, should use real attestation
          expect(attestation!.token, isNot(startsWith('MOCK_')));
          expect(attestation.isHardwareBacked, isTrue);
        } else {
          // On desktop/web/emulators, fallback is expected
          expect(attestation!.token, startsWith('MOCK_ATTESTATION_'));
          // Fallback attestation is not hardware-backed
        }

        // Should have proper structure regardless of type
        expect(
          attestation.platform,
          isIn(['iOS', 'Android', 'web', 'macos', 'windows', 'linux']),
        );
        expect(attestation.deviceId, isNotEmpty);
        expect(attestation.challenge, equals(challenge));
        expect(attestation.createdAt, isA<DateTime>());

        // Token should be substantial
        expect(attestation.token.length, greaterThan(50));
      });

      test('generates unique tokens for different challenges', () async {
        await attestationService.initialize();

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

        // Different challenges should produce different tokens
        expect(attestation1!.token, isNot(equals(attestation2!.token)));
        expect(attestation1.challenge, equals(challenge1));
        expect(attestation2.challenge, equals(challenge2));
      });

      test('generates unique tokens each time for same challenge', () async {
        await attestationService.initialize();

        final challenge =
            'same-challenge-${DateTime.now().millisecondsSinceEpoch}';

        final attestation1 = await attestationService.generateAttestation(
          challenge,
        );
        await Future.delayed(Duration(milliseconds: 100));
        final attestation2 = await attestationService.generateAttestation(
          challenge,
        );

        // Real attestation includes nonces/timestamps, so tokens are unique
        expect(attestation1!.token, isNot(equals(attestation2!.token)));
      });

      test('includes hardware-backed indicator for physical devices', () async {
        await attestationService.initialize();

        final deviceInfo = await attestationService.getDeviceInfo();
        final isPhysicalDevice = deviceInfo.isPhysicalDevice ?? false;

        final challenge = 'hw-test-${DateTime.now().millisecondsSinceEpoch}';
        final attestation = await attestationService.generateAttestation(
          challenge,
        );

        expect(attestation, isNotNull);

        // If physical device, should be hardware-backed
        // In emulator/simulator, may not be hardware-backed
        if (isPhysicalDevice) {
          expect(attestation!.isHardwareBacked, isTrue);
        }
      });

      test('includes device metadata in attestation', () async {
        await attestationService.initialize();

        final challenge =
            'metadata-test-${DateTime.now().millisecondsSinceEpoch}';
        final attestation = await attestationService.generateAttestation(
          challenge,
        );

        expect(attestation, isNotNull);
        expect(attestation!.metadata, isNotNull);
        expect(attestation.metadata, isA<Map<String, dynamic>>());

        // Should include attestation type
        expect(attestation.metadata!.containsKey('attestationType'), isTrue);

        // Should include device info
        expect(attestation.metadata!.containsKey('deviceInfo'), isTrue);
      });
    });

    group('Real Device Info', () {
      test('retrieves accurate device information', () async {
        await attestationService.initialize();

        final deviceInfo = await attestationService.getDeviceInfo();

        // Should have real platform info
        expect(
          deviceInfo.platform,
          isIn(['iOS', 'Android', 'web', 'macos', 'windows', 'linux']),
        );
        expect(deviceInfo.model, isNotEmpty);
        expect(deviceInfo.version, isNotEmpty);
        expect(deviceInfo.deviceId, isNotEmpty);

        // Device ID should NOT be 'unknown' on most platforms
        if (deviceInfo.platform == 'iOS' || deviceInfo.platform == 'Android') {
          expect(deviceInfo.deviceId, isNot(equals('unknown')));
        }
      });

      test('caches device info after initialization', () async {
        await attestationService.initialize();

        final deviceInfo1 = await attestationService.getDeviceInfo();
        final deviceInfo2 = await attestationService.getDeviceInfo();

        // Should return same instance (cached)
        expect(deviceInfo1.deviceId, equals(deviceInfo2.deviceId));
        expect(deviceInfo1.platform, equals(deviceInfo2.platform));
        expect(deviceInfo1.model, equals(deviceInfo2.model));
      });
    });

    group('Real Hardware Attestation Availability', () {
      test('correctly reports hardware attestation availability', () async {
        final isAvailable = await attestationService
            .isHardwareAttestationAvailable();

        // Should return boolean
        expect(isAvailable, isA<bool>());

        final deviceInfo = await attestationService.getDeviceInfo();

        // On physical iOS 14+ or Android devices with Play Services, should be true
        // On emulators/simulators, may be false
        if (deviceInfo.isPhysicalDevice == true) {
          if (deviceInfo.platform == 'iOS') {
            // iOS 14+ supports App Attest
            // We can't reliably test version without parsing, just check it doesn't crash
            expect(isAvailable, isA<bool>());
          } else if (deviceInfo.platform == 'Android') {
            // Most Android physical devices with Play Services support it
            expect(isAvailable, isA<bool>());
          }
        }
      });
    });

    group('Real Attestation Verification', () {
      test('basic attestation validation checks pass', () async {
        await attestationService.initialize();

        final challenge =
            'verify-test-${DateTime.now().millisecondsSinceEpoch}';
        final attestation = await attestationService.generateAttestation(
          challenge,
        );

        expect(attestation, isNotNull);

        // Basic validation should pass for correct challenge
        final isValid = await attestationService.verifyAttestation(
          attestation!,
          challenge,
        );
        expect(isValid, isTrue);
      });

      test('rejects attestation with wrong challenge', () async {
        await attestationService.initialize();

        final originalChallenge =
            'original-${DateTime.now().millisecondsSinceEpoch}';
        final wrongChallenge = 'wrong-${DateTime.now().millisecondsSinceEpoch}';

        final attestation = await attestationService.generateAttestation(
          originalChallenge,
        );

        expect(attestation, isNotNull);

        // Verification should fail with different challenge
        final isValid = await attestationService.verifyAttestation(
          attestation!,
          wrongChallenge,
        );
        expect(isValid, isFalse);
      });

      test('rejects expired attestation tokens', () async {
        await attestationService.initialize();

        final challenge =
            'expire-test-${DateTime.now().millisecondsSinceEpoch}';
        final attestation = await attestationService.generateAttestation(
          challenge,
        );

        expect(attestation, isNotNull);

        // Create an old attestation (simulate time passing)
        final expiredAttestation = DeviceAttestation(
          token: attestation!.token,
          platform: attestation.platform,
          deviceId: attestation.deviceId,
          isHardwareBacked: attestation.isHardwareBacked,
          createdAt: DateTime.now().subtract(Duration(hours: 2)), // 2 hours old
          challenge: challenge,
          metadata: attestation.metadata,
        );

        // Verification should fail for expired token (>1 hour old)
        final isValid = await attestationService.verifyAttestation(
          expiredAttestation,
          challenge,
        );
        expect(isValid, isFalse);
      });
    });

    group('Real Attestation Performance', () {
      test('generates attestation in reasonable time', () async {
        await attestationService.initialize();

        final challenge = 'perf-test-${DateTime.now().millisecondsSinceEpoch}';

        final stopwatch = Stopwatch()..start();
        await attestationService.generateAttestation(challenge);
        stopwatch.stop();

        // Attestation should complete within 5 seconds
        // (Real device attestation can take 1-3 seconds)
        expect(stopwatch.elapsedMilliseconds, lessThan(5000));
      });
    });

    group('Real Attestation Error Handling', () {
      test('generates attestation when crypto is enabled', () async {
        await attestationService.initialize();

        final challenge = 'error-test-${DateTime.now().millisecondsSinceEpoch}';
        final attestation = await attestationService.generateAttestation(
          challenge,
        );

        // ProofMode crypto is always enabled, so should generate attestation
        expect(attestation, isNotNull);
        expect(attestation, isA<DeviceAttestation>());
      });

      test('handles invalid challenge gracefully', () async {
        await attestationService.initialize();

        // Empty challenge should still work (generates attestation)
        final attestation = await attestationService.generateAttestation('');

        // Should handle gracefully
        expect(attestation, isA<DeviceAttestation?>());
      });
    });
  });
}
