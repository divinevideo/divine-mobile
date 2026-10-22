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

    group('retrySubscription', () {
      test(
        'keeps loaded holders while retrying only the subscription',
        () async {
          when(() => repository.loadAcceptedHolders(_coordinate))
              .thenAnswer((_) async => {'holder'});
          var reads = 0;
          when(
            () => repository.loadSubscriptions(requireComplete: true),
          ).thenAnswer((_) async {
            if (reads++ == 0) throw const BadgeReadIncompleteException('read');
            return {_coordinate};
          });
          final cubit = buildCubit();
          addTearDown(cubit.close);
          await cubit.load();
          await cubit.retrySubscription();
          expect(cubit.state.holders, ['holder']);
          expect(cubit.state.holdersStatus, BadgeHoldersStatus.loaded);
          expect(cubit.state.subscriptionStatus, BadgeSubscriptionStatus.ready);
          expect(cubit.state.isSubscribed, isTrue);
          verify(() => repository.loadAcceptedHolders(_coordinate)).called(1);
        },
      );
    });

    group('load', () {
      for (final oldFailure in [false, true]) {
        test(
          'new load owns holders and subscription after stale completion, failure $oldFailure',
          () async {
            final oldHolders = Completer<Set<String>>();
            final oldSubscriptions = Completer<Set<BadgeCoordinate>>();
            var holderReads = 0;
            var subscriptionReads = 0;
            when(() => repository.loadAcceptedHolders(_coordinate)).thenAnswer(
              (_) => holderReads++ == 0
                  ? oldHolders.future
                  : Future.value({'new-holder'}),
            );
            when(() => repository.loadSubscriptions(requireComplete: true))
                .thenAnswer(
                  (_) => subscriptionReads++ == 0
                      ? oldSubscriptions.future
                      : Future.value({_coordinate}),
                );
            final cubit = buildCubit();
            addTearDown(cubit.close);
            final oldLoad = cubit.load();
            await cubit.load();
            if (oldFailure) {
              oldHolders.completeError(
                const BadgeReadIncompleteException('stale'),
              );
              oldSubscriptions.completeError(
                const BadgeReadIncompleteException('stale'),
              );
            } else {
              oldHolders.complete({'old-holder'});
              oldSubscriptions.complete({});
            }
            await oldLoad;
            expect(cubit.state.holdersStatus, BadgeHoldersStatus.loaded);
            expect(cubit.state.holders, ['new-holder']);
            expect(
              cubit.state.subscriptionStatus,
              BadgeSubscriptionStatus.ready,
            );
            expect(cubit.state.isSubscribed, isTrue);
          },
        );
      }

      test(
        'stale preview cannot replace a newer load still awaiting holders',
        () async {
          final previews = [
            Completer<List<String>>(),
            Completer<List<String>>(),
          ];
          final holders = [Completer<Set<String>>(), Completer<Set<String>>()];
          var previewReads = 0;
          var holderReads = 0;
          when(() => repository.loadAcceptedHolders(_coordinate))
              .thenAnswer((_) => holders[holderReads++].future);
          when(() => repository.withoutHiddenPubkeys(any())).thenAnswer(
            (call) => call.positionalArguments.first as List<String>,
          );
          final cubit = BadgeHoldersCubit(
            repository: repository,
            coordinate: _coordinate,
            canSubscribe: false,
            loadIndexedPreview: (_) => previews[previewReads++].future,
          );
          addTearDown(cubit.close);
          final oldLoad = cubit.load();
          final newLoad = cubit.load();
          previews.first.complete(['old']);
          await Future<void>.value();
          expect(cubit.state.holdersStatus, BadgeHoldersStatus.loading);
          expect(cubit.state.holders, isEmpty);
          previews.last.complete(['new']);
          holders.first.complete({'old'});
          holders.last.complete({'new'});
          await Future.wait([oldLoad, newLoad]);
          expect(cubit.state.holders, ['new']);
        },
      );

      test('leaves hidden accounts out of the indexed preview', () async {
        final relayResult = Completer<Set<String>>();
        when(
          () => repository.loadAcceptedHolders(_coordinate),
        ).thenAnswer((_) => relayResult.future);
        when(
          () => repository.withoutHiddenPubkeys(['indexed', 'blocked']),
        ).thenReturn(['indexed']);
        final cubit = BadgeHoldersCubit(
          repository: repository,
          coordinate: _coordinate,
          canSubscribe: false,
          loadIndexedPreview: (_) async => ['indexed', 'blocked'],
        );
        addTearDown(cubit.close);

        final preview = cubit.stream.firstWhere(
          (state) => state.holdersStatus == BadgeHoldersStatus.preview,
        );
        final load = cubit.load();
        expect((await preview).holders, ['indexed']);
        relayResult.complete({'indexed'});
        await load;
      });

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
        when(
          () => repository.withoutHiddenPubkeys(['indexed']),
        ).thenReturn(['indexed']);
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

      test(
        'late indexed preview cannot replace completed relay holders',
        () async {
          final preview = Completer<List<String>>();
          final relay = Completer<Set<String>>();
          when(() => repository.loadAcceptedHolders(_coordinate))
              .thenAnswer((_) => relay.future);
          when(() => repository.withoutHiddenPubkeys(['indexed']))
              .thenReturn(['indexed']);
          final cubit = BadgeHoldersCubit(
            repository: repository,
            coordinate: _coordinate,
            canSubscribe: false,
            loadIndexedPreview: (_) => preview.future,
          );
          addTearDown(cubit.close);
          final loading = cubit.load();
          final complete = cubit.stream.firstWhere(
            (s) => s.holdersStatus == BadgeHoldersStatus.loaded,
          );
          relay.complete({'relay'});
          await complete;
          preview.complete(['indexed']);
          await loading;
          expect(cubit.state.holdersStatus, BadgeHoldersStatus.loaded);
          expect(cubit.state.holders, ['relay']);
        },
      );

      test('uses the relay result when the index is unavailable', () async {
        when(
          () => repository.loadAcceptedHolders(_coordinate),
        ).thenAnswer((_) async => {'federated'});
        final cubit = BadgeHoldersCubit(
          repository: repository,
          coordinate: _coordinate,
          canSubscribe: false,
          loadIndexedPreview: (_) async =>
              throw const BadgeReadIncompleteException('404'),
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
            () => repository.loadSubscriptions(requireComplete: true),
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
          verifyNever(
            () => repository.loadSubscriptions(requireComplete: true),
          );
        },
      );

      blocTest<BadgeHoldersCubit, BadgeHoldersState>(
        'reports failures for an incomplete holder or subscription read',
        setUp: () {
          when(
            () => repository.loadAcceptedHolders(_coordinate),
          ).thenThrow(
            const BadgeReadIncompleteException(
              'Badge holders could not be fully loaded',
            ),
          );
          when(
            () => repository.loadSubscriptions(requireComplete: true),
          ).thenThrow(const BadgeReadIncompleteException('relay unavailable'));
        },
        build: buildCubit,
        act: (cubit) => cubit.load(),
        errors: () => [
          isA<BadgeReadIncompleteException>(),
          isA<BadgeReadIncompleteException>(),
        ],
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
        'publishes the change and updates subscription state',
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
