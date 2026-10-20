// ABOUTME: Tests that the search page's Nostr-id cubit resolves only edited,
// ABOUTME: complete identifiers and drops lookups for replaced queries.

import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/nostr_id_search/nostr_id_search_cubit.dart';
import 'package:openvine/utils/nostr_key_utils.dart';
import 'package:openvine/utils/nostr_search_query.dart';
import 'package:profile_repository/profile_repository.dart';
import 'package:videos_repository/videos_repository.dart';

class _MockProfileRepository extends Mock implements ProfileRepository {}

class _MockVideosRepository extends Mock implements VideosRepository {}

void main() {
  const hexId =
      'c218ed9ce99db3c216ca7c70f7a289a3da56fe0b9ba1492b3179db73c8e63a4d';
  const authorHex =
      '81acbb70475b8b715c38d072ce93769ca275783d187990117ec0c01ea849bf95';
  final npub = NostrKeyUtils.encodePubKey(authorHex);
  final video = VideoEvent(
    id: hexId,
    pubkey: authorHex,
    createdAt: 1700000000,
    content: '',
    timestamp: DateTime.utc(2023, 11, 14),
  );
  final profile = UserProfile(
    pubkey: hexId,
    rawData: const {},
    createdAt: DateTime.utc(2023, 11, 14),
    eventId: 'f3c1a4e8b2d64e0e9a7b5c3d1f2e4a6b8c0d2e4f6a8b0c2d4e6f8a0b2c4d6e8f',
  );

  group(NostrIdSearchCubit, () {
    late _MockProfileRepository profileRepository;
    late _MockVideosRepository videosRepository;

    setUp(() {
      profileRepository = _MockProfileRepository();
      videosRepository = _MockVideosRepository();
    });

    NostrIdSearchCubit buildCubit({String initialQuery = ''}) =>
        NostrIdSearchCubit(
          profileRepository: profileRepository,
          videosRepository: videosRepository,
          initialQuery: initialQuery,
        );

    group('queryChanged', () {
      blocTest<NostrIdSearchCubit, NostrIdSearchState>(
        'does not open an identifier containing private-key-looking text',
        build: buildCubit,
        act: (cubit) => cubit.queryChanged('34236:$authorHex:nsec1'),
        verify: (cubit) {
          expect(cubit.state.query, isNot(contains('nsec1')));
          expect(cubit.state.action, isNull);
          verifyZeroInteractions(profileRepository);
          verifyZeroInteractions(videosRepository);
        },
      );

      blocTest<NostrIdSearchCubit, NostrIdSearchState>(
        'clears the current query when private-key-looking text replaces it',
        build: buildCubit,
        act: (cubit) async {
          await cubit.queryChanged(npub);
          await cubit.queryChanged('NSEC1abc');
        },
        expect: () => [
          NostrIdSearchState(query: npub),
          NostrIdSearchState(
            query: npub,
            action: const OpenProfileAction(authorHex),
          ),
          const NostrIdSearchState(),
        ],
      );

      blocTest<NostrIdSearchCubit, NostrIdSearchState>(
        'opens the profile an npub names without a lookup',
        build: buildCubit,
        act: (cubit) => cubit.queryChanged(' $npub '),
        expect: () => [
          NostrIdSearchState(query: npub),
          NostrIdSearchState(
            query: npub,
            action: const OpenProfileAction(authorHex),
          ),
        ],
        verify: (_) {
          verifyZeroInteractions(profileRepository);
          verifyZeroInteractions(videosRepository);
        },
      );

      blocTest<NostrIdSearchCubit, NostrIdSearchState>(
        'records ordinary text without anything to open',
        build: buildCubit,
        act: (cubit) => cubit.queryChanged('cats'),
        expect: () => const [NostrIdSearchState(query: 'cats')],
      );

      group('with a bare hex value', () {
        void stubVideo(VideoRouteLookupResult result) => when(
          () => videosRepository.lookupVideoForRouteId(hexId),
        ).thenAnswer((_) async => result);

        void stubProfile({UserProfile? cached, UserProfile? fresh}) {
          when(
            () => profileRepository.getCachedProfile(pubkey: hexId),
          ).thenAnswer((_) async => cached);
          when(
            () => profileRepository.fetchFreshProfile(pubkey: hexId),
          ).thenAnswer((_) async => fresh);
        }

        blocTest<NostrIdSearchCubit, NostrIdSearchState>(
          'opens the video it names',
          setUp: () {
            stubVideo(VideoRouteFound(video));
            stubProfile();
          },
          build: buildCubit,
          act: (cubit) => cubit.queryChanged(hexId),
          expect: () => const [
            NostrIdSearchState(query: hexId),
            NostrIdSearchState(query: hexId, action: OpenVideoAction(hexId)),
          ],
        );

        blocTest<NostrIdSearchCubit, NostrIdSearchState>(
          "opens a video the viewer's filters hide",
          setUp: () {
            stubVideo(VideoRouteHiddenByFilter(video));
            stubProfile();
          },
          build: buildCubit,
          act: (cubit) => cubit.queryChanged(hexId),
          expect: () => const [
            NostrIdSearchState(query: hexId),
            NostrIdSearchState(query: hexId, action: OpenVideoAction(hexId)),
          ],
        );

        blocTest<NostrIdSearchCubit, NostrIdSearchState>(
          'opens a cached profile when no video matches',
          setUp: () {
            stubVideo(const VideoRouteMissing());
            stubProfile(cached: profile);
          },
          build: buildCubit,
          act: (cubit) => cubit.queryChanged(hexId),
          expect: () => const [
            NostrIdSearchState(query: hexId),
            NostrIdSearchState(
              query: hexId,
              action: OpenProfileAction(hexId),
            ),
          ],
          verify: (_) => verifyNever(
            () => profileRepository.fetchFreshProfile(pubkey: hexId),
          ),
        );

        blocTest<NostrIdSearchCubit, NostrIdSearchState>(
          'fetches the profile when it is not cached',
          setUp: () {
            stubVideo(const VideoRouteMissing());
            stubProfile(fresh: profile);
          },
          build: buildCubit,
          act: (cubit) => cubit.queryChanged(hexId),
          expect: () => const [
            NostrIdSearchState(query: hexId),
            NostrIdSearchState(
              query: hexId,
              action: OpenProfileAction(hexId),
            ),
          ],
        );

        blocTest<NostrIdSearchCubit, NostrIdSearchState>(
          'opens nothing when neither a video nor a profile matches',
          setUp: () {
            stubVideo(const VideoRouteMissing());
            stubProfile();
          },
          build: buildCubit,
          act: (cubit) => cubit.queryChanged(hexId),
          expect: () => const [NostrIdSearchState(query: hexId)],
        );

        test('drops a lookup that finishes after the query changed', () async {
          final videoLookup = Completer<VideoRouteLookupResult>();
          when(
            () => videosRepository.lookupVideoForRouteId(hexId),
          ).thenAnswer((_) => videoLookup.future);
          stubProfile();
          final cubit = buildCubit();
          addTearDown(cubit.close);

          final pending = cubit.queryChanged(hexId);
          await cubit.queryChanged('cats');
          videoLookup.complete(VideoRouteFound(video));
          await pending;

          expect(cubit.state, equals(const NostrIdSearchState(query: 'cats')));
        });

        test('does not throw when closed during a lookup', () async {
          final videoLookup = Completer<VideoRouteLookupResult>();
          when(
            () => videosRepository.lookupVideoForRouteId(hexId),
          ).thenAnswer((_) => videoLookup.future);
          stubProfile();
          final cubit = buildCubit();

          final pending = cubit.queryChanged(hexId);
          await cubit.close();
          videoLookup.complete(VideoRouteFound(video));

          await expectLater(pending, completes);
        });
      });

      blocTest<NostrIdSearchCubit, NostrIdSearchState>(
        'ignores a repeat of the current query',
        build: buildCubit,
        act: (cubit) async {
          await cubit.queryChanged(npub);
          // The field reports cursor and focus changes with unchanged text.
          await cubit.queryChanged(npub);
        },
        expect: () => [
          NostrIdSearchState(query: npub),
          NostrIdSearchState(
            query: npub,
            action: const OpenProfileAction(authorHex),
          ),
        ],
      );

      test('does not keep a prefilled query that looks like a private key', () {
        final cubit = buildCubit(initialQuery: ' nsec1abc ');
        addTearDown(cubit.close);

        expect(cubit.state.query, isEmpty);
      });

      blocTest<NostrIdSearchCubit, NostrIdSearchState>(
        'leaves a query prefilled by the route unresolved until it changes',
        build: () => buildCubit(initialQuery: npub),
        act: (cubit) => cubit.queryChanged(npub),
        expect: () => const <NostrIdSearchState>[],
      );
    });
  });
}
