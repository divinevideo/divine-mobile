import 'dart:async';

import 'package:badge_repository/badge_repository.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/blocs/badges/badge_holders_cubit.dart';

class _MockBadgeRepository extends Mock implements BadgeRepository {}

void main() {
  group(BadgeHoldersCubit, () {
    late _MockBadgeRepository repository;

    setUpAll(() {
      registerFallbackValue(const BadgeCoordinate(pubkey: '', identifier: ''));
    });

    setUp(() {
      repository = _MockBadgeRepository();
    });

    BadgeHoldersCubit buildCubit({bool canSubscribe = true}) =>
        BadgeHoldersCubit(
          repository: repository,
          coordinate: _coordinate,
          canSubscribe: canSubscribe,
        );

    group('load', () {
      test('shows indexed holders before the complete relay result', () async {
        final relayResult = Completer<Set<String>>();
        when(
          () => repository.loadAcceptedHolders(_coordinate),
        ).thenAnswer((_) => relayResult.future);
        final cubit = BadgeHoldersCubit(
          repository: repository,
          coordinate: _coordinate,
          canSubscribe: false,
          loadIndexedPreview: (_) async => ['indexed'],
        );
        addTearDown(cubit.close);

        final preview = cubit.stream.firstWhere(
          (state) => state.holdersStatus == BadgeHoldersStatus.preview,
        );
        final load = cubit.load();
        expect((await preview).holders, ['indexed']);
        relayResult.complete({'indexed', 'federated'});
        await load;
        expect(cubit.state.holdersStatus, BadgeHoldersStatus.loaded);
        expect(cubit.state.holders, containsAll(['indexed', 'federated']));
      });

      test('uses the relay result when the index is unavailable', () async {
        when(
          () => repository.loadAcceptedHolders(_coordinate),
        ).thenAnswer((_) async => {'federated'});
        final cubit = BadgeHoldersCubit(
          repository: repository,
          coordinate: _coordinate,
          canSubscribe: false,
          loadIndexedPreview: (_) async => throw StateError('404'),
        );
        addTearDown(cubit.close);

        await cubit.load();
        expect(cubit.state.holdersStatus, BadgeHoldersStatus.loaded);
        expect(cubit.state.holders, ['federated']);
      });

      blocTest<BadgeHoldersCubit, BadgeHoldersState>(
        'loads the holders and whether the viewer subscribes',
        setUp: () {
          when(
            () => repository.loadAcceptedHolders(_coordinate),
          ).thenAnswer((_) async => {'holder'});
          when(
            () => repository.loadSubscriptions(),
          ).thenAnswer((_) async => {_coordinate});
        },
        build: buildCubit,
        act: (cubit) => cubit.load(),
        verify: (cubit) {
          expect(cubit.state.holdersStatus, BadgeHoldersStatus.loaded);
          expect(cubit.state.holders, ['holder']);
          expect(
            cubit.state.subscriptionStatus,
            BadgeSubscriptionStatus.ready,
          );
          expect(cubit.state.isSubscribed, isTrue);
        },
      );

      blocTest<BadgeHoldersCubit, BadgeHoldersState>(
        'does not read a subscription without a signed-in account',
        setUp: () {
          when(
            () => repository.loadAcceptedHolders(_coordinate),
          ).thenAnswer((_) async => {'holder'});
        },
        build: () => buildCubit(canSubscribe: false),
        act: (cubit) => cubit.load(),
        verify: (cubit) {
          expect(
            cubit.state.subscriptionStatus,
            BadgeSubscriptionStatus.unavailable,
          );
          verifyNever(() => repository.loadSubscriptions());
        },
      );

      blocTest<BadgeHoldersCubit, BadgeHoldersState>(
        'reports failures for an incomplete holder or subscription read',
        setUp: () {
          when(
            () => repository.loadAcceptedHolders(_coordinate),
          ).thenThrow(StateError('Badge holders could not be fully loaded'));
          when(
            () => repository.loadSubscriptions(),
          ).thenThrow(StateError('relay unavailable'));
        },
        build: buildCubit,
        act: (cubit) => cubit.load(),
        errors: () => [isA<StateError>(), isA<StateError>()],
        verify: (cubit) {
          expect(cubit.state.holdersStatus, BadgeHoldersStatus.failure);
          expect(
            cubit.state.subscriptionStatus,
            BadgeSubscriptionStatus.failure,
          );
        },
      );
    });

    group('toggleSubscription', () {
      blocTest<BadgeHoldersCubit, BadgeHoldersState>(
        'publishes the change and bumps the subscription revision',
        setUp: () {
          when(
            () => repository.setSubscription(_coordinate, subscribed: true),
          ).thenAnswer((_) async => {_coordinate});
        },
        seed: () => const BadgeHoldersState(
          coordinate: _coordinate,
          subscriptionStatus: BadgeSubscriptionStatus.ready,
        ),
        build: buildCubit,
        act: (cubit) => cubit.toggleSubscription(),
        expect: () => [
          const BadgeHoldersState(
            coordinate: _coordinate,
            subscriptionStatus: BadgeSubscriptionStatus.saving,
          ),
          const BadgeHoldersState(
            coordinate: _coordinate,
            subscriptionStatus: BadgeSubscriptionStatus.ready,
            isSubscribed: true,
          ),
        ],
      );

      blocTest<BadgeHoldersCubit, BadgeHoldersState>(
        'keeps the subscription and counts the failure when publishing fails',
        setUp: () {
          when(
            () => repository.setSubscription(_coordinate, subscribed: false),
          ).thenThrow(Exception('rejected'));
        },
        seed: () => const BadgeHoldersState(
          coordinate: _coordinate,
          subscriptionStatus: BadgeSubscriptionStatus.ready,
          isSubscribed: true,
        ),
        build: buildCubit,
        act: (cubit) => cubit.toggleSubscription(),
        errors: () => [isA<Exception>()],
        expect: () => [
          const BadgeHoldersState(
            coordinate: _coordinate,
            subscriptionStatus: BadgeSubscriptionStatus.saving,
            isSubscribed: true,
          ),
          const BadgeHoldersState(
            coordinate: _coordinate,
            subscriptionStatus: BadgeSubscriptionStatus.ready,
            isSubscribed: true,
            saveFailures: 1,
          ),
        ],
      );

      blocTest<BadgeHoldersCubit, BadgeHoldersState>(
        'ignores a toggle before the subscription is known',
        build: buildCubit,
        act: (cubit) => cubit.toggleSubscription(),
        expect: () => const <BadgeHoldersState>[],
        verify: (_) => verifyNever(
          () => repository.setSubscription(
            any(),
            subscribed: any(named: 'subscribed'),
          ),
        ),
      );
    });
  });
}

const _coordinate = BadgeCoordinate(
  pubkey: '0000000000000000000000000000000000000000000000000000000000000065',
  identifier: 'scene-stealer',
);
