// ABOUTME: Tests for the Explore Lists discovery gallery view: two
// ABOUTME: independent columns, per-column loading/error, empty state,
// ABOUTME: and card navigation.

import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:curated_list_repository/curated_list_repository.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/features/lists_discovery/cubit/lists_discovery_cubit.dart';
import 'package:openvine/features/feature_flags/models/feature_flag.dart';
import 'package:openvine/features/feature_flags/providers/feature_flag_providers.dart';
import 'package:openvine/features/people_lists/view/create_people_list_page.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/services/curated_list_service.dart';
import 'package:openvine/widgets/add_to_list_dialog.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/router/routes/route_extras.dart';
import 'package:openvine/screens/explore/tabs/explore_lists_tab.dart';
import 'package:openvine/widgets/divine_list_thumbnail.dart';
import 'package:people_lists_repository/people_lists_repository.dart';

import '../../../helpers/go_router.dart';
import '../../../helpers/test_provider_overrides.dart';

class _MockListsDiscoveryCubit extends MockCubit<ListsDiscoveryState>
    implements ListsDiscoveryCubit {}

class _MockCuratedListRepository extends Mock
    implements CuratedListRepository {}

class _MockPeopleListsRepository extends Mock
    implements PeopleListsRepository {}

Completer<List<CuratedList>>? _initialLoad;
Object? _initializationError;

class _FakeCuratedListsState extends CuratedListsState {
  @override
  CuratedListService? get service => null;

  @override
  Future<List<CuratedList>> build() async {
    if (_initializationError case final error?) throw error;
    return _initialLoad == null ? const [] : await _initialLoad!.future;
  }
}

final String _author = 'a' * 64;

CuratedList _videoList(String id) => CuratedList(
  id: id,
  name: 'Video $id',
  pubkey: _author,
  videoEventIds: const ['v1'],
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);

PeopleListSearchResult _peopleList(String id) => PeopleListSearchResult(
  ownerPubkey: _author,
  list: UserList(
    id: id,
    name: 'People $id',
    pubkeys: [_author],
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
  ),
);

