// ABOUTME: End-to-end test for the encrypted video DM round trip.
// ABOUTME: Real AES-GCM encrypt + decrypt; only Blossom upload, transport, and
// ABOUTME: the DM repository are faked. Send pipeline output is fed, as a
// ABOUTME: received kind 15 message, back through the receive pipeline.

import 'dart:io';
import 'dart:typed_data';

import 'package:blossom_upload_service/blossom_upload_service.dart';
import 'package:dio/dio.dart';
import 'package:dm_repository/dm_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:nostr_sdk/nip17/file_encryption.dart';
import 'package:openvine/services/dm_video_decryptor.dart';
import 'package:openvine/services/dm_video_encryption.dart';
import 'package:openvine/services/dm_video_send_service.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

import '../../mocks/mock_path_provider_platform.dart';

class _MockDmRepository extends Mock implements DmRepository {}

class _MockBlossomUploadService extends Mock implements BlossomUploadService {}

class _MockDio extends Mock implements Dio {}

const _recipientPubkey =
    '1111111111111111111111111111111111111111111111111111111111111111';
const _senderPubkey =
    '2222222222222222222222222222222222222222222222222222222222222222';
const _messageId =
    '3333333333333333333333333333333333333333333333333333333333333333';
const _conversationId =
    '4444444444444444444444444444444444444444444444444444444444444444';
const _giftWrapId =
    '5555555555555555555555555555555555555555555555555555555555555555';
const _mediaBase = 'https://media.divine.video';
const _mimeType = 'video/mp4';

/// Capture of what the send pipeline handed to the faked transport.
class _SentVideo {
  Uint8List? ciphertext;
  File? ciphertextFile;
  DmFileMetadata? metadata;
  String? fileUrl;
}

