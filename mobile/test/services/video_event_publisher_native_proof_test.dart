// ABOUTME: Test that native ProofMode data from Guardian Project library is published to Nostr
// ABOUTME: Verifies that NativeProofData is correctly added as tags to video events

import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/models/pending_upload.dart';
import 'package:models/models.dart' show NativeProofData;
import 'package:openvine/services/video_event_publisher.dart';
import 'package:openvine/services/upload_manager.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:nostr_sdk/event.dart';

// Mock classes
class MockAuthService extends Mock implements AuthService {}

class MockNostrService extends Mock implements NostrClient {}

class MockUploadManager extends Mock implements UploadManager {}

void main() {
  setUpAll(() {
    // Register fallback values for mocktail
    registerFallbackValue(
      Event.fromJson({
        'id': 'test',
        'pubkey': 'test',
        'created_at': 0,
        'kind': 34236,
        'tags': [],
        'content': '',
        'sig': 'test',
      }),
    );
    registerFallbackValue(UploadStatus.pending);
  });

  group('VideoEventPublisher - Native ProofMode Integration', () {
    late MockNostrService mockNostrService;
    late MockAuthService mockAuthService;
    late MockUploadManager mockUploadManager;
    late VideoEventPublisher publisher;

    setUp(() {
      mockNostrService = MockNostrService();
      mockAuthService = MockAuthService();
      mockUploadManager = MockUploadManager();

      // Mock auth service to return authenticated and create events
      when(() => mockAuthService.isAuthenticated).thenReturn(true);

      // Mock upload manager updateUploadStatus
      when(
        () => mockUploadManager.updateUploadStatus(
          any(),
          any(),
          nostrEventId: any(named: 'nostrEventId'),
        ),
      ).thenAnswer((_) async => {});

      publisher = VideoEventPublisher(
        uploadManager: mockUploadManager,
        nostrService: mockNostrService,
        authService: mockAuthService,
      );
    });

    test('MUST publish native ProofMode data to Nostr tags', () async {
      // Create native proof data (from Guardian Project library)
      final nativeProof = NativeProofData(
        videoHash: 'abc123def456',
        sensorDataCsv: 'timestamp,lat,lon\n2025-01-01,40.7,-74.0',
        pgpSignature:
            '-----BEGIN PGP SIGNATURE-----\ntest\n-----END PGP SIGNATURE-----',
        publicKey:
            '-----BEGIN PGP PUBLIC KEY BLOCK-----\ntest\n-----END PGP PUBLIC KEY BLOCK-----',
        deviceAttestation: 'attestation_token_12345',
        timestamp: '2025-01-01T12:00:00Z',
      );

      // Serialize to JSON (as stored in PendingUpload)
      final proofJson = jsonEncode(nativeProof.toJson());

      // Create upload with native proof data
      final upload =
          PendingUpload.create(
            localVideoPath: '/tmp/test.mp4',
            nostrPubkey: 'pubkey123',
            proofManifestJson: proofJson,
          ).copyWith(
            status: UploadStatus.readyToPublish,
            videoId: 'video123',
            cdnUrl: 'https://cdn.example.com/video.mp4',
          );

      // Mock event creation - capture the event that gets created
      Event? capturedEvent;
      when(
        () => mockAuthService.createAndSignEvent(
          kind: any(named: 'kind'),
          content: any(named: 'content'),
          tags: any(named: 'tags'),
        ),
      ).thenAnswer((invocation) {
        final tags = invocation.namedArguments[#tags] as List<List<String>>;
        final content = invocation.namedArguments[#content] as String;
        capturedEvent = Event.fromJson({
          'id': 'event123',
          'pubkey': 'pubkey123',
          'created_at': DateTime.now().millisecondsSinceEpoch ~/ 1000,
          'kind': 34236,
          'tags': tags,
          'content': content,
          'sig': 'signature123',
        });
        return Future.value(capturedEvent);
      });

      // Mock broadcast to succeed
      when(() => mockNostrService.broadcast(any())).thenAnswer((
        invocation,
      ) async {
        final event = invocation.positionalArguments[0] as Event;
        return NostrBroadcastResult(
          event: event,
          successCount: 1,
          totalRelays: 1,
          results: {'relay1': true},
          errors: {},
        );
      });

      await publisher.publishDirectUpload(upload);
      final publishedEvent = capturedEvent;

      // VERIFY: Event must contain ProofMode tags
      expect(publishedEvent, isNotNull, reason: 'Event should be published');
      expect(publishedEvent!.tags, isNotEmpty, reason: 'Event must have tags');

      // Find ProofMode tags (NIP-145 standard names)
      final proofModeTags = publishedEvent.tags
          .where((tag) => tag.isNotEmpty && tag[0] == 'proofmode')
          .toList();
      final verificationTags = publishedEvent.tags
          .where((tag) => tag.isNotEmpty && tag[0] == 'verification')
          .toList();
      final attestationTags = publishedEvent.tags
          .where((tag) => tag.isNotEmpty && tag[0] == 'device_attestation')
          .toList();
      final pgpTags = publishedEvent.tags
          .where((tag) => tag.isNotEmpty && tag[0] == 'pgp_fingerprint')
          .toList();

      // CRITICAL: Proof data must NOT be dropped
      expect(
        proofModeTags,
        hasLength(1),
        reason: 'MUST have proofmode tag with native proof data',
      );
      expect(
        verificationTags,
        hasLength(1),
        reason: 'MUST have verification level tag',
      );

      // Verify proofmode tag contains the native proof JSON
      final proofModeTagValue = proofModeTags[0][1];
      expect(
        proofModeTagValue,
        isNotEmpty,
        reason: 'Proof manifest must not be empty',
      );

      // Parse and verify it's valid NativeProofData
      final parsedProof = jsonDecode(proofModeTagValue);
      expect(
        parsedProof['videoHash'],
        equals('abc123def456'),
        reason: 'Must contain video hash from native library',
      );
      expect(
        parsedProof['sensorDataCsv'],
        isNotNull,
        reason: 'Must contain sensor data from native library',
      );

      // Verify verification level
      expect(
        verificationTags[0][1],
        equals('verified_mobile'),
        reason: 'Should be verified_mobile with attestation + signature',
      );

      // Verify optional tags if data present
      if (nativeProof.deviceAttestation != null) {
        expect(
          attestationTags,
          hasLength(1),
          reason: 'Must have attestation tag when native proof has it',
        );
        expect(attestationTags[0][1], equals('attestation_token_12345'));
      }

      if (nativeProof.pgpFingerprint != null) {
        expect(
          pgpTags,
          hasLength(1),
          reason: 'Must have PGP fingerprint tag when available',
        );
      }
    });

    test('MUST NOT drop ProofMode data when field names differ', () async {
      // This tests the bug: ProofManifest used 'finalVideoHash', NativeProofData uses 'videoHash'
      // Both should work - we must never silently drop proof data!

      final nativeProof = NativeProofData(
        videoHash: 'test_hash_123',
        pgpSignature: 'signature',
        publicKey: 'public_key',
      );

      final upload =
          PendingUpload.create(
            localVideoPath: '/tmp/test.mp4',
            nostrPubkey: 'pubkey123',
            proofManifestJson: jsonEncode(nativeProof.toJson()),
          ).copyWith(
            status: UploadStatus.readyToPublish,
            videoId: 'video123',
            cdnUrl: 'https://cdn.example.com/video.mp4',
          );

      // Mock event creation
      Event? capturedEvent;
      when(
        () => mockAuthService.createAndSignEvent(
          kind: any(named: 'kind'),
          content: any(named: 'content'),
          tags: any(named: 'tags'),
        ),
      ).thenAnswer((invocation) {
        final tags = invocation.namedArguments[#tags] as List<List<String>>;
        final content = invocation.namedArguments[#content] as String;
        capturedEvent = Event.fromJson({
          'id': 'event456',
          'pubkey': 'pubkey123',
          'created_at': DateTime.now().millisecondsSinceEpoch ~/ 1000,
          'kind': 34236,
          'tags': tags,
          'content': content,
          'sig': 'signature456',
        });
        return Future.value(capturedEvent);
      });

      when(() => mockNostrService.broadcast(any())).thenAnswer((
        invocation,
      ) async {
        final event = invocation.positionalArguments[0] as Event;
        return NostrBroadcastResult(
          event: event,
          successCount: 1,
          totalRelays: 1,
          results: {'relay1': true},
          errors: {},
        );
      });

      await publisher.publishDirectUpload(upload);
      final publishedEvent = capturedEvent;

      // CRITICAL ASSERTION: Proof data MUST be published
      final proofModeTags = publishedEvent!.tags
          .where((tag) => tag.isNotEmpty && tag[0] == 'proofmode')
          .toList();

      expect(
        proofModeTags,
        hasLength(1),
        reason: 'MUST NEVER drop ProofMode data due to parsing errors',
      );

      final proofJson = proofModeTags[0][1];
      expect(
        proofJson,
        contains('videoHash'),
        reason: 'Must contain native proof data',
      );
      expect(
        proofJson,
        contains('test_hash_123'),
        reason: 'Must contain actual hash value',
      );
    });

    test('handles missing ProofMode data gracefully', () async {
      // Upload without ProofMode data should still publish successfully
      final upload =
          PendingUpload.create(
            localVideoPath: '/tmp/test.mp4',
            nostrPubkey: 'pubkey123',
          ).copyWith(
            status: UploadStatus.readyToPublish,
            videoId: 'video123',
            cdnUrl: 'https://cdn.example.com/video.mp4',
          );

      Event? capturedEvent;
      when(
        () => mockAuthService.createAndSignEvent(
          kind: any(named: 'kind'),
          content: any(named: 'content'),
          tags: any(named: 'tags'),
        ),
      ).thenAnswer((invocation) {
        final tags = invocation.namedArguments[#tags] as List<List<String>>;
        final content = invocation.namedArguments[#content] as String;
        capturedEvent = Event.fromJson({
          'id': 'event789',
          'pubkey': 'pubkey123',
          'created_at': DateTime.now().millisecondsSinceEpoch ~/ 1000,
          'kind': 34236,
          'tags': tags,
          'content': content,
          'sig': 'signature789',
        });
        return Future.value(capturedEvent);
      });

      when(() => mockNostrService.broadcast(any())).thenAnswer((
        invocation,
      ) async {
        final event = invocation.positionalArguments[0] as Event;
        return NostrBroadcastResult(
          event: event,
          successCount: 1,
          totalRelays: 1,
          results: {'relay1': true},
          errors: {},
        );
      });

      final result = await publisher.publishDirectUpload(upload);
      final publishedEvent = capturedEvent;

      expect(
        result,
        isTrue,
        reason: 'Should publish successfully without ProofMode',
      );
      expect(publishedEvent, isNotNull);

      // Should have NO ProofMode tags
      final proofModeTags = publishedEvent!.tags
          .where((tag) => tag.isNotEmpty && tag[0] == 'proofmode')
          .toList();
      expect(
        proofModeTags,
        isEmpty,
        reason: 'Should not have ProofMode tags when no proof data',
      );
    });
  });
}
