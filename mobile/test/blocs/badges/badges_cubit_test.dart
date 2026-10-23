import 'dart:async';

import 'package:badge_repository/badge_repository.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nostr_sdk/nostr_sdk.dart';
import 'package:openvine/blocs/badges/badges_cubit.dart';

class _MockBadgeRepository extends Mock implements BadgeRepository {}

void main() {
  group('BadgesCubit', () {
    late _MockBadgeRepository repository;
    late BadgeAwardViewData awardedBadge;
    late IssuedBadgeViewData issuedBadge;
    late CreatedBadgeViewData createdBadge;
    late BadgeDashboardData dashboard;

    setUpAll(() {
      registerFallbackValue(_awardViewData());
    });

    setUp(() {
      repository = _MockBadgeRepository();
      awardedBadge = _awardViewData();
      issuedBadge = _issuedViewData();
      createdBadge = _createdViewData();
      dashboard = BadgeDashboardData(
        awarded: [awardedBadge],
        issued: [issuedBadge],
        created: [createdBadge],
      );
    });

    test('initial state is correct', () {
      final cubit = BadgesCubit(repository: repository);

      expect(cubit.state.status, BadgesStatus.initial);
      expect(cubit.state.actionStatus, BadgeActionStatus.idle);
      expect(cubit.state.awarded, isEmpty);
      expect(cubit.state.issued, isEmpty);
    });

    blocTest<BadgesCubit, BadgesState>(
      'emits loading then loaded data when load succeeds',
      setUp: () {
        when(
          repository.loadDashboard,
        ).thenAnswer((_) async => dashboard);
      },
      build: () => BadgesCubit(repository: repository),
      act: (cubit) => cubit.load(),
      expect: () => [
        const BadgesState(status: BadgesStatus.loading),
        isA<BadgesState>()
            .having((state) => state.status, 'status', BadgesStatus.loaded)
            .having((state) => state.awarded, 'awarded', [awardedBadge])
            .having((state) => state.issued, 'issued', [issuedBadge])
            .having((state) => state.created, 'created', [createdBadge]),
      ],
    );

    blocTest<BadgesCubit, BadgesState>(
      'emits error when load fails',
      setUp: () {
        when(
          repository.loadDashboard,
        ).thenThrow(Exception('relay unavailable'));
      },
      build: () => BadgesCubit(repository: repository),
      act: (cubit) => cubit.load(),
      expect: () => [
        const BadgesState(status: BadgesStatus.loading),
        const BadgesState(status: BadgesStatus.error),
      ],
      errors: () => [isA<Exception>()],
    );

    blocTest<BadgesCubit, BadgesState>(
      'acceptAward delegates then refreshes dashboard',
      setUp: () {
        when(() => repository.acceptAward(any())).thenAnswer((_) async {});
        when(
          repository.loadDashboard,
        ).thenAnswer((_) async => dashboard);
      },
      build: () => BadgesCubit(repository: repository),
      seed: () => BadgesState(
        status: BadgesStatus.loaded,
        awarded: [awardedBadge],
      ),
      act: (cubit) => cubit.acceptAward(awardedBadge),
      expect: () => [
        BadgesState(
          status: BadgesStatus.loaded,
          actionStatus: BadgeActionStatus.accepting,
          awarded: [awardedBadge],
        ),
        isA<BadgesState>()
            .having((state) => state.status, 'status', BadgesStatus.loaded)
            .having(
              (state) => state.actionStatus,
              'actionStatus',
              BadgeActionStatus.completed,
            )
            .having((state) => state.awarded, 'awarded', [awardedBadge])
            .having((state) => state.issued, 'issued', [issuedBadge]),
      ],
      verify: (_) {
        verify(() => repository.acceptAward(awardedBadge)).called(1);
        verify(repository.loadDashboard).called(1);
      },
    );

    blocTest<BadgesCubit, BadgesState>(
      'removeAward delegates then refreshes dashboard',
      setUp: () {
        when(() => repository.removeAward(any())).thenAnswer((_) async {});
        when(
          repository.loadDashboard,
        ).thenAnswer((_) async => dashboard);
      },
      build: () => BadgesCubit(repository: repository),
      seed: () => BadgesState(
        status: BadgesStatus.loaded,
        awarded: [awardedBadge],
      ),
      act: (cubit) => cubit.removeAward(awardedBadge),
      expect: () => [
        BadgesState(
          status: BadgesStatus.loaded,
          actionStatus: BadgeActionStatus.removing,
          awarded: [awardedBadge],
        ),
        isA<BadgesState>().having(
          (state) => state.actionStatus,
          'actionStatus',
          BadgeActionStatus.completed,
        ),
      ],
      verify: (_) {
        verify(() => repository.removeAward(awardedBadge)).called(1);
      },
    );

    blocTest<BadgesCubit, BadgesState>(
      'rejectAward dismisses the badge then refreshes dashboard',
      setUp: () {
        when(() => repository.hideAward(any())).thenAnswer((_) async {});
        when(
          repository.loadDashboard,
        ).thenAnswer(
          (_) async => const BadgeDashboardData(
            awarded: [],
            issued: [],
            created: [],
          ),
        );
      },
      build: () => BadgesCubit(repository: repository),
      seed: () => BadgesState(
        status: BadgesStatus.loaded,
        awarded: [awardedBadge],
      ),
      act: (cubit) => cubit.rejectAward(awardedBadge),
      expect: () => [
        BadgesState(
          status: BadgesStatus.loaded,
          actionStatus: BadgeActionStatus.hiding,
          awarded: [awardedBadge],
        ),
        const BadgesState(
          status: BadgesStatus.loaded,
          actionStatus: BadgeActionStatus.completed,
        ),
      ],
      verify: (_) {
        verify(
          () => repository.hideAward(awardedBadge.definitionCoordinate),
        ).called(1);
        verifyNever(() => repository.removeAward(any()));
      },
    );

    blocTest<BadgesCubit, BadgesState>(
      'rejectAward unpins an accepted badge before dismissing it',
      setUp: () {
        when(() => repository.hideAward(any())).thenAnswer((_) async {});
        when(() => repository.removeAward(any())).thenAnswer((_) async {});
        when(repository.loadDashboard).thenAnswer(
          (_) async => const BadgeDashboardData(
            awarded: [],
            issued: [],
            created: [],
          ),
        );
      },
      build: () => BadgesCubit(repository: repository),
      act: (cubit) => cubit.rejectAward(_awardViewData(isAccepted: true)),
      verify: (_) {
        verifyInOrder([
          () => repository.removeAward(any()),
          () => repository.hideAward(awardedBadge.definitionCoordinate),
        ]);
      },
    );

    blocTest<BadgesCubit, BadgesState>(
      'failed hiding after unpinning refreshes acceptance and retains error',
      setUp: () {
        when(() => repository.removeAward(any())).thenAnswer((_) async {});
        when(() => repository.hideAward(any())).thenThrow(
          Exception('incomplete decisions read'),
        );
        when(repository.loadDashboard).thenAnswer((_) async => dashboard);
      },
      build: () => BadgesCubit(repository: repository),
      seed: () => BadgesState(
        status: BadgesStatus.loaded,
        awarded: [_awardViewData(isAccepted: true)],
      ),
      act: (cubit) => cubit.rejectAward(_awardViewData(isAccepted: true)),
      verify: (cubit) {
        expect(cubit.state.awarded.single.isAccepted, isFalse);
        expect(cubit.state.actionStatus, BadgeActionStatus.error);
      },
      errors: () => [isA<Exception>()],
    );

    blocTest<BadgesCubit, BadgesState>(
      'failed rejection and failed reconciliation leave a retryable error',
      setUp: () {
        when(() => repository.removeAward(any())).thenAnswer((_) async {});
        when(() => repository.hideAward(any())).thenThrow(Exception('hide'));
        when(repository.loadDashboard).thenThrow(Exception('reload'));
      },
      build: () => BadgesCubit(repository: repository),
      act: (cubit) => cubit.rejectAward(_awardViewData(isAccepted: true)),
      verify: (cubit) {
        expect(cubit.state.status, BadgesStatus.error);
        expect(cubit.state.actionStatus, BadgeActionStatus.error);
      },
      errors: () => [isA<Exception>(), isA<Exception>()],
    );

    blocTest<BadgesCubit, BadgesState>(
      'unhideAward restores a dismissed award then refreshes dashboard',
      setUp: () {
        when(() => repository.unhideAward(any())).thenAnswer((_) async {});
        when(repository.loadDashboard).thenAnswer((_) async => dashboard);
      },
      build: () => BadgesCubit(repository: repository),
      seed: () => BadgesState(
        status: BadgesStatus.loaded,
        hidden: [awardedBadge],
      ),
      act: (cubit) => cubit.unhideAward(awardedBadge),
      expect: () => [
        BadgesState(
          status: BadgesStatus.loaded,
          actionStatus: BadgeActionStatus.hiding,
          hidden: [awardedBadge],
        ),
        isA<BadgesState>()
            .having(
              (state) => state.actionStatus,
              'actionStatus',
              BadgeActionStatus.completed,
            )
            .having((state) => state.awarded, 'awarded', [awardedBadge])
            .having((state) => state.hidden, 'hidden', isEmpty),
      ],
      verify: (_) {
        verify(
          () => repository.unhideAward(awardedBadge.definitionCoordinate),
        ).called(1);
      },
    );

    blocTest<BadgesCubit, BadgesState>(
      'emits action error when acceptAward fails',
      setUp: () {
        when(
          () => repository.acceptAward(any()),
        ).thenThrow(Exception('publish failed'));
      },
      build: () => BadgesCubit(repository: repository),
      seed: () => BadgesState(
        status: BadgesStatus.loaded,
        awarded: [awardedBadge],
      ),
      act: (cubit) => cubit.acceptAward(awardedBadge),
      expect: () => [
        BadgesState(
          status: BadgesStatus.loaded,
          actionStatus: BadgeActionStatus.accepting,
          awarded: [awardedBadge],
        ),
        BadgesState(
          status: BadgesStatus.loaded,
          actionStatus: BadgeActionStatus.error,
          awarded: [awardedBadge],
        ),
      ],
      errors: () => [isA<Exception>()],
    );

    blocTest<BadgesCubit, BadgesState>(
      'refresh clears a previous action failure',
      setUp: () {
        when(
          () => repository.loadDashboard(),
        ).thenAnswer(
          (_) async => const BadgeDashboardData(
            awarded: [],
            issued: [],
            created: [],
          ),
        );
      },
      build: () => BadgesCubit(repository: repository),
      seed: () => const BadgesState(
        status: BadgesStatus.loaded,
        actionStatus: BadgeActionStatus.error,
      ),
      act: (cubit) => cubit.refresh(),
      // Without this the "Could not update badge" note outlived a pull to
      // refresh, while the failure path already reset it.
      expect: () => [
        const BadgesState(
          status: BadgesStatus.loaded,
        ),
      ],
    );

    blocTest<BadgesCubit, BadgesState>(
      'refresh leaves an in-flight action status alone',
      setUp: () {
        when(repository.loadDashboard).thenAnswer((_) async => dashboard);
      },
      build: () => BadgesCubit(repository: repository),
      seed: () => const BadgesState(
        status: BadgesStatus.loaded,
        actionStatus: BadgeActionStatus.accepting,
      ),
      act: (cubit) => cubit.refresh(),
      // `accepting` is what disables the accept and reject buttons. Clearing
      // it because a pull to refresh landed first re-enabled them while the
      // publish was still running.
      expect: () => [
        isA<BadgesState>().having(
          (state) => state.actionStatus,
          'actionStatus',
          BadgeActionStatus.accepting,
        ),
      ],
    );

    group('closed mid-flight', () {
      test(
        'load drops the dashboard instead of emitting after close',
        () async {
          final dashboardLoad = Completer<BadgeDashboardData>();
          when(
            repository.loadDashboard,
          ).thenAnswer((_) => dashboardLoad.future);

          final cubit = BadgesCubit(repository: repository);
          final loading = cubit.load();
          await cubit.close();
          dashboardLoad.complete(dashboard);

          await expectLater(loading, completes);
          expect(cubit.state.status, BadgesStatus.loading);
          expect(cubit.state.awarded, isEmpty);
        },
      );

      test(
        'acceptAward drops the reload instead of emitting after close',
        () async {
          final dashboardLoad = Completer<BadgeDashboardData>();
          when(() => repository.acceptAward(any())).thenAnswer((_) async {});
          when(
            repository.loadDashboard,
          ).thenAnswer((_) => dashboardLoad.future);

          final cubit = BadgesCubit(repository: repository);
          final accepting = cubit.acceptAward(awardedBadge);
          await cubit.close();
          dashboardLoad.complete(dashboard);

          await expectLater(accepting, completes);
          expect(cubit.state.actionStatus, BadgeActionStatus.accepting);
        },
      );

      test(
        'acceptAward drops a failure instead of emitting after close',
        () async {
          final publish = Completer<void>();
          when(
            () => repository.acceptAward(any()),
          ).thenAnswer((_) => publish.future);

          final cubit = BadgesCubit(repository: repository);
          final accepting = cubit.acceptAward(awardedBadge);
          await cubit.close();
          publish.completeError(Exception('relay rejected'));

          await expectLater(accepting, completes);
          expect(cubit.state.actionStatus, BadgeActionStatus.accepting);
        },
      );
    });
  });
}

