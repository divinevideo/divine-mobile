// ABOUTME: Widget tests for the owned-lists surface on the profile Lists tab
// ABOUTME: Covers the mixed newest-first gallery and the list-type chooser

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
import 'package:openvine/features/people_lists/bloc/people_lists_bloc.dart';
import 'package:openvine/features/people_lists/view/create_people_list_page.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/list_providers.dart';
import 'package:openvine/router/routes/route_extras.dart';
import 'package:openvine/services/curated_list_service.dart';
import 'package:openvine/widgets/branded_loading_indicator.dart';
import 'package:openvine/widgets/divine_list_thumbnail.dart';
import 'package:openvine/widgets/list_info_sheet/list_info_form.dart';
import 'package:openvine/widgets/profile/profile_lists_grid.dart';
import 'package:openvine/widgets/video_thumbnail_widget.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../helpers/test_provider_overrides.dart';

class _MockCuratedListService extends Mock implements CuratedListService {
  @override
  bool recoveryNeedsRepair = false;
}

class _MockPeopleListsBloc extends MockBloc<PeopleListsEvent, PeopleListsState>
    implements PeopleListsBloc {}

List<CuratedList> _fakeLists = [];
Completer<List<CuratedList>>? _videoLoad;
_MockCuratedListService? _fakeService;
bool _failInitialization = false;
int _initializationAttempts = 0;

class _FakeCuratedListsState extends CuratedListsState {
  @override
  CuratedListService? get service => _fakeService;

  @override
  Future<List<CuratedList>> build() async {
    _initializationAttempts++;
    if (_failInitialization && _initializationAttempts == 1) {
      throw Exception('local list initialization failed');
    }
    return _videoLoad == null ? _fakeLists : await _videoLoad!.future;
  }
}

CuratedList _videoList(String id, {DateTime? createdAt}) => CuratedList(
  id: id,
  name: 'Video $id',
  videoEventIds: ['a' * 64],
  createdAt: createdAt ?? DateTime(2026),
  updatedAt: DateTime(2026),
);

UserList _peopleList(String id, {DateTime? createdAt}) => UserList(
  id: id,
  name: 'People $id',
  pubkeys: ['a' * 64],
  createdAt: createdAt ?? DateTime(2026),
  updatedAt: DateTime(2026),
);

