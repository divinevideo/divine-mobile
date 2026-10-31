// ABOUTME: Tests a creator managing their video replies: reading them, pinning
// ABOUTME: one to the front, hiding one, and going back when a save fails.

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/video_replies/video_replies_cubit.dart';
import 'package:video_responses_repository/video_responses_repository.dart';

class _MockVideoResponsesRepository extends Mock
    implements VideoResponsesRepository {}

String _hex(int n) => n.toRadixString(16).padLeft(64, '0');

final String _creator = _hex(1);
final String _address = '34236:$_creator:root-d';

VideoEvent _reply(int id) => VideoEvent(
  id: _hex(id),
  pubkey: _hex(1000 + id),
  createdAt: 1000 - id,
  content: '',
  timestamp: DateTime.fromMillisecondsSinceEpoch(0),
);

void main() {
  group(VideoRepliesCubit, () {
    late _MockVideoResponsesRepository repository;

    setUpAll(() => registerFallbackValue(const RepliesCuration()));

    setUp(() {
      repository = _MockVideoResponsesRepository();
      when(
        () => repository.saveCuration(
          any(),
          videoAddress: any(named: 'videoAddress'),
        ),
      ).thenAnswer((_) async {});
    });

    VideoRepliesCubit build() => VideoRepliesCubit(
      repository: repository,
      videoId: _hex(100),
      videoAddress: _address,
      creatorPubkey: _creator,
    );

    final loaded = VideoRepliesState(
      status: VideoRepliesStatus.loaded,
      replies: [_reply(1), _reply(2)],
    );

    group('load', () {
      blocTest<VideoRepliesCubit, VideoRepliesState>(
        'reads every reply and how they are curated',
        setUp: () {
          when(
            () => repository.fetchReplies(
              videoId: any(named: 'videoId'),
              videoAddress: any(named: 'videoAddress'),
              limit: any(named: 'limit'),
            ),
          ).thenAnswer(
            (_) async =>
                VideoResponses(total: 2, videos: [_reply(1), _reply(2)]),
          );
          when(
            () => repository.fetchCuration(
              creatorPubkey: _creator,
              videoAddress: _address,
            ),
          ).thenAnswer((_) async => RepliesCuration(hiddenIds: {_hex(1)}));
        },
        build: build,
        act: (cubit) => cubit.load(),
        expect: () => [
          const VideoRepliesState(),
          loaded.copyWith(curation: RepliesCuration(hiddenIds: {_hex(1)})),
        ],
        verify: (cubit) {
          expect(cubit.state.shown, equals([_reply(2)]));
          verify(
            () => repository.fetchReplies(
              videoId: _hex(100),
              videoAddress: _address,
              limit: VideoRepliesCubit.maxReplies,
            ),
          ).called(1);
        },
      );

      blocTest<VideoRepliesCubit, VideoRepliesState>(
        'tells when the replies could not be read',
        setUp: () => when(
          () => repository.fetchReplies(
            videoId: any(named: 'videoId'),
            videoAddress: any(named: 'videoAddress'),
            limit: any(named: 'limit'),
          ),
        ).thenThrow(Exception('offline')),
        build: build,
        act: (cubit) => cubit.load(),
        skip: 1,
        expect: () => [
          const VideoRepliesState(status: VideoRepliesStatus.failure),
        ],
        errors: () => [isA<Exception>()],
      );
    });

    group('pinToggled', () {
      blocTest<VideoRepliesCubit, VideoRepliesState>(
        'pins a reply, then unpins it',
        build: build,
        seed: () => loaded,
        act: (cubit) async {
          await cubit.pinToggled(_hex(2));
          await cubit.pinToggled(_hex(2));
        },
        expect: () => [
          loaded.copyWith(
            curation: RepliesCuration(pinnedId: _hex(2)),
            saveStatus: VideoRepliesSaveStatus.saving,
          ),
          loaded.copyWith(curation: RepliesCuration(pinnedId: _hex(2))),
          loaded.copyWith(saveStatus: VideoRepliesSaveStatus.saving),
          loaded,
        ],
        verify: (_) => verify(
          () => repository.saveCuration(
            RepliesCuration(pinnedId: _hex(2)),
            videoAddress: _address,
          ),
        ).called(1),
      );

      blocTest<VideoRepliesCubit, VideoRepliesState>(
        'saves one change at a time',
        build: build,
        seed: () => loaded.copyWith(saveStatus: VideoRepliesSaveStatus.saving),
        act: (cubit) => cubit.pinToggled(_hex(2)),
        expect: () => const <VideoRepliesState>[],
      );
    });

    group('hideToggled', () {
      blocTest<VideoRepliesCubit, VideoRepliesState>(
        'hides a reply, then shows it again',
        build: build,
        seed: () => loaded,
        act: (cubit) async {
          await cubit.hideToggled(_hex(1));
          await cubit.hideToggled(_hex(1));
        },
        skip: 1,
        expect: () => [
          loaded.copyWith(curation: RepliesCuration(hiddenIds: {_hex(1)})),
          loaded.copyWith(saveStatus: VideoRepliesSaveStatus.saving),
          loaded,
        ],
      );

      blocTest<VideoRepliesCubit, VideoRepliesState>(
        'goes back to how it was when the change could not be saved',
        setUp: () => when(
          () => repository.saveCuration(
            any(),
            videoAddress: any(named: 'videoAddress'),
          ),
        ).thenThrow(const RepliesCurationException('blocked')),
        build: build,
        seed: () => loaded,
        act: (cubit) => cubit.hideToggled(_hex(1)),
        skip: 1,
        expect: () => [
          loaded.copyWith(saveStatus: VideoRepliesSaveStatus.failed),
        ],
        errors: () => [isA<RepliesCurationException>()],
      );
    });
  });
}
