// ABOUTME: Test that native ProofMode data from Guardian Project library is published to Nostr
// ABOUTME: Verifies that NativeProofData is correctly added as tags to video events

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart' show NativeProofData;
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/event.dart';
import 'package:nostr_sdk/filter.dart';
import 'package:nostr_sdk/relay/publish_outcome.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/ios_device_attestation_service.dart';
import 'package:openvine/services/upload_manager.dart';
import 'package:openvine/services/video_event_publisher.dart';

// Mock classes
class MockAuthService extends Mock implements AuthService {}

class MockNostrService extends Mock implements NostrClient {}

class MockUploadManager extends Mock implements UploadManager {}

class _FakeFilter extends Fake implements Filter {}

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
    registerFallbackValue(_FakeFilter());
    registerFallbackValue(<Filter>[]);
    registerFallbackValue(Duration.zero);
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
      when(() => mockNostrService.isInitialized).thenReturn(true);
      when(() => mockNostrService.configuredRelayCount).thenReturn(1);
      when(() => mockNostrService.connectedRelayCount).thenReturn(1);
      when(
        () => mockNostrService.configuredRelays,
      ).thenReturn(const ['wss://relay.divine.video']);
      when(
        () => mockNostrService.connectedRelays,
      ).thenReturn(const ['wss://relay.divine.video']);
      when(() => mockNostrService.publicKey).thenReturn('');

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
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);

      // Create native proof data (from Guardian Project library)
      const nativeProof = NativeProofData(
        videoHash: 'abc123def456',
        sensorDataCsv: 'timestamp,lat,lon\n2025-01-01,40.7,-74.0',
        pgpSignature:
            '-----BEGIN PGP SIGNATURE-----\ntest\n-----END PGP SIGNATURE-----',
        publicKey: '-----BEGIN PGP PUBLIC KEY BLOCK-----\ntest\n-----END PGP PUBLIC KEY BLOCK-----',
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

      // Mock publish to succeed
      when(
        () => mockNostrService.publishEventAwaitOk(
          any(),
          timeout: any(named: 'timeout'),
        ),
      ).thenAnswer((invocation) async {
        return PublishOutcome(
          eventId: (invocation.positionalArguments[0] as Event).id,
          acceptedBy: const ['wss://relay.divine.video'],
          rejectedBy: const {},
          noResponseFrom: const [],
        );
      });
      when(
        () => mockNostrService.queryEvents(
          any(),
          subscriptionId: any(named: 'subscriptionId'),
          tempRelays: any(named: 'tempRelays'),
          relayTypes: any(named: 'relayTypes'),
          sendAfterAuth: any(named: 'sendAfterAuth'),
          useCache: any(named: 'useCache'),
        ),
      ).thenAnswer(
        (_) async => capturedEvent == null ? <Event>[] : [capturedEvent!],
      );

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

      const nativeProof = NativeProofData(
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

      when(
        () => mockNostrService.publishEventAwaitOk(
          any(),
          timeout: any(named: 'timeout'),
        ),
      ).thenAnswer((invocation) async {
        return PublishOutcome(
          eventId: (invocation.positionalArguments[0] as Event).id,
          acceptedBy: const ['wss://relay.divine.video'],
          rejectedBy: const {},
          noResponseFrom: const [],
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

      when(
        () => mockNostrService.publishEventAwaitOk(
          any(),
          timeout: any(named: 'timeout'),
        ),
      ).thenAnswer((invocation) async {
        return PublishOutcome(
          eventId: (invocation.positionalArguments[0] as Event).id,
          acceptedBy: const ['wss://relay.divine.video'],
          rejectedBy: const {},
          noResponseFrom: const [],
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

    test(
      'replaces a stale attestation with one bound to the publisher',
      () async {
        debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
        addTearDown(() => debugDefaultTargetPlatformOverride = null);

        final attestation = _RecordingAttestationService();
        publisher = VideoEventPublisher(
          uploadManager: mockUploadManager,
          nostrService: mockNostrService,
          authService: mockAuthService,
          iosDeviceAttestationService: attestation,
        );
        when(
          () => mockAuthService.currentPublicKeyHex,
        ).thenReturn('signer-pubkey');

        // Carries a payload minted for a different account, as an upload
        // recorded before an account switch would.
        const nativeProof = NativeProofData(
          videoHash: 'abc123def456',
          pgpSignature: 'signature',
          publicKey: 'public_key',
          deviceAttestation: 'attestation-for-the-previous-account',
        );

        final upload =
            PendingUpload.create(
              localVideoPath: '/tmp/test.mp4',
              nostrPubkey: 'signer-pubkey',
              proofManifestJson: jsonEncode(nativeProof.toJson()),
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
          capturedEvent = Event.fromJson({
            'id': 'event999',
            'pubkey': 'signer-pubkey',
            'created_at': DateTime.now().millisecondsSinceEpoch ~/ 1000,
            'kind': 34236,
            'tags': invocation.namedArguments[#tags],
            'content': invocation.namedArguments[#content],
            'sig': 'signature999',
          });
          return Future.value(capturedEvent);
        });
        when(
          () => mockNostrService.publishEventAwaitOk(
            any(),
            timeout: any(named: 'timeout'),
          ),
        ).thenAnswer(
          (invocation) async => PublishOutcome(
            eventId: (invocation.positionalArguments[0] as Event).id,
            acceptedBy: const ['wss://relay.divine.video'],
            rejectedBy: const {},
            noResponseFrom: const [],
          ),
        );

        await publisher.publishDirectUpload(upload);

        expect(attestation.proofHash, 'abc123def456');
        expect(attestation.pubkeyHex, 'signer-pubkey');

        final attestationTag = capturedEvent!.tags.firstWhere(
          (tag) => tag.isNotEmpty && tag[0] == 'device_attestation',
        );
        expect(attestationTag[1], 'attestation-for-signer-pubkey');

        final proofTag = capturedEvent!.tags.firstWhere(
          (tag) => tag.isNotEmpty && tag[0] == 'proofmode',
        );
        expect(
          jsonDecode(proofTag[1])['deviceAttestation'],
          'attestation-for-signer-pubkey',
          reason: 'the embedded JSON publishes the same payload as the tag',
        );
      },
    );

    test(
      'drops publish-time attestation when the account changes before signing',
      () async {
        debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
        addTearDown(() => debugDefaultTargetPlatformOverride = null);

        var currentPubkey = 'account-a-pubkey';
        final attestation = _RecordingAttestationService(
          payload: 'attestation-for-account-a',
          onAfterAttestation: () => currentPubkey = 'account-b-pubkey',
        );
        publisher = VideoEventPublisher(
          uploadManager: mockUploadManager,
          nostrService: mockNostrService,
          authService: mockAuthService,
          iosDeviceAttestationService: attestation,
        );
        when(
          () => mockAuthService.currentPublicKeyHex,
        ).thenAnswer((_) => currentPubkey);

        const nativeProof = NativeProofData(
          videoHash: 'abc123def456',
          pgpSignature: 'signature',
          publicKey: 'public_key',
          deviceAttestation: 'attestation-for-the-previous-account',
        );

        final upload =
            PendingUpload.create(
              localVideoPath: '/tmp/test.mp4',
              nostrPubkey: 'account-a-pubkey',
              proofManifestJson: jsonEncode(nativeProof.toJson()),
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
          capturedEvent = Event.fromJson({
            'id': 'event996',
            'pubkey': currentPubkey,
            'created_at': DateTime.now().millisecondsSinceEpoch ~/ 1000,
            'kind': 34236,
            'tags': invocation.namedArguments[#tags],
            'content': invocation.namedArguments[#content],
            'sig': 'signature996',
          });
          return Future.value(capturedEvent);
        });
        when(
          () => mockNostrService.publishEventAwaitOk(
            any(),
            timeout: any(named: 'timeout'),
          ),
        ).thenAnswer(
          (invocation) async => PublishOutcome(
            eventId: (invocation.positionalArguments[0] as Event).id,
            acceptedBy: const ['wss://relay.divine.video'],
            rejectedBy: const {},
            noResponseFrom: const [],
          ),
        );

        await publisher.publishDirectUpload(upload);

        expect(attestation.pubkeyHex, 'account-a-pubkey');
        expect(capturedEvent, isNotNull);
        expect(capturedEvent!.pubkey, 'account-b-pubkey');
        expect(
          capturedEvent!.tags.where(
            (tag) => tag.isNotEmpty && tag[0] == 'device_attestation',
          ),
          isEmpty,
          reason: 'account B must not publish account A device material',
        );
        final proofTag = capturedEvent!.tags.firstWhere(
          (tag) => tag.isNotEmpty && tag[0] == 'proofmode',
        );
        expect(jsonDecode(proofTag[1])['deviceAttestation'], isNull);
      },
    );

    test('publishes without attestation when App Attest fails', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);

      publisher = VideoEventPublisher(
        uploadManager: mockUploadManager,
        nostrService: mockNostrService,
        authService: mockAuthService,
        iosDeviceAttestationService: _RecordingAttestationService(
          payload: null,
        ),
      );
      when(
        () => mockAuthService.currentPublicKeyHex,
      ).thenReturn('signer-pubkey');

      const nativeProof = NativeProofData(
        videoHash: 'abc123def456',
        pgpSignature: 'signature',
        publicKey: 'public_key',
        deviceAttestation: 'attestation-for-the-previous-account',
      );

      final upload =
          PendingUpload.create(
            localVideoPath: '/tmp/test.mp4',
            nostrPubkey: 'signer-pubkey',
            proofManifestJson: jsonEncode(nativeProof.toJson()),
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
        capturedEvent = Event.fromJson({
          'id': 'event998',
          'pubkey': 'signer-pubkey',
          'created_at': DateTime.now().millisecondsSinceEpoch ~/ 1000,
          'kind': 34236,
          'tags': invocation.namedArguments[#tags],
          'content': invocation.namedArguments[#content],
          'sig': 'signature998',
        });
        return Future.value(capturedEvent);
      });
      when(
        () => mockNostrService.publishEventAwaitOk(
          any(),
          timeout: any(named: 'timeout'),
        ),
      ).thenAnswer(
        (invocation) async => PublishOutcome(
          eventId: (invocation.positionalArguments[0] as Event).id,
          acceptedBy: const ['wss://relay.divine.video'],
          rejectedBy: const {},
          noResponseFrom: const [],
        ),
      );

      await publisher.publishDirectUpload(upload);

      expect(capturedEvent, isNotNull, reason: 'the event still gets signed');
      expect(
        capturedEvent!.tags.where(
          (tag) => tag.isNotEmpty && tag[0] == 'device_attestation',
        ),
        isEmpty,
        reason: 'a stale payload must not survive a failed mint',
      );
      expect(
        capturedEvent!.tags.where(
          (tag) => tag.isNotEmpty && tag[0] == 'proofmode',
        ),
        hasLength(1),
        reason: 'the rest of the proof still publishes',
      );
    });

    test(
      'publishes without stale attestation when the signing pubkey is absent',
      () async {
        debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
        addTearDown(() => debugDefaultTargetPlatformOverride = null);

        publisher = VideoEventPublisher(
          uploadManager: mockUploadManager,
          nostrService: mockNostrService,
          authService: mockAuthService,
          iosDeviceAttestationService: _ThrowingAttestationService(),
        );
        when(() => mockAuthService.currentPublicKeyHex).thenReturn(null);

        const nativeProof = NativeProofData(
          videoHash: 'abc123def456',
          pgpSignature: 'signature',
          publicKey: 'public_key',
          deviceAttestation: 'attestation-for-the-previous-account',
        );

        final upload =
            PendingUpload.create(
              localVideoPath: '/tmp/test.mp4',
              nostrPubkey: 'signer-pubkey',
              proofManifestJson: jsonEncode(nativeProof.toJson()),
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
          capturedEvent = Event.fromJson({
            'id': 'event997',
            'pubkey': 'signer-pubkey',
            'created_at': DateTime.now().millisecondsSinceEpoch ~/ 1000,
            'kind': 34236,
            'tags': invocation.namedArguments[#tags],
            'content': invocation.namedArguments[#content],
            'sig': 'signature997',
          });
          return Future.value(capturedEvent);
        });
        when(
          () => mockNostrService.publishEventAwaitOk(
            any(),
            timeout: any(named: 'timeout'),
          ),
        ).thenAnswer(
          (invocation) async => PublishOutcome(
            eventId: (invocation.positionalArguments[0] as Event).id,
            acceptedBy: const ['wss://relay.divine.video'],
            rejectedBy: const {},
            noResponseFrom: const [],
          ),
        );

        await publisher.publishDirectUpload(upload);

        expect(capturedEvent, isNotNull, reason: 'the event still gets signed');
        expect(
          capturedEvent!.tags.where(
            (tag) => tag.isNotEmpty && tag[0] == 'device_attestation',
          ),
          isEmpty,
          reason: 'a stale payload must not publish without a scoped signer',
        );
        final proofTag = capturedEvent!.tags.firstWhere(
          (tag) => tag.isNotEmpty && tag[0] == 'proofmode',
        );
        expect(jsonDecode(proofTag[1])['deviceAttestation'], isNull);
      },
    );
  });
}

/// Stands in for App Attest, recording what the publisher asked it to bind.
class _RecordingAttestationService extends IosDeviceAttestationService {
  _RecordingAttestationService({
    this.payload = _boundPayload,
    this.onAfterAttestation,
  });

  static const _boundPayload = 'attestation-for-signer-pubkey';

  final String? payload;
  final VoidCallback? onAfterAttestation;
  String? proofHash;
  String? pubkeyHex;

  @override
  Future<String?> attestationFor({
    required String proofHash,
    required String pubkeyHex,
  }) async {
    this.proofHash = proofHash;
    this.pubkeyHex = pubkeyHex;
    onAfterAttestation?.call();
    return payload;
  }
}

class _ThrowingAttestationService extends IosDeviceAttestationService {
  @override
  Future<String?> attestationFor({
    required String proofHash,
    required String pubkeyHex,
  }) {
    throw StateError('attestation service should not be called');
  }
}
