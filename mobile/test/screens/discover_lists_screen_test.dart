// ABOUTME: Tests for DiscoverListsScreen pagination behavior
// ABOUTME: Verifies pagination stops re-triggering when no more lists found

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/list_providers.dart';
import 'package:openvine/screens/discover_lists_screen.dart';
import 'package:openvine/services/curated_list_service.dart';

import '../helpers/test_provider_overrides.dart';

class _MockCuratedListService extends Mock implements CuratedListService {}

/// Test subclass that exposes a mock service without requiring
/// the real async initialization (NostrClient, AuthService, etc.).
class _TestCuratedListsState extends CuratedListsState {
  _TestCuratedListsState(this._mockService);
  final CuratedListService? _mockService;

  @override
  CuratedListService? get service => _mockService;

  @override
  Future<List<CuratedList>> build() async => [];
}

/// Pre-populated DiscoveredLists notifier so the screen skips the
/// initial stream fetch (it only fetches when lists are empty).
class _PreloadedDiscoveredLists extends DiscoveredLists {
  _PreloadedDiscoveredLists(this._initialState);
  final DiscoveredListsState _initialState;

  @override
  DiscoveredListsState build() => _initialState;
}

CuratedList _makeList(String id, {DateTime? createdAt}) {
  return CuratedList(
    id: id,
    name: 'List $id',
    videoEventIds: ['video_$id'],
    createdAt: createdAt ?? DateTime(2025),
    updatedAt: createdAt ?? DateTime(2025),
  );
}

