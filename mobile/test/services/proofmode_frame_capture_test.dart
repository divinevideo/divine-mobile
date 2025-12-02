// ABOUTME: TDD tests for ProofMode frame capture and hashing during video recording
// ABOUTME: Tests real-time frame sampling and SHA256 hashing integration with camera service

import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/services/proofmode_session_service.dart';
import 'package:openvine/services/proofmode_key_service.dart';
import 'package:openvine/services/proofmode_attestation_service.dart';
import '../helpers/test_helpers.dart';

void main() {
  group('ProofMode Frame Capture', () {
    late ProofModeSessionService sessionService;

    setUpAll(() async {
      await setupTestEnvironment();
    });

    setUp(() async {
      // Enable crypto for all tests

      final keyService = ProofModeKeyService();
      final attestationService = ProofModeAttestationService();
      await keyService.initialize();
      await attestationService.initialize();

      sessionService = ProofModeSessionService(keyService, attestationService);
    });

    test('captures frame data from camera during recording', () async {
      // Start a proof session
      await sessionService.startSession();
      await sessionService.startRecordingSegment();

      // Simulate frame capture
      final mockFrameData = Uint8List.fromList(List.generate(100, (i) => i));
      await sessionService.captureFrame(mockFrameData);

      // Should have captured frame
      final session = sessionService.currentSession;
      expect(session, isNotNull);
      expect(session!.frameHashes.length, equals(1));
    });

    test('generates SHA256 hash for captured frames', () async {
      await sessionService.startSession();
      await sessionService.startRecordingSegment();

      final mockFrameData = Uint8List.fromList([1, 2, 3, 4, 5]);
      await sessionService.captureFrame(mockFrameData);

      final session = sessionService.currentSession!;
      final hash = session.frameHashes.first;

      // SHA256 hash should be 64 hex characters
      expect(hash.length, equals(64));
      expect(hash, matches(RegExp(r'^[0-9a-f]{64}$')));
    });

    test('samples frames at configured rate during recording', () async {
      await sessionService.startSession(frameSampleRate: 5); // Every 5th frame
      await sessionService.startRecordingSegment();

      // Capture 10 frames
      for (int i = 0; i < 10; i++) {
        final frameData = Uint8List.fromList([i]);
        await sessionService.captureFrame(frameData);
      }

      final session = sessionService.currentSession!;
      // Should only capture every 5th frame (frames 0, 5)
      expect(session.frameHashes.length, equals(2));
    });

    test('associates frame hashes with recording segments', () async {
      await sessionService.startSession();
      await sessionService.startRecordingSegment();

      // Capture frames in first segment
      await sessionService.captureFrame(Uint8List.fromList([1]));
      await sessionService.captureFrame(Uint8List.fromList([2]));

      // Pause recording
      await sessionService.pauseRecording();

      // Resume recording (new segment)
      await sessionService.resumeRecording();

      await sessionService.captureFrame(Uint8List.fromList([3]));

      // Stop the second segment to finalize it
      await sessionService.stopRecordingSegment();

      final session = sessionService.currentSession!;
      expect(session.segments.length, equals(2));
      expect(session.segments[0].frameHashes.length, equals(2));
      expect(session.segments[1].frameHashes.length, equals(1));
    });

    test('handles frame capture errors gracefully', () async {
      await sessionService.startSession();

      // Attempt to capture null/invalid frame
      expect(
        () => sessionService.captureFrame(null),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('stops frame capture when session ends', () async {
      await sessionService.startSession();
      await sessionService.startRecordingSegment();

      await sessionService.captureFrame(Uint8List.fromList([1]));

      await sessionService.endSession();

      // Attempting to capture after session ends should fail
      expect(
        () => sessionService.captureFrame(Uint8List.fromList([2])),
        throwsA(isA<StateError>()),
      );
    });

    test('frame hashes are deterministic for identical data', () async {
      await sessionService.startSession();
      await sessionService.startRecordingSegment();

      final frameData = Uint8List.fromList([1, 2, 3, 4, 5]);

      await sessionService.captureFrame(frameData);
      final hash1 = sessionService.currentSession!.frameHashes.first;

      await sessionService.endSession();
      await sessionService.startSession();
      await sessionService.startRecordingSegment();

      await sessionService.captureFrame(frameData);
      final hash2 = sessionService.currentSession!.frameHashes.first;

      // Same data should produce same hash
      expect(hash1, equals(hash2));
    });

    test('frame hashes differ for different data', () async {
      await sessionService.startSession();
      await sessionService.startRecordingSegment();

      await sessionService.captureFrame(Uint8List.fromList([1, 2, 3]));
      await sessionService.captureFrame(Uint8List.fromList([4, 5, 6]));

      final hashes = sessionService.currentSession!.frameHashes;
      expect(hashes[0], isNot(equals(hashes[1])));
    });

    test('tracks frame capture timing', () async {
      await sessionService.startSession();
      await sessionService.startRecordingSegment();

      final beforeCapture = DateTime.now();
      await sessionService.captureFrame(Uint8List.fromList([1]));
      final afterCapture = DateTime.now();

      await sessionService.stopRecordingSegment();

      final session = sessionService.currentSession!;
      expect(session.segments.first.frameTimestamps, isNotNull);
      expect(session.segments.first.frameTimestamps!.length, equals(1));

      final timestamp = session.segments.first.frameTimestamps!.first;
      expect(
        timestamp.isAfter(beforeCapture.subtract(Duration(seconds: 1))),
        isTrue,
      );
      expect(
        timestamp.isBefore(afterCapture.add(Duration(seconds: 1))),
        isTrue,
      );
    });

    test('limits total frame hashes to prevent memory issues', () async {
      await sessionService.startSession(
        frameSampleRate: 1,
        maxFrameHashes: 100,
      );
      await sessionService.startRecordingSegment();

      // Try to capture more than max
      for (int i = 0; i < 150; i++) {
        await sessionService.captureFrame(Uint8List.fromList([i % 256]));
      }

      final session = sessionService.currentSession!;
      // Should not exceed max
      expect(session.frameHashes.length, lessThanOrEqualTo(100));
    });
  });

  group('ProofMode Frame Capture Performance', () {
    late ProofModeSessionService sessionService;

    setUpAll(() async {
      await setupTestEnvironment();
    });

    setUp(() async {
      final keyService = ProofModeKeyService();
      final attestationService = ProofModeAttestationService();
      await keyService.initialize();
      await attestationService.initialize();

      sessionService = ProofModeSessionService(keyService, attestationService);
    });

    test('frame hashing completes in reasonable time', () async {
      await sessionService.startSession();
      await sessionService.startRecordingSegment();

      final largeFrame = Uint8List(1920 * 1080 * 4); // HD frame size
      for (int i = 0; i < largeFrame.length; i++) {
        largeFrame[i] = i % 256;
      }

      final stopwatch = Stopwatch()..start();
      await sessionService.captureFrame(largeFrame);
      stopwatch.stop();

      // Frame hashing should be fast (< 100ms even for HD)
      expect(stopwatch.elapsedMilliseconds, lessThan(100));
    });

    test('frame capture does not block camera operations', () async {
      await sessionService.startSession();
      await sessionService.startRecordingSegment();

      // Capture multiple frames rapidly
      final stopwatch = Stopwatch()..start();
      for (int i = 0; i < 10; i++) {
        final frame = Uint8List.fromList([i]);
        await sessionService.captureFrame(frame);
      }
      stopwatch.stop();

      // 10 captures should be very fast (< 50ms total)
      expect(stopwatch.elapsedMilliseconds, lessThan(50));
    });
  });
}
