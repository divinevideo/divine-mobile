// ABOUTME: Tests reading who joined an Add yours or replied to a video for its
// ABOUTME: sticker: the feeds' filter applied, hidden replies left out, pins first.

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/sticker_responses/sticker_responses_cubit.dart';
import 'package:video_responses_repository/video_responses_repository.dart';

class _MockVideoResponsesRepository extends Mock
    implements VideoResponsesRepository {}

String _hex(int n) => n.toRadixString(16).padLeft(64, '0');

final String _creator = _hex(1);

VideoEvent _video(int id, {String? pubkey, String? dTag, int? eventKind}) =>
    VideoEvent(
      id: _hex(id),
      pubkey: pubkey ?? _hex(1000 + id),
      createdAt: 1000 - id,
      content: '',
      timestamp: DateTime.fromMillisecondsSinceEpoch(0),
      vineId: dTag,
      addressableDTag: dTag,
      eventKind: eventKind,
    );

VideoStickerRegion _region(VideoStickerKind kind, {String target = ''}) =>
    VideoStickerRegion(
      kind: kind,
      target: target,
      centerX: 0.5,
      centerY: 0.5,
      width: 0.6,
      height: 0.3,
      label: kind == VideoStickerKind.prompt
          ? 'Show your desk\ndesksetup'
          : 'Reply with a video',
    );

