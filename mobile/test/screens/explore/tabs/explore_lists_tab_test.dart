// ABOUTME: Tests for the Explore Lists discovery gallery view: two
// ABOUTME: independent columns, per-column loading/error, empty state,
// ABOUTME: and card navigation.

import 'package:bloc_test/bloc_test.dart';
import 'package:curated_list_repository/curated_list_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/constants/semantic_ids.dart';
import 'package:openvine/features/feature_flags/models/feature_flag.dart';
import 'package:openvine/features/feature_flags/providers/feature_flag_providers.dart';
import 'package:openvine/features/lists_discovery/cubit/lists_discovery_cubit.dart';
import 'package:openvine/features/people_lists/view/create_people_list_page.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/router/routes/route_extras.dart';
import 'package:openvine/screens/explore/tabs/explore_lists_tab.dart';
import 'package:openvine/services/curated_list_service.dart';
import 'package:openvine/widgets/add_to_list_dialog.dart';
import 'package:openvine/widgets/divine_list_thumbnail.dart';
import 'package:people_lists_repository/people_lists_repository.dart';

import 'dart:async';

import '../../../helpers/go_router.dart';
import '../../../helpers/test_provider_overrides.dart';

class _MockListsDiscoveryCubit extends MockCubit<ListsDiscoveryState>
    implements ListsDiscoveryCubit {}

class _MockCuratedListService extends Mock implements CuratedListService {}

class _MockCuratedListRepository extends Mock
    implements CuratedListRepository {}

class _MockPeopleListsRepository extends Mock
    implements PeopleListsRepository {}

class _TestCuratedListsState extends CuratedListsState {
  _TestCuratedListsState(this._service);
  final CuratedListService _service;

  @override
  CuratedListService get service => _service;

  @override
  Future<List<CuratedList>> build() async => const [];
}

class _GalleryPeopleEnabled extends Notifier<bool> {
  @override
  bool build() => true;
  void setEnabled(bool enabled) => state = enabled;
}

final _galleryPeopleEnabledProvider =
    NotifierProvider<_GalleryPeopleEnabled, bool>(_GalleryPeopleEnabled.new);

class _RecoveringCuratedListsState extends _TestCuratedListsState {
  _RecoveringCuratedListsState(super._service, this.shouldFail);
  final bool Function() shouldFail;

