// ABOUTME: Performance benchmarks for ProofMode operations
// ABOUTME: Measures frame capture overhead, signing performance, and memory usage

import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/services/proofmode_session_service.dart';
import 'package:openvine/services/proofmode_key_service.dart';
import 'package:openvine/services/proofmode_attestation_service.dart';
import 'package:openvine/utils/nostr_encoding.dart';
import 'package:crypto/crypto.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ProofMode Performance Benchmarks', () {
    late ProofModeKeyService keyService;
    late ProofModeAttestationService attestationService;
    late ProofModeSessionService sessionService;

    setUpAll(() async {
      keyService = ProofModeKeyService();
      attestationService = ProofModeAttestationService();
      await attestationService.initialize();

      sessionService = ProofModeSessionService(keyService, attestationService);
    });

    group('Frame Capture Performance', () {
      test('should capture 180 frames (6s at 30fps) within 500ms', () async {
        // Arrange: Start session
        final sessionId = await sessionService.startSession();
        expect(sessionId, isNotNull);
        await sessionService.startRecordingSegment();

        // Create mock frame data (1080p YUV frame ~3MB)
        final frameData = Uint8List(1920 * 1080 * 3 ~/ 2);

        // Act: Capture 180 frames (6 seconds at 30fps)
        final stopwatch = Stopwatch()..start();

        for (int i = 0; i < 180; i++) {
          await sessionService.captureFrame(frameData);
        }

        stopwatch.stop();

        // Assert: Should complete in under 500ms (< 3ms per frame)
        expect(
          stopwatch.elapsedMilliseconds,
          lessThan(500),
          reason:
              'Frame capture took ${stopwatch.elapsedMilliseconds}ms, expected < 500ms',
        );

        print(
          'Frame capture performance: ${stopwatch.elapsedMilliseconds}ms for 180 frames '
          '(${(stopwatch.elapsedMilliseconds / 180).toStringAsFixed(2)}ms per frame)',
        );

        // Cleanup
        await sessionService.endSession();
      });

      test('should handle reduced sample rate (every 3rd frame)', () async {
        // Arrange: Start session with sample rate 3
        final sessionId = await sessionService.startSession(frameSampleRate: 3);
        expect(sessionId, isNotNull);
        await sessionService.startRecordingSegment();

        final frameData = Uint8List(1920 * 1080 * 3 ~/ 2);

        // Act: Capture 180 frames but only sample every 3rd
        final stopwatch = Stopwatch()..start();

        for (int i = 0; i < 180; i++) {
          await sessionService.captureFrame(frameData);
        }

        stopwatch.stop();

        // Assert: Should be faster with reduced sampling
        expect(
          stopwatch.elapsedMilliseconds,
          lessThan(200),
          reason:
              'Sampled capture took ${stopwatch.elapsedMilliseconds}ms, expected < 200ms',
        );

        print(
          'Sampled capture (1/3): ${stopwatch.elapsedMilliseconds}ms for 180 frames',
        );

        // Verify only ~60 hashes captured (180 / 3)
        final session = sessionService.currentSession;
        expect(session, isNotNull);
        expect(session!.frameHashes.length, greaterThan(50));
        expect(session.frameHashes.length, lessThan(70));

        print('Frames actually captured: ${session.frameHashes.length}/180');

        // Cleanup
        await sessionService.endSession();
      });

      test('should respect max frame hash limit', () async {
        // Arrange: Start session with max 100 hashes
        final sessionId = await sessionService.startSession(
          maxFrameHashes: 100,
        );
        expect(sessionId, isNotNull);
        await sessionService.startRecordingSegment();

        final frameData = Uint8List(1920 * 1080 * 3 ~/ 2);

        // Act: Try to capture 180 frames
        for (int i = 0; i < 180; i++) {
          await sessionService.captureFrame(frameData);
        }

        // Assert: Should stop at 100 hashes
        final session = sessionService.currentSession;
        expect(session, isNotNull);
        expect(session!.frameHashes.length, equals(100));

        print(
          'Max hash limit respected: ${session.frameHashes.length}/180 frames captured',
        );

        // Cleanup
        await sessionService.endSession();
      });
    });

    group('Hash Performance', () {
      test('should compute SHA256 hash in under 5ms per frame', () async {
        // Arrange: Create typical frame data (1080p YUV)
        final frameData = Uint8List(1920 * 1080 * 3 ~/ 2);

        // Act: Hash 100 frames
        final stopwatch = Stopwatch()..start();

        for (int i = 0; i < 100; i++) {
          sha256.convert(frameData);
        }

        stopwatch.stop();

        // Assert: Should average under 5ms per hash
        final avgMs = stopwatch.elapsedMilliseconds / 100;
        expect(
          avgMs,
          lessThan(5.0),
          reason:
              'SHA256 hashing averaged ${avgMs.toStringAsFixed(2)}ms per frame, expected < 5ms',
        );

        print(
          'SHA256 performance: ${avgMs.toStringAsFixed(2)}ms per frame (100 frames in ${stopwatch.elapsedMilliseconds}ms)',
        );
      });
    });

    group('Key Generation Performance', () {
      test('should generate Nostr keypair in under 100ms', () async {
        // Act
        final stopwatch = Stopwatch()..start();

        final privateKey = NostrEncoding.generatePrivateKey();
        final publicKey = NostrEncoding.derivePublicKey(privateKey);

        stopwatch.stop();

        // Assert: secp256k1 key generation is very fast
        expect(privateKey.length, equals(64));
        expect(publicKey.length, equals(64));
        expect(
          stopwatch.elapsedMilliseconds,
          lessThan(100),
          reason:
              'Nostr key generation took ${stopwatch.elapsedMilliseconds}ms, expected < 100ms',
        );

        print('Nostr key generation: ${stopwatch.elapsedMilliseconds}ms');
      });
    });

    group('Device Attestation Performance', () {
      test('should generate device attestation in under 1 second', () async {
        // Act
        final stopwatch = Stopwatch()..start();

        final attestation = await attestationService.generateAttestation(
          'test_challenge_nonce',
        );

        stopwatch.stop();

        // Assert
        expect(attestation, isNotNull);
        expect(
          stopwatch.elapsedMilliseconds,
          lessThan(1000),
          reason:
              'Attestation took ${stopwatch.elapsedMilliseconds}ms, expected < 1000ms',
        );

        print(
          'Device attestation: ${stopwatch.elapsedMilliseconds}ms '
          '(${attestation!.platform}, hardware-backed: ${attestation.isHardwareBacked})',
        );
      });
    });

    group('Memory Usage', () {
      test('should not exceed 50KB for 180 frame hashes', () async {
        // Arrange
        await sessionService.startSession();
        await sessionService.startRecordingSegment();

        final frameData = Uint8List(1920 * 1080 * 3 ~/ 2);

        // Act: Capture 180 frames
        for (int i = 0; i < 180; i++) {
          await sessionService.captureFrame(frameData);
        }

        // Assert: Calculate memory usage
        final session = sessionService.currentSession;
        expect(session, isNotNull);

        // Each SHA256 hash is 64 hex characters = 64 bytes
        // 180 hashes * 64 bytes = 11,520 bytes ≈ 11KB
        final expectedMemory = session!.frameHashes.length * 64;
        expect(expectedMemory, lessThan(50 * 1024)); // < 50KB

        print(
          'Frame hash memory usage: ${(expectedMemory / 1024).toStringAsFixed(2)}KB '
          'for ${session.frameHashes.length} hashes',
        );

        // Cleanup
        await sessionService.endSession();
      });
    });

    group('Full Recording Simulation', () {
      test('should handle complete 6-second recording lifecycle', () async {
        // Act: Simulate full recording lifecycle
        final totalStopwatch = Stopwatch()..start();

        // 1. Start session
        final sessionStart = Stopwatch()..start();
        await sessionService.startSession();
        await sessionService.startRecordingSegment();
        sessionStart.stop();

        // 2. Record 6 seconds at 30fps with interactions
        final captureStopwatch = Stopwatch()..start();
        final frameData = Uint8List(1920 * 1080 * 3 ~/ 2);

        for (int i = 0; i < 180; i++) {
          await sessionService.captureFrame(frameData);

          // Simulate user interaction every 60 frames
          if (i % 60 == 0) {
            await sessionService.recordInteraction('touch', 100.0, 200.0);
          }
        }
        captureStopwatch.stop();

        // 3. Pause and resume
        await sessionService.stopRecordingSegment();
        await Future.delayed(
          const Duration(milliseconds: 100),
        ); // Simulate pause
        await sessionService.startRecordingSegment();

        // 4. Record another second
        for (int i = 0; i < 30; i++) {
          await sessionService.captureFrame(frameData);
        }

        // 5. Finalize
        await sessionService.stopRecordingSegment();
        final finalizeStopwatch = Stopwatch()..start();
        final manifest = await sessionService.finalizeSession(
          'final_video_hash',
        );
        finalizeStopwatch.stop();

        totalStopwatch.stop();

        // Assert: Complete flow should be performant
        expect(manifest, isNotNull);
        expect(manifest!.segments.length, equals(2)); // Two recording segments
        expect(
          manifest.interactions.length,
          equals(4),
        ); // 3 during recording + pause

        print('\n=== Full Recording Performance ===');
        print('Session start: ${sessionStart.elapsedMilliseconds}ms');
        print(
          'Frame capture (210 frames): ${captureStopwatch.elapsedMilliseconds}ms',
        );
        print('Session finalize: ${finalizeStopwatch.elapsedMilliseconds}ms');
        print('Total overhead: ${totalStopwatch.elapsedMilliseconds}ms');
        print('Segments: ${manifest.segments.length}');
        print(
          'Frame hashes: ${manifest.segments.fold(0, (sum, s) => sum + s.frameHashes.length)}',
        );
        print('Interactions: ${manifest.interactions.length}');
        print('Recording duration: ${manifest.recordingDuration.inSeconds}s');
        print('==================================\n');

        // Total ProofMode overhead should be under 2 seconds for 6-second video
        expect(totalStopwatch.elapsedMilliseconds, lessThan(2000));
      });
    });
  });
}
