// ABOUTME: Tests for the /list/:pubkey/:listId deep-link resolver screen.
// ABOUTME: Verifies loading, resolved-list, and unavailable states.

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/extensions/safe_pop_extension.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/router/route_error_screen.dart';
import 'package:openvine/screens/curated_list_by_author_screen.dart';
import 'package:openvine/screens/curated_list_feed_screen.dart';
import 'package:openvine/services/curated_list_service.dart';

import '../helpers/finders.dart';
import '../helpers/go_router.dart';
import '../helpers/test_provider_overrides.dart';

class _MockCuratedListService extends Mock implements CuratedListService {}

class _TestCuratedListsState extends CuratedListsState {
  _TestCuratedListsState(this._mockService);

  final CuratedListService? _mockService;

  @override
  CuratedListService? get service => _mockService;

  @override
  Future<List<CuratedList>> build() async => [];
}

const _authorPubkey =
    'a1b2c3d4e5f6a7b8c9d0e1f2a3b4c5d6e7f8a9b0c1d2e3f4a5b6c7d8e9f0a1b2';

void main() {
  group(CuratedListByAuthorScreen, () {
    late _MockCuratedListService mockService;
    final l10n = lookupAppLocalizations(const Locale('en'));

    setUp(() {
      mockService = _MockCuratedListService();
      when(() => mockService.isOwnedList(any())).thenReturn(false);
      when(() => mockService.isSubscribedToList(any())).thenReturn(false);
    });

    Widget buildSubject({MockGoRouter? goRouter}) {
      const screen = CuratedListByAuthorScreen(
        authorPubkey: _authorPubkey,
        listId: 'my-vines',
      );
      return ProviderScope(
        overrides: [
          ...getStandardTestOverrides(),
          curatedListsStateProvider.overrideWith(
            () => _TestCuratedListsState(mockService),
          ),
        ],
        child: MaterialApp(
          localizationsDelegates: appLocalizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: goRouter == null
              ? screen
              : MockGoRouterProvider(goRouter: goRouter, child: screen),
        ),
      );
    }

    testWidgets('renders $CuratedListFeedScreen when the list resolves', (
      tester,
    ) async {
      when(
        () => mockService.fetchPublicList(
          authorPubkey: _authorPubkey,
          listId: 'my-vines',
        ),
      ).thenAnswer(
        (_) async => CuratedList(
          id: 'my-vines',
          name: 'My Vines',
          videoEventIds: const [],
          pubkey: _authorPubkey,
          createdAt: DateTime(2026),
          updatedAt: DateTime(2026),
        ),
      );

      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      expect(find.byType(CuratedListFeedScreen), findsOneWidget);
      expect(find.text('My Vines'), findsOneWidget);
    });

    testWidgets('shows the unavailable state when no list is found', (
      tester,
    ) async {
      when(
        () => mockService.fetchPublicList(
          authorPubkey: _authorPubkey,
          listId: 'my-vines',
        ),
      ).thenAnswer((_) async => null);

      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      expect(find.byType(RouteErrorScreen), findsOneWidget);
      expect(find.text(l10n.curatedListFailedToLoad), findsOneWidget);
    });

    testWidgets('shows the unavailable state when the fetch fails', (
      tester,
    ) async {
      when(
        () => mockService.fetchPublicList(
          authorPubkey: _authorPubkey,
          listId: 'my-vines',
        ),
      ).thenAnswer((_) async => throw Exception('relay unavailable'));

      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      expect(find.byType(RouteErrorScreen), findsOneWidget);
      expect(find.text(l10n.curatedListFailedToLoad), findsOneWidget);
    });

    testWidgets(
      'unavailable-state back button falls back to the home feed when there '
      'is nothing to pop (cold-start deep link)',
      (tester) async {
        when(
          () => mockService.fetchPublicList(
            authorPubkey: _authorPubkey,
            listId: 'my-vines',
          ),
        ).thenAnswer((_) async => null);

        final goRouter = MockGoRouter();
        when(goRouter.canPop).thenReturn(false);
        when(() => goRouter.go(any())).thenReturn(null);

        await tester.pumpWidget(buildSubject(goRouter: goRouter));
        await tester.pumpAndSettle();

        await tester.tap(findByTooltip('Back'));

        verify(() => goRouter.go(defaultSafePopFallback)).called(1);
        verifyNever(() => goRouter.pop<Object?>());
      },
    );

    testWidgets('shows a loading spinner while the list resolves', (
      tester,
    ) async {
      final completer = Completer<CuratedList?>();
      when(
        () => mockService.fetchPublicList(
          authorPubkey: _authorPubkey,
          listId: 'my-vines',
        ),
      ).thenAnswer((_) => completer.future);

      await tester.pumpWidget(buildSubject());
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      completer.complete(null);
      await tester.pump();
      await tester.pump();

      expect(find.byType(RouteErrorScreen), findsOneWidget);
    });
  });
}
