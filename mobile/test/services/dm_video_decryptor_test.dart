// ABOUTME: Tests for DmVideoDecryptor: fetch ciphertext, verify, decrypt to bytes.
// ABOUTME: Uses a mocked Dio returning real AES-GCM ciphertext so decrypt is real.

import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:blossom_upload_service/blossom_upload_service.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:nostr_sdk/nip17/file_encryption.dart';
import 'package:openvine/services/dm_video_decryptor.dart';

class _MockDio extends Mock implements Dio {}

/// Decrypts to the name of the isolate it ran in.
class _IsolateNamingEncryption extends FileEncryption {
  @override
  Future<Uint8List> decrypt({
    required Uint8List ciphertext,
    required String hexKey,
    required String hexNonce,
  }) async => Uint8List.fromList(utf8.encode(Isolate.current.debugName ?? ''));
}

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

    setUpAll(() {
      registerFallbackValue(Options());
      registerFallbackValue(CancelToken());
      registerFallbackValue((int received, int total) {});
      registerFallbackValue('');
    });

    setUp(() {
      dio = _MockDio();
      when(() => dio.options).thenReturn(BaseOptions());
    });

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
      'downloads ciphertext, verifies it, and returns the decrypted bytes',
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

        final decrypted = await DmVideoDecryptor(dio: dio).decrypt(message);

        expect(decrypted, equals(plaintext));

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

    test(
      'checks and decrypts off the calling isolate, so a long video cannot '
      'freeze the UI',
      () async {
        stubDownload(Uint8List.fromList(const [1, 2, 3]));

        final decrypted = await DmVideoDecryptor(
          dio: dio,
          encryption: _IsolateNamingEncryption(),
        ).decrypt(_videoMessage(fileHash: ''));

        expect(utf8.decode(decrypted), isNot(Isolate.current.debugName));
      },
    );

    test('configures finite connect and receive timeouts on the client', () {
      DmVideoDecryptor(dio: dio);

      expect(dio.options.connectTimeout, isNotNull);
      expect(dio.options.receiveTimeout, isNotNull);
    });

    test(
      'rejects a non-HTTPS url before any request, without naming it',
      () async {
        final message = _videoMessage(
          fileHash: 'ab' * 32,
          url: 'http://127.0.0.1/secret',
        );

        await expectLater(
          DmVideoDecryptor(dio: dio).decrypt(message),
          throwsA(
            isA<DmVideoUnavailableException>().having(
              (error) => error.toString(),
              'description',
              isNot(contains('127.0.0.1')),
            ),
          ),
        );

        verifyNever(
          () => dio.get<List<int>>(
            any(),
            options: any(named: 'options'),
            cancelToken: any(named: 'cancelToken'),
            onReceiveProgress: any(named: 'onReceiveProgress'),
          ),
        );
      },
    );

    test(
      'refuses a key of the wrong size before any request, without naming it',
      () async {
        final shortKey = '0f' * 16;
        final message = _videoMessage(fileHash: 'ab' * 32, key: shortKey);

        await expectLater(
          DmVideoDecryptor(dio: dio).decrypt(message),
          throwsA(
            isA<DmVideoUnavailableException>().having(
              (error) => error.toString(),
              'description',
              isNot(contains(shortKey)),
            ),
          ),
        );
        verifyNever(
          () => dio.get<List<int>>(
            any(),
            options: any(named: 'options'),
            cancelToken: any(named: 'cancelToken'),
            onReceiveProgress: any(named: 'onReceiveProgress'),
          ),
        );
      },
    );

    test(
      'refuses a nonce of the wrong size before any request, without naming '
      'it',
      () async {
        final shortNonce = '0e' * 16;
        final message = _videoMessage(fileHash: 'ab' * 32, nonce: shortNonce);

        await expectLater(
          DmVideoDecryptor(dio: dio).decrypt(message),
          throwsA(
            isA<DmVideoUnavailableException>().having(
              (error) => error.toString(),
              'description',
              isNot(contains(shortNonce)),
            ),
          ),
        );
        verifyNever(
          () => dio.get<List<int>>(
            any(),
            options: any(named: 'options'),
            cancelToken: any(named: 'cancelToken'),
            onReceiveProgress: any(named: 'onReceiveProgress'),
          ),
        );
      },
    );

    test('rejects a non-video message before making any request', () async {
      final message = _videoMessage(
        fileHash: 'ab' * 32,
        fileType: 'image/jpeg',
      );

      await expectLater(
        DmVideoDecryptor(dio: dio).decrypt(message),
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

    test(
      'reports a dropped download by its kind, never by its address',
      () async {
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
            type: DioExceptionType.unknown,
            error: HttpException(
              'Connection closed while receiving data',
              uri: Uri.parse(_videoUrl),
            ),
          ),
        );

        final message = _videoMessage(fileHash: 'ab' * 32);
        await expectLater(
          DmVideoDecryptor(dio: dio).decrypt(message),
          throwsA(
            isA<DmVideoUnavailableException>().having(
              (error) => error.toString(),
              'description',
              allOf(
                contains(DioExceptionType.unknown.name),
                isNot(contains('media.divine.video')),
              ),
            ),
          ),
        );
      },
    );

    test('refuses a download past a smaller size limit', () async {
      final produced = await FileEncryption().encrypt(
        Uint8List.fromList(List<int>.filled(64, 7)),
      );
      stubDownload(produced.ciphertext);
      final message = _videoMessage(
        fileHash: HashUtil.sha256Hash(produced.ciphertext),
        key: produced.key,
        nonce: produced.nonce,
      );

      await expectLater(
        DmVideoDecryptor(dio: dio).decrypt(message, maxBytes: 16),
        throwsA(isA<DmVideoUnavailableException>()),
      );
    });

    test('gives up on a download past its time limit', () async {
      when(
        () => dio.get<List<int>>(
          _videoUrl,
          options: any(named: 'options'),
          cancelToken: any(named: 'cancelToken'),
          onReceiveProgress: any(named: 'onReceiveProgress'),
        ),
      ).thenAnswer((invocation) async {
        final token = invocation.namedArguments[#cancelToken] as CancelToken;
        throw await token.whenCancel;
      });

      await expectLater(
        DmVideoDecryptor(dio: dio).decrypt(
          _videoMessage(fileHash: 'ab' * 32),
          timeLimit: const Duration(milliseconds: 20),
        ),
        throwsA(
          isA<DmVideoUnavailableException>().having(
            (e) => e.message,
            'message',
            contains('time'),
          ),
        ),
      );
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
        DmVideoDecryptor(dio: dio).decrypt(message),
        throwsA(isA<DmVideoUnavailableException>()),
      );
    });

    test(
      'propagates a decryption failure',
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
          DmVideoDecryptor(dio: dio).decrypt(message),
          throwsA(isA<Exception>()),
        );
      },
    );

    test('reports an HTTP failure by its status only', () async {
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
        DmVideoDecryptor(dio: dio).decrypt(message),
        throwsA(
          isA<DmVideoUnavailableException>().having(
            (error) => error.toString(),
            'description',
            allOf(contains('404'), isNot(contains('media.divine.video'))),
          ),
        ),
      );
    });
  });
}
