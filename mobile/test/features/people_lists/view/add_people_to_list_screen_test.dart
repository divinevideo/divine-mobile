// ABOUTME: Widget tests for AddPeopleToListScreen full-screen picker.
// ABOUTME: Covers candidate rendering, filtering, selection, disabled
// ABOUTME: already-member rows, and batch-add dispatch through the cubit.

import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:follow_repository/follow_repository.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/extensions/safe_pop_extension.dart';
import 'package:openvine/features/people_lists/bloc/add_people_to_list_cubit.dart';
import 'package:openvine/features/people_lists/bloc/add_people_to_list_state.dart';
import 'package:openvine/features/people_lists/bloc/people_lists_bloc.dart';
import 'package:openvine/features/people_lists/models/people_list_candidate.dart';
import 'package:openvine/features/people_lists/view/add_people_to_list_screen.dart';
import 'package:openvine/features/people_lists/view/widgets/person_pickable_row.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/nostr_client_provider.dart';
import 'package:openvine/providers/user_ranking_providers.dart';
import 'package:openvine/services/user_ranking/user_ranking_signals_loader.dart';
import 'package:profile_repository/profile_repository.dart';
import 'package:user_ranking/user_ranking.dart';

import '../../../helpers/go_router.dart';
import '../../../helpers/test_provider_overrides.dart';

class _MockPeopleListsBloc extends MockBloc<PeopleListsEvent, PeopleListsState>
    implements PeopleListsBloc {}

class _MockAddPeopleToListCubit extends MockCubit<AddPeopleToListState>
    implements AddPeopleToListCubit {}

class _MockRankingSignalsLoader extends Mock
    implements UserRankingSignalsLoader {}

class _MockProfileRepository extends Mock implements ProfileRepository {}

class _TestNostrSession extends NostrSession {
  @override
  NostrSessionReadiness build() =>
      const NostrSessionReadiness.identityKnown(pubkey: _ownerPubkey);
}

final _dependencyRevision = StateProvider<int>((ref) => 0);

class _MockFollowRepository extends Mock implements FollowRepository {}

// Full-length Nostr pubkeys — never truncate.
const String _ownerPubkey =
    'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
const String _candidateA =
    'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';
const String _candidateB =
    'cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc';
const String _candidateC =
    'dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd';

final DateTime _frozenNow = DateTime.utc(2026, 4, 20, 12);

UserList _buildList({
  required String id,
  required String name,
  List<String> pubkeys = const [],
  bool isEditable = true,
}) {
  return UserList(
    id: id,
    name: name,
    pubkeys: pubkeys,
    createdAt: _frozenNow,
    updatedAt: _frozenNow,
    isEditable: isEditable,
  );
}

PeopleListsState _stateWith({required List<UserList> lists}) {
  final reverseIndex = <String, Set<String>>{};
  for (final list in lists) {
    for (final pk in list.pubkeys) {
      (reverseIndex[pk] ??= <String>{}).add(list.id);
    }
  }
  return PeopleListsState(
    status: PeopleListsStatus.ready,
    ownerPubkey: _ownerPubkey,
    lists: lists,
    listIdsByPubkey: reverseIndex,
  );
}

PeopleListCandidate _candidate(
  String pubkey, {
  String? displayName,
  String? handle,
  bool isFollowing = true,
  bool isFollower = false,
  bool isAlreadyInList = false,
}) {
  return PeopleListCandidate(
    pubkey: pubkey,
    displayName: displayName,
    handle: handle,
    isFollowing: isFollowing,
    isFollower: isFollower,
    isAlreadyInList: isAlreadyInList,
  );
}