BadgeAwardViewData _awardViewData({bool isAccepted = false}) {
  final issuerPubkey = _pubkey(2);
  final definitionCoordinate = '30009:$issuerPubkey:daily-diviner';
  return BadgeAwardViewData(
    isAccepted: isAccepted,
    award: Nip58BadgeAward(
      event: _event(
        id: _eventId(1),
        pubkey: issuerPubkey,
        kind: EventKind.badgeAward,
        tags: [
          ['a', definitionCoordinate],
          ['p', _pubkey(1)],
        ],
      ),
      definitionCoordinate: definitionCoordinate,
      recipientPubkeys: [_pubkey(1)],
    ),
    definition: Nip58BadgeDefinition(
      event: _event(
        id: _eventId(2),
        pubkey: issuerPubkey,
        kind: EventKind.badgeDefinition,
      ),
      coordinate: definitionCoordinate,
      dTag: 'daily-diviner',
      name: 'Diviner of the Day',
    ),
  );
}

CreatedBadgeViewData _createdViewData() {
  final issuerPubkey = _pubkey(1);
  return CreatedBadgeViewData(
    definition: Nip58BadgeDefinition(
      event: _event(
        id: _eventId(5),
        pubkey: issuerPubkey,
        kind: EventKind.badgeDefinition,
      ),
      coordinate: '30009:$issuerPubkey:monthly-diviner',
      dTag: 'monthly-diviner',
      name: 'Diviner of the Month',
    ),
    awardCount: 2,
    recipientCount: 3,
  );
}

