// ABOUTME: TDD tests for ProofMode manifest generation with PGP signing
// ABOUTME: Tests proof manifest creation, frame hash inclusion, and PGP signature verification

import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/services/proofmode_session_service.dart';
import 'package:openvine/services/proofmode_key_service.dart';
import 'package:openvine/services/proofmode_attestation_service.dart';
import '../helpers/test_helpers.dart';

void main() {
  group('ProofMode Manifest Generation', () {
    late ProofModeSessionService sessionService;
    late ProofModeKeyService keyService;

    setUpAll(() async {
      await setupTestEnvironment();
    });

    setUp(() async {
      keyService = ProofModeKeyService();
      final attestationService = ProofModeAttestationService();
      await keyService.initialize();
      await attestationService.initialize();

      sessionService = ProofModeSessionService(keyService, attestationService);
    });

    test('generates manifest with frame hashes from recording', () async {
      await sessionService.startSession();
      await sessionService.startRecordingSegment();

      // Capture some frames
      await sessionService.captureFrame(Uint8List.fromList([1, 2, 3]));
      await sessionService.captureFrame(Uint8List.fromList([4, 5, 6]));

      await sessionService.stopRecordingSegment();

      final manifest = await sessionService.finalizeSession('video_hash_123');

      expect(manifest, isNotNull);
      expect(manifest!.segments.length, equals(1));
      expect(manifest.segments[0].frameHashes.length, equals(2));
      expect(manifest.finalVideoHash, equals('video_hash_123'));
    });

    test('manifest includes session metadata', () async {
      await sessionService.startSession();
      await sessionService.startRecordingSegment();

      await sessionService.captureFrame(Uint8List.fromList([1]));

      await sessionService.stopRecordingSegment();

      final manifest = await sessionService.finalizeSession('video_hash_abc');

      expect(manifest, isNotNull);
      expect(manifest!.sessionId, isNotEmpty);
      expect(manifest.challengeNonce, isNotEmpty);
      expect(manifest.vineSessionStart, isA<DateTime>());
      expect(manifest.vineSessionEnd, isA<DateTime>());
      expect(manifest.totalDuration, isA<Duration>());
      expect(manifest.recordingDuration, isA<Duration>());
    });

    test('manifest includes device attestation', () async {
      await sessionService.startSession();
      await sessionService.startRecordingSegment();

      await sessionService.captureFrame(Uint8List.fromList([1]));

      await sessionService.stopRecordingSegment();

      final manifest = await sessionService.finalizeSession('video_hash_xyz');

      expect(manifest, isNotNull);
      expect(manifest!.deviceAttestation, isNotNull);
      expect(manifest.deviceAttestation!.token, isNotEmpty);
      expect(
        manifest.deviceAttestation!.challenge,
        equals(manifest.challengeNonce),
      );
    });

    test('manifest is signed with PGP key', () async {
      await sessionService.startSession();
      await sessionService.startRecordingSegment();

      await sessionService.captureFrame(Uint8List.fromList([1]));

      await sessionService.stopRecordingSegment();

      final manifest = await sessionService.finalizeSession(
        'video_hash_signed',
      );

      expect(manifest, isNotNull);
      expect(manifest!.pgpSignature, isNotNull);
      expect(manifest.pgpSignature!.signature, isNotEmpty);
      expect(manifest.pgpSignature!.publicKeyFingerprint, isNotEmpty);
    });

    test('PGP signature is valid for manifest data', () async {
      await sessionService.startSession();
      await sessionService.startRecordingSegment();

      await sessionService.captureFrame(Uint8List.fromList([1, 2, 3]));

      await sessionService.stopRecordingSegment();

      final manifest = await sessionService.finalizeSession(
        'video_hash_verify',
      );

      expect(manifest, isNotNull);
      expect(manifest!.pgpSignature, isNotNull);

      // Create unsigned manifest JSON for verification
      final unsignedManifest = ProofManifest(
        sessionId: manifest.sessionId,
        challengeNonce: manifest.challengeNonce,
        vineSessionStart: manifest.vineSessionStart,
        vineSessionEnd: manifest.vineSessionEnd,
        segments: manifest.segments,
        pauseProofs: manifest.pauseProofs,
        interactions: manifest.interactions,
        finalVideoHash: manifest.finalVideoHash,
        deviceAttestation: manifest.deviceAttestation,
      );

      final manifestJson = jsonEncode(unsignedManifest.toJson());

      // Verify signature
      final isValid = await keyService.verifySignature(
        manifestJson,
        manifest.pgpSignature!,
      );

      expect(isValid, isTrue);
    });

    test('manifest includes multiple segments with frame hashes', () async {
      await sessionService.startSession();
      await sessionService.startRecordingSegment();

      // First segment
      await sessionService.captureFrame(Uint8List.fromList([1]));
      await sessionService.captureFrame(Uint8List.fromList([2]));

      await sessionService.pauseRecording();

      // Second segment
      await sessionService.resumeRecording();
      await sessionService.captureFrame(Uint8List.fromList([3]));
      await sessionService.captureFrame(Uint8List.fromList([4]));

      await sessionService.stopRecordingSegment();

      final manifest = await sessionService.finalizeSession(
        'video_multi_segment',
      );

      expect(manifest, isNotNull);
      expect(manifest!.segments.length, equals(2));
      expect(manifest.segments[0].frameHashes.length, equals(2));
      expect(manifest.segments[1].frameHashes.length, equals(2));
    });

    test('manifest includes user interactions', () async {
      await sessionService.startSession();
      await sessionService.startRecordingSegment();

      // Record some interactions
      await sessionService.recordInteraction(
        'start',
        100.0,
        200.0,
        pressure: 0.5,
      );
      await sessionService.captureFrame(Uint8List.fromList([1]));
      await sessionService.recordInteraction(
        'stop',
        150.0,
        250.0,
        pressure: 0.7,
      );

      await sessionService.stopRecordingSegment();

      final manifest = await sessionService.finalizeSession(
        'video_with_interactions',
      );

      expect(manifest, isNotNull);
      expect(manifest!.interactions.length, equals(2));
      expect(manifest.interactions[0].interactionType, equals('start'));
      expect(manifest.interactions[0].coordinates['x'], equals(100.0));
      expect(manifest.interactions[0].coordinates['y'], equals(200.0));
      expect(manifest.interactions[0].pressure, equals(0.5));
    });

    test('manifest includes frame timestamps', () async {
      await sessionService.startSession();
      await sessionService.startRecordingSegment();

      final beforeFirst = DateTime.now();
      await sessionService.captureFrame(Uint8List.fromList([1]));
      final afterFirst = DateTime.now();

      await sessionService.stopRecordingSegment();

      final manifest = await sessionService.finalizeSession(
        'video_with_timestamps',
      );

      expect(manifest, isNotNull);
      expect(manifest!.segments[0].frameTimestamps, isNotNull);
      expect(manifest.segments[0].frameTimestamps!.length, equals(1));

      final timestamp = manifest.segments[0].frameTimestamps!.first;
      expect(
        timestamp.isAfter(beforeFirst.subtract(Duration(seconds: 1))),
        isTrue,
      );
      expect(timestamp.isBefore(afterFirst.add(Duration(seconds: 1))), isTrue);
    });

    test('manifest serialization includes all fields', () async {
      await sessionService.startSession();
      await sessionService.startRecordingSegment();

      await sessionService.captureFrame(Uint8List.fromList([1]));
      await sessionService.recordInteraction('touch', 50.0, 75.0);

      await sessionService.stopRecordingSegment();

      final manifest = await sessionService.finalizeSession(
        'video_serialization',
      );

      expect(manifest, isNotNull);

      final json = manifest!.toJson();

      expect(json['sessionId'], isNotEmpty);
      expect(json['challengeNonce'], isNotEmpty);
      expect(json['vineSessionStart'], isNotEmpty);
      expect(json['vineSessionEnd'], isNotEmpty);
      expect(json['segments'], isA<List>());
      expect(json['pauseProofs'], isA<List>());
      expect(json['interactions'], isA<List>());
      expect(json['finalVideoHash'], equals('video_serialization'));
      expect(json['deviceAttestation'], isA<Map>());
      expect(json['pgpSignature'], isA<Map>());
    });

    test('manifest deserialization recreates all data', () async {
      await sessionService.startSession();
      await sessionService.startRecordingSegment();

      await sessionService.captureFrame(Uint8List.fromList([1, 2, 3]));
      await sessionService.recordInteraction('start', 10.0, 20.0);

      await sessionService.stopRecordingSegment();

      final manifest = await sessionService.finalizeSession('video_roundtrip');

      expect(manifest, isNotNull);

      final json = manifest!.toJson();
      final deserialized = ProofManifest.fromJson(json);

      expect(deserialized.sessionId, equals(manifest.sessionId));
      expect(deserialized.challengeNonce, equals(manifest.challengeNonce));
      expect(deserialized.finalVideoHash, equals(manifest.finalVideoHash));
      expect(deserialized.segments.length, equals(manifest.segments.length));
      expect(
        deserialized.interactions.length,
        equals(manifest.interactions.length),
      );
      expect(
        deserialized.deviceAttestation?.token,
        equals(manifest.deviceAttestation?.token),
      );
      expect(
        deserialized.pgpSignature?.signature,
        equals(manifest.pgpSignature?.signature),
      );
    });

    test('tampered manifest fails signature verification', () async {
      await sessionService.startSession();
      await sessionService.startRecordingSegment();

      await sessionService.captureFrame(Uint8List.fromList([1]));

      await sessionService.stopRecordingSegment();

      final manifest = await sessionService.finalizeSession(
        'video_tamper_test',
      );

      expect(manifest, isNotNull);

      // Create tampered manifest JSON
      final tamperedManifest = ProofManifest(
        sessionId: manifest!.sessionId,
        challengeNonce: manifest.challengeNonce,
        vineSessionStart: manifest.vineSessionStart,
        vineSessionEnd: manifest.vineSessionEnd,
        segments: manifest.segments,
        pauseProofs: manifest.pauseProofs,
        interactions: manifest.interactions,
        finalVideoHash: 'TAMPERED_HASH', // Changed!
        deviceAttestation: manifest.deviceAttestation,
      );

      final tamperedJson = jsonEncode(tamperedManifest.toJson());

      // Verification should fail
      final isValid = await keyService.verifySignature(
        tamperedJson,
        manifest.pgpSignature!,
      );

      expect(isValid, isFalse);
    });

    test('manifest includes recording duration calculation', () async {
      await sessionService.startSession();
      await sessionService.startRecordingSegment();

      await sessionService.captureFrame(Uint8List.fromList([1]));

      // Small delay to ensure measurable duration
      await Future.delayed(Duration(milliseconds: 100));

      await sessionService.stopRecordingSegment();

      final manifest = await sessionService.finalizeSession('video_duration');

      expect(manifest, isNotNull);
      expect(manifest!.totalDuration.inMilliseconds, greaterThan(0));
      expect(manifest.recordingDuration.inMilliseconds, greaterThan(0));
      expect(
        manifest.recordingDuration.inMilliseconds,
        lessThanOrEqualTo(manifest.totalDuration.inMilliseconds),
      );
    });
  });
}
