// ABOUTME: Covers the bell cubit's optimistic toggle, revert-on-failure, and
// ABOUTME: unfollow teardown.

import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/blocs/notify_bell/notify_bell_cubit.dart';
import 'package:openvine/observability/reportable_error.dart';
import 'package:people_lists_repository/people_lists_repository.dart';

class _MockNotifySubscriptionsRepository extends Mock
    implements NotifySubscriptionsRepository {}

const _viewer = 'viewer_pubkey_hex';
const _creator = 'creator_pubkey_hex';

void main() {
  group(NotifyBellCubit, () {
    late _MockNotifySubscriptionsRepository repository;
    late StreamController<Set<String>> subscriptions;

    setUp(() {
      repository = _MockNotifySubscriptionsRepository();
      subscriptions = StreamController<Set<String>>.broadcast();
      when(
        () => repository.watchSubscriptions(
          ownerPubkey: any(named: 'ownerPubkey'),
        ),
      ).thenAnswer((_) => subscriptions.stream);
      when(
        () => repository.reconcile(ownerPubkey: any(named: 'ownerPubkey')),
      ).thenAnswer((_) async => const PeopleListPublishResult.noop());
    });

    tearDown(() async {
      await subscriptions.close();
    });

    NotifyBellCubit build() => NotifyBellCubit(
      repository: repository,
      viewerPubkey: _viewer,
      creatorPubkey: _creator,
    );

    blocTest<NotifyBellCubit, NotifyBellState>(
      'is not interactive until the subscription list loads',
      build: build,
      verify: (cubit) {
        expect(cubit.state.isInteractive, isFalse);
        expect(cubit.state.isSubscribed, isFalse);
      },
    );

    blocTest<NotifyBellCubit, NotifyBellState>(
      'becomes subscribed when the list contains this creator',
      build: build,
      act: (cubit) async {
        await cubit.load();
        subscriptions.add({_creator});
      },
      expect: () => const [
        NotifyBellState(status: NotifyBellStatus.ready, isSubscribed: true),
      ],
    );

    blocTest<NotifyBellCubit, NotifyBellState>(
      'drains an unfollow teardown that never reached the relays',
      build: build,
      act: (cubit) => cubit.load(),
      verify: (_) {
        verify(() => repository.reconcile(ownerPubkey: _viewer)).called(1);
      },
    );

    blocTest<NotifyBellCubit, NotifyBellState>(
      'ignores a list containing only other creators',
      build: build,
      act: (cubit) async {
        await cubit.load();
        subscriptions.add({'someone_else_pubkey_hex'});
      },
      expect: () => const [NotifyBellState(status: NotifyBellStatus.ready)],
    );

    group('toggle', () {
      blocTest<NotifyBellCubit, NotifyBellState>(
        'flips on optimistically before the publish resolves',
        build: build,
        setUp: () {
          when(
            () => repository.subscribe(
              ownerPubkey: any(named: 'ownerPubkey'),
              creatorPubkey: any(named: 'creatorPubkey'),
            ),
          ).thenAnswer((_) async {
            await Future<void>.delayed(const Duration(milliseconds: 20));
            return const PeopleListPublishResult.submitted(eventId: 'e1');
          });
        },
        act: (cubit) async {
          await cubit.load();
          subscriptions.add(const <String>{});
          await Future<void>.delayed(Duration.zero);
          await cubit.toggle();
        },
        expect: () => const [
          NotifyBellState(status: NotifyBellStatus.ready),
          NotifyBellState(status: NotifyBellStatus.ready, isSubscribed: true),
        ],
      );

      blocTest<NotifyBellCubit, NotifyBellState>(
        'reverts and reports failure when the publish fails',
        build: build,
        setUp: () {
          when(
            () => repository.subscribe(
              ownerPubkey: any(named: 'ownerPubkey'),
              creatorPubkey: any(named: 'creatorPubkey'),
            ),
          ).thenAnswer((_) async => const PeopleListPublishResult.failed());
        },
        act: (cubit) async {
          await cubit.load();
          subscriptions.add(const <String>{});
          await Future<void>.delayed(Duration.zero);
          await cubit.toggle();
        },
        expect: () => const [
          NotifyBellState(status: NotifyBellStatus.ready),
          NotifyBellState(status: NotifyBellStatus.ready, isSubscribed: true),
          NotifyBellState(status: NotifyBellStatus.failure),
        ],
      );

      blocTest<NotifyBellCubit, NotifyBellState>(
        'unsubscribes when already subscribed',
        build: build,
        setUp: () {
          when(
            () => repository.unsubscribe(
              ownerPubkey: any(named: 'ownerPubkey'),
              creatorPubkey: any(named: 'creatorPubkey'),
            ),
          ).thenAnswer(
            (_) async => const PeopleListPublishResult.submitted(eventId: 'e1'),
          );
        },
        act: (cubit) async {
          await cubit.load();
          subscriptions.add({_creator});
          await Future<void>.delayed(Duration.zero);
          await cubit.toggle();
        },
        verify: (_) {
          verify(
            () => repository.unsubscribe(
              ownerPubkey: _viewer,
              creatorPubkey: _creator,
            ),
          ).called(1);
        },
      );

      blocTest<NotifyBellCubit, NotifyBellState>(
        'does nothing before the list has loaded',
        build: build,
        act: (cubit) => cubit.toggle(),
        expect: () => const <NotifyBellState>[],
        verify: (_) {
          verifyNever(
            () => repository.subscribe(
              ownerPubkey: any(named: 'ownerPubkey'),
              creatorPubkey: any(named: 'creatorPubkey'),
            ),
          );
        },
      );

      blocTest<NotifyBellCubit, NotifyBellState>(
        'reverts and reports when the repository throws',
        build: build,
        setUp: () {
          when(
            () => repository.subscribe(
              ownerPubkey: any(named: 'ownerPubkey'),
              creatorPubkey: any(named: 'creatorPubkey'),
            ),
          ).thenThrow(StateError('no signer'));
        },
        act: (cubit) async {
          await cubit.load();
          subscriptions.add(const <String>{});
          await Future<void>.delayed(Duration.zero);
          await cubit.toggle();
        },
        expect: () => const [
          NotifyBellState(status: NotifyBellStatus.ready),
          NotifyBellState(status: NotifyBellStatus.ready, isSubscribed: true),
          NotifyBellState(status: NotifyBellStatus.failure),
        ],
        errors: () => [
          isA<Reportable<Object>>().having(
            (r) => r.unwrap(),
            'unwrap',
            isA<StateError>(),
          ),
        ],
      );
    });
  });
}
