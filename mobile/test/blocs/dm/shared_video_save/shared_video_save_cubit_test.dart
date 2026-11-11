// ABOUTME: Tests for SharedVideoSaveCubit.
// ABOUTME: Verifies resolve states, in-flight guarding, and watermark text.

import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/nostr_sdk.dart';
import 'package:openvine/blocs/dm/shared_video_save/shared_video_save_cubit.dart';
import 'package:openvine/screens/inbox/conversation/dm_video_target.dart';
import 'package:profile_repository/profile_repository.dart';
import 'package:videos_repository/videos_repository.dart';

import '../../../builders/video_event_builder.dart';
import '../../../helpers/stored_relay_events.dart';

class _MockVideosRepository extends Mock implements VideosRepository {}

class _MockProfileRepository extends Mock implements ProfileRepository {}

class _MockNostrClient extends Mock implements NostrClient {}

void main() {
  const currentPubkey =
      'aabbccddaabbccddaabbccddaabbccddaabbccddaabbccddaabbccddaabbccdd';
  const otherPubkey =
      '1122334411223344112233441122334411223344112233441122334411223344';
  const target = DmVideoTarget(
    stableId: 'skate-loop',
    authorPubkey: otherPubkey,
    videoKind: 34236,
  );

  late _MockVideosRepository videosRepository;
  late _MockProfileRepository profileRepository;

  setUpAll(() {
    registerFallbackValue(<String>[]);
    registerFallbackValue(<Filter>[]);
  });

  setUp(() {
    videosRepository = _MockVideosRepository();
    profileRepository = _MockProfileRepository();
  });

  SharedVideoSaveCubit createCubit({String? currentUser = currentPubkey}) {
    return SharedVideoSaveCubit(
      videosRepository: videosRepository,
      profileRepository: profileRepository,
      currentPubkey: currentUser,
    );
  }

  group(SharedVideoSaveCubit, () {
    blocTest<SharedVideoSaveCubit, SharedVideoSaveState>(
      'emits originalReady for the current user video',
      build: () {
        final video = VideoEventBuilder(
          id: target.stableId,
          pubkey: currentPubkey,
        ).build();
        when(
          () => videosRepository.fetchVideoWithStatsForRouteId(
            target.routeId,
            fallbackRouteIds: target.fallbackRouteIds,
          ),
        ).thenAnswer((_) async => video);
        return createCubit();
      },
      act: (cubit) => cubit.save(target),
      expect: () => [
        const SharedVideoSaveState(status: SharedVideoSaveStatus.resolving),
        isA<SharedVideoSaveState>()
            .having(
              (state) => state.status,
              'status',
              SharedVideoSaveStatus.originalReady,
            )
            .having((state) => state.video?.id, 'video id', target.stableId),
      ],
    );

    blocTest<SharedVideoSaveCubit, SharedVideoSaveState>(
      'emits watermarkReady with resolved profile text for another creator',
      build: () {
        final video = VideoEventBuilder(
          id: target.stableId,
          pubkey: otherPubkey,
        ).build();
        when(
          () => videosRepository.fetchVideoWithStatsForRouteId(
            target.routeId,
            fallbackRouteIds: target.fallbackRouteIds,
          ),
        ).thenAnswer((_) async => video);
        when(
          () => profileRepository.getCachedProfile(pubkey: otherPubkey),
        ).thenAnswer(
          (_) async => UserProfile(
            pubkey: otherPubkey,
            rawData: const {},
            createdAt: DateTime.fromMillisecondsSinceEpoch(0),
            eventId: 'profile',
            nip05: 'alice@example.com',
          ),
        );
        return createCubit();
      },
      act: (cubit) => cubit.save(target),
      expect: () => [
        const SharedVideoSaveState(status: SharedVideoSaveStatus.resolving),
        isA<SharedVideoSaveState>()
            .having(
              (state) => state.status,
              'status',
              SharedVideoSaveStatus.watermarkReady,
            )
            .having((state) => state.video?.id, 'video id', target.stableId)
            .having(
              (state) => state.watermarkText,
              'watermark text',
              'alice@example.com',
            ),
      ],
    );

    blocTest<SharedVideoSaveCubit, SharedVideoSaveState>(
      'emits unavailable when resolve throws',
      build: () {
        when(
          () => videosRepository.fetchVideoWithStatsForRouteId(
            target.routeId,
            fallbackRouteIds: target.fallbackRouteIds,
          ),
        ).thenThrow(StateError('closed'));
        return createCubit();
      },
      act: (cubit) => cubit.save(target),
      expect: () => [
        const SharedVideoSaveState(status: SharedVideoSaveStatus.resolving),
        const SharedVideoSaveState(status: SharedVideoSaveStatus.unavailable),
      ],
    );

    test('drops a second save request while resolve is in flight', () async {
      final completer = Completer<VideoEvent?>();
      when(
        () => videosRepository.fetchVideoWithStatsForRouteId(
          target.routeId,
          fallbackRouteIds: target.fallbackRouteIds,
        ),
      ).thenAnswer((_) => completer.future);

      final cubit = createCubit();
      addTearDown(cubit.close);

      final first = cubit.save(target);
      final second = cubit.save(target);

      verify(
        () => videosRepository.fetchVideoWithStatsForRouteId(
          target.routeId,
          fallbackRouteIds: target.fallbackRouteIds,
        ),
      ).called(1);

      completer.complete(null);
      await Future.wait([first, second]);
      expect(cubit.state.status, SharedVideoSaveStatus.unavailable);
    });

    test("reports unavailable rather than saving another author's video "
        'under the same d tag', () async {
      const otherEventId =
          'b2b2f6b60119d9521934a691347d9f78'
          'e8770b56da16bb255ee77ac112b4c1f6';
      // Divine's d tag is the sha256 of the uploaded file, so two accounts
      // that upload the same bytes share one.
      const dTag =
          'ea331e1d9e63bb0bb35ff888f142a888'
          '4fd0859ce2428ea3ec33613fa7629478';
      final nostrClient = _MockNostrClient();
      answerQueriesFromStoredEvents(nostrClient, [
        Event.fromJson({
          'id': otherEventId,
          'pubkey': currentPubkey,
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

      final cubit = SharedVideoSaveCubit(
        videosRepository: repository,
        profileRepository: profileRepository,
        currentPubkey: currentPubkey,
      );
      addTearDown(cubit.close);

      await cubit.save(
        const DmVideoTarget(
          stableId: dTag,
          authorPubkey: otherPubkey,
          videoKind: 34236,
        ),
      );

      expect(cubit.state.status, SharedVideoSaveStatus.unavailable);
    });

    test('reports unavailable rather than saving a video whose d tag reuses '
        'the cited event id', () async {
      // A kind 22 citation routes by its event id, which is also looked up as
      // a d tag: anyone can publish a video under that d tag.
      const citedEventId =
          'c3c3f6b60119d9521934a691347d9f78'
          'e8770b56da16bb255ee77ac112b4c1f6';
      const squatterEventId =
          'b2b2f6b60119d9521934a691347d9f78'
          'e8770b56da16bb255ee77ac112b4c1f6';
      final nostrClient = _MockNostrClient();
      answerQueriesFromStoredEvents(nostrClient, [
        Event.fromJson({
          'id': squatterEventId,
          'pubkey': currentPubkey,
          'created_at': 1739350100,
          'kind': 34236,
          'tags': [
            ['d', citedEventId],
            ['url', 'https://example.com/other.mp4'],
          ],
          'content': '',
          'sig': '',
        }),
      ]);
      final repository = VideosRepository(nostrClient: nostrClient);

      // Positive control: an unattributed lookup of the id finds it.
      final bare = await repository.fetchVideoWithStatsForRouteId(
        citedEventId,
      );
      expect(bare?.id, equals(squatterEventId));

      final cubit = SharedVideoSaveCubit(
        videosRepository: repository,
        profileRepository: profileRepository,
        currentPubkey: currentPubkey,
      );
      addTearDown(cubit.close);

      await cubit.save(
        const DmVideoTarget(
          stableId: citedEventId,
          authorPubkey: otherPubkey,
          videoKind: 22,
        ),
      );

      expect(cubit.state.status, SharedVideoSaveStatus.unavailable);
    });
  });
}
