// ABOUTME: Unit tests for AddPeopleToListCubit.
// ABOUTME: Covers candidate loading, sort order, filtering, toggling, and retry.

import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:follow_repository/follow_repository.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/features/people_lists/bloc/add_people_to_list_cubit.dart';
import 'package:openvine/features/people_lists/bloc/add_people_to_list_state.dart';
import 'package:profile_repository/profile_repository.dart';

class _MockFollowRepository extends Mock implements FollowRepository {}

class _MockProfileRepository extends Mock implements ProfileRepository {}

// Full 64-character hex pubkeys — never truncate in app code, logs, or
// stored state. Full IDs only.
const String _alicePubkey =
    'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
const String _bobPubkey =
    'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';
const String _carolPubkey =
    'cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc';
const String _davePubkey =
    'dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd';
const String _evePubkey =
    'eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee';

UserProfile _profile({
  required String pubkey,
  String? displayName,
  String? name,
  String? nip05,
  String? picture,
}) {
  return UserProfile(
    pubkey: pubkey,
    displayName: displayName,
    name: name,
    nip05: nip05,
    picture: picture,
    rawData: const {},
    createdAt: DateTime.utc(2026),
    eventId: 'event_for_$pubkey',
  );
}

Future<void> _flush() => Future<void>.delayed(Duration.zero);

