// ABOUTME: Unit tests for DmVideoSendService orchestration.
// ABOUTME: Verifies encrypt -> upload -> sendFileMessage order, exact
// ABOUTME: DmFileMetadata fields, and ciphertext temp-file cleanup.

import 'dart:io';

import 'package:blossom_upload_service/blossom_upload_service.dart';
import 'package:dm_repository/dm_repository.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/services/dm_video_encryption.dart';
import 'package:openvine/services/dm_video_preview.dart';
import 'package:openvine/services/dm_video_send_service.dart';
// Not exported from pro_video_editor's barrel. Imported by path so the test
// can subclass MethodChannelProVideoEditor without its EventChannel setup.
import 'package:pro_video_editor/core/platform/native_method_channel.dart';
import 'package:pro_video_editor/core/platform/platform_interface.dart';

class _NoopInitProVideoEditor extends MethodChannelProVideoEditor {
  @override
  Stream<dynamic> initializeStream() => const Stream.empty();
}

class _MockDmRepository extends Mock implements DmRepository {}

class _MockBlossomUploadService extends Mock implements BlossomUploadService {}

class _MockDmVideoEncryption extends Mock implements DmVideoEncryption {}

const _recipientPubkey =
    '1111111111111111111111111111111111111111111111111111111111111111';
const _ciphertextHash =
    'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
const _plaintextHash =
    'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';
const _key = 'cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc';
const _nonce = 'dddddddddddddddddddddddddd';
const _fileUrl = 'https://media.divine.video/$_ciphertextHash';

