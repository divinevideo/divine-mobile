// ABOUTME: Unit tests for VideoLinkPreviewCubit.
// ABOUTME: Tests repository-delegated resolve, hydration, fallback, not-found.

import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/nostr_sdk.dart';
import 'package:openvine/screens/inbox/conversation/widgets/video_link_preview_cubit.dart';
import 'package:videos_repository/videos_repository.dart';

import '../../../../helpers/stored_relay_events.dart';

class _MockVideosRepository extends Mock implements VideosRepository {}

class _MockNostrClient extends Mock implements NostrClient {}

void main() {
  setUpAll(() {
    registerFallbackValue(<String>[]);
    registerFallbackValue(<Filter>[]);
  });

  group(VideoLinkPreviewCubit, () {
    late _MockVideosRepository mockVideosRepository;

    // Carries a hydrated `views` tag so totalLoops is non-zero: the exact
    // count the shared-video card and detail screen must surface (see #5844).
    final testVideo = VideoEvent(
      id:
          '0123456789abcdef0123456789abcdef'
          '0123456789abcdef0123456789abcdef',
      pubkey:
          'abcdef0123456789abcdef0123456789'
          'abcdef0123456789abcdef0123456789',
      createdAt: 1757385263,
      content: 'Test',
      timestamp: DateTime.fromMillisecondsSinceEpoch(1757385263 * 1000),
      title: 'My Cool Video',
      rawTags: const {'views': '1234'},
    );

    setUp(() {
      mockVideosRepository = _MockVideosRepository();

      // Default: repository resolves nothing.
      when(
        () => mockVideosRepository.fetchVideoWithStatsForRouteId(
          any(),
          fallbackRouteIds: any(named: 'fallbackRouteIds'),
        ),
      ).thenAnswer((_) async => null);
    });

    VideoLinkPreviewCubit createCubit({String stableId = 'test-id'}) =>
        VideoLinkPreviewCubit(
          videoStableId: stableId,
          videosRepository: mockVideosRepository,
        );

    group('resolve', () {
      blocTest<VideoLinkPreviewCubit, VideoLinkPreviewState>(
        'emits $VideoLinkPreviewResolved with the repository-hydrated video',
        setUp: () {
          when(
            () => mockVideosRepository.fetchVideoWithStatsForRouteId(
              'test-id',
              fallbackRouteIds: any(named: 'fallbackRouteIds'),
            ),
          ).thenAnswer((_) async => testVideo);
        },
        build: createCubit,
        expect: () => [
          isA<VideoLinkPreviewResolved>()
              .having((s) => s.video.id, 'video.id', testVideo.id)
              .having((s) => s.video.totalLoops, 'video.totalLoops', 1234),
        ],
      );

      blocTest<VideoLinkPreviewCubit, VideoLinkPreviewState>(
        'resolves an author-named addressable share by its coordinate alone',
        build: () => VideoLinkPreviewCubit(
          videoStableId: 'skate-loop',
          authorPubkey: testVideo.pubkey,
          videoKind: 34235,
          videosRepository: mockVideosRepository,
        ),
        expect: () => [isA<VideoLinkPreviewNotFound>()],
        verify: (_) {
          verify(
            () => mockVideosRepository.fetchVideoWithStatsForRouteId(
              '34235:${testVideo.pubkey}:skate-loop',
              fallbackRouteIds: any(named: 'fallbackRouteIds', that: isEmpty),
            ),
          ).called(1);
        },
      );

      blocTest<VideoLinkPreviewCubit, VideoLinkPreviewState>(
        'passes no fallback route when author/kind are absent',
        build: createCubit,
        expect: () => [isA<VideoLinkPreviewNotFound>()],
        verify: (_) {
          verify(
            () => mockVideosRepository.fetchVideoWithStatsForRouteId(
              'test-id',
              fallbackRouteIds: any(named: 'fallbackRouteIds', that: isEmpty),
            ),
          ).called(1);
        },
      );
    });

    group('author-named share', () {
      const author =
          '4bf0c63fcb93463407af97a5e5ee64fa'
          '883d107ef9e558472c4eb9aaaefa459d';
      const otherAuthor =
          '5bf0c63fcb93463407af97a5e5ee64fa'
          '883d107ef9e558472c4eb9aaaefa459d';
      const otherEventId =
          'b2b2f6b60119d9521934a691347d9f78'
          'e8770b56da16bb255ee77ac112b4c1f6';
      // Divine's d tag is the sha256 of the uploaded file, so two accounts
      // that upload the same bytes share one.
      const dTag =
          'ea331e1d9e63bb0bb35ff888f142a888'
          '4fd0859ce2428ea3ec33613fa7629478';

      test("emits $VideoLinkPreviewNotFound rather than another author's "
          'video under the same d tag', () async {
        final nostrClient = _MockNostrClient();
        answerQueriesFromStoredEvents(nostrClient, [
          Event.fromJson({
            'id': otherEventId,
            'pubkey': otherAuthor,
            'created_at': 1739350100,
            'kind': 34236,
            'tags': [
              ['d', dTag],
              ['url', 'https://example.com/other.mp4'],
            ],
            'content': '',
            'sig': '',
          }),
        ]);
        final repository = VideosRepository(nostrClient: nostrClient);

        // Positive control: the relay does hold a video under this d tag.
        final bare = await repository.fetchVideoWithStatsForRouteId(dTag);
        expect(bare?.id, equals(otherEventId));

        final cubit = VideoLinkPreviewCubit(
          videoStableId: dTag,
          authorPubkey: author,
          videoKind: 34236,
          videosRepository: repository,
        );
        addTearDown(cubit.close);

        await expectLater(
          cubit.stream,
          emits(isA<VideoLinkPreviewNotFound>()),
        );
      });
    });

    group('not found', () {
      blocTest<VideoLinkPreviewCubit, VideoLinkPreviewState>(
        'emits $VideoLinkPreviewNotFound when the repository resolves nothing',
        build: createCubit,
        expect: () => [isA<VideoLinkPreviewNotFound>()],
      );

      blocTest<VideoLinkPreviewCubit, VideoLinkPreviewState>(
        'emits $VideoLinkPreviewNotFound when the repository throws',
        setUp: () {
          when(
            () => mockVideosRepository.fetchVideoWithStatsForRouteId(
              any(),
              fallbackRouteIds: any(named: 'fallbackRouteIds'),
            ),
          ).thenThrow(Exception('network error'));
        },
        build: createCubit,
        expect: () => [isA<VideoLinkPreviewNotFound>()],
      );
    });

    group('close during in-flight resolve', () {
      test('does not emit or throw when closed mid resolve', () async {
        final completer = Completer<VideoEvent?>();
        when(
          () => mockVideosRepository.fetchVideoWithStatsForRouteId(
            any(),
            fallbackRouteIds: any(named: 'fallbackRouteIds'),
          ),
        ).thenAnswer((_) => completer.future);

        final cubit = createCubit();
        // Let _resolve run past scheduling to the awaited repository call.
        await pumpEventQueue();
        expect(cubit.state, isA<VideoLinkPreviewLoading>());

        // Close while the resolve is still in flight.
        await cubit.close();

        // Completing drives the post-await path; without the isClosed guard
        // this emits on the closed cubit and throws StateError.
        completer.complete(testVideo);
        await pumpEventQueue();

        expect(cubit.state, isA<VideoLinkPreviewLoading>());
      });
    });
  });
}
