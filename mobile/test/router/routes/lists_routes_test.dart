// ABOUTME: Tests the list routes registered by listsRoutes.
// ABOUTME: Pins locations, order, curated-list hints and the author boundary.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show ProviderFamily;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:models/models.dart';
import 'package:openvine/features/people_lists/view/create_people_list_page.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/router/route_error_screen.dart';
import 'package:openvine/router/route_paths.dart';
import 'package:openvine/router/routes/lists_routes.dart';
import 'package:openvine/router/routes/route_extras.dart';
import 'package:openvine/screens/curated_list_by_author_screen.dart';
import 'package:openvine/screens/curated_list_feed_screen.dart';
import 'package:openvine/screens/explore/explore_screen.dart';
import 'package:openvine/screens/saved_videos_screen.dart';
import 'package:openvine/screens/user_list_people_screen.dart';

import '../../helpers/test_provider_overrides.dart';
import '../../helpers/test_pubkeys.dart';

class _FakeGoRouterState extends Fake implements GoRouterState {
  _FakeGoRouterState({
    required String location,
    this.pathParameters = const {},
    this.extra,
  }) : uri = Uri.parse(location),
       matchedLocation = Uri.parse(location).path,
       fullPath = Uri.parse(location).path,
       pageKey = ValueKey<String>(location);

  @override
  final Uri uri;

  @override
  final String matchedLocation;

  @override
  final String? fullPath;

  @override
  final ValueKey<String> pageKey;

  @override
  final Map<String, String> pathParameters;

  @override
  final Object? extra;
}

/// Ids whose encoding has broken list routes before: a space, a slash, a
/// literal `%`, a `?`, non-ASCII text, an already-encoded slash, and the
/// child-route segments, which are valid d-tags too.
const _awkwardIds = [
  'crew',
  'members',
  'add-people',
  'edit',
  'new',
  'a b/c%d?雪',
  '%2F',
  '100%fun',
];

const _videoId =
    '1111111111111111111111111111111111111111111111111111111111111111';

/// The widget the route builder chose, recorded instead of rendered so these
/// tests never build a screen that queries relays.
Widget? _selected;

final ProviderFamily<GoRouter, String> _routerProvider =
    Provider.family<GoRouter, String>((ref, location) {
      final routes = listsRoutes().cast<GoRoute>().map(
        (route) => GoRoute(
          path: route.path,
          name: route.name,
          redirect: route.redirect,
          builder: (context, state) {
            _selected = route.builder!(context, state);
            return const Scaffold(body: Text('Selected route'));
          },
        ),
      );
      final router = GoRouter(initialLocation: location, routes: [...routes]);
      ref.onDispose(router.dispose);
      return router;
    });

