// ABOUTME: Widget tests for the owned-lists surface on the profile Lists tab
// ABOUTME: Covers the bookmarks entry that keeps kind 10003 saves readable

import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/features/feature_flags/models/feature_flag.dart';
import 'package:openvine/features/feature_flags/providers/feature_flag_providers.dart';
import 'package:openvine/features/people_lists/bloc/people_lists_bloc.dart';
import 'package:openvine/features/people_lists/view/create_people_list_page.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/list_providers.dart';
import 'package:openvine/screens/saved_videos_screen.dart';
import 'package:openvine/services/curated_list_service.dart';
import 'package:openvine/widgets/add_to_list_dialog.dart';
import 'package:openvine/widgets/divine_list_thumbnail.dart';
import 'package:openvine/widgets/profile/profile_lists_grid.dart';
import 'package:openvine/widgets/video_thumbnail_widget.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../helpers/test_provider_overrides.dart';

class _MockCuratedListService extends Mock implements CuratedListService {}

class _MockPeopleListsBloc extends MockBloc<PeopleListsEvent, PeopleListsState>
    implements PeopleListsBloc {}

List<CuratedList> _fakeLists = [];
Completer<List<CuratedList>>? _videoLoad;
_MockCuratedListService? _fakeService;

class _FakeCuratedListsState extends CuratedListsState {
  @override
  CuratedListService? get service => _fakeService;

  @override
  Future<List<CuratedList>> build() async =>
      _videoLoad == null ? _fakeLists : await _videoLoad!.future;
}