void main() {
  group(ProfileListsGrid, () {
    late _MockCuratedListService mockListService;
    late String pushedRoute;
    Object? pushedExtra;
    late _MockPeopleListsBloc peopleBloc;
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
      _failInitialization = false;
      _initializationAttempts = 0;
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
      pushedExtra = null;
    });

    Widget buildSubject({ThemeData? theme, Override? hydrationOverride}) =>
        testProviderScope(
          additionalOverrides: [
            curatedListsStateProvider.overrideWith(_FakeCuratedListsState.new),
            hydrationOverride ??
                myListsWithThumbnailsProvider.overrideWith(
                  (ref) async => mockListService.myLists,
                ),
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
                      pushedExtra = state.extra;
                      return const Scaffold(body: Text('video list'));
                    },
                  ),
                ],
              ),
            ),
          ),
        );

    final l10n = lookupAppLocalizations(const Locale('en'));

    PeopleListsState readyPeople(List<UserList> lists) => PeopleListsState(
      status: PeopleListsStatus.ready,
      ownerPubkey: owner,
      lists: lists,
    );

    Finder createButton() =>
        find.widgetWithText(DivineButton, l10n.listCreateNewList);

    group('renders', () {
      testWidgets('one create button and the empty message with no lists', (
        tester,
      ) async {
        await tester.pumpWidget(buildSubject());
        await tester.pumpAndSettle();

        expect(createButton(), findsOneWidget);
        expect(find.byType(DivineButton), findsOneWidget);
        expect(find.text(l10n.profileListsEmpty), findsOneWidget);
        expect(find.text(l10n.listNewVideoList), findsNothing);
        expect(find.text(l10n.listNewPeopleList), findsNothing);
        expect(find.text(l10n.shareMenuBookmarks), findsNothing);
      });

      for (final width in [360.0, 393.0, 430.0]) {
        testWidgets('create button spans the $width phone width', (
          tester,
        ) async {
          await tester.binding.setSurfaceSize(Size(width, 1000));
          addTearDown(() => tester.binding.setSurfaceSize(null));
          await tester.pumpWidget(buildSubject());
          await tester.pumpAndSettle();

          expect(tester.getSize(createButton()).width, width - 24);
          final paragraph = tester.renderObject<RenderParagraph>(
            find.descendant(
              of: find.text(l10n.listCreateNewList),
              matching: find.byType(RichText),
            ),
          );
          expect(paragraph.didExceedMaxLines, isFalse);
        });
      }

      testWidgets('uses the outline create button', (tester) async {
        await tester.pumpWidget(buildSubject());
        await tester.pumpAndSettle();

        final button = tester.widget<DivineButton>(createButton());
        expect(button.type, equals(DivineButtonType.secondary));
      });

      testWidgets('mixes both kinds newest first in two columns', (
        tester,
      ) async {
        await tester.binding.setSurfaceSize(const Size(393, 1600));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        when(() => mockListService.myLists).thenReturn([
          _videoList('old', createdAt: DateTime(2026)),
          _videoList('new', createdAt: DateTime(2026, 3)),
        ]);
        when(() => peopleBloc.state).thenReturn(
          readyPeople([_peopleList('mid', createdAt: DateTime(2026, 2))]),
        );
        await tester.pumpWidget(buildSubject());
        await tester.pumpAndSettle();

        final newest = tester.getTopLeft(find.text('Video new'));
        final middle = tester.getTopLeft(find.text('People mid'));
        final oldest = tester.getTopLeft(find.text('Video old'));
        expect(newest.dy, middle.dy);
        expect(newest.dx, lessThan(middle.dx));
        expect(oldest.dx, newest.dx);
        expect(oldest.dy, greaterThan(newest.dy));
        expect(find.text(l10n.profileListsEmpty), findsNothing);
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

      testWidgets('observes newly created owned lists from the app bloc', (
        tester,
      ) async {
        final states = StreamController<PeopleListsState>();
        addTearDown(states.close);
        whenListen(
          peopleBloc,
          states.stream,
          initialState: readyPeople(const []),
        );
        await tester.pumpWidget(buildSubject());
        await tester.pumpAndSettle();
        expect(find.text('Friends'), findsNothing);
        states.add(readyPeople([personList]));
        await tester.pumpAndSettle();
        expect(find.text('Friends'), findsOneWidget);
      });

      for (final light in [false, true]) {
        testWidgets(
          'renders the gallery in ${light ? 'light' : 'dark'} theme',
          (tester) async {
            when(() => mockListService.myLists).thenReturn([_videoList('a')]);
            when(() => peopleBloc.state).thenReturn(readyPeople([personList]));
            await tester.pumpWidget(
              buildSubject(
                theme: light ? VineTheme.lightTheme : VineTheme.theme,
              ),
            );
            await tester.pumpAndSettle();
            expect(find.text('Friends'), findsOneWidget);
            expect(find.text('Video a'), findsOneWidget);
            expect(tester.takeException(), isNull);
          },
        );
      }
    });

    group('loading and failure', () {
      testWidgets('video loading shows people cards with a loader', (
        tester,
      ) async {
        _videoLoad = Completer();
        when(() => peopleBloc.state).thenReturn(readyPeople([personList]));
        await tester.pumpWidget(buildSubject());
        await tester.pump();

        expect(find.text('Friends'), findsOneWidget);
        expect(find.byType(BrandedLoadingIndicator), findsOneWidget);
        expect(find.text(l10n.profileListsEmpty), findsNothing);
        _videoLoad!.complete([]);
        await tester.pumpAndSettle();
        expect(find.byType(BrandedLoadingIndicator), findsNothing);
      });

      testWidgets('people loading shows video cards with a loader', (
        tester,
      ) async {
        when(() => mockListService.myLists).thenReturn([_videoList('a')]);
        when(() => peopleBloc.state).thenReturn(
          const PeopleListsState(
            status: PeopleListsStatus.loading,
            ownerPubkey: owner,
            ownerReadStatus: PeopleListsOwnerReadStatus.pending,
          ),
        );
        await tester.pumpWidget(buildSubject());
        await tester.pump();
        await tester.pump();

        expect(find.text('Video a'), findsOneWidget);
        expect(find.byType(BrandedLoadingIndicator), findsOneWidget);
        expect(find.text(l10n.profileListsEmpty), findsNothing);
      });

      testWidgets('people read failure stays hidden behind loaded lists', (
        tester,
      ) async {
        // A slow relay fails the strict owner read even though the lists
        // came back; the gallery shows them without an error under them.
        when(() => mockListService.myLists).thenReturn([_videoList('a')]);
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
        expect(find.text('Video a'), findsOneWidget);
        expect(find.text(l10n.listErrorLoading), findsNothing);
        expect(find.text(l10n.peopleListsAddPeopleRetry), findsNothing);
        expect(find.text(l10n.profileListsEmpty), findsNothing);
      });

      testWidgets('people read failure with no lists offers retry', (
        tester,
      ) async {
        when(() => peopleBloc.state).thenReturn(
          const PeopleListsState(
            status: PeopleListsStatus.ready,
            ownerPubkey: owner,
            ownerReadStatus: PeopleListsOwnerReadStatus.failed,
          ),
        );
        await tester.pumpWidget(buildSubject());
        await tester.pumpAndSettle();
        expect(find.text(l10n.listErrorLoading), findsOneWidget);
        expect(find.text(l10n.profileListsEmpty), findsNothing);
        await tester.tap(find.text(l10n.peopleListsAddPeopleRetry));
        verify(
          () => peopleBloc.add(const PeopleListsOwnerSyncRequested()),
        ).called(1);
      });

      testWidgets('people read failure waits for the video lists', (
        tester,
      ) async {
        // Until the video lists load there may still be something to show,
        // so the people error must not flash under the loader and vanish.
        _videoLoad = Completer();
        when(() => mockListService.myLists).thenReturn([_videoList('a')]);
        when(() => peopleBloc.state).thenReturn(
          const PeopleListsState(
            status: PeopleListsStatus.ready,
            ownerPubkey: owner,
            ownerReadStatus: PeopleListsOwnerReadStatus.failed,
          ),
        );
        await tester.pumpWidget(buildSubject());
        await tester.pump();
        expect(find.byType(BrandedLoadingIndicator), findsOneWidget);
        expect(find.text(l10n.listErrorLoading), findsNothing);

        _videoLoad!.complete([_videoList('a')]);
        await tester.pumpAndSettle();
        expect(find.text('Video a'), findsOneWidget);
        expect(find.text(l10n.listErrorLoading), findsNothing);
      });

      testWidgets('video failure keeps people list accessible', (
        tester,
      ) async {
        _videoLoad = Completer();
        when(() => peopleBloc.state).thenReturn(readyPeople([personList]));
        await tester.pumpWidget(buildSubject());
        _videoLoad!.completeError(StateError('unavailable'));
        await tester.pumpAndSettle();
        expect(find.text(l10n.searchTryAgain), findsOneWidget);
        expect(find.text(l10n.profileListsEmpty), findsNothing);
        await tester.tap(find.text('Friends'));
        await tester.pumpAndSettle();
        expect(pushedRoute, '/people-lists/friends');
      });

      testWidgets('initialization failure offers retry before video lists', (
        tester,
      ) async {
        _failInitialization = true;
        _fakeLists = [_videoList('retry-list')];
        when(() => mockListService.myLists).thenReturn(_fakeLists);
        when(() => peopleBloc.state).thenReturn(readyPeople([personList]));
        await tester.pumpWidget(buildSubject());
        await tester.pumpAndSettle();
        expect(find.text(l10n.listErrorLoading), findsOneWidget);
        expect(find.text('Video retry-list'), findsNothing);
        expect(createButton(), findsOneWidget);
        expect(find.text('Friends'), findsOneWidget);

        await tester.tap(find.text(l10n.searchTryAgain));
        await tester.pumpAndSettle();
        expect(_initializationAttempts, 2);
        expect(find.text(l10n.listErrorLoading), findsNothing);
        expect(find.text('Video retry-list'), findsOneWidget);
        expect(find.text('Friends'), findsOneWidget);
      });
    });

    group('create list', () {
      testWidgets('offers both list types without a selection', (
        tester,
      ) async {
        await tester.pumpWidget(buildSubject());
        await tester.pumpAndSettle();

        await tester.tap(createButton());
        await tester.pumpAndSettle();

        expect(find.text(l10n.listTypeSheetTitle), findsOneWidget);
        expect(find.text(l10n.listTypeVideoList), findsOneWidget);
        expect(find.text(l10n.listTypePeopleList), findsOneWidget);
        final icons = tester
            .widgetList<DivineIcon>(find.byType(DivineIcon))
            .map((icon) => icon.icon);
        expect(icons, containsAll([DivineIconName.play, DivineIconName.users]));
        expect(icons, isNot(contains(DivineIconName.check)));
      });

      testWidgets('video list opens the create sheet', (tester) async {
        await tester.binding.setSurfaceSize(const Size(800, 1200));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await tester.pumpWidget(buildSubject());
        await tester.pumpAndSettle();

        await tester.tap(createButton());
        await tester.pumpAndSettle();
        await tester.tap(find.text(l10n.listTypeVideoList));
        await tester.pumpAndSettle();

        expect(find.byType(ListInfoForm), findsOneWidget);
        expect(pushedRoute, isEmpty);
      });

      testWidgets('people list opens the create page', (tester) async {
        await tester.pumpWidget(buildSubject());
        await tester.pumpAndSettle();

        await tester.tap(createButton());
        await tester.pumpAndSettle();
        await tester.tap(find.text(l10n.listTypePeopleList));
        await tester.pumpAndSettle();

        expect(pushedRoute, CreatePeopleListPage.path);
        expect(find.byType(ListInfoForm), findsNothing);
      });

      testWidgets('without people lists it opens the video sheet directly', (
        tester,
      ) async {
        await tester.binding.setSurfaceSize(const Size(800, 1200));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        when(() => peopleBloc.state).thenReturn(const PeopleListsState());
        await tester.pumpWidget(buildSubject());
        await tester.pumpAndSettle();

        await tester.tap(createButton());
        await tester.pumpAndSettle();

        expect(find.text(l10n.listTypeSheetTitle), findsNothing);
        expect(find.byType(ListInfoForm), findsOneWidget);
      });

      testWidgets('video recovery skips straight to the people page', (
        tester,
      ) async {
        mockListService.recoveryNeedsRepair = true;
        await tester.pumpWidget(buildSubject());
        await tester.pumpAndSettle();
        expect(find.text(l10n.listRecoveryReadOnly), findsOneWidget);

        await tester.tap(createButton());
        await tester.pumpAndSettle();

        expect(find.text(l10n.listTypeSheetTitle), findsNothing);
        expect(pushedRoute, CreatePeopleListPage.path);
        expect(find.byType(ListInfoForm), findsNothing);
      });

      testWidgets('video recovery without people lists disables creation', (
        tester,
      ) async {
        mockListService.recoveryNeedsRepair = true;
        when(() => peopleBloc.state).thenReturn(const PeopleListsState());
        await tester.pumpWidget(buildSubject());
        await tester.pumpAndSettle();

        expect(tester.widget<DivineButton>(createButton()).onPressed, isNull);
      });

      testWidgets('refreshes the recovery notice after service changes', (
        tester,
      ) async {
        await tester.pumpWidget(buildSubject());
        await tester.pumpAndSettle();
        final container = ProviderScope.containerOf(
          tester.element(find.byType(ProfileListsGrid)),
        );
        mockListService.recoveryNeedsRepair = true;
        container.invalidate(curatedListsStateProvider);
        await tester.pumpAndSettle();
        expect(find.text(l10n.listRecoveryReadOnly), findsOneWidget);

        mockListService.recoveryNeedsRepair = false;
        container.invalidate(curatedListsStateProvider);
        await tester.pumpAndSettle();
        expect(find.text(l10n.listRecoveryReadOnly), findsNothing);

        await tester.tap(createButton());
        await tester.pumpAndSettle();
        expect(find.text(l10n.listTypeVideoList), findsOneWidget);
      });
    });

    group('navigation', () {
      testWidgets('opens the list detail when a video card is tapped', (
        tester,
      ) async {
        when(() => mockListService.myLists).thenReturn([_videoList('skate')]);

        await tester.pumpWidget(buildSubject());
        await tester.pumpAndSettle();

        await tester.tap(find.text('Video skate'));
        await tester.pumpAndSettle();

        expect(pushedRoute, equals('/list/skate'));
        expect(
          pushedExtra,
          isA<CuratedListRouteExtra>().having(
            (extra) => extra.listName,
            'listName',
            'Video skate',
          ),
        );
      });

      testWidgets('video recovery still opens owned video lists', (
        tester,
      ) async {
        mockListService.recoveryNeedsRepair = true;
        when(() => mockListService.myLists).thenReturn([_videoList('skate')]);
        await tester.pumpWidget(buildSubject());
        await tester.pumpAndSettle();

        await tester.tap(find.text('Video skate'));
        await tester.pumpAndSettle();
        expect(pushedRoute, '/list/skate');
      });

      testWidgets('opens the members view when a people card is tapped', (
        tester,
      ) async {
        when(
          () => peopleBloc.state,
        ).thenReturn(readyPeople([_peopleList('crew')]));

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
