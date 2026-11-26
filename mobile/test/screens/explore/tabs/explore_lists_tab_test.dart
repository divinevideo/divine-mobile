// ABOUTME: Tests for the Explore Lists discovery gallery view: two
// ABOUTME: independent columns, per-column loading/error, empty state,
// ABOUTME: and card navigation.

import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:curated_list_repository/curated_list_repository.dart';
import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/constants/semantic_ids.dart';
import 'package:openvine/features/lists_discovery/cubit/lists_discovery_cubit.dart';
import 'package:openvine/features/people_lists/view/create_people_list_page.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/overlay_visibility_provider.dart';
import 'package:openvine/router/routes/route_extras.dart';
import 'package:openvine/screens/explore/tabs/explore_lists_tab.dart';
import 'package:openvine/services/age_verification_service.dart';
import 'package:openvine/services/curated_list_service.dart';
import 'package:openvine/widgets/divine_list_thumbnail.dart';
import 'package:openvine/widgets/list_info_sheet/list_info_form.dart';
import 'package:people_lists_repository/people_lists_repository.dart';
import 'package:riverpod/misc.dart' show Override;
import 'package:shared_preferences/shared_preferences.dart';

import '../../../helpers/go_router.dart';
import '../../../helpers/large_screen_layout.dart';
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

CuratedListSearchResult _result(String id) =>
    CuratedListSearchResult(_videoList(id));

/// Answers [repository]'s video-list discovery with [next] on each call.
void _answerDiscovery(
  _MockCuratedListRepository repository,
  Stream<List<CuratedListSearchResult>> Function() next,
) {
  when(
    () => repository.discoverLists(
      limit: any(named: 'limit'),
      excludeAuthor: any(named: 'excludeAuthor'),
      maxThumbnails: any(named: 'maxThumbnails'),
    ),
  ).thenAnswer((_) => next());
}

/// A curated list repository whose discovery finds nothing.
_MockCuratedListRepository _emptyDiscovery() {
  final repository = _MockCuratedListRepository();
  _answerDiscovery(repository, () => Stream.value(const []));
  return repository;
}

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

// Gallery lifecycle cases inject repositories that own their preview policy.
// Keep that policy stable unless the case explicitly changes it.
List<Override> _galleryTestOverrides() => [
  ...getStandardTestOverrides(),
  curatedListThumbnailFilterProvider.overrideWithValue((_) => false),
];