void main() {
  late _MockDmRepository dmRepository;
  late _MockBlossomUploadService blossom;
  late _MockDmVideoEncryption encryption;
  late Directory tempDir;

  setUp(() {
    dmRepository = _MockDmRepository();
    blossom = _MockBlossomUploadService();
    encryption = _MockDmVideoEncryption();
    tempDir = Directory.systemTemp.createTempSync('dm_video_send_service_test');
    registerFallbackValue(
      const DmFileMetadata(
        fileType: '',
        encryptionAlgorithm: '',
        decryptionKey: '',
        decryptionNonce: '',
        fileHash: '',
      ),
    );
  });

  tearDown(() {
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  File ciphertextFile() =>
      File('${tempDir.path}/$_ciphertextHash')
        ..writeAsBytesSync(const [1, 2, 3, 4]);

  EncryptedVideoFile encryptedVideo(File file) => EncryptedVideoFile(
    ciphertextFile: file,
    key: _key,
    nonce: _nonce,
    ciphertextHash: _ciphertextHash,
    plaintextHash: _plaintextHash,
    ciphertextSize: file.lengthSync(),
  );

  DmVideoSendService createService({DmVideoPreviewReader? readPreview}) =>
      DmVideoSendService(
        dmRepository: dmRepository,
        blossom: blossom,
        encryption: encryption,
        readPreview:
            readPreview ?? (_) async => (blurhash: null, dimensions: null),
      );

  /// Stubs a successful encrypt and upload of [videoFile], and captures the
  /// metadata the service hands to [DmRepository.sendFileMessage].
  List<DmFileMetadata> stubSuccessfulSend(
    File videoFile, {
    void Function()? onEncrypt,
  }) {
    final ciphertext = ciphertextFile();
    when(() => encryption.encryptFile(videoFile)).thenAnswer((_) async {
      onEncrypt?.call();
      return encryptedVideo(ciphertext);
    });
    when(
      () => blossom.uploadEncryptedFile(ciphertextFile: ciphertext),
    ).thenAnswer(
      (_) async => const BlossomUploadResult(
        success: true,
        videoId: _ciphertextHash,
        url: _fileUrl,
      ),
    );
    final sent = <DmFileMetadata>[];
    when(
      () => dmRepository.sendFileMessage(
        recipientPubkey: any(named: 'recipientPubkey'),
        fileUrl: any(named: 'fileUrl'),
        fileMetadata: any(named: 'fileMetadata'),
        extraTags: any(named: 'extraTags'),
      ),
    ).thenAnswer((invocation) async {
      sent.add(invocation.namedArguments[#fileMetadata] as DmFileMetadata);
      return NIP17SendResult.success(
        rumorEventId: 'rumor-1',
        messageEventId: 'wrap-1',
        recipientPubkey: _recipientPubkey,
      );
    });
    return sent;
  }

  group(DmVideoSendService, () {
    test(
      'encrypts, uploads, then sends kind 15 with exact metadata and '
      'deletes the ciphertext temp file',
      () async {
        final videoFile = File('${tempDir.path}/clip.mp4')
          ..writeAsBytesSync(const [9, 9, 9]);
        final ciphertext = ciphertextFile();
        final ciphertextSize = ciphertext.lengthSync();
        final enc = encryptedVideo(ciphertext);
        final success = NIP17SendResult.success(
          rumorEventId: 'rumor-1',
          messageEventId: 'wrap-1',
          recipientPubkey: _recipientPubkey,
        );

        when(() => encryption.encryptFile(videoFile))
            .thenAnswer((_) async => enc);
        when(
          () => blossom.uploadEncryptedFile(ciphertextFile: ciphertext),
        ).thenAnswer(
          (_) async => const BlossomUploadResult(
            success: true,
            videoId: _ciphertextHash,
            url: _fileUrl,
          ),
        );
        DmFileMetadata? sentMetadata;
        String? sentFileUrl;
        when(
          () => dmRepository.sendFileMessage(
            recipientPubkey: any(named: 'recipientPubkey'),
            fileUrl: any(named: 'fileUrl'),
            fileMetadata: any(named: 'fileMetadata'),
          ),
        ).thenAnswer((invocation) async {
          sentFileUrl = invocation.namedArguments[#fileUrl] as String?;
          sentMetadata =
              invocation.namedArguments[#fileMetadata] as DmFileMetadata?;
          return success;
        });

        final service = createService();
        final result = await service.sendVideo(
          recipientPubkey: _recipientPubkey,
          videoFile: videoFile,
          mimeType: 'video/mp4',
          blurhash: 'LEHV6nWB2yk8',
          dimensions: '1080x1920',
        );

        expect(result, success);
        verifyInOrder([
          () => encryption.encryptFile(videoFile),
          () => blossom.uploadEncryptedFile(ciphertextFile: ciphertext),
          () => dmRepository.sendFileMessage(
            recipientPubkey: _recipientPubkey,
            fileUrl: _fileUrl,
            fileMetadata: any(named: 'fileMetadata'),
          ),
        ]);

        expect(sentFileUrl, _fileUrl);
        expect(sentMetadata, isNotNull);
        expect(sentMetadata!.fileType, 'video/mp4');
        expect(sentMetadata!.encryptionAlgorithm, 'aes-gcm');
        expect(sentMetadata!.decryptionKey, _key);
        expect(sentMetadata!.decryptionNonce, _nonce);
        expect(sentMetadata!.fileHash, _ciphertextHash);
        expect(sentMetadata!.originalFileHash, _plaintextHash);
        expect(sentMetadata!.fileSize, ciphertextSize);
        expect(sentMetadata!.dimensions, '1080x1920');
        expect(sentMetadata!.blurhash, 'LEHV6nWB2yk8');
        expect(sentMetadata!.thumbnailUrl, isNull);

        expect(ciphertext.existsSync(), isFalse);
      },
    );

    test('forwards extraTags to sendFileMessage', () async {
      final videoFile = File('${tempDir.path}/clip.mp4')
        ..writeAsBytesSync(const [9, 9, 9]);
      final ciphertext = ciphertextFile();
      when(
        () => encryption.encryptFile(videoFile),
      ).thenAnswer((_) async => encryptedVideo(ciphertext));
      when(
        () => blossom.uploadEncryptedFile(ciphertextFile: ciphertext),
      ).thenAnswer(
        (_) async => const BlossomUploadResult(
          success: true,
          videoId: _ciphertextHash,
          url: _fileUrl,
        ),
      );
      when(
        () => dmRepository.sendFileMessage(
          recipientPubkey: any(named: 'recipientPubkey'),
          fileUrl: any(named: 'fileUrl'),
          fileMetadata: any(named: 'fileMetadata'),
          extraTags: any(named: 'extraTags'),
        ),
      ).thenAnswer(
        (_) async => NIP17SendResult.success(
          rumorEventId: 'rumor-1',
          messageEventId: 'wrap-1',
          recipientPubkey: _recipientPubkey,
        ),
      );

      final result = await createService().sendVideo(
        recipientPubkey: _recipientPubkey,
        videoFile: videoFile,
        mimeType: 'video/mp4',
        extraTags: const [
          ['divine-clip', 'vertical'],
        ],
      );

      expect(result.success, isTrue);
      verify(
        () => dmRepository.sendFileMessage(
          recipientPubkey: _recipientPubkey,
          fileUrl: _fileUrl,
          fileMetadata: any(named: 'fileMetadata'),
          extraTags: const [
            ['divine-clip', 'vertical'],
          ],
        ),
      ).called(1);
    });

    group('preview', () {
      late File videoFile;

      setUp(() {
        videoFile = File('${tempDir.path}/clip.mp4')
          ..writeAsBytesSync(const [9, 9, 9]);
      });

      test(
        'sends the blurhash and size read from the video, so the recipient '
        'sees a preview instead of a blank card',
        () async {
          final sent = stubSuccessfulSend(videoFile);
          final readFrom = <String>[];

          final result =
              await createService(
                readPreview: (file) async {
                  readFrom.add(file.path);
                  return (
                    blurhash: 'LKO2?U%2Tw=w]~RBVZRi};RPxuwH',
                    dimensions: '1080x1920',
                  );
                },
              ).sendVideo(
                recipientPubkey: _recipientPubkey,
                videoFile: videoFile,
                mimeType: 'video/mp4',
              );

          expect(result.success, isTrue);
          expect(readFrom, equals([videoFile.path]));
          expect(sent.single.blurhash, 'LKO2?U%2Tw=w]~RBVZRi};RPxuwH');
          expect(sent.single.dimensions, '1080x1920');
          expect(sent.single.thumbnailUrl, isNull);
        },
      );

      test(
        'reads the preview once the file is encrypted, so encryption does not '
        'use up its time limit',
        () async {
          // Encryption runs on this isolate and holds it for seconds on a
          // large file, which would expire a deadline started before it.
          final order = <String>[];
          final sent = stubSuccessfulSend(
            videoFile,
            onEncrypt: () => order.add('encrypt'),
          );

          final result =
              await createService(
                readPreview: (_) async {
                  order.add('preview');
                  return (blurhash: null, dimensions: null);
                },
              ).sendVideo(
                recipientPubkey: _recipientPubkey,
                videoFile: videoFile,
                mimeType: 'video/mp4',
              );

          expect(result.success, isTrue);
          expect(sent, hasLength(1));
          expect(order, equals(['encrypt', 'preview']));
        },
      );

      test('keeps a blurhash and size the caller already has', () async {
        final sent = stubSuccessfulSend(videoFile);

        final result =
            await createService(
              readPreview: (_) async =>
                  (blurhash: 'L00000fQfQfQfQfQfQfQfQfQfQfQ', dimensions: '1x1'),
            ).sendVideo(
              recipientPubkey: _recipientPubkey,
              videoFile: videoFile,
              mimeType: 'video/mp4',
              blurhash: 'LEHV6nWB2yk8',
              dimensions: '1080x1080',
            );

        expect(result.success, isTrue);
        expect(sent.single.blurhash, 'LEHV6nWB2yk8');
        expect(sent.single.dimensions, '1080x1080');
      });

      test('reads the preview from the video when none is injected', () async {
        final sent = stubSuccessfulSend(videoFile);
        final originalProVideoEditor = ProVideoEditor.instance;
        ProVideoEditor.instance = _NoopInitProVideoEditor();
        const channel = MethodChannel('pro_video_editor');
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, (call) async {
              return switch (call.method) {
                'getThumbnails' => [
                  img.encodePng(
                    img.fill(
                      img.Image(width: 16, height: 16),
                      color: img.ColorRgb8(255, 0, 0),
                    ),
                  ),
                ],
                'getMetadata' => const {'width': 1080, 'height': 1920},
                _ => null,
              };
            });
        addTearDown(() {
          ProVideoEditor.instance = originalProVideoEditor;
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
              .setMockMethodCallHandler(channel, null);
        });

        final result =
            await DmVideoSendService(
              dmRepository: dmRepository,
              blossom: blossom,
              encryption: encryption,
            ).sendVideo(
              recipientPubkey: _recipientPubkey,
              videoFile: videoFile,
              mimeType: 'video/mp4',
            );

        expect(result.success, isTrue);
        expect(sent.single.blurhash, isNotNull);
        expect(sent.single.dimensions, '1080x1920');
      });
    });

    test('upload failure skips sendFileMessage and still cleans up', () async {
      final videoFile = File('${tempDir.path}/clip.mp4')
        ..writeAsBytesSync(const [9, 9, 9]);
      final ciphertext = ciphertextFile();
      final enc = encryptedVideo(ciphertext);

      when(() => encryption.encryptFile(videoFile))
          .thenAnswer((_) async => enc);
      when(
        () => blossom.uploadEncryptedFile(ciphertextFile: ciphertext),
      ).thenAnswer(
        (_) async => const BlossomUploadResult(
          success: false,
          errorMessage: 'boom',
        ),
      );

      final service = createService();
      final result = await service.sendVideo(
        recipientPubkey: _recipientPubkey,
        videoFile: videoFile,
        mimeType: 'video/mp4',
      );

      expect(result.success, isFalse);
      expect(result.error, 'boom');
      verifyNever(
        () => dmRepository.sendFileMessage(
          recipientPubkey: any(named: 'recipientPubkey'),
          fileUrl: any(named: 'fileUrl'),
          fileMetadata: any(named: 'fileMetadata'),
        ),
      );
      expect(ciphertext.existsSync(), isFalse);
    });

    test(
      'upload reporting success without a videoId fails before sendFileMessage',
      () async {
        final videoFile = File('${tempDir.path}/clip.mp4')
          ..writeAsBytesSync(const [9, 9, 9]);
        final ciphertext = ciphertextFile();
        final enc = encryptedVideo(ciphertext);

        when(
          () => encryption.encryptFile(videoFile),
        ).thenAnswer((_) async => enc);
        when(
          () => blossom.uploadEncryptedFile(ciphertextFile: ciphertext),
        ).thenAnswer((_) async => const BlossomUploadResult(success: true));

        final service = createService();
        final result = await service.sendVideo(
          recipientPubkey: _recipientPubkey,
          videoFile: videoFile,
          mimeType: 'video/mp4',
        );

        expect(result.success, isFalse);
        expect(result.error, 'Encrypted upload failed');
        verifyNever(
          () => dmRepository.sendFileMessage(
            recipientPubkey: any(named: 'recipientPubkey'),
            fileUrl: any(named: 'fileUrl'),
            fileMetadata: any(named: 'fileMetadata'),
          ),
        );
        expect(ciphertext.existsSync(), isFalse);
      },
    );

    test(
      'falls back to the default media server when no url is returned',
      () async {
        final videoFile = File('${tempDir.path}/clip.mp4')
          ..writeAsBytesSync(const [9, 9, 9]);
        final ciphertext = ciphertextFile();
        final enc = encryptedVideo(ciphertext);

        when(() => encryption.encryptFile(videoFile))
            .thenAnswer((_) async => enc);
        when(
          () => blossom.uploadEncryptedFile(ciphertextFile: ciphertext),
        ).thenAnswer(
          (_) async => const BlossomUploadResult(
            success: true,
            videoId: _ciphertextHash,
          ),
        );
        String? sentFileUrl;
        when(
          () => dmRepository.sendFileMessage(
            recipientPubkey: any(named: 'recipientPubkey'),
            fileUrl: any(named: 'fileUrl'),
            fileMetadata: any(named: 'fileMetadata'),
          ),
        ).thenAnswer((invocation) async {
          sentFileUrl = invocation.namedArguments[#fileUrl] as String?;
          return NIP17SendResult.success(
            rumorEventId: 'rumor-1',
            messageEventId: 'wrap-1',
            recipientPubkey: _recipientPubkey,
          );
        });

        final service = createService();
        final result = await service.sendVideo(
          recipientPubkey: _recipientPubkey,
          videoFile: videoFile,
          mimeType: 'video/mp4',
        );

        expect(result.success, isTrue);
        expect(
          sentFileUrl,
          '${BlossomUploadService.defaultBlossomServer}/$_ciphertextHash',
        );
      },
    );

    test('reports encrypt, upload, then send phases in order', () async {
      final videoFile = File('${tempDir.path}/clip.mp4')
        ..writeAsBytesSync(const [9, 9, 9]);
      final ciphertext = ciphertextFile();
      final enc = encryptedVideo(ciphertext);

      when(() => encryption.encryptFile(videoFile))
          .thenAnswer((_) async => enc);
      when(
        () => blossom.uploadEncryptedFile(ciphertextFile: ciphertext),
      ).thenAnswer(
        (_) async => const BlossomUploadResult(
          success: true,
          videoId: _ciphertextHash,
          url: _fileUrl,
        ),
      );
      when(
        () => dmRepository.sendFileMessage(
          recipientPubkey: any(named: 'recipientPubkey'),
          fileUrl: any(named: 'fileUrl'),
          fileMetadata: any(named: 'fileMetadata'),
        ),
      ).thenAnswer(
        (_) async => NIP17SendResult.success(
          rumorEventId: 'rumor-1',
          messageEventId: 'wrap-1',
          recipientPubkey: _recipientPubkey,
        ),
      );

      final phases = <DmVideoSendPhase>[];
      final service = createService();
      final result = await service.sendVideo(
        recipientPubkey: _recipientPubkey,
        videoFile: videoFile,
        mimeType: 'video/mp4',
        onPhase: phases.add,
      );

      expect(result.success, isTrue);
      expect(phases, DmVideoSendPhase.values);
    });
  });
}
