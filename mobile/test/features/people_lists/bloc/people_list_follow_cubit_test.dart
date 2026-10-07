// ABOUTME: Tests for PeopleListFollowCubit: whether a list reads as followed,
// ABOUTME: and what following, unfollowing and a failed write do to the state.

import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/features/people_lists/bloc/people_list_follow_cubit.dart';
import 'package:openvine/observability/reportable_error.dart';
import 'package:people_lists_repository/people_lists_repository.dart';

class _MockPeopleListsRepository extends Mock
    implements PeopleListsRepository {}

// Full-length 64-char pubkeys — never truncate.
final String _viewer = 'a' * 64;
final String _owner = 'b' * 64;
final String _otherOwner = 'c' * 64;
final String _member = 'd' * 64;

UserList _list({String id = 'crew'}) {
  final stamp = DateTime.utc(2026);
  return UserList(
    id: id,
    name: 'Crew',
    pubkeys: [_member],
    createdAt: stamp,
    updatedAt: stamp,
    isEditable: false,
  );
}

PeopleListSearchResult _followed({String? ownerPubkey, String id = 'crew'}) =>
    PeopleListSearchResult(
      ownerPubkey: ownerPubkey ?? _owner,
      list: _list(id: id),
    );

void main() {
  setUpAll(() => registerFallbackValue(_list()));

  group(PeopleListFollowCubit, () {
    late _MockPeopleListsRepository repository;
    late StreamController<List<PeopleListSearchResult>> followedController;
    late bool durableFollow;

    setUp(() {
      repository = _MockPeopleListsRepository();
      durableFollow = false;
      when(
        () => repository.isFollowingList(
          viewerPubkey: _viewer,
          ownerPubkey: _owner,
          listId: 'crew',
        ),
      ).thenAnswer((_) async => durableFollow);
      followedController =
          StreamController<List<PeopleListSearchResult>>.broadcast();
      when(
        () => repository.watchFollowedLists(viewerPubkey: _viewer),
      ).thenAnswer((_) => followedController.stream);
    });

    tearDown(() => followedController.close());

    PeopleListFollowCubit buildCubit() => PeopleListFollowCubit(
      repository: repository,
      viewerPubkey: _viewer,
      ownerPubkey: _owner,
      listId: 'crew',
    );

    test('unfollows a durable reference without a resolved list', () async {
      durableFollow = true;
      when(
        () => repository.unfollowList(
          viewerPubkey: _viewer,
          ownerPubkey: _owner,
          listId: 'crew',
        ),
      ).thenAnswer((_) async => durableFollow = false);
      final cubit = buildCubit();
      addTearDown(cubit.close);
      await cubit.started();
      followedController.add(const []);
      await pumpEventQueue();
      expect(cubit.state.isFollowing, isTrue);
      await cubit.unfollowed();
      expect(cubit.state.isFollowing, isFalse);
      expect(cubit.state.status, PeopleListFollowStatus.ready);
      verify(
        () => repository.unfollowList(
          viewerPubkey: _viewer,
          ownerPubkey: _owner,
          listId: 'crew',
        ),
      ).called(1);
      await cubit.unfollowed();
      verifyNever(
        () => repository.followList(
          viewerPubkey: any(named: 'viewerPubkey'),
          ownerPubkey: any(named: 'ownerPubkey'),
          list: any(named: 'list'),
        ),
      );
    });

    test('starts out loading and not followed', () {
      final cubit = buildCubit();
      addTearDown(cubit.close);

      expect(cubit.state, equals(const PeopleListFollowState()));
      expect(cubit.state.isBusy, isTrue);
    });

    group('started', () {
      test('reads the follow without waiting for the watch to emit', () async {
        durableFollow = true;
        final cubit = buildCubit();
        addTearDown(cubit.close);

        await cubit.started();
        await pumpEventQueue();

        expect(cubit.state.hasReadFollowing, isTrue);
        expect(cubit.state.isFollowing, isTrue);
        expect(cubit.state.status, PeopleListFollowStatus.ready);
      });

      test(
        'a failed initial read cannot follow until an explicit retry',
        () async {
          var unavailable = true;
          when(
            () => repository.isFollowingList(
              viewerPubkey: _viewer,
              ownerPubkey: _owner,
              listId: 'crew',
            ),
          ).thenAnswer((_) async {
            if (unavailable) throw Exception('durable store unavailable');
            return true;
          });
          final cubit = buildCubit();
          addTearDown(cubit.close);
          await cubit.started();
          followedController.add(const []);
          await pumpEventQueue();
          expect(cubit.state.hasReadFollowing, isFalse);
          expect(cubit.state.isBusy, isTrue);
          await cubit.toggled(_list());
          verifyNever(
            () => repository.followList(
              viewerPubkey: any(named: 'viewerPubkey'),
              ownerPubkey: any(named: 'ownerPubkey'),
              list: any(named: 'list'),
            ),
          );
          unavailable = false;
          await cubit.retryRead();
          expect(cubit.state.hasReadFollowing, isTrue);
          expect(cubit.state.isFollowing, isTrue);
          expect(cubit.state.status, PeopleListFollowStatus.ready);
        },
      );

      test('stream error reads durable Following', () async {
        durableFollow = true;
        final cubit = buildCubit();
        addTearDown(cubit.close);
        await cubit.started();
        followedController.addError(StateError('box corrupt'));
        await pumpEventQueue();
        expect(cubit.state.isFollowing, isTrue);
        expect(cubit.state.status, PeopleListFollowStatus.failure);
      });

      blocTest<PeopleListFollowCubit, PeopleListFollowState>(
        'reads durable follow status when the list changes',
        setUp: () => durableFollow = true,
        build: buildCubit,
        act: (cubit) async {
          await cubit.started();
          followedController.add([_followed()]);
        },
        expect: () => const [
          PeopleListFollowState(
            hasReadFollowing: true,
            status: PeopleListFollowStatus.ready,
            isFollowing: true,
          ),
        ],
      );

      blocTest<PeopleListFollowCubit, PeopleListFollowState>(
        "does not count another owner's list with the same d tag, or "
        "this owner's other list",
        build: buildCubit,
        act: (cubit) async {
          await cubit.started();
          followedController.add([
            _followed(ownerPubkey: _otherOwner),
            _followed(id: 'friends'),
          ]);
        },
        expect: () => const [
          PeopleListFollowState(
            hasReadFollowing: true,
            status: PeopleListFollowStatus.ready,
          ),
        ],
      );

      blocTest<PeopleListFollowCubit, PeopleListFollowState>(
        'follows an unfollow made somewhere else',
        build: buildCubit,
        act: (cubit) async {
          await cubit.started();
          durableFollow = true;
          followedController.add([_followed()]);
          await pumpEventQueue();
          durableFollow = false;
          followedController.add(const []);
        },
        expect: () => const [
          PeopleListFollowState(
            hasReadFollowing: true,
            status: PeopleListFollowStatus.ready,
          ),
          PeopleListFollowState(
            hasReadFollowing: true,
            status: PeopleListFollowStatus.ready,
            isFollowing: true,
          ),
          PeopleListFollowState(
            hasReadFollowing: true,
            status: PeopleListFollowStatus.ready,
          ),
        ],
      );

      blocTest<PeopleListFollowCubit, PeopleListFollowState>(
        'reports a follows stream that fails, without claiming a follow',
        build: buildCubit,
        act: (cubit) async {
          await cubit.started();
          followedController.addError(StateError('box will not open'));
        },
        expect: () => const [
          PeopleListFollowState(
            hasReadFollowing: true,
            status: PeopleListFollowStatus.ready,
          ),
          PeopleListFollowState(
            hasReadFollowing: true,
            status: PeopleListFollowStatus.failure,
          ),
        ],
        errors: () => [isA<StateError>()],
      );

      test(
        'keeps Following without a cached copy and toggles an unfollow',
        () async {
          durableFollow = true;
          when(
            () => repository.unfollowList(
              viewerPubkey: _viewer,
              ownerPubkey: _owner,
              listId: 'crew',
            ),
          ).thenAnswer((_) async {
            durableFollow = false;
          });
          final cubit = buildCubit();
          addTearDown(cubit.close);
          await cubit.started();
          followedController.add(const []);
          await pumpEventQueue();

          expect(cubit.state.isFollowing, isTrue);
          expect(cubit.state.status, PeopleListFollowStatus.ready);
          await cubit.toggled(_list());

          expect(cubit.state.isFollowing, isFalse);
          verify(
            () => repository.unfollowList(
              viewerPubkey: _viewer,
              ownerPubkey: _owner,
              listId: 'crew',
            ),
          ).called(1);
          verifyNever(
            () => repository.followList(
              viewerPubkey: any(named: 'viewerPubkey'),
              ownerPubkey: any(named: 'ownerPubkey'),
              list: any(named: 'list'),
            ),
          );
        },
      );

      test(
        'a stale durable read cannot overwrite a newer follow update',
        () async {
          final oldRead = Completer<bool>();
          var reads = 0;
          when(
            () => repository.isFollowingList(
              viewerPubkey: _viewer,
              ownerPubkey: _owner,
              listId: 'crew',
            ),
          ).thenAnswer(
            (_) => reads++ == 0 ? oldRead.future : Future.value(true),
          );
          final cubit = buildCubit();
          addTearDown(cubit.close);
          await cubit.started();
          followedController.add(const []);
          await pumpEventQueue();
          followedController.add(const []);
          await pumpEventQueue();
          expect(cubit.state.isFollowing, isTrue);

          oldRead.complete(false);
          await pumpEventQueue();

          expect(cubit.state.isFollowing, isTrue);
        },
      );

      test(
        'a read started before an unfollow cannot restore Following',
        () async {
          durableFollow = true;
          final cubit = buildCubit();
          addTearDown(cubit.close);
          await cubit.started();
          followedController.add(const []);
          await pumpEventQueue();
          final staleRead = Completer<bool>();
          when(
            () => repository.isFollowingList(
              viewerPubkey: _viewer,
              ownerPubkey: _owner,
              listId: 'crew',
            ),
          ).thenAnswer((_) => staleRead.future);
          followedController.add(const []);
          await pumpEventQueue();
          when(
            () => repository.unfollowList(
              viewerPubkey: _viewer,
              ownerPubkey: _owner,
              listId: 'crew',
            ),
          ).thenAnswer((_) async {});
          when(
            () => repository.isFollowingList(
              viewerPubkey: _viewer,
              ownerPubkey: _owner,
              listId: 'crew',
            ),
          ).thenAnswer((_) async => false);

          await cubit.toggled(_list());
          staleRead.complete(true);
          await pumpEventQueue();

          expect(cubit.state.isFollowing, isFalse);
          expect(cubit.state.status, PeopleListFollowStatus.ready);
        },
      );

      test('stops listening on close', () async {
        final cubit = buildCubit();
        await cubit.started();
        expect(followedController.hasListener, isTrue);

        await cubit.close();

        expect(followedController.hasListener, isFalse);
      });
    });

    group('toggled', () {
      blocTest<PeopleListFollowCubit, PeopleListFollowState>(
        'follows the list on screen for this viewer',
        setUp: () {
          when(
            () => repository.followList(
              viewerPubkey: any(named: 'viewerPubkey'),
              ownerPubkey: any(named: 'ownerPubkey'),
              list: any(named: 'list'),
            ),
          ).thenAnswer((_) async {
            durableFollow = true;
          });
        },
        build: buildCubit,
        seed: () => const PeopleListFollowState(
          hasReadFollowing: true,
          status: PeopleListFollowStatus.ready,
        ),
        act: (cubit) => cubit.toggled(_list()),
        expect: () => const [
          PeopleListFollowState(
            hasReadFollowing: true,
            status: PeopleListFollowStatus.updating,
          ),
          PeopleListFollowState(
            hasReadFollowing: true,
            status: PeopleListFollowStatus.ready,
            isFollowing: true,
          ),
        ],
        verify: (_) {
          verify(
            () => repository.followList(
              viewerPubkey: _viewer,
              ownerPubkey: _owner,
              list: _list(),
            ),
          ).called(1);
        },
      );

      blocTest<PeopleListFollowCubit, PeopleListFollowState>(
        'unfollows a followed list',
        setUp: () {
          when(
            () => repository.unfollowList(
              viewerPubkey: any(named: 'viewerPubkey'),
              ownerPubkey: any(named: 'ownerPubkey'),
              listId: any(named: 'listId'),
            ),
          ).thenAnswer((_) async {
            durableFollow = false;
          });
        },
        build: buildCubit,
        seed: () => const PeopleListFollowState(
          hasReadFollowing: true,
          status: PeopleListFollowStatus.ready,
          isFollowing: true,
        ),
        act: (cubit) => cubit.toggled(_list()),
        expect: () => const [
          PeopleListFollowState(
            hasReadFollowing: true,
            status: PeopleListFollowStatus.updating,
            isFollowing: true,
          ),
          PeopleListFollowState(
            hasReadFollowing: true,
            status: PeopleListFollowStatus.ready,
          ),
        ],
        verify: (_) {
          verify(
            () => repository.unfollowList(
              viewerPubkey: _viewer,
              ownerPubkey: _owner,
              listId: 'crew',
            ),
          ).called(1);
        },
      );

      blocTest<PeopleListFollowCubit, PeopleListFollowState>(
        'keeps the list unfollowed and reports it when the write fails',
        setUp: () {
          when(
            () => repository.followList(
              viewerPubkey: any(named: 'viewerPubkey'),
              ownerPubkey: any(named: 'ownerPubkey'),
              list: any(named: 'list'),
            ),
          ).thenThrow(Exception('disk full'));
        },
        build: buildCubit,
        seed: () => const PeopleListFollowState(
          hasReadFollowing: true,
          status: PeopleListFollowStatus.ready,
        ),
        act: (cubit) => cubit.toggled(_list()),
        expect: () => const [
          PeopleListFollowState(
            hasReadFollowing: true,
            status: PeopleListFollowStatus.updating,
          ),
          PeopleListFollowState(
            hasReadFollowing: true,
            status: PeopleListFollowStatus.failure,
          ),
        ],
        errors: () => [isA<Exception>()],
      );

      blocTest<PeopleListFollowCubit, PeopleListFollowState>(
        'frees the control and reports it when the write hits a bug',
        setUp: () {
          when(
            () => repository.followList(
              viewerPubkey: any(named: 'viewerPubkey'),
              ownerPubkey: any(named: 'ownerPubkey'),
              list: any(named: 'list'),
            ),
          ).thenThrow(StateError('box is closed'));
        },
        build: buildCubit,
        seed: () => const PeopleListFollowState(
          hasReadFollowing: true,
          status: PeopleListFollowStatus.ready,
        ),
        act: (cubit) => cubit.toggled(_list()),
        expect: () => const [
          PeopleListFollowState(
            hasReadFollowing: true,
            status: PeopleListFollowStatus.updating,
          ),
          PeopleListFollowState(
            hasReadFollowing: true,
            status: PeopleListFollowStatus.failure,
          ),
        ],
        errors: () => [
          isA<Reportable<Object>>().having(
            (reportable) => reportable.unwrap(),
            'unwrap',
            isA<StateError>(),
          ),
        ],
      );

      blocTest<PeopleListFollowCubit, PeopleListFollowState>(
        'can be tried again after a failure',
        setUp: () {
          when(
            () => repository.followList(
              viewerPubkey: any(named: 'viewerPubkey'),
              ownerPubkey: any(named: 'ownerPubkey'),
              list: any(named: 'list'),
            ),
          ).thenAnswer((_) async {
            durableFollow = true;
          });
        },
        build: buildCubit,
        seed: () => const PeopleListFollowState(
          hasReadFollowing: true,
          status: PeopleListFollowStatus.failure,
        ),
        act: (cubit) => cubit.toggled(_list()),
        expect: () => const [
          PeopleListFollowState(
            hasReadFollowing: true,
            status: PeopleListFollowStatus.updating,
          ),
          PeopleListFollowState(
            hasReadFollowing: true,
            status: PeopleListFollowStatus.ready,
            isFollowing: true,
          ),
        ],
      );

      blocTest<PeopleListFollowCubit, PeopleListFollowState>(
        'ignores a tap while the follows are still being read',
        build: buildCubit,
        act: (cubit) => cubit.toggled(_list()),
        expect: () => const <PeopleListFollowState>[],
        verify: (_) {
          verifyNever(
            () => repository.followList(
              viewerPubkey: any(named: 'viewerPubkey'),
              ownerPubkey: any(named: 'ownerPubkey'),
              list: any(named: 'list'),
            ),
          );
        },
      );

      blocTest<PeopleListFollowCubit, PeopleListFollowState>(
        'ignores a second tap while a write is in flight',
        build: buildCubit,
        seed: () => const PeopleListFollowState(
          hasReadFollowing: true,
          status: PeopleListFollowStatus.updating,
        ),
        act: (cubit) => cubit.toggled(_list()),
        expect: () => const <PeopleListFollowState>[],
      );
    });
  });
}
