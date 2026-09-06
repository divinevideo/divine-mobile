import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/caption_mentions/caption_mentions_cubit.dart';
import 'package:profile_repository/profile_repository.dart';

class _MockProfileRepository extends Mock implements ProfileRepository {}

const _alice =
    'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
const _bob = 'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';

UserProfile _profile(String pubkey, {String? name}) => UserProfile(
  pubkey: pubkey,
  name: name,
  rawData: const {},
  createdAt: DateTime.utc(2026),
  eventId: 'event-$pubkey',
);

void main() {
  late _MockProfileRepository profileRepository;

  setUp(() {
    profileRepository = _MockProfileRepository();
    // Tier 2 runs whenever the cache yields fewer than five matches, which is
    // every test here; the cases that care about it override this.
    when(
      () => profileRepository.searchUsersFromApi(
        query: any(named: 'query'),
        limit: any(named: 'limit'),
        sortBy: any(named: 'sortBy'),
      ),
    ).thenAnswer((_) async => const <UserProfile>[]);
    when(
      () => profileRepository.getCachedProfile(pubkey: any(named: 'pubkey')),
    ).thenAnswer((_) async => null);
  });

  group(CaptionMentionsCubit, () {
    group('search', () {
      test(
        'offers followed accounts from cache before any network call',
        () async {
          when(
            () => profileRepository.getCachedProfile(pubkey: _alice),
          ).thenAnswer((_) async => _profile(_alice, name: 'OG-AB'));

          final cubit = CaptionMentionsCubit(
            profileRepositoryOf: () => profileRepository,
            candidatePubkeys: () => [_alice],
          );
          addTearDown(cubit.close);

          await cubit.search('OG-A');

          expect(cubit.state.query, equals('OG-A'));
          expect(
            cubit.state.suggestions.map((s) => s.pubkey),
            equals([_alice]),
          );
        },
      );

      test('backfills from the API when the follow list is thin', () async {
        when(
          () =>
              profileRepository.getCachedProfile(pubkey: any(named: 'pubkey')),
        ).thenAnswer((_) async => null);
        when(
          () => profileRepository.searchUsersFromApi(
            query: any(named: 'query'),
            limit: any(named: 'limit'),
            sortBy: any(named: 'sortBy'),
          ),
        ).thenAnswer((_) async => [_profile(_bob, name: 'OG-AB')]);

        final cubit = CaptionMentionsCubit(
          profileRepositoryOf: () => profileRepository,
          candidatePubkeys: () => [_alice],
        );
        addTearDown(cubit.close);

        await cubit.search('OG-AB');

        expect(cubit.state.suggestions.map((s) => s.pubkey), equals([_bob]));
      });

      test('keeps cached results when the API search throws', () async {
        when(
          () => profileRepository.getCachedProfile(pubkey: _alice),
        ).thenAnswer((_) async => _profile(_alice, name: 'OG-AB'));
        when(
          () => profileRepository.searchUsersFromApi(
            query: any(named: 'query'),
            limit: any(named: 'limit'),
            sortBy: any(named: 'sortBy'),
          ),
        ).thenThrow(Exception('offline'));

        final cubit = CaptionMentionsCubit(
          profileRepositoryOf: () => profileRepository,
          candidatePubkeys: () => [_alice],
        );
        addTearDown(cubit.close);

        await cubit.search('OG-AB');

        expect(cubit.state.suggestions.map((s) => s.pubkey), equals([_alice]));
      });

      test(
        'drops a slow response for a query the author has moved past',
        () async {
          // Without the request-id guard the stale search wins the race and
          // the list shows suggestions for text no longer on screen. The two
          // queries use separate stubs so awaiting the newer one cannot block
          // on the older one's pending future.
          final slow = Completer<List<UserProfile>>();
          when(
            () => profileRepository.searchUsersFromApi(
              query: 'alice',
              limit: any(named: 'limit'),
              sortBy: any(named: 'sortBy'),
            ),
          ).thenAnswer((_) => slow.future);
          when(
            () => profileRepository.searchUsersFromApi(
              query: 'bob',
              limit: any(named: 'limit'),
              sortBy: any(named: 'sortBy'),
            ),
          ).thenAnswer((_) async => [_profile(_bob, name: 'bob')]);

          final cubit = CaptionMentionsCubit(
            profileRepositoryOf: () => profileRepository,
            candidatePubkeys: () => const <String>[],
          );
          addTearDown(cubit.close);

          final stale = cubit.search('alice');
          await cubit.search('bob');
          slow.complete([_profile(_alice, name: 'alice')]);
          await stale;

          expect(cubit.state.query, equals('bob'));
          expect(cubit.state.suggestions.map((s) => s.pubkey), equals([_bob]));
        },
      );

      test('dismisses the list for an empty or whitespace query', () async {
        when(
          () => profileRepository.getCachedProfile(pubkey: _alice),
        ).thenAnswer((_) async => _profile(_alice, name: 'alice'));

        final cubit = CaptionMentionsCubit(
          profileRepositoryOf: () => profileRepository,
          candidatePubkeys: () => [_alice],
        );
        addTearDown(cubit.close);

        await cubit.search('alice');
        expect(cubit.state.suggestions, isNotEmpty);

        await cubit.search('   ');
        expect(cubit.state.suggestions, isEmpty);
        expect(cubit.state.query, isEmpty);

        await cubit.search(null);
        expect(cubit.state.suggestions, isEmpty);
      });

      test('survives a close mid-search without emitting', () async {
        // close() does not cancel the in-flight lookup; resuming into a closed
        // cubit must drop the emit rather than throw (see close_guard.dart).
        final slow = Completer<List<UserProfile>>();
        when(
          () => profileRepository.searchUsersFromApi(
            query: any(named: 'query'),
            limit: any(named: 'limit'),
            sortBy: any(named: 'sortBy'),
          ),
        ).thenAnswer((_) => slow.future);

        final cubit = CaptionMentionsCubit(
          profileRepositoryOf: () => profileRepository,
          candidatePubkeys: () => const <String>[],
        );

        final pending = cubit.search('alice');
        await cubit.close();
        slow.complete([_profile(_alice, name: 'alice')]);

        await expectLater(pending, completes);
      });
    });

    group('clear', () {
      test('empties the suggestions', () async {
        when(
          () => profileRepository.getCachedProfile(pubkey: _alice),
        ).thenAnswer((_) async => _profile(_alice, name: 'alice'));

        final cubit = CaptionMentionsCubit(
          profileRepositoryOf: () => profileRepository,
          candidatePubkeys: () => [_alice],
        );
        addTearDown(cubit.close);

        await cubit.search('alice');
        expect(cubit.state.suggestions, isNotEmpty);

        cubit.clear();
        expect(cubit.state.suggestions, isEmpty);
      });
    });
  });
}