void main() {
  group(ExploreListsTab, () {
    late String pushedRoute;

    setUp(() {
      _initialLoad = null;
      _initializationError = null;
      pushedRoute = '';
    });

    Widget buildPage({bool peopleEnabled = true}) => testProviderScope(
      additionalOverrides: [
        curatedListsStateProvider.overrideWith(_FakeCuratedListsState.new),
        curatedListRepositoryProvider.overrideWithValue(
          _MockCuratedListRepository(),
        ),
        peopleListsRepositoryProvider.overrideWithValue(
          _MockPeopleListsRepository(),
        ),
        isFeatureEnabledProvider(FeatureFlag.curatedLists)
            .overrideWithValue(peopleEnabled),
      ],
      child: MaterialApp.router(
        localizationsDelegates: appLocalizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        routerConfig: GoRouter(
          routes: [
            GoRoute(
              path: '/',
              builder: (_, _) => const Scaffold(body: ExploreListsTab()),
            ),
            GoRoute(
              path: CreatePeopleListPage.path,
              builder: (_, _) {
                pushedRoute = CreatePeopleListPage.path;
                return const Scaffold(body: Text('create people'));
              },
            ),
          ],
        ),
      ),
    );

    for (final enabled in [true, false]) {
      testWidgets('empty lists offers explicit creation with master=$enabled', (
        tester,
      ) async {
        await tester.pumpWidget(buildPage(peopleEnabled: enabled));
        await tester.pump();
        await tester.pump();
        expect(find.text('New video list'), findsOneWidget);
        expect(
          find.text('New people list'),
          enabled ? findsOneWidget : findsNothing,
        );
        expect(tester.takeException(), isNull);
      });
    }

    for (final failure in [false, true]) {
      testWidgets(
        'people creation remains reachable during initialization failure=$failure',
        (tester) async {
          if (failure) {
            _initializationError = StateError('initialization failed');
          } else {
            _initialLoad = Completer<List<CuratedList>>();
            addTearDown(() {
              if (!_initialLoad!.isCompleted) _initialLoad!.complete([]);
            });
          }
          await tester.pumpWidget(buildPage());
          await tester.pump();
          await tester.pump();
          expect(find.text('New video list'), findsOneWidget);
          expect(find.text('New people list'), findsOneWidget);
          await tester.tap(find.text('New people list'));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 200));
          expect(pushedRoute, CreatePeopleListPage.path);
          expect(tester.takeException(), isNull);
        },
      );
      testWidgets(
        'video creation keeps its dialog during initialization failure=$failure',
        (tester) async {
          if (failure)
            _initializationError = StateError('initialization failed');
          await tester.pumpWidget(buildPage());
          await tester.pump();
          await tester.pump();
          await tester.tap(find.text('New video list'));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 200));
          expect(find.byType(CreateListDialog), findsOneWidget);
          expect(tester.takeException(), isNull);
        },
      );
    }

    testWidgets('drops the status-bar inset above the first creation control', (
      tester,
    ) async {
      tester.view.padding = const FakeViewPadding(top: 120);
      addTearDown(tester.view.resetPadding);
      await tester.pumpWidget(buildPage());
      await tester.pump();
      final scroll = tester.widget<SingleChildScrollView>(
        find.byKey(const Key('lists-tab-content')),
      );
      expect(scroll.padding, const EdgeInsets.fromLTRB(16, 16, 16, 24));
      expect(tester.getTopLeft(find.text('New people list')).dy, lessThan(40));
      expect(tester.takeException(), isNull);
    });
  });

  group(ExploreListsView, () {
    late _MockListsDiscoveryCubit cubit;
    final l10n = lookupAppLocalizations(const Locale('en'));

    setUp(() {
      cubit = _MockListsDiscoveryCubit();
    });

    Widget buildSubject({MockGoRouter? goRouter}) {
      const view = ExploreListsView();
      return ProviderScope(
        overrides: [...getStandardTestOverrides()],
        child: MaterialApp(
          localizationsDelegates: appLocalizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: BlocProvider<ListsDiscoveryCubit>.value(
              value: cubit,
              child: goRouter == null
                  ? view
                  : MockGoRouterProvider(goRouter: goRouter, child: view),
            ),
          ),
        ),
      );
    }

    testWidgets('renders both columns from state', (tester) async {
      whenListen(
        cubit,
        const Stream<ListsDiscoveryState>.empty(),
        initialState: ListsDiscoveryState(
          videoStatus: ListsDiscoveryColumnStatus.success,
          peopleStatus: ListsDiscoveryColumnStatus.success,
          videoLists: [_videoList('skate')],
          peopleLists: [_peopleList('crew')],
        ),
      );

      await tester.pumpWidget(buildSubject());
      await tester.pump();

      expect(find.byType(DivineListThumbnail), findsNWidgets(2));
      expect(find.text('Video skate'), findsOneWidget);
      expect(find.text('People crew'), findsOneWidget);
    });

    testWidgets('video and people cards align to equal heights', (
      tester,
    ) async {
      // Both card types share the media aspect ratio and the fixed
      // two-line footer, so equal-width columns read as rows — even when
      // one list has a description and the other does not.
      whenListen(
        cubit,
        const Stream<ListsDiscoveryState>.empty(),
        initialState: ListsDiscoveryState(
          videoStatus: ListsDiscoveryColumnStatus.success,
          peopleStatus: ListsDiscoveryColumnStatus.success,
          videoLists: [
            CuratedList(
              id: 'skate',
              name: 'Video \u{1F51D} skate',
              description:
                  'A description long enough to wrap onto a second line '
                  'and then keep going past it for the ellipsis.',
              pubkey: _author,
              videoEventIds: const ['v1'],
              createdAt: DateTime(2026),
              updatedAt: DateTime(2026),
            ),
          ],
          peopleLists: [_peopleList('crew')],
        ),
      );

      await tester.pumpWidget(buildSubject());
      await tester.pump();

      final cards = find.byType(DivineListThumbnail);
      expect(cards, findsNWidgets(2));
      final videoSize = tester.getSize(cards.at(0));
      final peopleSize = tester.getSize(cards.at(1));
      expect(videoSize.width, peopleSize.width);
      expect(videoSize.height, peopleSize.height);
    });

    testWidgets('tells the cards while their thumbnails are still resolving', (
      tester,
    ) async {
      whenListen(
        cubit,
        const Stream<ListsDiscoveryState>.empty(),
        initialState: ListsDiscoveryState(
          videoStatus: ListsDiscoveryColumnStatus.success,
          peopleStatus: ListsDiscoveryColumnStatus.success,
          videoLists: [_videoList('skate')],
          videoThumbnailsPending: true,
        ),
      );

      await tester.pumpWidget(buildSubject());
      await tester.pump();

      final card = tester.widget<DivineListThumbnail>(
        find.byType(DivineListThumbnail),
      );
      expect(card.thumbnailsPending, isTrue);
    });

    testWidgets('keeps one column alive while the other loads', (
      tester,
    ) async {
      whenListen(
        cubit,
        const Stream<ListsDiscoveryState>.empty(),
        initialState: ListsDiscoveryState(
          videoStatus: ListsDiscoveryColumnStatus.success,
          peopleStatus: ListsDiscoveryColumnStatus.loading,
          videoLists: [_videoList('skate')],
        ),
      );

      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(buildSubject());
      await tester.pump();

      expect(find.byType(DivineListThumbnail), findsOneWidget);
      // The loading column is card silhouettes, announced once, not a
      // spinner — and people-shaped: no fan slots, so no positioned
      // children inside the silhouettes.
      expect(find.byType(DivineListThumbnailSkeleton), findsNWidgets(4));
      expect(
        find.descendant(
          of: find.byType(DivineListThumbnailSkeleton),
          matching: find.byType(Positioned),
        ),
        findsNothing,
      );
      final l10n = lookupAppLocalizations(const Locale('en'));
      expect(
        find.bySemanticsLabel(l10n.listsDiscoveryLoadingLabel),
        findsOneWidget,
      );
      semantics.dispose();
    });

    testWidgets('shows a quiet error line for a failed empty column', (
      tester,
    ) async {
      whenListen(
        cubit,
        const Stream<ListsDiscoveryState>.empty(),
        initialState: ListsDiscoveryState(
          videoStatus: ListsDiscoveryColumnStatus.success,
          peopleStatus: ListsDiscoveryColumnStatus.failure,
          videoLists: [_videoList('skate')],
        ),
      );

      await tester.pumpWidget(buildSubject());
      await tester.pump();

      expect(find.text(l10n.exploreErrorLoadingLists), findsOneWidget);
      expect(find.byType(DivineListThumbnail), findsOneWidget);
    });

    testWidgets('shows the empty message when both columns finish empty', (
      tester,
    ) async {
      whenListen(
        cubit,
        const Stream<ListsDiscoveryState>.empty(),
        initialState: const ListsDiscoveryState(
          videoStatus: ListsDiscoveryColumnStatus.success,
          peopleStatus: ListsDiscoveryColumnStatus.success,
        ),
      );

      await tester.pumpWidget(buildSubject());
      await tester.pump();

      expect(find.text(l10n.listsDiscoveryEmpty), findsOneWidget);
      expect(find.byType(DivineListThumbnail), findsNothing);
    });

    testWidgets('video card navigates to the list detail route', (
      tester,
    ) async {
      final goRouter = MockGoRouter();
      when(
        () => goRouter.push<void>(any(), extra: any(named: 'extra')),
      ).thenAnswer((_) async {});
      whenListen(
        cubit,
        const Stream<ListsDiscoveryState>.empty(),
        initialState: ListsDiscoveryState(
          videoStatus: ListsDiscoveryColumnStatus.success,
          peopleStatus: ListsDiscoveryColumnStatus.success,
          videoLists: [_videoList('skate')],
        ),
      );

      await tester.pumpWidget(buildSubject(goRouter: goRouter));
      await tester.pump();

      await tester.tap(find.text('Video skate'));

      final extra =
          verify(
                () => goRouter.push<void>(
                  '/list/skate',
                  extra: captureAny(named: 'extra'),
                ),
              ).captured.single
              as CuratedListRouteExtra;
      expect(extra.listName, equals('Video skate'));
      expect(extra.authorPubkey, equals(_videoList('skate').pubkey));
    });

    testWidgets('people card navigates with the owner query param', (
      tester,
    ) async {
      final goRouter = MockGoRouter();
      when(() => goRouter.push<void>(any())).thenAnswer((_) async {});
      whenListen(
        cubit,
        const Stream<ListsDiscoveryState>.empty(),
        initialState: ListsDiscoveryState(
          videoStatus: ListsDiscoveryColumnStatus.success,
          peopleStatus: ListsDiscoveryColumnStatus.success,
          peopleLists: [_peopleList('crew')],
        ),
      );

      await tester.pumpWidget(buildSubject(goRouter: goRouter));
      await tester.pump();

      await tester.tap(find.text('People crew'));

      verify(
        () => goRouter.push<void>('/people-lists/crew?owner=$_author'),
      ).called(1);
    });
  });
}
