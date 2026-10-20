// ABOUTME: Unit tests for DmVideoPlaybackCubit.
// ABOUTME: Covers the kept video reaching ready, failures, gallery save, and
// ABOUTME: that closing leaves the kept video for the next open.

import 'dart:io';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/dm/video_playback/dm_video_playback_cubit.dart';
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
  });

  DmVideoPlaybackCubit createCubit({bool signedIn = true}) =>
      DmVideoPlaybackCubit(
        message: _videoMessage(),
        store: signedIn ? store : null,
        gallerySaveService: gallerySaveService,
      );

  void stubKeptVideo([String path = _keptPath]) {
    when(() => store.videoFor(any())).thenAnswer((_) async => File(path));
  }

  group(DmVideoPlaybackCubit, () {
    group('load', () {
      test('emits ready with the kept video', () async {
        stubKeptVideo();
        final cubit = createCubit();
        addTearDown(cubit.close);

        await cubit.load();

        expect(cubit.state.status, DmVideoPlaybackStatus.ready);
        expect(cubit.state.clipPath, _keptPath);
      });

      test('emits nothing once closed mid-download', () async {
        stubKeptVideo();
        final cubit = createCubit();
        await cubit.close();

        await cubit.load();

        expect(cubit.state.status, DmVideoPlaybackStatus.loading);
      });

      test('emits failed on a download error', () async {
        when(() => store.videoFor(any())).thenThrow(Exception('boom'));
        final cubit = createCubit();
        addTearDown(cubit.close);

        await cubit.load();

        expect(cubit.state.status, DmVideoPlaybackStatus.failed);
      });

      blocTest<DmVideoPlaybackCubit, DmVideoPlaybackState>(
        'emits failed and reports an unavailable video when signed out',
        build: () => createCubit(signedIn: false),
        act: (cubit) => cubit.load(),
        expect: () => const [
          DmVideoPlaybackState(status: DmVideoPlaybackStatus.failed),
        ],
        errors: () => [isA<DmVideoUnavailableException>()],
      );
    });

    group('playbackFailed', () {
      test('emits failed', () async {
        stubKeptVideo();
        final cubit = createCubit();
        addTearDown(cubit.close);
        await cubit.load();

        cubit.playbackFailed(Exception('decode'), StackTrace.current);

        expect(cubit.state.status, DmVideoPlaybackStatus.failed);
      });
    });

    group('saveToGallery', () {
      setUp(stubKeptVideo);

      test('emits saved on success', () async {
        when(
          () => gallerySaveService.saveVideoToGallery(
            any(),
            copyUnderNeutralName: true,
          ),
        ).thenAnswer((_) async => const GallerySaveSuccess());
        final cubit = createCubit();
        addTearDown(cubit.close);
        await cubit.load();

        await cubit.saveToGallery();

        expect(cubit.state.saveStatus, DmVideoSaveStatus.saved);
      });

      test('emits permissionDenied when access is refused', () async {
        when(
          () => gallerySaveService.saveVideoToGallery(
            any(),
            copyUnderNeutralName: true,
          ),
        ).thenAnswer((_) async => const GallerySavePermissionDenied());
        final cubit = createCubit();
        addTearDown(cubit.close);
        await cubit.load();

        await cubit.saveToGallery();

        expect(cubit.state.saveStatus, DmVideoSaveStatus.permissionDenied);
      });
    });

    group('close', () {
      test('keeps the video for the next open', () async {
        final dir = Directory.systemTemp.createTempSync('dm_video_playback_');
        addTearDown(() => dir.deleteSync(recursive: true));
        final kept = File('${dir.path}/clip.mp4')..writeAsBytesSync(const [1]);
        stubKeptVideo(kept.path);
        final cubit = createCubit();
        await cubit.load();

        await cubit.close();

        expect(kept.existsSync(), isTrue);
      });
    });
  });
}
