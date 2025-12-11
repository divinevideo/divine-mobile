// ABOUTME: Tests for BlossomUploadService ProofMode header integration
// ABOUTME: Verifies ProofMode manifest/signature/attestation headers are included in uploads
//
// IMPLEMENTATION REQUIRED: This test file requires the following to be created:
// - lib/services/proofmode_session_service.dart
//   - ProofManifest class with toJson() method
//   - RecordingSegment class
// - lib/services/proofmode_attestation_service.dart
//   - DeviceAttestation class
// - lib/services/proofmode_key_service.dart
//   - ProofSignature class
//
// See docs/PROOFMODE_ARCHITECTURE.md for full specification.

import 'dart:io';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nostr_sdk/event.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/blossom_upload_service.dart';
import 'package:nostr_client/nostr_client.dart';

// Mock classes
class MockAuthService extends Mock implements AuthService {}

class MockNostrService extends Mock implements NostrClient {}

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
      'PENDING: ProofMode header tests require ProofManifest implementation',
      () {
        // This test requires ProofManifest, RecordingSegment, DeviceAttestation,
        // and ProofSignature classes to be implemented.
        //
        // Tests will verify:
        // - Includes ProofMode headers when ProofManifest is provided
        // - Uploads without ProofMode headers when no manifest provided
        // - X-ProofMode-Manifest header contains base64 encoded manifest
        // - X-ProofMode-Signature header is present
        // - X-ProofMode-Attestation header is present
        expect(true, isTrue, reason: 'Placeholder until implementation exists');
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
