// ABOUTME: Unit tests for EncryptedVideoSaveCubit.
// ABOUTME: Covers requiring a decrypt first, the save outcomes, and the
// ABOUTME: deletion of the temp clip before the save settles.

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/dm/encrypted_video_save/encrypted_video_save_cubit.dart';
import 'package:openvine/services/dm_video_decryptor.dart';
import 'package:openvine/services/gallery_save_service.dart';
import 'package:pro_video_editor/pro_video_editor.dart' show EditorVideo;

class _MockDmVideoDecryptor extends Mock implements DmVideoDecryptor {}

class _MockGallerySaveService extends Mock implements GallerySaveService {}

DmMessage _videoMessage() => DmMessage(
  id: 'a' * 64,
  conversationId: 'conversation',
  senderPubkey: 'b' * 64,
  content: 'https://blossom.example/encrypted',
  createdAt: 1757385263,
  giftWrapId: 'c' * 64,
  messageKind: 15,
  fileMetadata: const DmFileMetadata(
    fileType: 'video/mp4',
    encryptionAlgorithm: 'aes-gcm',
    decryptionKey: '00',
    decryptionNonce: '00',
    fileHash: 'ab',
  ),
);

void main() {
  late _MockDmVideoDecryptor decryptor;
  late _MockGallerySaveService gallerySaveService;

  setUpAll(() {
    registerFallbackValue(_videoMessage());
    registerFallbackValue(EditorVideo.file(''));
    registerFallbackValue('');
  });

  setUp(() {
    decryptor = _MockDmVideoDecryptor();
    gallerySaveService = _MockGallerySaveService();
  });

  EncryptedVideoSaveCubit createCubit() => EncryptedVideoSaveCubit(
    decryptor: decryptor,
    gallerySaveService: gallerySaveService,
  );

  group(EncryptedVideoSaveCubit, () {
    test('decrypts, saves, and deletes the temp clip on success', () async {
      when(
        () => decryptor.decryptToFile(any()),
      ).thenAnswer((_) async => '/tmp/dm_video_playback/clip.mp4');
      when(
        () => gallerySaveService.saveVideoToGallery(any()),
      ).thenAnswer((_) async => const GallerySaveSuccess());
      final cubit = createCubit();
      addTearDown(cubit.close);

      await cubit.save(_videoMessage());

      expect(cubit.state.status, DmVideoSaveStatus.saved);
      verify(() => decryptor.deleteClip('/tmp/dm_video_playback/clip.mp4'))
          .called(1);
    });

    test('reports permissionDenied', () async {
      when(
        () => decryptor.decryptToFile(any()),
      ).thenAnswer((_) async => '/tmp/dm_video_playback/clip.mp4');
      when(
        () => gallerySaveService.saveVideoToGallery(any()),
      ).thenAnswer((_) async => const GallerySavePermissionDenied());
      final cubit = createCubit();
      addTearDown(cubit.close);

      await cubit.save(_videoMessage());

      expect(cubit.state.status, DmVideoSaveStatus.permissionDenied);
    });

    test('reports failed and deletes the clip when the save fails', () async {
      when(
        () => decryptor.decryptToFile(any()),
      ).thenAnswer((_) async => '/tmp/dm_video_playback/clip.mp4');
      when(
        () => gallerySaveService.saveVideoToGallery(any()),
      ).thenAnswer((_) async => const GallerySaveFailure('disk'));
      final cubit = createCubit();
      addTearDown(cubit.close);

      await cubit.save(_videoMessage());

      expect(cubit.state.status, DmVideoSaveStatus.failed);
      verify(() => decryptor.deleteClip('/tmp/dm_video_playback/clip.mp4'))
          .called(1);
    });

    test('reports failed when decryption throws', () async {
      when(
        () => decryptor.decryptToFile(any()),
      ).thenThrow(Exception('boom'));
      final cubit = createCubit();
      addTearDown(cubit.close);

      await cubit.save(_videoMessage());

      expect(cubit.state.status, DmVideoSaveStatus.failed);
      verifyNever(() => decryptor.deleteClip(any()));
    });
  });
}