  @override
  Future<List<CuratedList>> build() async {
    if (shouldFail()) throw Exception('saved-list recovery unavailable');
    return const [];
  }
}

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
  group('ExploreListsTab preserved creation controls', () {
    late String pushedRoute;

    setUp(() {
      _initialLoad = null;
      _initializationError = null;
      pushedRoute = '';
    });

    Widget buildPage({bool peopleEnabled = true}) {
      final people = _MockPeopleListsRepository();
      when(
        () => people.discoverPublicLists(
          limit: any(named: 'limit'),
          excludeAuthor: any(named: 'excludeAuthor'),
        ),
      ).thenAnswer((_) async => const []);
      return testProviderScope(
        additionalOverrides: [
          curatedListsStateProvider.overrideWith(_FakeCuratedListsState.new),
          curatedListRepositoryProvider.overrideWithValue(
            _MockCuratedListRepository(),
          ),
          peopleListsRepositoryProvider.overrideWithValue(people),
          listsDiscoveryBlockFilterProvider.overrideWithValue((_) => false),
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
    }

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

  group(ExploreListsTab, () {
    for (final master in [false, true]) {
      for (final profileFeatures in [false, true]) {
        testWidgets('master $master and profile features $profileFeatures '
            'gate only people discovery', (tester) async {
          final service = _MockCuratedListService();
          final videos = _MockCuratedListRepository();
          final people = _MockPeopleListsRepository();
          when(
            () =>
                service.streamPublicListsFromRelays(limit: any(named: 'limit')),
          ).thenAnswer((_) => Stream.value([_videoList('skate')]));
          when(
            () => videos.resolveListThumbnails(
              any(),
              maxThumbnails: any(named: 'maxThumbnails'),
            ),
          ).thenAnswer(
            (invocation) async =>
                invocation.positionalArguments.first as List<CuratedList>,
          );
          when(
            () => people.discoverPublicLists(
              limit: any(named: 'limit'),
              excludeAuthor: any(named: 'excludeAuthor'),
            ),
          ).thenAnswer((_) async => [_peopleList('crew')]);
          await tester.pumpWidget(
            ProviderScope(
              overrides: [
                ...getStandardTestOverrides(),
                curatedListsStateProvider.overrideWith(
                  () => _TestCuratedListsState(service),
                ),
                curatedListRepositoryProvider.overrideWithValue(videos),
                peopleListsRepositoryProvider.overrideWithValue(people),
                listsDiscoveryBlockFilterProvider.overrideWithValue(
                  (_) => false,
                ),
                isFeatureEnabledProvider(FeatureFlag.curatedLists)
                    .overrideWith((_) => master),
                isFeatureEnabledProvider(FeatureFlag.profileListFeatures)
                    .overrideWith((_) => profileFeatures),
              ],
              child: const MaterialApp(
                localizationsDelegates: appLocalizationsDelegates,
                supportedLocales: AppLocalizations.supportedLocales,
                home: Scaffold(body: ExploreListsTab()),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(find.text('Video skate'), findsOneWidget);
          expect(
            find.text('People crew'),
            master ? findsOneWidget : findsNothing,
          );
          final view = tester.element(find.byType(ExploreListsView));
          expect(
            view.read<ListsDiscoveryCubit>().state.peopleListsEnabled,
            master,
          );
          if (master) {
            verify(
              () => people.discoverPublicLists(
                limit: any(named: 'limit'),
                excludeAuthor: any(named: 'excludeAuthor'),
              ),
            ).called(1);
          } else {
            verifyNever(
              () => people.discoverPublicLists(
                limit: any(named: 'limit'),
                excludeAuthor: any(named: 'excludeAuthor'),
              ),
            );
            expect(find.byType(DivineListThumbnailSkeleton), findsNothing);
          }
        });
      }
    }

    testWidgets('runtime master change retires pending people discovery', (
      tester,
    ) async {
      final service = _MockCuratedListService();
      final people = _MockPeopleListsRepository();
      final pending = Completer<List<PeopleListSearchResult>>();
      when(
        () => service.streamPublicListsFromRelays(limit: any(named: 'limit')),
      ).thenAnswer((_) => const Stream.empty());
      when(
        () => people.discoverPublicLists(
          limit: any(named: 'limit'),
          excludeAuthor: any(named: 'excludeAuthor'),
        ),
      ).thenAnswer((_) => pending.future);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ...getStandardTestOverrides(),
            curatedListsStateProvider.overrideWith(
              () => _TestCuratedListsState(service),
            ),
            curatedListRepositoryProvider.overrideWithValue(
              _MockCuratedListRepository(),
            ),
            peopleListsRepositoryProvider.overrideWithValue(people),
            listsDiscoveryBlockFilterProvider.overrideWithValue((_) => false),
            isFeatureEnabledProvider(FeatureFlag.curatedLists).overrideWith(
              (ref) => ref.watch(_galleryPeopleEnabledProvider),
            ),
          ],
          child: const MaterialApp(
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(body: ExploreListsTab()),
          ),
        ),
      );
      await tester.pump();
      final element = tester.element(find.byType(ExploreListsView));
      final oldCubit = element.read<ListsDiscoveryCubit>();
      final container = ProviderScope.containerOf(element);
      container.read(_galleryPeopleEnabledProvider.notifier).setEnabled(false);
      await tester.pumpAndSettle();
      expect(oldCubit.isClosed, isTrue);
      pending.complete([_peopleList('late')]);
      await tester.pumpAndSettle();
      expect(find.text('People late'), findsNothing);
      expect(find.byType(DivineListThumbnailSkeleton), findsNothing);
    });

    testWidgets(
      'live block changes retire hydration and refresh both sources',
      (tester) async {
        final service = _MockCuratedListService();
        final videos = _MockCuratedListRepository();
        final people = _MockPeopleListsRepository();
        var blocked = false;
        final pending = Completer<List<CuratedList>>();
        when(
          () => service.streamPublicListsFromRelays(limit: any(named: 'limit')),
        ).thenAnswer((_) => Stream.value([_videoList('skate')]));
        when(
          () => videos.resolveListThumbnails(
            any(),
            maxThumbnails: any(named: 'maxThumbnails'),
          ),
        ).thenAnswer((_) => pending.future);
        when(
          () => people.discoverPublicLists(
            limit: any(named: 'limit'),
            excludeAuthor: any(named: 'excludeAuthor'),
          ),
        ).thenAnswer((_) async => [_peopleList('crew')]);
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              ...getStandardTestOverrides(),
              curatedListsStateProvider.overrideWith(
                () => _TestCuratedListsState(service),
              ),
              curatedListRepositoryProvider.overrideWithValue(videos),
              peopleListsRepositoryProvider.overrideWithValue(people),
              listsDiscoveryBlockFilterProvider.overrideWithValue(
                (author) => blocked && author == _author,
              ),
            ],
            child: const MaterialApp(
              localizationsDelegates: appLocalizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Scaffold(body: ExploreListsTab()),
            ),
          ),
        );
        await tester.pump();
        await tester.pump();
        final element = tester.element(find.byType(ExploreListsView));
        final oldCubit = element.read<ListsDiscoveryCubit>();
        blocked = true;
        ProviderScope.containerOf(element)
            .read(blocklistVersionProvider.notifier)
            .increment();
        await tester.pumpAndSettle();
        expect(oldCubit.isClosed, isTrue);
        expect(find.text('Video skate'), findsNothing);
        expect(find.text('People crew'), findsNothing);
        pending.complete([_videoList('skate')]);
        await tester.pumpAndSettle();
        expect(find.text('Video skate'), findsNothing);
        verify(
          () => people.discoverPublicLists(
            limit: any(named: 'limit'),
            excludeAuthor: any(named: 'excludeAuthor'),
          ),
        ).called(2);
        verify(
          () => service.streamPublicListsFromRelays(limit: any(named: 'limit')),
        ).called(2);
      },
    );

    testWidgets(
      'saved video recovery shows retry while people remain available',
      (tester) async {
        final service = _MockCuratedListService();
        final people = _MockPeopleListsRepository();
        var attempts = 0;
        when(
          () => service.streamPublicListsFromRelays(limit: any(named: 'limit')),
        ).thenAnswer((_) => const Stream.empty());
        when(
          () => people.discoverPublicLists(
            limit: any(named: 'limit'),
            excludeAuthor: any(named: 'excludeAuthor'),
          ),
        ).thenAnswer((_) async => [_peopleList('crew')]);
        await tester.pumpWidget(
          ProviderScope(
            retry: (_, _) => null,
            overrides: [
              ...getStandardTestOverrides(),
              curatedListsStateProvider.overrideWith(
                () => _RecoveringCuratedListsState(
                  service,
                  () => attempts++ == 0,
                ),
              ),
              curatedListRepositoryProvider.overrideWithValue(
                _MockCuratedListRepository(),
              ),
              peopleListsRepositoryProvider.overrideWithValue(people),
              listsDiscoveryBlockFilterProvider.overrideWithValue((_) => false),
            ],
            child: const MaterialApp(
              localizationsDelegates: appLocalizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Scaffold(body: ExploreListsTab()),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Error loading lists'), findsOneWidget);
        expect(find.text('People crew'), findsOneWidget);
        await tester.tap(find.text('Try again'));
        await tester.pumpAndSettle();
        expect(find.text('Error loading lists'), findsNothing);
        expect(find.text('People crew'), findsOneWidget);
        expect(attempts, 2);
      },
    );

    testWidgets('tab navigation preserves discovery until explicit refresh', (
      tester,
    ) async {
      final service = _MockCuratedListService();
      final peopleRepository = _MockPeopleListsRepository();
      when(
        () => service.streamPublicListsFromRelays(limit: any(named: 'limit')),
      ).thenAnswer((_) => const Stream.empty());
      when(
        () => peopleRepository.discoverPublicLists(
          limit: any(named: 'limit'),
          excludeAuthor: any(named: 'excludeAuthor'),
        ),
      ).thenAnswer((_) async => const []);
      late TabController controller;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ...getStandardTestOverrides(),
            curatedListsStateProvider.overrideWith(
              () => _TestCuratedListsState(service),
            ),
            curatedListRepositoryProvider.overrideWithValue(
              _MockCuratedListRepository(),
            ),
            peopleListsRepositoryProvider.overrideWithValue(peopleRepository),
          ],
          child: MaterialApp(
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: DefaultTabController(
              length: 3,
              child: Builder(
                builder: (context) {
                  controller = DefaultTabController.of(context);
                  return const Scaffold(
                    body: TabBarView(
                      children: [
                        ExploreListsTab(),
                        SizedBox(),
                        SizedBox(),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final initial = tester
          .element(find.byType(ExploreListsView))
          .read<ListsDiscoveryCubit>();
      controller.animateTo(2);
      await tester.pumpAndSettle();
      expect(initial.isClosed, isFalse);
      controller.animateTo(0);
      await tester.pumpAndSettle();
      final returned = tester
          .element(find.byType(ExploreListsView))
          .read<ListsDiscoveryCubit>();
      expect(identical(initial, returned), isTrue);
      verify(
        () => service.streamPublicListsFromRelays(limit: any(named: 'limit')),
      ).called(1);
      verify(
        () => peopleRepository.discoverPublicLists(
          limit: any(named: 'limit'),
          excludeAuthor: any(named: 'excludeAuthor'),
        ),
      ).called(1);
      await tester.runAsync(returned.load);
      await tester.pumpAndSettle();
      verify(
        () => service.streamPublicListsFromRelays(limit: any(named: 'limit')),
      ).called(1);
      verify(
        () => peopleRepository.discoverPublicLists(
          limit: any(named: 'limit'),
          excludeAuthor: any(named: 'excludeAuthor'),
        ),
      ).called(1);
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

    testWidgets('anchors each video card for the screenshot run', (
      tester,
    ) async {
      whenListen(
        cubit,
        const Stream<ListsDiscoveryState>.empty(),
        initialState: ListsDiscoveryState(
          videoStatus: ListsDiscoveryColumnStatus.success,
          peopleStatus: ListsDiscoveryColumnStatus.success,
          videoLists: [_videoList('skate'), _videoList('surf')],
        ),
      );
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(buildSubject());
      await tester.pump();
      expect(
        find.bySemanticsIdentifier(SemanticIds.listCard(0)),
        findsOneWidget,
      );
      expect(
        find.bySemanticsIdentifier(SemanticIds.listCard(1)),
        findsOneWidget,
      );
      expect(find.bySemanticsIdentifier(SemanticIds.listCard(2)), findsNothing);
      semantics.dispose();
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
      when(() => goRouter.push<void>(any(), extra: any(named: 'extra')))
          .thenAnswer((_) async {});
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
                  '/list/$_author/skate',
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
      when(() => goRouter.push<void>(any(), extra: any(named: 'extra')))
          .thenAnswer((_) async {});
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
