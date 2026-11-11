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

/// A reply published at an address, which its author can replace.
final VideoEvent _addressableReply = VideoEvent(
  id: _hex(9),
  pubkey: _hex(1009),
  createdAt: 991,
  content: '',
  timestamp: DateTime.fromMillisecondsSinceEpoch(0),
  vineId: 'reply-d',
  addressableDTag: 'reply-d',
);

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
    late RepliesWarnings warnings;

    setUpAll(() {
      registerFallbackValue(const RepliesCuration());
      registerFallbackValue(<String>{});
    });

    setUp(() {
      repository = _MockVideoResponsesRepository();
      warnings = (replies) => replies;
      when(
        () => repository.saveCuration(
          any(),
          videoAddress: any(named: 'videoAddress'),
          previous: any(named: 'previous'),
          takenBackRestores: any(named: 'takenBackRestores'),
        ),
      ).thenAnswer(
        (call) async => call.positionalArguments.first as RepliesCuration,
      );
    });

    VideoRepliesCubit build() => VideoRepliesCubit(
      repository: repository,
      warnings: (replies) => warnings(replies),
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
        "puts the creator's warnings on each reply, leaving none out",
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
          ).thenAnswer((_) async => const RepliesCuration());
          warnings = (replies) => [
            for (final reply in replies)
              if (reply.id == _hex(2))
                reply.copyWith(warnLabels: ['nudity'])
              else
                reply,
          ];
        },
        build: build,
        act: (cubit) => cubit.load(),
        skip: 1,
        verify: (cubit) => expect(
          cubit.state.replies.map((reply) => reply.shouldShowWarning),
          equals([false, true]),
        ),
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

      blocTest<VideoRepliesCubit, VideoRepliesState>(
        'tells when the curation could not be read, rather than showing none',
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
          ).thenThrow(
            const RepliesCurationUnavailableException('The relays timed out'),
          );
        },
        build: build,
        act: (cubit) => cubit.load(),
        skip: 1,
        // Loaded with an empty curation, the creator's next pin would publish
        // over the replies they hid.
        expect: () => [
          const VideoRepliesState(status: VideoRepliesStatus.failure),
        ],
        errors: () => [isA<RepliesCurationUnavailableException>()],
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
            previous: const RepliesCuration(),
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

      blocTest<VideoRepliesCubit, VideoRepliesState>(
        'shows the reply of an account the creator blocked when pinning it',
        build: build,
        seed: () => loaded.copyWith(
          curation: RepliesCuration(hiddenAuthors: {_hex(1001)}),
        ),
        act: (cubit) => cubit.pinToggled(_hex(1)),
        skip: 1,
        expect: () => [
          loaded.copyWith(
            curation: RepliesCuration(
              pinnedId: _hex(1),
              restoredIds: {_hex(1)},
              hiddenAuthors: {_hex(1001)},
            ),
          ),
        ],
      );
    });

    group('hideToggled', () {
      blocTest<VideoRepliesCubit, VideoRepliesState>(
        'adopts the complete curation reconciled with another device',
        setUp: () =>
            when(
              () => repository.saveCuration(
                any(),
                videoAddress: _address,
                previous: const RepliesCuration(),
                takenBackRestores: any(named: 'takenBackRestores'),
              ),
            ).thenAnswer(
              (_) async => RepliesCuration(
                hiddenIds: {_hex(1), _hex(3)},
                pinnedId: _hex(2),
              ),
            ),
        build: build,
        seed: () => loaded,
        act: (cubit) => cubit.hideToggled(_hex(1)),
        skip: 1,
        expect: () => [
          loaded.copyWith(
            curation: RepliesCuration(
              hiddenIds: {_hex(1), _hex(3)},
              pinnedId: _hex(2),
            ),
          ),
        ],
      );

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
        'approves the version shown of an addressable reply, not its address',
        build: build,
        seed: () => VideoRepliesState(
          status: VideoRepliesStatus.loaded,
          replies: [_addressableReply],
          curation: RepliesCuration(hiddenAuthors: {_hex(1009)}),
        ),
        act: (cubit) =>
            cubit.hideToggled(RepliesCuration.keyOf(_addressableReply)),
        skip: 1,
        expect: () => [
          VideoRepliesState(
            status: VideoRepliesStatus.loaded,
            replies: [_addressableReply],
            curation: RepliesCuration(
              restoredIds: {_hex(9)},
              hiddenAuthors: {_hex(1009)},
            ),
          ),
        ],
        // Showing must not take back the restore it adds: left out,
        // takenBackRestores is expected at its empty default.
        verify: (_) => verify(
          () => repository.saveCuration(
            any(),
            videoAddress: _address,
            previous: any(named: 'previous'),
          ),
        ).called(1),
      );

      blocTest<VideoRepliesCubit, VideoRepliesState>(
        'takes back a restore of the hidden version made on another device',
        build: build,
        seed: () => VideoRepliesState(
          status: VideoRepliesStatus.loaded,
          replies: [_addressableReply],
        ),
        act: (cubit) =>
            cubit.hideToggled(RepliesCuration.keyOf(_addressableReply)),
        verify: (_) => verify(
          () => repository.saveCuration(
            any(),
            videoAddress: _address,
            previous: const RepliesCuration(),
            takenBackRestores: {_hex(9)},
          ),
        ).called(1),
      );

      blocTest<VideoRepliesCubit, VideoRepliesState>(
        'shows the reply of an account the creator blocked again, then hides '
        'it',
        build: build,
        seed: () => loaded.copyWith(
          curation: RepliesCuration(hiddenAuthors: {_hex(1001)}),
        ),
        act: (cubit) async {
          await cubit.hideToggled(_hex(1));
          await cubit.hideToggled(_hex(1));
        },
        skip: 1,
        expect: () => [
          loaded.copyWith(
            curation: RepliesCuration(
              restoredIds: {_hex(1)},
              hiddenAuthors: {_hex(1001)},
            ),
          ),
          loaded.copyWith(
            curation: RepliesCuration(
              hiddenIds: {_hex(1)},
              hiddenAuthors: {_hex(1001)},
            ),
            saveStatus: VideoRepliesSaveStatus.saving,
          ),
          loaded.copyWith(
            curation: RepliesCuration(
              hiddenIds: {_hex(1)},
              hiddenAuthors: {_hex(1001)},
            ),
          ),
        ],
      );

      blocTest<VideoRepliesCubit, VideoRepliesState>(
        'goes back to how it was when the change could not be saved',
        setUp: () => when(
          () => repository.saveCuration(
            any(),
            videoAddress: any(named: 'videoAddress'),
            previous: any(named: 'previous'),
            takenBackRestores: any(named: 'takenBackRestores'),
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

      blocTest<VideoRepliesCubit, VideoRepliesState>(
        'goes back and takes the next change after any failed save',
        setUp: () => when(
          () => repository.saveCuration(
            any(),
            videoAddress: any(named: 'videoAddress'),
            previous: any(named: 'previous'),
            takenBackRestores: any(named: 'takenBackRestores'),
          ),
        ).thenThrow(StateError('signer gone')),
        build: build,
        seed: () => loaded,
        act: (cubit) => cubit.hideToggled(_hex(1)),
        skip: 1,
        // Left at saving, the page would show the unsaved hide as done and
        // drop every later pin or hide.
        expect: () => [
          loaded.copyWith(saveStatus: VideoRepliesSaveStatus.failed),
        ],
        errors: () => [isA<StateError>()],
      );
    });
  });
}
