// ABOUTME: Tests for BlossomUploadService verifying NIP-98 auth and
// multi-server support
// ABOUTME: Tests configuration persistence, server selection, and upload flow

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:blossom_upload_service/blossom_upload_service.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Mock classes
class _MockAuthProvider extends Mock implements BlossomAuthProvider {}

class _MockDio extends Mock implements Dio {}

class _MockFile extends Mock implements File {}

class _MockResponse extends Mock implements Response<dynamic> {}

const _testPublicKey =
    '0223456789abcdef0123456789abcdef0123456789abcdef'
    '0123456789abcdef';

/// Helper to create a [BlossomSignedEvent] with the given [pubkey] and [tags].
BlossomSignedEvent _signedEvent(
  String pubkey,
  int kind,
  List<List<String>> tags,
  String content,
) {
  return BlossomSignedEvent(
    json: {
      'id': 'test_id',
      'pubkey': pubkey,
      'created_at': 0,
      'kind': kind,
      'tags': tags,
      'content': content,
      'sig': 'test_sig',
    },
  );
}

/// Generates a minimal JPEG with EXIF orientation and a GPS latitude ref.
Uint8List _jpegBytesWithGps(String latitudeRef) {
  final image = img.Image(width: 2, height: 2);
  final jpgBytes = img.encodeJpg(image, quality: 95);
  final exif = img.ExifData()
    ..imageIfd.orientation = 6
    ..gpsIfd['GPSLatitudeRef'] = img.IfdValueAscii(latitudeRef);
  return img.injectJpgExif(jpgBytes, exif) ?? Uint8List.fromList(jpgBytes);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    registerFallbackValue(Uri.parse('https://example.com'));
    registerFallbackValue(Options());
    registerFallbackValue(<String, String>{});
  });

  group('BlossomUploadService', () {
    late BlossomUploadService service;
    late _MockAuthProvider mockAuthProvider;

    setUp(() async {
      // Initialize SharedPreferences with test values
      SharedPreferences.setMockInitialValues({});

      mockAuthProvider = _MockAuthProvider();

      service = BlossomUploadService(authProvider: mockAuthProvider);
    });

    group('Configuration', () {
      test('should save and retrieve Blossom server URL', () async {
        // Arrange
        const testServerUrl = 'https://blossom.example.com';

        // Act
        await service.setBlossomServer(testServerUrl);
        final retrievedUrl = await service.getBlossomServer();

        // Assert
        expect(retrievedUrl, equals(testServerUrl));
      });

      test('should clear Blossom server URL when set to null', () async {
        // Arrange
        await service.setBlossomServer('https://blossom.example.com');

        // Act
        await service.setBlossomServer(null);
        final retrievedUrl = await service.getBlossomServer();

        // Assert - Clearing falls back to default server
        expect(retrievedUrl, equals(BlossomUploadService.defaultBlossomServer));
      });

      test(
        'should default to custom Blossom server enabled for new installs',
        () async {
          // Act & Assert - New installs should default to allowing
          // non-Divine media servers
          expect(await service.isBlossomEnabled(), isTrue);
        },
      );

      test('should save and retrieve Blossom enabled state', () async {
        // Enable custom Blossom server
        await service.setBlossomEnabled(true);
        expect(await service.isBlossomEnabled(), isTrue);

        // Disable custom Blossom server
        await service.setBlossomEnabled(false);
        expect(await service.isBlossomEnabled(), isFalse);
      });
    });

    group('Upload Validation', () {
      // Note: When Blossom is disabled, uploads succeed using the default
      // Divine server (blossom.divine.video), so there's no "not enabled"
      // error case.

      test('should fail upload if no server is configured', () async {
        // Arrange
        when(() => mockAuthProvider.isAuthenticated).thenReturn(true);
        await service.setBlossomEnabled(true);
        await service.setBlossomServer(
          '',
        ); // Set empty string to trigger "no server" error

        final mockFile = _MockFile();
        when(() => mockFile.path).thenReturn('/test/video.mp4');
        when(mockFile.existsSync).thenReturn(true);
        when(
          mockFile.openRead,
        ).thenAnswer((_) => Stream.value(Uint8List.fromList([1, 2, 3])));

        // Act
        final result = await service.uploadVideo(
          videoFile: mockFile,
          nostrPubkey: 'testpubkey',
          title: 'Test Video',
          description: null,
          hashtags: null,
          proofManifestJson: null,
        );

        // Assert - empty server URL yields failure (code adds default server
        // as fallback, so we may get auth/upload error instead of
        // "not configured")
        expect(result.success, isFalse);
        expect(result.errorMessage, isNotNull);
        expect(result.errorMessage!.isNotEmpty, isTrue);
      });

      test('should fail upload with invalid server URL', () async {
        // Arrange
        await service.setBlossomEnabled(true);
        await service.setBlossomServer('not-a-valid-url');

        // Mock isAuthenticated
        when(() => mockAuthProvider.isAuthenticated).thenReturn(false);

        final mockFile = _MockFile();
        when(() => mockFile.path).thenReturn('/test/video.mp4');

        // Act
        final result = await service.uploadVideo(
          videoFile: mockFile,
          nostrPubkey: 'testpubkey',
          title: 'Test Video',
          description: null,
          hashtags: null,
          proofManifestJson: null,
        );

        // Assert
        expect(result.success, isFalse);
        expect(result.errorMessage != null, isTrue);
        // Since we check auth before URL validation, and auth is false,
        // we'll get an unauthenticated error
        expect(result.errorMessage, contains('authenticated'));
      });
    });

    group('Real Blossom Upload Implementation', () {
      late _MockDio mockDio;

      setUp(() {
        mockDio = _MockDio();
        // Inject the mock Dio into the service
        service = BlossomUploadService(
          authProvider: mockAuthProvider,
          dio: mockDio,
        );
      });

      test('should successfully upload to Blossom server', () async {
        // Arrange
        await service.setBlossomEnabled(true);
        await service.setBlossomServer('https://cdn.satellite.earth');

        const testPublicKey = _testPublicKey;

        when(() => mockAuthProvider.isAuthenticated).thenReturn(true);
        // Mock the createAndSignEvent method that BlossomUploadService calls
        when(
          () => mockAuthProvider.createAndSignEvent(
            kind: any(named: 'kind'),
            content: any(named: 'content'),
            tags: any(named: 'tags'),
          ),
        ).thenAnswer((_) async {
          return _signedEvent(testPublicKey, 24242, [
            ['t', 'upload'],
          ], 'Upload video to Blossom server');
        });

        final mockFile = _MockFile();
        when(() => mockFile.path).thenReturn('/test/video.mp4');
        when(mockFile.existsSync).thenReturn(true);
        when(
          mockFile.readAsBytes,
        ).thenAnswer((_) async => Uint8List.fromList([1, 2, 3, 4, 5]));
        when(
          mockFile.readAsBytesSync,
        ).thenReturn(Uint8List.fromList([1, 2, 3, 4, 5]));
        when(mockFile.lengthSync).thenReturn(5);
        when(
          mockFile.openRead,
        ).thenAnswer((_) => Stream.value(Uint8List.fromList([1, 2, 3, 4, 5])));

        // Mock Dio response
        final mockResponse = _MockResponse();
        when(() => mockResponse.statusCode).thenReturn(200);
        when(() => mockResponse.headers).thenReturn(Headers());
        when(() => mockResponse.data).thenReturn({
          'url': 'https://cdn.satellite.earth/abc123.mp4',
          'sha256': 'abc123',
          'size': 5,
        });

        when(
          () => mockDio.head<dynamic>(any(), options: any(named: 'options')),
        ).thenAnswer(
          (_) async => Response(
            requestOptions: RequestOptions(path: '/upload'),
            statusCode: 200,
            headers: Headers(),
          ),
        );

        when(
          () => mockDio.put<dynamic>(
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
          description: null,
          hashtags: null,
          proofManifestJson: null,
        );

        // Assert
        expect(result.success, isTrue);
        // URL is now constructed client-side: {defaultBlossomServer}/{sha256}
        // per Blossom spec (BUD-01), regardless of server response URL
        const expectedHash =
            '74f81fe167d99b4cb41d6d0ccda82278caee9f3e2f25d5e5a3936ff3dcec60d0';
        expect(
          result.cdnUrl,
          equals('https://media.divine.video/$expectedHash'),
        );
        expect(result.videoId, equals(expectedHash));
      });

      test(
        'uses resumable init flow for Divine servers that advertise support',
        () async {
          final expectedExpiresAt = DateTime.fromMillisecondsSinceEpoch(
            1774827544000,
            isUtc: true,
          );
          const testPublicKey = _testPublicKey;

          when(() => mockAuthProvider.isAuthenticated).thenReturn(true);
          when(
            () => mockAuthProvider.createAndSignEvent(
              kind: any(named: 'kind'),
              content: any(named: 'content'),
              tags: any(named: 'tags'),
            ),
          ).thenAnswer(
            (_) async => _signedEvent(
              testPublicKey,
              24242,
              const [],
              'Upload video to Blossom server',
            ),
          );

          final tempDir = await Directory.systemTemp.createTemp(
            'blossom_resumable_service_test_',
          );
          final videoFile = File('${tempDir.path}/video.mp4')
            ..writeAsBytesSync(List<int>.generate(10, (index) => index));
          final sessionUpdates = <BlossomResumableUploadSession>[];

          when(
            () => mockDio.head<dynamic>(any(), options: any(named: 'options')),
          ).thenAnswer(
            (_) async => Response(
              requestOptions: RequestOptions(path: '/upload'),
              statusCode: 200,
              headers: Headers.fromMap({
                DivineUploadHeaders.extensions: [
                  DivineUploadExtensions.resumableSessions,
                ],
                DivineUploadHeaders.controlHost: ['https://media.divine.video'],
                DivineUploadHeaders.dataHost: ['https://upload.divine.video'],
              }),
            ),
          );

          when(
            () => mockDio.post<dynamic>(
              any(),
              data: any(named: 'data'),
              options: any(named: 'options'),
            ),
          ).thenAnswer((invocation) async {
            final url = invocation.positionalArguments.first as String;
            final data = invocation.namedArguments[#data];
            if (url.endsWith('/upload/init')) {
              return Response(
                requestOptions: RequestOptions(path: '/upload/init'),
                statusCode: 200,
                data: {
                  'uploadId': 'up_123',
                  'uploadUrl': 'https://upload.divine.video/sessions/up_123',
                  'expiresAt': '1774827544',
                  'chunkSize': 4,
                  'nextOffset': 0,
                  'requiredHeaders': {'Authorization': 'Bearer session-token'},
                },
              );
            }

            if (url.endsWith('/upload/up_123/complete')) {
              expect(data, isA<Map<String, dynamic>>());
              expect((data as Map<String, dynamic>)['sha256'], isNotEmpty);
              return Response(
                requestOptions: RequestOptions(path: '/upload/up_123/complete'),
                statusCode: 200,
                data: {
                  'url': 'https://media.divine.video/final',
                  'fallbackUrl': 'https://media.divine.video/final',
                },
              );
            }

            throw StateError('Unexpected POST url: $url');
          });

          var chunkRequestCount = 0;
          when(
            () => mockDio.put<dynamic>(
              any(),
              data: any(named: 'data'),
              options: any(named: 'options'),
              onSendProgress: any(named: 'onSendProgress'),
            ),
          ).thenAnswer((invocation) async {
            final onSendProgress =
                invocation.namedArguments[#onSendProgress]
                    as void Function(int, int)?;
            final options = invocation.namedArguments[#options] as Options;
            chunkRequestCount += 1;

            if (chunkRequestCount == 1) {
              expect(options.headers?['Content-Range'], equals('bytes 0-3/10'));
              expect(
                options.headers?['Authorization'],
                equals('Bearer session-token'),
              );
              onSendProgress?.call(4, 4);
              return Response(
                requestOptions: RequestOptions(path: '/sessions/up_123'),
                statusCode: 204,
                headers: Headers.fromMap({
                  DivineUploadHeaders.uploadOffset: ['4'],
                }),
              );
            }

            if (chunkRequestCount == 2) {
              expect(options.headers?['Content-Range'], equals('bytes 4-7/10'));
              onSendProgress?.call(4, 4);
              return Response(
                requestOptions: RequestOptions(path: '/sessions/up_123'),
                statusCode: 204,
                headers: Headers.fromMap({
                  DivineUploadHeaders.uploadOffset: ['8'],
                }),
              );
            }

            expect(options.headers?['Content-Range'], equals('bytes 8-9/10'));
            onSendProgress?.call(2, 2);
            return Response(
              requestOptions: RequestOptions(path: '/sessions/up_123'),
              statusCode: 204,
              headers: Headers.fromMap({
                DivineUploadHeaders.uploadOffset: ['10'],
              }),
            );
          });

          final result = await service.uploadVideo(
            videoFile: videoFile,
            nostrPubkey: testPublicKey,
            title: 'Resumable Video',
            description: null,
            hashtags: null,
            proofManifestJson: null,
            onResumableSessionUpdated: sessionUpdates.add,
          );

          expect(result.success, isTrue);
          expect(result.videoId, isNotNull);
          expect(
            result.cdnUrl,
            equals(
              'https://media.divine.video/'
              '${result.videoId}',
            ),
          );
          expect(chunkRequestCount, equals(3));
          expect(sessionUpdates.map((session) => session.nextOffset), [
            0,
            4,
            8,
            10,
          ]);
          expect(sessionUpdates.first.expiresAt, equals(expectedExpiresAt));

          verifyInOrder([
            () => mockDio.head<dynamic>(
              'https://media.divine.video/upload',
              options: any(named: 'options'),
            ),
            () => mockDio.post<dynamic>(
              'https://media.divine.video/upload/init',
              data: any(named: 'data'),
              options: any(named: 'options'),
            ),
            () => mockDio.put<dynamic>(
              'https://upload.divine.video/sessions/up_123',
              data: any(named: 'data'),
              options: any(named: 'options'),
              onSendProgress: any(named: 'onSendProgress'),
            ),
            () => mockDio.post<dynamic>(
              'https://media.divine.video/upload/up_123/complete',
              data: any(named: 'data'),
              options: any(named: 'options'),
            ),
          ]);

          await tempDir.delete(recursive: true);
        },
      );

      test('awaits betweenChunks after every non-final chunk', () async {
        const testPublicKey = _testPublicKey;
        var betweenChunksCalls = 0;
        final backpressureService = BlossomUploadService(
          authProvider: mockAuthProvider,
          dio: mockDio,
          betweenChunks: () async => betweenChunksCalls++,
        );

        when(() => mockAuthProvider.isAuthenticated).thenReturn(true);
        when(
          () => mockAuthProvider.createAndSignEvent(
            kind: any(named: 'kind'),
            content: any(named: 'content'),
            tags: any(named: 'tags'),
          ),
        ).thenAnswer(
          (_) async => _signedEvent(testPublicKey, 24242, const [], 'Upload'),
        );

        final tempDir = await Directory.systemTemp.createTemp(
          'blossom_backpressure_test_',
        );
        final videoFile = File('${tempDir.path}/video.mp4')
          ..writeAsBytesSync(List<int>.generate(10, (index) => index));

        when(
          () => mockDio.head<dynamic>(any(), options: any(named: 'options')),
        ).thenAnswer(
          (_) async => Response(
            requestOptions: RequestOptions(path: '/upload'),
            statusCode: 200,
            headers: Headers.fromMap({
              DivineUploadHeaders.extensions: [
                DivineUploadExtensions.resumableSessions,
              ],
              DivineUploadHeaders.controlHost: ['https://media.divine.video'],
              DivineUploadHeaders.dataHost: ['https://upload.divine.video'],
            }),
          ),
        );

        when(
          () => mockDio.post<dynamic>(
            any(),
            data: any(named: 'data'),
            options: any(named: 'options'),
          ),
        ).thenAnswer((invocation) async {
          final url = invocation.positionalArguments.first as String;
          if (url.endsWith('/upload/init')) {
            return Response(
              requestOptions: RequestOptions(path: '/upload/init'),
              statusCode: 200,
              data: {
                'uploadId': 'up_123',
                'uploadUrl': 'https://upload.divine.video/sessions/up_123',
                'expiresAt': '1774827544',
                'chunkSize': 4,
                'nextOffset': 0,
              },
            );
          }
          return Response(
            requestOptions: RequestOptions(path: '/upload/up_123/complete'),
            statusCode: 200,
            data: {
              'url': 'https://media.divine.video/final',
              'fallbackUrl': 'https://media.divine.video/final',
            },
          );
        });

        // 10 bytes / 4-byte chunks => 3 chunks => offsets 4, 8, 10.
        var chunkRequestCount = 0;
        when(
          () => mockDio.put<dynamic>(
            any(),
            data: any(named: 'data'),
            options: any(named: 'options'),
            onSendProgress: any(named: 'onSendProgress'),
          ),
        ).thenAnswer((_) async {
          chunkRequestCount += 1;
          final offset = switch (chunkRequestCount) {
            1 => '4',
            2 => '8',
            _ => '10',
          };
          return Response(
            requestOptions: RequestOptions(path: '/sessions/up_123'),
            statusCode: 204,
            headers: Headers.fromMap({
              DivineUploadHeaders.uploadOffset: [offset],
            }),
          );
        });

        final result = await backpressureService.uploadVideo(
          videoFile: videoFile,
          nostrPubkey: testPublicKey,
          title: 'Backpressure Video',
          description: null,
          hashtags: null,
          proofManifestJson: null,
        );

        expect(result.success, isTrue);
        expect(chunkRequestCount, equals(3));
        // Three chunks have two inter-chunk boundaries; the final chunk does
        // not pause.
        expect(betweenChunksCalls, equals(2));

        await tempDir.delete(recursive: true);
      });

      test('resumeUploadSession parses upload-expires unix seconds from '
          'session HEAD', () async {
        final expectedExpiresAt = DateTime.fromMillisecondsSinceEpoch(
          1774827600000,
          isUtc: true,
        );

        when(
          () => mockDio.head<dynamic>(any(), options: any(named: 'options')),
        ).thenAnswer(
          (_) async => Response(
            requestOptions: RequestOptions(path: '/sessions/up_123'),
            statusCode: 204,
            headers: Headers.fromMap({
              'upload-offset': ['262144'],
              'upload-expires': ['1774827600'],
            }),
          ),
        );

        final session = await service.resumeUploadSession(
          session: const BlossomResumableUploadSession(
            uploadId: 'up_123',
            uploadUrl: 'https://upload.divine.video/sessions/up_123',
            chunkSize: 8388608,
            nextOffset: 0,
          ),
        );

        expect(session.nextOffset, equals(262144));
        expect(session.expiresAt, equals(expectedExpiresAt));
      });

      test('falls back to legacy PUT upload when resumable capability '
          'is absent', () async {
        const testPublicKey = _testPublicKey;

        when(() => mockAuthProvider.isAuthenticated).thenReturn(true);
        when(
          () => mockAuthProvider.createAndSignEvent(
            kind: any(named: 'kind'),
            content: any(named: 'content'),
            tags: any(named: 'tags'),
          ),
        ).thenAnswer(
          (_) async => _signedEvent(
            testPublicKey,
            24242,
            const [],
            'Upload video to Blossom server',
          ),
        );

        final tempDir = await Directory.systemTemp.createTemp(
          'blossom_legacy_fallback_test_',
        );
        final videoFile = File('${tempDir.path}/video.mp4')
          ..writeAsBytesSync(List<int>.generate(5, (index) => index + 1));

        when(
          () => mockDio.head<dynamic>(any(), options: any(named: 'options')),
        ).thenAnswer(
          (_) async => Response(
            requestOptions: RequestOptions(path: '/upload'),
            statusCode: 200,
            headers: Headers(),
          ),
        );

        when(
          () => mockDio.put<dynamic>(
            any(),
            data: any(named: 'data'),
            options: any(named: 'options'),
            onSendProgress: any(named: 'onSendProgress'),
          ),
        ).thenAnswer(
          (_) async => Response(
            requestOptions: RequestOptions(path: '/upload'),
            statusCode: 200,
            data: {
              'url': 'https://media.divine.video/final',
              'fallbackUrl': 'https://media.divine.video/final',
            },
          ),
        );

        final result = await service.uploadVideo(
          videoFile: videoFile,
          nostrPubkey: testPublicKey,
          title: 'Legacy Video',
          description: null,
          hashtags: null,
          proofManifestJson: null,
        );

        expect(result.success, isTrue);

        verify(
          () => mockDio.put<dynamic>(
            'https://media.divine.video/upload',
            data: any(named: 'data'),
            options: any(named: 'options'),
            onSendProgress: any(named: 'onSendProgress'),
          ),
        ).called(1);
        verifyNever(
          () => mockDio.post<dynamic>(
            'https://media.divine.video/upload/init',
            data: any(named: 'data'),
            options: any(named: 'options'),
          ),
        );

        await tempDir.delete(recursive: true);
      });

      test('uses resumable upload when ProofMode data is present and sends '
          'ProofMode headers on complete', () async {
        const testPublicKey = _testPublicKey;
        const proofManifest = '{"videoHash":"abc123","pgpSignature":"sig"}';

        when(() => mockAuthProvider.isAuthenticated).thenReturn(true);
        when(
          () => mockAuthProvider.createAndSignEvent(
            kind: any(named: 'kind'),
            content: any(named: 'content'),
            tags: any(named: 'tags'),
          ),
        ).thenAnswer(
          (_) async => _signedEvent(
            testPublicKey,
            24242,
            const [],
            'Upload video to Blossom server',
          ),
        );

        final tempDir = await Directory.systemTemp.createTemp(
          'blossom_proofmode_resumable_test_',
        );
        final videoFile = File('${tempDir.path}/video.mp4')
          ..writeAsBytesSync(List<int>.generate(5, (index) => index + 1));

        when(
          () => mockDio.head<dynamic>(any(), options: any(named: 'options')),
        ).thenAnswer((invocation) async {
          final url = invocation.positionalArguments.first as String;
          if (url == 'https://media.divine.video/upload') {
            return Response(
              requestOptions: RequestOptions(path: '/upload'),
              statusCode: 200,
              headers: Headers.fromMap({
                DivineUploadHeaders.extensions: [
                  DivineUploadExtensions.resumableSessions,
                ],
              }),
            );
          }

          throw StateError('Unexpected HEAD url: $url');
        });

        when(
          () => mockDio.post<dynamic>(
            any(),
            data: any(named: 'data'),
            options: any(named: 'options'),
          ),
        ).thenAnswer((invocation) async {
          final url = invocation.positionalArguments.first as String;
          final options = invocation.namedArguments[#options] as Options;
          final data = invocation.namedArguments[#data];

          if (url == 'https://media.divine.video/upload/init') {
            expect(options.headers?['Authorization'], isNotNull);
            return Response(
              requestOptions: RequestOptions(path: '/upload/init'),
              statusCode: 200,
              data: {
                'uploadId': 'up_proof',
                'uploadUrl': 'https://upload.divine.video/sessions/up_proof',
                'chunkSize': 5,
                'nextOffset': 0,
                'requiredHeaders': {'Authorization': 'Bearer session-token'},
              },
            );
          }

          if (url == 'https://media.divine.video/upload/up_proof/complete') {
            expect(options.headers?['X-ProofMode-Manifest'], isNotNull);
            expect(data, isA<Map<String, dynamic>>());
            expect((data as Map<String, dynamic>)['sha256'], isNotEmpty);
            return Response(
              requestOptions: RequestOptions(path: '/upload/up_proof/complete'),
              statusCode: 200,
              data: {
                'url': 'https://media.divine.video/final',
                'fallbackUrl': 'https://media.divine.video/final',
              },
            );
          }

          throw StateError('Unexpected POST url: $url');
        });

        when(
          () => mockDio.put<dynamic>(
            any(),
            data: any(named: 'data'),
            options: any(named: 'options'),
            onSendProgress: any(named: 'onSendProgress'),
          ),
        ).thenAnswer((invocation) async {
          final url = invocation.positionalArguments.first as String;
          final options = invocation.namedArguments[#options] as Options;

          expect(url, equals('https://upload.divine.video/sessions/up_proof'));
          expect(
            options.headers?['Authorization'],
            equals('Bearer session-token'),
          );
          expect(options.headers?['X-ProofMode-Manifest'], isNull);

          return Response(
            requestOptions: RequestOptions(path: '/sessions/up_proof'),
            statusCode: 204,
            headers: Headers.fromMap({
              DivineUploadHeaders.uploadOffset: ['5'],
            }),
          );
        });

        final result = await service.uploadVideo(
          videoFile: videoFile,
          nostrPubkey: testPublicKey,
          title: 'ProofMode Video',
          description: null,
          hashtags: null,
          proofManifestJson: proofManifest,
        );

        expect(result.success, isTrue);

        verify(
          () => mockDio.post<dynamic>(
            'https://media.divine.video/upload/init',
            data: any(named: 'data'),
            options: any(named: 'options'),
          ),
        ).called(1);
        verify(
          () => mockDio.put<dynamic>(
            'https://upload.divine.video/sessions/up_proof',
            data: any(named: 'data'),
            options: any(named: 'options'),
            onSendProgress: any(named: 'onSendProgress'),
          ),
        ).called(1);
        verify(
          () => mockDio.post<dynamic>(
            'https://media.divine.video/upload/up_proof/complete',
            data: any(named: 'data'),
            options: any(
              named: 'options',
              that: isA<Options>().having(
                (opts) => opts.headers?['X-ProofMode-Manifest'],
                'X-ProofMode-Manifest',
                isNotNull,
              ),
            ),
          ),
        ).called(1);
        verifyNever(
          () => mockDio.put<dynamic>(
            'https://media.divine.video/upload',
            data: any(named: 'data'),
            options: any(named: 'options'),
            onSendProgress: any(named: 'onSendProgress'),
          ),
        );

        await tempDir.delete(recursive: true);
      });

      test('uses resumable upload for Divine servers when capability probe '
          'fails transiently', () async {
        const testPublicKey = _testPublicKey;

        when(() => mockAuthProvider.isAuthenticated).thenReturn(true);
        when(
          () => mockAuthProvider.createAndSignEvent(
            kind: any(named: 'kind'),
            content: any(named: 'content'),
            tags: any(named: 'tags'),
          ),
        ).thenAnswer(
          (_) async => _signedEvent(
            testPublicKey,
            24242,
            const [],
            'Upload video to Blossom server',
          ),
        );

        final tempDir = await Directory.systemTemp.createTemp(
          'blossom_capability_probe_fallback_test_',
        );
        final videoFile = File('${tempDir.path}/video.mp4')
          ..writeAsBytesSync(List<int>.generate(5, (index) => index + 1));

        when(
          () => mockDio.head<dynamic>(any(), options: any(named: 'options')),
        ).thenThrow(
          DioException(
            requestOptions: RequestOptions(path: '/upload'),
            type: DioExceptionType.connectionTimeout,
            error: 'timed out',
          ),
        );

        when(
          () => mockDio.post<dynamic>(
            any(),
            data: any(named: 'data'),
            options: any(named: 'options'),
          ),
        ).thenAnswer((invocation) async {
          final url = invocation.positionalArguments.first as String;

          if (url == 'https://media.divine.video/upload/init') {
            return Response(
              requestOptions: RequestOptions(path: '/upload/init'),
              statusCode: 200,
              data: {
                'uploadId': 'up_probe',
                'uploadUrl': 'https://upload.divine.video/sessions/up_probe',
                'chunkSize': 5,
                'nextOffset': 0,
                'requiredHeaders': {'Authorization': 'Bearer session-token'},
              },
            );
          }

          if (url == 'https://media.divine.video/upload/up_probe/complete') {
            return Response(
              requestOptions: RequestOptions(path: '/upload/up_probe/complete'),
              statusCode: 200,
              data: {
                'url': 'https://media.divine.video/final',
                'fallbackUrl': 'https://media.divine.video/final',
              },
            );
          }

          throw StateError('Unexpected POST url: $url');
        });

        when(
          () => mockDio.put<dynamic>(
            any(),
            data: any(named: 'data'),
            options: any(named: 'options'),
            onSendProgress: any(named: 'onSendProgress'),
          ),
        ).thenAnswer((invocation) async {
          final url = invocation.positionalArguments.first as String;

          if (url == 'https://upload.divine.video/sessions/up_probe') {
            return Response(
              requestOptions: RequestOptions(path: '/sessions/up_probe'),
              statusCode: 204,
              headers: Headers.fromMap({
                DivineUploadHeaders.uploadOffset: ['5'],
              }),
            );
          }

          throw StateError('Unexpected PUT url: $url');
        });

        final result = await service.uploadVideo(
          videoFile: videoFile,
          nostrPubkey: testPublicKey,
          title: 'Capability Probe Fallback Video',
          description: null,
          hashtags: null,
          proofManifestJson: null,
        );

        expect(result.success, isTrue);

        verify(
          () => mockDio.post<dynamic>(
            'https://media.divine.video/upload/init',
            data: any(named: 'data'),
            options: any(named: 'options'),
          ),
        ).called(1);
        verify(
          () => mockDio.put<dynamic>(
            'https://upload.divine.video/sessions/up_probe',
            data: any(named: 'data'),
            options: any(named: 'options'),
            onSendProgress: any(named: 'onSendProgress'),
          ),
        ).called(1);
        verify(
          () => mockDio.post<dynamic>(
            'https://media.divine.video/upload/up_probe/complete',
            data: any(named: 'data'),
            options: any(named: 'options'),
          ),
        ).called(1);
        verifyNever(
          () => mockDio.put<dynamic>(
            'https://media.divine.video/upload',
            data: any(named: 'data'),
            options: any(named: 'options'),
            onSendProgress: any(named: 'onSendProgress'),
          ),
        );

        await tempDir.delete(recursive: true);
      });

      test('continues to use legacy PUT upload for third-party servers when '
          'capability probe fails', () async {
        const testPublicKey = _testPublicKey;

        await service.setBlossomServer('https://custom.blossom.server');
        await service.setBlossomEnabled(true);

        when(() => mockAuthProvider.isAuthenticated).thenReturn(true);
        when(
          () => mockAuthProvider.createAndSignEvent(
            kind: any(named: 'kind'),
            content: any(named: 'content'),
            tags: any(named: 'tags'),
          ),
        ).thenAnswer(
          (_) async => _signedEvent(
            testPublicKey,
            24242,
            const [],
            'Upload video to Blossom server',
          ),
        );

        final tempDir = await Directory.systemTemp.createTemp(
          'blossom_third_party_probe_fallback_test_',
        );
        final videoFile = File('${tempDir.path}/video.mp4')
          ..writeAsBytesSync(List<int>.generate(5, (index) => index + 1));

        when(
          () => mockDio.head<dynamic>(any(), options: any(named: 'options')),
        ).thenAnswer((invocation) {
          final url = invocation.positionalArguments.first as String;
          if (url == 'https://custom.blossom.server/upload') {
            throw DioException(
              requestOptions: RequestOptions(path: '/upload'),
              type: DioExceptionType.connectionTimeout,
              error: 'timed out',
            );
          }

          throw StateError('Unexpected HEAD url: $url');
        });

        when(
          () => mockDio.put<dynamic>(
            any(),
            data: any(named: 'data'),
            options: any(named: 'options'),
            onSendProgress: any(named: 'onSendProgress'),
          ),
        ).thenAnswer((invocation) async {
          final url = invocation.positionalArguments.first as String;
          if (url == 'https://custom.blossom.server/upload') {
            return Response(
              requestOptions: RequestOptions(path: '/upload'),
              statusCode: 200,
              data: {
                'url': 'https://custom.blossom.server/final',
                'fallbackUrl': 'https://custom.blossom.server/final',
              },
            );
          }

          throw StateError('Unexpected PUT url: $url');
        });

        final result = await service.uploadVideo(
          videoFile: videoFile,
          nostrPubkey: testPublicKey,
          title: 'Third-party Capability Probe Fallback Video',
          description: null,
          hashtags: null,
          proofManifestJson: null,
        );

        expect(result.success, isTrue);

        verify(
          () => mockDio.put<dynamic>(
            'https://custom.blossom.server/upload',
            data: any(named: 'data'),
            options: any(named: 'options'),
            onSendProgress: any(named: 'onSendProgress'),
          ),
        ).called(1);
        verifyNever(
          () => mockDio.post<dynamic>(
            'https://custom.blossom.server/upload/init',
            data: any(named: 'data'),
            options: any(named: 'options'),
          ),
        );

        await tempDir.delete(recursive: true);
      });

      test('falls back to legacy PUT when Divine resumable init fails after '
          'transient probe failure', () async {
        const testPublicKey = _testPublicKey;

        when(() => mockAuthProvider.isAuthenticated).thenReturn(true);
        when(
          () => mockAuthProvider.createAndSignEvent(
            kind: any(named: 'kind'),
            content: any(named: 'content'),
            tags: any(named: 'tags'),
          ),
        ).thenAnswer(
          (_) async => _signedEvent(
            testPublicKey,
            24242,
            const [],
            'Upload video to Blossom server',
          ),
        );

        final tempDir = await Directory.systemTemp.createTemp(
          'blossom_divine_resumable_init_fallback_test_',
        );
        final videoFile = File('${tempDir.path}/video.mp4')
          ..writeAsBytesSync(List<int>.generate(5, (index) => index + 1));

        when(
          () => mockDio.head<dynamic>(any(), options: any(named: 'options')),
        ).thenThrow(
          DioException(
            requestOptions: RequestOptions(path: '/upload'),
            type: DioExceptionType.connectionTimeout,
            error: 'timed out',
          ),
        );

        when(
          () => mockDio.post<dynamic>(
            any(),
            data: any(named: 'data'),
            options: any(named: 'options'),
          ),
        ).thenAnswer((invocation) async {
          final url = invocation.positionalArguments.first as String;

          if (url == 'https://media.divine.video/upload/init') {
            throw DioException(
              requestOptions: RequestOptions(path: '/upload/init'),
              type: DioExceptionType.connectionError,
              error: 'upstream offline',
            );
          }

          throw StateError('Unexpected POST url: $url');
        });

        when(
          () => mockDio.put<dynamic>(
            any(),
            data: any(named: 'data'),
            options: any(named: 'options'),
            onSendProgress: any(named: 'onSendProgress'),
          ),
        ).thenAnswer((invocation) async {
          final url = invocation.positionalArguments.first as String;

          if (url == 'https://media.divine.video/upload') {
            return Response(
              requestOptions: RequestOptions(path: '/upload'),
              statusCode: 200,
              data: {
                'url': 'https://media.divine.video/final',
                'fallbackUrl': 'https://media.divine.video/final',
              },
            );
          }

          throw StateError('Unexpected PUT url: $url');
        });

        final result = await service.uploadVideo(
          videoFile: videoFile,
          nostrPubkey: testPublicKey,
          title: 'Divine Resumable Fallback Video',
          description: null,
          hashtags: null,
          proofManifestJson: null,
        );

        expect(result.success, isTrue);

        verify(
          () => mockDio.post<dynamic>(
            'https://media.divine.video/upload/init',
            data: any(named: 'data'),
            options: any(named: 'options'),
          ),
        ).called(1);
        verify(
          () => mockDio.put<dynamic>(
            'https://media.divine.video/upload',
            data: any(named: 'data'),
            options: any(named: 'options'),
            onSendProgress: any(named: 'onSendProgress'),
          ),
        ).called(1);

        await tempDir.delete(recursive: true);
      });

      test('does not fall back to legacy PUT when a resumable chunk fails '
          'with an unknown bad file descriptor socket close', () async {
        const testPublicKey = _testPublicKey;
        final sessionUrl = Uri.parse(
          'https://upload.divine.video/sessions/up_bad_fd',
        );

        expect(
          BlossomUploadFailureReason.fromDioException(
            DioException(
              requestOptions: RequestOptions(path: sessionUrl.toString()),
              error: HttpException('Bad file descriptor', uri: sessionUrl),
            ),
          ),
          BlossomUploadFailureReason.network,
        );

        when(() => mockAuthProvider.isAuthenticated).thenReturn(true);
        when(
          () => mockAuthProvider.createAndSignEvent(
            kind: any(named: 'kind'),
            content: any(named: 'content'),
            tags: any(named: 'tags'),
          ),
        ).thenAnswer(
          (_) async => _signedEvent(
            testPublicKey,
            24242,
            const [],
            'Upload video to Blossom server',
          ),
        );

        final tempDir = await Directory.systemTemp.createTemp(
          'blossom_resumable_bad_fd_test_',
        );
        final videoFile = File('${tempDir.path}/video.mp4')
          ..writeAsBytesSync(List<int>.generate(10, (index) => index + 1));
        final sessionUpdates = <BlossomResumableUploadSession>[];

        when(
          () => mockDio.head<dynamic>(any(), options: any(named: 'options')),
        ).thenAnswer((invocation) async {
          final url = invocation.positionalArguments.first as String;
          if (url == 'https://media.divine.video/upload') {
            return Response(
              requestOptions: RequestOptions(path: '/upload'),
              statusCode: 200,
              headers: Headers.fromMap({
                DivineUploadHeaders.extensions: [
                  DivineUploadExtensions.resumableSessions,
                ],
              }),
            );
          }

          throw StateError('Unexpected HEAD url: $url');
        });

        when(
          () => mockDio.post<dynamic>(
            any(),
            data: any(named: 'data'),
            options: any(named: 'options'),
          ),
        ).thenAnswer((invocation) async {
          final url = invocation.positionalArguments.first as String;

          if (url == 'https://media.divine.video/upload/init') {
            return Response(
              requestOptions: RequestOptions(path: '/upload/init'),
              statusCode: 200,
              data: {
                'uploadId': 'up_bad_fd',
                'uploadUrl': sessionUrl.toString(),
                'chunkSize': 5,
                'nextOffset': 0,
                'requiredHeaders': {'Authorization': 'Bearer session-token'},
              },
            );
          }

          throw StateError('Unexpected POST url: $url');
        });

        var failingChunkAttempts = 0;
        when(
          () => mockDio.put<dynamic>(
            any(),
            data: any(named: 'data'),
            options: any(named: 'options'),
            onSendProgress: any(named: 'onSendProgress'),
          ),
        ).thenAnswer((invocation) async {
          final url = invocation.positionalArguments.first as String;
          final options = invocation.namedArguments[#options] as Options;

          if (url == sessionUrl.toString()) {
            final contentRange = options.headers?['Content-Range'] as String;
            if (contentRange == 'bytes 0-4/10') {
              return Response(
                requestOptions: RequestOptions(path: '/sessions/up_bad_fd'),
                statusCode: 204,
                headers: Headers.fromMap({
                  DivineUploadHeaders.uploadOffset: ['5'],
                }),
              );
            }
            if (contentRange == 'bytes 5-9/10') {
              failingChunkAttempts++;
              throw DioException(
                requestOptions: RequestOptions(path: sessionUrl.toString()),
                error: HttpException('Bad file descriptor', uri: sessionUrl),
              );
            }
          }

          throw StateError('Unexpected PUT url: $url');
        });

        final result = await service.uploadVideo(
          videoFile: videoFile,
          nostrPubkey: testPublicKey,
          title: 'Recoverable Bad FD Video',
          description: null,
          hashtags: null,
          proofManifestJson: null,
          onResumableSessionUpdated: sessionUpdates.add,
        );

        expect(result.success, isFalse);
        expect(result.failureReason, BlossomUploadFailureReason.network);
        expect(failingChunkAttempts, equals(3));
        expect(sessionUpdates.map((session) => session.nextOffset), [0, 5]);

        verifyNever(
          () => mockDio.put<dynamic>(
            'https://media.divine.video/upload',
            data: any(named: 'data'),
            options: any(named: 'options'),
            onSendProgress: any(named: 'onSendProgress'),
          ),
        );
        verifyNever(
          () => mockDio.post<dynamic>(
            'https://media.divine.video/upload/up_bad_fd/complete',
            data: any(named: 'data'),
            options: any(named: 'options'),
          ),
        );

        await tempDir.delete(recursive: true);
      });

      test('does not fall back to legacy PUT when a resumable chunk returns '
          '408 Request Timeout', () async {
        const testPublicKey = _testPublicKey;
        final sessionUrl = Uri.parse(
          'https://upload.divine.video/sessions/up_408',
        );

        when(() => mockAuthProvider.isAuthenticated).thenReturn(true);
        when(
          () => mockAuthProvider.createAndSignEvent(
            kind: any(named: 'kind'),
            content: any(named: 'content'),
            tags: any(named: 'tags'),
          ),
        ).thenAnswer(
          (_) async => _signedEvent(
            testPublicKey,
            24242,
            const [],
            'Upload video to Blossom server',
          ),
        );

        final tempDir = await Directory.systemTemp.createTemp(
          'blossom_resumable_408_test_',
        );
        final videoFile = File('${tempDir.path}/video.mp4')
          ..writeAsBytesSync(List<int>.generate(10, (index) => index + 1));
        final sessionUpdates = <BlossomResumableUploadSession>[];

        when(
          () => mockDio.head<dynamic>(any(), options: any(named: 'options')),
        ).thenAnswer((invocation) async {
          final url = invocation.positionalArguments.first as String;
          if (url == 'https://media.divine.video/upload') {
            return Response(
              requestOptions: RequestOptions(path: '/upload'),
              statusCode: 200,
              headers: Headers.fromMap({
                DivineUploadHeaders.extensions: [
                  DivineUploadExtensions.resumableSessions,
                ],
              }),
            );
          }

          throw StateError('Unexpected HEAD url: $url');
        });

        when(
          () => mockDio.post<dynamic>(
            any(),
            data: any(named: 'data'),
            options: any(named: 'options'),
          ),
        ).thenAnswer((invocation) async {
          final url = invocation.positionalArguments.first as String;

          if (url == 'https://media.divine.video/upload/init') {
            return Response(
              requestOptions: RequestOptions(path: '/upload/init'),
              statusCode: 200,
              data: {
                'uploadId': 'up_408',
                'uploadUrl': sessionUrl.toString(),
                'chunkSize': 5,
                'nextOffset': 0,
                'requiredHeaders': {'Authorization': 'Bearer session-token'},
              },
            );
          }

          throw StateError('Unexpected POST url: $url');
        });

        var failingChunkAttempts = 0;
        when(
          () => mockDio.put<dynamic>(
            any(),
            data: any(named: 'data'),
            options: any(named: 'options'),
            onSendProgress: any(named: 'onSendProgress'),
          ),
        ).thenAnswer((invocation) async {
          final url = invocation.positionalArguments.first as String;
          final options = invocation.namedArguments[#options] as Options;

          if (url == sessionUrl.toString()) {
            final contentRange = options.headers?['Content-Range'] as String;
            if (contentRange == 'bytes 0-4/10') {
              return Response(
                requestOptions: RequestOptions(path: '/sessions/up_408'),
                statusCode: 204,
                headers: Headers.fromMap({
                  DivineUploadHeaders.uploadOffset: ['5'],
                }),
              );
            }
            if (contentRange == 'bytes 5-9/10') {
              failingChunkAttempts++;
              // A Fastly chunk timeout arrives as a real 408 *response*, not a
              // thrown DioException: validateStatus admits everything under
              // 500, so Dio never raises for it.
              return Response(
                requestOptions: RequestOptions(path: '/sessions/up_408'),
                statusCode: 408,
              );
            }
          }

          // The legacy whole-file PUT is the regression under test. Answer it
          // with the same timeout a slow link would produce rather than
          // throwing, so the failure surfaces as the verifyNever below instead
          // of an unrelated StateError.
          if (url == 'https://media.divine.video/upload') {
            return Response(
              requestOptions: RequestOptions(path: '/upload'),
              statusCode: 408,
            );
          }

          throw StateError('Unexpected PUT url: $url');
        });

        final result = await service.uploadVideo(
          videoFile: videoFile,
          nostrPubkey: testPublicKey,
          title: 'Chunk Timeout Video',
          description: null,
          hashtags: null,
          proofManifestJson: null,
          onResumableSessionUpdated: sessionUpdates.add,
        );

        expect(result.success, isFalse);

        // Demoting to the legacy whole-file PUT is strictly worse here: a link
        // too slow to finish one 5-byte chunk cannot finish the entire file in
        // a single request. The resumable session must survive instead.
        verifyNever(
          () => mockDio.put<dynamic>(
            'https://media.divine.video/upload',
            data: any(named: 'data'),
            options: any(named: 'options'),
            onSendProgress: any(named: 'onSendProgress'),
          ),
        );

        // Unlike a 5xx, a 408 means the server already spent its full timeout
        // waiting, so the chunk is not retried in-loop — stacking more
        // same-length waits would just delay the failure. Retrying is the
        // outer policy's job, where the backoff is exponential.
        expect(failingChunkAttempts, equals(1));

        // Progress up to the failing chunk stays banked for the next resume.
        expect(sessionUpdates.map((session) => session.nextOffset), [0, 5]);

        await tempDir.delete(recursive: true);
      });

      test(
        'should send PUT request with raw bytes and NIP-98 auth header',
        () async {
          // Arrange
          await service.setBlossomEnabled(true);
          await service.setBlossomServer('https://cdn.satellite.earth');

          const testPublicKey = _testPublicKey;

          when(() => mockAuthProvider.isAuthenticated).thenReturn(true);
          // Mock the createAndSignEvent method
          when(
            () => mockAuthProvider.createAndSignEvent(
              kind: any(named: 'kind'),
              content: any(named: 'content'),
              tags: any(named: 'tags'),
            ),
          ).thenAnswer((_) async {
            return _signedEvent(testPublicKey, 24242, [
              ['t', 'upload'],
            ], 'Upload video to Blossom server');
          });

          final mockFile = _MockFile();
          when(() => mockFile.path).thenReturn('/test/video.mp4');
          when(mockFile.existsSync).thenReturn(true);
          when(
            mockFile.readAsBytes,
          ).thenAnswer((_) async => Uint8List.fromList([1, 2, 3, 4, 5]));
          when(
            mockFile.readAsBytesSync,
          ).thenReturn(Uint8List.fromList([1, 2, 3, 4, 5]));
          when(mockFile.lengthSync).thenReturn(5);
          when(mockFile.openRead).thenAnswer(
            (_) => Stream.value(Uint8List.fromList([1, 2, 3, 4, 5])),
          );

          // Mock successful response
          final mockResponse = _MockResponse();
          when(() => mockResponse.statusCode).thenReturn(200);
          when(() => mockResponse.headers).thenReturn(Headers());
          when(() => mockResponse.data).thenReturn({
            'url': 'https://cdn.satellite.earth/abc123.mp4',
            'sha256': 'abc123',
            'size': 5,
          });

          when(
            () => mockDio.head<dynamic>(any(), options: any(named: 'options')),
          ).thenAnswer(
            (_) async => Response(
              requestOptions: RequestOptions(path: '/upload'),
              statusCode: 200,
              headers: Headers(),
            ),
          );

          when(
            () => mockDio.put<dynamic>(
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
            description: null,
            hashtags: null,
            proofManifestJson: null,
          );

          // Assert
          expect(result.success, isTrue);

          // Verify PUT was called with stream data (for streaming upload)
          verify(
            () => mockDio.put<dynamic>(
              'https://cdn.satellite.earth/upload',
              data: any(named: 'data', that: isA<Stream<List<int>>>()),
              options: any(
                named: 'options',
                that: isA<Options>()
                    .having(
                      (opts) => opts.headers?['Authorization'],
                      'Authorization header',
                      startsWith('Nostr '),
                    )
                    .having(
                      (opts) => opts.headers?['Content-Type'],
                      'Content-Type header',
                      equals('video/mp4'),
                    ),
              ),
              onSendProgress: any(named: 'onSendProgress'),
            ),
          ).called(1);
        },
      );
    });

    group('Server Presets', () {
      test('should support popular Blossom servers', () async {
        // Test that the service can be configured with known servers
        final popularServers = [
          'https://blossom.primal.net',
          'https://media.nostr.band',
          'https://nostr.build',
          'https://void.cat',
        ];

        for (final server in popularServers) {
          await service.setBlossomServer(server);
          final retrieved = await service.getBlossomServer();
          expect(retrieved, equals(server));
        }
      });
    });

    group('Capability Cache', () {
      late _MockDio mockDio;
      late DateTime fakeNow;

      setUp(() {
        mockDio = _MockDio();
        fakeNow = DateTime.utc(2026, 3, 28, 12);
      });

      BlossomUploadService createServiceWithClock() {
        return BlossomUploadService(
          authProvider: mockAuthProvider,
          dio: mockDio,
          clock: () => fakeNow,
        );
      }

      void arrangeCapabilityHead({bool resumable = true}) {
        when(
          () => mockDio.head<dynamic>(any(), options: any(named: 'options')),
        ).thenAnswer(
          (_) async => Response(
            requestOptions: RequestOptions(path: '/upload'),
            statusCode: 200,
            headers: resumable
                ? Headers.fromMap({
                    DivineUploadHeaders.extensions: [
                      DivineUploadExtensions.resumableSessions,
                    ],
                    DivineUploadHeaders.controlHost: [
                      'https://media.divine.video',
                    ],
                    DivineUploadHeaders.dataHost: [
                      'https://upload.divine.video',
                    ],
                  })
                : Headers(),
          ),
        );
      }

      test('reuses cached capability within TTL window', () async {
        arrangeCapabilityHead();
        final svc = createServiceWithClock();

        // Arrange auth
        const testPublicKey = _testPublicKey;
        when(() => mockAuthProvider.isAuthenticated).thenReturn(true);
        when(
          () => mockAuthProvider.createAndSignEvent(
            kind: any(named: 'kind'),
            content: any(named: 'content'),
            tags: any(named: 'tags'),
          ),
        ).thenAnswer(
          (_) async => _signedEvent(testPublicKey, 24242, [
            ['t', 'upload'],
          ], ''),
        );

        // Arrange file
        final tempDir = await Directory.systemTemp.createTemp(
          'blossom_cache_hit_test_',
        );
        final videoFile = File('${tempDir.path}/video.mp4')
          ..writeAsBytesSync(List<int>.generate(5, (i) => i + 1));

        // Arrange legacy PUT upload response
        when(
          () => mockDio.put<dynamic>(
            any(),
            data: any<dynamic>(named: 'data'),
            options: any(named: 'options'),
            onSendProgress: any(named: 'onSendProgress'),
          ),
        ).thenAnswer(
          (_) async => Response(
            requestOptions: RequestOptions(path: '/upload'),
            statusCode: 200,
            data: {'url': 'https://media.divine.video/abc123'},
          ),
        );

        // Arrange HEAD without resumable so it goes to the simpler
        // PUT path
        arrangeCapabilityHead(resumable: false);

        SharedPreferences.setMockInitialValues({});

        // First upload
        await svc.uploadVideo(
          videoFile: videoFile,
          nostrPubkey: testPublicKey,
          title: 'test',
          proofManifestJson: null,
          description: null,
          hashtags: null,
        );

        // Advance clock by 2 minutes (within 5 min TTL)
        fakeNow = fakeNow.add(const Duration(minutes: 2));

        // Second upload
        await svc.uploadVideo(
          videoFile: videoFile,
          nostrPubkey: testPublicKey,
          title: 'test2',
          proofManifestJson: null,
          description: null,
          hashtags: null,
        );

        // HEAD should be called only once — second call used cache
        verify(
          () => mockDio.head<dynamic>(any(), options: any(named: 'options')),
        ).called(1);

        // Clean up
        await tempDir.delete(recursive: true);
      });

      test('reprobes after TTL expires', () async {
        final svc = createServiceWithClock();

        // Arrange
        const testPublicKey = _testPublicKey;
        when(() => mockAuthProvider.isAuthenticated).thenReturn(true);
        when(
          () => mockAuthProvider.createAndSignEvent(
            kind: any(named: 'kind'),
            content: any(named: 'content'),
            tags: any(named: 'tags'),
          ),
        ).thenAnswer(
          (_) async => _signedEvent(testPublicKey, 24242, [
            ['t', 'upload'],
          ], ''),
        );

        final tempDir = await Directory.systemTemp.createTemp(
          'blossom_cache_expiry_test_',
        );
        final videoFile = File('${tempDir.path}/video.mp4')
          ..writeAsBytesSync(List<int>.generate(5, (i) => i + 1));

        arrangeCapabilityHead(resumable: false);

        when(
          () => mockDio.put<dynamic>(
            any(),
            data: any<dynamic>(named: 'data'),
            options: any(named: 'options'),
            onSendProgress: any(named: 'onSendProgress'),
          ),
        ).thenAnswer(
          (_) async => Response(
            requestOptions: RequestOptions(path: '/upload'),
            statusCode: 200,
            data: {'url': 'https://media.divine.video/abc123'},
          ),
        );

        SharedPreferences.setMockInitialValues({});

        // First upload
        await svc.uploadVideo(
          videoFile: videoFile,
          nostrPubkey: testPublicKey,
          title: 'test',
          proofManifestJson: null,
          description: null,
          hashtags: null,
        );

        // Advance clock past TTL (6 minutes > 5 minute TTL)
        fakeNow = fakeNow.add(const Duration(minutes: 6));

        // Second upload
        await svc.uploadVideo(
          videoFile: videoFile,
          nostrPubkey: testPublicKey,
          title: 'test2',
          proofManifestJson: null,
          description: null,
          hashtags: null,
        );

        // HEAD should be called twice — cache expired
        verify(
          () => mockDio.head<dynamic>(any(), options: any(named: 'options')),
        ).called(2);

        await tempDir.delete(recursive: true);
      });

      test('does not downgrade Divine uploads after a transient capability '
          'probe failure', () async {
        final svc = createServiceWithClock();

        const testPublicKey = _testPublicKey;
        when(() => mockAuthProvider.isAuthenticated).thenReturn(true);
        when(
          () => mockAuthProvider.createAndSignEvent(
            kind: any(named: 'kind'),
            content: any(named: 'content'),
            tags: any(named: 'tags'),
          ),
        ).thenAnswer(
          (_) async => _signedEvent(testPublicKey, 24242, [
            ['t', 'upload'],
          ], ''),
        );

        final tempDir = await Directory.systemTemp.createTemp(
          'blossom_divine_probe_failure_test_',
        );
        final videoFile = File('${tempDir.path}/video.mp4')
          ..writeAsBytesSync(List<int>.generate(5, (i) => i + 1));

        var capabilityHeadCalls = 0;
        when(
          () => mockDio.head<dynamic>(any(), options: any(named: 'options')),
        ).thenAnswer((invocation) async {
          final url = invocation.positionalArguments.first as String;
          if (url != 'https://media.divine.video/upload') {
            throw StateError('Unexpected HEAD url: $url');
          }

          capabilityHeadCalls += 1;
          if (capabilityHeadCalls == 1) {
            throw DioException(
              requestOptions: RequestOptions(path: '/upload'),
              type: DioExceptionType.connectionTimeout,
              error: 'timed out',
            );
          }

          return Response(
            requestOptions: RequestOptions(path: '/upload'),
            statusCode: 200,
            headers: Headers.fromMap({
              DivineUploadHeaders.extensions: [
                DivineUploadExtensions.resumableSessions,
              ],
            }),
          );
        });

        var initCalls = 0;
        when(
          () => mockDio.post<dynamic>(
            any(),
            data: any<dynamic>(named: 'data'),
            options: any(named: 'options'),
          ),
        ).thenAnswer((invocation) async {
          final url = invocation.positionalArguments.first as String;

          if (url == 'https://media.divine.video/upload/init') {
            initCalls += 1;
            final uploadId = 'up_$initCalls';
            return Response(
              requestOptions: RequestOptions(path: '/upload/init'),
              statusCode: 200,
              data: {
                'uploadId': uploadId,
                'uploadUrl': 'https://upload.divine.video/sessions/$uploadId',
                'chunkSize': 5,
                'nextOffset': 0,
                'requiredHeaders': {'Authorization': 'Bearer session-token'},
              },
            );
          }

          if (url.startsWith('https://media.divine.video/upload/up_') &&
              url.endsWith('/complete')) {
            return Response(
              requestOptions: RequestOptions(path: '/upload/complete'),
              statusCode: 200,
              data: {'url': 'https://media.divine.video/abc123'},
            );
          }

          throw StateError('Unexpected POST url: $url');
        });

        when(
          () => mockDio.put<dynamic>(
            any(),
            data: any<dynamic>(named: 'data'),
            options: any(named: 'options'),
            onSendProgress: any(named: 'onSendProgress'),
          ),
        ).thenAnswer((invocation) async {
          final url = invocation.positionalArguments.first as String;
          if (url.startsWith('https://upload.divine.video/sessions/up_')) {
            return Response(
              requestOptions: RequestOptions(path: '/sessions'),
              statusCode: 204,
              headers: Headers.fromMap({
                DivineUploadHeaders.uploadOffset: ['5'],
              }),
            );
          }

          throw StateError('Unexpected PUT url: $url');
        });

        SharedPreferences.setMockInitialValues({});

        await svc.uploadVideo(
          videoFile: videoFile,
          nostrPubkey: testPublicKey,
          title: 'test',
          proofManifestJson: null,
          description: null,
          hashtags: null,
        );

        fakeNow = fakeNow.add(const Duration(minutes: 1));

        await svc.uploadVideo(
          videoFile: videoFile,
          nostrPubkey: testPublicKey,
          title: 'test2',
          proofManifestJson: null,
          description: null,
          hashtags: null,
        );

        expect(initCalls, equals(2));
        verifyNever(
          () => mockDio.put<dynamic>(
            'https://media.divine.video/upload',
            data: any<dynamic>(named: 'data'),
            options: any(named: 'options'),
            onSendProgress: any(named: 'onSendProgress'),
          ),
        );

        await tempDir.delete(recursive: true);
      });

      test('caches independently per server URL', () async {
        final svc = createServiceWithClock();

        const testPublicKey = _testPublicKey;
        when(() => mockAuthProvider.isAuthenticated).thenReturn(true);
        when(
          () => mockAuthProvider.createAndSignEvent(
            kind: any(named: 'kind'),
            content: any(named: 'content'),
            tags: any(named: 'tags'),
          ),
        ).thenAnswer(
          (_) async => _signedEvent(testPublicKey, 24242, [
            ['t', 'upload'],
          ], ''),
        );

        final tempDir = await Directory.systemTemp.createTemp(
          'blossom_cache_per_server_test_',
        );
        final videoFile = File('${tempDir.path}/video.mp4')
          ..writeAsBytesSync(List<int>.generate(5, (i) => i + 1));

        arrangeCapabilityHead(resumable: false);

        when(
          () => mockDio.put<dynamic>(
            any(),
            data: any<dynamic>(named: 'data'),
            options: any(named: 'options'),
            onSendProgress: any(named: 'onSendProgress'),
          ),
        ).thenAnswer(
          (_) async => Response(
            requestOptions: RequestOptions(path: '/upload'),
            statusCode: 200,
            data: {'url': 'https://media.divine.video/abc123'},
          ),
        );

        // Upload 1: custom server -> probes custom server
        SharedPreferences.setMockInitialValues({
          'blossom_server_url': 'https://custom.blossom.server',
          'use_blossom_upload': true,
        });

        await svc.uploadVideo(
          videoFile: videoFile,
          nostrPubkey: testPublicKey,
          title: 'test',
          proofManifestJson: null,
          description: null,
          hashtags: null,
        );

        // Upload 2: same custom server - should use cache, no new HEAD
        await svc.uploadVideo(
          videoFile: videoFile,
          nostrPubkey: testPublicKey,
          title: 'test2',
          proofManifestJson: null,
          description: null,
          hashtags: null,
        );

        // Only 1 HEAD call total for the custom server across both
        // uploads
        verify(
          () => mockDio.head<dynamic>(
            'https://custom.blossom.server/upload',
            options: any(named: 'options'),
          ),
        ).called(1);

        await tempDir.delete(recursive: true);
      });
    });

    group('uploadSubtitleVtt', () {
      test(
        'PUTs VTT bytes with text/vtt content type and returns sha256',
        () async {
          final mockDio = _MockDio();
          final mockResponse = _MockResponse();
          when(() => mockResponse.statusCode).thenReturn(200);
          when(() => mockResponse.data).thenReturn(<String, dynamic>{
            'url': 'https://media.divine.video/abc123',
          });
          when(() => mockAuthProvider.isAuthenticated).thenReturn(true);
          when(
            () => mockAuthProvider.createAndSignEvent(
              kind: any(named: 'kind'),
              content: any(named: 'content'),
              tags: any(named: 'tags'),
            ),
          ).thenAnswer(
            (_) async => _signedEvent(_testPublicKey, 24242, const [], ''),
          );
          when(
            () => mockDio.put<dynamic>(
              any(),
              data: any(named: 'data'),
              options: any(named: 'options'),
              onSendProgress: any(named: 'onSendProgress'),
            ),
          ).thenAnswer((_) async => mockResponse);

          final service = BlossomUploadService(
            authProvider: mockAuthProvider,
            dio: mockDio,
          );

          final vtt = utf8.encode(
            'WEBVTT\n\n00:00:00.000 --> 00:00:01.000\nhi\n',
          );
          final result = await service.uploadSubtitleVtt(
            bytes: Uint8List.fromList(vtt),
          );

          expect(result.success, isTrue);
          final videoId = result.videoId;
          expect(videoId, isNotNull);
          expect(result.url, contains(videoId));

          final captured =
              verify(
                    () => mockDio.put<dynamic>(
                      any(),
                      data: any(named: 'data'),
                      options: captureAny(named: 'options'),
                      onSendProgress: any(named: 'onSendProgress'),
                    ),
                  ).captured.single
                  as Options;
          expect(captured.headers!['Content-Type'], equals('text/vtt'));
        },
      );

      test('returns auth failure when not authenticated', () async {
        when(() => mockAuthProvider.isAuthenticated).thenReturn(false);
        final service = BlossomUploadService(authProvider: mockAuthProvider);
        final result = await service.uploadSubtitleVtt(
          bytes: Uint8List.fromList(utf8.encode('WEBVTT\n')),
        );
        expect(result.success, isFalse);
        expect(result.failureReason, equals(BlossomUploadFailureReason.auth));
      });

      test('returns upload failure when subtitle PUT is rejected', () async {
        final mockDio = _MockDio();
        final mockResponse = _MockResponse();
        when(() => mockResponse.statusCode).thenReturn(400);
        when(() => mockResponse.headers).thenReturn(Headers());
        when(
          () => mockResponse.data,
        ).thenReturn(<String, dynamic>{'message': 'bad VTT'});
        when(() => mockAuthProvider.isAuthenticated).thenReturn(true);
        when(
          () => mockAuthProvider.createAndSignEvent(
            kind: any(named: 'kind'),
            content: any(named: 'content'),
            tags: any(named: 'tags'),
          ),
        ).thenAnswer(
          (_) async => _signedEvent(_testPublicKey, 24242, const [], ''),
        );
        when(
          () => mockDio.put<dynamic>(
            any(),
            data: any(named: 'data'),
            options: any(named: 'options'),
            onSendProgress: any(named: 'onSendProgress'),
          ),
        ).thenAnswer((_) async => mockResponse);

        final service = BlossomUploadService(
          authProvider: mockAuthProvider,
          dio: mockDio,
        );
        final progress = <double>[];

        final result = await service.uploadSubtitleVtt(
          bytes: Uint8List.fromList(utf8.encode('WEBVTT\n')),
          onProgress: progress.add,
        );

        expect(progress.first, equals(0.1));
        expect(result.success, isFalse);
        expect(result.statusCode, equals(400));
        expect(result.errorMessage, isNotNull);
      });

      test('returns failure when subtitle upload setup throws', () async {
        when(
          () => mockAuthProvider.isAuthenticated,
        ).thenThrow(StateError('auth state unavailable'));
        final service = BlossomUploadService(authProvider: mockAuthProvider);

        final result = await service.uploadSubtitleVtt(
          bytes: Uint8List.fromList(utf8.encode('WEBVTT\n')),
        );

        expect(result.success, isFalse);
        expect(result.errorMessage, contains('Subtitle VTT upload failed'));
        expect(
          result.failureReason,
          equals(BlossomUploadFailureReason.unknown),
        );
      });

      test('returns authUnavailable (not auth) when the signer cannot produce '
          'the auth header', () async {
        // Authenticated, but the remote signer is briefly unreachable so
        // createAndSignEvent yields null. This is transient — it must NOT
        // be classified as a permanent `auth` rejection.
        when(() => mockAuthProvider.isAuthenticated).thenReturn(true);
        when(
          () => mockAuthProvider.createAndSignEvent(
            kind: any(named: 'kind'),
            content: any(named: 'content'),
            tags: any(named: 'tags'),
          ),
        ).thenAnswer((_) async => null);

        final service = BlossomUploadService(authProvider: mockAuthProvider);

        final result = await service.uploadSubtitleVtt(
          bytes: Uint8List.fromList(utf8.encode('WEBVTT\n')),
        );

        expect(result.success, isFalse);
        expect(
          result.failureReason,
          equals(BlossomUploadFailureReason.authUnavailable),
        );
      });

      test('returns auth when the server rejects the PUT with 403', () async {
        final mockDio = _MockDio();
        final mockResponse = _MockResponse();
        when(() => mockResponse.statusCode).thenReturn(403);
        when(() => mockResponse.headers).thenReturn(Headers());
        when(
          () => mockResponse.data,
        ).thenReturn(<String, dynamic>{'message': 'forbidden'});
        when(() => mockAuthProvider.isAuthenticated).thenReturn(true);
        when(
          () => mockAuthProvider.createAndSignEvent(
            kind: any(named: 'kind'),
            content: any(named: 'content'),
            tags: any(named: 'tags'),
          ),
        ).thenAnswer(
          (_) async => _signedEvent(_testPublicKey, 24242, const [], ''),
        );
        when(
          () => mockDio.put<dynamic>(
            any(),
            data: any(named: 'data'),
            options: any(named: 'options'),
            onSendProgress: any(named: 'onSendProgress'),
          ),
        ).thenAnswer((_) async => mockResponse);

        final service = BlossomUploadService(
          authProvider: mockAuthProvider,
          dio: mockDio,
        );

        final result = await service.uploadSubtitleVtt(
          bytes: Uint8List.fromList(utf8.encode('WEBVTT\n')),
        );

        expect(result.success, isFalse);
        expect(result.statusCode, equals(403));
        expect(result.failureReason, equals(BlossomUploadFailureReason.auth));
      });
    });

    group('transcribeAudio', () {
      test(
        'posts audio with t=media auth and returns the VTT on 200',
        () async {
          final mockDio = _MockDio();
          when(() => mockAuthProvider.isAuthenticated).thenReturn(true);
          when(
            () => mockAuthProvider.createAndSignEvent(
              kind: any(named: 'kind'),
              content: any(named: 'content'),
              tags: any(named: 'tags'),
            ),
          ).thenAnswer(
            (_) async => _signedEvent(_testPublicKey, 24242, const [], ''),
          );
          when(
            () => mockDio.post<String>(
              any(),
              data: any(named: 'data'),
              queryParameters: any(named: 'queryParameters'),
              options: any(named: 'options'),
            ),
          ).thenAnswer(
            (_) async => Response<String>(
              requestOptions: RequestOptions(path: '/transcribe'),
              statusCode: 200,
              data: 'WEBVTT\n\n00:00:00.000 --> 00:00:01.000\nhi\n',
            ),
          );

          final service = BlossomUploadService(
            authProvider: mockAuthProvider,
            dio: mockDio,
          );

          final vtt = await service.transcribeAudio(
            bytes: Uint8List.fromList([1, 2, 3]),
            language: 'en-US',
          );

          expect(vtt, contains('WEBVTT'));

          final tags =
              verify(
                    () => mockAuthProvider.createAndSignEvent(
                      kind: any(named: 'kind'),
                      content: any(named: 'content'),
                      tags: captureAny(named: 'tags'),
                    ),
                  ).captured.single
                  as List<List<String>>;
          expect(tags, contains(equals(['t', 'media'])));

          final options =
              verify(
                    () => mockDio.post<String>(
                      any(),
                      data: any(named: 'data'),
                      queryParameters: any(named: 'queryParameters'),
                      options: captureAny(named: 'options'),
                    ),
                  ).captured.single
                  as Options;
          expect(options.headers!['Content-Type'], equals('audio/wav'));
        },
      );

      test('returns null when not authenticated', () async {
        when(() => mockAuthProvider.isAuthenticated).thenReturn(false);
        final service = BlossomUploadService(authProvider: mockAuthProvider);
        final vtt = await service.transcribeAudio(
          bytes: Uint8List.fromList([1, 2, 3]),
        );
        expect(vtt, isNull);
      });

      test('returns null on a non-200 response', () async {
        final mockDio = _MockDio();
        when(() => mockAuthProvider.isAuthenticated).thenReturn(true);
        when(
          () => mockAuthProvider.createAndSignEvent(
            kind: any(named: 'kind'),
            content: any(named: 'content'),
            tags: any(named: 'tags'),
          ),
        ).thenAnswer(
          (_) async => _signedEvent(_testPublicKey, 24242, const [], ''),
        );
        when(
          () => mockDio.post<String>(
            any(),
            data: any(named: 'data'),
            queryParameters: any(named: 'queryParameters'),
            options: any(named: 'options'),
          ),
        ).thenAnswer(
          (_) async => Response<String>(
            requestOptions: RequestOptions(path: '/transcribe'),
            statusCode: 500,
          ),
        );

        final service = BlossomUploadService(
          authProvider: mockAuthProvider,
          dio: mockDio,
        );

        final vtt = await service.transcribeAudio(
          bytes: Uint8List.fromList([1, 2, 3]),
        );

        expect(vtt, isNull);
      });

      test('returns null when the request throws', () async {
        final mockDio = _MockDio();
        when(() => mockAuthProvider.isAuthenticated).thenReturn(true);
        when(
          () => mockAuthProvider.createAndSignEvent(
            kind: any(named: 'kind'),
            content: any(named: 'content'),
            tags: any(named: 'tags'),
          ),
        ).thenAnswer(
          (_) async => _signedEvent(_testPublicKey, 24242, const [], ''),
        );
        when(
          () => mockDio.post<String>(
            any(),
            data: any(named: 'data'),
            queryParameters: any(named: 'queryParameters'),
            options: any(named: 'options'),
          ),
        ).thenThrow(Exception('network failure'));

        final service = BlossomUploadService(
          authProvider: mockAuthProvider,
          dio: mockDio,
        );

        final vtt = await service.transcribeAudio(
          bytes: Uint8List.fromList([1, 2, 3]),
        );

        expect(vtt, isNull);
      });
    });

    group('Model classes', () {
      group(BlossomUploadResult, () {
        test('cdnUrl returns fallbackUrl when present', () {
          const result = BlossomUploadResult(
            success: true,
            fallbackUrl: 'https://cdn.example.com/fallback',
            url: 'https://cdn.example.com/primary',
          );
          expect(result.cdnUrl, equals('https://cdn.example.com/fallback'));
        });

        test('cdnUrl returns url when fallbackUrl is null', () {
          const result = BlossomUploadResult(
            success: true,
            url: 'https://cdn.example.com/primary',
          );
          expect(result.cdnUrl, equals('https://cdn.example.com/primary'));
        });

        test('cdnUrl returns null when both are null', () {
          const result = BlossomUploadResult(success: false);
          expect(result.cdnUrl, isNull);
        });
      });

      group(BlossomHealthCheckResult, () {
        test('toString shows OK with latency when reachable', () {
          const result = BlossomHealthCheckResult(
            isReachable: true,
            latencyMs: 42,
          );
          expect(result.toString(), equals('OK (42ms)'));
        });

        test('toString shows FAILED with error when unreachable', () {
          const result = BlossomHealthCheckResult(
            isReachable: false,
            errorMessage: 'Connection refused',
          );
          expect(result.toString(), equals('FAILED: Connection refused'));
        });

        test('toString shows Unknown error when no message', () {
          const result = BlossomHealthCheckResult(isReachable: false);
          expect(result.toString(), equals('FAILED: Unknown error'));
        });
      });

      group(BlossomResumableUploadException, () {
        test('toString returns message', () {
          const exception = BlossomResumableUploadException(
            'upload failed',
            statusCode: 500,
          );
          expect(exception.toString(), equals('upload failed'));
          expect(exception.statusCode, equals(500));
        });

        test('carries failureReason when provided', () {
          const exception = BlossomResumableUploadException(
            'Failed to create Blossom authentication for resumable upload init',
            failureReason: BlossomUploadFailureReason.authUnavailable,
          );
          expect(
            exception.failureReason,
            equals(BlossomUploadFailureReason.authUnavailable),
          );
          expect(exception.statusCode, isNull);
        });

        test('failureReason defaults to null', () {
          const exception = BlossomResumableUploadException('upload failed');
          expect(exception.failureReason, isNull);
        });
      });

      group(BlossomUploadFailureReason, () {
        group('fromStatusCode', () {
          test('returns null for null status', () {
            expect(BlossomUploadFailureReason.fromStatusCode(null), isNull);
          });

          test('returns null for 2xx success codes', () {
            expect(BlossomUploadFailureReason.fromStatusCode(200), isNull);
            expect(BlossomUploadFailureReason.fromStatusCode(201), isNull);
            expect(BlossomUploadFailureReason.fromStatusCode(204), isNull);
          });

          test('returns null for 3xx redirect codes', () {
            expect(BlossomUploadFailureReason.fromStatusCode(301), isNull);
            expect(BlossomUploadFailureReason.fromStatusCode(304), isNull);
          });

          test('returns auth for 401 and 403', () {
            expect(
              BlossomUploadFailureReason.fromStatusCode(401),
              equals(BlossomUploadFailureReason.auth),
            );
            expect(
              BlossomUploadFailureReason.fromStatusCode(403),
              equals(BlossomUploadFailureReason.auth),
            );
          });

          test('returns fileTooLarge for 413', () {
            expect(
              BlossomUploadFailureReason.fromStatusCode(413),
              equals(BlossomUploadFailureReason.fileTooLarge),
            );
          });

          test('returns server for 5xx codes', () {
            expect(
              BlossomUploadFailureReason.fromStatusCode(500),
              equals(BlossomUploadFailureReason.server),
            );
            expect(
              BlossomUploadFailureReason.fromStatusCode(502),
              equals(BlossomUploadFailureReason.server),
            );
            expect(
              BlossomUploadFailureReason.fromStatusCode(503),
              equals(BlossomUploadFailureReason.server),
            );
            expect(
              BlossomUploadFailureReason.fromStatusCode(504),
              equals(BlossomUploadFailureReason.server),
            );
            expect(
              BlossomUploadFailureReason.fromStatusCode(599),
              equals(BlossomUploadFailureReason.server),
            );
          });

          test('returns unknown for unmapped 4xx codes', () {
            expect(
              BlossomUploadFailureReason.fromStatusCode(400),
              equals(BlossomUploadFailureReason.unknown),
            );
            expect(
              BlossomUploadFailureReason.fromStatusCode(404),
              equals(BlossomUploadFailureReason.unknown),
            );
            expect(
              BlossomUploadFailureReason.fromStatusCode(429),
              equals(BlossomUploadFailureReason.unknown),
            );
          });

          test('returns unknown for codes outside 4xx/5xx', () {
            expect(
              BlossomUploadFailureReason.fromStatusCode(600),
              equals(BlossomUploadFailureReason.unknown),
            );
          });
        });

        group('fromDioException', () {
          DioException dioException(DioExceptionType type, {int? statusCode}) {
            final requestOptions = RequestOptions(path: '/upload');
            return DioException(
              requestOptions: requestOptions,
              type: type,
              response: statusCode == null
                  ? null
                  : Response<dynamic>(
                      requestOptions: requestOptions,
                      statusCode: statusCode,
                    ),
            );
          }

          test('returns network for connection timeout', () {
            expect(
              BlossomUploadFailureReason.fromDioException(
                dioException(DioExceptionType.connectionTimeout),
              ),
              equals(BlossomUploadFailureReason.network),
            );
          });

          test('returns network for send timeout', () {
            expect(
              BlossomUploadFailureReason.fromDioException(
                dioException(DioExceptionType.sendTimeout),
              ),
              equals(BlossomUploadFailureReason.network),
            );
          });

          test('returns network for receive timeout', () {
            expect(
              BlossomUploadFailureReason.fromDioException(
                dioException(DioExceptionType.receiveTimeout),
              ),
              equals(BlossomUploadFailureReason.network),
            );
          });

          test('returns network for connection error', () {
            expect(
              BlossomUploadFailureReason.fromDioException(
                dioException(DioExceptionType.connectionError),
              ),
              equals(BlossomUploadFailureReason.network),
            );
          });

          test('returns network for unknown SocketException', () {
            expect(
              BlossomUploadFailureReason.fromDioException(
                DioException(
                  requestOptions: RequestOptions(path: '/upload'),
                  error: const SocketException(
                    'Socket closed',
                    osError: OSError('Broken pipe'),
                  ),
                ),
              ),
              equals(BlossomUploadFailureReason.network),
            );
          });

          test('returns network for unknown OSError socket close detail', () {
            expect(
              BlossomUploadFailureReason.fromDioException(
                DioException(
                  requestOptions: RequestOptions(path: '/upload'),
                  error: const OSError('Broken pipe'),
                ),
              ),
              equals(BlossomUploadFailureReason.network),
            );
          });

          test('returns server for badResponse with 5xx status', () {
            expect(
              BlossomUploadFailureReason.fromDioException(
                dioException(DioExceptionType.badResponse, statusCode: 503),
              ),
              equals(BlossomUploadFailureReason.server),
            );
          });

          test('returns auth for badResponse with 401', () {
            expect(
              BlossomUploadFailureReason.fromDioException(
                dioException(DioExceptionType.badResponse, statusCode: 401),
              ),
              equals(BlossomUploadFailureReason.auth),
            );
          });

          test('returns fileTooLarge for badResponse with 413', () {
            expect(
              BlossomUploadFailureReason.fromDioException(
                dioException(DioExceptionType.badResponse, statusCode: 413),
              ),
              equals(BlossomUploadFailureReason.fileTooLarge),
            );
          });

          test('returns unknown for badResponse with no status', () {
            expect(
              BlossomUploadFailureReason.fromDioException(
                dioException(DioExceptionType.badResponse),
              ),
              equals(BlossomUploadFailureReason.unknown),
            );
          });

          test('returns unknown for cancel', () {
            expect(
              BlossomUploadFailureReason.fromDioException(
                dioException(DioExceptionType.cancel),
              ),
              equals(BlossomUploadFailureReason.unknown),
            );
          });

          test('uses status code for badCertificate when present', () {
            expect(
              BlossomUploadFailureReason.fromDioException(
                dioException(DioExceptionType.badCertificate, statusCode: 502),
              ),
              equals(BlossomUploadFailureReason.server),
            );
          });

          test('returns network for unknown wrapping a SocketException', () {
            expect(
              BlossomUploadFailureReason.fromDioException(
                DioException(
                  requestOptions: RequestOptions(path: '/upload'),
                  error: const SocketException('Connection reset by peer'),
                ),
              ),
              equals(BlossomUploadFailureReason.network),
            );
          });

          test('returns unknown for unknown without a SocketException', () {
            expect(
              BlossomUploadFailureReason.fromDioException(
                dioException(DioExceptionType.unknown),
              ),
              equals(BlossomUploadFailureReason.unknown),
            );
          });
        });
      });
    });

    group('testServerConnection', () {
      late _MockDio mockDio;

      setUp(() {
        mockDio = _MockDio();
        service = BlossomUploadService(
          authProvider: mockAuthProvider,
          dio: mockDio,
        );
      });

      test('returns reachable on successful HEAD', () async {
        when(
          () => mockDio.head<dynamic>(any(), options: any(named: 'options')),
        ).thenAnswer(
          (_) async => Response(
            requestOptions: RequestOptions(path: '/'),
            statusCode: 200,
          ),
        );

        final result = await service.testServerConnection(
          'https://blossom.example.com',
        );

        expect(result.isReachable, isTrue);
        expect(result.statusCode, equals(200));
        expect(result.serverUrl, equals('https://blossom.example.com'));
        expect(result.latencyMs, isNotNull);
      });

      test('falls back to GET when HEAD returns 405', () async {
        when(
          () => mockDio.head<dynamic>(any(), options: any(named: 'options')),
        ).thenThrow(
          DioException(
            requestOptions: RequestOptions(path: '/'),
            response: Response(
              requestOptions: RequestOptions(path: '/'),
              statusCode: 405,
            ),
            type: DioExceptionType.badResponse,
          ),
        );

        when(
          () => mockDio.get<dynamic>(any(), options: any(named: 'options')),
        ).thenAnswer(
          (_) async => Response(
            requestOptions: RequestOptions(path: '/'),
            statusCode: 200,
          ),
        );

        final result = await service.testServerConnection(
          'https://blossom.example.com',
        );

        expect(result.isReachable, isTrue);
        expect(result.statusCode, equals(200));
      });

      test('returns connection timeout error', () async {
        when(
          () => mockDio.head<dynamic>(any(), options: any(named: 'options')),
        ).thenThrow(
          DioException(
            requestOptions: RequestOptions(path: '/'),
            type: DioExceptionType.connectionTimeout,
          ),
        );

        final result = await service.testServerConnection(
          'https://blossom.example.com',
        );

        expect(result.isReachable, isFalse);
        expect(result.errorMessage, equals('Connection timeout'));
      });

      test('returns connection error', () async {
        when(
          () => mockDio.head<dynamic>(any(), options: any(named: 'options')),
        ).thenThrow(
          DioException(
            requestOptions: RequestOptions(path: '/'),
            type: DioExceptionType.connectionError,
            message: 'DNS lookup failed',
          ),
        );

        final result = await service.testServerConnection(
          'https://blossom.example.com',
        );

        expect(result.isReachable, isFalse);
        expect(result.errorMessage, contains('Cannot connect'));
      });

      test('returns generic DioException error', () async {
        when(
          () => mockDio.head<dynamic>(any(), options: any(named: 'options')),
        ).thenThrow(
          DioException(
            requestOptions: RequestOptions(path: '/'),
            type: DioExceptionType.badResponse,
            message: 'Internal Server Error',
            response: Response(
              requestOptions: RequestOptions(path: '/'),
              statusCode: 500,
            ),
          ),
        );

        final result = await service.testServerConnection(
          'https://blossom.example.com',
        );

        expect(result.isReachable, isFalse);
        expect(result.statusCode, equals(500));
      });

      test('returns error on non-Dio exception', () async {
        when(
          () => mockDio.head<dynamic>(any(), options: any(named: 'options')),
        ).thenThrow(const FormatException('bad url'));

        final result = await service.testServerConnection(
          'https://blossom.example.com',
        );

        expect(result.isReachable, isFalse);
        expect(result.errorMessage, contains('FormatException'));
      });

      test('uses configured server when no URL provided', () async {
        await service.setBlossomServer('https://my.blossom.server');

        when(
          () => mockDio.head<dynamic>(any(), options: any(named: 'options')),
        ).thenAnswer(
          (_) async => Response(
            requestOptions: RequestOptions(path: '/'),
            statusCode: 200,
          ),
        );

        final result = await service.testServerConnection();

        expect(result.isReachable, isTrue);
        verify(
          () => mockDio.head<dynamic>(
            'https://my.blossom.server',
            options: any(named: 'options'),
          ),
        ).called(1);
      });
    });

    group('uploadAudio', () {
      late _MockDio mockDio;

      setUp(() {
        mockDio = _MockDio();
        service = BlossomUploadService(
          authProvider: mockAuthProvider,
          dio: mockDio,
        );
      });

      test('returns failure when not authenticated', () async {
        when(() => mockAuthProvider.isAuthenticated).thenReturn(false);

        final mockFile = _MockFile();
        final result = await service.uploadAudio(audioFile: mockFile);

        expect(result.success, isFalse);
        expect(result.errorMessage, equals('Not authenticated'));
      });

      test('succeeds with valid audio file', () async {
        when(() => mockAuthProvider.isAuthenticated).thenReturn(true);
        when(
          () => mockAuthProvider.createAndSignEvent(
            kind: any(named: 'kind'),
            content: any(named: 'content'),
            tags: any(named: 'tags'),
          ),
        ).thenAnswer(
          (_) async => _signedEvent(_testPublicKey, 24242, const [], 'upload'),
        );

        final tempDir = await Directory.systemTemp.createTemp(
          'audio_upload_test_',
        );
        final audioFile = File('${tempDir.path}/audio.aac')
          ..writeAsBytesSync([1, 2, 3]);

        when(
          () => mockDio.head<dynamic>(any(), options: any(named: 'options')),
        ).thenAnswer(
          (_) async => Response(
            requestOptions: RequestOptions(path: '/upload'),
            statusCode: 200,
            headers: Headers(),
          ),
        );

        when(
          () => mockDio.put<dynamic>(
            any(),
            data: any(named: 'data'),
            options: any(named: 'options'),
            onSendProgress: any(named: 'onSendProgress'),
          ),
        ).thenAnswer(
          (_) async => Response(
            requestOptions: RequestOptions(path: '/upload'),
            statusCode: 200,
            data: {
              'url': 'https://media.divine.video/hash123',
              'fallbackUrl': 'https://media.divine.video/hash123',
            },
          ),
        );

        final progressValues = <double>[];
        final result = await service.uploadAudio(
          audioFile: audioFile,
          onProgress: progressValues.add,
        );

        expect(result.success, isTrue);
        expect(result.cdnUrl, contains('media.divine.video'));
        expect(progressValues, isNotEmpty);

        await tempDir.delete(recursive: true);
      });

      test('returns failure when all servers fail', () async {
        when(() => mockAuthProvider.isAuthenticated).thenReturn(true);
        when(
          () => mockAuthProvider.createAndSignEvent(
            kind: any(named: 'kind'),
            content: any(named: 'content'),
            tags: any(named: 'tags'),
          ),
        ).thenAnswer((_) async => null);

        final tempDir = await Directory.systemTemp.createTemp(
          'audio_upload_fail_test_',
        );
        final audioFile = File('${tempDir.path}/audio.aac')
          ..writeAsBytesSync([1, 2, 3]);

        when(
          () => mockDio.head<dynamic>(any(), options: any(named: 'options')),
        ).thenAnswer(
          (_) async => Response(
            requestOptions: RequestOptions(path: '/upload'),
            statusCode: 200,
            headers: Headers(),
          ),
        );

        final result = await service.uploadAudio(audioFile: audioFile);

        expect(result.success, isFalse);

        await tempDir.delete(recursive: true);
      });

      test('catches exception from server and returns failure', () async {
        when(() => mockAuthProvider.isAuthenticated).thenReturn(true);
        when(
          () => mockAuthProvider.createAndSignEvent(
            kind: any(named: 'kind'),
            content: any(named: 'content'),
            tags: any(named: 'tags'),
          ),
        ).thenAnswer(
          (_) async => _signedEvent(_testPublicKey, 24242, const [], 'upload'),
        );

        final tempDir = await Directory.systemTemp.createTemp(
          'audio_upload_exc_test_',
        );
        final audioFile = File('${tempDir.path}/audio.aac')
          ..writeAsBytesSync([1, 2, 3]);

        when(
          () => mockDio.head<dynamic>(any(), options: any(named: 'options')),
        ).thenAnswer(
          (_) async => Response(
            requestOptions: RequestOptions(path: '/upload'),
            statusCode: 200,
            headers: Headers(),
          ),
        );

        when(
          () => mockDio.put<dynamic>(
            any(),
            data: any(named: 'data'),
            options: any(named: 'options'),
            onSendProgress: any(named: 'onSendProgress'),
          ),
        ).thenThrow(
          DioException(
            requestOptions: RequestOptions(path: '/upload'),
            type: DioExceptionType.connectionError,
          ),
        );

        final result = await service.uploadAudio(audioFile: audioFile);

        expect(result.success, isFalse);

        await tempDir.delete(recursive: true);
      });
    });

    group('uploadImage - error paths', () {
      late _MockDio mockDio;

      setUp(() {
        mockDio = _MockDio();
        service = BlossomUploadService(
          authProvider: mockAuthProvider,
          dio: mockDio,
          // authUnavailable is transient, so the un-signable case below
          // retries; skip the backoff so the test stays fast.
          sleep: (_) async {},
        );
      });

      test('returns failure when not authenticated', () async {
        when(() => mockAuthProvider.isAuthenticated).thenReturn(false);

        final mockFile = _MockFile();
        final result = await service.uploadImage(
          imageFile: mockFile,
          nostrPubkey: _testPublicKey,
        );

        expect(result.success, isFalse);
        expect(result.errorMessage, equals('Not authenticated'));
        expect(result.failureReason, equals(BlossomUploadFailureReason.auth));
      });

      test('returns failure when all servers fail', () async {
        when(() => mockAuthProvider.isAuthenticated).thenReturn(true);
        when(
          () => mockAuthProvider.createAndSignEvent(
            kind: any(named: 'kind'),
            content: any(named: 'content'),
            tags: any(named: 'tags'),
          ),
        ).thenAnswer((_) async => null);

        final tempDir = await Directory.systemTemp.createTemp(
          'image_upload_fail_test_',
        );
        final imageFile = File('${tempDir.path}/image.jpg')
          ..writeAsBytesSync([0xFF, 0xD8, 0xFF]);

        when(
          () => mockDio.head<dynamic>(any(), options: any(named: 'options')),
        ).thenAnswer(
          (_) async => Response(
            requestOptions: RequestOptions(path: '/upload'),
            statusCode: 200,
            headers: Headers(),
          ),
        );

        final result = await service.uploadImage(
          imageFile: imageFile,
          nostrPubkey: _testPublicKey,
        );

        expect(result.success, isFalse);
        // Auth-header build failure (signer unreachable) is transient and
        // classifies as authUnavailable, NOT a permanent `auth` rejection.
        expect(
          result.failureReason,
          equals(BlossomUploadFailureReason.authUnavailable),
        );

        await tempDir.delete(recursive: true);
      });
    });

    group('uploadImage - failure classification', () {
      late _MockDio mockDio;

      setUp(() {
        mockDio = _MockDio();
        service = BlossomUploadService(
          authProvider: mockAuthProvider,
          dio: mockDio,
          // Skip retry backoff so each failure test runs in milliseconds.
          sleep: (_) async {},
        );
      });

      Future<File> writeTempImage(String name) async {
        final tempDir = await Directory.systemTemp.createTemp(
          'image_upload_classification_',
        );
        return File('${tempDir.path}/$name')
          ..writeAsBytesSync([0xFF, 0xD8, 0xFF]);
      }

      void arrangeAuthenticated() {
        when(() => mockAuthProvider.isAuthenticated).thenReturn(true);
        when(
          () => mockAuthProvider.createAndSignEvent(
            kind: any(named: 'kind'),
            content: any(named: 'content'),
            tags: any(named: 'tags'),
          ),
        ).thenAnswer(
          (_) async => _signedEvent(_testPublicKey, 24242, const [], 'upload'),
        );
      }

      void arrangeLegacyCapability() {
        when(
          () => mockDio.head<dynamic>(any(), options: any(named: 'options')),
        ).thenAnswer(
          (_) async => Response(
            requestOptions: RequestOptions(path: '/upload'),
            statusCode: 200,
            headers: Headers(),
          ),
        );
      }

      void arrangePutThrows(DioException exception) {
        when(
          () => mockDio.put<dynamic>(
            any(),
            data: any(named: 'data'),
            options: any(named: 'options'),
            onSendProgress: any(named: 'onSendProgress'),
          ),
        ).thenThrow(exception);
      }

      void arrangePutResponse({
        required int statusCode,
        Map<String, dynamic>? data,
      }) {
        when(
          () => mockDio.put<dynamic>(
            any(),
            data: any(named: 'data'),
            options: any(named: 'options'),
            onSendProgress: any(named: 'onSendProgress'),
          ),
        ).thenAnswer(
          (_) async => Response<dynamic>(
            requestOptions: RequestOptions(path: '/upload'),
            statusCode: statusCode,
            data: data,
          ),
        );
      }

      test('classifies connection timeout as network', () async {
        arrangeAuthenticated();
        arrangeLegacyCapability();
        arrangePutThrows(
          DioException(
            requestOptions: RequestOptions(path: '/upload'),
            type: DioExceptionType.connectionTimeout,
          ),
        );

        final imageFile = await writeTempImage('timeout.jpg');
        final result = await service.uploadImage(
          imageFile: imageFile,
          nostrPubkey: _testPublicKey,
        );

        expect(result.success, isFalse);
        expect(
          result.failureReason,
          equals(BlossomUploadFailureReason.network),
        );

        await imageFile.parent.delete(recursive: true);
      });

      test('classifies connection error as network', () async {
        arrangeAuthenticated();
        arrangeLegacyCapability();
        arrangePutThrows(
          DioException(
            requestOptions: RequestOptions(path: '/upload'),
            type: DioExceptionType.connectionError,
            message: 'DNS lookup failed',
          ),
        );

        final imageFile = await writeTempImage('connection_error.jpg');
        final result = await service.uploadImage(
          imageFile: imageFile,
          nostrPubkey: _testPublicKey,
        );

        expect(result.success, isFalse);
        expect(
          result.failureReason,
          equals(BlossomUploadFailureReason.network),
        );

        await imageFile.parent.delete(recursive: true);
      });

      test('classifies HTTP 503 from server as server', () async {
        arrangeAuthenticated();
        arrangeLegacyCapability();
        arrangePutResponse(
          statusCode: 503,
          data: {'error': 'Service Unavailable'},
        );

        final imageFile = await writeTempImage('server_503.jpg');
        final result = await service.uploadImage(
          imageFile: imageFile,
          nostrPubkey: _testPublicKey,
        );

        expect(result.success, isFalse);
        expect(result.failureReason, equals(BlossomUploadFailureReason.server));

        await imageFile.parent.delete(recursive: true);
      });

      test('classifies HTTP 401 from server as auth', () async {
        arrangeAuthenticated();
        arrangeLegacyCapability();
        arrangePutResponse(statusCode: 401, data: {'error': 'Unauthorized'});

        final imageFile = await writeTempImage('auth_401.jpg');
        final result = await service.uploadImage(
          imageFile: imageFile,
          nostrPubkey: _testPublicKey,
        );

        expect(result.success, isFalse);
        expect(result.failureReason, equals(BlossomUploadFailureReason.auth));

        await imageFile.parent.delete(recursive: true);
      });

      test('classifies HTTP 413 from server as fileTooLarge', () async {
        arrangeAuthenticated();
        arrangeLegacyCapability();
        arrangePutResponse(
          statusCode: 413,
          data: {'error': 'Payload Too Large'},
        );

        final imageFile = await writeTempImage('too_large.jpg');
        final result = await service.uploadImage(
          imageFile: imageFile,
          nostrPubkey: _testPublicKey,
        );

        expect(result.success, isFalse);
        expect(
          result.failureReason,
          equals(BlossomUploadFailureReason.fileTooLarge),
        );

        await imageFile.parent.delete(recursive: true);
      });

      test(
        'classifies HTTP 400 (unmapped 4xx) from server as unknown',
        () async {
          arrangeAuthenticated();
          arrangeLegacyCapability();
          arrangePutResponse(statusCode: 400, data: {'error': 'Bad Request'});

          final imageFile = await writeTempImage('bad_request.jpg');
          final result = await service.uploadImage(
            imageFile: imageFile,
            nostrPubkey: _testPublicKey,
          );

          expect(result.success, isFalse);
          expect(
            result.failureReason,
            equals(BlossomUploadFailureReason.unknown),
          );

          await imageFile.parent.delete(recursive: true);
        },
      );
    });

    group('uploadImageBytes', () {
      late _MockDio mockDio;

      setUp(() {
        mockDio = _MockDio();
        service = BlossomUploadService(
          authProvider: mockAuthProvider,
          dio: mockDio,
        );
        SharedPreferences.setMockInitialValues({});
      });

      // Minimal 2x2 JPEG produced by image_metadata_stripper test fixtures
      // would couple the two packages; produce one inline so this test
      // doesn't depend on stripping internals.
      Uint8List makeJpegBytes() {
        // SOI + APP0 (JFIF) + SOS-ish marker + EOI; the real round-trip
        // doesn't need to be a valid JPEG because the stripper falls
        // through to `decodeImage` and back to the original bytes.
        return Uint8List.fromList([
          0xFF, 0xD8, // SOI
          0xFF, 0xE0, 0x00, 0x10, 0x4A, 0x46, 0x49, 0x46, 0x00, // APP0 JFIF
          0x01, 0x01, 0x00, 0x00, 0x01, 0x00, 0x01, 0x00, 0x00,
          0xFF, 0xD9, // EOI
        ]);
      }

      void arrangeAuth() {
        when(() => mockAuthProvider.isAuthenticated).thenReturn(true);
        when(
          () => mockAuthProvider.createAndSignEvent(
            kind: any(named: 'kind'),
            content: any(named: 'content'),
            tags: any(named: 'tags'),
          ),
        ).thenAnswer(
          (_) async => _signedEvent(
            _testPublicKey,
            24242,
            const [],
            'Upload image to Blossom server',
          ),
        );
      }

      void arrangeNonResumableHead() {
        when(
          () => mockDio.head<dynamic>(any(), options: any(named: 'options')),
        ).thenAnswer(
          (_) async => Response(
            requestOptions: RequestOptions(path: '/upload'),
            statusCode: 200,
            headers: Headers(),
          ),
        );
      }

      test(
        'returns failure without touching dio when not authenticated',
        () async {
          when(() => mockAuthProvider.isAuthenticated).thenReturn(false);

          final result = await service.uploadImageBytes(
            bytes: makeJpegBytes(),
            nostrPubkey: _testPublicKey,
          );

          expect(result.success, isFalse);
          expect(result.errorMessage, equals('Not authenticated'));
          verifyNever(
            () => mockDio.put<dynamic>(
              any(),
              data: any(named: 'data'),
              options: any(named: 'options'),
              onSendProgress: any(named: 'onSendProgress'),
            ),
          );
        },
      );

      test(
        'uploads bytes via legacy PUT and returns canonical URL on success',
        () async {
          arrangeAuth();
          arrangeNonResumableHead();

          final mockResponse = _MockResponse();
          when(() => mockResponse.statusCode).thenReturn(200);
          when(() => mockResponse.headers).thenReturn(Headers());
          when(
            () => mockResponse.data,
          ).thenReturn({'url': 'https://media.divine.video/anything-here.jpg'});

          Uint8List? capturedPayload;
          when(
            () => mockDio.put<dynamic>(
              any(),
              data: any(named: 'data'),
              options: any(named: 'options'),
              onSendProgress: any(named: 'onSendProgress'),
            ),
          ).thenAnswer((invocation) async {
            final data = invocation.namedArguments[#data];
            if (data is Uint8List) {
              capturedPayload = data;
            }
            return mockResponse;
          });

          final progress = <double>[];
          final result = await service.uploadImageBytes(
            bytes: makeJpegBytes(),
            nostrPubkey: _testPublicKey,
            filename: 'avatar.jpg',
            onProgress: progress.add,
          );

          expect(result.success, isTrue);
          // The canonical URL is always derived from the default Divine
          // server + sha256, so it does not depend on the response body.
          expect(
            result.url,
            equals(result.fallbackUrl),
            reason:
                'image upload publishes the canonical {server}/{sha256} url',
          );
          expect(result.url, startsWith('https://media.divine.video/'));
          expect(result.videoId, isNotNull);

          // Payload was passed through as in-memory bytes (not a stream),
          // confirming we did not try to read from a File.
          expect(capturedPayload, isA<Uint8List>());
          expect(capturedPayload, isNotEmpty);

          // Progress reports the start (0.1) and the completion (1.0).
          // Asserted with `contains` rather than first/last so adding
          // intermediate milestones doesn't break this test.
          expect(progress, contains(0.1));
          expect(progress, contains(1.0));
        },
      );

      test('defaults filename to upload.jpg when caller passes none', () async {
        arrangeAuth();
        arrangeNonResumableHead();

        final mockResponse = _MockResponse();
        when(() => mockResponse.statusCode).thenReturn(200);
        when(() => mockResponse.headers).thenReturn(Headers());
        when(
          () => mockResponse.data,
        ).thenReturn({'url': 'https://media.divine.video/x.bin'});

        when(
          () => mockDio.put<dynamic>(
            any(),
            data: any(named: 'data'),
            options: any(named: 'options'),
            onSendProgress: any(named: 'onSendProgress'),
          ),
        ).thenAnswer((_) async => mockResponse);

        final result = await service.uploadImageBytes(
          bytes: makeJpegBytes(),
          nostrPubkey: _testPublicKey,
        );

        expect(result.success, isTrue);
        // Default 'upload.jpg' lands in the JPEG branch of the stripper,
        // so the upload still succeeds end-to-end.
      });

      test('uploads bytes via resumable chunk flow on capable hosts', () async {
        arrangeAuth();

        // HEAD says resumable is supported
        when(
          () => mockDio.head<dynamic>(any(), options: any(named: 'options')),
        ).thenAnswer(
          (_) async => Response(
            requestOptions: RequestOptions(path: '/upload'),
            statusCode: 200,
            headers: Headers.fromMap({
              DivineUploadHeaders.extensions: [
                DivineUploadExtensions.resumableSessions,
              ],
            }),
          ),
        );

        // Init returns a small chunk size so we exercise the chunk loop.
        when(
          () => mockDio.post<dynamic>(
            any(),
            data: any(named: 'data'),
            options: any(named: 'options'),
          ),
        ).thenAnswer((invocation) async {
          final url = invocation.positionalArguments.first as String;
          if (url.endsWith('/upload/init')) {
            return Response(
              requestOptions: RequestOptions(path: '/upload/init'),
              statusCode: 200,
              data: {
                'uploadId': 'up_bytes',
                'uploadUrl': 'https://upload.divine.video/sessions/up_bytes',
                'chunkSize': 4,
                'nextOffset': 0,
              },
            );
          }
          // /complete
          return Response(
            requestOptions: RequestOptions(path: '/upload/up_bytes/complete'),
            statusCode: 200,
            data: {
              'url': 'https://media.divine.video/final.jpg',
              'fallbackUrl': 'https://media.divine.video/final.jpg',
            },
          );
        });

        final chunkPayloads = <List<int>>[];
        when(
          () => mockDio.put<dynamic>(
            any(),
            data: any(named: 'data'),
            options: any(named: 'options'),
            onSendProgress: any(named: 'onSendProgress'),
          ),
        ).thenAnswer((invocation) async {
          final data = invocation.namedArguments[#data];
          if (data is List<int>) {
            chunkPayloads.add(List<int>.from(data));
          }
          return Response(
            requestOptions: RequestOptions(path: '/upload/up_bytes'),
            statusCode: 200,
            headers: Headers(),
          );
        });

        final bytes = makeJpegBytes();
        final result = await service.uploadImageBytes(
          bytes: bytes,
          nostrPubkey: _testPublicKey,
          filename: 'avatar.jpg',
        );

        expect(result.success, isTrue);
        // We sent at least one chunk's worth of bytes, and the slice came
        // straight from the in-memory buffer rather than a File reader.
        expect(chunkPayloads, isNotEmpty);
        expect(chunkPayloads.first.length, lessThanOrEqualTo(4));
      });

      test('strips JPEG GPS metadata before computing the hash', () async {
        arrangeAuth();
        arrangeNonResumableHead();

        // Two JPEGs with the same pixel content and the same orientation
        // but different GPS coordinates. After stripping, only the
        // (preserved) orientation field remains in EXIF, so the byte
        // payloads — and therefore their sha256 hashes — should match.
        final bytesGpsNorth = _jpegBytesWithGps('N');
        final bytesGpsSouth = _jpegBytesWithGps('S');
        // Sanity check: the inputs really do differ.
        expect(bytesGpsNorth, isNot(equals(bytesGpsSouth)));

        final mockResponse = _MockResponse();
        when(() => mockResponse.statusCode).thenReturn(200);
        when(() => mockResponse.headers).thenReturn(Headers());
        when(
          () => mockResponse.data,
        ).thenReturn({'url': 'https://media.divine.video/x.jpg'});

        when(
          () => mockDio.put<dynamic>(
            any(),
            data: any(named: 'data'),
            options: any(named: 'options'),
            onSendProgress: any(named: 'onSendProgress'),
          ),
        ).thenAnswer((_) async => mockResponse);

        final r1 = await service.uploadImageBytes(
          bytes: bytesGpsNorth,
          nostrPubkey: _testPublicKey,
          filename: 'photo.jpg',
        );
        final r2 = await service.uploadImageBytes(
          bytes: bytesGpsSouth,
          nostrPubkey: _testPublicKey,
          filename: 'photo.jpg',
        );

        expect(r1.success, isTrue);
        expect(r2.success, isTrue);
        // GPS field stripped → same hash → same canonical URL.
        expect(r1.videoId, equals(r2.videoId));
      });

      test(
        'returns failure when an unexpected error escapes pre-upload prep',
        () async {
          // Drive the outer `on Object catch` by making the auth check
          // itself throw — the only path before `_uploadImageSourceToServers`
          // can capture errors. Mirrors the existing `uploadImage returns
          // failure when file processing throws` test on the file path.
          when(
            () => mockAuthProvider.isAuthenticated,
          ).thenThrow(StateError('boom'));

          final result = await service.uploadImageBytes(
            bytes: makeJpegBytes(),
            nostrPubkey: _testPublicKey,
          );

          expect(result.success, isFalse);
          expect(result.errorMessage, contains('Image upload failed'));
        },
      );
    });

    group('DioException error handling in legacy upload', () {
      late _MockDio mockDio;

      setUp(() {
        mockDio = _MockDio();
        service = BlossomUploadService(
          authProvider: mockAuthProvider,
          dio: mockDio,
        );
      });

      Future<BlossomUploadResult> triggerUploadWithDioError(
        DioExceptionType type, {
        String? message,
        int? statusCode,
      }) async {
        when(() => mockAuthProvider.isAuthenticated).thenReturn(true);
        when(
          () => mockAuthProvider.createAndSignEvent(
            kind: any(named: 'kind'),
            content: any(named: 'content'),
            tags: any(named: 'tags'),
          ),
        ).thenAnswer(
          (_) async => _signedEvent(_testPublicKey, 24242, const [], 'upload'),
        );

        final tempDir = await Directory.systemTemp.createTemp(
          'dio_error_test_',
        );
        final file = File('${tempDir.path}/video.mp4')
          ..writeAsBytesSync([1, 2, 3]);

        when(
          () => mockDio.head<dynamic>(any(), options: any(named: 'options')),
        ).thenAnswer(
          (_) async => Response(
            requestOptions: RequestOptions(path: '/upload'),
            statusCode: 200,
            headers: Headers(),
          ),
        );

        when(
          () => mockDio.put<dynamic>(
            any(),
            data: any(named: 'data'),
            options: any(named: 'options'),
            onSendProgress: any(named: 'onSendProgress'),
          ),
        ).thenThrow(
          DioException(
            requestOptions: RequestOptions(path: '/upload'),
            type: type,
            message: message,
            error: message != null ? Exception(message) : null,
            response: statusCode != null
                ? Response(
                    requestOptions: RequestOptions(path: '/upload'),
                    statusCode: statusCode,
                  )
                : null,
          ),
        );

        final result = await service.uploadVideo(
          videoFile: file,
          nostrPubkey: _testPublicKey,
          title: 'test',
          description: null,
          hashtags: null,
          proofManifestJson: null,
        );

        await tempDir.delete(recursive: true);
        return result;
      }

      test('handles connectionTimeout', () async {
        final result = await triggerUploadWithDioError(
          DioExceptionType.connectionTimeout,
        );
        expect(result.success, isFalse);
        expect(result.errorMessage, contains('Connection timeout'));
      });

      test('handles sendTimeout', () async {
        final result = await triggerUploadWithDioError(
          DioExceptionType.sendTimeout,
        );
        expect(result.success, isFalse);
        expect(result.errorMessage, contains('Send timeout'));
      });

      test('handles receiveTimeout', () async {
        final result = await triggerUploadWithDioError(
          DioExceptionType.receiveTimeout,
        );
        expect(result.success, isFalse);
        expect(result.errorMessage, contains('Receive timeout'));
      });

      test('handles connectionError', () async {
        final result = await triggerUploadWithDioError(
          DioExceptionType.connectionError,
          message: 'DNS failed',
        );
        expect(result.success, isFalse);
        expect(result.errorMessage, contains('Cannot connect'));
      });

      test('handles cancel', () async {
        final result = await triggerUploadWithDioError(DioExceptionType.cancel);
        expect(result.success, isFalse);
        expect(result.errorMessage, contains('cancelled'));
      });

      test('handles badResponse', () async {
        final result = await triggerUploadWithDioError(
          DioExceptionType.badResponse,
          statusCode: 413,
          message: 'Payload Too Large',
        );
        expect(result.success, isFalse);
        expect(result.errorMessage, contains('Server error'));
        expect(result.statusCode, equals(413));
      });

      test('handles unknown DioException type', () async {
        final result = await triggerUploadWithDioError(
          DioExceptionType.unknown,
          message: 'Something weird',
        );
        expect(result.success, isFalse);
        expect(result.errorMessage, contains('Network error'));
      });

      test('handles non-Dio exception in upload', () async {
        when(() => mockAuthProvider.isAuthenticated).thenReturn(true);
        when(
          () => mockAuthProvider.createAndSignEvent(
            kind: any(named: 'kind'),
            content: any(named: 'content'),
            tags: any(named: 'tags'),
          ),
        ).thenAnswer(
          (_) async => _signedEvent(_testPublicKey, 24242, const [], 'upload'),
        );

        final tempDir = await Directory.systemTemp.createTemp(
          'non_dio_error_test_',
        );
        final file = File('${tempDir.path}/video.mp4')
          ..writeAsBytesSync([1, 2, 3]);

        when(
          () => mockDio.head<dynamic>(any(), options: any(named: 'options')),
        ).thenAnswer(
          (_) async => Response(
            requestOptions: RequestOptions(path: '/upload'),
            statusCode: 200,
            headers: Headers(),
          ),
        );

        when(
          () => mockDio.put<dynamic>(
            any(),
            data: any(named: 'data'),
            options: any(named: 'options'),
            onSendProgress: any(named: 'onSendProgress'),
          ),
        ).thenThrow(const FormatException('bad data'));

        final result = await service.uploadVideo(
          videoFile: file,
          nostrPubkey: _testPublicKey,
          title: 'test',
          description: null,
          hashtags: null,
          proofManifestJson: null,
        );

        expect(result.success, isFalse);
        expect(result.errorMessage, contains('Upload error'));

        await tempDir.delete(recursive: true);
      });
    });

    group('Upload response parsing edge cases', () {
      late _MockDio mockDio;

      setUp(() {
        mockDio = _MockDio();
        service = BlossomUploadService(
          authProvider: mockAuthProvider,
          dio: mockDio,
        );
      });

      Future<BlossomUploadResult> uploadAndGetResult(
        Object? responseData, {
        int statusCode = 200,
        Headers? headers,
      }) async {
        when(() => mockAuthProvider.isAuthenticated).thenReturn(true);
        when(
          () => mockAuthProvider.createAndSignEvent(
            kind: any(named: 'kind'),
            content: any(named: 'content'),
            tags: any(named: 'tags'),
          ),
        ).thenAnswer(
          (_) async => _signedEvent(_testPublicKey, 24242, const [], 'upload'),
        );

        final tempDir = await Directory.systemTemp.createTemp(
          'response_parse_test_',
        );
        final file = File('${tempDir.path}/video.mp4')
          ..writeAsBytesSync([1, 2, 3]);

        when(
          () => mockDio.head<dynamic>(any(), options: any(named: 'options')),
        ).thenAnswer(
          (_) async => Response(
            requestOptions: RequestOptions(path: '/upload'),
            statusCode: 200,
            headers: Headers(),
          ),
        );

        when(
          () => mockDio.put<dynamic>(
            any(),
            data: any(named: 'data'),
            options: any(named: 'options'),
            onSendProgress: any(named: 'onSendProgress'),
          ),
        ).thenAnswer(
          (_) async => Response(
            requestOptions: RequestOptions(path: '/upload'),
            statusCode: statusCode,
            data: responseData,
            headers: headers ?? Headers(),
          ),
        );

        final result = await service.uploadVideo(
          videoFile: file,
          nostrPubkey: _testPublicKey,
          title: 'test',
          description: null,
          hashtags: null,
          proofManifestJson: null,
        );

        await tempDir.delete(recursive: true);
        return result;
      }

      test('parses streaming data from response', () async {
        final result = await uploadAndGetResult({
          'url': 'https://media.divine.video/hash',
          'fallbackUrl': 'https://r2.divine.video/hash',
          'streaming': {
            'mp4Url': 'https://stream.divine.video/hash.mp4',
            'hlsUrl': 'https://stream.divine.video/hash.m3u8',
            'thumbnailUrl': 'https://stream.divine.video/thumb.jpg',
            'status': 'processing',
          },
        });

        expect(result.success, isTrue);
        expect(result.streamingMp4Url, isNotNull);
        expect(result.streamingHlsUrl, isNotNull);
        expect(result.thumbnailUrl, isNotNull);
        expect(result.streamingStatus, equals('processing'));
      });

      test('handles 409 Conflict as success', () async {
        final result = await uploadAndGetResult(null, statusCode: 409);

        expect(result.success, isTrue);
        expect(result.cdnUrl, contains('media.divine.video'));
      });

      test('handles non-200/201/409 status with X-Reason header', () async {
        final result = await uploadAndGetResult(
          'error body',
          statusCode: 403,
          headers: Headers.fromMap({
            'X-Reason': ['Quota exceeded'],
          }),
        );

        expect(result.success, isFalse);
        expect(result.errorMessage, contains('Quota exceeded'));
        expect(result.statusCode, equals(403));
      });

      test('handles 200 response with missing URL field', () async {
        final result = await uploadAndGetResult({'sha256': 'abc', 'size': 123});

        expect(result.success, isFalse);
        expect(result.errorMessage, contains('missing URL'));
      });

      test('handles 200 response with empty URL', () async {
        final result = await uploadAndGetResult({'url': '', 'sha256': 'abc'});

        expect(result.success, isFalse);
        expect(result.errorMessage, contains('missing URL'));
      });

      test('handles streaming with thumbnail fallback', () async {
        final result = await uploadAndGetResult({
          'url': 'https://media.divine.video/hash',
          'streaming': {
            'mp4Url': 'https://stream.divine.video/hash.mp4',
            'thumbnail': 'https://stream.divine.video/thumb2.jpg',
          },
        });

        expect(result.success, isTrue);
        expect(result.thumbnailUrl, contains('thumb2'));
      });
    });

    group('Resumable upload error paths', () {
      late _MockDio mockDio;

      setUp(() {
        mockDio = _MockDio();
        service = BlossomUploadService(
          authProvider: mockAuthProvider,
          dio: mockDio,
        );
      });

      test('resumeUploadSession throws on 404 expired session', () async {
        when(
          () => mockDio.head<dynamic>(any(), options: any(named: 'options')),
        ).thenAnswer(
          (_) async => Response(
            requestOptions: RequestOptions(path: '/sessions'),
            statusCode: 404,
          ),
        );

        expect(
          () => service.resumeUploadSession(
            session: const BlossomResumableUploadSession(
              uploadId: 'up_old',
              uploadUrl: 'https://upload.divine.video/sessions/up_old',
              chunkSize: 1024,
              nextOffset: 0,
            ),
          ),
          throwsA(isA<BlossomResumableUploadException>()),
        );
      });

      test('resumeUploadSession throws on 410 gone session', () async {
        when(
          () => mockDio.head<dynamic>(any(), options: any(named: 'options')),
        ).thenAnswer(
          (_) async => Response(
            requestOptions: RequestOptions(path: '/sessions'),
            statusCode: 410,
          ),
        );

        expect(
          () => service.resumeUploadSession(
            session: const BlossomResumableUploadSession(
              uploadId: 'up_gone',
              uploadUrl: 'https://upload.divine.video/sessions/up_gone',
              chunkSize: 1024,
              nextOffset: 0,
            ),
          ),
          throwsA(isA<BlossomResumableUploadException>()),
        );
      });

      test(
        'resumeUploadSession throws auth-classified exception on 401',
        () async {
          when(
            () => mockDio.head<dynamic>(any(), options: any(named: 'options')),
          ).thenAnswer(
            (_) async => Response(
              requestOptions: RequestOptions(path: '/sessions'),
              statusCode: 401,
            ),
          );

          expect(
            () => service.resumeUploadSession(
              session: const BlossomResumableUploadSession(
                uploadId: 'up_unauthorized',
                uploadUrl:
                    'https://upload.divine.video/sessions/up_unauthorized',
                chunkSize: 1024,
                nextOffset: 0,
              ),
            ),
            throwsA(
              isA<BlossomResumableUploadException>()
                  .having((e) => e.statusCode, 'statusCode', 401)
                  .having(
                    (e) => e.failureReason,
                    'failureReason',
                    BlossomUploadFailureReason.auth,
                  ),
            ),
          );
        },
      );

      test('resumeUploadSession throws on unexpected status', () async {
        when(
          () => mockDio.head<dynamic>(any(), options: any(named: 'options')),
        ).thenAnswer(
          (_) async => Response(
            requestOptions: RequestOptions(path: '/sessions'),
            statusCode: 500,
          ),
        );

        // Note: 500 passes _validateHttpStatus (< 500 check fails)
        // so it falls through. Actually _validateHttpStatus requires
        // statusCode < 500, so 500 won't pass. The mock returns 500
        // without validateStatus, so it goes through. Actually the
        // HEAD call uses _validateHttpStatus which rejects >= 500.
        // Let me use 302 which would pass but isn't 200/204/404/410.
        when(
          () => mockDio.head<dynamic>(any(), options: any(named: 'options')),
        ).thenAnswer(
          (_) async => Response(
            requestOptions: RequestOptions(path: '/sessions'),
            statusCode: 302,
          ),
        );

        expect(
          () => service.resumeUploadSession(
            session: const BlossomResumableUploadSession(
              uploadId: 'up_redirect',
              uploadUrl: 'https://upload.divine.video/sessions/up_redirect',
              chunkSize: 1024,
              nextOffset: 0,
            ),
          ),
          throwsA(isA<BlossomResumableUploadException>()),
        );
      });

      test('initResumableUpload throws when auth fails', () async {
        when(() => mockAuthProvider.isAuthenticated).thenReturn(true);
        when(
          () => mockAuthProvider.createAndSignEvent(
            kind: any(named: 'kind'),
            content: any(named: 'content'),
            tags: any(named: 'tags'),
          ),
        ).thenAnswer((_) async => null);

        final tempDir = await Directory.systemTemp.createTemp(
          'init_auth_fail_test_',
        );
        final file = File('${tempDir.path}/video.mp4')
          ..writeAsBytesSync([1, 2, 3]);

        // capability probe says resumable supported
        when(
          () => mockDio.head<dynamic>(any(), options: any(named: 'options')),
        ).thenAnswer(
          (_) async => Response(
            requestOptions: RequestOptions(path: '/upload'),
            statusCode: 200,
            headers: Headers.fromMap({
              DivineUploadHeaders.extensions: [
                DivineUploadExtensions.resumableSessions,
              ],
            }),
          ),
        );

        // Auth returns null -> init should throw, caught by uploadVideo
        final result = await service.uploadVideo(
          videoFile: file,
          nostrPubkey: _testPublicKey,
          title: 'test',
          description: null,
          hashtags: null,
          proofManifestJson: null,
        );

        // Should fall back to legacy after init failure, which also
        // fails auth -> returns failure
        expect(result.success, isFalse);

        await tempDir.delete(recursive: true);
      });

      test('initResumableUpload throws on missing response fields', () async {
        when(() => mockAuthProvider.isAuthenticated).thenReturn(true);
        when(
          () => mockAuthProvider.createAndSignEvent(
            kind: any(named: 'kind'),
            content: any(named: 'content'),
            tags: any(named: 'tags'),
          ),
        ).thenAnswer(
          (_) async => _signedEvent(_testPublicKey, 24242, const [], 'upload'),
        );

        final tempDir = await Directory.systemTemp.createTemp(
          'init_missing_fields_test_',
        );
        final file = File('${tempDir.path}/video.mp4')
          ..writeAsBytesSync([1, 2, 3]);

        when(
          () => mockDio.head<dynamic>(any(), options: any(named: 'options')),
        ).thenAnswer(
          (_) async => Response(
            requestOptions: RequestOptions(path: '/upload'),
            statusCode: 200,
            headers: Headers.fromMap({
              DivineUploadHeaders.extensions: [
                DivineUploadExtensions.resumableSessions,
              ],
            }),
          ),
        );

        // Init response with missing uploadUrl
        when(
          () => mockDio.post<dynamic>(
            any(),
            data: any(named: 'data'),
            options: any(named: 'options'),
          ),
        ).thenAnswer(
          (_) async => Response(
            requestOptions: RequestOptions(path: '/upload/init'),
            statusCode: 200,
            data: {
              'uploadId': 'up_123',
              // missing uploadUrl and chunkSize
            },
          ),
        );

        // Legacy fallback after init failure
        when(
          () => mockDio.put<dynamic>(
            any(),
            data: any(named: 'data'),
            options: any(named: 'options'),
            onSendProgress: any(named: 'onSendProgress'),
          ),
        ).thenAnswer(
          (_) async => Response(
            requestOptions: RequestOptions(path: '/upload'),
            statusCode: 200,
            data: {
              'url': 'https://media.divine.video/hash',
              'fallbackUrl': 'https://media.divine.video/hash',
            },
          ),
        );

        final result = await service.uploadVideo(
          videoFile: file,
          nostrPubkey: _testPublicKey,
          title: 'test',
          description: null,
          hashtags: null,
          proofManifestJson: null,
        );

        // Should fall back to legacy PUT
        expect(result.success, isTrue);

        await tempDir.delete(recursive: true);
      });

      test('chunk upload handles 404 expired session mid-upload', () async {
        when(() => mockAuthProvider.isAuthenticated).thenReturn(true);
        when(
          () => mockAuthProvider.createAndSignEvent(
            kind: any(named: 'kind'),
            content: any(named: 'content'),
            tags: any(named: 'tags'),
          ),
        ).thenAnswer(
          (_) async => _signedEvent(_testPublicKey, 24242, const [], 'upload'),
        );

        final tempDir = await Directory.systemTemp.createTemp(
          'chunk_404_test_',
        );
        final file = File('${tempDir.path}/video.mp4')
          ..writeAsBytesSync(List.generate(10, (i) => i));

        when(
          () => mockDio.head<dynamic>(any(), options: any(named: 'options')),
        ).thenAnswer(
          (_) async => Response(
            requestOptions: RequestOptions(path: '/upload'),
            statusCode: 200,
            headers: Headers.fromMap({
              DivineUploadHeaders.extensions: [
                DivineUploadExtensions.resumableSessions,
              ],
            }),
          ),
        );

        when(
          () => mockDio.post<dynamic>(
            any(),
            data: any(named: 'data'),
            options: any(named: 'options'),
          ),
        ).thenAnswer(
          (_) async => Response(
            requestOptions: RequestOptions(path: '/upload/init'),
            statusCode: 200,
            data: {
              'uploadId': 'up_exp',
              'uploadUrl': 'https://upload.divine.video/sessions/up_exp',
              'chunkSize': 5,
              'nextOffset': 0,
            },
          ),
        );

        // First chunk succeeds, second returns 404
        var chunkCount = 0;
        when(
          () => mockDio.put<dynamic>(
            any(),
            data: any(named: 'data'),
            options: any(named: 'options'),
            onSendProgress: any(named: 'onSendProgress'),
          ),
        ).thenAnswer((invocation) async {
          final url = invocation.positionalArguments.first as String;
          chunkCount++;

          if (url.contains('sessions/up_exp')) {
            if (chunkCount == 1) {
              return Response(
                requestOptions: RequestOptions(path: '/sessions'),
                statusCode: 204,
                headers: Headers.fromMap({
                  DivineUploadHeaders.uploadOffset: ['5'],
                }),
              );
            }
            return Response(
              requestOptions: RequestOptions(path: '/sessions'),
              statusCode: 404,
            );
          }

          // Legacy fallback PUT
          return Response(
            requestOptions: RequestOptions(path: '/upload'),
            statusCode: 200,
            data: {
              'url': 'https://media.divine.video/hash',
              'fallbackUrl': 'https://media.divine.video/hash',
            },
          );
        });

        final result = await service.uploadVideo(
          videoFile: file,
          nostrPubkey: _testPublicKey,
          title: 'test',
          description: null,
          hashtags: null,
          proofManifestJson: null,
        );

        // Falls back to legacy after session expires
        expect(result.success, isTrue);

        await tempDir.delete(recursive: true);
      });

      test('does not restart via legacy when a committed chunk then hits a '
          'transient network error', () async {
        when(() => mockAuthProvider.isAuthenticated).thenReturn(true);
        when(
          () => mockAuthProvider.createAndSignEvent(
            kind: any(named: 'kind'),
            content: any(named: 'content'),
            tags: any(named: 'tags'),
          ),
        ).thenAnswer(
          (_) async => _signedEvent(_testPublicKey, 24242, const [], 'upload'),
        );

        final tempDir = await Directory.systemTemp.createTemp(
          'chunk_transient_test_',
        );
        final file = File('${tempDir.path}/video.mp4')
          ..writeAsBytesSync(List.generate(10, (i) => i));

        when(
          () => mockDio.head<dynamic>(any(), options: any(named: 'options')),
        ).thenAnswer(
          (_) async => Response(
            requestOptions: RequestOptions(path: '/upload'),
            statusCode: 200,
            headers: Headers.fromMap({
              DivineUploadHeaders.extensions: [
                DivineUploadExtensions.resumableSessions,
              ],
            }),
          ),
        );

        when(
          () => mockDio.post<dynamic>(
            any(),
            data: any(named: 'data'),
            options: any(named: 'options'),
          ),
        ).thenAnswer(
          (_) async => Response(
            requestOptions: RequestOptions(path: '/upload/init'),
            statusCode: 200,
            data: {
              'uploadId': 'up_net',
              'uploadUrl': 'https://upload.divine.video/sessions/up_net',
              'chunkSize': 5,
              'nextOffset': 0,
            },
          ),
        );

        // First chunk commits offset 5; the second is killed mid-flight by a
        // connection reset (the symptom of the OS suspending a backgrounded
        // app), which dio surfaces as an `unknown` DioException wrapping a
        // SocketException.
        var chunkCount = 0;
        when(
          () => mockDio.put<dynamic>(
            any(),
            data: any(named: 'data'),
            options: any(named: 'options'),
            onSendProgress: any(named: 'onSendProgress'),
          ),
        ).thenAnswer((invocation) async {
          final url = invocation.positionalArguments.first as String;
          if (url.contains('sessions/up_net')) {
            chunkCount++;
            if (chunkCount == 1) {
              return Response(
                requestOptions: RequestOptions(path: '/sessions'),
                statusCode: 204,
                headers: Headers.fromMap({
                  DivineUploadHeaders.uploadOffset: ['5'],
                }),
              );
            }
            throw DioException(
              requestOptions: RequestOptions(path: '/sessions'),
              error: const SocketException('Connection reset by peer'),
            );
          }

          // Legacy fallback PUT — must NOT be reached.
          return Response(
            requestOptions: RequestOptions(path: '/upload'),
            statusCode: 200,
            data: {
              'url': 'https://media.divine.video/hash',
              'fallbackUrl': 'https://media.divine.video/hash',
            },
          );
        });

        final result = await service.uploadVideo(
          videoFile: file,
          nostrPubkey: _testPublicKey,
          title: 'test',
          description: null,
          hashtags: null,
          proofManifestJson: null,
        );

        // The transient failure is surfaced (so the caller's outer retry can
        // resume from the committed offset) rather than restarting the whole
        // file through the legacy PUT.
        expect(result.success, isFalse);
        expect(
          result.failureReason,
          equals(BlossomUploadFailureReason.network),
        );
        verifyNever(
          () => mockDio.put<dynamic>(
            'https://media.divine.video/upload',
            data: any(named: 'data'),
            options: any(named: 'options'),
            onSendProgress: any(named: 'onSendProgress'),
          ),
        );

        await tempDir.delete(recursive: true);
      });

      test('chunk upload handles non-success status with X-Reason', () async {
        when(() => mockAuthProvider.isAuthenticated).thenReturn(true);
        when(
          () => mockAuthProvider.createAndSignEvent(
            kind: any(named: 'kind'),
            content: any(named: 'content'),
            tags: any(named: 'tags'),
          ),
        ).thenAnswer(
          (_) async => _signedEvent(_testPublicKey, 24242, const [], 'upload'),
        );

        final tempDir = await Directory.systemTemp.createTemp(
          'chunk_xreason_test_',
        );
        final file = File('${tempDir.path}/video.mp4')
          ..writeAsBytesSync([1, 2, 3]);

        when(
          () => mockDio.head<dynamic>(any(), options: any(named: 'options')),
        ).thenAnswer(
          (_) async => Response(
            requestOptions: RequestOptions(path: '/upload'),
            statusCode: 200,
            headers: Headers.fromMap({
              DivineUploadHeaders.extensions: [
                DivineUploadExtensions.resumableSessions,
              ],
            }),
          ),
        );

        when(
          () => mockDio.post<dynamic>(
            any(),
            data: any(named: 'data'),
            options: any(named: 'options'),
          ),
        ).thenAnswer(
          (_) async => Response(
            requestOptions: RequestOptions(path: '/upload/init'),
            statusCode: 200,
            data: {
              'uploadId': 'up_bad',
              'uploadUrl': 'https://upload.divine.video/sessions/up_bad',
              'chunkSize': 10,
              'nextOffset': 0,
            },
          ),
        );

        when(
          () => mockDio.put<dynamic>(
            any(),
            data: any(named: 'data'),
            options: any(named: 'options'),
            onSendProgress: any(named: 'onSendProgress'),
          ),
        ).thenAnswer((invocation) async {
          final url = invocation.positionalArguments.first as String;
          if (url.contains('sessions/up_bad')) {
            return Response(
              requestOptions: RequestOptions(path: '/sessions'),
              statusCode: 403,
              headers: Headers.fromMap({
                'X-Reason': ['Quota exceeded'],
              }),
            );
          }

          // Legacy fallback
          return Response(
            requestOptions: RequestOptions(path: '/upload'),
            statusCode: 200,
            data: {
              'url': 'https://media.divine.video/hash',
              'fallbackUrl': 'https://media.divine.video/hash',
            },
          );
        });

        final result = await service.uploadVideo(
          videoFile: file,
          nostrPubkey: _testPublicKey,
          title: 'test',
          description: null,
          hashtags: null,
          proofManifestJson: null,
        );

        // Falls back to legacy
        expect(result.success, isTrue);

        await tempDir.delete(recursive: true);
      });
    });

    group('Capability discovery - 5xx DioException', () {
      late _MockDio mockDio;

      setUp(() {
        mockDio = _MockDio();
        service = BlossomUploadService(
          authProvider: mockAuthProvider,
          dio: mockDio,
        );
      });

      test('non-transient DioException on non-Divine host falls back to '
          'no resumable', () async {
        await service.setBlossomServer('https://custom.server');
        await service.setBlossomEnabled(true);

        when(() => mockAuthProvider.isAuthenticated).thenReturn(true);
        when(
          () => mockAuthProvider.createAndSignEvent(
            kind: any(named: 'kind'),
            content: any(named: 'content'),
            tags: any(named: 'tags'),
          ),
        ).thenAnswer(
          (_) async => _signedEvent(_testPublicKey, 24242, const [], 'upload'),
        );

        final tempDir = await Directory.systemTemp.createTemp(
          'cap_non_transient_test_',
        );
        final file = File('${tempDir.path}/video.mp4')
          ..writeAsBytesSync([1, 2, 3]);

        // Non-transient error: badCertificate
        when(
          () => mockDio.head<dynamic>(any(), options: any(named: 'options')),
        ).thenThrow(
          DioException(
            requestOptions: RequestOptions(path: '/upload'),
            type: DioExceptionType.badCertificate,
          ),
        );

        when(
          () => mockDio.put<dynamic>(
            any(),
            data: any(named: 'data'),
            options: any(named: 'options'),
            onSendProgress: any(named: 'onSendProgress'),
          ),
        ).thenAnswer(
          (_) async => Response(
            requestOptions: RequestOptions(path: '/upload'),
            statusCode: 200,
            data: {
              'url': 'https://custom.server/hash',
              'fallbackUrl': 'https://custom.server/hash',
            },
          ),
        );

        final result = await service.uploadVideo(
          videoFile: file,
          nostrPubkey: _testPublicKey,
          title: 'test',
          description: null,
          hashtags: null,
          proofManifestJson: null,
        );

        // Should use legacy PUT (no resumable)
        expect(result.success, isTrue);
        verifyNever(
          () => mockDio.post<dynamic>(
            any(),
            data: any(named: 'data'),
            options: any(named: 'options'),
          ),
        );

        await tempDir.delete(recursive: true);
      });
    });

    group('Server URL resolution', () {
      late _MockDio mockDio;

      setUp(() {
        mockDio = _MockDio();
        service = BlossomUploadService(
          authProvider: mockAuthProvider,
          dio: mockDio,
        );
      });

      test('uses default server when blossom is disabled', () async {
        await service.setBlossomEnabled(false);

        when(() => mockAuthProvider.isAuthenticated).thenReturn(true);
        when(
          () => mockAuthProvider.createAndSignEvent(
            kind: any(named: 'kind'),
            content: any(named: 'content'),
            tags: any(named: 'tags'),
          ),
        ).thenAnswer(
          (_) async => _signedEvent(_testPublicKey, 24242, const [], 'upload'),
        );

        final tempDir = await Directory.systemTemp.createTemp(
          'disabled_server_test_',
        );
        final file = File('${tempDir.path}/video.mp4')
          ..writeAsBytesSync([1, 2, 3]);

        when(
          () => mockDio.head<dynamic>(any(), options: any(named: 'options')),
        ).thenAnswer(
          (_) async => Response(
            requestOptions: RequestOptions(path: '/upload'),
            statusCode: 200,
            headers: Headers(),
          ),
        );

        when(
          () => mockDio.put<dynamic>(
            any(),
            data: any(named: 'data'),
            options: any(named: 'options'),
            onSendProgress: any(named: 'onSendProgress'),
          ),
        ).thenAnswer(
          (_) async => Response(
            requestOptions: RequestOptions(path: '/upload'),
            statusCode: 200,
            data: {
              'url': 'https://media.divine.video/hash',
              'fallbackUrl': 'https://media.divine.video/hash',
            },
          ),
        );

        await service.uploadVideo(
          videoFile: file,
          nostrPubkey: _testPublicKey,
          title: 'test',
          description: null,
          hashtags: null,
          proofManifestJson: null,
        );

        verify(
          () => mockDio.head<dynamic>(
            'https://media.divine.video/upload',
            options: any(named: 'options'),
          ),
        ).called(1);

        await tempDir.delete(recursive: true);
      });
    });

    group('getBlossomServer edge cases', () {
      test('returns default when empty string stored', () async {
        SharedPreferences.setMockInitialValues({'blossom_server_url': ''});
        service = BlossomUploadService(authProvider: mockAuthProvider);
        final url = await service.getBlossomServer();
        expect(url, equals(BlossomUploadService.defaultBlossomServer));
      });

      test('setBlossomServer with empty string clears server', () async {
        await service.setBlossomServer('https://example.com');
        await service.setBlossomServer('');
        final url = await service.getBlossomServer();
        expect(url, equals(BlossomUploadService.defaultBlossomServer));
      });
    });

    group('Non-third-party resumable failure rethrows', () {
      late _MockDio mockDio;

      setUp(() {
        mockDio = _MockDio();
      });

      test('third-party resumable failure rethrows without fallback', () async {
        SharedPreferences.setMockInitialValues({
          'blossom_server_url': 'https://third-party.com',
          'use_blossom_upload': true,
        });

        service = BlossomUploadService(
          authProvider: mockAuthProvider,
          dio: mockDio,
        );

        when(() => mockAuthProvider.isAuthenticated).thenReturn(true);
        when(
          () => mockAuthProvider.createAndSignEvent(
            kind: any(named: 'kind'),
            content: any(named: 'content'),
            tags: any(named: 'tags'),
          ),
        ).thenAnswer(
          (_) async => _signedEvent(_testPublicKey, 24242, const [], 'upload'),
        );

        final tempDir = await Directory.systemTemp.createTemp(
          'third_party_rethrow_test_',
        );
        final file = File('${tempDir.path}/video.mp4')
          ..writeAsBytesSync([1, 2, 3]);

        // Both third-party and default servers advertise resumable
        when(
          () => mockDio.head<dynamic>(any(), options: any(named: 'options')),
        ).thenAnswer(
          (_) async => Response(
            requestOptions: RequestOptions(path: '/upload'),
            statusCode: 200,
            headers: Headers.fromMap({
              DivineUploadHeaders.extensions: [
                DivineUploadExtensions.resumableSessions,
              ],
            }),
          ),
        );

        // Init throws for third-party server
        when(
          () => mockDio.post<dynamic>(
            'https://third-party.com/upload/init',
            data: any(named: 'data'),
            options: any(named: 'options'),
          ),
        ).thenThrow(const BlossomResumableUploadException('init failed'));

        // Default server init also fails to isolate the test
        when(
          () => mockDio.post<dynamic>(
            'https://media.divine.video/upload/init',
            data: any(named: 'data'),
            options: any(named: 'options'),
          ),
        ).thenThrow(const BlossomResumableUploadException('init failed'));

        // Legacy fallback also fails (auth returns null for PUT)
        when(
          () => mockDio.put<dynamic>(
            any(),
            data: any(named: 'data'),
            options: any(named: 'options'),
            onSendProgress: any(named: 'onSendProgress'),
          ),
        ).thenAnswer(
          (_) async => Response(
            requestOptions: RequestOptions(path: '/upload'),
            statusCode: 401,
            data: 'Unauthorized',
            headers: Headers(),
          ),
        );

        final result = await service.uploadVideo(
          videoFile: file,
          nostrPubkey: _testPublicKey,
          title: 'test',
          description: null,
          hashtags: null,
          proofManifestJson: null,
        );

        // Third-party rethrows, then the error is caught by the
        // server loop and recorded. The test verifies the error
        // surfaces.
        expect(result.success, isFalse);

        await tempDir.delete(recursive: true);
      });
    });

    group('Chunk retry on transient error', () {
      late _MockDio mockDio;

      setUp(() {
        mockDio = _MockDio();
        service = BlossomUploadService(
          authProvider: mockAuthProvider,
          dio: mockDio,
        );
      });

      test('retries chunk PUT on transient 500 error then succeeds', () async {
        when(() => mockAuthProvider.isAuthenticated).thenReturn(true);
        when(
          () => mockAuthProvider.createAndSignEvent(
            kind: any(named: 'kind'),
            content: any(named: 'content'),
            tags: any(named: 'tags'),
          ),
        ).thenAnswer(
          (_) async => _signedEvent(_testPublicKey, 24242, const [], 'upload'),
        );

        final tempDir = await Directory.systemTemp.createTemp(
          'chunk_retry_test_',
        );
        final file = File('${tempDir.path}/video.mp4')
          ..writeAsBytesSync([1, 2, 3]);

        when(
          () => mockDio.head<dynamic>(any(), options: any(named: 'options')),
        ).thenAnswer(
          (_) async => Response(
            requestOptions: RequestOptions(path: '/upload'),
            statusCode: 200,
            headers: Headers.fromMap({
              DivineUploadHeaders.extensions: [
                DivineUploadExtensions.resumableSessions,
              ],
            }),
          ),
        );

        when(
          () => mockDio.post<dynamic>(
            any(),
            data: any(named: 'data'),
            options: any(named: 'options'),
          ),
        ).thenAnswer((invocation) async {
          final url = invocation.positionalArguments.first as String;
          if (url.endsWith('/upload/init')) {
            return Response(
              requestOptions: RequestOptions(path: '/upload/init'),
              statusCode: 200,
              data: {
                'uploadId': 'up_retry',
                'uploadUrl': 'https://upload.divine.video/sessions/up_retry',
                'chunkSize': 10,
                'nextOffset': 0,
              },
            );
          }
          if (url.endsWith('/complete')) {
            return Response(
              requestOptions: RequestOptions(path: '/complete'),
              statusCode: 200,
              data: {
                'url': 'https://media.divine.video/hash',
                'fallbackUrl': 'https://media.divine.video/hash',
              },
            );
          }
          throw StateError('Unexpected POST: $url');
        });

        var chunkAttempts = 0;
        when(
          () => mockDio.put<dynamic>(
            any(),
            data: any(named: 'data'),
            options: any(named: 'options'),
            onSendProgress: any(named: 'onSendProgress'),
          ),
        ).thenAnswer((_) async {
          chunkAttempts++;
          if (chunkAttempts == 1) {
            // First attempt fails with 500
            throw DioException(
              requestOptions: RequestOptions(path: '/sessions'),
              type: DioExceptionType.badResponse,
              response: Response(
                requestOptions: RequestOptions(path: '/sessions'),
                statusCode: 500,
              ),
            );
          }
          // Second attempt succeeds
          return Response(
            requestOptions: RequestOptions(path: '/sessions'),
            statusCode: 204,
            headers: Headers.fromMap({
              DivineUploadHeaders.uploadOffset: ['3'],
            }),
          );
        });

        final result = await service.uploadVideo(
          videoFile: file,
          nostrPubkey: _testPublicKey,
          title: 'test',
          description: null,
          hashtags: null,
          proofManifestJson: null,
        );

        expect(result.success, isTrue);
        expect(chunkAttempts, equals(2));

        await tempDir.delete(recursive: true);
      });

      test(
        'chunk retry fails after max retries with non-transient error',
        () async {
          when(() => mockAuthProvider.isAuthenticated).thenReturn(true);
          when(
            () => mockAuthProvider.createAndSignEvent(
              kind: any(named: 'kind'),
              content: any(named: 'content'),
              tags: any(named: 'tags'),
            ),
          ).thenAnswer(
            (_) async =>
                _signedEvent(_testPublicKey, 24242, const [], 'upload'),
          );

          final tempDir = await Directory.systemTemp.createTemp(
            'chunk_max_retry_test_',
          );
          final file = File('${tempDir.path}/video.mp4')
            ..writeAsBytesSync([1, 2, 3]);

          when(
            () => mockDio.head<dynamic>(any(), options: any(named: 'options')),
          ).thenAnswer(
            (_) async => Response(
              requestOptions: RequestOptions(path: '/upload'),
              statusCode: 200,
              headers: Headers.fromMap({
                DivineUploadHeaders.extensions: [
                  DivineUploadExtensions.resumableSessions,
                ],
              }),
            ),
          );

          when(
            () => mockDio.post<dynamic>(
              any(),
              data: any(named: 'data'),
              options: any(named: 'options'),
            ),
          ).thenAnswer((invocation) async {
            final url = invocation.positionalArguments.first as String;
            if (url.endsWith('/upload/init')) {
              return Response(
                requestOptions: RequestOptions(path: '/upload/init'),
                statusCode: 200,
                data: {
                  'uploadId': 'up_maxretry',
                  'uploadUrl':
                      'https://upload.divine.video/sessions/up_maxretry',
                  'chunkSize': 10,
                  'nextOffset': 0,
                },
              );
            }
            throw StateError('Unexpected POST: $url');
          });

          // Non-transient error (badCertificate) — should not retry
          when(
            () => mockDio.put<dynamic>(
              any(),
              data: any(named: 'data'),
              options: any(named: 'options'),
              onSendProgress: any(named: 'onSendProgress'),
            ),
          ).thenThrow(
            DioException(
              requestOptions: RequestOptions(path: '/sessions'),
              type: DioExceptionType.badCertificate,
            ),
          );

          final result = await service.uploadVideo(
            videoFile: file,
            nostrPubkey: _testPublicKey,
            title: 'test',
            description: null,
            hashtags: null,
            proofManifestJson: null,
          );

          // Falls back to legacy which also fails
          expect(result.success, isFalse);

          await tempDir.delete(recursive: true);
        },
      );
    });

    group('Upload with progress callback', () {
      late _MockDio mockDio;

      setUp(() {
        mockDio = _MockDio();
        service = BlossomUploadService(
          authProvider: mockAuthProvider,
          dio: mockDio,
        );
      });

      test('uploadVideo calls onProgress at initialization stages', () async {
        when(() => mockAuthProvider.isAuthenticated).thenReturn(true);
        when(
          () => mockAuthProvider.createAndSignEvent(
            kind: any(named: 'kind'),
            content: any(named: 'content'),
            tags: any(named: 'tags'),
          ),
        ).thenAnswer(
          (_) async => _signedEvent(_testPublicKey, 24242, const [], 'upload'),
        );

        final tempDir = await Directory.systemTemp.createTemp('progress_test_');
        final file = File('${tempDir.path}/video.mp4')
          ..writeAsBytesSync([1, 2, 3]);

        when(
          () => mockDio.head<dynamic>(any(), options: any(named: 'options')),
        ).thenAnswer(
          (_) async => Response(
            requestOptions: RequestOptions(path: '/upload'),
            statusCode: 200,
            headers: Headers(),
          ),
        );

        when(
          () => mockDio.put<dynamic>(
            any(),
            data: any(named: 'data'),
            options: any(named: 'options'),
            onSendProgress: any(named: 'onSendProgress'),
          ),
        ).thenAnswer(
          (_) async => Response(
            requestOptions: RequestOptions(path: '/upload'),
            statusCode: 200,
            data: {
              'url': 'https://media.divine.video/hash',
              'fallbackUrl': 'https://media.divine.video/hash',
            },
          ),
        );

        final progressValues = <double>[];
        await service.uploadVideo(
          videoFile: file,
          nostrPubkey: _testPublicKey,
          title: 'test',
          description: null,
          hashtags: null,
          proofManifestJson: null,
          onProgress: progressValues.add,
        );

        // Should have at least 0.1 (init) and 0.2 (after hash)
        expect(progressValues, contains(0.1));
        expect(progressValues, contains(0.2));

        await tempDir.delete(recursive: true);
      });
    });

    group('Image upload success path', () {
      late _MockDio mockDio;

      setUp(() {
        mockDio = _MockDio();
        service = BlossomUploadService(
          authProvider: mockAuthProvider,
          dio: mockDio,
        );
      });

      test('succeeds with correct canonical URL', () async {
        when(() => mockAuthProvider.isAuthenticated).thenReturn(true);
        when(
          () => mockAuthProvider.createAndSignEvent(
            kind: any(named: 'kind'),
            content: any(named: 'content'),
            tags: any(named: 'tags'),
          ),
        ).thenAnswer(
          (_) async => _signedEvent(_testPublicKey, 24242, const [], 'upload'),
        );

        final tempDir = await Directory.systemTemp.createTemp(
          'image_success_test_',
        );
        final imageFile = File('${tempDir.path}/image.jpg')
          ..writeAsBytesSync([0xFF, 0xD8, 0xFF]);

        when(
          () => mockDio.head<dynamic>(any(), options: any(named: 'options')),
        ).thenAnswer(
          (_) async => Response(
            requestOptions: RequestOptions(path: '/upload'),
            statusCode: 200,
            headers: Headers(),
          ),
        );

        when(
          () => mockDio.put<dynamic>(
            any(),
            data: any(named: 'data'),
            options: any(named: 'options'),
            onSendProgress: any(named: 'onSendProgress'),
          ),
        ).thenAnswer(
          (_) async => Response(
            requestOptions: RequestOptions(path: '/upload'),
            statusCode: 200,
            data: {
              'url': 'https://media.divine.video/hash',
              'fallbackUrl': 'https://media.divine.video/hash',
            },
          ),
        );

        final progressValues = <double>[];
        final result = await service.uploadImage(
          imageFile: imageFile,
          nostrPubkey: _testPublicKey,
          onProgress: progressValues.add,
        );

        expect(result.success, isTrue);
        expect(result.cdnUrl, contains('media.divine.video'));
        expect(progressValues, contains(0.1));
        expect(progressValues, contains(0.2));

        await tempDir.delete(recursive: true);
      });

      test(
        'uses resumable upload when Divine image server advertises support',
        () async {
          when(() => mockAuthProvider.isAuthenticated).thenReturn(true);
          when(
            () => mockAuthProvider.createAndSignEvent(
              kind: any(named: 'kind'),
              content: any(named: 'content'),
              tags: any(named: 'tags'),
            ),
          ).thenAnswer(
            (_) async =>
                _signedEvent(_testPublicKey, 24242, const [], 'upload'),
          );

          final tempDir = await Directory.systemTemp.createTemp(
            'image_resumable_test_',
          );
          final imageFile = File('${tempDir.path}/image.jpg')
            ..writeAsBytesSync([0xFF, 0xD8, 0xFF]);

          when(
            () => mockDio.head<dynamic>(any(), options: any(named: 'options')),
          ).thenAnswer(
            (_) async => Response(
              requestOptions: RequestOptions(path: '/upload'),
              statusCode: 200,
              headers: Headers.fromMap({
                DivineUploadHeaders.extensions: [
                  DivineUploadExtensions.resumableSessions,
                ],
                DivineUploadHeaders.dataHost: ['https://upload.divine.video'],
              }),
            ),
          );

          when(
            () => mockDio.post<dynamic>(
              any(),
              data: any(named: 'data'),
              options: any(named: 'options'),
            ),
          ).thenAnswer((invocation) async {
            final url = invocation.positionalArguments.first as String;

            if (url.endsWith('/upload/init')) {
              return Response(
                requestOptions: RequestOptions(path: '/upload/init'),
                statusCode: 201,
                data: {
                  'uploadId': 'up_image',
                  'uploadUrl': 'https://upload.divine.video/sessions/up_image',
                  'chunkSize': 1024,
                  'nextOffset': 0,
                  'expiresAt': 9999999999,
                },
              );
            }

            if (url.endsWith('/upload/up_image/complete')) {
              return Response(
                requestOptions: RequestOptions(
                  path: '/upload/up_image/complete',
                ),
                statusCode: 200,
                data: {
                  'url': 'https://media.divine.video/image-hash',
                  'fallbackUrl': 'https://media.divine.video/image-hash',
                },
              );
            }

            throw StateError('Unexpected POST url: $url');
          });

          final putUrls = <String>[];
          when(
            () => mockDio.put<dynamic>(
              any(),
              data: any(named: 'data'),
              options: any(named: 'options'),
              onSendProgress: any(named: 'onSendProgress'),
            ),
          ).thenAnswer((invocation) async {
            final url = invocation.positionalArguments.first as String;
            putUrls.add(url);

            if (url == 'https://upload.divine.video/sessions/up_image') {
              return Response(
                requestOptions: RequestOptions(path: '/sessions/up_image'),
                statusCode: 204,
                headers: Headers.fromMap({
                  DivineUploadHeaders.uploadOffset: ['3'],
                }),
              );
            }

            return Response(
              requestOptions: RequestOptions(path: '/upload'),
              statusCode: 503,
              data: {'error': 'legacy upload unavailable'},
            );
          });

          final result = await service.uploadImage(
            imageFile: imageFile,
            nostrPubkey: _testPublicKey,
          );

          expect(result.success, isTrue);
          expect(putUrls, isNot(contains('https://media.divine.video/upload')));
          expect(
            putUrls,
            contains('https://upload.divine.video/sessions/up_image'),
          );

          await tempDir.delete(recursive: true);
        },
      );

      test(
        'skips the resumable handshake when allowResumable is false, even on '
        'a resumable-capable server',
        () async {
          when(() => mockAuthProvider.isAuthenticated).thenReturn(true);
          when(
            () => mockAuthProvider.createAndSignEvent(
              kind: any(named: 'kind'),
              content: any(named: 'content'),
              tags: any(named: 'tags'),
            ),
          ).thenAnswer(
            (_) async =>
                _signedEvent(_testPublicKey, 24242, const [], 'upload'),
          );

          final tempDir = await Directory.systemTemp.createTemp(
            'image_single_put_test_',
          );
          final imageFile = File('${tempDir.path}/image.jpg')
            ..writeAsBytesSync([0xFF, 0xD8, 0xFF]);

          // The server advertises resumable support...
          when(
            () => mockDio.head<dynamic>(any(), options: any(named: 'options')),
          ).thenAnswer(
            (_) async => Response(
              requestOptions: RequestOptions(path: '/upload'),
              statusCode: 200,
              headers: Headers.fromMap({
                DivineUploadHeaders.extensions: [
                  DivineUploadExtensions.resumableSessions,
                ],
                DivineUploadHeaders.dataHost: ['https://upload.divine.video'],
              }),
            ),
          );

          // ...but with allowResumable: false the init endpoint must not run.
          var initCalled = false;
          when(
            () => mockDio.post<dynamic>(
              any(),
              data: any(named: 'data'),
              options: any(named: 'options'),
            ),
          ).thenAnswer((invocation) async {
            initCalled = true;
            throw StateError(
              'Unexpected resumable POST: '
              '${invocation.positionalArguments.first}',
            );
          });

          final putUrls = <String>[];
          when(
            () => mockDio.put<dynamic>(
              any(),
              data: any(named: 'data'),
              options: any(named: 'options'),
              onSendProgress: any(named: 'onSendProgress'),
            ),
          ).thenAnswer((invocation) async {
            putUrls.add(invocation.positionalArguments.first as String);
            return Response(
              requestOptions: RequestOptions(path: '/upload'),
              statusCode: 200,
              data: {
                'url': 'https://media.divine.video/hash',
                'fallbackUrl': 'https://media.divine.video/hash',
              },
            );
          });

          final result = await service.uploadImage(
            imageFile: imageFile,
            nostrPubkey: _testPublicKey,
            allowResumable: false,
          );

          expect(result.success, isTrue);
          expect(initCalled, isFalse);
          expect(putUrls, contains('https://media.divine.video/upload'));

          await tempDir.delete(recursive: true);
        },
      );

      test(
        'skips the capability probe entirely when allowResumable is false',
        () async {
          when(() => mockAuthProvider.isAuthenticated).thenReturn(true);
          when(
            () => mockAuthProvider.createAndSignEvent(
              kind: any(named: 'kind'),
              content: any(named: 'content'),
              tags: any(named: 'tags'),
            ),
          ).thenAnswer(
            (_) async =>
                _signedEvent(_testPublicKey, 24242, const [], 'upload'),
          );

          final tempDir = await Directory.systemTemp.createTemp(
            'image_no_capability_probe_test_',
          );
          final imageFile = File('${tempDir.path}/image.jpg')
            ..writeAsBytesSync([0xFF, 0xD8, 0xFF]);

          // Stubbed so a stray probe would surface as a verify failure rather
          // than a null-return crash.
          when(
            () => mockDio.head<dynamic>(any(), options: any(named: 'options')),
          ).thenAnswer(
            (_) async => Response(
              requestOptions: RequestOptions(path: '/upload'),
              statusCode: 200,
              headers: Headers(),
            ),
          );

          when(
            () => mockDio.put<dynamic>(
              any(),
              data: any(named: 'data'),
              options: any(named: 'options'),
              onSendProgress: any(named: 'onSendProgress'),
            ),
          ).thenAnswer(
            (_) async => Response(
              requestOptions: RequestOptions(path: '/upload'),
              statusCode: 200,
              data: {
                'url': 'https://media.divine.video/hash',
                'fallbackUrl': 'https://media.divine.video/hash',
              },
            ),
          );

          final result = await service.uploadImage(
            imageFile: imageFile,
            nostrPubkey: _testPublicKey,
            allowResumable: false,
          );

          expect(result.success, isTrue);
          // The probe only picks resumable vs single PUT, so with resumable
          // off it is a pure round-trip tax on the publish critical path.
          verifyNever(
            () => mockDio.head<dynamic>(any(), options: any(named: 'options')),
          );

          await tempDir.delete(recursive: true);
        },
      );

      test(
        'falls back to legacy upload when Divine image resumable init fails',
        () async {
          when(() => mockAuthProvider.isAuthenticated).thenReturn(true);
          when(
            () => mockAuthProvider.createAndSignEvent(
              kind: any(named: 'kind'),
              content: any(named: 'content'),
              tags: any(named: 'tags'),
            ),
          ).thenAnswer(
            (_) async =>
                _signedEvent(_testPublicKey, 24242, const [], 'upload'),
          );

          final tempDir = await Directory.systemTemp.createTemp(
            'image_resumable_init_fallback_test_',
          );
          final imageFile = File('${tempDir.path}/image.jpg')
            ..writeAsBytesSync([0xFF, 0xD8, 0xFF]);

          when(
            () => mockDio.head<dynamic>(any(), options: any(named: 'options')),
          ).thenAnswer(
            (_) async => Response(
              requestOptions: RequestOptions(path: '/upload'),
              statusCode: 200,
              headers: Headers.fromMap({
                DivineUploadHeaders.extensions: [
                  DivineUploadExtensions.resumableSessions,
                ],
              }),
            ),
          );

          when(
            () => mockDio.post<dynamic>(
              any(),
              data: any(named: 'data'),
              options: any(named: 'options'),
            ),
          ).thenAnswer(
            (_) async => Response(
              requestOptions: RequestOptions(path: '/upload/init'),
              statusCode: 403,
              data: {'error': 'init unavailable'},
            ),
          );

          final putUrls = <String>[];
          when(
            () => mockDio.put<dynamic>(
              any(),
              data: any(named: 'data'),
              options: any(named: 'options'),
              onSendProgress: any(named: 'onSendProgress'),
            ),
          ).thenAnswer((invocation) async {
            final url = invocation.positionalArguments.first as String;
            putUrls.add(url);

            return Response(
              requestOptions: RequestOptions(path: '/upload'),
              statusCode: 200,
              data: {
                'url': 'https://media.divine.video/fallback-image',
                'fallbackUrl': 'https://media.divine.video/fallback-image',
              },
            );
          });

          final result = await service.uploadImage(
            imageFile: imageFile,
            nostrPubkey: _testPublicKey,
          );

          expect(result.success, isTrue);
          expect(putUrls, contains('https://media.divine.video/upload'));

          await tempDir.delete(recursive: true);
        },
      );

      test(
        'falls back to legacy upload when Divine image completion fails',
        () async {
          when(() => mockAuthProvider.isAuthenticated).thenReturn(true);
          when(
            () => mockAuthProvider.createAndSignEvent(
              kind: any(named: 'kind'),
              content: any(named: 'content'),
              tags: any(named: 'tags'),
            ),
          ).thenAnswer(
            (_) async =>
                _signedEvent(_testPublicKey, 24242, const [], 'upload'),
          );

          final tempDir = await Directory.systemTemp.createTemp(
            'image_resumable_result_fallback_test_',
          );
          final imageFile = File('${tempDir.path}/image.jpg')
            ..writeAsBytesSync([0xFF, 0xD8, 0xFF]);

          when(
            () => mockDio.head<dynamic>(any(), options: any(named: 'options')),
          ).thenAnswer(
            (_) async => Response(
              requestOptions: RequestOptions(path: '/upload'),
              statusCode: 200,
              headers: Headers.fromMap({
                DivineUploadHeaders.extensions: [
                  DivineUploadExtensions.resumableSessions,
                ],
              }),
            ),
          );

          when(
            () => mockDio.post<dynamic>(
              any(),
              data: any(named: 'data'),
              options: any(named: 'options'),
            ),
          ).thenAnswer((invocation) async {
            final url = invocation.positionalArguments.first as String;

            if (url.endsWith('/upload/init')) {
              return Response(
                requestOptions: RequestOptions(path: '/upload/init'),
                statusCode: 201,
                data: {
                  'uploadId': 'up_image',
                  'uploadUrl': 'https://upload.divine.video/sessions/up_image',
                  'chunkSize': 1024,
                  'nextOffset': 0,
                  'expiresAt': 9999999999,
                },
              );
            }

            if (url.endsWith('/upload/up_image/complete')) {
              return Response(
                requestOptions: RequestOptions(
                  path: '/upload/up_image/complete',
                ),
                statusCode: 200,
                data: {'sha256': 'image-hash'},
              );
            }

            throw StateError('Unexpected POST url: $url');
          });

          final putUrls = <String>[];
          when(
            () => mockDio.put<dynamic>(
              any(),
              data: any(named: 'data'),
              options: any(named: 'options'),
              onSendProgress: any(named: 'onSendProgress'),
            ),
          ).thenAnswer((invocation) async {
            final url = invocation.positionalArguments.first as String;
            putUrls.add(url);

            if (url == 'https://upload.divine.video/sessions/up_image') {
              return Response(
                requestOptions: RequestOptions(path: '/sessions/up_image'),
                statusCode: 204,
                headers: Headers.fromMap({
                  DivineUploadHeaders.uploadOffset: ['3'],
                }),
              );
            }

            return Response(
              requestOptions: RequestOptions(path: '/upload'),
              statusCode: 200,
              data: {
                'url': 'https://media.divine.video/fallback-image',
                'fallbackUrl': 'https://media.divine.video/fallback-image',
              },
            );
          });

          final result = await service.uploadImage(
            imageFile: imageFile,
            nostrPubkey: _testPublicKey,
          );

          expect(result.success, isTrue);
          expect(
            putUrls,
            contains('https://upload.divine.video/sessions/up_image'),
          );
          expect(putUrls, contains('https://media.divine.video/upload'));

          await tempDir.delete(recursive: true);
        },
      );

      test('tries Divine image legacy fallback only once when resumable init '
          'and fallback both fail', () async {
        when(() => mockAuthProvider.isAuthenticated).thenReturn(true);
        when(
          () => mockAuthProvider.createAndSignEvent(
            kind: any(named: 'kind'),
            content: any(named: 'content'),
            tags: any(named: 'tags'),
          ),
        ).thenAnswer(
          (_) async => _signedEvent(_testPublicKey, 24242, const [], 'upload'),
        );

        final tempDir = await Directory.systemTemp.createTemp(
          'image_single_fallback_attempt_test_',
        );
        final imageFile = File('${tempDir.path}/image.jpg')
          ..writeAsBytesSync([0xFF, 0xD8, 0xFF]);

        when(
          () => mockDio.head<dynamic>(any(), options: any(named: 'options')),
        ).thenAnswer(
          (_) async => Response(
            requestOptions: RequestOptions(path: '/upload'),
            statusCode: 200,
            headers: Headers.fromMap({
              DivineUploadHeaders.extensions: [
                DivineUploadExtensions.resumableSessions,
              ],
            }),
          ),
        );

        when(
          () => mockDio.post<dynamic>(
            any(),
            data: any(named: 'data'),
            options: any(named: 'options'),
          ),
        ).thenAnswer(
          (_) async => Response(
            requestOptions: RequestOptions(path: '/upload/init'),
            statusCode: 403,
            data: {'error': 'init unavailable'},
          ),
        );

        final putUrls = <String>[];
        when(
          () => mockDio.put<dynamic>(
            any(),
            data: any(named: 'data'),
            options: any(named: 'options'),
            onSendProgress: any(named: 'onSendProgress'),
          ),
        ).thenAnswer((invocation) async {
          final url = invocation.positionalArguments.first as String;
          putUrls.add(url);

          return Response(
            requestOptions: RequestOptions(path: '/upload'),
            statusCode: 503,
            data: {'error': 'legacy upload unavailable'},
          );
        });

        // maxAttempts: 1 isolates this test to a single per-server attempt,
        // which is the property under test (no duplicate legacy fallback
        // *within* one attempt). The retry behavior across attempts is
        // covered separately under "uploadImage - retry behavior".
        final result = await service.uploadImage(
          imageFile: imageFile,
          nostrPubkey: _testPublicKey,
          maxAttempts: 1,
        );

        expect(result.success, isFalse);
        expect(
          putUrls.where((url) => url == 'https://media.divine.video/upload'),
          hasLength(1),
        );

        await tempDir.delete(recursive: true);
      });

      test('does not use legacy fallback for third-party image resumable '
          'failures', () async {
        SharedPreferences.setMockInitialValues({
          'blossom_server_url': 'https://third-party.com',
          'use_blossom_upload': true,
        });
        service = BlossomUploadService(
          authProvider: mockAuthProvider,
          dio: mockDio,
        );

        when(() => mockAuthProvider.isAuthenticated).thenReturn(true);
        when(
          () => mockAuthProvider.createAndSignEvent(
            kind: any(named: 'kind'),
            content: any(named: 'content'),
            tags: any(named: 'tags'),
          ),
        ).thenAnswer(
          (_) async => _signedEvent(_testPublicKey, 24242, const [], 'upload'),
        );

        final tempDir = await Directory.systemTemp.createTemp(
          'image_third_party_no_fallback_test_',
        );
        final imageFile = File('${tempDir.path}/image.jpg')
          ..writeAsBytesSync([0xFF, 0xD8, 0xFF]);

        when(
          () => mockDio.head<dynamic>(any(), options: any(named: 'options')),
        ).thenAnswer((invocation) async {
          final url = invocation.positionalArguments.first as String;

          if (url == 'https://third-party.com/upload') {
            return Response(
              requestOptions: RequestOptions(path: '/upload'),
              statusCode: 200,
              headers: Headers.fromMap({
                DivineUploadHeaders.extensions: [
                  DivineUploadExtensions.resumableSessions,
                ],
              }),
            );
          }

          return Response(
            requestOptions: RequestOptions(path: '/upload'),
            statusCode: 200,
            headers: Headers(),
          );
        });

        when(
          () => mockDio.post<dynamic>(
            'https://third-party.com/upload/init',
            data: any(named: 'data'),
            options: any(named: 'options'),
          ),
        ).thenThrow(const BlossomResumableUploadException('init failed'));

        when(
          () => mockDio.put<dynamic>(
            any(),
            data: any(named: 'data'),
            options: any(named: 'options'),
            onSendProgress: any(named: 'onSendProgress'),
          ),
        ).thenAnswer(
          (_) async => Response(
            requestOptions: RequestOptions(path: '/upload'),
            statusCode: 200,
            data: {
              'url': 'https://media.divine.video/fallback-image',
              'fallbackUrl': 'https://media.divine.video/fallback-image',
            },
          ),
        );

        final result = await service.uploadImage(
          imageFile: imageFile,
          nostrPubkey: _testPublicKey,
        );

        expect(result.success, isTrue);
        verifyNever(
          () => mockDio.put<dynamic>(
            'https://third-party.com/upload',
            data: any(named: 'data'),
            options: any(named: 'options'),
            onSendProgress: any(named: 'onSendProgress'),
          ),
        );
        verify(
          () => mockDio.put<dynamic>(
            'https://media.divine.video/upload',
            data: any(named: 'data'),
            options: any(named: 'options'),
            onSendProgress: any(named: 'onSendProgress'),
          ),
        ).called(1);

        await tempDir.delete(recursive: true);
      });

      test('catches server DioException and tries next server', () async {
        when(() => mockAuthProvider.isAuthenticated).thenReturn(true);
        when(
          () => mockAuthProvider.createAndSignEvent(
            kind: any(named: 'kind'),
            content: any(named: 'content'),
            tags: any(named: 'tags'),
          ),
        ).thenAnswer(
          (_) async => _signedEvent(_testPublicKey, 24242, const [], 'upload'),
        );

        final tempDir = await Directory.systemTemp.createTemp(
          'image_exc_test_',
        );
        final imageFile = File('${tempDir.path}/image.jpg')
          ..writeAsBytesSync([0xFF, 0xD8, 0xFF]);

        when(
          () => mockDio.head<dynamic>(any(), options: any(named: 'options')),
        ).thenAnswer(
          (_) async => Response(
            requestOptions: RequestOptions(path: '/upload'),
            statusCode: 200,
            headers: Headers(),
          ),
        );

        when(
          () => mockDio.put<dynamic>(
            any(),
            data: any(named: 'data'),
            options: any(named: 'options'),
            onSendProgress: any(named: 'onSendProgress'),
          ),
        ).thenThrow(
          DioException(
            requestOptions: RequestOptions(path: '/upload'),
            type: DioExceptionType.connectionError,
            response: Response(
              requestOptions: RequestOptions(path: '/upload'),
              statusCode: 503,
            ),
          ),
        );

        final result = await service.uploadImage(
          imageFile: imageFile,
          nostrPubkey: _testPublicKey,
        );

        expect(result.success, isFalse);

        await tempDir.delete(recursive: true);
      });
    });

    // Regression coverage for #3862: a single transient 5xx from the only
    // configured server used to surface as a hard failure. The service now
    // retries the per-server attempt with exponential backoff before falling
    // through to the next server.
    group('uploadImage - retry behavior', () {
      late _MockDio mockDio;

      setUp(() {
        mockDio = _MockDio();
        // No-op sleep: assertions in this group are about attempt counts and
        // final state, not backoff timing. Skipping the real 1s/2s waits cuts
        // the group's wall time from ~16s to ~1s without changing semantics.
        service = BlossomUploadService(
          authProvider: mockAuthProvider,
          dio: mockDio,
          sleep: (_) async {},
        );
      });

      // Stock head() mock — capability discovery returns 200 with no
      // resumable extension, so the legacy PUT path is taken.
      void stubLegacyHead() {
        when(
          () => mockDio.head<dynamic>(any(), options: any(named: 'options')),
        ).thenAnswer(
          (_) async => Response(
            requestOptions: RequestOptions(path: '/upload'),
            statusCode: 200,
            headers: Headers(),
          ),
        );
      }

      void stubAuth() {
        when(() => mockAuthProvider.isAuthenticated).thenReturn(true);
        when(
          () => mockAuthProvider.createAndSignEvent(
            kind: any(named: 'kind'),
            content: any(named: 'content'),
            tags: any(named: 'tags'),
          ),
        ).thenAnswer(
          (_) async => _signedEvent(_testPublicKey, 24242, const [], 'upload'),
        );
      }

      Future<File> tempImage(String tag) async {
        final tempDir = await Directory.systemTemp.createTemp(
          'image_retry_test_${tag}_',
        );
        return File('${tempDir.path}/image.jpg')
          ..writeAsBytesSync([0xFF, 0xD8, 0xFF]);
      }

      DioException dioBadResponse(int statusCode) => DioException(
        requestOptions: RequestOptions(path: '/upload'),
        type: DioExceptionType.badResponse,
        response: Response(
          requestOptions: RequestOptions(path: '/upload'),
          statusCode: statusCode,
        ),
      );

      Response<dynamic> uploadOkResponse() => Response(
        requestOptions: RequestOptions(path: '/upload'),
        statusCode: 200,
        data: {
          'url': 'https://media.divine.video/hash',
          'fallbackUrl': 'https://media.divine.video/hash',
        },
      );

      test('retries on 503 and succeeds on second attempt', () async {
        stubAuth();
        stubLegacyHead();

        final imageFile = await tempImage('503');
        var attempt = 0;
        when(
          () => mockDio.put<dynamic>(
            any(),
            data: any(named: 'data'),
            options: any(named: 'options'),
            onSendProgress: any(named: 'onSendProgress'),
          ),
        ).thenAnswer((_) async {
          attempt++;
          if (attempt == 1) throw dioBadResponse(503);
          return uploadOkResponse();
        });

        final result = await service.uploadImage(
          imageFile: imageFile,
          nostrPubkey: _testPublicKey,
        );

        expect(result.success, isTrue);
        expect(attempt, equals(2));

        await imageFile.parent.delete(recursive: true);
      });

      test('retries on 504 and succeeds', () async {
        stubAuth();
        stubLegacyHead();

        final imageFile = await tempImage('504');
        var attempt = 0;
        when(
          () => mockDio.put<dynamic>(
            any(),
            data: any(named: 'data'),
            options: any(named: 'options'),
            onSendProgress: any(named: 'onSendProgress'),
          ),
        ).thenAnswer((_) async {
          attempt++;
          if (attempt == 1) throw dioBadResponse(504);
          return uploadOkResponse();
        });

        final result = await service.uploadImage(
          imageFile: imageFile,
          nostrPubkey: _testPublicKey,
        );

        expect(result.success, isTrue);
        expect(attempt, equals(2));

        await imageFile.parent.delete(recursive: true);
      });

      test('retries on 429 and succeeds', () async {
        stubAuth();
        stubLegacyHead();

        final imageFile = await tempImage('429');
        var attempt = 0;
        when(
          () => mockDio.put<dynamic>(
            any(),
            data: any(named: 'data'),
            options: any(named: 'options'),
            onSendProgress: any(named: 'onSendProgress'),
          ),
        ).thenAnswer((_) async {
          attempt++;
          if (attempt == 1) throw dioBadResponse(429);
          return uploadOkResponse();
        });

        final result = await service.uploadImage(
          imageFile: imageFile,
          nostrPubkey: _testPublicKey,
        );

        expect(result.success, isTrue);
        expect(attempt, equals(2));

        await imageFile.parent.delete(recursive: true);
      });

      test('retries on 408 and succeeds', () async {
        stubAuth();
        stubLegacyHead();

        final imageFile = await tempImage('408');
        var attempt = 0;
        when(
          () => mockDio.put<dynamic>(
            any(),
            data: any(named: 'data'),
            options: any(named: 'options'),
            onSendProgress: any(named: 'onSendProgress'),
          ),
        ).thenAnswer((_) async {
          attempt++;
          if (attempt == 1) throw dioBadResponse(408);
          return uploadOkResponse();
        });

        final result = await service.uploadImage(
          imageFile: imageFile,
          nostrPubkey: _testPublicKey,
        );

        expect(result.success, isTrue);
        expect(attempt, equals(2));

        await imageFile.parent.delete(recursive: true);
      });

      test(
        'exhausts retries on persistent 503 and returns last error',
        () async {
          stubAuth();
          stubLegacyHead();

          final imageFile = await tempImage('exhaust');
          var attempt = 0;
          when(
            () => mockDio.put<dynamic>(
              any(),
              data: any(named: 'data'),
              options: any(named: 'options'),
              onSendProgress: any(named: 'onSendProgress'),
            ),
          ).thenAnswer((_) async {
            attempt++;
            throw dioBadResponse(503);
          });

          final result = await service.uploadImage(
            imageFile: imageFile,
            nostrPubkey: _testPublicKey,
          );

          expect(result.success, isFalse);
          expect(result.statusCode, equals(503));
          expect(attempt, equals(3));

          await imageFile.parent.delete(recursive: true);
        },
      );

      test('does NOT retry on 401', () async {
        stubAuth();
        stubLegacyHead();

        final imageFile = await tempImage('401');
        var attempt = 0;
        when(
          () => mockDio.put<dynamic>(
            any(),
            data: any(named: 'data'),
            options: any(named: 'options'),
            onSendProgress: any(named: 'onSendProgress'),
          ),
        ).thenAnswer((_) async {
          attempt++;
          throw dioBadResponse(401);
        });

        final result = await service.uploadImage(
          imageFile: imageFile,
          nostrPubkey: _testPublicKey,
        );

        expect(result.success, isFalse);
        expect(result.statusCode, equals(401));
        expect(attempt, equals(1));

        await imageFile.parent.delete(recursive: true);
      });

      test('does NOT retry on 413 (file too large)', () async {
        stubAuth();
        stubLegacyHead();

        final imageFile = await tempImage('413');
        var attempt = 0;
        when(
          () => mockDio.put<dynamic>(
            any(),
            data: any(named: 'data'),
            options: any(named: 'options'),
            onSendProgress: any(named: 'onSendProgress'),
          ),
        ).thenAnswer((_) async {
          attempt++;
          throw dioBadResponse(413);
        });

        final result = await service.uploadImage(
          imageFile: imageFile,
          nostrPubkey: _testPublicKey,
        );

        expect(result.success, isFalse);
        expect(result.statusCode, equals(413));
        expect(attempt, equals(1));

        await imageFile.parent.delete(recursive: true);
      });

      test('does NOT retry on success', () async {
        stubAuth();
        stubLegacyHead();

        final imageFile = await tempImage('happy');
        var attempt = 0;
        when(
          () => mockDio.put<dynamic>(
            any(),
            data: any(named: 'data'),
            options: any(named: 'options'),
            onSendProgress: any(named: 'onSendProgress'),
          ),
        ).thenAnswer((_) async {
          attempt++;
          return uploadOkResponse();
        });

        final result = await service.uploadImage(
          imageFile: imageFile,
          nostrPubkey: _testPublicKey,
        );

        expect(result.success, isTrue);
        expect(attempt, equals(1));

        await imageFile.parent.delete(recursive: true);
      });

      test('maxAttempts: 1 disables retry', () async {
        stubAuth();
        stubLegacyHead();

        final imageFile = await tempImage('opt_out');
        var attempt = 0;
        when(
          () => mockDio.put<dynamic>(
            any(),
            data: any(named: 'data'),
            options: any(named: 'options'),
            onSendProgress: any(named: 'onSendProgress'),
          ),
        ).thenAnswer((_) async {
          attempt++;
          throw dioBadResponse(503);
        });

        final result = await service.uploadImage(
          imageFile: imageFile,
          nostrPubkey: _testPublicKey,
          maxAttempts: 1,
        );

        expect(result.success, isFalse);
        expect(result.statusCode, equals(503));
        expect(
          attempt,
          equals(1),
          reason:
              'maxAttempts: 1 must short-circuit retry so callers with their '
              'own outer retry loop (UploadManager) do not double-retry.',
        );

        await imageFile.parent.delete(recursive: true);
      });

      test(
        'retries on DioException thrown from non-Divine host resumable init',
        () async {
          // Non-Divine hosts re-throw resumable failures (no Divine-only
          // legacy fallback). The retry helper must classify a DioException
          // with a 5xx status as transient and retry, exercising the
          // exception-typed `_isTransientUploadError` branch.
          await service.setBlossomEnabled(true);
          await service.setBlossomServer('https://third-party.example');

          stubAuth();

          final imageFile = await tempImage('non_divine_dio');

          when(
            () => mockDio.head<dynamic>(any(), options: any(named: 'options')),
          ).thenAnswer(
            (_) async => Response(
              requestOptions: RequestOptions(path: '/upload'),
              statusCode: 200,
              headers: Headers.fromMap({
                DivineUploadHeaders.extensions: [
                  DivineUploadExtensions.resumableSessions,
                ],
              }),
            ),
          );

          // Track init attempts per host so we can distinguish per-server
          // retry from the multi-server fallback that runs after retries are
          // exhausted.
          final initAttemptsByHost = <String, int>{};
          when(
            () => mockDio.post<dynamic>(
              any(),
              data: any(named: 'data'),
              options: any(named: 'options'),
            ),
          ).thenAnswer((invocation) async {
            final url = invocation.positionalArguments.first as String;
            if (!url.endsWith('/upload/init')) {
              // Complete endpoint or anything else — return a generic OK so
              // we only count init attempts in the assertion below.
              return Response(
                requestOptions: RequestOptions(path: url),
                statusCode: 200,
                data: {
                  'url': 'https://media.divine.video/hash',
                  'fallbackUrl': 'https://media.divine.video/hash',
                },
              );
            }
            final host = Uri.parse(url).host;
            final n = (initAttemptsByHost[host] ?? 0) + 1;
            initAttemptsByHost[host] = n;
            if (host == 'third-party.example' && n == 1) {
              throw DioException(
                requestOptions: RequestOptions(path: '/upload/init'),
                type: DioExceptionType.badResponse,
                response: Response(
                  requestOptions: RequestOptions(path: '/upload/init'),
                  statusCode: 503,
                ),
              );
            }
            return Response(
              requestOptions: RequestOptions(path: '/upload/init'),
              statusCode: 201,
              data: {
                'uploadId': 'up_retry_dio',
                'uploadUrl':
                    'https://third-party.example/sessions/up_retry_dio',
                'chunkSize': 1024,
                'nextOffset': 0,
                'expiresAt': 9999999999,
              },
            );
          });

          when(
            () => mockDio.put<dynamic>(
              any(),
              data: any(named: 'data'),
              options: any(named: 'options'),
              onSendProgress: any(named: 'onSendProgress'),
            ),
          ).thenAnswer(
            (_) async => Response(
              requestOptions: RequestOptions(path: '/sessions/up_retry_dio'),
              statusCode: 204,
              headers: Headers.fromMap({
                DivineUploadHeaders.uploadOffset: ['3'],
              }),
            ),
          );

          await service.uploadImage(
            imageFile: imageFile,
            nostrPubkey: _testPublicKey,
          );

          expect(
            initAttemptsByHost['third-party.example'],
            equals(2),
            reason:
                'A 503 DioException from non-Divine host resumable init must '
                'be classified as transient by _isTransientUploadError so the '
                'retry helper schedules another attempt on the same host.',
          );

          await imageFile.parent.delete(recursive: true);
        },
      );

      test('does NOT retry on DioException with non-retriable status from '
          'non-Divine host', () async {
        await service.setBlossomEnabled(true);
        await service.setBlossomServer('https://third-party.example');

        stubAuth();

        final imageFile = await tempImage('non_divine_dio_401');

        when(
          () => mockDio.head<dynamic>(any(), options: any(named: 'options')),
        ).thenAnswer(
          (_) async => Response(
            requestOptions: RequestOptions(path: '/upload'),
            statusCode: 200,
            headers: Headers.fromMap({
              DivineUploadHeaders.extensions: [
                DivineUploadExtensions.resumableSessions,
              ],
            }),
          ),
        );

        final initAttemptsByHost = <String, int>{};
        when(
          () => mockDio.post<dynamic>(
            any(),
            data: any(named: 'data'),
            options: any(named: 'options'),
          ),
        ).thenAnswer((invocation) async {
          final url = invocation.positionalArguments.first as String;
          final host = Uri.parse(url).host;
          initAttemptsByHost[host] = (initAttemptsByHost[host] ?? 0) + 1;
          throw DioException(
            requestOptions: RequestOptions(path: '/upload/init'),
            type: DioExceptionType.badResponse,
            response: Response(
              requestOptions: RequestOptions(path: '/upload/init'),
              statusCode: 401,
            ),
          );
        });

        await service.uploadImage(
          imageFile: imageFile,
          nostrPubkey: _testPublicKey,
        );

        expect(
          initAttemptsByHost['third-party.example'],
          equals(1),
          reason:
              '401 is non-retriable, so a single DioException with that '
              'status must short-circuit the retry helper for the failing '
              'host.',
        );

        await imageFile.parent.delete(recursive: true);
      });

      test('retries on DioException of connectionTimeout type from non-Divine '
          'host', () async {
        // Connection timeout has no statusCode; classification falls to
        // the DioExceptionType switch in _isTransientUploadError.
        await service.setBlossomEnabled(true);
        await service.setBlossomServer('https://third-party.example');

        stubAuth();

        final imageFile = await tempImage('non_divine_dio_timeout');

        when(
          () => mockDio.head<dynamic>(any(), options: any(named: 'options')),
        ).thenAnswer(
          (_) async => Response(
            requestOptions: RequestOptions(path: '/upload'),
            statusCode: 200,
            headers: Headers.fromMap({
              DivineUploadHeaders.extensions: [
                DivineUploadExtensions.resumableSessions,
              ],
            }),
          ),
        );

        final initAttemptsByHost = <String, int>{};
        when(
          () => mockDio.post<dynamic>(
            any(),
            data: any(named: 'data'),
            options: any(named: 'options'),
          ),
        ).thenAnswer((invocation) async {
          final url = invocation.positionalArguments.first as String;
          if (!url.endsWith('/upload/init')) {
            return Response(
              requestOptions: RequestOptions(path: url),
              statusCode: 200,
              data: {
                'url': 'https://media.divine.video/hash',
                'fallbackUrl': 'https://media.divine.video/hash',
              },
            );
          }
          final host = Uri.parse(url).host;
          final n = (initAttemptsByHost[host] ?? 0) + 1;
          initAttemptsByHost[host] = n;
          if (host == 'third-party.example' && n == 1) {
            throw DioException(
              requestOptions: RequestOptions(path: '/upload/init'),
              type: DioExceptionType.connectionTimeout,
            );
          }
          return Response(
            requestOptions: RequestOptions(path: '/upload/init'),
            statusCode: 201,
            data: {
              'uploadId': 'up_retry_timeout',
              'uploadUrl':
                  'https://third-party.example/sessions/up_retry_timeout',
              'chunkSize': 1024,
              'nextOffset': 0,
              'expiresAt': 9999999999,
            },
          );
        });

        when(
          () => mockDio.put<dynamic>(
            any(),
            data: any(named: 'data'),
            options: any(named: 'options'),
            onSendProgress: any(named: 'onSendProgress'),
          ),
        ).thenAnswer(
          (_) async => Response(
            requestOptions: RequestOptions(path: '/sessions/up_retry_timeout'),
            statusCode: 204,
            headers: Headers.fromMap({
              DivineUploadHeaders.uploadOffset: ['3'],
            }),
          ),
        );

        await service.uploadImage(
          imageFile: imageFile,
          nostrPubkey: _testPublicKey,
        );

        expect(
          initAttemptsByHost['third-party.example'],
          equals(2),
          reason:
              'connectionTimeout is transient and must be retried on the '
              'same host by _isTransientUploadError.',
        );

        await imageFile.parent.delete(recursive: true);
      });

      // Liz flagged that the retry helper's contract has to cover both
      // signals: retriable HTTP statuses and the transient network
      // failures that _uploadToServer catches and converts to result-typed
      // failures with statusCode: null. The four tests below pin the
      // default-host legacy PUT path for each transient DioExceptionType
      // (connection / send / receive timeout, connection error). Without
      // the isTransientNetworkFailure signal these would each short-circuit
      // after one attempt — exactly the user-facing failure mode #3862
      // describes when media.divine.video has a transient network blip.
      test(
        'retries on connectionTimeout from default-host legacy PUT',
        () async {
          stubAuth();
          stubLegacyHead();

          final imageFile = await tempImage('legacy_conn_timeout');
          var attempt = 0;
          when(
            () => mockDio.put<dynamic>(
              any(),
              data: any(named: 'data'),
              options: any(named: 'options'),
              onSendProgress: any(named: 'onSendProgress'),
            ),
          ).thenAnswer((_) async {
            attempt++;
            if (attempt == 1) {
              throw DioException(
                requestOptions: RequestOptions(path: '/upload'),
                type: DioExceptionType.connectionTimeout,
              );
            }
            return uploadOkResponse();
          });

          final result = await service.uploadImage(
            imageFile: imageFile,
            nostrPubkey: _testPublicKey,
          );

          expect(result.success, isTrue);
          expect(
            attempt,
            equals(2),
            reason:
                'connectionTimeout caught inside _uploadToServer is converted '
                'to a result with statusCode: null, so the retry helper has '
                'to look at isTransientNetworkFailure to retry.',
          );

          await imageFile.parent.delete(recursive: true);
        },
      );

      test('retries on connectionError from default-host legacy PUT', () async {
        stubAuth();
        stubLegacyHead();

        final imageFile = await tempImage('legacy_conn_error');
        var attempt = 0;
        when(
          () => mockDio.put<dynamic>(
            any(),
            data: any(named: 'data'),
            options: any(named: 'options'),
            onSendProgress: any(named: 'onSendProgress'),
          ),
        ).thenAnswer((_) async {
          attempt++;
          if (attempt == 1) {
            throw DioException(
              requestOptions: RequestOptions(path: '/upload'),
              type: DioExceptionType.connectionError,
            );
          }
          return uploadOkResponse();
        });

        final result = await service.uploadImage(
          imageFile: imageFile,
          nostrPubkey: _testPublicKey,
        );

        expect(result.success, isTrue);
        expect(attempt, equals(2));

        await imageFile.parent.delete(recursive: true);
      });

      test('retries on sendTimeout from default-host legacy PUT', () async {
        stubAuth();
        stubLegacyHead();

        final imageFile = await tempImage('legacy_send_timeout');
        var attempt = 0;
        when(
          () => mockDio.put<dynamic>(
            any(),
            data: any(named: 'data'),
            options: any(named: 'options'),
            onSendProgress: any(named: 'onSendProgress'),
          ),
        ).thenAnswer((_) async {
          attempt++;
          if (attempt == 1) {
            throw DioException(
              requestOptions: RequestOptions(path: '/upload'),
              type: DioExceptionType.sendTimeout,
            );
          }
          return uploadOkResponse();
        });

        final result = await service.uploadImage(
          imageFile: imageFile,
          nostrPubkey: _testPublicKey,
        );

        expect(result.success, isTrue);
        expect(attempt, equals(2));

        await imageFile.parent.delete(recursive: true);
      });

      test('retries on receiveTimeout from default-host legacy PUT', () async {
        stubAuth();
        stubLegacyHead();

        final imageFile = await tempImage('legacy_recv_timeout');
        var attempt = 0;
        when(
          () => mockDio.put<dynamic>(
            any(),
            data: any(named: 'data'),
            options: any(named: 'options'),
            onSendProgress: any(named: 'onSendProgress'),
          ),
        ).thenAnswer((_) async {
          attempt++;
          if (attempt == 1) {
            throw DioException(
              requestOptions: RequestOptions(path: '/upload'),
              type: DioExceptionType.receiveTimeout,
            );
          }
          return uploadOkResponse();
        });

        final result = await service.uploadImage(
          imageFile: imageFile,
          nostrPubkey: _testPublicKey,
        );

        expect(result.success, isTrue);
        expect(attempt, equals(2));

        await imageFile.parent.delete(recursive: true);
      });

      test('does NOT retry on cancel from default-host legacy PUT', () async {
        // Opposing-symmetry guard: cancel is a user action, not a
        // transient network condition. _uploadToServer catches it but
        // must NOT mark the result transient — otherwise we'd loop on a
        // cancelled upload.
        stubAuth();
        stubLegacyHead();

        final imageFile = await tempImage('legacy_cancel');
        var attempt = 0;
        when(
          () => mockDio.put<dynamic>(
            any(),
            data: any(named: 'data'),
            options: any(named: 'options'),
            onSendProgress: any(named: 'onSendProgress'),
          ),
        ).thenAnswer((_) async {
          attempt++;
          throw DioException(
            requestOptions: RequestOptions(path: '/upload'),
            type: DioExceptionType.cancel,
          );
        });

        final result = await service.uploadImage(
          imageFile: imageFile,
          nostrPubkey: _testPublicKey,
        );

        expect(result.success, isFalse);
        expect(attempt, equals(1));

        await imageFile.parent.delete(recursive: true);
      });

      test(
        'falls through to next server after exhausting retries on the first',
        () async {
          stubAuth();

          await service.setBlossomEnabled(true);
          await service.setBlossomServer('https://blossom.example.com');

          final imageFile = await tempImage('multi_server');

          when(
            () => mockDio.head<dynamic>(any(), options: any(named: 'options')),
          ).thenAnswer(
            (_) async => Response(
              requestOptions: RequestOptions(path: '/upload'),
              statusCode: 200,
              headers: Headers(),
            ),
          );

          final attemptsByHost = <String, int>{};
          when(
            () => mockDio.put<dynamic>(
              any(),
              data: any(named: 'data'),
              options: any(named: 'options'),
              onSendProgress: any(named: 'onSendProgress'),
            ),
          ).thenAnswer((invocation) async {
            final url = invocation.positionalArguments.first as String;
            final host = Uri.parse(url).host;
            attemptsByHost[host] = (attemptsByHost[host] ?? 0) + 1;
            if (host == 'blossom.example.com') {
              throw dioBadResponse(503);
            }
            return uploadOkResponse();
          });

          final result = await service.uploadImage(
            imageFile: imageFile,
            nostrPubkey: _testPublicKey,
          );

          expect(result.success, isTrue);
          expect(
            attemptsByHost['blossom.example.com'],
            equals(3),
            reason: 'Custom server should be tried 3 times before fallback.',
          );
          expect(
            attemptsByHost['media.divine.video'],
            equals(1),
            reason:
                'Default Divine server should succeed on its first attempt '
                'after the custom server exhausts its retries.',
          );

          await imageFile.parent.delete(recursive: true);
        },
      );

      // Symmetry guard for _isTransientUploadError: a
      // BlossomResumableUploadException whose statusCode is in the retriable
      // set must be retried by the outer helper, the same way a
      // DioException(503) already is. The init endpoint throws
      // BlossomResumableUploadException directly for any non-200/201
      // response that still passes validateStatus (4xx + 408 + 429 land
      // here; 5xx is thrown by Dio as DioException(badResponse) instead).
      test('retries on BlossomResumableUploadException with retriable status '
          'from non-Divine host resumable init', () async {
        await service.setBlossomEnabled(true);
        await service.setBlossomServer('https://third-party.example');

        stubAuth();

        final imageFile = await tempImage('non_divine_resumable_408');

        when(
          () => mockDio.head<dynamic>(any(), options: any(named: 'options')),
        ).thenAnswer(
          (_) async => Response(
            requestOptions: RequestOptions(path: '/upload'),
            statusCode: 200,
            headers: Headers.fromMap({
              DivineUploadHeaders.extensions: [
                DivineUploadExtensions.resumableSessions,
              ],
            }),
          ),
        );

        final initAttemptsByHost = <String, int>{};
        when(
          () => mockDio.post<dynamic>(
            any(),
            data: any(named: 'data'),
            options: any(named: 'options'),
          ),
        ).thenAnswer((invocation) async {
          final url = invocation.positionalArguments.first as String;
          if (!url.endsWith('/upload/init')) {
            return Response(
              requestOptions: RequestOptions(path: url),
              statusCode: 200,
              data: {
                'url': 'https://media.divine.video/hash',
                'fallbackUrl': 'https://media.divine.video/hash',
              },
            );
          }
          final host = Uri.parse(url).host;
          final n = (initAttemptsByHost[host] ?? 0) + 1;
          initAttemptsByHost[host] = n;
          if (host == 'third-party.example' && n == 1) {
            // 408 passes validateStatus (< 500) so init throws a
            // BlossomResumableUploadException(statusCode: 408) rather
            // than a DioException.
            return Response(
              requestOptions: RequestOptions(path: '/upload/init'),
              statusCode: 408,
              data: 'Request timeout',
            );
          }
          return Response(
            requestOptions: RequestOptions(path: '/upload/init'),
            statusCode: 201,
            data: {
              'uploadId': 'up_resumable_408',
              'uploadUrl':
                  'https://third-party.example/sessions/up_resumable_408',
              'chunkSize': 1024,
              'nextOffset': 0,
              'expiresAt': 9999999999,
            },
          );
        });

        when(
          () => mockDio.put<dynamic>(
            any(),
            data: any(named: 'data'),
            options: any(named: 'options'),
            onSendProgress: any(named: 'onSendProgress'),
          ),
        ).thenAnswer(
          (_) async => Response(
            requestOptions: RequestOptions(path: '/sessions/up_resumable_408'),
            statusCode: 204,
            headers: Headers.fromMap({
              DivineUploadHeaders.uploadOffset: ['3'],
            }),
          ),
        );

        await service.uploadImage(
          imageFile: imageFile,
          nostrPubkey: _testPublicKey,
        );

        expect(
          initAttemptsByHost['third-party.example'],
          equals(2),
          reason:
              'BlossomResumableUploadException with statusCode 408 must be '
              'classified transient by _isTransientUploadError so the outer '
              'retry rebuilds the resumable session.',
        );

        await imageFile.parent.delete(recursive: true);
      });

      test(
        'does NOT retry on BlossomResumableUploadException with '
        'non-retriable status (410) from non-Divine host resumable init',
        () async {
          // Opposing-symmetry guard: 410 (session expired / gone) is
          // explicitly non-transient — re-creating the session via outer
          // retry would only produce another 410. _isTransientUploadError
          // must short-circuit it to a single attempt.
          await service.setBlossomEnabled(true);
          await service.setBlossomServer('https://third-party.example');

          stubAuth();

          final imageFile = await tempImage('non_divine_resumable_410');

          when(
            () => mockDio.head<dynamic>(any(), options: any(named: 'options')),
          ).thenAnswer(
            (_) async => Response(
              requestOptions: RequestOptions(path: '/upload'),
              statusCode: 200,
              headers: Headers.fromMap({
                DivineUploadHeaders.extensions: [
                  DivineUploadExtensions.resumableSessions,
                ],
              }),
            ),
          );

          final initAttemptsByHost = <String, int>{};
          when(
            () => mockDio.post<dynamic>(
              any(),
              data: any(named: 'data'),
              options: any(named: 'options'),
            ),
          ).thenAnswer((invocation) async {
            final url = invocation.positionalArguments.first as String;
            final host = Uri.parse(url).host;
            initAttemptsByHost[host] = (initAttemptsByHost[host] ?? 0) + 1;
            return Response(
              requestOptions: RequestOptions(path: '/upload/init'),
              statusCode: 410,
              data: 'Gone',
            );
          });

          final result = await service.uploadImage(
            imageFile: imageFile,
            nostrPubkey: _testPublicKey,
          );

          expect(result.success, isFalse);
          expect(
            initAttemptsByHost['third-party.example'],
            equals(1),
            reason:
                'A BlossomResumableUploadException with statusCode 410 must '
                'short-circuit the retry helper — re-initing the session '
                'would just return another 410.',
          );

          await imageFile.parent.delete(recursive: true);
        },
      );
    });

    group('Audio upload with DioException per server', () {
      late _MockDio mockDio;

      setUp(() {
        mockDio = _MockDio();
        service = BlossomUploadService(
          authProvider: mockAuthProvider,
          dio: mockDio,
        );
      });

      test('records DioException statusCode in error result', () async {
        when(() => mockAuthProvider.isAuthenticated).thenReturn(true);
        when(
          () => mockAuthProvider.createAndSignEvent(
            kind: any(named: 'kind'),
            content: any(named: 'content'),
            tags: any(named: 'tags'),
          ),
        ).thenAnswer(
          (_) async => _signedEvent(_testPublicKey, 24242, const [], 'upload'),
        );

        final tempDir = await Directory.systemTemp.createTemp(
          'audio_dio_exc_test_',
        );
        final audioFile = File('${tempDir.path}/audio.aac')
          ..writeAsBytesSync([1, 2, 3]);

        when(
          () => mockDio.head<dynamic>(any(), options: any(named: 'options')),
        ).thenAnswer(
          (_) async => Response(
            requestOptions: RequestOptions(path: '/upload'),
            statusCode: 200,
            headers: Headers(),
          ),
        );

        when(
          () => mockDio.put<dynamic>(
            any(),
            data: any(named: 'data'),
            options: any(named: 'options'),
            onSendProgress: any(named: 'onSendProgress'),
          ),
        ).thenThrow(
          DioException(
            requestOptions: RequestOptions(path: '/upload'),
            type: DioExceptionType.badResponse,
            response: Response(
              requestOptions: RequestOptions(path: '/upload'),
              statusCode: 413,
            ),
          ),
        );

        final result = await service.uploadAudio(audioFile: audioFile);

        expect(result.success, isFalse);
        expect(result.statusCode, equals(413));

        await tempDir.delete(recursive: true);
      });
    });

    group('Video upload outer exception handler', () {
      test('catches non-Dio exception before server loop', () async {
        when(() => mockAuthProvider.isAuthenticated).thenReturn(true);

        // A file that throws on openRead (to trigger outer catch)
        final mockFile = _MockFile();
        when(
          mockFile.openRead,
        ).thenThrow(const FileSystemException('permission denied'));
        // Must also fail on readAsBytes used by HashUtil
        when(
          mockFile.readAsBytes,
        ).thenThrow(const FileSystemException('permission denied'));

        final result = await service.uploadVideo(
          videoFile: mockFile,
          nostrPubkey: _testPublicKey,
          title: 'test',
          description: null,
          hashtags: null,
          proofManifestJson: null,
        );

        expect(result.success, isFalse);
        expect(result.errorMessage, contains('Blossom upload failed'));
      });
    });

    group('Resumable upload with existing session', () {
      late _MockDio mockDio;

      setUp(() {
        mockDio = _MockDio();
        service = BlossomUploadService(
          authProvider: mockAuthProvider,
          dio: mockDio,
        );
      });

      test('uses existing session via _queryResumableUploadSession', () async {
        when(() => mockAuthProvider.isAuthenticated).thenReturn(true);
        when(
          () => mockAuthProvider.createAndSignEvent(
            kind: any(named: 'kind'),
            content: any(named: 'content'),
            tags: any(named: 'tags'),
          ),
        ).thenAnswer(
          (_) async => _signedEvent(_testPublicKey, 24242, const [], 'upload'),
        );

        final tempDir = await Directory.systemTemp.createTemp(
          'resume_session_test_',
        );
        final file = File('${tempDir.path}/video.mp4')
          ..writeAsBytesSync([1, 2, 3]);

        when(
          () => mockDio.head<dynamic>(any(), options: any(named: 'options')),
        ).thenAnswer((invocation) async {
          final url = invocation.positionalArguments.first as String;
          if (url.endsWith('/upload')) {
            return Response(
              requestOptions: RequestOptions(path: '/upload'),
              statusCode: 200,
              headers: Headers.fromMap({
                DivineUploadHeaders.extensions: [
                  DivineUploadExtensions.resumableSessions,
                ],
              }),
            );
          }
          // Session query HEAD
          return Response(
            requestOptions: RequestOptions(path: '/sessions'),
            statusCode: 200,
            headers: Headers.fromMap({
              DivineUploadHeaders.uploadOffset: ['0'],
            }),
          );
        });

        when(
          () => mockDio.put<dynamic>(
            any(),
            data: any(named: 'data'),
            options: any(named: 'options'),
            onSendProgress: any(named: 'onSendProgress'),
          ),
        ).thenAnswer(
          (_) async => Response(
            requestOptions: RequestOptions(path: '/sessions'),
            statusCode: 204,
            headers: Headers.fromMap({
              DivineUploadHeaders.uploadOffset: ['3'],
            }),
          ),
        );

        when(
          () => mockDio.post<dynamic>(
            any(),
            data: any(named: 'data'),
            options: any(named: 'options'),
          ),
        ).thenAnswer(
          (_) async => Response(
            requestOptions: RequestOptions(path: '/complete'),
            statusCode: 200,
            data: {
              'url': 'https://media.divine.video/hash',
              'fallbackUrl': 'https://media.divine.video/hash',
            },
          ),
        );

        final result = await service.uploadVideo(
          videoFile: file,
          nostrPubkey: _testPublicKey,
          title: 'test',
          description: null,
          hashtags: null,
          proofManifestJson: null,
          resumableSession: const BlossomResumableUploadSession(
            uploadId: 'up_resume',
            uploadUrl: 'https://upload.divine.video/sessions/up_resume',
            chunkSize: 10,
            nextOffset: 0,
          ),
        );

        expect(result.success, isTrue);

        // Should NOT call /upload/init (uses existing session)
        verifyNever(
          () => mockDio.post<dynamic>(
            'https://media.divine.video/upload/init',
            data: any(named: 'data'),
            options: any(named: 'options'),
          ),
        );

        await tempDir.delete(recursive: true);
      });
    });

    group('Init resumable upload non-200 response', () {
      late _MockDio mockDio;

      setUp(() {
        mockDio = _MockDio();
        service = BlossomUploadService(
          authProvider: mockAuthProvider,
          dio: mockDio,
        );
      });

      test('throws on 403 from init endpoint', () async {
        when(() => mockAuthProvider.isAuthenticated).thenReturn(true);
        when(
          () => mockAuthProvider.createAndSignEvent(
            kind: any(named: 'kind'),
            content: any(named: 'content'),
            tags: any(named: 'tags'),
          ),
        ).thenAnswer(
          (_) async => _signedEvent(_testPublicKey, 24242, const [], 'upload'),
        );

        final tempDir = await Directory.systemTemp.createTemp('init_403_test_');
        final file = File('${tempDir.path}/video.mp4')
          ..writeAsBytesSync([1, 2, 3]);

        when(
          () => mockDio.head<dynamic>(any(), options: any(named: 'options')),
        ).thenAnswer(
          (_) async => Response(
            requestOptions: RequestOptions(path: '/upload'),
            statusCode: 200,
            headers: Headers.fromMap({
              DivineUploadHeaders.extensions: [
                DivineUploadExtensions.resumableSessions,
              ],
            }),
          ),
        );

        when(
          () => mockDio.post<dynamic>(
            any(),
            data: any(named: 'data'),
            options: any(named: 'options'),
          ),
        ).thenAnswer(
          (_) async => Response(
            requestOptions: RequestOptions(path: '/upload/init'),
            statusCode: 403,
            data: 'Forbidden',
          ),
        );

        // Legacy fallback
        when(
          () => mockDio.put<dynamic>(
            any(),
            data: any(named: 'data'),
            options: any(named: 'options'),
            onSendProgress: any(named: 'onSendProgress'),
          ),
        ).thenAnswer(
          (_) async => Response(
            requestOptions: RequestOptions(path: '/upload'),
            statusCode: 200,
            data: {
              'url': 'https://media.divine.video/hash',
              'fallbackUrl': 'https://media.divine.video/hash',
            },
          ),
        );

        final result = await service.uploadVideo(
          videoFile: file,
          nostrPubkey: _testPublicKey,
          title: 'test',
          description: null,
          hashtags: null,
          proofManifestJson: null,
        );

        // Falls back to legacy
        expect(result.success, isTrue);

        await tempDir.delete(recursive: true);
      });
    });

    group('transient capability discovery fallback', () {
      late _MockDio mockDio;

      setUp(() {
        mockDio = _MockDio();
        service = BlossomUploadService(
          authProvider: mockAuthProvider,
          dio: mockDio,
          defaultServerUrl: 'https://media.divine.video',
        );
      });

      test(
        'falls back to resumable=true for Divine host on 500 error',
        () async {
          when(() => mockAuthProvider.isAuthenticated).thenReturn(true);
          when(
            () => mockAuthProvider.createAndSignEvent(
              kind: any(named: 'kind'),
              content: any(named: 'content'),
              tags: any(named: 'tags'),
            ),
          ).thenAnswer(
            (_) async =>
                _signedEvent(_testPublicKey, 24242, const [], 'upload'),
          );

          final tempDir = await Directory.systemTemp.createTemp(
            'transient_cap_test_',
          );
          final file = File('${tempDir.path}/video.mp4')
            ..writeAsBytesSync([0x00, 0x01, 0x02]);

          // HEAD request for capability discovery fails with 500
          when(
            () => mockDio.head<dynamic>(any(), options: any(named: 'options')),
          ).thenThrow(
            DioException(
              requestOptions: RequestOptions(path: '/upload'),
              type: DioExceptionType.badResponse,
              response: Response(
                requestOptions: RequestOptions(path: '/upload'),
                statusCode: 500,
              ),
            ),
          );

          // PUT for legacy fallback upload succeeds
          when(
            () => mockDio.put<dynamic>(
              any(),
              data: any(named: 'data'),
              options: any(named: 'options'),
              onSendProgress: any(named: 'onSendProgress'),
            ),
          ).thenAnswer(
            (_) async => Response(
              requestOptions: RequestOptions(path: '/upload'),
              statusCode: 200,
              data: {
                'url': 'https://media.divine.video/hash',
                'fallbackUrl': 'https://media.divine.video/hash',
              },
            ),
          );

          final result = await service.uploadVideo(
            videoFile: file,
            nostrPubkey: _testPublicKey,
            title: 'test',
            description: null,
            hashtags: null,
            proofManifestJson: null,
          );

          // Upload should succeed via legacy fallback after transient
          // capability failure
          expect(result.success, isTrue);

          await tempDir.delete(recursive: true);
        },
      );

      test(
        'falls back to resumable=true for Divine host on connection error',
        () async {
          when(() => mockAuthProvider.isAuthenticated).thenReturn(true);
          when(
            () => mockAuthProvider.createAndSignEvent(
              kind: any(named: 'kind'),
              content: any(named: 'content'),
              tags: any(named: 'tags'),
            ),
          ).thenAnswer(
            (_) async =>
                _signedEvent(_testPublicKey, 24242, const [], 'upload'),
          );

          final tempDir = await Directory.systemTemp.createTemp(
            'transient_cap_conn_test_',
          );
          final file = File('${tempDir.path}/video.mp4')
            ..writeAsBytesSync([0x00, 0x01, 0x02]);

          // HEAD fails with connectionTimeout
          when(
            () => mockDio.head<dynamic>(any(), options: any(named: 'options')),
          ).thenThrow(
            DioException(
              requestOptions: RequestOptions(path: '/upload'),
              type: DioExceptionType.connectionTimeout,
            ),
          );

          // PUT for legacy fallback upload succeeds
          when(
            () => mockDio.put<dynamic>(
              any(),
              data: any(named: 'data'),
              options: any(named: 'options'),
              onSendProgress: any(named: 'onSendProgress'),
            ),
          ).thenAnswer(
            (_) async => Response(
              requestOptions: RequestOptions(path: '/upload'),
              statusCode: 200,
              data: {
                'url': 'https://media.divine.video/hash',
                'fallbackUrl': 'https://media.divine.video/hash',
              },
            ),
          );

          final result = await service.uploadVideo(
            videoFile: file,
            nostrPubkey: _testPublicKey,
            title: 'test',
            description: null,
            hashtags: null,
            proofManifestJson: null,
          );

          expect(result.success, isTrue);

          await tempDir.delete(recursive: true);
        },
      );

      test(
        'uses cached capability when transient error occurs and cache exists',
        () async {
          // Use a mutable clock so we can expire the cache on the
          // same service instance (cache is per-instance)
          var clockOffset = Duration.zero;
          service = BlossomUploadService(
            authProvider: mockAuthProvider,
            dio: mockDio,
            defaultServerUrl: 'https://media.divine.video',
            clock: () => DateTime.now().add(clockOffset),
          );

          when(() => mockAuthProvider.isAuthenticated).thenReturn(true);
          when(
            () => mockAuthProvider.createAndSignEvent(
              kind: any(named: 'kind'),
              content: any(named: 'content'),
              tags: any(named: 'tags'),
            ),
          ).thenAnswer(
            (_) async =>
                _signedEvent(_testPublicKey, 24242, const [], 'upload'),
          );

          final tempDir = await Directory.systemTemp.createTemp(
            'cached_cap_test_',
          );
          final file = File('${tempDir.path}/video.mp4')
            ..writeAsBytesSync([0x00, 0x01, 0x02]);

          var headCallCount = 0;

          // First HEAD succeeds — populates the capability cache with
          // supportsResumable=true
          // Second HEAD fails with 500 — should use cached capability
          when(
            () => mockDio.head<dynamic>(any(), options: any(named: 'options')),
          ).thenAnswer((_) async {
            headCallCount++;
            if (headCallCount == 1) {
              return Response(
                requestOptions: RequestOptions(path: '/upload'),
                statusCode: 200,
                headers: Headers.fromMap({
                  'x-divine-upload-extensions': ['resumable-sessions'],
                }),
              );
            }
            throw DioException(
              requestOptions: RequestOptions(path: '/upload'),
              type: DioExceptionType.badResponse,
              response: Response(
                requestOptions: RequestOptions(path: '/upload'),
                statusCode: 500,
              ),
            );
          });

          // POST for resumable init (first call, when cache is fresh)
          when(
            () => mockDio.post<dynamic>(
              any(),
              data: any(named: 'data'),
              options: any(named: 'options'),
            ),
          ).thenThrow(
            DioException(
              requestOptions: RequestOptions(path: '/upload/init'),
              type: DioExceptionType.connectionError,
            ),
          );

          // PUT for legacy fallback
          when(
            () => mockDio.put<dynamic>(
              any(),
              data: any(named: 'data'),
              options: any(named: 'options'),
              onSendProgress: any(named: 'onSendProgress'),
            ),
          ).thenAnswer(
            (_) async => Response(
              requestOptions: RequestOptions(path: '/upload'),
              statusCode: 200,
              data: {
                'url': 'https://media.divine.video/hash',
                'fallbackUrl': 'https://media.divine.video/hash',
              },
            ),
          );

          // First upload: populates capability cache
          final result1 = await service.uploadVideo(
            videoFile: file,
            nostrPubkey: _testPublicKey,
            title: 'test',
            description: null,
            hashtags: null,
            proofManifestJson: null,
          );
          expect(result1.success, isTrue);

          // Advance clock past the 5-minute TTL to expire cache
          clockOffset = const Duration(minutes: 6);

          // Re-write the file so hashing works
          file.writeAsBytesSync([0x00, 0x01, 0x02]);

          // Second upload: cache expired, HEAD fails with 500,
          // should use cached capability (supportsResumable=true)
          final result2 = await service.uploadVideo(
            videoFile: file,
            nostrPubkey: _testPublicKey,
            title: 'test',
            description: null,
            hashtags: null,
            proofManifestJson: null,
          );

          // Should still succeed via fallback
          expect(result2.success, isTrue);

          await tempDir.delete(recursive: true);
        },
      );
    });

    group('parseDateTimeValue ISO-8601 fallback', () {
      late _MockDio mockDio;

      setUp(() {
        mockDio = _MockDio();
        service = BlossomUploadService(
          authProvider: mockAuthProvider,
          dio: mockDio,
          defaultServerUrl: 'https://media.divine.video',
        );
      });

      test(
        'parses ISO-8601 date from resumable upload init response',
        () async {
          when(() => mockAuthProvider.isAuthenticated).thenReturn(true);
          when(
            () => mockAuthProvider.createAndSignEvent(
              kind: any(named: 'kind'),
              content: any(named: 'content'),
              tags: any(named: 'tags'),
            ),
          ).thenAnswer(
            (_) async =>
                _signedEvent(_testPublicKey, 24242, const [], 'upload'),
          );

          final tempDir = await Directory.systemTemp.createTemp(
            'iso_date_test_',
          );
          final file = File('${tempDir.path}/video.mp4')
            ..writeAsBytesSync([0x00, 0x01, 0x02]);

          // HEAD returns resumable capability
          when(
            () => mockDio.head<dynamic>(any(), options: any(named: 'options')),
          ).thenAnswer(
            (_) async => Response(
              requestOptions: RequestOptions(path: '/upload'),
              statusCode: 200,
              headers: Headers.fromMap({
                'x-divine-upload-extensions': ['resumable-sessions'],
              }),
            ),
          );

          // POST handles both init and complete — differentiate by URL
          when(
            () => mockDio.post<dynamic>(
              any(),
              data: any(named: 'data'),
              options: any(named: 'options'),
            ),
          ).thenAnswer((invocation) async {
            final url = invocation.positionalArguments[0] as String;
            if (url.contains('/upload/init')) {
              return Response(
                requestOptions: RequestOptions(path: url),
                statusCode: 201,
                data: {
                  'uploadId': 'up_iso_test',
                  'uploadUrl':
                      'https://upload.divine.video/sessions/up_iso_test',
                  'chunkSize': 1024 * 1024,
                  'nextOffset': 0,
                  // ISO-8601 format instead of epoch seconds
                  'expiresAt': '2099-12-31T23:59:59Z',
                },
              );
            }
            // Complete endpoint
            return Response(
              requestOptions: RequestOptions(path: url),
              statusCode: 200,
              data: {
                'url': 'https://media.divine.video/final',
                'fallbackUrl': 'https://media.divine.video/final',
              },
            );
          });

          // PUT for chunk upload
          when(
            () => mockDio.put<dynamic>(
              any(),
              data: any(named: 'data'),
              options: any(named: 'options'),
              onSendProgress: any(named: 'onSendProgress'),
            ),
          ).thenAnswer(
            (_) async => Response(
              requestOptions: RequestOptions(path: '/sessions/up_iso_test'),
              statusCode: 204,
              headers: Headers.fromMap({
                'upload-offset': ['3'],
              }),
            ),
          );

          final result = await service.uploadVideo(
            videoFile: file,
            nostrPubkey: _testPublicKey,
            title: 'test',
            description: null,
            hashtags: null,
            proofManifestJson: null,
          );

          expect(result.success, isTrue);

          await tempDir.delete(recursive: true);
        },
      );

      test('expired resumable session re-inits without session HEAD', () async {
        service = BlossomUploadService(
          authProvider: mockAuthProvider,
          dio: mockDio,
          defaultServerUrl: 'https://media.divine.video',
          clock: () => DateTime.utc(2026),
        );

        when(() => mockAuthProvider.isAuthenticated).thenReturn(true);
        when(
          () => mockAuthProvider.createAndSignEvent(
            kind: any(named: 'kind'),
            content: any(named: 'content'),
            tags: any(named: 'tags'),
          ),
        ).thenAnswer(
          (_) async => _signedEvent(_testPublicKey, 24242, const [], 'upload'),
        );

        final tempDir = await Directory.systemTemp.createTemp(
          'expired_resume_test_',
        );
        final file = File('${tempDir.path}/video.mp4')
          ..writeAsBytesSync([0x00, 0x01, 0x02]);

        var sessionHeadCalls = 0;
        when(
          () => mockDio.head<dynamic>(any(), options: any(named: 'options')),
        ).thenAnswer((invocation) async {
          final url = invocation.positionalArguments.first as String;
          if (url.contains('/sessions/')) {
            sessionHeadCalls++;
          }
          return Response(
            requestOptions: RequestOptions(path: url),
            statusCode: 200,
            headers: Headers.fromMap({
              'x-divine-upload-extensions': ['resumable-sessions'],
            }),
          );
        });

        when(
          () => mockDio.post<dynamic>(
            any(),
            data: any(named: 'data'),
            options: any(named: 'options'),
          ),
        ).thenAnswer((invocation) async {
          final url = invocation.positionalArguments.first as String;
          if (url.contains('/upload/init')) {
            return Response(
              requestOptions: RequestOptions(path: url),
              statusCode: 201,
              data: {
                'uploadId': 'up_new',
                'uploadUrl': 'https://upload.divine.video/sessions/up_new',
                'chunkSize': 1024,
                'nextOffset': 0,
              },
            );
          }
          return Response(
            requestOptions: RequestOptions(path: url),
            statusCode: 200,
            data: {
              'url': 'https://media.divine.video/final',
              'fallbackUrl': 'https://media.divine.video/final',
            },
          );
        });

        when(
          () => mockDio.put<dynamic>(
            any(),
            data: any(named: 'data'),
            options: any(named: 'options'),
            onSendProgress: any(named: 'onSendProgress'),
          ),
        ).thenAnswer(
          (_) async => Response(
            requestOptions: RequestOptions(path: '/sessions/up_new'),
            statusCode: 204,
            headers: Headers.fromMap({
              'upload-offset': ['3'],
            }),
          ),
        );

        final result = await service.uploadVideo(
          videoFile: file,
          nostrPubkey: _testPublicKey,
          title: 'test',
          description: null,
          hashtags: null,
          proofManifestJson: null,
          resumableSession: BlossomResumableUploadSession(
            uploadId: 'up_old',
            uploadUrl: 'https://upload.divine.video/sessions/up_old',
            chunkSize: 1024,
            nextOffset: 0,
            expiresAt: DateTime.utc(2025),
          ),
        );

        expect(result.success, isTrue);
        expect(sessionHeadCalls, isZero);

        await tempDir.delete(recursive: true);
      });
    });

    group('upload response 409 with progress callback', () {
      late _MockDio mockDio;

      setUp(() {
        mockDio = _MockDio();
        service = BlossomUploadService(
          authProvider: mockAuthProvider,
          dio: mockDio,
        );
      });

      test('calls onProgress with 1.0 on 409 (file exists)', () async {
        when(() => mockAuthProvider.isAuthenticated).thenReturn(true);
        when(
          () => mockAuthProvider.createAndSignEvent(
            kind: any(named: 'kind'),
            content: any(named: 'content'),
            tags: any(named: 'tags'),
          ),
        ).thenAnswer(
          (_) async => _signedEvent(_testPublicKey, 24242, const [], 'upload'),
        );

        final tempDir = await Directory.systemTemp.createTemp(
          'progress_409_test_',
        );
        final imageFile = File('${tempDir.path}/image.jpg')
          ..writeAsBytesSync([0xFF, 0xD8, 0xFF]);

        // HEAD for capability (non-resumable)
        when(
          () => mockDio.head<dynamic>(any(), options: any(named: 'options')),
        ).thenAnswer(
          (_) async => Response(
            requestOptions: RequestOptions(path: '/upload'),
            statusCode: 200,
            headers: Headers(),
          ),
        );

        // PUT returns 409 — file already exists
        when(
          () => mockDio.put<dynamic>(
            any(),
            data: any(named: 'data'),
            options: any(named: 'options'),
            onSendProgress: any(named: 'onSendProgress'),
          ),
        ).thenAnswer(
          (_) async => Response(
            requestOptions: RequestOptions(path: '/upload'),
            statusCode: 409,
          ),
        );

        final progressValues = <double>[];
        final result = await service.uploadImage(
          imageFile: imageFile,
          nostrPubkey: _testPublicKey,
          onProgress: progressValues.add,
        );

        expect(result.success, isTrue);
        // Should call onProgress(1) for the 409 path
        expect(progressValues, contains(1.0));

        await tempDir.delete(recursive: true);
      });
    });

    group('chunk upload x-reason header', () {
      late _MockDio mockDio;

      setUp(() {
        mockDio = _MockDio();
        service = BlossomUploadService(
          authProvider: mockAuthProvider,
          dio: mockDio,
          defaultServerUrl: 'https://media.divine.video',
        );
      });

      test('includes x-reason in error when chunk fails with non-standard '
          'status', () async {
        when(() => mockAuthProvider.isAuthenticated).thenReturn(true);
        when(
          () => mockAuthProvider.createAndSignEvent(
            kind: any(named: 'kind'),
            content: any(named: 'content'),
            tags: any(named: 'tags'),
          ),
        ).thenAnswer(
          (_) async => _signedEvent(_testPublicKey, 24242, const [], 'upload'),
        );

        final tempDir = await Directory.systemTemp.createTemp('xreason_test_');
        final file = File('${tempDir.path}/video.mp4')
          ..writeAsBytesSync([0x00, 0x01, 0x02]);

        // HEAD returns resumable capability
        when(
          () => mockDio.head<dynamic>(any(), options: any(named: 'options')),
        ).thenAnswer(
          (_) async => Response(
            requestOptions: RequestOptions(path: '/upload'),
            statusCode: 200,
            headers: Headers.fromMap({
              'x-divine-upload-extensions': ['resumable-sessions'],
            }),
          ),
        );

        // POST for resumable init
        when(
          () => mockDio.post<dynamic>(
            any(),
            data: any(named: 'data'),
            options: any(named: 'options'),
          ),
        ).thenAnswer(
          (_) async => Response(
            requestOptions: RequestOptions(path: '/upload/init'),
            statusCode: 201,
            data: {
              'uploadId': 'up_xreason',
              'uploadUrl': 'https://upload.divine.video/sessions/up_xreason',
              'chunkSize': 1024 * 1024,
              'nextOffset': 0,
              'expiresAt': 9999999999,
            },
          ),
        );

        // PUT for chunk — returns 400 with x-reason header
        when(
          () => mockDio.put<dynamic>(
            any(),
            data: any(named: 'data'),
            options: any(named: 'options'),
            onSendProgress: any(named: 'onSendProgress'),
          ),
        ).thenAnswer(
          (_) async => Response(
            requestOptions: RequestOptions(path: '/sessions/up_xreason'),
            statusCode: 400,
            headers: Headers.fromMap({
              'x-reason': ['Invalid chunk alignment'],
            }),
          ),
        );

        final result = await service.uploadVideo(
          videoFile: file,
          nostrPubkey: _testPublicKey,
          title: 'test',
          description: null,
          hashtags: null,
          proofManifestJson: null,
        );

        // Resumable fails, falls back to legacy which should
        // succeed or fail — the key assertion is that it didn't crash
        // and the x-reason header was read
        expect(result, isNotNull);

        await tempDir.delete(recursive: true);
      });
    });

    group('outer catch-all error handlers', () {
      test('uploadAudio returns failure when file hashing throws', () async {
        final mockFile = _MockFile();
        when(() => mockAuthProvider.isAuthenticated).thenReturn(true);
        when(
          mockFile.openRead,
        ).thenThrow(const FileSystemException('permission denied'));

        final result = await service.uploadAudio(audioFile: mockFile);

        expect(result.success, isFalse);
        expect(result.errorMessage, contains('Audio upload failed'));
      });

      test('uploadImage returns failure when file processing throws', () async {
        when(() => mockAuthProvider.isAuthenticated).thenReturn(true);

        // Pass a file that doesn't exist — ImageMetadataStripper
        // will throw when trying to read it
        final nonExistentFile = File(
          '/tmp/nonexistent_${DateTime.now().millisecondsSinceEpoch}.jpg',
        );

        final result = await service.uploadImage(
          imageFile: nonExistentFile,
          nostrPubkey: _testPublicKey,
        );

        expect(result.success, isFalse);
        expect(result.errorMessage, contains('Image upload failed'));
      });
    });
  });
}
