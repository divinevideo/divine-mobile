// ABOUTME: Integration tests for ProofMode camera recording workflows
// ABOUTME: Tests end-to-end ProofMode functionality with camera service integration

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/services/camera_service.dart';
import 'package:openvine/services/proofmode_camera_integration.dart';
import 'package:openvine/services/proofmode_key_service.dart';
import 'package:openvine/services/proofmode_attestation_service.dart';
import 'package:openvine/services/proofmode_session_service.dart';
import 'package:openvine/services/proofmode_config.dart';
import 'package:openvine/services/feature_flag_service.dart';
import 'package:openvine/services/proofmode_human_detection.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../helpers/test_helpers.dart';
import 'dart:io';

void main() {
  group('ProofMode Camera Integration Tests', () {
    late ProofModeCameraIntegration integration;
    late TestCameraService testCameraService;
    late TestProofModeKeyService testKeyService;
    late TestProofModeAttestationService testAttestationService;
    late ProofModeSessionService sessionService;
    late TestFeatureFlagService testFlagService;

    setUpAll(() async {
      await setupTestEnvironment();
    });

    setUp(() async {
      testCameraService = TestCameraService();
      testKeyService = TestProofModeKeyService();
      testAttestationService = TestProofModeAttestationService();
      testFlagService = await TestFeatureFlagService.create();

      sessionService = ProofModeSessionService(
        testKeyService,
        testAttestationService,
      );

      integration = ProofModeCameraIntegration(
        testCameraService,
        testKeyService,
        testAttestationService,
        sessionService,
      );

      ProofModeConfig.initialize(testFlagService);
      await integration.initialize();
    });

    group('Full Recording Workflow', () {
      test(
        'should complete full vine recording with ProofMode enabled',
        () async {
          // Enable all ProofMode features
          testFlagService.setFlags({
            'proofmode_crypto': true,
            'proofmode_capture': true,
            'proofmode_publish': true,
          });

          testKeyService.setMockSignature(
            ProofSignature(
              signature: 'test_signature',
              publicKeyFingerprint: 'test_fingerprint',
              signedAt: DateTime.now(),
            ),
          );

          testAttestationService.setMockAttestation(
            DeviceAttestation(
              token: 'test_token',
              platform: 'test',
              deviceId: 'test_device',
              isHardwareBacked: true,
              createdAt: DateTime.now(),
            ),
          );

          testCameraService.setMockRecordingResult(
            VineRecordingResult(
              videoFile: File('/test/video.mp4'),
              duration: Duration(seconds: 6),
            ),
          );

          // Execute full workflow
          await integration.startRecording();
          expect(integration.hasActiveProofSession, isTrue);
          expect(testCameraService.isRecording, isTrue);

          // Simulate user interactions
          integration.recordTouchInteraction();
          integration.recordTouchInteraction();

          // Complete recording
          final result = await integration.stopRecording();

          // Verify results
          expect(result, isA<ProofModeVineRecordingResult>());
          expect(result.hasProof, isTrue);
          expect(result.proofLevel, isNotNull);
          expect(result.proofManifest, isNotNull);
          expect(
            result.proofManifest!['interactions']?.length ?? 0,
            greaterThanOrEqualTo(2),
          );
          expect(result.proofManifest!['pgpSignature'], isNotNull);
          expect(integration.hasActiveProofSession, isFalse);
        },
      );

      test(
        'should complete recording without ProofMode when disabled',
        () async {
          // Disable ProofMode
          testFlagService.setFlags({
            'proofmode_crypto': false,
            'proofmode_capture': false,
          });

          testCameraService.setMockRecordingResult(
            VineRecordingResult(
              videoFile: File('/test/video.mp4'),
              duration: Duration(seconds: 6),
            ),
          );

          await integration.startRecording();
          expect(integration.hasActiveProofSession, isFalse);
          expect(testCameraService.isRecording, isTrue);

          final result = await integration.stopRecording();

          expect(result.hasProof, isFalse);
          expect(result.proofLevel, equals('unverified'));
          expect(result.proofManifest, isNull);
        },
      );

      test('should handle segmented recording with pauses', () async {
        testFlagService.setFlags({
          'proofmode_crypto': true,
          'proofmode_capture': true,
        });

        testKeyService.setMockSignature(
          ProofSignature(
            signature: 'test_sig',
            publicKeyFingerprint: 'test_fp',
            signedAt: DateTime.now(),
          ),
        );

        testCameraService.setMockRecordingResult(
          VineRecordingResult(
            videoFile: File('/test/segmented_video.mp4'),
            duration: Duration(seconds: 6),
          ),
        );

        // Start recording
        await integration.startRecording();

        // Record first segment
        integration.recordTouchInteraction();

        // Pause
        await integration.pauseRecording();
        await Future.delayed(Duration(milliseconds: 100));

        // Resume for second segment
        await integration.resumeRecording();
        integration.recordTouchInteraction();

        // Pause again
        await integration.pauseRecording();
        await Future.delayed(Duration(milliseconds: 50));

        // Resume for final segment
        await integration.resumeRecording();
        integration.recordTouchInteraction();

        final result = await integration.stopRecording();

        expect(result.hasProof, isTrue);
        expect(
          result.proofManifest!['segments']?.length ?? 0,
          greaterThanOrEqualTo(3),
        );
        expect(
          result.proofManifest!['interactions']?.length ?? 0,
          greaterThanOrEqualTo(3),
        );
      });
    });

    group('Error Handling and Recovery', () {
      test('should recover gracefully from camera service errors', () async {
        testFlagService.setFlags({
          'proofmode_crypto': true,
          'proofmode_capture': true,
        });

        testCameraService.setShouldThrowError(true);

        expect(() => integration.startRecording(), throwsException);
        expect(integration.hasActiveProofSession, isFalse);
      });

      test('should continue recording when ProofMode services fail', () async {
        testFlagService.setFlags({
          'proofmode_crypto': true,
          'proofmode_capture': true,
        });

        testKeyService.setShouldThrowError(true);
        testAttestationService.setShouldThrowError(true);

        testCameraService.setMockRecordingResult(
          VineRecordingResult(
            videoFile: File('/test/video.mp4'),
            duration: Duration(seconds: 6),
          ),
        );

        await integration.startRecording();
        final result = await integration.stopRecording();

        // Recording should succeed even if ProofMode fails
        expect(result, isNotNull);
        expect(result.videoFile.path, equals('/test/video.mp4'));
        // ProofMode should fail gracefully
        expect(result.hasProof, isFalse);
        expect(result.proofLevel, equals('unverified'));
      });

      test('should handle cancellation correctly', () async {
        testFlagService.setFlags({
          'proofmode_crypto': true,
          'proofmode_capture': true,
        });

        await integration.startRecording();
        expect(integration.hasActiveProofSession, isTrue);

        await integration.cancelRecording();
        expect(integration.hasActiveProofSession, isFalse);
      });

      test('should handle multiple start/stop cycles', () async {
        testFlagService.setFlags({
          'proofmode_crypto': true,
          'proofmode_capture': true,
        });

        testCameraService.setMockRecordingResult(
          VineRecordingResult(
            videoFile: File('/test/video1.mp4'),
            duration: Duration(seconds: 6),
          ),
        );

        // First recording
        await integration.startRecording();
        await integration.stopRecording();
        expect(integration.hasActiveProofSession, isFalse);

        // Second recording
        testCameraService.setMockRecordingResult(
          VineRecordingResult(
            videoFile: File('/test/video2.mp4'),
            duration: Duration(seconds: 6),
          ),
        );

        await integration.startRecording();
        final result = await integration.stopRecording();

        expect(result.videoFile.path, equals('/test/video2.mp4'));
        expect(integration.hasActiveProofSession, isFalse);
      });
    });

    group('Proof Level Determination', () {
      test(
        'should assign verified_mobile for hardware-backed attestation',
        () async {
          testFlagService.setFlags({
            'proofmode_crypto': true,
            'proofmode_capture': true,
          });

          testAttestationService.setMockAttestation(
            DeviceAttestation(
              token: 'hw_token',
              platform: 'iOS',
              deviceId: 'device123',
              isHardwareBacked: true,
              createdAt: DateTime.now(),
            ),
          );

          testKeyService.setMockSignature(
            ProofSignature(
              signature: 'sig',
              publicKeyFingerprint: 'fp',
              signedAt: DateTime.now(),
            ),
          );

          testCameraService.setMockRecordingResult(
            VineRecordingResult(
              videoFile: File('/test/video.mp4'),
              duration: Duration(seconds: 6),
            ),
          );

          await integration.startRecording();
          final result = await integration.stopRecording();

          expect(result.proofLevel, equals('verified_mobile'));
        },
      );

      test('should assign verified_web for web platform', () async {
        testFlagService.setFlags({
          'proofmode_crypto': true,
          'proofmode_capture': true,
        });

        testAttestationService.setMockAttestation(
          DeviceAttestation(
            token: 'web_token',
            platform: 'web',
            deviceId: 'browser123',
            isHardwareBacked: false,
            createdAt: DateTime.now(),
          ),
        );

        testKeyService.setMockSignature(
          ProofSignature(
            signature: 'sig',
            publicKeyFingerprint: 'fp',
            signedAt: DateTime.now(),
          ),
        );

        testCameraService.setMockRecordingResult(
          VineRecordingResult(
            videoFile: File('/test/video.mp4'),
            duration: Duration(seconds: 6),
          ),
        );

        await integration.startRecording();
        final result = await integration.stopRecording();

        expect(result.proofLevel, equals('verified_web'));
      });

      test(
        'should assign basic_proof for signed but non-attested content',
        () async {
          testFlagService.setFlags({
            'proofmode_crypto': true,
            'proofmode_capture': true,
          });

          testKeyService.setMockSignature(
            ProofSignature(
              signature: 'sig',
              publicKeyFingerprint: 'fp',
              signedAt: DateTime.now(),
            ),
          );

          // No attestation provided
          testAttestationService.setMockAttestation(null);

          testCameraService.setMockRecordingResult(
            VineRecordingResult(
              videoFile: File('/test/video.mp4'),
              duration: Duration(seconds: 6),
            ),
          );

          await integration.startRecording();
          integration.recordTouchInteraction();
          final result = await integration.stopRecording();

          expect(result.proofLevel, equals('basic_proof'));
        },
      );
    });

    group('Human Activity Integration', () {
      test(
        'should capture natural human interactions during recording',
        () async {
          testFlagService.setFlags({
            'proofmode_crypto': true,
            'proofmode_capture': true,
          });

          testCameraService.setMockRecordingResult(
            VineRecordingResult(
              videoFile: File('/test/video.mp4'),
              duration: Duration(seconds: 6),
            ),
          );

          await integration.startRecording();

          // Simulate natural human touch patterns
          integration.recordTouchInteraction();
          integration.recordTouchInteraction();
          integration.recordTouchInteraction();
          integration.recordTouchInteraction();

          final result = await integration.stopRecording();

          expect(result.hasProof, isTrue);
          expect(
            result.proofManifest!['interactions']?.length ?? 0,
            greaterThanOrEqualTo(4),
          );

          // Verify interactions have natural variation
          final interactions =
              result.proofManifest!['interactions'] as List<dynamic>? ?? [];
          final coords = interactions
              .map((i) => i['coordinates'] as Map<String, dynamic>)
              .toList();

          final xValues = coords.map((c) => c['x']!).toList();
          final yValues = coords.map((c) => c['y']!).toList();

          // Should have some variation (not all identical)
          expect(xValues.toSet().length, greaterThan(1));
          expect(yValues.toSet().length, greaterThan(1));
        },
      );

      test('should detect and flag bot-like interactions', () async {
        testFlagService.setFlags({
          'proofmode_crypto': true,
          'proofmode_capture': true,
        });

        testCameraService.setMockRecordingResult(
          VineRecordingResult(
            videoFile: File('/test/video.mp4'),
            duration: Duration(seconds: 6),
          ),
        );

        await integration.startRecording();

        // Simulate bot-like perfect interactions
        integration.recordTouchInteraction();
        integration.recordTouchInteraction();
        integration.recordTouchInteraction();

        final result = await integration.stopRecording();

        expect(result.hasProof, isTrue);

        // Verify that human detection would flag this as suspicious
        final interactions =
            result.proofManifest!['interactions'] as List<dynamic>? ?? [];
        final userInteractions = interactions.cast<UserInteractionProof>();
        final analysis = ProofModeHumanDetection.analyzeInteractions(
          userInteractions,
        );

        expect(analysis.isHumanLikely, isFalse);
        expect(analysis.redFlags, isNotEmpty);
      });
    });

    group('Performance and Resources', () {
      test('should handle rapid start/stop operations', () async {
        testFlagService.setFlags({
          'proofmode_crypto': true,
          'proofmode_capture': true,
        });

        testCameraService.setMockRecordingResult(
          VineRecordingResult(
            videoFile: File('/test/video.mp4'),
            duration: Duration(seconds: 1),
          ),
        );

        // Rapid operations
        for (int i = 0; i < 5; i++) {
          await integration.startRecording();
          integration.recordTouchInteraction();
          await integration.stopRecording();
        }

        // Should complete without errors
        expect(integration.hasActiveProofSession, isFalse);
      });

      test('should cleanup resources properly on disposal', () async {
        testFlagService.setFlags({
          'proofmode_crypto': true,
          'proofmode_capture': true,
        });

        await integration.startRecording();
        expect(integration.hasActiveProofSession, isTrue);

        integration.dispose();
        expect(integration.hasActiveProofSession, isFalse);
      });
    });
  });
}