void main() {
  setUpAll(() {
    registerFallbackValue(
      const PeopleListsPubkeyAddRequested(
        listId: 'fallback',
        pubkey:
            '0000000000000000000000000000000000000000000000000000000000000000',
      ),
    );
  });

  group(AddPeopleToListScreen, () {
    late _MockPeopleListsBloc bloc;
    late _MockAddPeopleToListCubit cubit;
    late MockGoRouter router;

    setUp(() {
      router = MockGoRouter();
      when(() => router.canPop()).thenReturn(true);
      bloc = _MockPeopleListsBloc();
      when(() => bloc.submit(any()))
          .thenAnswer((_) async => PeopleListsOperationResult.succeeded);
      cubit = _MockAddPeopleToListCubit();
    });

    tearDown(() async {
      await bloc.close();
      await cubit.close();
    });

    Widget buildViewSubject({
      required UserList userList,
      required AddPeopleToListState cubitState,
    }) {
      when(() => cubit.state).thenReturn(cubitState);
      return MaterialApp(
        localizationsDelegates: appLocalizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: MockGoRouterProvider(
          goRouter: router,
          child: MultiBlocProvider(
            providers: [
              BlocProvider<PeopleListsBloc>.value(value: bloc),
              BlocProvider<AddPeopleToListCubit>.value(value: cubit),
            ],
            child: AddPeopleToListView(userList: userList),
          ),
        ),
      );
    }

    testWidgets(
      'partial batch failure keeps failed people selected and retry publishes only those people',
      (tester) async {
        final list = _buildList(id: 'crew', name: 'Crew');
        final follow = _MockFollowRepository();
        when(() => follow.followingPubkeys)
            .thenReturn([_candidateA, _candidateC]);
        when(() => follow.followingStream)
            .thenAnswer((_) => const Stream.empty());
        when(follow.watchMyFollowers).thenAnswer((_) => const Stream.empty());
        final loader = _MockRankingSignalsLoader();
        when(() => loader.isEligible(any())).thenReturn(true);
        when(() => loader.load(any())).thenAnswer(
          (invocation) async => {
            for (final key
                in invocation.positionalArguments.single as Iterable<String>)
              key: UserRankingSignals(pubkey: key),
          },
        );
        when(() => loader.loadCachedDisplayNames(any()))
            .thenAnswer((_) async => {});
        final picker = AddPeopleToListCubit(
          rankingSignalsLoader: loader,
          followRepository: follow,
          profileRepository: null,
          existingMemberPubkeys: [],
        );
        addTearDown(picker.close);
        await picker.started();
        picker.candidateToggled(_candidateA);
        picker.candidateToggled(_candidateC);
        when(() => bloc.state).thenReturn(_stateWith(lists: [list]));
        final pending = Completer<PeopleListsOperationResult>();
        when(
          () => bloc.submit(
            const PeopleListsPubkeyAddRequested(
              listId: 'crew',
              pubkey: _candidateC,
            ),
          ),
        ).thenAnswer((_) => pending.future);
        await tester.pumpWidget(
          MaterialApp(
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: MockGoRouterProvider(
              goRouter: router,
              child: MultiBlocProvider(
                providers: [
                  BlocProvider<PeopleListsBloc>.value(value: bloc),
                  BlocProvider<AddPeopleToListCubit>.value(value: picker),
                ],
                child: AddPeopleToListView(userList: list),
              ),
            ),
          ),
        );
        await tester.tap(find.widgetWithText(DivineButton, 'Add 2'));
        await tester.pump();
        expect(find.byType(CircularProgressIndicator), findsOneWidget);
        pending.complete(PeopleListsOperationResult.failed);
        await tester.pumpAndSettle();
        expect(picker.state.selectedPubkeys, {_candidateC});
        expect(
          picker.state.candidates
              .singleWhere((person) => person.pubkey == _candidateA)
              .isAlreadyInList,
          isTrue,
        );
        expect(
          picker.state.candidates
              .singleWhere((person) => person.pubkey == _candidateC)
              .isAlreadyInList,
          isFalse,
        );
        expect(
          find.text(
            lookupAppLocalizations(const Locale('en')).listUpdateFailed,
          ),
          findsOneWidget,
        );
        when(() => bloc.submit(any()))
            .thenAnswer((_) async => PeopleListsOperationResult.succeeded);
        await tester.tap(find.widgetWithText(DivineButton, 'Add 1'));
        await tester.pumpAndSettle();
        expect(picker.state.selectedPubkeys, isEmpty);
        verify(
          () => bloc.submit(
            const PeopleListsPubkeyAddRequested(
              listId: 'crew',
              pubkey: _candidateA,
            ),
          ),
        ).called(1);
        verify(
          () => bloc.submit(
            const PeopleListsPubkeyAddRequested(
              listId: 'crew',
              pubkey: _candidateC,
            ),
          ),
        ).called(2);
      },
    );

    group('after a confirmed add', () {
      Future<void> addSelected(WidgetTester tester) async {
        final list = _buildList(id: 'list-42', name: 'Close Friends');
        when(() => bloc.state).thenReturn(_stateWith(lists: [list]));
        await tester.pumpWidget(
          buildViewSubject(
            userList: list,
            cubitState: AddPeopleToListState(
              status: AddPeopleToListStatus.ready,
              candidates: [_candidate(_candidateA, displayName: 'Alice')],
              selectedPubkeys: const {_candidateA},
            ),
          ),
        );
        await tester.tap(find.widgetWithText(DivineButton, 'Add 1'));
        await tester.pumpAndSettle();
      }

      testWidgets('returns to the previous route', (tester) async {
        await addSelected(tester);

        verify(() => router.pop()).called(1);
        verifyNever(() => router.go(any()));
      });

      testWidgets('leaves for the fallback when nothing is below', (
        tester,
      ) async {
        when(() => router.canPop()).thenReturn(false);

        await addSelected(tester);

        verify(() => router.go(defaultSafePopFallback)).called(1);
        verifyNever(() => router.pop());
      });

      testWidgets('stays put when a person could not be added', (tester) async {
        when(() => bloc.submit(any()))
            .thenAnswer((_) async => PeopleListsOperationResult.failed);

        await addSelected(tester);

        verifyNever(() => router.pop());
        verifyNever(() => router.go(any()));
      });
    });

    test('exposes route name and path constants', () {
      expect(AddPeopleToListScreen.routeName, equals('people-list-add-people'));
      expect(
        AddPeopleToListScreen.path,
        equals('/people-lists/:listId/add-people'),
      );
    });

    testWidgets(
      'renders a $PersonPickableRow for each candidate in cubit state',
      (tester) async {
        final list = _buildList(id: 'list-1', name: 'Close Friends');
        when(() => bloc.state).thenReturn(_stateWith(lists: [list]));

        await tester.pumpWidget(
          buildViewSubject(
            userList: list,
            cubitState: AddPeopleToListState(
              status: AddPeopleToListStatus.ready,
              candidates: [
                _candidate(_candidateA, displayName: 'Alice'),
                _candidate(_candidateB, displayName: 'Bob'),
                _candidate(_candidateC, displayName: 'Carol'),
              ],
            ),
          ),
        );

        expect(find.byType(PersonPickableRow), findsNWidgets(3));
      },
    );

    testWidgets('shows spinner when status is $AddPeopleToListStatus.loading', (
      tester,
    ) async {
      final list = _buildList(id: 'list-1', name: 'Close Friends');
      when(() => bloc.state).thenReturn(_stateWith(lists: [list]));

      await tester.pumpWidget(
        buildViewSubject(
          userList: list,
          cubitState: const AddPeopleToListState(
            status: AddPeopleToListStatus.loading,
          ),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.byType(PersonPickableRow), findsNothing);
    });

    testWidgets(
      'shows retry view when status is $AddPeopleToListStatus.failure',
      (tester) async {
        final list = _buildList(id: 'list-1', name: 'Close Friends');
        when(() => bloc.state).thenReturn(_stateWith(lists: [list]));

        await tester.pumpWidget(
          buildViewSubject(
            userList: list,
            cubitState: const AddPeopleToListState(
              status: AddPeopleToListStatus.failure,
            ),
          ),
        );

        final retryFinder = find.widgetWithText(DivineButton, 'Try again');
        expect(retryFinder, findsOneWidget);

        await tester.tap(retryFinder);
        await tester.pump();
        verify(() => cubit.retryRequested()).called(1);
      },
    );

    testWidgets(
      'shows empty state when candidates are empty and status is ready',
      (tester) async {
        final list = _buildList(id: 'list-1', name: 'Close Friends');
        when(() => bloc.state).thenReturn(_stateWith(lists: [list]));

        await tester.pumpWidget(
          buildViewSubject(
            userList: list,
            cubitState: const AddPeopleToListState(
              status: AddPeopleToListStatus.ready,
            ),
          ),
        );

        expect(find.text('No people available to add.'), findsOneWidget);
        expect(find.byType(PersonPickableRow), findsNothing);
      },
    );

    testWidgets(
      'disables rows for candidates that are already members of the list',
      (tester) async {
        final list = _buildList(
          id: 'list-1',
          name: 'Close Friends',
          pubkeys: [_candidateA],
        );
        when(() => bloc.state).thenReturn(_stateWith(lists: [list]));

        await tester.pumpWidget(
          buildViewSubject(
            userList: list,
            cubitState: AddPeopleToListState(
              status: AddPeopleToListStatus.ready,
              candidates: [
                _candidate(
                  _candidateA,
                  displayName: 'Alice',
                  isAlreadyInList: true,
                ),
                _candidate(_candidateB, displayName: 'Bob'),
              ],
            ),
          ),
        );

        final rows = tester
            .widgetList<PersonPickableRow>(find.byType(PersonPickableRow))
            .toList();
        // Already-a-member row is rendered selected + disabled.
        expect(rows[0].enabled, isFalse);
        expect(rows[0].isSelected, isTrue);
        // Second candidate is selectable.
        expect(rows[1].enabled, isTrue);
        expect(rows[1].isSelected, isFalse);
      },
    );

    testWidgets('typing in the search field forwards the query to the cubit', (
      tester,
    ) async {
      final list = _buildList(id: 'list-1', name: 'Close Friends');
      when(() => bloc.state).thenReturn(_stateWith(lists: [list]));

      await tester.pumpWidget(
        buildViewSubject(
          userList: list,
          cubitState: AddPeopleToListState(
            status: AddPeopleToListStatus.ready,
            candidates: [
              _candidate(_candidateA, displayName: 'Alice'),
              _candidate(_candidateB, displayName: 'Bob'),
            ],
          ),
        ),
      );

      await tester.enterText(find.byType(TextField), 'ali');
      await tester.pump();

      verify(() => cubit.queryChanged('ali')).called(1);
    });

    testWidgets('visibleCandidates drives the rendered row set', (
      tester,
    ) async {
      final list = _buildList(id: 'list-1', name: 'Close Friends');
      when(() => bloc.state).thenReturn(_stateWith(lists: [list]));

      // Query 'alice' so only Alice's candidate survives the filter.
      await tester.pumpWidget(
        buildViewSubject(
          userList: list,
          cubitState: AddPeopleToListState(
            status: AddPeopleToListStatus.ready,
            query: 'alice',
            candidates: [
              _candidate(_candidateA, displayName: 'Alice'),
              _candidate(_candidateB, displayName: 'Bob'),
            ],
          ),
        ),
      );

      final rows = tester
          .widgetList<PersonPickableRow>(find.byType(PersonPickableRow))
          .toList();
      expect(rows, hasLength(1));
      expect(rows.single.pubkey, equals(_candidateA));
    });

    testWidgets('tapping a candidate row calls candidateToggled on the cubit', (
      tester,
    ) async {
      final list = _buildList(id: 'list-1', name: 'Close Friends');
      when(() => bloc.state).thenReturn(_stateWith(lists: [list]));

      await tester.pumpWidget(
        buildViewSubject(
          userList: list,
          cubitState: AddPeopleToListState(
            status: AddPeopleToListStatus.ready,
            candidates: [
              _candidate(_candidateA, displayName: 'Alice'),
              _candidate(_candidateB, displayName: 'Bob'),
            ],
          ),
        ),
      );

      await tester.tap(find.byType(PersonPickableRow).first);
      await tester.pump();

      verify(() => cubit.candidateToggled(_candidateA)).called(1);
    });

    testWidgets('Add button is disabled when no candidates are selected', (
      tester,
    ) async {
      final list = _buildList(id: 'list-1', name: 'Close Friends');
      when(() => bloc.state).thenReturn(_stateWith(lists: [list]));

      await tester.pumpWidget(
        buildViewSubject(
          userList: list,
          cubitState: AddPeopleToListState(
            status: AddPeopleToListStatus.ready,
            candidates: [_candidate(_candidateA, displayName: 'Alice')],
          ),
        ),
      );

      final addButton = tester.widget<DivineButton>(
        find.widgetWithText(DivineButton, 'Add'),
      );
      expect(addButton.onPressed, isNull);
    });

    testWidgets('Add button reflects selection count from cubit state', (
      tester,
    ) async {
      final list = _buildList(id: 'list-1', name: 'Close Friends');
      when(() => bloc.state).thenReturn(_stateWith(lists: [list]));

      await tester.pumpWidget(
        buildViewSubject(
          userList: list,
          cubitState: AddPeopleToListState(
            status: AddPeopleToListStatus.ready,
            candidates: [
              _candidate(_candidateA, displayName: 'Alice'),
              _candidate(_candidateB, displayName: 'Bob'),
            ],
            selectedPubkeys: const {_candidateA},
          ),
        ),
      );

      expect(find.widgetWithText(DivineButton, 'Add 1'), findsOneWidget);
    });

    testWidgets(
      'tapping Add dispatches $PeopleListsPubkeyAddRequested for each '
      'selected pubkey with full pubkeys',
      (tester) async {
        final list = _buildList(id: 'list-42', name: 'Close Friends');
        when(() => bloc.state).thenReturn(_stateWith(lists: [list]));

        await tester.pumpWidget(
          buildViewSubject(
            userList: list,
            cubitState: AddPeopleToListState(
              status: AddPeopleToListStatus.ready,
              candidates: [
                _candidate(_candidateA, displayName: 'Alice'),
                _candidate(_candidateB, displayName: 'Bob'),
                _candidate(_candidateC, displayName: 'Carol'),
              ],
              selectedPubkeys: const {_candidateA, _candidateC},
            ),
          ),
        );

        await tester.tap(find.widgetWithText(DivineButton, 'Add 2'));
        await tester.pump();

        verify(
          () => bloc.submit(
            const PeopleListsPubkeyAddRequested(
              listId: 'list-42',
              pubkey: _candidateA,
            ),
          ),
        ).called(1);
        verify(
          () => bloc.submit(
            const PeopleListsPubkeyAddRequested(
              listId: 'list-42',
              pubkey: _candidateC,
            ),
          ),
        ).called(1);
        verifyNever(
          () => bloc.submit(
            const PeopleListsPubkeyAddRequested(
              listId: 'list-42',
              pubkey: _candidateB,
            ),
          ),
        );
      },
    );
  });

  group('$AddPeopleToListScreen page integration', () {
    late _MockPeopleListsBloc bloc;
    late _MockFollowRepository mockFollowRepository;

    setUp(() {
      bloc = _MockPeopleListsBloc();
      when(() => bloc.submit(any()))
          .thenAnswer((_) async => PeopleListsOperationResult.succeeded);
      mockFollowRepository = _MockFollowRepository();

      when(
        () => mockFollowRepository.followingPubkeys,
      ).thenReturn(const <String>[]);
      when(
        () => mockFollowRepository.followingStream,
      ).thenAnswer((_) => const Stream<List<String>>.empty());
      when(
        mockFollowRepository.watchMyFollowers,
      ).thenAnswer((_) => const Stream<FollowersSnapshot>.empty());
    });

    tearDown(() async {
      await bloc.close();
    });

    testWidgets(
      'same-owner dependency refresh preserves the flow and owner switch clears it',
      (tester) async {
        final list = _buildList(
          id: 'refresh',
          name: 'Crew',
          pubkeys: [_candidateB],
        );
        when(() => bloc.state).thenReturn(_stateWith(lists: [list]));
        when(() => mockFollowRepository.followingPubkeys)
            .thenReturn([_candidateA, _candidateB]);
        final loaders = [
          _MockRankingSignalsLoader(),
          _MockRankingSignalsLoader(),
        ];
        final repositories = [
          _MockProfileRepository(),
          _MockProfileRepository(),
        ];
        for (var index = 0; index < 2; index++) {
          final loader = loaders[index];
          final repo = repositories[index];
          when(() => loader.isEligible(any())).thenReturn(true);
          when(() => loader.load(any())).thenAnswer(
            (_) async => {
              _candidateA: UserRankingSignals(
                pubkey: _candidateA,
                lastInteractionAt: index == 0 ? DateTime.now() : null,
              ),
              _candidateB: UserRankingSignals(
                pubkey: _candidateB,
                lastInteractionAt: index == 1 ? DateTime.now() : null,
              ),
            },
          );
          when(() => loader.loadCachedDisplayNames(any()))
              .thenAnswer((_) async => {});
          when(() => repo.getCachedProfile(pubkey: any(named: 'pubkey')))
              .thenAnswer((invocation) async {
                final key = invocation.namedArguments[#pubkey] as String;
                return UserProfile(
                  pubkey: key,
                  displayName: key == _candidateA
                      ? (index == 0 ? 'Zelda' : 'Aaron')
                      : 'Maria',
                  rawData: const {},
                  createdAt: _frozenNow,
                  eventId: 'e' * 64,
                );
              });
          when(() => repo.fetchFreshProfile(pubkey: any(named: 'pubkey')))
              .thenAnswer((_) async => null);
        }
        await tester.pumpWidget(
          testMaterialApp(
            mockFollowRepository: mockFollowRepository,
            home: ProviderScope(
              overrides: [
                nostrSessionProvider.overrideWith(_TestNostrSession.new),
                profileRepositoryProvider.overrideWith(
                  (ref) => repositories[ref.watch(_dependencyRevision)],
                ),
                userRankingSignalsLoaderProvider.overrideWith(
                  (ref) => loaders[ref.watch(_dependencyRevision)],
                ),
              ],
              child: BlocProvider<PeopleListsBloc>.value(
                value: bloc,
                child: AddPeopleToListScreen(listId: list.id),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final before = tester
            .element(find.byType(AddPeopleToListView))
            .read<AddPeopleToListCubit>();
        expect(before.state.candidates.map((c) => c.pubkey), [
          _candidateA,
          _candidateB,
        ]);
        await tester.tap(find.byType(PersonPickableRow).first);
        await tester.enterText(find.byType(TextField), 'a');
        await tester.pumpAndSettle();
        expect(before.state.selectedPubkeys, {_candidateA});
        expect(before.state.query, 'a');
        final container = ProviderScope.containerOf(
          tester.element(find.byType(AddPeopleToListScreen)),
        );
        container.read(_dependencyRevision.notifier).state = 1;
        await tester.pumpAndSettle();
        await tester.runAsync(() async {});
        await tester.pumpAndSettle();
        final after = tester
            .element(find.byType(AddPeopleToListView))
            .read<AddPeopleToListCubit>();
        expect(after, isNot(same(before)));
        expect(before.isClosed, isTrue);
        expect(after.state.selectedPubkeys, {_candidateA});
        expect(after.state.query, 'a');
        expect(
          tester.widget<TextField>(find.byType(TextField)).controller!.text,
          'a',
        );
        expect(after.state.candidates.map((c) => c.pubkey), [
          _candidateA,
          _candidateB,
        ]);
        expect(after.state.candidates.first.displayName, 'Aaron');
        expect(after.state.candidates.last.isAlreadyInList, isTrue);
        expect(
          after.state.rankingSignals[_candidateB]!.lastInteractionAt,
          isNotNull,
        );
        container
            .read(nostrSessionProvider.notifier)
            .update(NostrSessionReadiness.identityKnown(pubkey: 'e' * 64));
        await tester.pumpAndSettle();
        await tester.runAsync(() async {});
        await tester.pumpAndSettle();
        final otherOwner = tester
            .element(find.byType(AddPeopleToListView))
            .read<AddPeopleToListCubit>();
        expect(after.isClosed, isTrue);
        expect(otherOwner.state.selectedPubkeys, isEmpty);
        expect(otherOwner.state.query, isEmpty);
        expect(
          tester.widget<TextField>(find.byType(TextField)).controller!.text,
          isEmpty,
        );
        expect(otherOwner.state.candidates.map((c) => c.pubkey), [
          _candidateB,
          _candidateA,
        ]);
      },
    );

    testWidgets('renders network candidates seeded from FollowRepository', (
      tester,
    ) async {
      final list = _buildList(id: 'list-1', name: 'Close Friends');
      when(() => bloc.state).thenReturn(_stateWith(lists: [list]));

      when(
        () => mockFollowRepository.followingPubkeys,
      ).thenReturn([_candidateA, _candidateB]);
      when(() => mockFollowRepository.followingStream).thenAnswer(
        (_) => Stream<List<String>>.fromIterable([
          [_candidateA, _candidateB],
        ]),
      );

      await tester.pumpWidget(
        testMaterialApp(
          home: BlocProvider<PeopleListsBloc>.value(
            value: bloc,
            child: AddPeopleToListScreen(listId: list.id),
          ),
          mockFollowRepository: mockFollowRepository,
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.byType(PersonPickableRow), findsNWidgets(2));
    });

    testWidgets(
      'empty state is shown only when both follow sources are empty',
      (tester) async {
        final list = _buildList(id: 'list-1', name: 'Close Friends');
        when(() => bloc.state).thenReturn(_stateWith(lists: [list]));

        await tester.pumpWidget(
          testMaterialApp(
            home: BlocProvider<PeopleListsBloc>.value(
              value: bloc,
              child: AddPeopleToListScreen(listId: list.id),
            ),
            mockFollowRepository: mockFollowRepository,
          ),
        );
        await tester.pump();
        await tester.pump();

        expect(find.text('No people available to add.'), findsOneWidget);
        expect(find.byType(PersonPickableRow), findsNothing);
      },
    );

    testWidgets(
      'renders fallback scaffold when the list is missing from bloc state',
      (tester) async {
        when(() => bloc.state).thenReturn(_stateWith(lists: const []));

        await tester.pumpWidget(
          testMaterialApp(
            home: BlocProvider<PeopleListsBloc>.value(
              value: bloc,
              child: const AddPeopleToListScreen(listId: 'missing-id'),
            ),
            mockFollowRepository: mockFollowRepository,
          ),
        );
        await tester.pump();

        expect(find.textContaining('List not found'), findsOneWidget);
        expect(find.byType(PersonPickableRow), findsNothing);
      },
    );
  });

  group('GoRouter /people-lists/:listId/add-people', () {
    testWidgets(
      'route opens the full-screen picker using handwritten $GoRoute',
      (tester) async {
        final bloc = _MockPeopleListsBloc();
        when(() => bloc.submit(any()))
            .thenAnswer((_) async => PeopleListsOperationResult.succeeded);
        addTearDown(() async => bloc.close());
        final mockFollowRepository = _MockFollowRepository();
        when(
          () => mockFollowRepository.followingPubkeys,
        ).thenReturn(const <String>[]);
        when(
          () => mockFollowRepository.followingStream,
        ).thenAnswer((_) => const Stream<List<String>>.empty());
        when(
          mockFollowRepository.watchMyFollowers,
        ).thenAnswer((_) => const Stream<FollowersSnapshot>.empty());

        final list = _buildList(id: 'routed-list', name: 'Routed');
        when(() => bloc.state).thenReturn(_stateWith(lists: [list]));

        final router = GoRouter(
          initialLocation:
              '/people-lists/${Uri.encodeComponent(list.id)}/add-people',
          routes: [
            GoRoute(
              path: AddPeopleToListScreen.path,
              name: AddPeopleToListScreen.routeName,
              builder: (context, state) {
                final listId = state.pathParameters['listId'];
                if (listId == null || listId.isEmpty) {
                  return const Scaffold(
                    body: Center(child: Text('Invalid list')),
                  );
                }
                return AddPeopleToListScreen(listId: listId);
              },
            ),
          ],
        );

        await tester.pumpWidget(
          testProviderScope(
            mockFollowRepository: mockFollowRepository,
            child: BlocProvider<PeopleListsBloc>.value(
              value: bloc,
              child: MaterialApp.router(
                localizationsDelegates: appLocalizationsDelegates,
                supportedLocales: AppLocalizations.supportedLocales,
                routerConfig: router,
              ),
            ),
          ),
        );

        await tester.pump();

        expect(find.byType(AddPeopleToListScreen), findsOneWidget);
      },
    );
  });
}
