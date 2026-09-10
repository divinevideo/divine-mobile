// ABOUTME: Widget tests for AddPeopleToListScreen full-screen picker.
// ABOUTME: Covers candidate rendering, filtering, selection, disabled
// ABOUTME: already-member rows, and batch-add dispatch through the cubit.

import 'package:bloc_test/bloc_test.dart';
import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:follow_repository/follow_repository.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/features/people_lists/bloc/add_people_to_list_cubit.dart';
import 'package:openvine/features/people_lists/bloc/add_people_to_list_state.dart';
import 'package:openvine/features/people_lists/bloc/people_lists_bloc.dart';
import 'package:openvine/features/people_lists/models/people_list_candidate.dart';
import 'package:openvine/features/people_lists/view/add_people_to_list_screen.dart';
import 'package:openvine/features/people_lists/view/widgets/person_pickable_row.dart';
import 'package:openvine/l10n/l10n.dart';

import '../../../helpers/test_provider_overrides.dart';

class _MockPeopleListsBloc extends MockBloc<PeopleListsEvent, PeopleListsState>
    implements PeopleListsBloc {}

class _MockAddPeopleToListCubit extends MockCubit<AddPeopleToListState>
    implements AddPeopleToListCubit {}

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

    setUp(() {
      bloc = _MockPeopleListsBloc();
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
        home: MultiBlocProvider(
          providers: [
            BlocProvider<PeopleListsBloc>.value(value: bloc),
            BlocProvider<AddPeopleToListCubit>.value(value: cubit),
          ],
          child: AddPeopleToListView(userList: userList),
        ),
      );
    }

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
          () => bloc.add(
            const PeopleListsPubkeyAddRequested(
              listId: 'list-42',
              pubkey: _candidateA,
            ),
          ),
        ).called(1);
        verify(
          () => bloc.add(
            const PeopleListsPubkeyAddRequested(
              listId: 'list-42',
              pubkey: _candidateC,
            ),
          ),
        ).called(1);
        verifyNever(
          () => bloc.add(
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
