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

VideoEvent _video(int id, {String? pubkey, String? dTag}) => VideoEvent(
  id: _hex(id),
  pubkey: pubkey ?? _hex(1000 + id),
  createdAt: 1000 - id,
  content: '',
  timestamp: DateTime.fromMillisecondsSinceEpoch(0),
  vineId: dTag,
  addressableDTag: dTag,
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
        'keeps the warnings the filter puts on a response, to blur it',
        setUp: () {
          when(
            () => repository.fetchJoined(
              chainRoot: any(named: 'chainRoot'),
              hashtag: any(named: 'hashtag'),
              limit: any(named: 'limit'),
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
        'reads who joined the chain an Add yours starts',
        setUp: () =>
            when(
              () => repository.fetchJoined(
                chainRoot: any(named: 'chainRoot'),
                hashtag: any(named: 'hashtag'),
                limit: any(named: 'limit'),
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
          ),
        ],
        verify: (_) => verify(
          () => repository.fetchJoined(
            chainRoot: rootAddress,
            hashtag: 'desksetup',
            limit: StickerResponsesCubit.feedLimit,
          ),
        ).called(1),
      );

      blocTest<StickerResponsesCubit, StickerResponsesState>(
        'reads the chain an answer joined, not the answer itself',
        setUp: () => when(
          () => repository.fetchJoined(
            chainRoot: any(named: 'chainRoot'),
            hashtag: any(named: 'hashtag'),
            limit: any(named: 'limit'),
          ),
        ).thenAnswer((_) async => const VideoResponses()),
        build: () => build(
          _region(VideoStickerKind.prompt, target: '34236:$_creator:first'),
        ),
        act: (cubit) => cubit.load(),
        verify: (_) => verify(
          () => repository.fetchJoined(
            chainRoot: '34236:$_creator:first',
            hashtag: 'desksetup',
            limit: StickerResponsesCubit.feedLimit,
          ),
        ).called(1),
      );

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
