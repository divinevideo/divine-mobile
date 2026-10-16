// ABOUTME: Unit tests for AddPeopleToListCubit.
// ABOUTME: Covers candidate loading, sort order, filtering, toggling, and retry.

import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_test/flutter_test.dart';
import 'package:follow_repository/follow_repository.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/features/people_lists/bloc/add_people_to_list_cubit.dart';
import 'package:openvine/features/people_lists/bloc/add_people_to_list_state.dart';
import 'package:openvine/features/people_lists/models/people_list_candidate.dart';
import 'package:openvine/observability/reportable_error.dart';
import 'package:openvine/services/user_ranking/user_ranking_signals_loader.dart';
import 'package:profile_repository/profile_repository.dart';
import 'package:user_ranking/user_ranking.dart';

class _RecordingObserver extends BlocObserver {
  final errors = <Object>[];

  @override
  void onError(BlocBase<dynamic> bloc, Object error, StackTrace stackTrace) {
    errors.add(error);
    super.onError(bloc, error, stackTrace);
  }
}

class _MockRankingSignalsLoader extends Mock
    implements UserRankingSignalsLoader {}

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

Future<void> _flush() => pumpEventQueue();

void main() {
  setUpAll(() {
    registerFallbackValue(<String>[]);
  });

  group(AddPeopleToListCubit, () {
    late _MockRankingSignalsLoader rankingLoader;
    late _MockFollowRepository followRepository;
    late _MockProfileRepository profileRepository;
    late StreamController<List<String>> followingController;
    late StreamController<FollowersSnapshot> followersController;

    setUp(() {
      rankingLoader = _MockRankingSignalsLoader();
      when(() => rankingLoader.isEligible(any())).thenReturn(true);
      when(() => rankingLoader.load(any())).thenAnswer(
        (invocation) async => {
          for (final key
              in invocation.positionalArguments.single as Iterable<String>)
            key: UserRankingSignals(pubkey: key),
        },
      );
      when(() => rankingLoader.loadCachedDisplayNames(any()))
          .thenAnswer((_) async => {});
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
      when(
        () =>
            profileRepository.getCachedProfiles(pubkeys: any(named: 'pubkeys')),
      ).thenAnswer(
        (invocation) async => [
          for (final key in invocation.namedArguments[#pubkeys] as List<String>)
            ?await profileRepository.getCachedProfile(pubkey: key),
        ],
      );
    });

    tearDown(() async {
      if (!followingController.isClosed) await followingController.close();
      if (!followersController.isClosed) await followersController.close();
    });

    AddPeopleToListCubit createCubit({
      List<String> existingMembers = const [],
      AddPeopleToListState initialState = const AddPeopleToListState(),
    }) {
      return AddPeopleToListCubit(
        followRepository: followRepository,
        rankingSignalsLoader: rankingLoader,
        profileRepository: profileRepository,
        existingMemberPubkeys: existingMembers,
        initialState: initialState,
      );
    }

    test('refreshes bounded signals after ready emission', () async {
      when(() => followRepository.followingPubkeys).thenReturn([_alicePubkey]);
      final cubit = createCubit();
      addTearDown(cubit.close);
      when(() => rankingLoader.refreshInBackground(any())).thenAnswer((_) {
        expect(cubit.state.status, AddPeopleToListStatus.ready);
        expect(cubit.state.candidates.map((c) => c.pubkey), [_alicePubkey]);
      });
      await cubit.started();
      verify(() => rankingLoader.refreshInBackground([_alicePubkey])).called(1);
    });

    test('ranks arriving follower rows after hydration and keeps earlier rows and selection stable', () async {
      when(() => followRepository.followingPubkeys).thenReturn([_alicePubkey]);
      when(() => profileRepository.getCachedProfile(pubkey: _bobPubkey))
          .thenAnswer(
            (_) async => _profile(pubkey: _bobPubkey, displayName: 'Zebra'),
          );
      when(() => profileRepository.getCachedProfile(pubkey: _carolPubkey))
          .thenAnswer(
            (_) async => _profile(pubkey: _carolPubkey, displayName: 'Aaron'),
          );
      final cubit = createCubit();
      addTearDown(cubit.close);
      await cubit.started();
      cubit.candidateToggled(_alicePubkey);
      followersController.add(
        const FollowersSnapshot(pubkeys: [_bobPubkey, _carolPubkey], count: 2),
      );
      await _flush();
      expect(cubit.state.candidates.map((c) => c.pubkey), [
        _alicePubkey,
        _carolPubkey,
        _bobPubkey,
      ]);
      expect(cubit.state.selectedPubkeys, {_alicePubkey});
      followersController.add(
        const FollowersSnapshot(pubkeys: [_bobPubkey, _carolPubkey], count: 2),
      );
      await _flush();
      expect(cubit.state.candidates.map((c) => c.pubkey), [
        _alicePubkey,
        _carolPubkey,
        _bobPubkey,
      ]);
      verify(() => rankingLoader.refreshInBackground(any())).called(1);
    });

    test(
      'one pending fresh profile does not block cached named arrivals',
      () async {
        final hydrated = Completer<UserProfile?>();
        when(() => followRepository.followingPubkeys)
            .thenReturn([_alicePubkey]);
        when(() => profileRepository.fetchFreshProfile(pubkey: _bobPubkey))
            .thenAnswer((_) => hydrated.future);
        when(() => profileRepository.getCachedProfile(pubkey: _carolPubkey))
            .thenAnswer(
              (_) async => _profile(pubkey: _carolPubkey, displayName: 'Aaron'),
            );
        when(() => rankingLoader.load(any())).thenAnswer(
          (invocation) async => {
            for (final key
                in invocation.positionalArguments.single as Iterable<String>)
              key: UserRankingSignals(
                pubkey: key,
                videoCount: key == _bobPubkey ? 100 : null,
              ),
          },
        );
        final cubit = createCubit();
        addTearDown(cubit.close);
        await cubit.started();
        cubit.candidateToggled(_alicePubkey);
        followersController.add(
          const FollowersSnapshot(
            pubkeys: [_carolPubkey, _bobPubkey],
            count: 2,
          ),
        );
        await _flush();
        expect(cubit.state.candidates.map((c) => c.pubkey), [
          _alicePubkey,
          _carolPubkey,
        ]);
        expect(cubit.state.candidatePositions.containsKey(_bobPubkey), isFalse);
        expect(cubit.state.selectedPubkeys, {_alicePubkey});
        hydrated.complete(_profile(pubkey: _bobPubkey, displayName: 'Zebra'));
        await _flush();
        expect(cubit.state.candidates.map((c) => c.pubkey), [
          _alicePubkey,
          _carolPubkey,
          _bobPubkey,
        ]);
        expect(cubit.state.rankingSignals[_bobPubkey]!.videoCount, 100);
        expect(cubit.state.selectedPubkeys, {_alicePubkey});
      },
    );

    test(
      'caps fresh hydration across stream batches and appends completed rows',
      () async {
        final keys = [
          _bobPubkey,
          _carolPubkey,
          _davePubkey,
          _evePubkey,
          'f' * 64,
          '1' * 64,
        ];
        final pending = {
          for (final key in keys) key: Completer<UserProfile?>(),
        };
        final fetching = <String>[];
        when(
          () =>
              profileRepository.fetchFreshProfile(pubkey: any(named: 'pubkey')),
        ).thenAnswer((invocation) {
          final key = invocation.namedArguments[#pubkey] as String;
          fetching.add(key);
          return pending[key]!.future;
        });
        final cubit = createCubit();
        addTearDown(cubit.close);
        await cubit.started();
        followersController.add(
          FollowersSnapshot(pubkeys: keys.take(3).toList(), count: 3),
        );
        await _flush();
        expect(fetching, hasLength(3));
        followersController.add(
          FollowersSnapshot(pubkeys: keys, count: keys.length),
        );
        await _flush();
        expect(fetching, hasLength(4));
        expect(cubit.state.candidatePositions, isEmpty);
        pending[_carolPubkey]!.complete(
          _profile(pubkey: _carolPubkey, displayName: 'Ready'),
        );
        await _flush();
        expect(fetching, hasLength(5));
        expect(cubit.state.candidates.map((c) => c.pubkey), [_carolPubkey]);
        cubit.candidateToggled(_carolPubkey);
        for (final entry in pending.entries) {
          if (!entry.value.isCompleted) {
            entry.value.complete(
              _profile(pubkey: entry.key, displayName: 'Late'),
            );
          }
        }
        await _flush();
        expect(fetching, hasLength(keys.length));
        expect(cubit.state.candidates, hasLength(keys.length));
        expect(cubit.state.candidates.first.pubkey, _carolPubkey);
        expect(cubit.state.selectedPubkeys, {_carolPubkey});
      },
    );

    test('ranks available cached arrivals by signals before names', () async {
      when(() => followRepository.followingPubkeys).thenReturn([_alicePubkey]);
      when(() => profileRepository.getCachedProfile(pubkey: _bobPubkey))
          .thenAnswer(
            (_) async => _profile(pubkey: _bobPubkey, displayName: 'Zebra'),
          );
      when(() => profileRepository.getCachedProfile(pubkey: _carolPubkey))
          .thenAnswer(
            (_) async => _profile(pubkey: _carolPubkey, displayName: 'Aaron'),
          );
      when(() => rankingLoader.load(any())).thenAnswer(
        (invocation) async => {
          for (final key
              in invocation.positionalArguments.single as Iterable<String>)
            key: UserRankingSignals(
              pubkey: key,
              videoCount: key == _bobPubkey ? 100 : null,
            ),
        },
      );
      final cubit = createCubit();
      addTearDown(cubit.close);
      await cubit.started();
      followersController.add(
        const FollowersSnapshot(pubkeys: [_carolPubkey, _bobPubkey], count: 2),
      );
      await _flush();
      expect(cubit.state.candidates.map((c) => c.pubkey), [
        _alicePubkey,
        _bobPubkey,
        _carolPubkey,
      ]);
    });

    test('initial state is initial status with empty candidates', () async {
      final cubit = createCubit();
      expect(cubit.state.status, AddPeopleToListStatus.initial);
      expect(cubit.state.candidates, isEmpty);
      expect(cubit.state.query, isEmpty);
      expect(cubit.state.selectedPubkeys, isEmpty);
      await cubit.close();
    });

    group('ranked candidates', () {
      List<String> order(AddPeopleToListCubit cubit) =>
          cubit.state.candidates.map((c) => c.pubkey).toList();

      test('cubit candidates follow ranked order', () async {
        when(() => followRepository.followingPubkeys)
            .thenReturn([_alicePubkey, _bobPubkey]);
        when(() => rankingLoader.load(any())).thenAnswer(
          (_) async => {
            _alicePubkey: const UserRankingSignals(pubkey: _alicePubkey),
            _bobPubkey: UserRankingSignals(
              pubkey: _bobPubkey,
              lastInteractionAt: DateTime.now(),
            ),
          },
        );
        final cubit = createCubit();
        await cubit.started();
        expect(order(cubit), [_bobPubkey, _alicePubkey]);
        expect(
          cubit.state.rankingSignals.keys,
          containsAll([_alicePubkey, _bobPubkey]),
        );
        await cubit.close();
      });

      test(
        'late candidates append and keep their first-visible positions',
        () async {
          when(() => followRepository.followingPubkeys)
              .thenReturn([_davePubkey]);
          final cubit = createCubit();
          await cubit.started();
          expect(order(cubit), [_davePubkey]);
          followingController.add([_davePubkey, _carolPubkey]);
          await _flush();
          expect(order(cubit), [_davePubkey, _carolPubkey]);
          followersController.add(
            const FollowersSnapshot(pubkeys: [_alicePubkey], count: 1),
          );
          await _flush();
          expect(order(cubit), [_davePubkey, _carolPubkey, _alicePubkey]);
          followingController.add([
            _davePubkey,
            _carolPubkey,
            _alicePubkey,
            _bobPubkey,
          ]);
          await _flush();
          cubit.candidateToggled(_carolPubkey);
          expect(order(cubit), [
            _davePubkey,
            _carolPubkey,
            _alicePubkey,
            _bobPubkey,
          ]);
          await cubit.close();
        },
      );

      test(
        'cached names break initial score ties and fresh names keep positions',
        () async {
          final fresh = Completer<UserProfile?>();
          when(() => followRepository.followingPubkeys)
              .thenReturn([_alicePubkey, _bobPubkey]);
          when(() => rankingLoader.loadCachedDisplayNames(any())).thenAnswer(
            (_) async => {
              _alicePubkey: 'Zoe',
              _bobPubkey: 'Maria',
            },
          );
          when(() => profileRepository.fetchFreshProfile(pubkey: _alicePubkey))
              .thenAnswer((_) => fresh.future);
          final cubit = createCubit();
          await cubit.started();
          expect(order(cubit), [_bobPubkey, _alicePubkey]);
          fresh.complete(_profile(pubkey: _alicePubkey, displayName: 'Aaron'));
          await _flush();
          expect(order(cubit), [_bobPubkey, _alicePubkey]);
          expect(cubit.state.candidates.last.displayName, 'Aaron');
          await cubit.close();
        },
      );

      test(
        'successful ranking omissions remain hidden after relationship updates',
        () async {
          when(() => followRepository.followingPubkeys)
              .thenReturn([_alicePubkey, _bobPubkey]);
          when(() => rankingLoader.load(any())).thenAnswer(
            (_) async => {
              _bobPubkey: const UserRankingSignals(pubkey: _bobPubkey),
            },
          );
          final cubit = createCubit();
          await cubit.started();
          expect(order(cubit), [_bobPubkey]);
          followersController.add(
            const FollowersSnapshot(
              pubkeys: [_alicePubkey, _bobPubkey],
              count: 2,
            ),
          );
          await _flush();
          expect(order(cubit), [_bobPubkey]);
          await cubit.close();
        },
      );

      test('ranking failure reports error and still excludes ineligible candidates', () async {
        final messages = <String>[];
        final previousDebugPrint = debugPrint;
        debugPrint = (message, {wrapWidth}) {
          if (message != null) messages.add(message);
        };
        try {
          when(() => followRepository.followingPubkeys)
              .thenReturn([_alicePubkey, _bobPubkey]);
          final observer = _RecordingObserver();
          final previousObserver = Bloc.observer;
          Bloc.observer = observer;
          addTearDown(() => Bloc.observer = previousObserver);
          when(() => rankingLoader.load(any()))
              .thenThrow(StateError('local signals'));
          when(() => rankingLoader.isEligible(_alicePubkey)).thenReturn(false);
          final cubit = createCubit();
          await cubit.started();
          expect(cubit.state.status, AddPeopleToListStatus.ready);
          expect(order(cubit), [_bobPubkey]);
          expect(observer.errors.single, isA<ReportableError>());
          expect(
            messages.single,
            contains('Failed to load follow ranking: Bad state: local signals'),
          );
          await cubit.close();
        } finally {
          debugPrint = previousDebugPrint;
        }
      });

      test(
        'closing while initial ranking loads does not attach streams',
        () async {
          final signals = Completer<Map<String, UserRankingSignals>>();
          final entered = Completer<void>();
          when(() => followRepository.followingPubkeys)
              .thenReturn([_alicePubkey]);
          when(() => rankingLoader.load(any())).thenAnswer((_) {
            entered.complete();
            return signals.future;
          });
          final cubit = createCubit();
          final loading = cubit.started();
          await entered.future;
          await cubit.close();
          signals.complete({
            _alicePubkey: const UserRankingSignals(pubkey: _alicePubkey),
          });
          await loading;
          expect(cubit.isClosed, isTrue);
          verifyNever(() => followRepository.followingStream);
        },
      );
    });

    group('same-owner snapshot handoff', () {
      Future<AddPeopleToListState> selectedSnapshot() async {
        when(() => followRepository.followingPubkeys)
            .thenReturn([_alicePubkey, _bobPubkey]);
        final original = createCubit();
        await original.started();
        original.queryChanged('a');
        original.candidateToggled(_alicePubkey);
        final snapshot = original.state;
        expect(snapshot.candidates.map((c) => c.pubkey), [
          _alicePubkey,
          _bobPubkey,
        ]);
        expect(snapshot.selectedPubkeys, {_alicePubkey});
        await original.close();
        return snapshot;
      }

      test('revalidates retained rows and selection synchronously before a refresh', () async {
        final snapshot = await selectedSnapshot();
        when(() => rankingLoader.isEligible(_alicePubkey)).thenReturn(false);
        final replacement = createCubit(
          initialState: snapshot,
          existingMembers: [_bobPubkey],
        );
        expect(replacement.state.candidates.map((c) => c.pubkey), [_bobPubkey]);
        expect(replacement.state.candidates.single.isAlreadyInList, isTrue);
        expect(replacement.state.selectedPubkeys, isEmpty);
        expect(replacement.state.query, 'a');
        expect(replacement.state.candidatePositions[_bobPubkey], 1);
        await replacement.close();
      });

      test(
        'confirmation during refresh keeps rows and confirmed membership',
        () async {
          final snapshot = await selectedSnapshot();
          final signals = Completer<Map<String, UserRankingSignals>>();
          final entered = Completer<void>();
          when(() => rankingLoader.load(any())).thenAnswer((_) {
            entered.complete();
            return signals.future;
          });
          final replacement = createCubit(initialState: snapshot);
          final emitted = <AddPeopleToListState>[];
          final subscription = replacement.stream.listen(emitted.add);
          addTearDown(() async {
            if (!signals.isCompleted) signals.complete({});
            await subscription.cancel();
            await replacement.close();
          });
          final refresh = replacement.started();
          await entered.future;
          expect(replacement.state.status, AddPeopleToListStatus.ready);
          expect(
            replacement.state.candidates.map((candidate) => candidate.pubkey),
            [_alicePubkey, _bobPubkey],
          );
          replacement.additionsConfirmed({_alicePubkey});
          expect(
            replacement.state.candidates.map((candidate) => candidate.pubkey),
            [_alicePubkey, _bobPubkey],
          );
          expect(replacement.state.candidates.first.isAlreadyInList, isTrue);
          expect(replacement.state.selectedPubkeys, isEmpty);
          signals.complete({
            _alicePubkey: const UserRankingSignals(pubkey: _alicePubkey),
            _bobPubkey: const UserRankingSignals(pubkey: _bobPubkey),
          });
          await refresh;
          await _flush();
          expect(
            replacement.state.candidates.map((candidate) => candidate.pubkey),
            [_alicePubkey, _bobPubkey],
          );
          expect(replacement.state.candidates.first.isAlreadyInList, isTrue);
          expect(replacement.state.selectedPubkeys, isEmpty);
          expect(replacement.state.query, 'a');
          expect(emitted, isNotEmpty);
          for (final state in emitted) {
            expect(state.candidates.map((candidate) => candidate.pubkey), [
              _alicePubkey,
              _bobPubkey,
            ]);
          }
          await subscription.cancel();
          await replacement.close();
        },
      );

      test('successful refresh omissions remove retained rows and their selections', () async {
        final snapshot = await selectedSnapshot();
        when(() => rankingLoader.load(any())).thenAnswer(
          (_) async => {
            _bobPubkey: const UserRankingSignals(pubkey: _bobPubkey),
          },
        );
        final replacement = createCubit(initialState: snapshot);
        expect(replacement.state.selectedPubkeys, {_alicePubkey});
        await replacement.started();
        expect(replacement.state.candidates.map((c) => c.pubkey), [_bobPubkey]);
        expect(replacement.state.selectedPubkeys, isEmpty);
        expect(replacement.state.candidatePositions[_bobPubkey], 1);
        expect(replacement.state.query, 'a');
        await replacement.close();
      });
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

    group('additionsConfirmed', () {
      Future<AddPeopleToListCubit> startedWithTwoSelected() async {
        when(
          () => followRepository.followingPubkeys,
        ).thenReturn([_alicePubkey, _bobPubkey]);
        when(
          () => followRepository.watchMyFollowers(),
        ).thenAnswer((_) => const Stream.empty());
        final cubit = createCubit();
        await cubit.started();
        cubit
          ..candidateToggled(_alicePubkey)
          ..candidateToggled(_bobPubkey);
        return cubit;
      }

      PeopleListCandidate candidateOf(
        AddPeopleToListCubit cubit,
        String pubkey,
      ) => cubit.state.candidates.singleWhere((c) => c.pubkey == pubkey);

      test(
        'keeps unconfirmed people selected and not yet in the list',
        () async {
          final cubit = await startedWithTwoSelected();
          // Guards the assertions below: both choices begin selected.
          expect(cubit.state.selectedPubkeys, {_alicePubkey, _bobPubkey});

          cubit.additionsConfirmed({_alicePubkey});

          expect(cubit.state.selectedPubkeys, {_bobPubkey});
          expect(candidateOf(cubit, _alicePubkey).isAlreadyInList, isTrue);
          expect(candidateOf(cubit, _bobPubkey).isAlreadyInList, isFalse);

          await cubit.close();
        },
      );

      test('settles every person once all are confirmed', () async {
        final cubit = await startedWithTwoSelected();

        cubit.additionsConfirmed({_alicePubkey, _bobPubkey});

        expect(cubit.state.selectedPubkeys, isEmpty);
        expect(
          cubit.state.candidates.every((c) => c.isAlreadyInList),
          isTrue,
        );

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
          rankingSignalsLoader: rankingLoader,
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
