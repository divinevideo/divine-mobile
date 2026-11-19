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
        audience: () => gateAgeRestrictedContent
            ? FeaturedTabAudience.unverified
            : FeaturedTabAudience.adult,
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

    test('verification failure keeps a cold campaign inconclusive', () async {
      when(
        () => repository.refresh(
          gateAgeRestrictedContent: true,
          requiredFeaturedFeedId: _tab.id,
        ),
      ).thenAnswer((_) async => const FeaturedTabsSnapshot());
      final cubit = FeaturedTabsCubit(
        repository: repository,
        audience: () => FeaturedTabAudience.failed,
        requiredFeaturedFeedId: _tab.id,
      );
      addTearDown(cubit.close);

      await cubit.refresh();

      expect(cubit.state.tab, isNull);
      expect(cubit.state.status, FeaturedTabsStatus.failed);
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
        audience: () => FeaturedTabAudience.adult,
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

    test('clears and refreshes a campaign at its configured end', () {
      fakeAsync((async) {
        final start = DateTime.utc(2026, 11, 17, 12);
        final tab = FeaturedTabConfig(
          id: _tab.id,
          slug: _tab.slug,
          label: _tab.label,
          startsAt: start,
          endsAt: start.add(const Duration(seconds: 1)),
          enabled: true,
          hasContent: true,
        );
        when(
          () => repository.refresh(
            gateAgeRestrictedContent: false,
            requiredFeaturedFeedId: tab.id,
          ),
        ).thenAnswer(
          (_) async => async.elapsed < const Duration(seconds: 1)
              ? FeaturedTabsSnapshot(tab: tab)
              : const FeaturedTabsSnapshot(),
        );
        final cubit = FeaturedTabsCubit(
          repository: repository,
          audience: () => FeaturedTabAudience.adult,
          requiredFeaturedFeedId: tab.id,
          now: () => start.add(async.elapsed),
        );

        unawaited(cubit.refresh());
        async.flushMicrotasks();
        expect(cubit.state.tab, tab);

        async.elapse(const Duration(seconds: 1));
        expect(cubit.state.tab, isNull);
        expect(cubit.state.status, FeaturedTabsStatus.resolved);
        verify(
          () => repository.refresh(
            gateAgeRestrictedContent: false,
            requiredFeaturedFeedId: tab.id,
          ),
        ).called(2);

        unawaited(cubit.close());
        async.flushMicrotasks();
      });
    });

    test('keeps a campaign that ends beyond the one-day timer cap', () {
      fakeAsync((async) {
        final start = DateTime.utc(2026, 11, 17, 12);
        final tab = FeaturedTabConfig(
          id: _tab.id,
          slug: _tab.slug,
          label: _tab.label,
          startsAt: start,
          endsAt: start.add(const Duration(days: 2)),
          enabled: true,
          hasContent: true,
        );
        // Polling off: only the expiry timer can clear or re-arm the tab.
        when(
          () => repository.refresh(
            gateAgeRestrictedContent: false,
            requiredFeaturedFeedId: tab.id,
          ),
        ).thenAnswer(
          (_) async => async.elapsed < const Duration(days: 2)
              ? FeaturedTabsSnapshot(tab: tab, pollInterval: Duration.zero)
              : const FeaturedTabsSnapshot(pollInterval: Duration.zero),
        );
        final cubit = FeaturedTabsCubit(
          repository: repository,
          audience: () => FeaturedTabAudience.adult,
          requiredFeaturedFeedId: tab.id,
          now: () => start.add(async.elapsed),
        );

        unawaited(cubit.refresh());
        async.flushMicrotasks();
        expect(cubit.state.tab, tab);
        final states = <FeaturedTabsState>[];
        final subscription = cubit.stream.listen(states.add);

        async.elapse(const Duration(days: 1, minutes: 1));
        expect(states.where((state) => state.tab == null), isEmpty);
        expect(cubit.state.tab, tab);
        verify(
          () => repository.refresh(
            gateAgeRestrictedContent: false,
            requiredFeaturedFeedId: tab.id,
          ),
        ).called(1);

        async.elapse(const Duration(days: 1) - const Duration(minutes: 1));
        expect(cubit.state.tab, isNull);

        unawaited(subscription.cancel());
        unawaited(cubit.close());
        async.flushMicrotasks();
      });
    });

    test('keeps an expired campaign resolved when the refresh is offline', () {
      fakeAsync((async) {
        final start = DateTime.utc(2026, 11, 17, 12);
        final tab = FeaturedTabConfig(
          id: _tab.id,
          slug: _tab.slug,
          label: _tab.label,
          startsAt: start,
          endsAt: start.add(const Duration(seconds: 1)),
          enabled: true,
          hasContent: true,
        );
        when(
          () => repository.refresh(
            gateAgeRestrictedContent: false,
            requiredFeaturedFeedId: tab.id,
          ),
        ).thenAnswer(
          (_) async => async.elapsed < const Duration(seconds: 1)
              ? FeaturedTabsSnapshot(tab: tab)
              : const FeaturedTabsSnapshot(hasResolvedCatalog: false),
        );
        final cubit = FeaturedTabsCubit(
          repository: repository,
          audience: () => FeaturedTabAudience.adult,
          requiredFeaturedFeedId: tab.id,
          now: () => start.add(async.elapsed),
        );

        unawaited(cubit.refresh());
        async.flushMicrotasks();
        expect(cubit.state.tab, tab);

        async.elapse(const Duration(seconds: 1));
        expect(cubit.state.tab, isNull);
        expect(cubit.state.status, FeaturedTabsStatus.resolved);
        verify(
          () => repository.refresh(
            gateAgeRestrictedContent: false,
            requiredFeaturedFeedId: tab.id,
          ),
        ).called(2);

        unawaited(cubit.close());
        async.flushMicrotasks();
      });
    });

    test('absence confirmed for one audience does not cover another', () async {
      var audience = FeaturedTabAudience.unverified;
      stubSnapshot(const FeaturedTabsSnapshot());
      final cubit = FeaturedTabsCubit(
        repository: repository,
        audience: () => audience,
      );
      addTearDown(cubit.close);
      await cubit.refresh();
      expect(
        cubit.state,
        const FeaturedTabsState(status: FeaturedTabsStatus.resolved),
      );

      audience = FeaturedTabAudience.adult;
      stubSnapshot(const FeaturedTabsSnapshot(hasResolvedCatalog: false));
      await cubit.refresh();

      expect(cubit.state.tab, isNull);
      expect(cubit.state.status, FeaturedTabsStatus.failed);
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
