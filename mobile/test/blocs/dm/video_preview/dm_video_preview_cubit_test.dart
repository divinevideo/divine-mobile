// ABOUTME: Unit tests for DmVideoPreviewCubit: the frame a video DM's card
// ABOUTME: shows, and a request's card waiting for its video to be played.

import 'dart:async';
import 'dart:io';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/dm/video_preview/dm_video_preview_cubit.dart';
import 'package:openvine/services/dm_video_store.dart';

class _MockDmVideoStore extends Mock implements DmVideoStore {}

const _framePath = '/kept/dm_videos/owner/clip.preview.jpg';

DmMessage _videoMessage({String? id}) => DmMessage(
  id: id ?? 'a' * 64,
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
  late StreamController<String> kept;

  setUpAll(() => registerFallbackValue(_videoMessage()));

  setUp(() {
    store = _MockDmVideoStore();
    kept = StreamController<String>.broadcast();
    when(() => store.kept).thenAnswer((_) => kept.stream);
  });

  tearDown(() => kept.close());

  DmVideoPreviewCubit createCubit({required bool download}) =>
      DmVideoPreviewCubit(
        message: _videoMessage(),
        store: store,
        download: download,
        decode: true,
      );

  void stubPreview(String? path, {required bool download}) {
    when(
      () => store.previewFor(
        any(),
        download: download,
        stillWanted: any(named: 'stillWanted'),
      ),
    ).thenAnswer((_) async => path == null ? null : File(path));
  }

  group(DmVideoPreviewCubit, () {
    group('initial state', () {
      test('is loading while the store knows no frame', () {
        final cubit = createCubit(download: true);
        addTearDown(cubit.close);

        expect(cubit.state, equals(const DmVideoPreviewState()));
      });

      test(
        'shows a frame the store already knows, so a card built again does '
        'not flash its blurhash first',
        () {
          when(() => store.knownPreviewPathFor(any())).thenReturn(_framePath);
          final cubit = createCubit(download: false);
          addTearDown(cubit.close);

          expect(
            cubit.state,
            equals(
              const DmVideoPreviewState(
                status: DmVideoPreviewStatus.ready,
                framePath: _framePath,
              ),
            ),
          );
        },
      );
    });

    group('wanting its frame', () {
      test('stops once closed, so its queued download is dropped', () async {
        bool Function()? stillWanted;
        when(
          () => store.previewFor(
            any(),
            download: true,
            decode: any(named: 'decode'),
            stillWanted: any(named: 'stillWanted'),
          ),
        ).thenAnswer((invocation) async {
          stillWanted =
              invocation.namedArguments[#stillWanted] as bool Function()?;
          return null;
        });
        final cubit = createCubit(download: true);
        await cubit.load();
        expect(stillWanted!(), isTrue);

        await cubit.close();

        expect(stillWanted!(), isFalse);
      });
    });

    group('load', () {
      blocTest<DmVideoPreviewCubit, DmVideoPreviewState>(
        'shows the frame the store keeps, downloading the video if needed',
        setUp: () => stubPreview(_framePath, download: true),
        build: () => createCubit(download: true),
        act: (cubit) => cubit.load(),
        expect: () => const [
          DmVideoPreviewState(
            status: DmVideoPreviewStatus.ready,
            framePath: _framePath,
          ),
        ],
      );

      blocTest<DmVideoPreviewCubit, DmVideoPreviewState>(
        'shows no frame when none can be read',
        setUp: () => stubPreview(null, download: true),
        build: () => createCubit(download: true),
        act: (cubit) => cubit.load(),
        expect: () => const [
          DmVideoPreviewState(status: DmVideoPreviewStatus.none),
        ],
      );

      blocTest<DmVideoPreviewCubit, DmVideoPreviewState>(
        'shows no frame and reports a failed download',
        setUp: () => when(
          () => store.previewFor(
            any(),
            download: true,
            decode: any(named: 'decode'),
            stillWanted: any(named: 'stillWanted'),
          ),
        ).thenThrow(const SocketException('offline')),
        build: () => createCubit(download: true),
        act: (cubit) => cubit.load(),
        expect: () => const [
          DmVideoPreviewState(status: DmVideoPreviewStatus.none),
        ],
        errors: () => [isA<SocketException>()],
      );

      blocTest<DmVideoPreviewCubit, DmVideoPreviewState>(
        'shows no frame when no account is signed in',
        build: () => DmVideoPreviewCubit(
          message: _videoMessage(),
          store: null,
          download: true,
          decode: true,
        ),
        act: (cubit) => cubit.load(),
        expect: () => const [
          DmVideoPreviewState(status: DmVideoPreviewStatus.none),
        ],
      );
    });

    group('waiting for a request to be played', () {
      blocTest<DmVideoPreviewCubit, DmVideoPreviewState>(
        'asks only for a frame of a video already kept',
        setUp: () => stubPreview(null, download: false),
        build: () => createCubit(download: false),
        act: (cubit) => cubit.load(),
        expect: () => const [
          DmVideoPreviewState(status: DmVideoPreviewStatus.none),
        ],
        verify: (_) => verifyNever(
          () => store.previewFor(
            any(),
            download: true,
            decode: any(named: 'decode'),
            stillWanted: any(named: 'stillWanted'),
          ),
        ),
      );

      blocTest<DmVideoPreviewCubit, DmVideoPreviewState>(
        'shows the frame once the video is played and kept',
        setUp: () => stubPreview(null, download: false),
        build: () => createCubit(download: false),
        act: (cubit) async {
          await cubit.load();
          stubPreview(_framePath, download: false);
          kept.add('f' * 64);
          await pumpEventQueue();
          kept.add('a' * 64);
          await pumpEventQueue();
        },
        expect: () => const [
          DmVideoPreviewState(status: DmVideoPreviewStatus.none),
          DmVideoPreviewState(
            status: DmVideoPreviewStatus.ready,
            framePath: _framePath,
          ),
        ],
      );

      blocTest<DmVideoPreviewCubit, DmVideoPreviewState>(
        'shows the frame of a video too big to fetch by itself once played',
        setUp: () => stubPreview(null, download: true),
        build: () => createCubit(download: true),
        act: (cubit) async {
          await cubit.load();
          stubPreview(_framePath, download: true);
          kept.add('a' * 64);
          await pumpEventQueue();
        },
        expect: () => const [
          DmVideoPreviewState(status: DmVideoPreviewStatus.none),
          DmVideoPreviewState(
            status: DmVideoPreviewStatus.ready,
            framePath: _framePath,
          ),
        ],
      );

      blocTest<DmVideoPreviewCubit, DmVideoPreviewState>(
        'shows the frame of a video whose download failed once it is played',
        setUp: () => when(
          () => store.previewFor(
            any(),
            download: true,
            decode: any(named: 'decode'),
            stillWanted: any(named: 'stillWanted'),
          ),
        ).thenThrow(const SocketException('offline')),
        build: () => createCubit(download: true),
        act: (cubit) async {
          await cubit.load();
          stubPreview(_framePath, download: true);
          kept.add('a' * 64);
          await pumpEventQueue();
        },
        expect: () => const [
          DmVideoPreviewState(status: DmVideoPreviewStatus.none),
          DmVideoPreviewState(
            status: DmVideoPreviewStatus.ready,
            framePath: _framePath,
          ),
        ],
        errors: () => [isA<SocketException>()],
      );

      test('stops waiting when closed', () async {
        stubPreview(null, download: false);
        final cubit = createCubit(download: false);
        await cubit.load();
        expect(kept.hasListener, isTrue);

        await cubit.close();

        expect(kept.hasListener, isFalse);
      });
    });
  });
}
