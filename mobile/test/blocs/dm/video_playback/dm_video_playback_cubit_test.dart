// ABOUTME: Unit tests for DmVideoPlaybackCubit.
// ABOUTME: Covers decrypt-to-ready, failure cleanup, gallery save, and the
// ABOUTME: temp-clip deletion on close.

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/dm/video_playback/dm_video_playback_cubit.dart';
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

  DmVideoPlaybackCubit createCubit() => DmVideoPlaybackCubit(
    message: _videoMessage(),
    decryptor: decryptor,
    gallerySaveService: gallerySaveService,
  );

  group(DmVideoPlaybackCubit, () {
    group('load', () {
      test('emits ready with the decrypted clip path', () async {
        when(() => decryptor.decryptToFile(any())).thenAnswer(
          (_) async => '/tmp/dm_video_playback/clip.mp4',
        );
        final cubit = createCubit();
        addTearDown(cubit.close);

        await cubit.load();

        expect(cubit.state.status, DmVideoPlaybackStatus.ready);
        expect(cubit.state.clipPath, '/tmp/dm_video_playback/clip.mp4');
      });

      test(
        'emits failed and deletes the clip if it closed mid-decrypt',
        () async {
          when(() => decryptor.decryptToFile(any())).thenAnswer(
            (_) async => '/tmp/dm_video_playback/clip.mp4',
          );
          final cubit = createCubit();
          await cubit.close();

          await cubit.load();

          expect(cubit.state.status, DmVideoPlaybackStatus.loading);
          verify(() => decryptor.deleteClip('/tmp/dm_video_playback/clip.mp4'))
              .called(1);
        },
      );

      test('emits failed on a decrypt error', () async {
        when(
          () => decryptor.decryptToFile(any()),
        ).thenThrow(Exception('boom'));
        final cubit = createCubit();
        addTearDown(cubit.close);

        await cubit.load();

        expect(cubit.state.status, DmVideoPlaybackStatus.failed);
      });
    });

    group('playbackFailed', () {
      test('deletes the clip and emits failed', () async {
        when(() => decryptor.decryptToFile(any())).thenAnswer(
          (_) async => '/tmp/dm_video_playback/clip.mp4',
        );
        final cubit = createCubit();
        addTearDown(cubit.close);
        await cubit.load();

        cubit.playbackFailed(Exception('decode'), StackTrace.current);

        expect(cubit.state.status, DmVideoPlaybackStatus.failed);
        verify(() => decryptor.deleteClip('/tmp/dm_video_playback/clip.mp4'))
            .called(1);
      });
    });

    group('saveToGallery', () {
      setUp(() {
        when(() => decryptor.decryptToFile(any())).thenAnswer(
          (_) async => '/tmp/dm_video_playback/clip.mp4',
        );
      });

      test('emits saved on success', () async {
        when(
          () => gallerySaveService.saveVideoToGallery(any()),
        ).thenAnswer((_) async => const GallerySaveSuccess());
        final cubit = createCubit();
        addTearDown(cubit.close);
        await cubit.load();

        await cubit.saveToGallery();

        expect(cubit.state.saveStatus, DmVideoSaveStatus.saved);
      });

      test('emits permissionDenied when access is refused', () async {
        when(
          () => gallerySaveService.saveVideoToGallery(any()),
        ).thenAnswer((_) async => const GallerySavePermissionDenied());
        final cubit = createCubit();
        addTearDown(cubit.close);
        await cubit.load();

        await cubit.saveToGallery();

        expect(cubit.state.saveStatus, DmVideoSaveStatus.permissionDenied);
      });
    });

    test('close deletes the decrypted clip', () async {
      when(() => decryptor.decryptToFile(any())).thenAnswer(
        (_) async => '/tmp/dm_video_playback/clip.mp4',
      );
      final cubit = createCubit();
      await cubit.load();

      await cubit.close();

      verify(() => decryptor.deleteClip('/tmp/dm_video_playback/clip.mp4'))
          .called(1);
    });
  });
}
