// ABOUTME: Tests FeaturedTabsCubit refresh, polling, and 18+ viewer gating.
// ABOUTME: Absence of a tab is the expected outcome, not an error state.

import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:funnelcake_api_client/funnelcake_api_client.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/blocs/featured_tabs/featured_tabs_cubit.dart';
import 'package:openvine/repositories/featured_tabs_repository.dart';

class _MockFeaturedTabsRepository extends Mock
    implements FeaturedTabsRepository {}

const _tab = FeaturedTabConfig(
  id: 'ft_a1b2c3d4',
  slug: 'featured-slug',
  label: {'default': 'Featured'},
  startsAt: null,
  endsAt: null,
  enabled: true,
  hasContent: true,
);

void main() {
  group(FeaturedTabsCubit, () {
    late _MockFeaturedTabsRepository repository;

    setUp(() {
      repository = _MockFeaturedTabsRepository();
    });

    void stubSnapshot(FeaturedTabsSnapshot snapshot) {
      when(
        () => repository.refresh(
          gateAgeRestrictedContent: any(named: 'gateAgeRestrictedContent'),
        ),
      ).thenAnswer((_) async => snapshot);
    }

    FeaturedTabsCubit buildCubit({bool gateAgeRestrictedContent = false}) {
      return FeaturedTabsCubit(
        repository: repository,
        gateAgeRestrictedContent: () => gateAgeRestrictedContent,
      );
    }

    blocTest<FeaturedTabsCubit, FeaturedTabsState>(
      'resolves with the tab the repository returns',
      setUp: () => stubSnapshot(const FeaturedTabsSnapshot(tab: _tab)),
      build: buildCubit,
      act: (cubit) => cubit.refresh(),
      expect: () => const [
        FeaturedTabsState(status: FeaturedTabsStatus.loading),
        FeaturedTabsState(status: FeaturedTabsStatus.resolved, tab: _tab),
      ],
    );

    blocTest<FeaturedTabsCubit, FeaturedTabsState>(
      'resolves with no tab when nothing is eligible',
      setUp: () => stubSnapshot(const FeaturedTabsSnapshot()),
      build: buildCubit,
      act: (cubit) => cubit.refresh(),
      expect: () => const [
        FeaturedTabsState(status: FeaturedTabsStatus.loading),
        FeaturedTabsState(status: FeaturedTabsStatus.resolved),
      ],
    );

    blocTest<FeaturedTabsCubit, FeaturedTabsState>(
      'clears a previously resolved tab when the server kills it',
      setUp: () => stubSnapshot(const FeaturedTabsSnapshot(tab: _tab)),
      build: buildCubit,
      act: (cubit) async {
        await cubit.refresh();
        stubSnapshot(const FeaturedTabsSnapshot());
        await cubit.refresh();
      },
      expect: () => const [
        FeaturedTabsState(status: FeaturedTabsStatus.loading),
        FeaturedTabsState(status: FeaturedTabsStatus.resolved, tab: _tab),
        FeaturedTabsState(status: FeaturedTabsStatus.loading, tab: _tab),
        FeaturedTabsState(status: FeaturedTabsStatus.resolved),
      ],
    );

    test('passes the current viewer age gate to the repository', () async {
      stubSnapshot(const FeaturedTabsSnapshot());
      final cubit = buildCubit(gateAgeRestrictedContent: true);
      addTearDown(cubit.close);

      await cubit.refresh();

      verify(
        () => repository.refresh(gateAgeRestrictedContent: true),
      ).called(1);
    });

    test('passes the required campaign feed on every refresh', () async {
      when(
        () => repository.refresh(
          gateAgeRestrictedContent: false,
          requiredFeaturedFeedId: 'ft_b',
        ),
      ).thenAnswer((_) async => const FeaturedTabsSnapshot());
      final cubit = FeaturedTabsCubit(
        repository: repository,
        gateAgeRestrictedContent: () => false,
        requiredFeaturedFeedId: 'ft_b',
      );
      addTearDown(cubit.close);
      await cubit.refresh();
      await cubit.refresh();
      verify(
        () => repository.refresh(
          gateAgeRestrictedContent: false,
          requiredFeaturedFeedId: 'ft_b',
        ),
      ).called(2);
    });

    test('surfaces the server poll interval on the state', () async {
      stubSnapshot(
        const FeaturedTabsSnapshot(
          tab: _tab,
          pollInterval: Duration(seconds: 120),
        ),
      );
      final cubit = buildCubit();
      addTearDown(cubit.close);

      await cubit.refresh();

      expect(cubit.state.pollInterval, equals(const Duration(seconds: 120)));
    });

    test('preserves the current tab when only status changes', () {
      const state = FeaturedTabsState(
        status: FeaturedTabsStatus.resolved,
        tab: _tab,
      );

      expect(
        state.copyWith(status: FeaturedTabsStatus.loading).tab,
        equals(_tab),
      );
    });

    test('re-polls at the server-supplied interval', () {
      fakeAsync((async) {
        stubSnapshot(
          const FeaturedTabsSnapshot(
            tab: _tab,
            pollInterval: Duration(seconds: 60),
          ),
        );
        final cubit = buildCubit();

        unawaited(cubit.refresh());
        async.flushMicrotasks();
        clearInteractions(repository);

        async.elapse(const Duration(seconds: 60));
        async.flushMicrotasks();

        verify(
          () => repository.refresh(
            gateAgeRestrictedContent: any(named: 'gateAgeRestrictedContent'),
          ),
        ).called(1);

        unawaited(cubit.close());
        async.flushMicrotasks();
      });
    });

    test('stops polling once closed', () {
      fakeAsync((async) {
        stubSnapshot(
          const FeaturedTabsSnapshot(
            tab: _tab,
            pollInterval: Duration(seconds: 60),
          ),
        );
        final cubit = buildCubit();

        unawaited(cubit.refresh());
        async.flushMicrotasks();
        unawaited(cubit.close());
        async.flushMicrotasks();
        clearInteractions(repository);

        async.elapse(const Duration(minutes: 5));
        async.flushMicrotasks();

        verifyNever(
          () => repository.refresh(
            gateAgeRestrictedContent: any(named: 'gateAgeRestrictedContent'),
          ),
        );
      });
    });

    test('a slower earlier refresh cannot resurrect a killed tab', () async {
      // The poll timer, the foreground listener, and the minor-status
      // listener all call refresh(). If a request issued before the kill
      // lands after the one that resolved the tab away, the tab comes back
      // on screen and the kill switch is defeated until the next poll.
      final beforeKill = Completer<FeaturedTabsSnapshot>();
      final afterKill = Completer<FeaturedTabsSnapshot>();
      var call = 0;
      when(
        () => repository.refresh(
          gateAgeRestrictedContent: any(named: 'gateAgeRestrictedContent'),
        ),
      ).thenAnswer((_) {
        call++;
        return call == 1 ? beforeKill.future : afterKill.future;
      });

      final cubit = buildCubit();
      addTearDown(cubit.close);

      final stale = cubit.refresh();
      final fresh = cubit.refresh();

      afterKill.complete(const FeaturedTabsSnapshot());
      await fresh;
      expect(cubit.state.tab, isNull);

      beforeKill.complete(const FeaturedTabsSnapshot(tab: _tab));
      await stale;

      expect(
        cubit.state.tab,
        isNull,
        reason: 'a superseded refresh must not publish',
      );
    });
  });
}
