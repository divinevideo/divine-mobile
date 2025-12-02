// ABOUTME: Tests for BlossomUploadService ProofMode header integration
// ABOUTME: Verifies ProofMode manifest/signature/attestation headers are included in uploads

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nostr_sdk/event.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/blossom_upload_service.dart';
import 'package:openvine/services/nostr_service_interface.dart';
import 'package:openvine/services/proofmode_session_service.dart';
import 'package:openvine/services/proofmode_attestation_service.dart';
import 'package:openvine/services/proofmode_key_service.dart';

// Mock classes
class MockAuthService extends Mock implements AuthService {}

class MockNostrService extends Mock implements INostrService {}

class MockDio extends Mock implements Dio {}

class MockFile extends Mock implements File {}

class MockResponse extends Mock implements Response<dynamic> {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    registerFallbackValue(Uri.parse('https://example.com'));
    registerFallbackValue(Options());
    registerFallbackValue(<String, String>{});
  });

  group('BlossomUploadService ProofMode Integration', () {
    late BlossomUploadService service;
    late MockAuthService mockAuthService;
    late MockNostrService mockNostrService;
    late MockDio mockDio;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});

      mockAuthService = MockAuthService();
      mockNostrService = MockNostrService();
      mockDio = MockDio();

      service = BlossomUploadService(
        authService: mockAuthService,
        nostrService: mockNostrService,
        dio: mockDio,
      );

      await service.setBlossomEnabled(true);
      await service.setBlossomServer('https://blossom.divine.video');
    });

    test(
      'should include ProofMode headers when ProofManifest is provided',
      () async {
        // Arrange
        const testPublicKey =
            '0223456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef';

        when(() => mockAuthService.isAuthenticated).thenReturn(true);
        when(
          () => mockAuthService.currentPublicKeyHex,
        ).thenReturn(testPublicKey);

        // Mock createAndSignEvent
        when(
          () => mockAuthService.createAndSignEvent(
            kind: any(named: 'kind'),
            content: any(named: 'content'),
            tags: any(named: 'tags'),
          ),
        ).thenAnswer(
          (_) async => Event(testPublicKey, 24242, [
            ['t', 'upload'],
          ], 'Upload video to Blossom server'),
        );

        // Create a valid ProofManifest
        final proofManifest = ProofManifest(
          sessionId: 'session_test_123',
          challengeNonce: 'nonce_abc123',
          vineSessionStart: DateTime(2025, 10, 13, 10, 0),
          vineSessionEnd: DateTime(2025, 10, 13, 10, 0, 6),
          segments: [
            RecordingSegment(
              segmentId: 'segment_1',
              startTime: DateTime(2025, 10, 13, 10, 0),
              endTime: DateTime(2025, 10, 13, 10, 0, 3),
              frameHashes: ['hash1', 'hash2', 'hash3'],
            ),
          ],
          pauseProofs: [],
          interactions: [],
          finalVideoHash: 'finalvideohash123',
          deviceAttestation: DeviceAttestation(
            token: 'attestation_token_xyz',
            platform: 'ios',
            deviceId: 'device123',
            isHardwareBacked: true,
            createdAt: DateTime(2025, 10, 13, 10, 0),
            challenge: 'nonce_abc123',
          ),
          pgpSignature: ProofSignature(
            signature: 'signature_data',
            publicKeyFingerprint: 'key123',
            signedAt: DateTime(2025, 10, 13, 10, 0),
          ),
        );

        final proofManifestJson = jsonEncode(proofManifest.toJson());

        final mockFile = MockFile();
        when(() => mockFile.path).thenReturn('/test/video.mp4');
        when(() => mockFile.existsSync()).thenReturn(true);
        when(
          () => mockFile.readAsBytes(),
        ).thenAnswer((_) async => Uint8List.fromList([1, 2, 3, 4, 5]));
        when(
          () => mockFile.readAsBytesSync(),
        ).thenReturn(Uint8List.fromList([1, 2, 3, 4, 5]));
        when(() => mockFile.lengthSync()).thenReturn(5);

        // Mock successful response
        final mockResponse = MockResponse();
        when(() => mockResponse.statusCode).thenReturn(200);
        when(() => mockResponse.headers).thenReturn(Headers());
        when(() => mockResponse.data).thenReturn({
          'url': 'https://cdn.divine.video/abc123.mp4',
          'sha256': 'abc123',
          'size': 5,
          'proofmode': {
            'verified': true,
            'level': 'verified_mobile',
            'deviceFingerprint': 'ios_device_123',
            'timestamp':
                DateTime(2025, 10, 13, 10, 0).millisecondsSinceEpoch ~/ 1000,
          },
        });

        when(
          () => mockDio.put(
            any(),
            data: any(named: 'data'),
            options: any(named: 'options'),
            onSendProgress: any(named: 'onSendProgress'),
          ),
        ).thenAnswer((_) async => mockResponse);

        // Act
        final result = await service.uploadVideo(
          videoFile: mockFile,
          nostrPubkey: testPublicKey,
          title: 'Test Video',
          proofManifestJson: proofManifestJson,
        );

        // Assert
        expect(result.success, isTrue);

        // Verify PUT was called with ProofMode headers
        final capturedCall = verify(
          () => mockDio.put(
            'https://blossom.divine.video/upload',
            data: any(named: 'data'),
            options: captureAny(named: 'options'),
            onSendProgress: any(named: 'onSendProgress'),
          ),
        );

        capturedCall.called(1);

        final capturedOptions = capturedCall.captured.first as Options;
        final headers = capturedOptions.headers;

        expect(headers, isNotNull);
        expect(headers!['Authorization'], startsWith('Nostr '));
        expect(headers['Content-Type'], equals('video/mp4'));

        // Verify ProofMode headers are present
        expect(headers['X-ProofMode-Manifest'], isNotNull);
        expect(headers['X-ProofMode-Signature'], isNotNull);
        expect(headers['X-ProofMode-Attestation'], isNotNull);

        // Verify manifest is base64 encoded
        final manifestBase64 = headers['X-ProofMode-Manifest'] as String;
        final decodedManifest = utf8.decode(base64.decode(manifestBase64));
        expect(decodedManifest, contains('session_test_123'));
      },
    );

    test(
      'should upload without ProofMode headers when no manifest provided',
      () async {
        // Arrange
        const testPublicKey =
            '0223456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef';

        when(() => mockAuthService.isAuthenticated).thenReturn(true);
        when(
          () => mockAuthService.currentPublicKeyHex,
        ).thenReturn(testPublicKey);

        when(
          () => mockAuthService.createAndSignEvent(
            kind: any(named: 'kind'),
            content: any(named: 'content'),
            tags: any(named: 'tags'),
          ),
        ).thenAnswer(
          (_) async => Event(testPublicKey, 24242, [
            ['t', 'upload'],
          ], 'Upload video to Blossom server'),
        );

        final mockFile = MockFile();
        when(() => mockFile.path).thenReturn('/test/video.mp4');
        when(() => mockFile.existsSync()).thenReturn(true);
        when(
          () => mockFile.readAsBytes(),
        ).thenAnswer((_) async => Uint8List.fromList([1, 2, 3, 4, 5]));
        when(
          () => mockFile.readAsBytesSync(),
        ).thenReturn(Uint8List.fromList([1, 2, 3, 4, 5]));
        when(() => mockFile.lengthSync()).thenReturn(5);

        final mockResponse = MockResponse();
        when(() => mockResponse.statusCode).thenReturn(200);
        when(() => mockResponse.headers).thenReturn(Headers());
        when(() => mockResponse.data).thenReturn({
          'url': 'https://cdn.divine.video/abc123.mp4',
          'sha256': 'abc123',
          'size': 5,
        });

        when(
          () => mockDio.put(
            any(),
            data: any(named: 'data'),
            options: any(named: 'options'),
            onSendProgress: any(named: 'onSendProgress'),
          ),
        ).thenAnswer((_) async => mockResponse);

        // Act
        final result = await service.uploadVideo(
          videoFile: mockFile,
          nostrPubkey: testPublicKey,
          title: 'Test Video',
          // No proofManifestJson provided
        );

        // Assert
        expect(result.success, isTrue);

        // Verify PUT was called WITHOUT ProofMode headers
        final capturedCall = verify(
          () => mockDio.put(
            'https://blossom.divine.video/upload',
            data: any(named: 'data'),
            options: captureAny(named: 'options'),
            onSendProgress: any(named: 'onSendProgress'),
          ),
        );

        capturedCall.called(1);

        final capturedOptions = capturedCall.captured.first as Options;
        final headers = capturedOptions.headers;

        expect(headers, isNotNull);
        expect(headers!['Authorization'], startsWith('Nostr '));
        expect(headers['Content-Type'], equals('video/mp4'));

        // Verify ProofMode headers are NOT present
        expect(headers['X-ProofMode-Manifest'], isNull);
        expect(headers['X-ProofMode-Signature'], isNull);
        expect(headers['X-ProofMode-Attestation'], isNull);
      },
    );

    test(
      'should fix missing file extension in image upload conflict response',
      () async {
        // Arrange
        const testPublicKey =
            '0223456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef';

        when(() => mockAuthService.isAuthenticated).thenReturn(true);
        when(
          () => mockAuthService.currentPublicKeyHex,
        ).thenReturn(testPublicKey);

        when(
          () => mockAuthService.createAndSignEvent(
            kind: any(named: 'kind'),
            content: any(named: 'content'),
            tags: any(named: 'tags'),
          ),
        ).thenAnswer(
          (_) async => Event(testPublicKey, 24242, [
            ['t', 'upload'],
          ], 'Upload to Blossom'),
        );

        final mockFile = MockFile();
        when(() => mockFile.path).thenReturn('/test/image.jpg');
        when(() => mockFile.existsSync()).thenReturn(true);
        when(
          () => mockFile.readAsBytes(),
        ).thenAnswer((_) async => Uint8List.fromList([1, 2, 3]));
        when(
          () => mockFile.readAsBytesSync(),
        ).thenReturn(Uint8List.fromList([1, 2, 3]));
        when(() => mockFile.lengthSync()).thenReturn(3);

        // Mock 409 Conflict response (file already exists)
        final mockResponse = MockResponse();
        when(() => mockResponse.statusCode).thenReturn(409);
        when(() => mockResponse.headers).thenReturn(Headers());
        when(() => mockResponse.data).thenReturn({});

        when(
          () => mockDio.put(
            any(),
            data: any(named: 'data'),
            options: any(named: 'options'),
            onSendProgress: any(named: 'onSendProgress'),
          ),
        ).thenAnswer((_) async => mockResponse);

        // Act
        final result = await service.uploadImage(
          imageFile: mockFile,
          nostrPubkey: testPublicKey,
          mimeType: 'image/jpeg',
        );

        // Assert
        expect(result.success, isTrue);
        // Should include file extension based on MIME type
        expect(result.cdnUrl, contains('.jpg'));
        // SHA-256 of bytes [1,2,3]
        expect(
          result.cdnUrl,
          equals(
            'https://cdn.divine.video/039058c6f2c0cb492c533b0a4d14ef77cc0f78abccced5287d84a1a2011cfb81.jpg',
          ),
        );
      },
    );
  });
}