CuratedList _videoList(String id) => CuratedList(
  id: id,
  name: 'Video $id',
  videoEventIds: ['a' * 64],
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
    late String pushedRoute;
    late _MockPeopleListsBloc peopleBloc;
    var enabled = true;
    const owner =
        'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
    final personList = UserList(
      id: 'friends',
      name: 'Friends',
      pubkeys: const [],
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );

    setUp(() {
      _fakeLists = [];
      _videoLoad = null;
      enabled = true;
      peopleBloc = _MockPeopleListsBloc();
      when(() => peopleBloc.state).thenReturn(
        const PeopleListsState(
          status: PeopleListsStatus.ready,
          ownerPubkey: owner,
        ),
      );
      mockListService = _MockCuratedListService();
      _fakeService = mockListService;
      when(() => mockListService.myLists).thenReturn(const <CuratedList>[]);
      pushedRoute = '';
    });

    Widget buildSubject({ThemeData? theme, Override? hydrationOverride}) =>
        testProviderScope(
          additionalOverrides: [
            curatedListsStateProvider.overrideWith(_FakeCuratedListsState.new),
            hydrationOverride ??
                myListsWithThumbnailsProvider.overrideWith(
                  (ref) async => mockListService.myLists,
                ),
            isFeatureEnabledProvider(FeatureFlag.curatedLists)
                .overrideWithValue(enabled),
          ],
          child: BlocProvider<PeopleListsBloc>.value(
            value: peopleBloc,
            child: MaterialApp.router(
              theme: theme,
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
                    path: CreatePeopleListPage.path,
                    builder: (_, _) {
                      pushedRoute = CreatePeopleListPage.path;
                      return const Scaffold(body: Text('create people'));
                    },
                  ),
                  GoRoute(
                    path: '/people-lists/:listId',
                    builder: (_, state) {
                      pushedRoute = state.uri.path;
                      return const Scaffold(body: Text('members'));
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
                    path: SavedVideosScreen.path,
                    builder: (_, _) {
                      pushedRoute = SavedVideosScreen.path;
                      return const Scaffold(body: Text('saved'));
                    },
                  ),
                ],
              ),
            ),
          ),
        );

    testWidgets('empty profile offers separate people and video creation', (
      tester,
    ) async {
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();
      expect(find.text('New people list'), findsOneWidget);
      expect(find.text('New video list'), findsOneWidget);
      expect(find.text('People Lists'), findsOneWidget);
      expect(find.text('Video Lists'), findsOneWidget);
      await tester.tap(find.text('New people list'));
      await tester.pumpAndSettle();
      expect(pushedRoute, CreatePeopleListPage.path);
    });

    for (final width in [360.0, 393.0, 430.0]) {
      testWidgets('creation labels remain readable at $width phone width', (
        tester,
      ) async {
        await tester.binding.setSurfaceSize(Size(width, 1000));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await tester.pumpWidget(buildSubject());
        await tester.pumpAndSettle();
        for (final label in ['New people list', 'New video list']) {
          final paragraph = tester.renderObject<RenderParagraph>(
            find.descendant(
              of: find.text(label),
              matching: find.byType(RichText),
            ),
          );
          expect(paragraph.didExceedMaxLines, isFalse, reason: label);
        }
      });
    }

    testWidgets('owner-less people section does not reserve an empty column', (
      tester,
    ) async {
      when(() => peopleBloc.state).thenReturn(const PeopleListsState());
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();
      final button = find.widgetWithText(DivineButton, 'New video list');
      expect(tester.getSize(button).width, 768);
      expect(find.text('New people list'), findsNothing);
    });

    testWidgets('wide surface stacks sections with enlarged text', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(800, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      tester.platformDispatcher.textScaleFactorTestValue = 1.3;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();
      expect(
        tester.getTopLeft(find.text('People Lists')).dy,
        greaterThan(tester.getTopLeft(find.text('Video Lists')).dy),
      );
      for (final label in ['New people list', 'New video list']) {
        expect(
          tester.getSize(find.widgetWithText(DivineButton, label)).width,
          768,
        );
        final paragraph = tester.renderObject<RenderParagraph>(
          find.descendant(
            of: find.text(label),
            matching: find.byType(RichText),
          ),
        );
        expect(paragraph.didExceedMaxLines, isFalse, reason: label);
      }
    });

    testWidgets('people read failure keeps cached lists and offers retry', (
      tester,
    ) async {
      when(() => peopleBloc.state).thenReturn(
        PeopleListsState(
          status: PeopleListsStatus.ready,
          ownerPubkey: owner,
          lists: [personList],
          ownerReadStatus: PeopleListsOwnerReadStatus.failed,
        ),
      );
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();
      expect(find.text('Friends'), findsOneWidget);
      expect(find.text('Bookmarks'), findsOneWidget);
      await tester.tap(find.text('Try again'));
      verify(() => peopleBloc.add(const PeopleListsOwnerSyncRequested()))
          .called(1);
    });

    testWidgets('video loading does not hide people or bookmarks', (
      tester,
    ) async {
      _videoLoad = Completer();
      when(() => peopleBloc.state).thenReturn(
        PeopleListsState(
          status: PeopleListsStatus.ready,
          ownerPubkey: owner,
          lists: [personList],
        ),
      );
      await tester.pumpWidget(buildSubject());
      await tester.pump();
      expect(find.text('Friends'), findsOneWidget);
      expect(find.text('Bookmarks'), findsOneWidget);
      _videoLoad!.complete([]);
      await tester.pumpAndSettle();
    });

    testWidgets(
      'master off hides people controls and retains video and bookmarks',
      (tester) async {
        enabled = false;
        await tester.pumpWidget(buildSubject());
        await tester.pumpAndSettle();
        expect(find.text('New people list'), findsNothing);
        expect(find.text('New video list'), findsOneWidget);
        expect(find.text('Bookmarks'), findsOneWidget);
      },
    );

    for (final withPeople in [false, true]) {
      testWidgets('shows owned video lists with people=$withPeople', (
        tester,
      ) async {
        final videoList = CuratedList(
          id: 'videos',
          name: 'Favorite videos',
          videoEventIds: const [],
          createdAt: DateTime(2026),
          updatedAt: DateTime(2026),
        );
        when(() => mockListService.myLists).thenReturn([videoList]);
        when(() => peopleBloc.state).thenReturn(
          PeopleListsState(
            status: PeopleListsStatus.ready,
            ownerPubkey: owner,
            lists: withPeople ? [personList] : [],
          ),
        );
        await tester.pumpWidget(buildSubject());
        await tester.pumpAndSettle();
        expect(find.text('Favorite videos'), findsOneWidget);
        expect(
          find.text('Friends'),
          withPeople ? findsOneWidget : findsNothing,
        );
        expect(find.text('Bookmarks'), findsOneWidget);
      });
    }

    testWidgets('people loading keeps video creation and bookmarks visible', (
      tester,
    ) async {
      when(() => peopleBloc.state).thenReturn(
        const PeopleListsState(
          status: PeopleListsStatus.loading,
          ownerPubkey: owner,
          ownerReadStatus: PeopleListsOwnerReadStatus.pending,
        ),
      );
      await tester.pumpWidget(buildSubject());
      await tester.pump();
      expect(find.text('New people list'), findsOneWidget);
      expect(find.text('New video list'), findsOneWidget);
      expect(find.text('Bookmarks'), findsOneWidget);
      expect(
        find.text('Create a list to start grouping people.'),
        findsNothing,
      );
    });

    testWidgets('video failure keeps people list accessible', (tester) async {
      _videoLoad = Completer();
      when(() => peopleBloc.state).thenReturn(
        PeopleListsState(
          status: PeopleListsStatus.ready,
          ownerPubkey: owner,
          lists: [personList],
        ),
      );
      await tester.pumpWidget(buildSubject());
      _videoLoad!.completeError(StateError('unavailable'));
      await tester.pumpAndSettle();
      expect(find.text('Bookmarks'), findsOneWidget);
      expect(find.text('Try again'), findsOneWidget);
      await tester.tap(find.text('Friends'));
      await tester.pumpAndSettle();
      expect(pushedRoute, '/people-lists/friends');
    });

    testWidgets('observes newly created owned lists from the app bloc', (
      tester,
    ) async {
      final states = StreamController<PeopleListsState>();
      addTearDown(states.close);
      whenListen(
        peopleBloc,
        states.stream,
        initialState: const PeopleListsState(
          status: PeopleListsStatus.ready,
          ownerPubkey: owner,
        ),
      );
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();
      expect(find.text('Friends'), findsNothing);
      states.add(
        PeopleListsState(
          status: PeopleListsStatus.ready,
          ownerPubkey: owner,
          lists: [personList],
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Friends'), findsOneWidget);
    });

    for (final light in [false, true]) {
      testWidgets(
        'renders people and video controls in ${light ? 'light' : 'dark'} theme',
        (tester) async {
          when(() => peopleBloc.state).thenReturn(
            PeopleListsState(
              status: PeopleListsStatus.ready,
              ownerPubkey: owner,
              lists: [personList],
            ),
          );
          await tester.pumpWidget(
            buildSubject(theme: light ? VineTheme.lightTheme : VineTheme.theme),
          );
          await tester.pumpAndSettle();
          expect(find.text('Friends'), findsOneWidget);
          expect(find.text('New people list'), findsOneWidget);
          expect(find.text('New video list'), findsOneWidget);
          final bookmark = tester.widget<DivineIcon>(
            find.byWidgetPredicate(
              (widget) =>
                  widget is DivineIcon &&
                  widget.icon == DivineIconName.bookmarkSimple,
            ),
          );
          final colors = tester.element(find.text('Bookmarks')).vineColors;
          expect(bookmark.color, colors.primaryText);
          expect(tester.takeException(), isNull);
        },
      );
    }

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
    group('renders', () {
      testWidgets("shows both columns of the viewer's lists", (tester) async {
        when(
          () => mockListService.myLists,
        ).thenReturn([_videoList('skate')]);
        whenListen(
          peopleBloc,
          const Stream<PeopleListsState>.empty(),
          initialState: PeopleListsState(
            status: PeopleListsStatus.ready,
            ownerPubkey: owner,
            lists: [_peopleList('crew')],
          ),
        );

        await tester.pumpWidget(buildSubject());
        await tester.pumpAndSettle();

        expect(find.byType(DivineListThumbnail), findsNWidgets(2));
        expect(find.text('Video skate'), findsOneWidget);

        expect(find.text('People crew'), findsOneWidget);
        expect(
          tester.getTopLeft(find.text('Video skate')).dx,
          lessThan(tester.getTopLeft(find.text('People crew')).dx),
        );
      });

      testWidgets('keeps an owned list visible before it has any videos', (
        tester,
      ) async {
        when(() => mockListService.myLists).thenReturn([
          _videoList('empty').copyWith(videoEventIds: const []),
        ]);

        await tester.pumpWidget(buildSubject());
        await tester.pumpAndSettle();

        expect(find.text('Video empty'), findsOneWidget);
        expect(find.byType(DivineListThumbnail), findsOneWidget);
      });

      testWidgets('uses the outline create button', (tester) async {
        await tester.pumpWidget(buildSubject());
        await tester.pumpAndSettle();

        final l10n = lookupAppLocalizations(const Locale('en'));
        final button = tester.widget<DivineButton>(
          find.ancestor(
            of: find.text(l10n.listNewVideoList),
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
    });

    group('navigation', () {
      testWidgets('opens the create dialog from the create button', (
        tester,
      ) async {
        await tester.binding.setSurfaceSize(const Size(800, 1200));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await tester.pumpWidget(buildSubject());
        await tester.pumpAndSettle();
        final l10n = lookupAppLocalizations(const Locale('en'));
        expect(find.byType(CreateListDialog), findsNothing);

        await tester.tap(find.text(l10n.listNewVideoList));
        await tester.pumpAndSettle();

        expect(find.byType(CreateListDialog), findsOneWidget);
        // Main retains a type-specific creation label; the existing dialog
        // keeps its own title and confirmation action.
        expect(find.text(l10n.listNewVideoList), findsOneWidget);
        expect(find.text(l10n.listCreateNewList), findsOneWidget);
        expect(find.bySemanticsLabel(l10n.listCreate), findsOneWidget);
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
          peopleBloc,
          const Stream<PeopleListsState>.empty(),
          initialState: PeopleListsState(
            status: PeopleListsStatus.ready,
            ownerPubkey: owner,
            lists: [_peopleList('crew')],
          ),
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

    group('list membership vs thumbnail hydration', () {
      testWidgets('keeps thumbnails on their author-qualified card', (
        tester,
      ) async {
        final first = _videoList('my_vine_list').copyWith(
          pubkey: 'a' * 64,
          name: 'First owner',
        );
        final second = first.copyWith(pubkey: 'b' * 64, name: 'Second owner');
        final hydrated = [
          first.copyWith(thumbnailUrls: ['https://example.com/first.jpg']),
          second.copyWith(thumbnailUrls: ['https://example.com/second.jpg']),
        ];
        _fakeLists = [first, second];
        when(() => mockListService.myLists).thenReturn(_fakeLists);
        await tester.pumpWidget(
          buildSubject(
            hydrationOverride: myListsWithThumbnailsProvider.overrideWith(
              (ref) async => hydrated,
            ),
          ),
        );
        await tester.pump();
        await tester.pump();
        for (final (name, url) in [
          ('First owner', 'https://example.com/first.jpg'),
          ('Second owner', 'https://example.com/second.jpg'),
        ]) {
          final card = find.ancestor(
            of: find.text(name),
            matching: find.byType(DivineListThumbnail),
          );
          final image = find.descendant(
            of: card,
            matching: find.byType(PassiveAuthThumbnailImage),
          );
          expect(tester.widget<PassiveAuthThumbnailImage>(image).url, url);
        }
      });

      testWidgets(
        'retires cached and durable thumbnails during policy reload',
        (
          tester,
        ) async {
          final list = _videoList('my_vine_list').copyWith(
            pubkey: 'a' * 64,
            thumbnailUrls: ['https://example.com/unfiltered.jpg'],
          );
          _fakeLists = [list];
          when(() => mockListService.myLists).thenReturn(_fakeLists);
          var pass = 0;
          final reload = Completer<List<CuratedList>>();
          await tester.pumpWidget(
            buildSubject(
              hydrationOverride: myListsWithThumbnailsProvider.overrideWith((
                ref,
              ) {
                if (pass++ == 0) {
                  return Future.value([
                    list.copyWith(
                      thumbnailUrls: ['https://example.com/safe.jpg'],
                    ),
                  ]);
                }
                return reload.future;
              }),
            ),
          );
          await tester.pump();
          await tester.pump();
          expect(find.byType(PassiveAuthThumbnailImage), findsOneWidget);
          ProviderScope.containerOf(
            tester.element(find.byType(ProfileListsGrid)),
          ).invalidate(myListsWithThumbnailsProvider);
          await tester.pump();
          expect(find.byType(PassiveAuthThumbnailImage), findsNothing);
          reload.complete([]);
          await tester.pump();
          await tester.pump();
          expect(find.byType(PassiveAuthThumbnailImage), findsNothing);
        },
      );

      testWidgets('never carries the previous account images through reload', (
        tester,
      ) async {
        final outgoing = _videoList('my_vine_list').copyWith(pubkey: 'a' * 64);
        final incoming = outgoing.copyWith(
          pubkey: 'b' * 64,
          name: 'Incoming owner',
          thumbnailUrls: ['https://example.com/incoming-unfiltered.jpg'],
        );
        _fakeLists = [outgoing];
        when(() => mockListService.myLists).thenAnswer((_) => _fakeLists);
        var pass = 0;
        final reload = Completer<List<CuratedList>>();
        await tester.pumpWidget(
          buildSubject(
            hydrationOverride: myListsWithThumbnailsProvider.overrideWith((
              ref,
            ) async {
              await ref.watch(curatedListsStateProvider.future);
              if (pass++ == 0) {
                return [
                  outgoing.copyWith(
                    thumbnailUrls: ['https://example.com/outgoing-safe.jpg'],
                  ),
                ];
              }
              return reload.future;
            }),
          ),
        );
        await tester.pump();
        await tester.pump();
        expect(find.byType(PassiveAuthThumbnailImage), findsOneWidget);
        final container = ProviderScope.containerOf(
          tester.element(find.byType(ProfileListsGrid)),
        );
        _fakeLists = [incoming];
        container.invalidate(curatedListsStateProvider);
        await tester.pump();
        await tester.pump();
        expect(find.text('Incoming owner'), findsOneWidget);
        expect(container.read(myListsWithThumbnailsProvider).isLoading, isTrue);
        expect(find.byType(PassiveAuthThumbnailImage), findsNothing);
        reload.complete([
          incoming.copyWith(
            thumbnailUrls: ['https://example.com/incoming-safe.jpg'],
          ),
        ]);
        await tester.pump();
        await tester.pump();
        expect(
          tester
              .widget<PassiveAuthThumbnailImage>(
                find.byType(PassiveAuthThumbnailImage),
              )
              .url,
          'https://example.com/incoming-safe.jpg',
        );
      });

      testWidgets('does not fall back to durable thumbnails after a failure', (
        tester,
      ) async {
        _fakeLists = [
          _videoList('list').copyWith(
            thumbnailUrls: ['https://example.com/unfiltered.jpg'],
          ),
        ];
        when(() => mockListService.myLists).thenReturn(_fakeLists);
        await tester.pumpWidget(
          buildSubject(
            hydrationOverride: myListsWithThumbnailsProvider.overrideWith(
              (ref) async => throw StateError('Hydration failed'),
            ),
          ),
        );
        await tester.pump();
        await tester.pump();
        expect(find.text('Video list'), findsOneWidget);
        expect(find.byType(PassiveAuthThumbnailImage), findsNothing);
        expect(
          tester
              .widget<DivineListThumbnail>(find.byType(DivineListThumbnail))
              .thumbnailsPending,
          isFalse,
        );
      });

      testWidgets('cards shimmer their fans until the resolver first returns', (
        tester,
      ) async {
        _fakeLists = [_videoList('a')];
        when(() => mockListService.myLists).thenReturn([_videoList('a')]);
        final neverResolves = Completer<List<CuratedList>>();

        await tester.pumpWidget(
          testProviderScope(
            additionalOverrides: [
              curatedListsStateProvider.overrideWith(
                _FakeCuratedListsState.new,
              ),
              myListsWithThumbnailsProvider.overrideWith(
                (ref) => neverResolves.future,
              ),
            ],
            child: BlocProvider<PeopleListsBloc>.value(
              value: peopleBloc,
              child: const MaterialApp(
                localizationsDelegates: appLocalizationsDelegates,
                supportedLocales: AppLocalizations.supportedLocales,
                home: Scaffold(body: ProfileListsGrid()),
              ),
            ),
          ),
        );
        await tester.pump();
        await tester.pump();

        final card = tester.widget<DivineListThumbnail>(
          find.byType(DivineListThumbnail),
        );
        expect(card.thumbnailsPending, isTrue);
      });

      testWidgets('renders a list the resolver has not caught up with', (
        tester,
      ) async {
        _fakeLists = [_videoList('a')];
        when(() => mockListService.myLists).thenReturn([_videoList('a')]);

        // Faithful to the real provider: depends on curatedListsStateProvider,
        // then awaits the resolver. The second pass is held open so the
        // recompute window is observable.
        var pass = 0;
        final slowResolve = Completer<void>();

        await tester.pumpWidget(
          testProviderScope(
            additionalOverrides: [
              curatedListsStateProvider.overrideWith(
                _FakeCuratedListsState.new,
              ),
              myListsWithThumbnailsProvider.overrideWith((ref) async {
                await ref.watch(curatedListsStateProvider.future);
                final lists = mockListService.myLists;
                if (lists.isEmpty) return lists;
                if (pass++ > 0) await slowResolve.future;
                return lists;
              }),
            ],
            child: BlocProvider<PeopleListsBloc>.value(
              value: peopleBloc,
              child: const MaterialApp(
                localizationsDelegates: appLocalizationsDelegates,
                supportedLocales: AppLocalizations.supportedLocales,
                home: Scaffold(body: ProfileListsGrid()),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Video a'), findsOneWidget);

        // The user creates a list: the service gains it and notifies, so
        // curatedListsStateProvider re-emits and the resolver restarts.
        _fakeLists = [_videoList('a'), _videoList('b')];
        when(
          () => mockListService.myLists,
        ).thenReturn([_videoList('a'), _videoList('b')]);
        ProviderScope.containerOf(
          tester.element(find.byType(ProfileListsGrid)),
        ).invalidate(curatedListsStateProvider);
        await tester.pump();
        await tester.pump();

        expect(find.text('Video a'), findsOneWidget);
        expect(
          find.text('Video b'),
          findsOneWidget,
          reason:
              'a just-created list must not wait for every other list to '
              'resolve its thumbnails',
        );

        slowResolve.complete();
        await tester.pumpAndSettle();
      });
    });
  });
}