/// Test implementation of CameraService
class TestCameraService extends CameraService {
  bool _isRecording = false;
  bool _shouldThrowError = false;
  VineRecordingResult? _mockResult;

  void setMockRecordingResult(VineRecordingResult result) {
    _mockResult = result;
  }

  void setShouldThrowError(bool shouldThrow) {
    _shouldThrowError = shouldThrow;
  }

  @override
  bool get isRecording => _isRecording;

  @override
  Future<void> startRecording() async {
    if (_shouldThrowError) {
      throw Exception('Test camera error');
    }
    _isRecording = true;
  }

  @override
  Future<VineRecordingResult> stopRecording() async {
    if (_shouldThrowError) {
      throw Exception('Test camera error');
    }
    _isRecording = false;
    return _mockResult ??
        VineRecordingResult(
          videoFile: File('/test/default.mp4'),
          duration: Duration(seconds: 6),
        );
  }
}

/// Test implementation of ProofModeKeyService
class TestProofModeKeyService extends ProofModeKeyService {
  ProofSignature? _mockSignature;
  bool _shouldThrowError = false;

  void setMockSignature(ProofSignature signature) {
    _mockSignature = signature;
  }

  void setShouldThrowError(bool shouldThrow) {
    _shouldThrowError = shouldThrow;
  }

