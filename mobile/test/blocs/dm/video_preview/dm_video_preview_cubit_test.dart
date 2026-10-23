// ABOUTME: Unit tests for DmVideoPreviewCubit: the frame a trusted sender's
// ABOUTME: video DM card shows, now or once its video is played and kept.

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

  DmVideoPreviewCubit createCubit() =>
      DmVideoPreviewCubit(message: _videoMessage(), store: store);

  void stubPreview(String? path) {
    when(
      () => store.previewFor(
        any(),
        stillWanted: any(named: 'stillWanted'),
      ),
    ).thenAnswer((_) async => path == null ? null : File(path));
  }

  group(DmVideoPreviewCubit, () {
    group('initial state', () {
      test('is loading while the store knows no frame', () {
        final cubit = createCubit();
        addTearDown(cubit.close);

        expect(cubit.state, equals(const DmVideoPreviewState()));
      });

      test(
        'shows a frame the store already knows, so a card built again does '
        'not flash its blurhash first',
        () {
          when(() => store.knownPreviewPathFor(any())).thenReturn(_framePath);
          final cubit = createCubit();
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
            stillWanted: any(named: 'stillWanted'),
          ),
        ).thenAnswer((invocation) async {
          stillWanted =
              invocation.namedArguments[#stillWanted] as bool Function()?;
          return null;
        });
        final cubit = createCubit();
        await cubit.load();
        expect(stillWanted!(), isTrue);

        await cubit.close();

        expect(stillWanted!(), isFalse);
      });
    });

    group('load', () {
      blocTest<DmVideoPreviewCubit, DmVideoPreviewState>(
        'shows the frame the store keeps, downloading the video if needed',
        setUp: () => stubPreview(_framePath),
        build: createCubit,
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
        setUp: () => stubPreview(null),
        build: createCubit,
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
            stillWanted: any(named: 'stillWanted'),
          ),
        ).thenThrow(const SocketException('offline')),
        build: createCubit,
        act: (cubit) => cubit.load(),
        expect: () => const [
          DmVideoPreviewState(status: DmVideoPreviewStatus.none),
        ],
        errors: () => [isA<SocketException>()],
      );

      late Completer<File?> lateFailure;
      blocTest<DmVideoPreviewCubit, DmVideoPreviewState>(
        'still reports a failure that lands once it closed',
        setUp: () {
          lateFailure = Completer<File?>();
          when(
            () => store.previewFor(
              any(),
              stillWanted: any(named: 'stillWanted'),
            ),
          ).thenAnswer((_) => lateFailure.future);
        },
        build: createCubit,
        act: (cubit) async {
          final loading = cubit.load();
          await cubit.close();
          lateFailure.completeError(StateError('a bug'));
          await loading;
        },
        expect: () => const <DmVideoPreviewState>[],
        errors: () => [isA<StateError>()],
      );

      blocTest<DmVideoPreviewCubit, DmVideoPreviewState>(
        'shows no frame when no account is signed in',
        build: () => DmVideoPreviewCubit(message: _videoMessage(), store: null),
        act: (cubit) => cubit.load(),
        expect: () => const [
          DmVideoPreviewState(status: DmVideoPreviewStatus.none),
        ],
      );
    });

    group('waiting for its video to be kept', () {
      blocTest<DmVideoPreviewCubit, DmVideoPreviewState>(
        'shows the frame of a video too big to fetch by itself once played, '
        'not when another video is kept',
        setUp: () => stubPreview(null),
        build: createCubit,
        act: (cubit) async {
          await cubit.load();
          stubPreview(_framePath);
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
        'shows the frame of a video whose download failed once it is played',
        setUp: () => when(
          () => store.previewFor(
            any(),
            stillWanted: any(named: 'stillWanted'),
          ),
        ).thenThrow(const SocketException('offline')),
        build: createCubit,
        act: (cubit) async {
          await cubit.load();
          stubPreview(_framePath);
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
        stubPreview(null);
        final cubit = createCubit();
        await cubit.load();
        expect(kept.hasListener, isTrue);

        await cubit.close();

        expect(kept.hasListener, isFalse);
      });
    });
  });
}
