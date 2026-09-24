// ABOUTME: Tests for DmVideoDecryptor: fetch ciphertext, verify, decrypt to a clip.
// ABOUTME: Uses a mocked Dio returning real AES-GCM ciphertext so decrypt is real.

import 'dart:io';
import 'dart:typed_data';

import 'package:blossom_upload_service/blossom_upload_service.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:nostr_sdk/nip17/file_encryption.dart';
import 'package:openvine/services/dm_video_decryptor.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

import '../mocks/mock_path_provider_platform.dart';

class _MockDio extends Mock implements Dio {}

const _videoUrl = 'https://media.divine.video/testciphertexthash';
final String _messageId = 'a' * 64;

DmMessage _videoMessage({
  required String fileHash,
  String? key,
  String? nonce,
  String url = _videoUrl,
  String fileType = 'video/mp4',
}) => DmMessage(
  id: _messageId,
  conversationId: 'conversation',
  senderPubkey: 'b' * 64,
  content: url,
  createdAt: 1757385263,
  giftWrapId: 'c' * 64,
  messageKind: 15,
  fileMetadata: DmFileMetadata(
    fileType: fileType,
    encryptionAlgorithm: 'aes-gcm',
    decryptionKey: key ?? '00' * 32,
    decryptionNonce: nonce ?? '00' * 12,
    fileHash: fileHash,
  ),
);

void main() {
  group(DmVideoDecryptor, () {
    late _MockDio dio;
    late Directory tempDir;
    late PathProviderPlatform originalPathProvider;

    setUpAll(() {
      registerFallbackValue(Options());
      registerFallbackValue(CancelToken());
      registerFallbackValue((int received, int total) {});
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

    String clipPath(DmMessage message) =>
        '${tempDir.path}/${DmVideoDecryptor.playbackDirName}/'
        '${DmVideoDecryptor.clipFileNameFor(message)}';

    void stubDownload(Uint8List ciphertext) {
      when(
        () => dio.get<List<int>>(
          _videoUrl,
          options: any(named: 'options'),
          cancelToken: any(named: 'cancelToken'),
          onReceiveProgress: any(named: 'onReceiveProgress'),
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
      'downloads ciphertext, verifies it, and writes the decrypted bytes to a '
      'clip',
      () async {
        final plaintext = Uint8List.fromList(
          List<int>.generate(256, (index) => index % 251),
        );
        final encrypted = await FileEncryption().encrypt(plaintext);
        stubDownload(encrypted.ciphertext);
        final message = _videoMessage(
          fileHash: HashUtil.sha256Hash(encrypted.ciphertext),
          key: encrypted.key,
          nonce: encrypted.nonce,
        );

        final path = await DmVideoDecryptor(dio: dio).decryptToFile(message);

        expect(path, equals(clipPath(message)));
        expect(File(path).readAsBytesSync(), equals(plaintext));

        final options =
            verify(
                  () => dio.get<List<int>>(
                    _videoUrl,
                    options: captureAny(named: 'options'),
                    cancelToken: any(named: 'cancelToken'),
                    onReceiveProgress: any(named: 'onReceiveProgress'),
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
      final message = _videoMessage(
        fileHash: 'ab' * 32,
        url: 'http://127.0.0.1/secret',
      );

      await expectLater(
        DmVideoDecryptor(dio: dio).decryptToFile(message),
        throwsA(isA<ArgumentError>()),
      );

      verifyNever(
        () => dio.get<List<int>>(
          any(),
          options: any(named: 'options'),
          cancelToken: any(named: 'cancelToken'),
          onReceiveProgress: any(named: 'onReceiveProgress'),
        ),
      );
      expect(File(clipPath(message)).existsSync(), isFalse);
    });

    test('rejects a non-video message before making any request', () async {
      final message = _videoMessage(
        fileHash: 'ab' * 32,
        fileType: 'image/jpeg',
      );

      await expectLater(
        DmVideoDecryptor(dio: dio).decryptToFile(message),
        throwsA(isA<DmVideoUnavailableException>()),
      );

      verifyNever(
        () => dio.get<List<int>>(
          any(),
          options: any(named: 'options'),
          cancelToken: any(named: 'cancelToken'),
          onReceiveProgress: any(named: 'onReceiveProgress'),
        ),
      );
    });

    test('surfaces a download timeout as an error', () async {
      when(
        () => dio.get<List<int>>(
          _videoUrl,
          options: any(named: 'options'),
          cancelToken: any(named: 'cancelToken'),
          onReceiveProgress: any(named: 'onReceiveProgress'),
        ),
      ).thenThrow(
        DioException(
          requestOptions: RequestOptions(path: _videoUrl),
          type: DioExceptionType.receiveTimeout,
        ),
      );

      final message = _videoMessage(fileHash: 'ab' * 32);
      await expectLater(
        DmVideoDecryptor(dio: dio).decryptToFile(message),
        throwsA(
          isA<DioException>().having(
            (e) => e.type,
            'type',
            DioExceptionType.receiveTimeout,
          ),
        ),
      );
      expect(File(clipPath(message)).existsSync(), isFalse);
    });

    test('rejects ciphertext whose hash does not match the x tag', () async {
      final produced = await FileEncryption().encrypt(
        Uint8List.fromList([1, 2, 3, 4, 5]),
      );
      stubDownload(produced.ciphertext);
      final message = _videoMessage(
        fileHash: 'ab' * 32,
        key: produced.key,
        nonce: produced.nonce,
      );

      await expectLater(
        DmVideoDecryptor(dio: dio).decryptToFile(message),
        throwsA(isA<DmVideoUnavailableException>()),
      );
      expect(File(clipPath(message)).existsSync(), isFalse);
    });

    test(
      'propagates a decryption failure and writes no plaintext file',
      () async {
        final produced = await FileEncryption().encrypt(
          Uint8List.fromList([1, 2, 3, 4, 5]),
        );
        stubDownload(produced.ciphertext);
        final message = _videoMessage(
          fileHash: HashUtil.sha256Hash(produced.ciphertext),
          key: produced.key,
          nonce: '00' * 12,
        );

        await expectLater(
          DmVideoDecryptor(dio: dio).decryptToFile(message),
          throwsA(isA<Exception>()),
        );
        expect(File(clipPath(message)).existsSync(), isFalse);
      },
    );

    test('propagates an HTTP failure and writes no plaintext file', () async {
      when(
        () => dio.get<List<int>>(
          _videoUrl,
          options: any(named: 'options'),
          cancelToken: any(named: 'cancelToken'),
          onReceiveProgress: any(named: 'onReceiveProgress'),
        ),
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

      final message = _videoMessage(fileHash: 'ab' * 32);
      await expectLater(
        DmVideoDecryptor(dio: dio).decryptToFile(message),
        throwsA(isA<DioException>()),
      );
      expect(File(clipPath(message)).existsSync(), isFalse);
    });

    test('deleteClip removes an existing clip and tolerates a missing one', () {
      final path = '${tempDir.path}/${DmVideoDecryptor.playbackDirName}/clip';
      final file = File(path)
        ..createSync(recursive: true)
        ..writeAsBytesSync(const [1]);
      final decryptor = DmVideoDecryptor(dio: dio);

      decryptor.deleteClip(path);
      expect(file.existsSync(), isFalse);

      // Deleting again is a no-op rather than a throw.
      decryptor.deleteClip(path);
    });
  });
}
