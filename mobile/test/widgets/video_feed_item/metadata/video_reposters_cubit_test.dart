// ABOUTME: Unit tests for VideoRepostersCubit.
// ABOUTME: Pins the success/error paths and the close-during-fetch race
// ABOUTME: that previously surfaced as a Crashlytics 'emit after close'.

import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/widgets/video_feed_item/metadata/video_reposters_cubit.dart';
import 'package:reposts_repository/reposts_repository.dart';

class _MockRepostsRepository extends Mock implements RepostsRepository {}

void main() {
  group(VideoRepostersCubit, () {
    late _MockRepostsRepository repostsRepository;

    setUp(() {
      repostsRepository = _MockRepostsRepository();
    });

    blocTest<VideoRepostersCubit, VideoRepostersState>(
      'emits success state when fetch resolves before close',
      setUp: () {
        when(
          () => repostsRepository.fetchEventReposters(eventId: 'video-id'),
        ).thenAnswer((_) async => ['pubkey-a', 'pubkey-b']);
      },
      build: () => VideoRepostersCubit(
        repostsRepository: repostsRepository,
        videoId: 'video-id',
      ),
      expect: () => const [
        VideoRepostersState(
          pubkeys: ['pubkey-a', 'pubkey-b'],
          isLoading: false,
        ),
      ],
    );

    blocTest<VideoRepostersCubit, VideoRepostersState>(
      'passes addressableId through to the repository when provided',
      setUp: () {
        when(
          () => repostsRepository.fetchEventReposters(
            eventId: 'video-id',
            addressableId: '34236:author:d-tag',
          ),
        ).thenAnswer((_) async => ['pubkey-a']);
      },
      build: () => VideoRepostersCubit(
        repostsRepository: repostsRepository,
        videoId: 'video-id',
        addressableId: '34236:author:d-tag',
      ),
      expect: () => const [
        VideoRepostersState(pubkeys: ['pubkey-a'], isLoading: false),
      ],
      verify: (_) {
        verify(
          () => repostsRepository.fetchEventReposters(
            eventId: 'video-id',
            addressableId: '34236:author:d-tag',
          ),
        ).called(1);
      },
    );

    test('moves to loading=false when videoId is empty', () async {
      final cubit = VideoRepostersCubit(
        repostsRepository: repostsRepository,
        videoId: '',
      );
      // The empty-id branch emits synchronously inside the constructor,
      // so a direct state check is the right shape — blocTest's stream
      // listener attaches too late to observe it.
      expect(cubit.state, equals(const VideoRepostersState(isLoading: false)));
      verifyNever(
        () => repostsRepository.fetchEventReposters(
          eventId: any(named: 'eventId'),
          addressableId: any(named: 'addressableId'),
        ),
      );
      await cubit.close();
    });

    blocTest<VideoRepostersCubit, VideoRepostersState>(
      'emits loading=false and reports addError on relay failure',
      setUp: () {
        when(
          () => repostsRepository.fetchEventReposters(eventId: 'video-id'),
        ).thenAnswer((_) async => throw StateError('relay unavailable'));
      },
      build: () => VideoRepostersCubit(
        repostsRepository: repostsRepository,
        videoId: 'video-id',
      ),
      expect: () => const [VideoRepostersState(isLoading: false)],
      errors: () => [isA<StateError>()],
    );

    test(
      'does not emit (or throw) when closed before in-flight fetch resolves '
      '— regression for #3734 emit-after-close race',
      () async {
        final completer = Completer<List<String>>();
        when(
          () => repostsRepository.fetchEventReposters(eventId: 'video-id'),
        ).thenAnswer((_) => completer.future);

        final cubit = VideoRepostersCubit(
          repostsRepository: repostsRepository,
          videoId: 'video-id',
        );

        final emissions = <VideoRepostersState>[];
        final subscription = cubit.stream.listen(emissions.add);

        await cubit.close();
        completer.complete(['pubkey-late']);
        await pumpEventQueue();

        expect(emissions, isEmpty);
        await subscription.cancel();
      },
    );

    test(
      'does not emit (or addError) when closed before in-flight fetch errors',
      () async {
        final completer = Completer<List<String>>();
        when(
          () => repostsRepository.fetchEventReposters(eventId: 'video-id'),
        ).thenAnswer((_) => completer.future);

        final cubit = VideoRepostersCubit(
          repostsRepository: repostsRepository,
          videoId: 'video-id',
        );

        final emissions = <VideoRepostersState>[];
        final subscription = cubit.stream.listen(emissions.add);

        await cubit.close();
        completer.completeError(StateError('relay timeout'));
        await pumpEventQueue();

        expect(emissions, isEmpty);
        await subscription.cancel();
      },
    );
  });
}