IssuedBadgeViewData _issuedViewData() {
  final issuerPubkey = _pubkey(1);
  final recipientPubkey = _pubkey(3);
  final definitionCoordinate = '30009:$issuerPubkey:weekly-diviner';
  return IssuedBadgeViewData(
    coordinate: definitionCoordinate,
    latestAwardedAt: 1000,
    definition: Nip58BadgeDefinition(
      event: _event(
        id: _eventId(4),
        pubkey: issuerPubkey,
        kind: EventKind.badgeDefinition,
      ),
      coordinate: definitionCoordinate,
      dTag: 'weekly-diviner',
      name: 'Diviner of the Week',
    ),
    recipients: [
      IssuedBadgeRecipientViewData(
        pubkey: recipientPubkey,
        isAccepted: true,
      ),
    ],
  );
}

Event _event({
  required String id,
  required String pubkey,
  int kind = 1,
  List<List<String>> tags = const [],
  int createdAt = 1000,
  String content = '',
}) {
  return Event.fromJson({
    'id': id,
    'pubkey': pubkey,
    'created_at': createdAt,
    'kind': kind,
    'tags': tags,
    'content': content,
    'sig': '',
  });
}

String _eventId(int seed) => seed.toRadixString(16).padLeft(64, '0');

String _pubkey(int seed) => (seed + 100).toRadixString(16).padLeft(64, '0');
