// ABOUTME: Unit tests for EncryptedVideoSaveCubit.
// ABOUTME: Covers saving the kept video to the gallery, the save outcomes, and
// ABOUTME: a save with no account signed in.

import 'dart:io';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/dm/encrypted_video_save/encrypted_video_save_cubit.dart';
import 'package:openvine/services/dm_video_decryptor.dart';
import 'package:openvine/services/dm_video_store.dart';
import 'package:openvine/services/gallery_save_service.dart';
import 'package:pro_video_editor/pro_video_editor.dart' show EditorVideo;

class _MockDmVideoStore extends Mock implements DmVideoStore {}

class _MockGallerySaveService extends Mock implements GallerySaveService {}

const _keptPath = '/kept/dm_videos/owner/clip.mp4';

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
  late _MockDmVideoStore store;
  late _MockGallerySaveService gallerySaveService;

  setUpAll(() {
    registerFallbackValue(_videoMessage());
    registerFallbackValue(EditorVideo.file(''));
  });

  setUp(() {
    store = _MockDmVideoStore();
    gallerySaveService = _MockGallerySaveService();
    when(
      () => store.videoFor(any()),
    ).thenAnswer((_) async => File(_keptPath));
  });

  EncryptedVideoSaveCubit createCubit() => EncryptedVideoSaveCubit(
    resolveStore: () => store,
    gallerySaveService: gallerySaveService,
  );

  void stubGallery(GallerySaveResult result) {
    when(
      () => gallerySaveService.saveVideoToGallery(any()),
    ).thenAnswer((_) async => result);
  }

  group(EncryptedVideoSaveCubit, () {
    group('save', () {
      blocTest<EncryptedVideoSaveCubit, EncryptedVideoSaveState>(
        'saves the kept video to the gallery',
        setUp: () => stubGallery(const GallerySaveSuccess()),
        build: createCubit,
        act: (cubit) => cubit.save(_videoMessage()),
        expect: () => const [
          EncryptedVideoSaveState(status: DmVideoSaveStatus.saving),
          EncryptedVideoSaveState(status: DmVideoSaveStatus.saved),
        ],
        verify: (_) {
          final video =
              verify(
                    () => gallerySaveService.saveVideoToGallery(captureAny()),
                  ).captured.single
                  as EditorVideo;
          expect(video.file?.path, equals(_keptPath));
        },
      );

      blocTest<EncryptedVideoSaveCubit, EncryptedVideoSaveState>(
        'reports permissionDenied',
        setUp: () => stubGallery(const GallerySavePermissionDenied()),
        build: createCubit,
        act: (cubit) => cubit.save(_videoMessage()),
        expect: () => const [
          EncryptedVideoSaveState(status: DmVideoSaveStatus.saving),
          EncryptedVideoSaveState(status: DmVideoSaveStatus.permissionDenied),
        ],
      );

      blocTest<EncryptedVideoSaveCubit, EncryptedVideoSaveState>(
        'reports failed when the gallery save fails',
        setUp: () => stubGallery(const GallerySaveFailure('disk full')),
        build: createCubit,
        act: (cubit) => cubit.save(_videoMessage()),
        expect: () => const [
          EncryptedVideoSaveState(status: DmVideoSaveStatus.saving),
          EncryptedVideoSaveState(status: DmVideoSaveStatus.failed),
        ],
      );

      blocTest<EncryptedVideoSaveCubit, EncryptedVideoSaveState>(
        'reports failed when the video cannot be downloaded',
        setUp: () => when(
          () => store.videoFor(any()),
        ).thenThrow(const DmVideoUnavailableException('hash mismatch')),
        build: createCubit,
        act: (cubit) => cubit.save(_videoMessage()),
        expect: () => const [
          EncryptedVideoSaveState(status: DmVideoSaveStatus.saving),
          EncryptedVideoSaveState(status: DmVideoSaveStatus.failed),
        ],
        errors: () => [isA<DmVideoUnavailableException>()],
      );

      blocTest<EncryptedVideoSaveCubit, EncryptedVideoSaveState>(
        'fails without downloading when no account is signed in',
        build: () => EncryptedVideoSaveCubit(
          resolveStore: () => null,
          gallerySaveService: gallerySaveService,
        ),
        act: (cubit) => cubit.save(_videoMessage()),
        expect: () => const [
          EncryptedVideoSaveState(status: DmVideoSaveStatus.saving),
          EncryptedVideoSaveState(status: DmVideoSaveStatus.failed),
        ],
        errors: () => [isA<DmVideoUnavailableException>()],
        verify: (_) => verifyNever(() => store.videoFor(any())),
      );
    });
  });
}
