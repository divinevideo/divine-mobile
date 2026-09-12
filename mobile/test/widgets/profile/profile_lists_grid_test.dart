// ABOUTME: Widget tests for the owned-lists surface on the profile Lists tab
// ABOUTME: Covers the bookmarks entry that keeps kind 10003 saves readable

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/screens/saved_videos_screen.dart';
import 'package:openvine/services/curated_list_service.dart';
import 'package:openvine/widgets/profile/profile_lists_grid.dart';

import '../../helpers/test_provider_overrides.dart';

class _MockCuratedListService extends Mock implements CuratedListService {}

List<CuratedList> _fakeLists = [];
_MockCuratedListService? _fakeService;

class _FakeCuratedListsState extends CuratedListsState {
  @override
  CuratedListService? get service => _fakeService;

  @override
  Future<List<CuratedList>> build() async => _fakeLists;
}

void main() {
  group(ProfileListsGrid, () {
    late _MockCuratedListService mockListService;
    late String pushedRoute;

    setUp(() {
      _fakeLists = [];
      mockListService = _MockCuratedListService();
      _fakeService = mockListService;
      when(() => mockListService.myLists).thenReturn(const <CuratedList>[]);
      pushedRoute = '';
    });

    Widget buildSubject() => testProviderScope(
      additionalOverrides: [
        curatedListsStateProvider.overrideWith(_FakeCuratedListsState.new),
      ],
      child: MaterialApp.router(
        localizationsDelegates: appLocalizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        routerConfig: GoRouter(
          initialLocation: '/',
          routes: [
            GoRoute(
              path: '/',
              builder: (_, _) => const Scaffold(body: ProfileListsGrid()),
            ),
            GoRoute(
              path: SavedVideosScreen.path,
              builder: (_, _) {
                pushedRoute = SavedVideosScreen.path;
                return const Scaffold(body: Text('saved'));
              },
            ),
          ],
        ),
      ),
    );

    testWidgets('renders the bookmarks entry when there are no lists', (
      tester,
    ) async {
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      final l10n = lookupAppLocalizations(const Locale('en'));
      expect(find.text(l10n.shareMenuBookmarks), findsOneWidget);
    });

    testWidgets('gives the bookmarks icon an explicit colour', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      // The asset is a hardcoded white fill and DivineIcon applies no filter
      // when color is null, so an uncoloured icon vanishes on light.
      final icon = tester.widget<DivineIcon>(
        find.byWidgetPredicate(
          (w) => w is DivineIcon && w.icon == DivineIconName.bookmarkSimple,
        ),
      );
      expect(icon.color, isNotNull);
    });

    testWidgets('opens the saved videos screen when bookmarks is tapped', (
      tester,
    ) async {
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      await tester.tap(
        find.byWidgetPredicate(
          (w) => w is DivineIcon && w.icon == DivineIconName.bookmarkSimple,
        ),
      );
      await tester.pumpAndSettle();

      expect(pushedRoute, equals(SavedVideosScreen.path));
    });
  });
}