void main() {
  group('ExploreListsTab preserved creation controls', () {
    late String pushedRoute;

    setUp(() {
      _initialLoad = null;
      _initializationError = null;
      pushedRoute = '';
    });

    Widget buildPage() {
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

    testWidgets('empty lists offers video and people creation', (tester) async {
      await tester.pumpWidget(buildPage());
      await tester.pump();
      await tester.pump();
      expect(find.text('New video list'), findsOneWidget);
      expect(find.text('New people list'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

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
        'video creation keeps its approved sheet during initialization failure=$failure',
        (tester) async {
          if (failure) {
            _initializationError = StateError('initialization failed');
          }
          await tester.pumpWidget(buildPage());
          await tester.pump();
          await tester.pump();
          final container = ProviderScope.containerOf(
            tester.element(find.byType(ExploreListsTab)),
          );
          expect(container.read(overlayVisibilityProvider).isPageOpen, isFalse);
          await tester.tap(find.text('New video list'));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 200));
          expect(find.byType(ListInfoForm), findsOneWidget);
          expect(find.byType(VineBottomSheet), findsOneWidget);
          expect(find.byType(AlertDialog), findsNothing);
          expect(container.read(overlayVisibilityProvider).isPageOpen, isFalse);
          expect(
            container.read(overlayVisibilityProvider).isBottomSheetOpen,
            isTrue,
          );
          expect(
            container.read(overlayVisibilityProvider).hasVisibleOverlay,
            isTrue,
          );
          expect(
            container.read(overlayVisibilityProvider).shouldRetainPlayer,
            isTrue,
          );
          Navigator.of(tester.element(find.byType(ListInfoForm))).pop();
          // The gallery keeps shimmering while its service is unavailable.
          // Finish only the sheet transition instead of settling that loop.
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 200));
          expect(find.byType(ListInfoForm), findsNothing);
          expect(
            container.read(overlayVisibilityProvider).isBottomSheetOpen,
            isFalse,
          );
          expect(
            container.read(overlayVisibilityProvider).hasVisibleOverlay,
            isFalse,
          );
          expect(tester.takeException(), isNull);
        },
      );
    }

    testWidgets('closing video creation preserves another page pause owner', (
      tester,
    ) async {
      await tester.pumpWidget(buildPage());
      await tester.pump();
      await tester.pump();
      final container = ProviderScope.containerOf(
        tester.element(find.byType(ExploreListsTab)),
      );
      final notifier = container.read(overlayVisibilityProvider.notifier);
      final otherPageOwner = Object();
      notifier.setPageOpenForOwner(otherPageOwner, isOpen: true);
      await tester.tap(find.text('New video list'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      final whileOpen = container.read(overlayVisibilityProvider);
      expect(whileOpen.isPageOpen, isTrue);
      expect(whileOpen.isBottomSheetOpen, isTrue);
      expect(whileOpen.hasVisibleOverlay, isTrue);
      expect(whileOpen.shouldRetainPlayer, isFalse);
      Navigator.of(tester.element(find.byType(ListInfoForm))).pop();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      final afterClose = container.read(overlayVisibilityProvider);
      expect(afterClose.isBottomSheetOpen, isFalse);
      expect(afterClose.isPageOpen, isTrue);
      expect(afterClose.hasVisibleOverlay, isTrue);
      notifier.setPageOpenForOwner(otherPageOwner, isOpen: false);
      expect(
        container.read(overlayVisibilityProvider).hasVisibleOverlay,
        isFalse,
      );
      expect(tester.takeException(), isNull);
    });

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
    testWidgets('discovers video and people lists', (tester) async {
      final service = _MockCuratedListService();
      final videos = _MockCuratedListRepository();
      final people = _MockPeopleListsRepository();
      _answerDiscovery(videos, () => Stream.value([_result('skate')]));
      when(
        () => people.discoverPublicLists(
          limit: any(named: 'limit'),
          excludeAuthor: any(named: 'excludeAuthor'),
        ),
      ).thenAnswer((_) async => [_peopleList('crew')]);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ..._galleryTestOverrides(),
            curatedListsStateProvider.overrideWith(
              () => _TestCuratedListsState(service),
            ),
            curatedListRepositoryProvider.overrideWithValue(videos),
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
      expect(find.text('Video skate'), findsOneWidget);
      expect(find.text('People crew'), findsOneWidget);
      verify(
        () => people.discoverPublicLists(
          limit: any(named: 'limit'),
          excludeAuthor: any(named: 'excludeAuthor'),
        ),
      ).called(1);
    });

    for (final policy in ['content', 'adult verification', 'provenance']) {
      for (final initiallyPending in [false, true]) {
        testWidgets(
          '$policy change retires ${initiallyPending ? "pending" : "rendered"} video previews with stable repositories',
          (tester) async {
            SharedPreferences.setMockInitialValues({});
            final preferences = await SharedPreferences.getInstance();
            final age = AgeVerificationService(preferences: preferences);
            await age.initialize();
            final service = _MockCuratedListService();
            final videos = _MockCuratedListRepository();
            final people = _MockPeopleListsRepository();
            // Stays open: the first discovery still resolving thumbnails.
            final pending = StreamController<List<CuratedListSearchResult>>();
            // Not awaited: a stream nobody listened to never reports done.
            addTearDown(() => unawaited(pending.close()));
            var permitted = true;
            var requests = 0;
            final initialList = _videoList('policy-list').copyWith(
              videoEventIds: [_author],
              thumbnailUrls: const ['https://media.divine.video/allowed.jpg'],
            );
            _answerDiscovery(videos, () {
              requests++;
              if (initiallyPending && requests == 1) {
                pending.add([
                  CuratedListSearchResult(
                    initialList.copyWith(thumbnailUrls: const []),
                  ),
                ]);
                return pending.stream;
              }
              return Stream.value([
                CuratedListSearchResult(
                  initialList.copyWith(
                    thumbnailUrls: permitted ? initialList.thumbnailUrls : [],
                  ),
                ),
              ]);
            });
            when(
              () => people.discoverPublicLists(
                limit: any(named: 'limit'),
                excludeAuthor: any(named: 'excludeAuthor'),
              ),
            ).thenAnswer((_) async => const []);
            await tester.pumpWidget(
              ProviderScope(
                overrides: [
                  ...getStandardTestOverrides(),
                  ageVerificationServiceProvider.overrideWithValue(age),
                  curatedListsStateProvider.overrideWith(
                    () => _TestCuratedListsState(service),
                  ),
                  curatedListRepositoryProvider.overrideWithValue(videos),
                  peopleListsRepositoryProvider.overrideWithValue(people),
                  listsDiscoveryBlockFilterProvider.overrideWithValue(
                    (_) => false,
                  ),
                  curatedListThumbnailFilterProvider.overrideWith((ref) {
                    final version = switch (policy) {
                      'content' => ref.watch(contentFilterVersionProvider),
                      'adult verification' => ref.watch(
                        adultContentVerificationVersionProvider,
                      ),
                      _ => ref.watch(videoProvenanceFilterVersionProvider),
                    };
                    return (_) => version != 0;
                  }),
                ],
                child: const MaterialApp(
                  localizationsDelegates: appLocalizationsDelegates,
                  supportedLocales: AppLocalizations.supportedLocales,
                  home: Scaffold(body: ExploreListsTab()),
                ),
              ),
            );
            await tester.pump();
            await tester.runAsync(pumpEventQueue);
            await tester.pump();
            final view = tester.element(find.byType(ExploreListsView));
            final oldCubit = view.read<ListsDiscoveryCubit>();
            expect(oldCubit.isClosed, isFalse);
            expect(requests, 1);
            if (!initiallyPending) {
              expect(
                oldCubit.state.videoLists.single.list.thumbnailUrls,
                initialList.thumbnailUrls,
              );
            }
            final container = ProviderScope.containerOf(view);
            permitted = false;
            switch (policy) {
              case 'content':
                container
                    .read(contentFilterVersionProvider.notifier)
                    .increment();
              case 'adult verification':
                container
                    .read(adultContentVerificationVersionProvider.notifier)
                    .increment();
              default:
                container
                    .read(videoProvenanceFilterVersionProvider.notifier)
                    .increment();
            }
            await tester.pump();
            await tester.runAsync(pumpEventQueue);
            await tester.pump();
            expect(oldCubit.isClosed, isTrue);
            final freshCubit = tester
                .element(find.byType(ExploreListsView))
                .read<ListsDiscoveryCubit>();
            expect(freshCubit, isNot(same(oldCubit)));
            expect(
              freshCubit.state.videoLists.single.list.thumbnailUrls,
              isEmpty,
            );
            expect(find.text('Video policy-list'), findsOneWidget);
            expect(requests, 2);
            if (initiallyPending) {
              pending.add([CuratedListSearchResult(initialList)]);
              await tester.pump();
              await tester.runAsync(pumpEventQueue);
              await tester.pump();
              expect(
                freshCubit.state.videoLists.single.list.thumbnailUrls,
                isEmpty,
              );
            }
            expect(tester.takeException(), isNull);
            await tester.pumpWidget(const SizedBox.shrink());
            await tester.pump();
            await tester.runAsync(pumpEventQueue);
            await tester.pump();
            expect(freshCubit.isClosed, isTrue);
          },
        );
      }
    }

    testWidgets('block change retires pending people discovery', (
      tester,
    ) async {
      final service = _MockCuratedListService();
      final people = _MockPeopleListsRepository();
      final pending = Completer<List<PeopleListSearchResult>>();
      var blocked = false;
      var requests = 0;
      when(
        () => people.discoverPublicLists(
          limit: any(named: 'limit'),
          excludeAuthor: any(named: 'excludeAuthor'),
        ),
      ).thenAnswer((_) async => ++requests == 1 ? pending.future : []);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ..._galleryTestOverrides(),
            curatedListsStateProvider.overrideWith(
              () => _TestCuratedListsState(service),
            ),
            curatedListRepositoryProvider.overrideWithValue(
              _emptyDiscovery(),
            ),
            peopleListsRepositoryProvider.overrideWithValue(people),
            listsDiscoveryBlockFilterProvider.overrideWith((ref) {
              ref.watch(blocklistVersionProvider);
              return (_) => blocked;
            }),
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
      blocked = true;
      container.read(blocklistVersionProvider.notifier).increment();
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
        // The first discovery stays open, still resolving thumbnails.
        final pending = StreamController<List<CuratedListSearchResult>>();
        addTearDown(() => unawaited(pending.close()));
        var requests = 0;
        _answerDiscovery(videos, () {
          if (requests++ > 0) return Stream.value([_result('skate')]);
          pending.add([_result('skate')]);
          return pending.stream;
        });
        when(
          () => people.discoverPublicLists(
            limit: any(named: 'limit'),
            excludeAuthor: any(named: 'excludeAuthor'),
          ),
        ).thenAnswer((_) async => [_peopleList('crew')]);
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              ..._galleryTestOverrides(),
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
        pending.add([_result('skate')]);
        await tester.pumpAndSettle();
        expect(find.text('Video skate'), findsNothing);
        verify(
          () => people.discoverPublicLists(
            limit: any(named: 'limit'),
            excludeAuthor: any(named: 'excludeAuthor'),
          ),
        ).called(2);
        verify(
          () => videos.discoverLists(
            limit: any(named: 'limit'),
            excludeAuthor: any(named: 'excludeAuthor'),
            maxThumbnails: any(named: 'maxThumbnails'),
          ),
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
          () => people.discoverPublicLists(
            limit: any(named: 'limit'),
            excludeAuthor: any(named: 'excludeAuthor'),
          ),
        ).thenAnswer((_) async => [_peopleList('crew')]);
        await tester.pumpWidget(
          ProviderScope(
            retry: (_, _) => null,
            overrides: [
              ..._galleryTestOverrides(),
              curatedListsStateProvider.overrideWith(
                () => _RecoveringCuratedListsState(
                  service,
                  () => attempts++ == 0,
                ),
              ),
              curatedListRepositoryProvider.overrideWithValue(
                _emptyDiscovery(),
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
      final videos = _emptyDiscovery();
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
            ..._galleryTestOverrides(),
            curatedListsStateProvider.overrideWith(
              () => _TestCuratedListsState(service),
            ),
            curatedListRepositoryProvider.overrideWithValue(videos),
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
                      children: [ExploreListsTab(), SizedBox(), SizedBox()],
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
        () => videos.discoverLists(
          limit: any(named: 'limit'),
          excludeAuthor: any(named: 'excludeAuthor'),
          maxThumbnails: any(named: 'maxThumbnails'),
        ),
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
        () => videos.discoverLists(
          limit: any(named: 'limit'),
          excludeAuthor: any(named: 'excludeAuthor'),
          maxThumbnails: any(named: 'maxThumbnails'),
        ),
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
          videoLists: [_result('skate')],
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
          videoLists: [_result('skate'), _result('surf')],
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
            CuratedListSearchResult(
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
          videoLists: [_result('skate')],
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

    group('on a wide window', () {
      /// The gallery in a 1300 pt window: 1268 pt between the side padding,
      /// past the last breakpoint, so five columns with the large-screen
      /// layouts.
      Future<void> pumpWide(
        WidgetTester tester, {
        required bool largeScreenLayout,
        required ListsDiscoveryState state,
      }) async {
        whenListen(
          cubit,
          const Stream<ListsDiscoveryState>.empty(),
          initialState: state,
        );
        setTestWindowSize(tester, 1300);
        await tester.pumpWidget(
          largeScreenLayoutApp(
            enabled: largeScreenLayout,
            overrides: getStandardTestOverrides(),
            home: Scaffold(
              body: BlocProvider<ListsDiscoveryCubit>.value(
                value: cubit,
                child: const ExploreListsView(),
              ),
            ),
          ),
        );
        await tester.pump();
      }

      final loaded = ListsDiscoveryState(
        videoStatus: ListsDiscoveryColumnStatus.success,
        peopleStatus: ListsDiscoveryColumnStatus.success,
        videoLists: [
          _result('a'),
          _result('b'),
          _result('c'),
          _result('d'),
        ],
        peopleLists: [_peopleList('x'), _peopleList('y')],
      );

      Rect card(WidgetTester tester, String name) => tester.getRect(
        find.ancestor(
          of: find.text(name),
          matching: find.byType(DivineListThumbnail),
        ),
      );

      testWidgets('gives the video lists the odd column of five', (
        tester,
      ) async {
        await pumpWide(tester, largeScreenLayout: true, state: loaded);

        final firstRow = [
          for (final name in [
            'Video a',
            'Video b',
            'Video c',
            'People x',
            'People y',
          ])
            card(tester, name),
        ];
        // (1268 - 4 gaps of 16) / 5 columns, all equally wide.
        for (final rect in firstRow) {
          expect(rect.width, moreOrLessEquals(240.8));
          expect(rect.top, equals(firstRow.first.top));
        }
        for (var i = 1; i < firstRow.length; i++) {
          expect(firstRow[i].left, greaterThan(firstRow[i - 1].right));
        }
        // The fourth video list starts a second row under the first.
        final d = card(tester, 'Video d');
        expect(d.left, equals(firstRow.first.left));
        expect(d.top, greaterThan(firstRow.first.bottom));
      });

      testWidgets('fills every loading column with silhouettes', (
        tester,
      ) async {
        await pumpWide(
          tester,
          largeScreenLayout: true,
          state: const ListsDiscoveryState(
            videoStatus: ListsDiscoveryColumnStatus.loading,
            peopleStatus: ListsDiscoveryColumnStatus.loading,
          ),
        );

        // Four silhouettes in each of the five columns.
        expect(find.byType(DivineListThumbnailSkeleton), findsNWidgets(20));
      });

      testWidgets('keeps one video and one people column with the flag off', (
        tester,
      ) async {
        await pumpWide(tester, largeScreenLayout: false, state: loaded);

        final a = card(tester, 'Video a');
        final b = card(tester, 'Video b');
        final x = card(tester, 'People x');
        // (1268 - 16) / 2, as before the large-screen layouts.
        expect(a.width, moreOrLessEquals(626));
        expect(x.width, moreOrLessEquals(626));
        expect(x.top, equals(a.top));
        expect(b.left, equals(a.left));
        expect(b.top, greaterThan(a.bottom));
      });
    });

    testWidgets('keeps one column alive while the other loads', (tester) async {
      whenListen(
        cubit,
        const Stream<ListsDiscoveryState>.empty(),
        initialState: ListsDiscoveryState(
          videoStatus: ListsDiscoveryColumnStatus.success,
          peopleStatus: ListsDiscoveryColumnStatus.loading,
          videoLists: [_result('skate')],
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
          videoLists: [_result('skate')],
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
          videoLists: [_result('skate')],
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
      expect(extra.list?.id, equals('skate'));
      expect(extra.authorPubkey, equals(extra.list?.pubkey));
    });

    testWidgets(
      'a summary card counts the index videos and opens the list by its '
      'address',
      (tester) async {
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
            videoLists: [
              CuratedListSearchResult.summary(
                list: _videoList('skate').copyWith(videoEventIds: const []),
                itemCount: 12,
              ),
            ],
          ),
        );

        final semantics = tester.ensureSemantics();
        await tester.pumpWidget(buildSubject(goRouter: goRouter));
        await tester.pump();

        expect(
          find.bySemanticsLabel(
            l10n.listCardSemanticLabel(
              'Video skate',
              'public',
              l10n.listVideoCount(12),
            ),
          ),
          findsOneWidget,
        );
        semantics.dispose();
        await tester.tap(find.text('Video skate'));

        final extra =
            verify(
                  () => goRouter.push<void>(
                    '/list/$_author/skate',
                    extra: captureAny(named: 'extra'),
                  ),
                ).captured.single
                as CuratedListRouteExtra;
        expect(extra.videoIds, isNull);
        expect(extra.list, isNull);
      },
    );

    testWidgets('people card counts every member, not just the preview', (
      tester,
    ) async {
      whenListen(
        cubit,
        const Stream<ListsDiscoveryState>.empty(),
        initialState: ListsDiscoveryState(
          videoStatus: ListsDiscoveryColumnStatus.success,
          peopleStatus: ListsDiscoveryColumnStatus.success,
          peopleLists: [
            PeopleListSearchResult(
              ownerPubkey: _author,
              list: _peopleList('crew').list,
              memberCount: 17,
            ),
          ],
        ),
      );

      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(buildSubject());
      await tester.pump();

      expect(
        find.bySemanticsLabel(
          l10n.listCardSemanticLabel(
            'People crew',
            'public',
            l10n.listMemberCount(17),
          ),
        ),
        findsOneWidget,
      );
      semantics.dispose();
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

      verify(() => goRouter.push<void>('/people-lists/crew?owner=$_author'))
          .called(1);
    });
  });
}