void main() {
  group('listsRoutes', () {
    late BuildContext context;

    Future<void> captureContext(WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: appLocalizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (c) {
              context = c;
              return const SizedBox.shrink();
            },
          ),
        ),
      );
    }

    GoRoute routeNamed(String name) => listsRoutes()
        .whereType<GoRoute>()
        .singleWhere((route) => route.name == name);

    Widget build(
      String name,
      String location, {
      Map<String, String> pathParameters = const {},
      Object? extra,
    }) => routeNamed(name).builder!(
      context,
      _FakeGoRouterState(
        location: location,
        pathParameters: pathParameters,
        extra: extra,
      ),
    );

    group('locations', () {
      // Deep links, redirects, the route parser and the universal-link
      // resolver still build these locations from RoutePaths and the
      // screens' path builders, so the typed routes must produce the same
      // URLs for every id and author callers pass.
      for (final id in _awkwardIds) {
        test('a curated list location matches pathForId for "$id"', () {
          expect(
            CuratedListFeedRouteData(listId: id).location,
            equals(CuratedListFeedScreen.pathForId(id)),
          );
        });

        test('an authored list location matches pathFor for "$id"', () {
          for (final author in [
            syntheticOtherTestPubkey,
            syntheticOtherTestNpub,
          ]) {
            expect(
              CuratedListByAuthorRouteData(pubkey: author, listId: id).location,
              equals(
                CuratedListByAuthorScreen.pathFor(pubkey: author, listId: id),
              ),
              reason: author,
            );
          }
        });

        test('the people-list locations match RoutePaths for "$id"', () {
          expect(
            PeopleListRouteData(listId: id).location,
            equals(RoutePaths.peopleListForId(id)),
          );
          expect(
            PeopleListMembersRouteData(listId: id).location,
            equals(RoutePaths.peopleListMembersForId(id)),
          );
          expect(
            EditPeopleListRouteData(listId: id).location,
            equals(RoutePaths.peopleListEditForId(id)),
          );
          expect(
            AddPeopleToListRouteData(listId: id).location,
            equals(RoutePaths.peopleListAddPeopleForId(id)),
          );
        });

        test('an owner query matches RoutePaths for "$id"', () {
          for (final owner in [
            syntheticOtherTestPubkey,
            syntheticOtherTestNpub,
          ]) {
            expect(
              PeopleListRouteData(listId: id, owner: owner).location,
              equals(RoutePaths.peopleListForId(id, ownerPubkey: owner)),
              reason: owner,
            );
            expect(
              PeopleListMembersRouteData(listId: id, owner: owner).location,
              equals(RoutePaths.peopleListMembersForId(id, ownerPubkey: owner)),
              reason: owner,
            );
          }
        });
      }

      test('create keeps its path, with and without a person to seed', () {
        expect(
          const CreatePeopleListRouteData().location,
          equals(CreatePeopleListPage.path),
        );
        expect(
          const CreatePeopleListRouteData(
            initialPubkey: syntheticOtherTestPubkey,
          ).location,
          equals(
            CreatePeopleListPage.pathWithInitialPubkey(
              syntheticOtherTestPubkey,
            ),
          ),
        );
      });

      test('saved videos and discover lists keep their paths', () {
        expect(
          const SavedVideosRouteData().location,
          equals(SavedVideosScreen.path),
        );
        expect(
          const DiscoverListsRouteData().location,
          equals(RoutePaths.discoverLists),
        );
      });
    });

    group('order', () {
      // go_router matches same-segment-count routes top-to-bottom, so the
      // literal `new` must be registered before `:listId` can capture it.
      test('create precedes the list route so a literal new is creation', () {
        final paths = listsRoutes()
            .whereType<GoRoute>()
            .map((route) => route.path)
            .toList();

        expect(
          paths.indexOf(CreatePeopleListPage.path),
          lessThan(paths.indexOf(UserListPeopleScreen.path)),
        );
      });
    });

    group('curated list hints', () {
      final now = DateTime.utc(2026);
      final discovered = CuratedList(
        id: 'skate',
        name: 'Skate',
        pubkey: syntheticOtherTestPubkey,
        videoEventIds: const [_videoId],
        createdAt: now,
        updatedAt: now,
      );

      testWidgets('a curated list reads its hint', (tester) async {
        await captureContext(tester);

        final screen = build(
          CuratedListFeedScreen.routeName,
          CuratedListFeedScreen.pathForId('skate'),
          pathParameters: const {'listId': 'skate'},
          extra: CuratedListRouteExtra(
            listName: 'Skate',
            videoIds: const [_videoId],
            authorPubkey: syntheticOtherTestPubkey,
            list: discovered,
          ),
        );

        expect(
          screen,
          isA<CuratedListFeedScreen>()
              .having((s) => s.listId, 'listId', 'skate')
              .having((s) => s.listName, 'listName', 'Skate')
              .having((s) => s.videoIds, 'videoIds', const [_videoId])
              .having(
                (s) => s.authorPubkey,
                'authorPubkey',
                syntheticOtherTestPubkey,
              )
              .having((s) => s.discoveredList, 'discoveredList', discovered),
        );
      });

      // A deep link carries no hint, and restored route state can hand one
      // back as a decoded map; neither may dead-end the route (#3335).
      for (final (label, extra) in [
        ('no hint', null),
        ('a restored map', const <String, dynamic>{'listName': 'Skate'}),
      ]) {
        testWidgets('a curated list opens from its id alone with $label', (
          tester,
        ) async {
          await captureContext(tester);

          final screen = build(
            CuratedListFeedScreen.routeName,
            CuratedListFeedScreen.pathForId('skate'),
            pathParameters: const {'listId': 'skate'},
            extra: extra,
          );

          expect(
            screen,
            isA<CuratedListFeedScreen>()
                .having((s) => s.listId, 'listId', 'skate')
                .having(
                  (s) => s.listName,
                  'listName',
                  context.l10n.routeDefaultListName,
                )
                .having((s) => s.videoIds, 'videoIds', isNull)
                .having((s) => s.authorPubkey, 'authorPubkey', isNull)
                .having((s) => s.discoveredList, 'discoveredList', isNull),
          );
        });
      }

      testWidgets('an authored list warms from its hint', (tester) async {
        await captureContext(tester);

        final screen = build(
          CuratedListByAuthorScreen.routeName,
          CuratedListByAuthorScreen.pathFor(
            pubkey: syntheticOtherTestPubkey,
            listId: 'skate',
          ),
          pathParameters: const {
            'pubkey': syntheticOtherTestPubkey,
            'listId': 'skate',
          },
          extra: CuratedListRouteExtra(listName: 'Skate', list: discovered),
        );

        expect(
          screen,
          isA<CuratedListByAuthorScreen>()
              .having(
                (s) => s.authorPubkey,
                'authorPubkey',
                syntheticOtherTestPubkey,
              )
              .having((s) => s.listId, 'listId', 'skate')
              .having((s) => s.discoveredList, 'discoveredList', discovered),
        );
      });

      testWidgets('an authored list opens from its path alone', (
        tester,
      ) async {
        await captureContext(tester);

        final screen = build(
          CuratedListByAuthorScreen.routeName,
          CuratedListByAuthorScreen.pathFor(
            pubkey: syntheticOtherTestNpub,
            listId: 'skate',
          ),
          pathParameters: const {
            'pubkey': syntheticOtherTestNpub,
            'listId': 'skate',
          },
          extra: const <String, dynamic>{'list': 'not a list'},
        );

        expect(
          screen,
          isA<CuratedListByAuthorScreen>()
              .having(
                (s) => s.authorPubkey,
                'authorPubkey',
                syntheticOtherTestPubkey,
              )
              .having((s) => s.discoveredList, 'discoveredList', isNull),
        );
      });
    });

    group('invalid ids', () {
      testWidgets('a curated list shows its own error for an empty id', (
        tester,
      ) async {
        await captureContext(tester);

        final screen = build(
          CuratedListFeedScreen.routeName,
          '${RoutePaths.curatedListFeedBase}/',
          pathParameters: const {'listId': ''},
        );

        expect(
          screen,
          isA<RouteErrorScreen>().having(
            (s) => s.message,
            'message',
            context.l10n.routeInvalidListId,
          ),
        );
      });

      testWidgets('an authored list shows its own error for an empty id', (
        tester,
      ) async {
        await captureContext(tester);

        final screen = build(
          CuratedListByAuthorScreen.routeName,
          '${RoutePaths.curatedListFeedBase}/$syntheticOtherTestPubkey/',
          pathParameters: const {
            'pubkey': syntheticOtherTestPubkey,
            'listId': '',
          },
        );

        expect(
          screen,
          isA<RouteErrorScreen>().having(
            (s) => s.message,
            'message',
            context.l10n.routeInvalidListId,
          ),
        );
      });
    });

    group(RoutePaths.discoverLists, () {
      testWidgets('lands on the Explore lists tab', (tester) async {
        final router = GoRouter(
          initialLocation: '/',
          routes: [
            GoRoute(path: '/', builder: (_, _) => const SizedBox.shrink()),
            ...listsRoutes(),
            GoRoute(
              path: ExploreScreen.pathTabSubpath,
              builder: (_, state) =>
                  Text('tab:${state.pathParameters['name']}'),
            ),
          ],
        );
        addTearDown(router.dispose);

        await tester.pumpWidget(
          MaterialApp.router(
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            routerConfig: router,
          ),
        );
        router.go(RoutePaths.discoverLists);
        await tester.pumpAndSettle();

        expect(find.text('tab:lists'), findsOneWidget);
        expect(
          router.routeInformationProvider.value.uri.path,
          ExploreScreen.pathForTab('lists'),
        );
      });
    });
  });

  group('Curated list by author route', () {
    setUp(() => _selected = null);

    Future<void> pumpRoute(WidgetTester tester, String location) async {
      await tester.pumpWidget(
        testProviderScope(
          child: Consumer(
            builder: (context, ref, child) => MaterialApp.router(
              localizationsDelegates: appLocalizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              routerConfig: ref.watch(_routerProvider(location)),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    // Relays require a 64-char hex author, so passing this through only turned
    // into a load failure after a round trip.
    testWidgets('rejects an author that is not a key', (tester) async {
      await pumpRoute(tester, '/list/hello/patrol-list');

      expect(_selected, isA<RouteErrorScreen>());
    });

    testWidgets('rejects an npub author whose checksum fails', (tester) async {
      await pumpRoute(tester, '/list/$syntheticMisspelledNpub/patrol-list');

      expect(_selected, isA<RouteErrorScreen>());
    });

    testWidgets('resolves an npub author to its hex key', (tester) async {
      await pumpRoute(tester, '/list/$syntheticOtherTestNpub/patrol-list');

      expect(
        _selected,
        isA<CuratedListByAuthorScreen>().having(
          (screen) => screen.authorPubkey,
          'authorPubkey',
          syntheticOtherTestPubkey,
        ),
      );
    });

    testWidgets('lowercases an uppercase hex author', (tester) async {
      final upper = syntheticOtherTestPubkey.toUpperCase();

      await pumpRoute(tester, '/list/$upper/patrol-list');

      expect(
        _selected,
        isA<CuratedListByAuthorScreen>().having(
          (screen) => screen.authorPubkey,
          'authorPubkey',
          syntheticOtherTestPubkey,
        ),
      );
    });
  });
}
