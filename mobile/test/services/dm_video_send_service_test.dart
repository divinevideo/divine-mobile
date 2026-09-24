// ABOUTME: Unit tests for DmVideoSendService orchestration.
// ABOUTME: Verifies encrypt -> upload -> sendFileMessage order, exact
// ABOUTME: DmFileMetadata fields, and ciphertext temp-file cleanup.

import 'dart:io';

import 'package:blossom_upload_service/blossom_upload_service.dart';
import 'package:dm_repository/dm_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/services/dm_video_encryption.dart';
import 'package:openvine/services/dm_video_send_service.dart';

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

  DmVideoSendService createService() => DmVideoSendService(
    dmRepository: dmRepository,
    blossom: blossom,
    encryption: encryption,
  );

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