void main() {
  group(StickerResponsesCubit, () {
    late _MockVideoResponsesRepository repository;
    late StickerResponsesFilter filter;
    final root = _video(100, pubkey: _creator, dTag: 'root-d');
    final rootAddress = root.addressableId!;

    setUp(() {
      repository = _MockVideoResponsesRepository();
      filter = (videos) => videos;
    });

    StickerResponsesCubit build(VideoStickerRegion region, {VideoEvent? on}) =>
        StickerResponsesCubit(
          repository: repository,
          filter: (videos) => filter(videos),
          video: on ?? root,
          region: region,
        );

    group('load', () {
      blocTest<StickerResponsesCubit, StickerResponsesState>(
        'shows the replies with the pinned one first, without the hidden '
        'ones or any the feeds leave out, and counts them out',
        setUp: () {
          when(
            () => repository.fetchReplies(
              videoId: any(named: 'videoId'),
              videoAddress: any(named: 'videoAddress'),
              limit: any(named: 'limit'),
            ),
          ).thenAnswer(
            (_) async => VideoResponses(
              total: 10,
              videos: [_video(1), _video(2), _video(3), _video(4)],
            ),
          );
          when(
            () => repository.fetchCuration(
              creatorPubkey: _creator,
              videoAddress: rootAddress,
            ),
          ).thenAnswer(
            (_) async =>
                RepliesCuration(pinnedId: _hex(3), hiddenIds: {_hex(2)}),
          );
          // The feeds' filter: blocks and mutes either way, content filters.
          filter = (videos) => [
            for (final video in videos)
              if (video.pubkey != _hex(1004)) video,
          ];
        },
        build: () => build(_region(VideoStickerKind.replies)),
        act: (cubit) => cubit.load(),
        expect: () => [
          const StickerResponsesState(status: StickerResponsesStatus.loading),
          StickerResponsesState(
            status: StickerResponsesStatus.loaded,
            total: 8,
            videos: [_video(3), _video(1)],
            curation: RepliesCuration(pinnedId: _hex(3), hiddenIds: {_hex(2)}),
          ),
        ],
        verify: (_) => verify(
          () => repository.fetchReplies(
            videoId: root.id,
            videoAddress: rootAddress,
            limit: StickerResponsesCubit.feedLimit,
          ),
        ).called(1),
      );

      blocTest<StickerResponsesCubit, StickerResponsesState>(
        'leaves out the replies of the accounts the creator blocked, but '
        'one they showed again, and counts them out',
        setUp: () {
          when(
            () => repository.fetchReplies(
              videoId: any(named: 'videoId'),
              videoAddress: any(named: 'videoAddress'),
              limit: any(named: 'limit'),
            ),
          ).thenAnswer(
            (_) async => VideoResponses(
              total: 5,
              videos: [
                _video(1),
                _video(2),
                _video(3, pubkey: _hex(1002)),
              ],
            ),
          );
          when(
            () => repository.fetchCuration(
              creatorPubkey: _creator,
              videoAddress: rootAddress,
            ),
          ).thenAnswer(
            (_) async => RepliesCuration(
              restoredIds: {_hex(3)},
              hiddenAuthors: {_hex(1002)},
            ),
          );
        },
        build: () => build(_region(VideoStickerKind.replies)),
        act: (cubit) => cubit.load(),
        skip: 1,
        expect: () => [
          StickerResponsesState(
            status: StickerResponsesStatus.loaded,
            total: 4,
            videos: [
              _video(1),
              _video(3, pubkey: _hex(1002)),
            ],
            curation: RepliesCuration(
              restoredIds: {_hex(3)},
              hiddenAuthors: {_hex(1002)},
            ),
          ),
        ],
      );

      group('with a pin older than the replies read', () {
        setUp(() {
          when(
            () => repository.fetchReplies(
              videoId: any(named: 'videoId'),
              videoAddress: any(named: 'videoAddress'),
              limit: any(named: 'limit'),
            ),
          ).thenAnswer(
            (_) async =>
                VideoResponses(total: 10, videos: [_video(1), _video(2)]),
          );
          when(
            () => repository.fetchCuration(
              creatorPubkey: _creator,
              videoAddress: rootAddress,
            ),
          ).thenAnswer((_) async => RepliesCuration(pinnedId: _hex(9)));
        });

        blocTest<StickerResponsesCubit, StickerResponsesState>(
          'reads the pinned reply on its own and shows it first',
          setUp: () => when(
            () => repository.fetchReply(
              _hex(9),
              videoId: root.id,
              videoAddress: rootAddress,
            ),
          ).thenAnswer((_) async => _video(9)),
          build: () => build(_region(VideoStickerKind.replies)),
          act: (cubit) => cubit.load(),
          skip: 1,
          expect: () => [
            StickerResponsesState(
              status: StickerResponsesStatus.loaded,
              total: 10,
              videos: [_video(9), _video(1), _video(2)],
              curation: RepliesCuration(pinnedId: _hex(9)),
            ),
          ],
        );

        blocTest<StickerResponsesCubit, StickerResponsesState>(
          'keeps a count the relays cut off as a floor',
          setUp: () {
            when(
              () => repository.fetchReplies(
                videoId: any(named: 'videoId'),
                videoAddress: any(named: 'videoAddress'),
                limit: any(named: 'limit'),
              ),
            ).thenAnswer(
              (_) async => VideoResponses(
                total: 500,
                videos: [_video(1), _video(2)],
                totalIsAtLeast: true,
              ),
            );
            when(
              () => repository.fetchReply(
                _hex(9),
                videoId: root.id,
                videoAddress: rootAddress,
              ),
            ).thenAnswer((_) async => _video(9));
          },
          build: () => build(_region(VideoStickerKind.replies)),
          act: (cubit) => cubit.load(),
          skip: 1,
          verify: (cubit) {
            expect(cubit.state.videos.first, equals(_video(9)));
            expect(cubit.state.totalIsAtLeast, isTrue);
          },
        );

        blocTest<StickerResponsesCubit, StickerResponsesState>(
          'shows the replies read when the pinned one is gone',
          setUp: () => when(
            () => repository.fetchReply(
              _hex(9),
              videoId: root.id,
              videoAddress: rootAddress,
            ),
          ).thenAnswer((_) async => null),
          build: () => build(_region(VideoStickerKind.replies)),
          act: (cubit) => cubit.load(),
          skip: 1,
          expect: () => [
            StickerResponsesState(
              status: StickerResponsesStatus.loaded,
              total: 10,
              videos: [_video(1), _video(2)],
              curation: RepliesCuration(pinnedId: _hex(9)),
            ),
          ],
        );

        blocTest<StickerResponsesCubit, StickerResponsesState>(
          'leaves out a pinned reply the feeds leave out, and its count',
          setUp: () {
            when(
              () => repository.fetchReply(
                _hex(9),
                videoId: root.id,
                videoAddress: rootAddress,
              ),
            ).thenAnswer((_) async => _video(9));
            filter = (videos) => [
              for (final video in videos)
                if (video.id != _hex(9)) video,
            ];
          },
          build: () => build(_region(VideoStickerKind.replies)),
          act: (cubit) => cubit.load(),
          skip: 1,
          expect: () => [
            StickerResponsesState(
              status: StickerResponsesStatus.loaded,
              total: 9,
              videos: [_video(1), _video(2)],
              curation: RepliesCuration(pinnedId: _hex(9)),
            ),
          ],
        );
      });

      blocTest<StickerResponsesCubit, StickerResponsesState>(
        'keeps the warnings the filter puts on a response, to blur it',
        setUp: () {
          when(
            () => repository.fetchJoined(
              chainRoot: any(named: 'chainRoot'),
              hashtag: any(named: 'hashtag'),
              limit: any(named: 'limit'),
              filter: any(named: 'filter'),
            ),
          ).thenAnswer(
            (_) async => VideoResponses(total: 1, videos: [_video(1)]),
          );
          filter = (videos) => [
            for (final video in videos) video.copyWith(warnLabels: ['nudity']),
          ];
        },
        build: () => build(_region(VideoStickerKind.prompt)),
        act: (cubit) => cubit.load(),
        skip: 1,
        verify: (cubit) {
          expect(cubit.state.videos.single.warnLabels, equals(['nudity']));
          expect(cubit.state.videos.single.shouldShowWarning, isTrue);
        },
      );

      blocTest<StickerResponsesCubit, StickerResponsesState>(
        'reads no curation for a video with no address',
        setUp: () =>
            when(
              () => repository.fetchReplies(
                videoId: any(named: 'videoId'),
                videoAddress: any(named: 'videoAddress'),
                limit: any(named: 'limit'),
              ),
            ).thenAnswer(
              (_) async => VideoResponses(total: 1, videos: [_video(1)]),
            ),
        build: () => build(_region(VideoStickerKind.replies), on: _video(100)),
        act: (cubit) => cubit.load(),
        skip: 1,
        expect: () => [
          StickerResponsesState(
            status: StickerResponsesStatus.loaded,
            total: 1,
            videos: [_video(1)],
          ),
        ],
        verify: (_) => verifyNever(
          () => repository.fetchCuration(
            creatorPubkey: any(named: 'creatorPubkey'),
            videoAddress: any(named: 'videoAddress'),
          ),
        ),
      );

      blocTest<StickerResponsesCubit, StickerResponsesState>(
        'reads and joins the chain of a Kind 34235 video under the 34236 key '
        'answers already cite (#10776)',
        setUp: () =>
            when(
              () => repository.fetchJoined(
                chainRoot: any(named: 'chainRoot'),
                hashtag: any(named: 'hashtag'),
                limit: any(named: 'limit'),
                filter: any(named: 'filter'),
              ),
            ).thenAnswer(
              (_) async => VideoResponses(total: 1, videos: [_video(5)]),
            ),
        build: () => build(
          _region(VideoStickerKind.prompt),
          on: _video(100, pubkey: _creator, dTag: 'normal-d', eventKind: 34235),
        ),
        act: (cubit) => cubit.load(),
        skip: 1,
        expect: () => [
          StickerResponsesState(
            status: StickerResponsesStatus.loaded,
            total: 1,
            videos: [_video(5)],
            chainRoot: '34236:$_creator:normal-d',
          ),
        ],
        verify: (_) => verify(
          () => repository.fetchJoined(
            chainRoot: '34236:$_creator:normal-d',
            hashtag: 'desksetup',
            limit: StickerResponsesCubit.feedLimit,
            filter: any(named: 'filter'),
          ),
        ).called(1),
      );

      blocTest<StickerResponsesCubit, StickerResponsesState>(
        'reads who joined the chain an Add yours starts',
        setUp: () =>
            when(
              () => repository.fetchJoined(
                chainRoot: any(named: 'chainRoot'),
                hashtag: any(named: 'hashtag'),
                limit: any(named: 'limit'),
                filter: any(named: 'filter'),
              ),
            ).thenAnswer(
              (_) async => VideoResponses(total: 3, videos: [_video(5)]),
            ),
        build: () => build(_region(VideoStickerKind.prompt)),
        act: (cubit) => cubit.load(),
        skip: 1,
        expect: () => [
          StickerResponsesState(
            status: StickerResponsesStatus.loaded,
            total: 3,
            videos: [_video(5)],
            chainRoot: rootAddress,
          ),
        ],
        verify: (_) {
          verify(
            () => repository.fetchJoined(
              chainRoot: rootAddress,
              hashtag: 'desksetup',
              limit: StickerResponsesCubit.feedLimit,
              filter: any(named: 'filter'),
            ),
          ).called(1);
          // The first video of its own chain is not checked.
          verifyNever(
            () => repository.chainStart(
              any(),
              hashtag: any(named: 'hashtag'),
            ),
          );
        },
      );

      blocTest<StickerResponsesCubit, StickerResponsesState>(
        "hands the joined read the viewer's filter, so each person's answer "
        'is picked from what the viewer may see',
        setUp: () {
          filter = (videos) => [
            for (final video in videos)
              if (video.id != _video(6).id) video,
          ];
          when(
            () => repository.fetchJoined(
              chainRoot: any(named: 'chainRoot'),
              hashtag: any(named: 'hashtag'),
              limit: any(named: 'limit'),
              filter: any(named: 'filter'),
            ),
          ).thenAnswer((_) async => const VideoResponses());
        },
        build: () => build(_region(VideoStickerKind.prompt)),
        act: (cubit) => cubit.load(),
        verify: (_) {
          final handed =
              verify(
                    () => repository.fetchJoined(
                      chainRoot: any(named: 'chainRoot'),
                      hashtag: any(named: 'hashtag'),
                      limit: any(named: 'limit'),
                      filter: captureAny(named: 'filter'),
                    ),
                  ).captured.single
                  as StickerResponsesFilter;
          expect(handed([_video(5), _video(6)]), equals([_video(5)]));
        },
      );

      blocTest<StickerResponsesCubit, StickerResponsesState>(
        'says when the count is only a floor',
        setUp: () =>
            when(
              () => repository.fetchJoined(
                chainRoot: any(named: 'chainRoot'),
                hashtag: any(named: 'hashtag'),
                limit: any(named: 'limit'),
                filter: any(named: 'filter'),
              ),
            ).thenAnswer(
              (_) async => VideoResponses(
                total: 500,
                videos: [_video(5)],
                totalIsAtLeast: true,
              ),
            ),
        build: () => build(_region(VideoStickerKind.prompt)),
        act: (cubit) => cubit.load(),
        skip: 1,
        verify: (cubit) {
          expect(cubit.state.total, equals(500));
          expect(cubit.state.totalIsAtLeast, isTrue);
        },
      );

      group('on an answer naming the first video', () {
        final first = '34236:$_creator:first';

        setUp(
          () => when(
            () => repository.fetchJoined(
              chainRoot: any(named: 'chainRoot'),
              hashtag: any(named: 'hashtag'),
              limit: any(named: 'limit'),
              filter: any(named: 'filter'),
            ),
          ).thenAnswer((_) async => const VideoResponses()),
        );

        blocTest<StickerResponsesCubit, StickerResponsesState>(
          'reads the chain the answer joined, not the answer itself',
          setUp: () => when(
            () => repository.chainStart(first, hashtag: 'desksetup'),
          ).thenAnswer((_) async => AddYoursChainStart.starts),
          build: () => build(_region(VideoStickerKind.prompt, target: first)),
          act: (cubit) => cubit.load(),
          verify: (cubit) {
            expect(cubit.state.chainRoot, equals(first));
            verify(
              () => repository.fetchJoined(
                chainRoot: first,
                hashtag: 'desksetup',
                limit: StickerResponsesCubit.feedLimit,
                filter: any(named: 'filter'),
              ),
            ).called(1);
          },
        );

        blocTest<StickerResponsesCubit, StickerResponsesState>(
          'counts the named chain but offers no Join while a relay that did '
          'not answer may hold the named video',
          setUp: () => when(
            () => repository.chainStart(first, hashtag: 'desksetup'),
          ).thenAnswer((_) async => AddYoursChainStart.unconfirmed),
          build: () => build(_region(VideoStickerKind.prompt, target: first)),
          act: (cubit) => cubit.load(),
          verify: (cubit) {
            expect(cubit.state.status, equals(StickerResponsesStatus.loaded));
            expect(cubit.state.chainRoot, isNull);
            verify(
              () => repository.fetchJoined(
                chainRoot: first,
                hashtag: 'desksetup',
                limit: StickerResponsesCubit.feedLimit,
                filter: any(named: 'filter'),
              ),
            ).called(1);
          },
        );

        blocTest<StickerResponsesCubit, StickerResponsesState>(
          'fails, offering no chain to join, when no relay could be asked',
          setUp: () =>
              when(
                () => repository.chainStart(first, hashtag: 'desksetup'),
              ).thenThrow(
                const AddYoursChainUnavailableException(
                  'No relay could be asked',
                ),
              ),
          build: () => build(_region(VideoStickerKind.prompt, target: first)),
          act: (cubit) => cubit.load(),
          errors: () => [isA<AddYoursChainUnavailableException>()],
          verify: (cubit) {
            expect(cubit.state.status, equals(StickerResponsesStatus.failure));
            expect(cubit.state.chainRoot, isNull);
            verifyNever(
              () => repository.fetchJoined(
                chainRoot: any(named: 'chainRoot'),
                hashtag: any(named: 'hashtag'),
                limit: any(named: 'limit'),
                filter: any(named: 'filter'),
              ),
            );
          },
        );

        blocTest<StickerResponsesCubit, StickerResponsesState>(
          'starts its own chain when the named video starts none',
          setUp: () => when(
            () => repository.chainStart(first, hashtag: 'desksetup'),
          ).thenAnswer((_) async => AddYoursChainStart.doesNotStart),
          build: () => build(_region(VideoStickerKind.prompt, target: first)),
          act: (cubit) => cubit.load(),
          verify: (cubit) {
            expect(cubit.state.chainRoot, equals(rootAddress));
            verify(
              () => repository.fetchJoined(
                chainRoot: rootAddress,
                hashtag: 'desksetup',
                limit: StickerResponsesCubit.feedLimit,
                filter: any(named: 'filter'),
              ),
            ).called(1);
          },
        );
      });

      blocTest<StickerResponsesCubit, StickerResponsesState>(
        'shows nobody for an Add yours on a video with no address',
        build: () => build(_region(VideoStickerKind.prompt), on: _video(100)),
        act: (cubit) => cubit.load(),
        skip: 1,
        expect: () => [
          const StickerResponsesState(status: StickerResponsesStatus.loaded),
        ],
      );

      blocTest<StickerResponsesCubit, StickerResponsesState>(
        'tells when the responses could not be read',
        setUp: () => when(
          () => repository.fetchJoined(
            chainRoot: any(named: 'chainRoot'),
            hashtag: any(named: 'hashtag'),
            limit: any(named: 'limit'),
            filter: any(named: 'filter'),
          ),
        ).thenThrow(Exception('offline')),
        build: () => build(_region(VideoStickerKind.prompt)),
        act: (cubit) => cubit.load(),
        skip: 1,
        expect: () => [
          const StickerResponsesState(status: StickerResponsesStatus.failure),
        ],
        errors: () => [isA<Exception>()],
      );

      blocTest<StickerResponsesCubit, StickerResponsesState>(
        "shows no replies when the creator's hides could not be read",
        setUp: () {
          when(
            () => repository.fetchReplies(
              videoId: any(named: 'videoId'),
              videoAddress: any(named: 'videoAddress'),
              limit: any(named: 'limit'),
            ),
          ).thenAnswer(
            (_) async =>
                VideoResponses(total: 2, videos: [_video(1), _video(2)]),
          );
          when(
            () => repository.fetchCuration(
              creatorPubkey: _creator,
              videoAddress: rootAddress,
            ),
          ).thenThrow(
            const RepliesCurationUnavailableException('The relays timed out'),
          );
        },
        build: () => build(_region(VideoStickerKind.replies)),
        act: (cubit) => cubit.load(),
        skip: 1,
        // Without the curation a reply the creator hid would show again.
        expect: () => [
          const StickerResponsesState(status: StickerResponsesStatus.failure),
        ],
        errors: () => [isA<RepliesCurationUnavailableException>()],
      );
    });
  });
}