void main() {
  setUpAll(() {
    registerFallbackValue(Duration.zero);
  });

  group(DiscoverListsScreen, () {
    late _MockCuratedListService mockService;
    late List<CuratedList> preloadedLists;

    setUp(() {
      mockService = _MockCuratedListService();

      // Create enough lists so auto-pagination doesn't kick in
      // (_minListsBeforeAutoPaginate = 10), and so the list is scrollable
      // across widget-test viewport differences.
      preloadedLists = List.generate(
        50,
        (i) => _makeList(
          'list_$i',
          createdAt: DateTime(2025).subtract(Duration(hours: i)),
        ),
      );

      // Default: isSubscribedToList returns false
      when(() => mockService.isSubscribedToList(any())).thenReturn(false);
    });

    Widget buildSubject({
      List<CuratedList>? initialLists,
      DateTime? oldestTimestamp,
    }) {
      final lists = initialLists ?? preloadedLists;
      final oldest =
          oldestTimestamp ??
          (lists.isEmpty
              ? null
              : lists
                    .map((list) => list.createdAt)
                    .reduce((a, b) => a.isBefore(b) ? a : b));

      return ProviderScope(
        overrides: [
          ...getStandardTestOverrides(),
          discoveredListsProvider.overrideWith(
            () => _PreloadedDiscoveredLists(
              DiscoveredListsState(lists: lists, oldestTimestamp: oldest),
            ),
          ),
          curatedListsStateProvider.overrideWith(
            () => _TestCuratedListsState(mockService),
          ),
        ],
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: DiscoverListsScreen(),
        ),
      );
    }

    testWidgets(
      'scrolling to bottom again after finding no new lists should not '
      're-trigger pagination',
      (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        var streamCalls = 0;

        when(
          () => mockService.streamPublicListsFromRelays(
            until: any(named: 'until'),
            excludeIds: any(named: 'excludeIds'),
            timeout: any(named: 'timeout'),
          ),
        ).thenAnswer((invocation) {
          streamCalls++;
          expect(
            invocation.namedArguments[#timeout],
            const Duration(seconds: 3),
          );
          return const Stream<List<CuratedList>>.empty();
        });

        await tester.pumpWidget(buildSubject());
        await tester.pump();
        await tester.pump();

        // Verify lists are shown and no spinner yet
        expect(find.byType(Card), findsWidgets);
        expect(find.byType(CircularProgressIndicator), findsNothing);

        // --- First scroll: triggers pagination ---
        await tester.scrollUntilVisible(
          find.text('List list_49'),
          500,
          scrollable: find.byType(Scrollable),
        );

        // pump() processes microtasks: _loadMoreLists starts, calls mock,
        // listens to the bounded stream, and completes when it closes empty.
        await tester.pump();
        await tester.pump();

        // _loadMoreLists should have completed: spinner gone
        expect(
          find.byType(CircularProgressIndicator),
          findsNothing,
          reason: '_loadMoreLists should have completed on empty stream',
        );

        // --- Second scroll: should NOT trigger pagination again ---
        // Scroll UP first so the subsequent scroll DOWN actually changes
        // the position and fires the _onScroll listener at the bottom.
        await tester.drag(find.byType(ListView), const Offset(0, 1000));
        await tester.pump();
        await tester.scrollUntilVisible(
          find.text('List list_49'),
          500,
          scrollable: find.byType(Scrollable),
        );
        await tester.pump();
        await tester.pump();

        // With _hasReachedEnd: _onScroll returns early → 1 controller
        // Without _hasReachedEnd: _loadMoreLists is called again → 2+
        expect(
          streamCalls,
          1,
          reason:
              '_loadMoreLists should not be called again after finding '
              'no new lists (streams created: $streamCalls)',
        );
      },
    );

    testWidgets('initial load shows retry when service stream times out', (
      tester,
    ) async {
      final l10n = lookupAppLocalizations(const Locale('en'));

      when(() => mockService.streamPublicListsFromRelays()).thenAnswer(
        (_) => Stream<List<CuratedList>>.error(
          TimeoutException('Public curated lists relay read timed out'),
        ),
      );

      await tester.pumpWidget(buildSubject(initialLists: []));
      await tester.pump();
      await tester.pump();

      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.text(l10n.discoverListsFailedToLoad), findsOneWidget);
      expect(find.text(l10n.discoverListsRelayTimeout), findsOneWidget);
      expect(find.text(l10n.commonRetry), findsOneWidget);
    });

    testWidgets('initial partial results stay visible after relay timeout', (
      tester,
    ) async {
      final l10n = lookupAppLocalizations(const Locale('en'));
      final controller = StreamController<List<CuratedList>>();
      addTearDown(controller.close);

      when(
        () => mockService.streamPublicListsFromRelays(),
      ).thenAnswer((_) => controller.stream);

      await tester.pumpWidget(buildSubject(initialLists: []));
      await tester.pump();
      await tester.pump();

      final partialLists = List.generate(
        10,
        (index) => _makeList('partial_$index'),
      );
      controller.add(partialLists);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('List partial_0'), findsOneWidget);

      controller.addError(
        TimeoutException('Public curated lists relay read timed out'),
      );
      await tester.pump();

      expect(find.text('List partial_0'), findsOneWidget);
      expect(find.text(l10n.discoverListsFailedToLoad), findsNothing);
      expect(find.text(l10n.discoverListsRelayTimeout), findsNothing);
    });

    testWidgets('refresh that never emits keeps the lists already on screen', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final l10n = lookupAppLocalizations(const Locale('en'));

      when(() => mockService.streamPublicListsFromRelays()).thenAnswer(
        (_) => Stream<List<CuratedList>>.error(
          TimeoutException('Public curated lists relay read timed out'),
        ),
      );

      await tester.pumpWidget(buildSubject());
      await tester.pump();
      await tester.pump();

      expect(find.text('List list_0'), findsOneWidget);

      // Pull to refresh against a relay that never answers.
      await tester.fling(find.text('List list_0'), const Offset(0, 400), 1000);
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await tester.pump();

      // The initial-load timeout must not fire here: replacing a populated
      // screen with the error view would lose content the user was reading.
      expect(find.text('List list_0'), findsOneWidget);
      expect(find.text(l10n.discoverListsFailedToLoad), findsNothing);
      expect(find.text(l10n.discoverListsRelayTimeout), findsNothing);
    });

    testWidgets('dispose cancels the active initial relay stream', (
      tester,
    ) async {
      var streamCanceled = false;
      final controller = StreamController<List<CuratedList>>(
        onCancel: () {
          streamCanceled = true;
        },
      );
      addTearDown(controller.close);

      when(
        () => mockService.streamPublicListsFromRelays(),
      ).thenAnswer((_) => controller.stream);

      await tester.pumpWidget(buildSubject(initialLists: []));
      await tester.pump();
      await tester.pump();

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();

      expect(streamCanceled, isTrue);
    });

    testWidgets('pagination cancels the relay stream after unmount', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      var paginationStreamCanceled = false;
      final controller = StreamController<List<CuratedList>>(
        onCancel: () {
          paginationStreamCanceled = true;
        },
      );
      addTearDown(controller.close);

      when(
        () => mockService.streamPublicListsFromRelays(
          until: any(named: 'until'),
          excludeIds: any(named: 'excludeIds'),
          timeout: any(named: 'timeout'),
        ),
      ).thenAnswer((_) => controller.stream);

      await tester.pumpWidget(buildSubject());
      await tester.pump();
      await tester.pump();

      await tester.scrollUntilVisible(
        find.text('List list_49'),
        500,
        scrollable: find.byType(Scrollable),
      );
      await tester.pump();

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();

      controller.add([_makeList('after_unmount')]);
      await tester.pump();

      expect(paginationStreamCanceled, isTrue);
    });

    testWidgets('initial EOSE with zero lists renders empty state', (
      tester,
    ) async {
      final l10n = lookupAppLocalizations(const Locale('en'));

      when(
        () => mockService.streamPublicListsFromRelays(),
      ).thenAnswer((_) => const Stream<List<CuratedList>>.empty());

      await tester.pumpWidget(buildSubject(initialLists: []));
      await tester.pump();
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.text(l10n.discoverListsEmptyTitle), findsOneWidget);
      expect(find.text(l10n.discoverListsFailedToLoad), findsNothing);
      expect(find.text(l10n.discoverListsRelayTimeout), findsNothing);
    });
  });
}