void main() {
  setUpAll(() {
    registerFallbackValue(<String>[]);
  });

  group(AddPeopleToListCubit, () {
    late _MockFollowRepository followRepository;
    late _MockProfileRepository profileRepository;
    late StreamController<List<String>> followingController;
    late StreamController<FollowersSnapshot> followersController;

    setUp(() {
      followRepository = _MockFollowRepository();
      profileRepository = _MockProfileRepository();
      followingController = StreamController<List<String>>.broadcast();
      followersController = StreamController<FollowersSnapshot>.broadcast();

      when(() => followRepository.followingPubkeys).thenReturn(const []);
      when(
        () => followRepository.followingStream,
      ).thenAnswer((_) => followingController.stream);
      when(
        () => followRepository.watchMyFollowers(),
      ).thenAnswer((_) => followersController.stream);

      when(
        () => profileRepository.getCachedProfile(pubkey: any(named: 'pubkey')),
      ).thenAnswer((_) async => null);
      when(
        () => profileRepository.fetchFreshProfile(pubkey: any(named: 'pubkey')),
      ).thenAnswer((_) async => null);
    });

    tearDown(() async {
      if (!followingController.isClosed) await followingController.close();
      if (!followersController.isClosed) await followersController.close();
    });

    AddPeopleToListCubit createCubit({
      List<String> existingMembers = const [],
    }) {
      return AddPeopleToListCubit(
        followRepository: followRepository,
        profileRepository: profileRepository,
        existingMemberPubkeys: existingMembers,
      );
    }

    test('initial state is initial status with empty candidates', () async {
      final cubit = createCubit();
      expect(cubit.state.status, AddPeopleToListStatus.initial);
      expect(cubit.state.candidates, isEmpty);
      expect(cubit.state.query, isEmpty);
      expect(cubit.state.selectedPubkeys, isEmpty);
      await cubit.close();
    });

    group('started', () {
      test(
        'emits following-only candidates with isFollowing=true, '
        'isFollower=false',
        () async {
          when(
            () => followRepository.followingPubkeys,
          ).thenReturn([_alicePubkey]);
          when(
            () => followRepository.watchMyFollowers(),
          ).thenAnswer((_) => const Stream.empty());

          final cubit = createCubit();
          await cubit.started();

          expect(cubit.state.status, AddPeopleToListStatus.ready);
          expect(cubit.state.candidates, hasLength(1));
          final candidate = cubit.state.candidates.first;
          expect(candidate.pubkey, _alicePubkey);
          expect(candidate.isFollowing, isTrue);
          expect(candidate.isFollower, isFalse);
          expect(candidate.isMutual, isFalse);

          await cubit.close();
        },
      );

      test(
        'emits follower-only candidates with isFollowing=false, '
        'isFollower=true',
        () async {
          when(() => followRepository.followingPubkeys).thenReturn(const []);
          when(() => followRepository.watchMyFollowers()).thenAnswer(
            (_) => Stream.value(
              const FollowersSnapshot(pubkeys: [_bobPubkey], count: 1),
            ),
          );

          final cubit = createCubit();
          await cubit.started();
          await _flush();

          expect(cubit.state.status, AddPeopleToListStatus.ready);
          final bob = cubit.state.candidates.firstWhere(
            (c) => c.pubkey == _bobPubkey,
          );
          expect(bob.isFollowing, isFalse);
          expect(bob.isFollower, isTrue);
          expect(bob.isMutual, isFalse);

          await cubit.close();
        },
      );

      test(
        'mutual candidates sort before following-only and follower-only',
        () async {
          // Alice = mutual (following + follower).
          // Carol = following-only.
          // Bob = follower-only.
          when(
            () => followRepository.followingPubkeys,
          ).thenReturn([_alicePubkey, _carolPubkey]);
          when(() => followRepository.watchMyFollowers()).thenAnswer(
            (_) => Stream.value(
              const FollowersSnapshot(
                pubkeys: [_alicePubkey, _bobPubkey],
                count: 2,
              ),
            ),
          );

          final cubit = createCubit();
          await cubit.started();
          await _flush();

          final order = cubit.state.candidates.map((c) => c.pubkey).toList();
          // Alice (mutual) must come first, then following-only (Carol),
          // then follower-only (Bob).
          expect(
            order.indexOf(_alicePubkey),
            lessThan(order.indexOf(_carolPubkey)),
          );
          expect(
            order.indexOf(_carolPubkey),
            lessThan(order.indexOf(_bobPubkey)),
          );

          final alice = cubit.state.candidates.firstWhere(
            (c) => c.pubkey == _alicePubkey,
          );
          expect(alice.isMutual, isTrue);

          await cubit.close();
        },
      );

      test('existingMemberPubkeys appear with isAlreadyInList=true', () async {
        when(
          () => followRepository.followingPubkeys,
        ).thenReturn([_alicePubkey]);
        when(
          () => followRepository.watchMyFollowers(),
        ).thenAnswer((_) => const Stream.empty());

        final cubit = createCubit(existingMembers: [_alicePubkey]);
        await cubit.started();

        final alice = cubit.state.candidates.firstWhere(
          (c) => c.pubkey == _alicePubkey,
        );
        expect(alice.isAlreadyInList, isTrue);

        await cubit.close();
      });

      test(
        'profile lookup failure keeps candidate with fallback labels',
        () async {
          when(
            () => followRepository.followingPubkeys,
          ).thenReturn([_davePubkey]);
          when(
            () => followRepository.watchMyFollowers(),
          ).thenAnswer((_) => const Stream.empty());
          when(
            () => profileRepository.getCachedProfile(
              pubkey: any(named: 'pubkey'),
            ),
          ).thenAnswer((_) async => null);
          when(
            () => profileRepository.fetchFreshProfile(
              pubkey: any(named: 'pubkey'),
            ),
          ).thenThrow(Exception('relay timeout'));

          final cubit = createCubit();
          await cubit.started();
          await _flush();

          // Failure should not tear down the list.
          expect(cubit.state.status, AddPeopleToListStatus.ready);
          final dave = cubit.state.candidates.firstWhere(
            (c) => c.pubkey == _davePubkey,
          );
          // displayName stays null so the UI can render a fallback derived
          // from the full pubkey. The pubkey itself is the stable identifier.
          expect(dave.displayName, isNull);
          expect(dave.handle, isNull);
          expect(dave.avatarUrl, isNull);
          expect(dave.pubkey, _davePubkey);

          await cubit.close();
        },
      );

      test(
        'populates candidate display metadata from cached profile',
        () async {
          when(
            () => followRepository.followingPubkeys,
          ).thenReturn([_alicePubkey]);
          when(
            () => followRepository.watchMyFollowers(),
          ).thenAnswer((_) => const Stream.empty());
          when(
            () => profileRepository.getCachedProfile(pubkey: _alicePubkey),
          ).thenAnswer(
            (_) async => _profile(
              pubkey: _alicePubkey,
              displayName: 'Alice',
              name: 'alice',
              picture: 'https://example.com/a.png',
            ),
          );

          final cubit = createCubit();
          await cubit.started();
          await _flush();

          final alice = cubit.state.candidates.firstWhere(
            (c) => c.pubkey == _alicePubkey,
          );
          expect(alice.displayName, 'Alice');
          expect(alice.handle, '@alice');
          expect(alice.avatarUrl, 'https://example.com/a.png');

          await cubit.close();
        },
      );

      test(
        'does not emit when profile hydration completes after close',
        () async {
          final cachedProfile = Completer<UserProfile?>();
          when(
            () => followRepository.followingPubkeys,
          ).thenReturn([_alicePubkey]);
          when(
            () => followRepository.watchMyFollowers(),
          ).thenAnswer((_) => const Stream.empty());
          when(
            () => profileRepository.getCachedProfile(pubkey: _alicePubkey),
          ).thenAnswer((_) => cachedProfile.future);

          final cubit = createCubit();
          await cubit.started();
          await cubit.close();

          cachedProfile.complete(_profile(pubkey: _alicePubkey));
          await _flush();

          expect(cubit.isClosed, isTrue);
        },
      );
    });

    group('queryChanged', () {
      test('filters by display name (case-insensitive)', () async {
        when(
          () => followRepository.followingPubkeys,
        ).thenReturn([_alicePubkey, _bobPubkey]);
        when(
          () => followRepository.watchMyFollowers(),
        ).thenAnswer((_) => const Stream.empty());
        when(
          () => profileRepository.getCachedProfile(pubkey: _alicePubkey),
        ).thenAnswer(
          (_) async => _profile(pubkey: _alicePubkey, displayName: 'Alice'),
        );
        when(
          () => profileRepository.getCachedProfile(pubkey: _bobPubkey),
        ).thenAnswer(
          (_) async => _profile(pubkey: _bobPubkey, displayName: 'Bob'),
        );

        final cubit = createCubit();
        await cubit.started();
        await _flush();

        cubit.queryChanged('ALICE');
        final visible = cubit.state.visibleCandidates;
        expect(visible, hasLength(1));
        expect(visible.first.pubkey, _alicePubkey);

        await cubit.close();
      });

      test('filters by handle (case-insensitive)', () async {
        when(
          () => followRepository.followingPubkeys,
        ).thenReturn([_alicePubkey, _bobPubkey]);
        when(
          () => followRepository.watchMyFollowers(),
        ).thenAnswer((_) => const Stream.empty());
        when(
          () => profileRepository.getCachedProfile(pubkey: _alicePubkey),
        ).thenAnswer(
          (_) async =>
              _profile(pubkey: _alicePubkey, displayName: 'A', name: 'Wonder'),
        );
        when(
          () => profileRepository.getCachedProfile(pubkey: _bobPubkey),
        ).thenAnswer(
          (_) async =>
              _profile(pubkey: _bobPubkey, displayName: 'B', name: 'builder'),
        );

        final cubit = createCubit();
        await cubit.started();
        await _flush();

        cubit.queryChanged('WONDER');
        final visible = cubit.state.visibleCandidates;
        expect(visible, hasLength(1));
        expect(visible.first.pubkey, _alicePubkey);

        await cubit.close();
      });

      test('filters by full pubkey (prefix match)', () async {
        when(
          () => followRepository.followingPubkeys,
        ).thenReturn([_alicePubkey, _bobPubkey]);
        when(
          () => followRepository.watchMyFollowers(),
        ).thenAnswer((_) => const Stream.empty());

        final cubit = createCubit();
        await cubit.started();
        await _flush();

        // All 'a's prefix — the Cubit should match the full pubkey for Alice.
        cubit.queryChanged('aaaaaaaaaa');
        final visible = cubit.state.visibleCandidates;
        expect(visible, hasLength(1));
        expect(visible.first.pubkey, _alicePubkey);

        await cubit.close();
      });

      test('passing the full pubkey matches exactly one candidate', () async {
        when(
          () => followRepository.followingPubkeys,
        ).thenReturn([_alicePubkey, _bobPubkey]);
        when(
          () => followRepository.watchMyFollowers(),
        ).thenAnswer((_) => const Stream.empty());

        final cubit = createCubit();
        await cubit.started();
        await _flush();

        cubit.queryChanged(_alicePubkey);
        final visible = cubit.state.visibleCandidates;
        expect(visible, hasLength(1));
        expect(visible.first.pubkey, _alicePubkey);

        await cubit.close();
      });
    });

    group('candidateToggled', () {
      test('adds and removes pubkey from selectedPubkeys', () async {
        when(
          () => followRepository.followingPubkeys,
        ).thenReturn([_alicePubkey]);
        when(
          () => followRepository.watchMyFollowers(),
        ).thenAnswer((_) => const Stream.empty());

        final cubit = createCubit();
        await cubit.started();

        expect(cubit.state.selectedPubkeys, isEmpty);
        cubit.candidateToggled(_alicePubkey);
        expect(cubit.state.selectedPubkeys, contains(_alicePubkey));
        cubit.candidateToggled(_alicePubkey);
        expect(cubit.state.selectedPubkeys, isNot(contains(_alicePubkey)));

        await cubit.close();
      });
    });

    group('retryRequested', () {
      blocTest<AddPeopleToListCubit, AddPeopleToListState>(
        're-runs the loader after a prior failure',
        setUp: () {
          var callCount = 0;
          when(() => followRepository.followingPubkeys).thenAnswer((_) {
            callCount++;
            if (callCount == 1) {
              throw Exception('boom');
            }
            return [_evePubkey];
          });
          when(
            () => followRepository.watchMyFollowers(),
          ).thenAnswer((_) => const Stream.empty());
        },
        build: () => AddPeopleToListCubit(
          followRepository: followRepository,
          profileRepository: profileRepository,
          existingMemberPubkeys: const [],
        ),
        act: (cubit) async {
          await cubit.started();
          await _flush();
          cubit.retryRequested();
          await _flush();
        },
        errors: () => [isA<Exception>()],
        verify: (cubit) {
          expect(cubit.state.status, AddPeopleToListStatus.ready);
          expect(
            cubit.state.candidates.map((c) => c.pubkey),
            contains(_evePubkey),
          );
        },
      );
    });

    group('candidate fixtures', () {
      test('always use full 64-character hex pubkeys', () {
        for (final pk in [
          _alicePubkey,
          _bobPubkey,
          _carolPubkey,
          _davePubkey,
          _evePubkey,
        ]) {
          expect(pk.length, 64);
          expect(RegExp(r'^[0-9a-f]{64}$').hasMatch(pk), isTrue);
        }
      });
    });
  });
}
