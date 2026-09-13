// ABOUTME: Unit tests for ExploreTabsCubit availability + tab ordering logic.

import 'package:analytics/analytics.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/blocs/explore_tabs/explore_tabs_cubit.dart';
import 'package:openvine/services/top_hashtags_service.dart';

class _MockTopHashtagsLoader extends Mock implements TopHashtagsLoader {}

class _RecordingAnalyticsSink implements AnalyticsEventSink {
  final events = <({String name, Map<String, Object> parameters})>[];

  @override
  Future<void> setUserId(String? userId) async {}

  @override
  Future<void> logEvent({
    required String name,
    required Map<String, Object> parameters,
  }) async {
    events.add((name: name, parameters: parameters));
  }

  @override
  Future<void> logScreenView({
    required String screenName,
    String? screenClass,
    Map<String, Object>? parameters,
  }) async {}
}

/// A cubit whose analytics writes go nowhere, for the tab-ordering tests.
ExploreTabsCubit _buildCubit() => ExploreTabsCubit(
  screenAnalytics: ScreenAnalyticsService(
    history: PageLoadHistory(),
    sink: const NoOpAnalyticsEventSink(),
  ),
);

void main() {
  group(ExploreTabsCubit, () {
    test('initial state has only the base tabs', () {
      final cubit = _buildCubit();
      addTearDown(cubit.close);

      expect(cubit.state.classicsAvailable, isFalse);
      expect(cubit.state.forYouAvailable, isFalse);
      expect(cubit.state.appsAvailable, isFalse);
      expect(cubit.state.tabNames, const [
        'new',
        'popular',
        'categories',
        'lists',
      ]);
      expect(cubit.state.tabCount, 4);
    });

    blocTest<ExploreTabsCubit, ExploreTabsState>(
      'emits new tab order when availability changes',
      build: _buildCubit,
      act: (cubit) => cubit.updateAvailability(
        classicsAvailable: true,
        forYouAvailable: true,
        appsAvailable: true,
      ),
      expect: () => [
        isA<ExploreTabsState>().having((s) => s.tabCount, 'tabCount', 7).having(
          (s) => s.tabNames,
          'tabNames',
          const [
            'classics',
            'new',
            'popular',
            'categories',
            'for_you',
            'lists',
            'apps',
          ],
        ),
      ],
    );

    blocTest<ExploreTabsCubit, ExploreTabsState>(
      'does not emit when availability is unchanged',
      build: _buildCubit,
      act: (cubit) => cubit.updateAvailability(
        classicsAvailable: false,
        forYouAvailable: false,
        appsAvailable: false,
      ),
      expect: () => const <ExploreTabsState>[],
    );

    group('index <-> name conversion', () {
      test('shifts indices when an earlier optional tab appears', () {
        const withoutClassics = ExploreTabsState();
        expect(withoutClassics.indexForName('popular'), 1);
        expect(withoutClassics.newVideosIndex, 0);
        expect(withoutClassics.trendingIndex, 1);

        const withClassics = ExploreTabsState(classicsAvailable: true);
        expect(withClassics.indexForName('classics'), 0);
        expect(withClassics.indexForName('popular'), 2);
        expect(withClassics.newVideosIndex, 1);
        expect(withClassics.trendingIndex, 2);
      });

      test('nameForIndex round-trips with indexForName', () {
        const state = ExploreTabsState(
          classicsAvailable: true,
          forYouAvailable: true,
          appsAvailable: true,
        );
        for (final name in state.tabNames) {
          expect(state.nameForIndex(state.indexForName(name)), name);
        }
      });

      test('unknown name falls back to the default tab index', () {
        const state = ExploreTabsState();
        expect(
          state.indexForName('does-not-exist'),
          state.indexForName(exploreDefaultTabName),
        );
      });

      test('out-of-range index falls back to popular', () {
        const state = ExploreTabsState();
        expect(state.nameForIndex(999), 'popular');
        expect(state.nameForIndex(-1), 'popular');
      });
    });

    group('side effects', () {
      late _RecordingAnalyticsSink analyticsSink;
      late ScreenAnalyticsService analytics;
      late _MockTopHashtagsLoader topHashtags;
      late ExploreTabsCubit cubit;

      setUp(() {
        analyticsSink = _RecordingAnalyticsSink();
        analytics = ScreenAnalyticsService(
          history: PageLoadHistory(),
          sink: analyticsSink,
        );
        topHashtags = _MockTopHashtagsLoader();
        cubit = ExploreTabsCubit(
          screenAnalytics: analytics,
          topHashtags: topHashtags,
        );
      });

      tearDown(() {
        cubit.close();
      });

      test('trackScreenLoad starts the explore screen analytics session', () {
        expect(analytics.activeSessionCount, 0);

        cubit.trackScreenLoad();

        expect(analytics.activeSessionCount, 1);
      });

      test('trackTabChange records the selected explore tab', () async {
        cubit.trackTabChange('popular');

        await pumpEventQueue();

        expect(analyticsSink.events, hasLength(1));
        expect(analyticsSink.events.single.name, 'tab_changed');
        expect(
          analyticsSink.events.single.parameters,
          containsPair('screen_name', 'explore_screen'),
        );
        expect(
          analyticsSink.events.single.parameters,
          containsPair('tab_name', 'popular'),
        );
      });

      test('loadHashtags delegates to the injected hashtag loader', () async {
        when(() => topHashtags.loadTopHashtags()).thenAnswer((_) async {});

        await cubit.loadHashtags();

        verify(() => topHashtags.loadTopHashtags()).called(1);
      });
    });
  });
}