  @override
  Future<void> initialize() async {
    if (_shouldThrowError) {
      throw Exception('Test key service error');
    }
  }

  @override
  Future<ProofSignature?> signData(String data) async {
    if (_shouldThrowError) {
      throw Exception('Test key service error');
    }
    return _mockSignature;
  }
}

/// Test implementation of ProofModeAttestationService
class TestProofModeAttestationService extends ProofModeAttestationService {
  DeviceAttestation? _mockAttestation;
  bool _shouldThrowError = false;

  void setMockAttestation(DeviceAttestation? attestation) {
    _mockAttestation = attestation;
  }

  void setShouldThrowError(bool shouldThrow) {
    _shouldThrowError = shouldThrow;
  }

  @override
  Future<void> initialize() async {
    if (_shouldThrowError) {
      throw Exception('Test attestation service error');
    }
  }

  @override
  Future<DeviceAttestation?> generateAttestation(String challenge) async {
    if (_shouldThrowError) {
      throw Exception('Test attestation service error');
    }
    return _mockAttestation;
  }
}

/// Test implementation of FeatureFlagService
class TestFeatureFlagService extends FeatureFlagService {
  final Map<String, bool> _flags = {};

  TestFeatureFlagService._() : super(apiBaseUrl: 'test', prefs: _testPrefs!);

  static SharedPreferences? _testPrefs;

  static Future<TestFeatureFlagService> create() async {
    _testPrefs = await getTestSharedPreferences();
    return TestFeatureFlagService._();
  }

  void setFlags(Map<String, bool> flags) {
    _flags.addAll(flags);
  }

  @override
  Future<bool> isEnabled(
    String flagName, {
    Map<String, dynamic>? attributes,
    bool forceRefresh = false,
  }) async {
    return _flags[flagName] ?? false;
  }
}
