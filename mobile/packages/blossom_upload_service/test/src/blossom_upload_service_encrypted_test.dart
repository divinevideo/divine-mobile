// ABOUTME: Tests for BlossomUploadService.uploadEncryptedFile verifying the
// ABOUTME: ciphertext is uploaded as octet-stream with t=upload / x auth tags.

import 'dart:convert';
import 'dart:io';

import 'package:blossom_upload_service/blossom_upload_service.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockAuthProvider extends Mock implements BlossomAuthProvider {}

class _MockDio extends Mock implements Dio {}

class _MockResponse extends Mock implements Response<dynamic> {}

const _testPublicKey =
    '0223456789abcdef0123456789abcdef0123456789abcdef'
    '0123456789abcdef';

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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    registerFallbackValue(Options());
  });

  group(BlossomUploadService, () {
    late _MockAuthProvider mockAuthProvider;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      mockAuthProvider = _MockAuthProvider();
    });

    group('uploadEncryptedFile', () {
      test(
        'uploads ciphertext as octet-stream with t=upload / x auth tags',
        () async {
          final mockDio = _MockDio();
          final file = File('${Directory.systemTemp.path}/ct.bin');
          final bytes = List<int>.filled(32, 7);
          await file.writeAsBytes(bytes);
          addTearDown(() async {
            if (file.existsSync()) await file.delete();
          });
          final ctHash = HashUtil.sha256Hash(bytes);

          when(() => mockAuthProvider.isAuthenticated).thenReturn(true);
          when(
            () => mockAuthProvider.createAndSignEvent(
              kind: any(named: 'kind'),
              content: any(named: 'content'),
              tags: any(named: 'tags'),
            ),
          ).thenAnswer((invocation) async {
            return _signedEvent(
              _testPublicKey,
              invocation.namedArguments[#kind] as int,
              invocation.namedArguments[#tags] as List<List<String>>,
              invocation.namedArguments[#content] as String,
            );
          });

          final mockResponse = _MockResponse();
          when(() => mockResponse.statusCode).thenReturn(201);
          when(() => mockResponse.data).thenReturn(<String, dynamic>{
            'url': 'https://media.divine.video/$ctHash',
            'sha256': ctHash,
          });
          when(
            () => mockDio.put<dynamic>(
              'https://media.divine.video/upload',
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

          final result = await service.uploadEncryptedFile(
            ciphertextFile: file,
            onProgress: progress.add,
          );

          expect(result.success, isTrue);
          expect(result.videoId, equals(ctHash));
          expect(result.url, equals('https://media.divine.video/$ctHash'));
          expect(progress, contains(0.1));

          final options =
              verify(
                    () => mockDio.put<dynamic>(
                      'https://media.divine.video/upload',
                      data: any(named: 'data'),
                      options: captureAny(named: 'options'),
                      onSendProgress: any(named: 'onSendProgress'),
                    ),
                  ).captured.single
                  as Options;
          expect(
            options.headers!['Content-Type'],
            equals('application/octet-stream'),
          );

          final authHeader = options.headers!['Authorization'] as String;
          final event =
              jsonDecode(
                    utf8.decode(
                      base64.decode(authHeader.substring('Nostr '.length)),
                    ),
                  )
                  as Map<String, dynamic>;
          expect(event['kind'], equals(24242));
          final tags = (event['tags'] as List).cast<List<dynamic>>();
          expect(tags, contains(equals(['t', 'upload'])));
          expect(tags, contains(equals(['x', ctHash])));
        },
      );

      test('returns a permanent auth failure when not authenticated', () async {
        when(() => mockAuthProvider.isAuthenticated).thenReturn(false);
        final service = BlossomUploadService(authProvider: mockAuthProvider);

        final result = await service.uploadEncryptedFile(
          ciphertextFile: File('${Directory.systemTemp.path}/unused.bin'),
        );

        expect(result.success, isFalse);
        expect(result.failureReason, equals(BlossomUploadFailureReason.auth));
      });

      test(
        'returns the server failure when the ciphertext PUT is rejected',
        () async {
          final mockDio = _MockDio();
          final file = File('${Directory.systemTemp.path}/ct-rejected.bin');
          await file.writeAsBytes(List<int>.filled(16, 3));
          addTearDown(() async {
            if (file.existsSync()) await file.delete();
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

          final mockResponse = _MockResponse();
          when(() => mockResponse.statusCode).thenReturn(400);
          when(() => mockResponse.headers).thenReturn(Headers());
          when(
            () => mockResponse.data,
          ).thenReturn(<String, dynamic>{'message': 'bad ciphertext'});
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

          final result = await service.uploadEncryptedFile(
            ciphertextFile: file,
          );

          expect(result.success, isFalse);
          expect(result.statusCode, equals(400));
          expect(
            result.failureReason,
            equals(BlossomUploadFailureReason.unknown),
          );
        },
      );

      test('returns an unknown failure when setup throws', () async {
        when(
          () => mockAuthProvider.isAuthenticated,
        ).thenThrow(StateError('auth state unavailable'));
        final service = BlossomUploadService(authProvider: mockAuthProvider);

        final result = await service.uploadEncryptedFile(
          ciphertextFile: File('${Directory.systemTemp.path}/unused.bin'),
        );

        expect(result.success, isFalse);
        expect(
          result.errorMessage,
          contains('Encrypted file upload failed'),
        );
        expect(
          result.failureReason,
          equals(BlossomUploadFailureReason.unknown),
        );
      });
    });
  });
}