/// Fakes the send-side transport: Blossom "stores" the uploaded ciphertext,
/// and the repository records the metadata and URL it was asked to send.
///
/// The stored ciphertext is served back by [stubDownload] on the receive side,
/// so encryption and decryption both stay real.
void _recordSend({
  required _MockBlossomUploadService blossom,
  required _MockDmRepository dmRepository,
  required _SentVideo out,
}) {
  when(
    () => blossom.uploadEncryptedFile(
      ciphertextFile: any(named: 'ciphertextFile'),
    ),
  ).thenAnswer((invocation) async {
    final file = invocation.namedArguments[#ciphertextFile] as File;
    out.ciphertextFile = file;
    out.ciphertext = await file.readAsBytes();
    final hash = HashUtil.sha256Hash(out.ciphertext!);
    return BlossomUploadResult(
      success: true,
      videoId: hash,
      url: '$_mediaBase/$hash',
    );
  });

  when(
    () => dmRepository.sendFileMessage(
      recipientPubkey: any(named: 'recipientPubkey'),
      fileUrl: any(named: 'fileUrl'),
      fileMetadata: any(named: 'fileMetadata'),
    ),
  ).thenAnswer((invocation) async {
    out.fileUrl = invocation.namedArguments[#fileUrl] as String?;
    out.metadata = invocation.namedArguments[#fileMetadata] as DmFileMetadata?;
    return NIP17SendResult.success(
      rumorEventId: _messageId,
      messageEventId: _giftWrapId,
      recipientPubkey: _recipientPubkey,
    );
  });
}

/// Serves [bytes] from [url] through the faked receive transport.
void _stubDownload(_MockDio dio, String url, List<int> bytes) {
  when(
    () => dio.get<List<int>>(url, options: any(named: 'options')),
  ).thenAnswer(
    (_) async => Response<List<int>>(
      requestOptions: RequestOptions(path: url),
      statusCode: 200,
      data: bytes,
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('encrypted video DM end to end', () {
    late _MockDmRepository dmRepository;
    late _MockBlossomUploadService blossom;
    late _MockDio dio;
    late Directory tempDir;
    late PathProviderPlatform originalPathProvider;

    setUpAll(() {
      registerFallbackValue(
        const DmFileMetadata(
          fileType: '',
          encryptionAlgorithm: '',
          decryptionKey: '',
          decryptionNonce: '',
          fileHash: '',
        ),
      );
      registerFallbackValue(File('/tmp/dm_video_flow_fallback'));
      registerFallbackValue(Options());
    });

    setUp(() {
      dmRepository = _MockDmRepository();
      blossom = _MockBlossomUploadService();
      dio = _MockDio();
      when(() => dio.options).thenReturn(BaseOptions());

      tempDir = Directory.systemTemp.createTempSync('encrypted_video_dm_flow_');
      originalPathProvider = PathProviderPlatform.instance;
      PathProviderPlatform.instance = MockPathProviderPlatform()
        ..setTemporaryPath(tempDir.path);
    });

    tearDown(() {
      PathProviderPlatform.instance = originalPathProvider;
      if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
    });

    File writePlaintextVideo(String name, Uint8List bytes) =>
        File('${tempDir.path}/$name')..writeAsBytesSync(bytes);

    DmVideoSendService createSendService() => DmVideoSendService(
      dmRepository: dmRepository,
      blossom: blossom,
      encryption: DmVideoEncryption(),
    );

    test(
      'a sent video is decrypted to its original bytes by the receive path',
      () async {
        final plaintext = Uint8List.fromList(
          List<int>.generate(4096, (index) => (index * 7) % 256),
        );
        final videoFile = writePlaintextVideo('original_clip.mp4', plaintext);
        final sent = _SentVideo();
        _recordSend(
          blossom: blossom,
          dmRepository: dmRepository,
          out: sent,
        );

        // --- Send half: real encryption, fake upload/repository. ---
        final result = await createSendService().sendVideo(
          recipientPubkey: _recipientPubkey,
          videoFile: videoFile,
          mimeType: _mimeType,
        );

        expect(result.success, isTrue);
        expect(sent.ciphertext, isNotNull);
        expect(sent.metadata, isNotNull);
        expect(sent.fileUrl, isNotNull);

        // Crypto genuinely ran: ciphertext is not the plaintext.
        expect(sent.ciphertext, isNot(equals(plaintext)));
        expect(sent.metadata!.fileHash, HashUtil.sha256Hash(sent.ciphertext!));
        expect(sent.metadata!.fileType, _mimeType);
        expect(sent.metadata!.encryptionAlgorithm, 'aes-gcm');
        expect(sent.metadata!.decryptionKey, hasLength(64));
        expect(sent.metadata!.decryptionNonce, hasLength(24));
        expect(sent.metadata!.thumbnailUrl, isNull);
        // Send cleans up its ciphertext temp file.
        expect(sent.ciphertextFile!.existsSync(), isFalse);

        _stubDownload(dio, sent.fileUrl!, sent.ciphertext!.toList());

        // --- Receive half: rebuild a kind 15 message from the wire data. ---
        final received = DmMessage(
          id: _messageId,
          conversationId: _conversationId,
          senderPubkey: _senderPubkey,
          content: sent.fileUrl!,
          createdAt: 1700000000,
          giftWrapId: _giftWrapId,
          messageKind: 15,
          fileMetadata: sent.metadata,
        );
        expect(received.isFileMessage, isTrue);
        expect(received.fileMetadata!.isVideo, isTrue);

        final clip =
            await DmVideoDecryptor(
              dio: dio,
              encryption: FileEncryption(),
            ).materialize(
              url: received.content,
              key: received.fileMetadata!.decryptionKey,
              nonce: received.fileMetadata!.decryptionNonce,
              fileName: 'dm_video_${received.id}.mp4',
            );

        // The decrypted plaintext equals the original input, byte for byte.
        expect(File(clip.uri).readAsBytesSync(), equals(plaintext));
      },
    );

    test(
      'a tampered ciphertext fails authentication instead of yielding bytes',
      () async {
        final plaintext = Uint8List.fromList(
          List<int>.generate(512, (index) => index % 251),
        );
        final videoFile = writePlaintextVideo('tamper_clip.mp4', plaintext);
        final sent = _SentVideo();
        _recordSend(
          blossom: blossom,
          dmRepository: dmRepository,
          out: sent,
        );

        final result = await createSendService().sendVideo(
          recipientPubkey: _recipientPubkey,
          videoFile: videoFile,
          mimeType: _mimeType,
        );
        expect(result.success, isTrue);

        // Flip one ciphertext byte before the receiver downloads it.
        final tampered = Uint8List.fromList(sent.ciphertext!);
        tampered[0] ^= 0xff;
        _stubDownload(dio, sent.fileUrl!, tampered.toList());

        await expectLater(
          DmVideoDecryptor(
            dio: dio,
            encryption: FileEncryption(),
          ).materialize(
            url: sent.fileUrl!,
            key: sent.metadata!.decryptionKey,
            nonce: sent.metadata!.decryptionNonce,
            fileName: 'dm_video_$_messageId.mp4',
          ),
          throwsA(isA<Exception>()),
        );
      },
    );
  });
}
