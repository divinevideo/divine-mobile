// ABOUTME: Widget tests for the profile My Lists tab: the two-column gallery
// ABOUTME: of own video and people lists, the create button, and the
// ABOUTME: bookmarks entry that keeps kind 10003 saves readable.

import 'package:bloc_test/bloc_test.dart';
import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/features/people_lists/people_lists.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/list_providers.dart';
import 'package:openvine/screens/saved_videos_screen.dart';
import 'package:openvine/services/curated_list_service.dart';
import 'package:openvine/widgets/list_search_card.dart';
import 'package:openvine/widgets/people_list_card.dart';
import 'package:openvine/widgets/profile/profile_lists_grid.dart';

import '../../helpers/test_provider_overrides.dart';

class _MockCuratedListService extends Mock implements CuratedListService {}

class _MockPeopleListsBloc extends MockBloc<PeopleListsEvent, PeopleListsState>
    implements PeopleListsBloc {}

List<CuratedList> _fakeLists = [];
_MockCuratedListService? _fakeService;

class _FakeCuratedListsState extends CuratedListsState {
  @override
  CuratedListService? get service => _fakeService;

  @override
  Future<List<CuratedList>> build() async => _fakeLists;
}

CuratedList _videoList(String id) => CuratedList(
  id: id,
  name: 'Video $id',
  videoEventIds: const ['v1'],
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);

UserList _peopleList(String id) => UserList(
  id: id,
  name: 'People $id',
  pubkeys: ['a' * 64],
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);

void main() {
  group(ProfileListsGrid, () {
    late _MockCuratedListService mockListService;
    late _MockPeopleListsBloc peopleListsBloc;
    late String pushedRoute;

    setUp(() {
      _fakeLists = [];
      mockListService = _MockCuratedListService();
      _fakeService = mockListService;
      when(() => mockListService.myLists).thenReturn(const <CuratedList>[]);
      peopleListsBloc = _MockPeopleListsBloc();
      whenListen(
        peopleListsBloc,
        const Stream<PeopleListsState>.empty(),
        initialState: const PeopleListsState(),
      );
      pushedRoute = '';
    });

    Widget buildSubject() => testProviderScope(
      additionalOverrides: [
        curatedListsStateProvider.overrideWith(_FakeCuratedListsState.new),
        // The gallery renders instantly from myLists; hydration resolves to
        // the same lists so tests stay on the placeholder-fan path.
        myListsWithThumbnailsProvider.overrideWith(
          (ref) async => mockListService.myLists,
        ),
      ],
      child: BlocProvider<PeopleListsBloc>.value(
        value: peopleListsBloc,
        child: MaterialApp.router(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
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
              GoRoute(
                path: '/list/:listId',
                builder: (_, state) {
                  pushedRoute = state.uri.toString();
                  return const Scaffold(body: Text('video list'));
                },
              ),
              GoRoute(
                path: '/people-lists/:listId',
                builder: (_, state) {
                  pushedRoute = state.uri.toString();
                  return const Scaffold(body: Text('people list'));
                },
              ),
            ],
          ),
        ),
      ),
    );

    group('renders', () {
      testWidgets("shows both columns of the viewer's lists", (tester) async {
        when(
          () => mockListService.myLists,
        ).thenReturn([_videoList('skate')]);
        whenListen(
          peopleListsBloc,
          const Stream<PeopleListsState>.empty(),
          initialState: PeopleListsState(lists: [_peopleList('crew')]),
        );

        await tester.pumpWidget(buildSubject());
        await tester.pumpAndSettle();

        expect(find.byType(CuratedListSearchCard), findsOneWidget);
        expect(find.text('Video skate'), findsOneWidget);
        expect(find.byType(PeopleListCard), findsOneWidget);
        expect(find.text('People crew'), findsOneWidget);
      });

      testWidgets('uses the outline create button', (tester) async {
        await tester.pumpWidget(buildSubject());
        await tester.pumpAndSettle();

        final l10n = lookupAppLocalizations(const Locale('en'));
        final button = tester.widget<DivineButton>(
          find.ancestor(
            of: find.text(l10n.listCreateNewList),
            matching: find.byType(DivineButton),
          ),
        );
        expect(button.type, equals(DivineButtonType.secondary));
      });

      testWidgets('shows the empty message when both kinds are empty', (
        tester,
      ) async {
        await tester.pumpWidget(buildSubject());
        await tester.pumpAndSettle();

        final l10n = lookupAppLocalizations(const Locale('en'));
        expect(find.text(l10n.profileListsEmpty), findsOneWidget);
      });

      testWidgets('renders the bookmarks entry when there are no lists', (
        tester,
      ) async {
        await tester.pumpWidget(buildSubject());
        await tester.pumpAndSettle();

        final l10n = lookupAppLocalizations(const Locale('en'));
        expect(find.text(l10n.shareMenuBookmarks), findsOneWidget);
      });

      testWidgets('gives the bookmarks icon an explicit colour', (
        tester,
      ) async {
        await tester.pumpWidget(buildSubject());
        await tester.pumpAndSettle();

        // The asset is a hardcoded white fill and DivineIcon applies no
        // filter when color is null, so an uncoloured icon vanishes on
        // light.
        final icon = tester.widget<DivineIcon>(
          find.byWidgetPredicate(
            (w) => w is DivineIcon && w.icon == DivineIconName.bookmarkSimple,
          ),
        );
        expect(icon.color, isNotNull);
      });
    });

    group('navigation', () {
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

      testWidgets('opens the list detail when a video card is tapped', (
        tester,
      ) async {
        when(
          () => mockListService.myLists,
        ).thenReturn([_videoList('skate')]);

        await tester.pumpWidget(buildSubject());
        await tester.pumpAndSettle();

        await tester.tap(find.text('Video skate'));
        await tester.pumpAndSettle();

        expect(pushedRoute, equals('/list/skate'));
      });

      testWidgets('opens the members view when a people card is tapped', (
        tester,
      ) async {
        whenListen(
          peopleListsBloc,
          const Stream<PeopleListsState>.empty(),
          initialState: PeopleListsState(lists: [_peopleList('crew')]),
        );

        await tester.pumpWidget(buildSubject());
        await tester.pumpAndSettle();

        await tester.tap(find.text('People crew'));
        await tester.pumpAndSettle();

        // Own list: no owner query param, so the members screen selects it
        // from the owner-scoped bloc.
        expect(pushedRoute, equals('/people-lists/crew'));
      });
    });
  });
}
