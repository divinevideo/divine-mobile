// ABOUTME: Tests for DmVideoDecryptor: fetch ciphertext, decrypt, produce a clip.
// ABOUTME: Uses a mocked Dio returning real AES-GCM ciphertext so decrypt is real.

import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nostr_sdk/nip17/file_encryption.dart';
import 'package:openvine/services/dm_video_decryptor.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

import '../mocks/mock_path_provider_platform.dart';

class _MockDio extends Mock implements Dio {}

const _videoUrl = 'https://media.divine.video/testciphertexthash';
const _clipFileName = 'received.mp4';

void main() {
  group(DmVideoDecryptor, () {
    late _MockDio dio;
    late Directory tempDir;
    late PathProviderPlatform originalPathProvider;

    setUpAll(() {
      registerFallbackValue(Options());
      registerFallbackValue('');
    });

    setUp(() {
      dio = _MockDio();
      when(() => dio.options).thenReturn(BaseOptions());
      tempDir = Directory.systemTemp.createTempSync('dm_video_decryptor_');
      originalPathProvider = PathProviderPlatform.instance;
      PathProviderPlatform.instance = MockPathProviderPlatform()
        ..setTemporaryPath(tempDir.path);
    });

    tearDown(() {
      PathProviderPlatform.instance = originalPathProvider;
      if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
    });

    String clipPath() => '${tempDir.path}/divine_player_memory/$_clipFileName';

    void stubDownload(Uint8List ciphertext) {
      when(
        () => dio.get<List<int>>(
          _videoUrl,
          options: any(named: 'options'),
        ),
      ).thenAnswer(
        (_) async => Response<List<int>>(
          requestOptions: RequestOptions(path: _videoUrl),
          statusCode: 200,
          data: ciphertext.toList(),
        ),
      );
    }

    test(
      'downloads ciphertext, decrypts it, and returns a clip over the '
      'decrypted bytes',
      () async {
        final plaintext = Uint8List.fromList(
          List<int>.generate(256, (index) => index % 251),
        );
        final encrypted = await FileEncryption().encrypt(plaintext);
        stubDownload(encrypted.ciphertext);

        final clip = await DmVideoDecryptor(dio: dio).materialize(
          url: _videoUrl,
          key: encrypted.key,
          nonce: encrypted.nonce,
          fileName: _clipFileName,
        );

        expect(clip.uri, equals(clipPath()));
        expect(File(clip.uri).readAsBytesSync(), equals(plaintext));

        final options =
            verify(
                  () => dio.get<List<int>>(
                    _videoUrl,
                    options: captureAny(named: 'options'),
                  ),
                ).captured.single
                as Options;
        expect(options.responseType, ResponseType.bytes);
      },
    );

    test('configures finite connect and receive timeouts on the client', () {
      DmVideoDecryptor(dio: dio);

      expect(dio.options.connectTimeout, isNotNull);
      expect(dio.options.receiveTimeout, isNotNull);
    });

    test('rejects a non-HTTPS url before making any request', () async {
      await expectLater(
        DmVideoDecryptor(dio: dio).materialize(
          url: 'http://127.0.0.1/secret',
          key: '00' * 32,
          nonce: '00' * 12,
          fileName: _clipFileName,
        ),
        throwsA(isA<ArgumentError>()),
      );

      verifyNever(
        () => dio.get<List<int>>(any(), options: any(named: 'options')),
      );
      expect(File(clipPath()).existsSync(), isFalse);
    });

    test('surfaces a download timeout as an error', () async {
      when(
        () => dio.get<List<int>>(_videoUrl, options: any(named: 'options')),
      ).thenThrow(
        DioException(
          requestOptions: RequestOptions(path: _videoUrl),
          type: DioExceptionType.receiveTimeout,
        ),
      );

      await expectLater(
        DmVideoDecryptor(dio: dio).materialize(
          url: _videoUrl,
          key: '00' * 32,
          nonce: '00' * 12,
          fileName: _clipFileName,
        ),
        throwsA(
          isA<DioException>().having(
            (e) => e.type,
            'type',
            DioExceptionType.receiveTimeout,
          ),
        ),
      );
      expect(File(clipPath()).existsSync(), isFalse);
    });

    test(
      'propagates a decryption failure and writes no plaintext file',
      () async {
        final produced = await FileEncryption().encrypt(
          Uint8List.fromList([1, 2, 3, 4, 5]),
        );
        stubDownload(produced.ciphertext);

        await expectLater(
          DmVideoDecryptor(dio: dio).materialize(
            url: _videoUrl,
            key: '00' * 32,
            nonce: produced.nonce,
            fileName: _clipFileName,
          ),
          throwsA(isA<Exception>()),
        );
        expect(File(clipPath()).existsSync(), isFalse);
      },
    );

    test('propagates an HTTP failure and writes no plaintext file', () async {
      when(
        () => dio.get<List<int>>(_videoUrl, options: any(named: 'options')),
      ).thenThrow(
        DioException(
          requestOptions: RequestOptions(path: _videoUrl),
          type: DioExceptionType.badResponse,
          response: Response<void>(
            requestOptions: RequestOptions(path: _videoUrl),
            statusCode: 404,
          ),
        ),
      );

      await expectLater(
        DmVideoDecryptor(dio: dio).materialize(
          url: _videoUrl,
          key: '00' * 32,
          nonce: '00' * 12,
          fileName: _clipFileName,
        ),
        throwsA(isA<DioException>()),
      );
      expect(File(clipPath()).existsSync(), isFalse);
    });
  });
}
