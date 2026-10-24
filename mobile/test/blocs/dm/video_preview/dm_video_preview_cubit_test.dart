// ABOUTME: Unit tests for DmVideoPreviewCubit: the frame a trusted sender's
// ABOUTME: video DM card shows, now or once its video is played and kept.

import 'dart:async';
import 'dart:io';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/dm/video_preview/dm_video_preview_cubit.dart';
import 'package:openvine/services/dm_video_preview_memory.dart';
import 'package:openvine/services/dm_video_store.dart';

class _MockDmVideoStore extends Mock implements DmVideoStore {}

/// A memory whose plays a test announces, to see who listens to them.
class _PlaysMemory extends DmVideoPreviewMemory {
  final played = StreamController<String>.broadcast();

  @override
  Stream<String> get watched => played.stream;

  @override
  void dispose() {
    unawaited(played.close());
    super.dispose();
  }
}

const _framePath = '/kept/dm_videos/owner/clip.preview.jpg';

DmMessage _videoMessage({String? id, String? blurhash}) => DmMessage(
  id: id ?? 'a' * 64,
  conversationId: 'conversation',
  senderPubkey: 'b' * 64,
  content: 'https://blossom.example/encrypted',
  createdAt: 1757385263,
  giftWrapId: 'c' * 64,
  messageKind: 15,
  fileMetadata: DmFileMetadata(
    fileType: 'video/mp4',
    encryptionAlgorithm: 'aes-gcm',
    decryptionKey: '00',
    decryptionNonce: '00',
    fileHash: 'ab',
    blurhash: blurhash,
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
          expect(cubit.state.status, DmVideoPreviewStatus.none);
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

      test('does not start waiting when closed as its download ends', () async {
        final download = Completer<File?>();
        when(
          () => store.previewFor(
            any(),
            stillWanted: any(named: 'stillWanted'),
          ),
        ).thenAnswer((_) => download.future);
        final cubit = createCubit();
        final loading = cubit.load();

        // Completed first, so the load resumes ahead of anything close()
        // awaits before it closes.
        download.complete(null);
        final closing = cubit.close();
        await closing;
        await loading;

        expect(kept.hasListener, isFalse);
      });

      test('stops waiting when closed', () async {
        stubPreview(null);
        final cubit = createCubit();
        await cubit.load();
        expect(kept.hasListener, isTrue);

        await cubit.close();

        expect(kept.hasListener, isFalse);
      });
    });

    group('blurring until played', () {
      const frameBlurhash = 'LEHV6nWB2yk8';
      late Directory dir;
      late String keptFrame;
      late DmVideoPreviewMemory memory;
      late int encodes;

      setUp(() {
        dir = Directory.systemTemp.createTempSync('dm_preview_cubit_');
        keptFrame = (File(
          '${dir.path}/frame.jpg',
        )..writeAsBytesSync([1, 2, 3])).path;
        encodes = 0;
        memory = DmVideoPreviewMemory(
          encodeBlurhash: (_) async {
            encodes++;
            return frameBlurhash;
          },
        );
      });

      tearDown(() {
        memory.dispose();
        dir.deleteSync(recursive: true);
      });

      DmVideoPreviewCubit createBlurringCubit({
        DmMessage? message,
        bool blurUntilPlayed = true,
      }) => DmVideoPreviewCubit(
        message: message ?? _videoMessage(),
        store: store,
        memory: memory,
        blurUntilPlayed: blurUntilPlayed,
      );

      test('starts blurred', () {
        final cubit = createBlurringCubit();
        addTearDown(cubit.close);

        expect(cubit.state.blurred, isTrue);
      });

      test('starts with the blurhash already read from its frame', () async {
        await memory.frameBlurhashFor(
          messageId: 'a' * 64,
          framePath: keptFrame,
        );
        final cubit = createBlurringCubit();
        addTearDown(cubit.close);

        expect(cubit.state.frameBlurhash, frameBlurhash);
      });

      test('starts unblurred for a video played this session', () {
        memory.markWatched('a' * 64);
        final cubit = createBlurringCubit();
        addTearDown(cubit.close);

        expect(cubit.state.blurred, isFalse);
      });

      blocTest<DmVideoPreviewCubit, DmVideoPreviewState>(
        'unblurs once its video is played, not when another one is',
        build: createBlurringCubit,
        act: (cubit) async {
          memory.markWatched('f' * 64);
          await pumpEventQueue();
          expect(cubit.state.blurred, isTrue);
          memory.markWatched('a' * 64);
          await pumpEventQueue();
        },
        expect: () => [
          isA<DmVideoPreviewState>().having(
            (state) => state.blurred,
            'blurred',
            isFalse,
          ),
        ],
      );

      blocTest<DmVideoPreviewCubit, DmVideoPreviewState>(
        'reads a blurhash from the kept frame when the sender sent none',
        setUp: () => stubPreview(keptFrame),
        build: createBlurringCubit,
        act: (cubit) => cubit.load(),
        expect: () => [
          DmVideoPreviewState(
            status: DmVideoPreviewStatus.ready,
            framePath: keptFrame,
            blurred: true,
          ),
          DmVideoPreviewState(
            status: DmVideoPreviewStatus.ready,
            framePath: keptFrame,
            blurred: true,
            frameBlurhash: frameBlurhash,
          ),
        ],
      );

      blocTest<DmVideoPreviewCubit, DmVideoPreviewState>(
        "keeps the sender's blurhash instead of reading one",
        setUp: () => stubPreview(keptFrame),
        build: () => createBlurringCubit(
          message: _videoMessage(blurhash: 'L6Pj0^jE.AyE_3t7t7R**0o#DgR4'),
        ),
        act: (cubit) => cubit.load(),
        expect: () => [
          DmVideoPreviewState(
            status: DmVideoPreviewStatus.ready,
            framePath: keptFrame,
            blurred: true,
          ),
        ],
        verify: (_) => expect(encodes, equals(0)),
      );

      blocTest<DmVideoPreviewCubit, DmVideoPreviewState>(
        'reads no blurhash for a card that is not blurred',
        setUp: () => stubPreview(keptFrame),
        build: () => createBlurringCubit(blurUntilPlayed: false),
        act: (cubit) => cubit.load(),
        expect: () => [
          DmVideoPreviewState(
            status: DmVideoPreviewStatus.ready,
            framePath: keptFrame,
          ),
        ],
        verify: (_) => expect(encodes, equals(0)),
      );

      test('stops listening for plays once closed', () async {
        final plays = _PlaysMemory();
        addTearDown(plays.dispose);
        final cubit = DmVideoPreviewCubit(
          message: _videoMessage(),
          store: store,
          memory: plays,
          blurUntilPlayed: true,
        );
        expect(plays.played.hasListener, isTrue);

        await cubit.close();

        expect(plays.played.hasListener, isFalse);
      });
    });
  });
}
