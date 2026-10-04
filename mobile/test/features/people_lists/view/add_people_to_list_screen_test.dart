// ABOUTME: Widget tests for AddPeopleToListScreen, the one-tap people picker.
// ABOUTME: Covers the Following-style rows, the add/remove button driven by
// ABOUTME: PeopleListsBloc membership, search, and the loading states.

import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:follow_repository/follow_repository.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/features/feature_flags/models/feature_flag.dart';
import 'package:openvine/features/feature_flags/providers/feature_flag_providers.dart';
import 'package:openvine/features/people_lists/bloc/add_people_to_list_cubit.dart';
import 'package:openvine/features/people_lists/bloc/add_people_to_list_state.dart';
import 'package:openvine/features/people_lists/bloc/people_lists_bloc.dart';
import 'package:openvine/features/people_lists/models/people_list_candidate.dart';
import 'package:openvine/features/people_lists/view/add_people_to_list_screen.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/follow_relationship_provider.dart';
import 'package:openvine/providers/user_profile_providers.dart';
import 'package:openvine/widgets/branded_loading_indicator.dart';
import 'package:openvine/widgets/user_profile_tile.dart';
import 'package:people_lists_repository/people_lists_repository.dart';
// Override lives in riverpod's misc barrel; flutter_riverpod does not
// re-export the type name even though it accepts List<Override>.
import 'package:riverpod/misc.dart' show Override;

import '../../../helpers/finders.dart';
import '../../../helpers/test_provider_overrides.dart';

class _MockPeopleListsBloc extends MockBloc<PeopleListsEvent, PeopleListsState>
    implements PeopleListsBloc {}

class _MockAddPeopleToListCubit extends MockCubit<AddPeopleToListState>
    implements AddPeopleToListCubit {}

class _MockFollowRepository extends Mock implements FollowRepository {}

class _MockPeopleListsRepository extends Mock
    implements PeopleListsRepository {}

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

PeopleListsState _stateWith({
  required List<UserList> lists,
  PeopleListsStatus status = PeopleListsStatus.ready,
}) {
  final reverseIndex = <String, Set<String>>{};
  for (final list in lists) {
    for (final pk in list.pubkeys) {
      (reverseIndex[pk] ??= <String>{}).add(list.id);
    }
  }
  return PeopleListsState(
    status: status,
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
}) {
  return PeopleListCandidate(
    pubkey: pubkey,
    displayName: displayName,
    handle: handle,
    isFollowing: isFollowing,
    isFollower: isFollower,
  );
}

UserProfile _profile(String pubkey, String name) => UserProfile(
  pubkey: pubkey,
  displayName: name,
  rawData: const {},
  createdAt: _frozenNow,
  eventId: 'e' * 64,
);

/// Providers every rendered [UserProfileTile] reads, one set per candidate.
List<Override> _tileOverrides(Map<String, String> namesByPubkey) => [
  for (final entry in namesByPubkey.entries) ...[
    profileVanishedProvider(entry.key).overrideWith((ref) => false),
    followRelationshipProvider(
      entry.key,
    ).overrideWith((ref) => Stream.value(FollowRelationship.none)),
    userProfileReactiveProvider(
      entry.key,
    ).overrideWith((ref) => Stream.value(_profile(entry.key, entry.value))),
  ],
];

Finder _addButtons() => find.byWidgetPredicate(
  (widget) =>
      widget is DivineIconButton && widget.icon == DivineIconName.userPlus,
);

Finder _removeButtons() => find.byWidgetPredicate(
  (widget) =>
      widget is DivineIconButton && widget.icon == DivineIconName.userMinus,
);

void main() {
  final l10n = lookupAppLocalizations(const Locale('en'));

  setUpAll(() {
    registerFallbackValue(
      const PeopleListsPubkeyToggleRequested(
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

    final threeCandidates = AddPeopleToListState(
      status: AddPeopleToListStatus.ready,
      candidates: [
        _candidate(_candidateA, displayName: 'Alice'),
        _candidate(_candidateB, displayName: 'Bob'),
        _candidate(_candidateC, displayName: 'Carol'),
      ],
    );
    const threeNames = {
      _candidateA: 'Alice',
      _candidateB: 'Bob',
      _candidateC: 'Carol',
    };

    Future<void> pumpView(
      WidgetTester tester, {
      required UserList userList,
      required AddPeopleToListState cubitState,
      Map<String, String> names = threeNames,
      List<Override> additionalOverrides = const [],
      PeopleListsBloc? peopleListsBloc,
    }) async {
      when(() => cubit.state).thenReturn(cubitState);
      await tester.pumpWidget(
        testMaterialApp(
          additionalOverrides: [
            ..._tileOverrides(names),
            ...additionalOverrides,
          ],
          home: MultiBlocProvider(
            providers: [
              BlocProvider<PeopleListsBloc>.value(
                value: peopleListsBloc ?? bloc,
              ),
              BlocProvider<AddPeopleToListCubit>.value(value: cubit),
            ],
            child: AddPeopleToListView(userList: userList),
          ),
        ),
      );
      await tester.pump();
    }

    group('Main confirmed row-operation contracts', () {
      late _MockPeopleListsRepository repository;
      late PeopleListsBloc confirmedBloc;
      final list = _buildList(id: 'crew', name: 'Crew');

      setUp(() {
        repository = _MockPeopleListsRepository();
        when(
          () => repository.watchLists(ownerPubkey: any(named: 'ownerPubkey')),
        ).thenAnswer((_) => const Stream.empty());
        when(
          () => repository.syncOwner(ownerPubkey: any(named: 'ownerPubkey')),
        ).thenAnswer((_) async {});
        when(
          () => repository.syncFollowedLists(
            viewerPubkey: any(named: 'viewerPubkey'),
            isCancelled: any(named: 'isCancelled'),
          ),
        ).thenAnswer((_) async {});
      });

      tearDown(() async => confirmedBloc.close());

      Future<void> pumpConfirmedView(WidgetTester tester) async {
        confirmedBloc = PeopleListsBloc(
          repository: repository,
          ownerPubkeyStream: const Stream.empty(),
          repositoryStream: const Stream.empty(),
          enabledStream: const Stream.empty(),
          initialOwnerPubkey: _ownerPubkey,
          clock: () => _frozenNow,
        );
        confirmedBloc.add(
          PeopleListsRepositoryListsChanged(
            ownerPubkey: _ownerPubkey,
            lists: [list],
          ),
        );
        when(() => cubit.state).thenReturn(threeCandidates);
        await tester.pumpWidget(
          testMaterialApp(
            additionalOverrides: _tileOverrides(threeNames),
            home: MultiBlocProvider(
              providers: [
                BlocProvider<PeopleListsBloc>.value(value: confirmedBloc),
                BlocProvider<AddPeopleToListCubit>.value(value: cubit),
              ],
              child: AddPeopleToListView(userList: list),
            ),
          ),
        );
        await tester.pumpAndSettle();
      }

      Finder addPerson(String pubkey) => find.descendant(
        of: find.byWidgetPredicate(
          (widget) => widget is UserProfileTile && widget.pubkey == pubkey,
        ),
        matching: _addButtons(),
      );

      for (final failed in [false, true]) {
        testWidgets(
          'a ${failed ? 'failed' : 'confirmed'} row write keeps the picker and query open',
          (tester) async {
            final pending = Completer<PeopleListPublishResult>();
            addTearDown(() {
              if (!pending.isCompleted) {
                pending.complete(
                  const PeopleListPublishResult(
                    status: PeopleListPublishStatus.failed,
                  ),
                );
              }
            });
            when(
              () => repository.addPubkey(
                ownerPubkey: _ownerPubkey,
                listId: 'crew',
                pubkey: _candidateA,
              ),
            ).thenAnswer((_) => pending.future);
            await pumpConfirmedView(tester);
            await tester.enterText(find.byType(TextField), 'Ali');
            await tester.tap(addPerson(_candidateA));
            await tester.pumpAndSettle();
            expect(confirmedBloc.state.pendingMutations, isNotEmpty);
            expect(confirmedBloc.state.lists.single.pubkeys, [_candidateA]);
            expect(_removeButtons(), findsOneWidget);
            expect(find.byType(AddPeopleToListView), findsOneWidget);

            pending.complete(
              PeopleListPublishResult(
                status: failed
                    ? PeopleListPublishStatus.failed
                    : PeopleListPublishStatus.submitted,
              ),
            );
            await tester.pumpAndSettle();
            expect(confirmedBloc.state.pendingMutations, isEmpty);
            expect(
              confirmedBloc.state.lists.single.pubkeys,
              failed ? isEmpty : [_candidateA],
            );
            expect(
              find.text(l10n.peopleListsMembershipUpdateFailed),
              failed ? findsOneWidget : findsNothing,
            );
            expect(find.byType(AddPeopleToListView), findsOneWidget);
            expect(
              tester.widget<TextField>(find.byType(TextField)).controller!.text,
              'Ali',
            );
          },
        );
      }

      testWidgets(
        'a failed person retries without republishing a confirmed person',
        (
          tester,
        ) async {
          when(
            () => repository.addPubkey(
              ownerPubkey: _ownerPubkey,
              listId: 'crew',
              pubkey: _candidateA,
            ),
          ).thenAnswer(
            (_) async => const PeopleListPublishResult(
              status: PeopleListPublishStatus.submitted,
            ),
          );
          var carolAttempts = 0;
          when(
            () => repository.addPubkey(
              ownerPubkey: _ownerPubkey,
              listId: 'crew',
              pubkey: _candidateC,
            ),
          ).thenAnswer(
            (_) async => PeopleListPublishResult(
              status: ++carolAttempts == 1
                  ? PeopleListPublishStatus.failed
                  : PeopleListPublishStatus.submitted,
            ),
          );
          await pumpConfirmedView(tester);
          await tester.tap(addPerson(_candidateA));
          await tester.pumpAndSettle();
          await tester.tap(addPerson(_candidateC));
          await tester.pumpAndSettle();
          expect(confirmedBloc.state.lists.single.pubkeys, [_candidateA]);
          expect(
            find.text(l10n.peopleListsMembershipUpdateFailed),
            findsOneWidget,
          );
          await tester.tap(addPerson(_candidateC));
          await tester.pumpAndSettle();
          expect(confirmedBloc.state.lists.single.pubkeys, [
            _candidateA,
            _candidateC,
          ]);
          verify(
            () => repository.addPubkey(
              ownerPubkey: _ownerPubkey,
              listId: 'crew',
              pubkey: _candidateA,
            ),
          ).called(1);
          verify(
            () => repository.addPubkey(
              ownerPubkey: _ownerPubkey,
              listId: 'crew',
              pubkey: _candidateC,
            ),
          ).called(2);
          expect(find.byType(AddPeopleToListView), findsOneWidget);
        },
      );

      testWidgets(
        'owner replacement cancels the write and rejects stale picker actions',
        (
          tester,
        ) async {
          final pending = Completer<PeopleListPublishResult>();
          addTearDown(() {
            if (!pending.isCompleted) {
              pending.complete(
                const PeopleListPublishResult(
                  status: PeopleListPublishStatus.failed,
                ),
              );
            }
          });
          when(
            () => repository.addPubkey(
              ownerPubkey: _ownerPubkey,
              listId: 'crew',
              pubkey: _candidateA,
            ),
          ).thenAnswer((_) => pending.future);
          await pumpConfirmedView(tester);
          await tester.tap(addPerson(_candidateA));
          await tester.pumpAndSettle();
          expect(confirmedBloc.state.pendingMutations, isNotEmpty);
          confirmedBloc.add(
            const PeopleListsOwnerChanged(ownerPubkey: _candidateB),
          );
          await tester.pumpAndSettle();
          confirmedBloc.add(
            PeopleListsRepositoryListsChanged(
              ownerPubkey: _candidateB,
              lists: [list],
            ),
          );
          await tester.pumpAndSettle();
          expect(confirmedBloc.state.activeOwnerPubkey, _candidateB);
          expect(confirmedBloc.state.pendingMutations, isEmpty);
          pending.complete(
            const PeopleListPublishResult(
              status: PeopleListPublishStatus.submitted,
            ),
          );
          await tester.pumpAndSettle();
          expect(confirmedBloc.state.lists.single.pubkeys, isEmpty);
          await tester.tap(addPerson(_candidateC));
          await tester.pumpAndSettle();
          verifyNever(
            () => repository.addPubkey(
              ownerPubkey: _candidateB,
              listId: any(named: 'listId'),
              pubkey: any(named: 'pubkey'),
            ),
          );
          expect(
            find.text(l10n.peopleListsMembershipUpdateFailed),
            findsNothing,
          );
          expect(find.byType(AddPeopleToListView), findsOneWidget);
        },
      );
    });

    test('exposes route name and path constants', () {
      expect(AddPeopleToListScreen.routeName, equals('people-list-add-people'));
      expect(
        AddPeopleToListScreen.path,
        equals('/people-lists/:listId/add-people'),
      );
    });

    group('renders', () {
      testWidgets(
        'a Following-style row per candidate, with no checkbox and no '
        'confirm bar',
        (tester) async {
          final list = _buildList(id: 'list-1', name: 'Close Friends');
          when(() => bloc.state).thenReturn(_stateWith(lists: [list]));

          await pumpView(
            tester,
            userList: list,
            cubitState: threeCandidates,
          );

          expect(find.byType(UserProfileTile), findsNWidgets(3));
          expect(find.text('Alice'), findsOneWidget);
          expect(find.byType(DivineSpriteCheckbox), findsNothing);
          expect(find.byType(DivineButton), findsNothing);
        },
      );

      testWidgets('titles the bar with the list name and its member count', (
        tester,
      ) async {
        final list = _buildList(
          id: 'list-1',
          name: 'Close Friends',
          pubkeys: const [_candidateA, _candidateB],
        );
        when(() => bloc.state).thenReturn(_stateWith(lists: [list]));

        await pumpView(tester, userList: list, cubitState: threeCandidates);

        expect(
          find.text(l10n.peopleListsAddToListName('Close Friends')),
          findsOneWidget,
        );
        expect(find.text(l10n.listMemberCount(2)), findsOneWidget);
      });

      testWidgets(
        'the remove button on a member and the add button on everyone else',
        (tester) async {
          final list = _buildList(
            id: 'list-1',
            name: 'Close Friends',
            pubkeys: const [_candidateA],
          );
          when(() => bloc.state).thenReturn(_stateWith(lists: [list]));

          await pumpView(tester, userList: list, cubitState: threeCandidates);

          expect(_removeButtons(), findsOneWidget);
          expect(_addButtons(), findsNWidgets(2));
          // Both states are the chip size, so a row keeps its shape when it
          // flips; the secondary type would otherwise default to a larger
          // one. The tap target is 48px either way, so the size is asserted
          // on the widget rather than measured.
          expect(
            tester.widget<DivineIconButton>(_removeButtons()).size,
            equals(tester.widget<DivineIconButton>(_addButtons().first).size),
          );
          expect(
            tester.widget<DivineIconButton>(_removeButtons()).size,
            equals(DivineIconButtonSize.small),
          );
          expect(
            tester.widget<DivineIconButton>(_removeButtons()).semanticLabel,
            equals(l10n.peopleListsRemovePersonSemanticLabel('Alice')),
          );
          expect(
            tester
                .widgetList<DivineIconButton>(_addButtons())
                .map((button) => button.semanticLabel),
            containsAll([
              l10n.peopleListsAddPersonSemanticLabel('Bob'),
              l10n.peopleListsAddPersonSemanticLabel('Carol'),
            ]),
          );
        },
      );

      testWidgets(
        'no add-to-list action even when profile list features are on',
        (tester) async {
          // The row's own button already edits a list; the list-plus action
          // the Following screen shows would open the sheet for another one.
          final list = _buildList(id: 'list-1', name: 'Close Friends');
          when(() => bloc.state).thenReturn(_stateWith(lists: [list]));

          await pumpView(
            tester,
            userList: list,
            cubitState: threeCandidates,
            additionalOverrides: [
              isFeatureEnabledProvider(
                FeatureFlag.profileListFeatures,
              ).overrideWithValue(true),
              isFeatureEnabledProvider(
                FeatureFlag.curatedLists,
              ).overrideWithValue(true),
            ],
          );

          expect(findByTooltip(l10n.peopleListsAddToList), findsNothing);
          expect(_addButtons(), findsNWidgets(3));
        },
      );

      testWidgets('a spinner while candidates load', (tester) async {
        final list = _buildList(id: 'list-1', name: 'Close Friends');
        when(() => bloc.state).thenReturn(_stateWith(lists: [list]));

        await pumpView(
          tester,
          userList: list,
          cubitState: const AddPeopleToListState(
            status: AddPeopleToListStatus.loading,
          ),
        );

        expect(find.byType(BrandedLoadingIndicator), findsOneWidget);
        expect(find.byType(UserProfileTile), findsNothing);
      });

      testWidgets('the empty state when there is nobody to add', (
        tester,
      ) async {
        final list = _buildList(id: 'list-1', name: 'Close Friends');
        when(() => bloc.state).thenReturn(_stateWith(lists: [list]));

        await pumpView(
          tester,
          userList: list,
          cubitState: const AddPeopleToListState(
            status: AddPeopleToListStatus.ready,
          ),
        );

        expect(find.text(l10n.peopleListsNoPeopleToAdd), findsOneWidget);
        expect(find.byType(UserProfileTile), findsNothing);
      });

      testWidgets('no-results copy when the query hides every candidate', (
        tester,
      ) async {
        final list = _buildList(id: 'list-1', name: 'Close Friends');
        when(() => bloc.state).thenReturn(_stateWith(lists: [list]));

        await pumpView(
          tester,
          userList: list,
          cubitState: threeCandidates.copyWith(query: 'zzz'),
        );

        expect(find.text(l10n.searchNoResultsFound('zzz')), findsOneWidget);
        expect(find.text(l10n.peopleListsNoPeopleToAdd), findsNothing);
        expect(find.byType(UserProfileTile), findsNothing);
      });
    });

    group('interactions', () {
      testWidgets(
        'reports a refused write after a repository update while publishing',
        (tester) async {
          final list = _buildList(id: 'list-1', name: 'Close Friends');
          final repository = _MockPeopleListsRepository();
          final lists = StreamController<List<UserList>>();
          final publish = Completer<PeopleListPublishResult>();
          when(
            () => repository.watchLists(ownerPubkey: _ownerPubkey),
          ).thenAnswer((_) => lists.stream);
          when(
            () => repository.syncOwner(ownerPubkey: _ownerPubkey),
          ).thenAnswer((_) async {});
          when(
            () => repository.syncFollowedLists(
              viewerPubkey: _ownerPubkey,
              isCancelled: any(named: 'isCancelled'),
            ),
          ).thenAnswer((_) async {});
          when(
            () => repository.addPubkey(
              ownerPubkey: _ownerPubkey,
              listId: list.id,
              pubkey: _candidateA,
            ),
          ).thenAnswer((_) => publish.future);
          final peopleListsBloc = (await tester.runAsync(() async {
            final result = PeopleListsBloc(
              repository: repository,
              ownerPubkeyStream: const Stream.empty(),
              repositoryStream: const Stream.empty(),
              enabledStream: const Stream.empty(),
              initialOwnerPubkey: _ownerPubkey,
            );
            final loaded = result.stream.firstWhere(
              (state) => state.status == PeopleListsStatus.ready,
            );
            result.add(const PeopleListsStarted());
            await result.stream.firstWhere(
              (state) => state.status == PeopleListsStatus.loading,
            );
            lists.add([list]);
            await loaded;
            return result;
          }))!;
          Future<void> waitForStatus(PeopleListsStatus status) async {
            await tester.runAsync(() async {
              if (peopleListsBloc.state.status != status) {
                await peopleListsBloc.stream.firstWhere(
                  (state) => state.status == status,
                );
              }
            });
            await tester.pump();
          }

          try {
            await pumpView(
              tester,
              userList: list,
              cubitState: threeCandidates,
              peopleListsBloc: peopleListsBloc,
            );
            await tester.tap(_addButtons().first);
            await waitForStatus(PeopleListsStatus.submitting);
            expect(peopleListsBloc.state.status, PeopleListsStatus.submitting);
            expect(peopleListsBloc.state.pendingMutations, hasLength(1));
            expect(_removeButtons(), findsOneWidget);

            lists.add([list]);
            await waitForStatus(PeopleListsStatus.ready);
            expect(peopleListsBloc.state.status, PeopleListsStatus.ready);
            expect(peopleListsBloc.state.pendingMutations, hasLength(1));
            expect(
              find.text(l10n.peopleListsMembershipUpdateFailed),
              findsNothing,
            );

            publish.complete(const PeopleListPublishResult.failed());
            await waitForStatus(PeopleListsStatus.failure);
            expect(peopleListsBloc.state.status, PeopleListsStatus.failure);
            expect(peopleListsBloc.state.pendingMutations, isEmpty);
            expect(_removeButtons(), findsNothing);
            expect(_addButtons(), findsNWidgets(3));
            expect(
              find.text(l10n.peopleListsMembershipUpdateFailed),
              findsOneWidget,
            );
          } finally {
            if (!publish.isCompleted) {
              publish.complete(const PeopleListPublishResult.failed());
            }
            await tester.pumpWidget(const SizedBox.shrink());
            await tester.runAsync(() async {
              await peopleListsBloc.close();
              await lists.close();
            });
          }
        },
      );

      testWidgets('the add button toggles that person through the bloc', (
        tester,
      ) async {
        final list = _buildList(id: 'list-1', name: 'Close Friends');
        when(() => bloc.state).thenReturn(_stateWith(lists: [list]));

        await pumpView(tester, userList: list, cubitState: threeCandidates);

        await tester.tap(_addButtons().first);
        await tester.pump();

        verify(
          () => bloc.add(
            const PeopleListsPubkeyToggleRequested(
              listId: 'list-1',
              pubkey: _candidateA,
            ),
          ),
        ).called(1);
        expect(find.byType(DivineButton), findsNothing);
      });

      testWidgets('the remove button toggles a member back out', (
        tester,
      ) async {
        final list = _buildList(
          id: 'list-1',
          name: 'Close Friends',
          pubkeys: const [_candidateB],
        );
        when(() => bloc.state).thenReturn(_stateWith(lists: [list]));

        await pumpView(tester, userList: list, cubitState: threeCandidates);

        await tester.tap(_removeButtons());
        await tester.pump();

        verify(
          () => bloc.add(
            const PeopleListsPubkeyToggleRequested(
              listId: 'list-1',
              pubkey: _candidateB,
            ),
          ),
        ).called(1);
      });

      testWidgets(
        'a row flips to the remove button and the count grows once the bloc '
        'admits the person',
        (tester) async {
          final before = _buildList(id: 'list-1', name: 'Close Friends');
          final after = _buildList(
            id: 'list-1',
            name: 'Close Friends',
            pubkeys: const [_candidateA],
          );
          final states = StreamController<PeopleListsState>();
          addTearDown(states.close);
          whenListen(
            bloc,
            states.stream,
            initialState: _stateWith(lists: [before]),
          );

          await pumpView(tester, userList: before, cubitState: threeCandidates);
          expect(find.text(l10n.listMemberCount(0)), findsOneWidget);
          expect(_removeButtons(), findsNothing);

          states.add(_stateWith(lists: [after]));
          // One pump delivers the stream event, the next builds on it.
          await tester.pump();
          await tester.pump();

          expect(_removeButtons(), findsOneWidget);
          expect(_addButtons(), findsNWidgets(2));
          expect(find.text(l10n.listMemberCount(1)), findsOneWidget);
        },
      );

      testWidgets('a rolled-back write is reported in a snackbar', (
        tester,
      ) async {
        final list = _buildList(id: 'list-1', name: 'Close Friends');
        whenListen(
          bloc,
          Stream.fromIterable([
            _stateWith(lists: [list], status: PeopleListsStatus.submitting),
            _stateWith(lists: [list], status: PeopleListsStatus.failure),
          ]),
          initialState: _stateWith(lists: [list]),
        );

        await pumpView(tester, userList: list, cubitState: threeCandidates);
        await tester.pump();
        await tester.pump();

        expect(
          find.text(l10n.peopleListsMembershipUpdateFailed),
          findsOneWidget,
        );
      });

      testWidgets(
        'typing in the search field forwards the query to the cubit',
        (
          tester,
        ) async {
          final list = _buildList(id: 'list-1', name: 'Close Friends');
          when(() => bloc.state).thenReturn(_stateWith(lists: [list]));

          await pumpView(tester, userList: list, cubitState: threeCandidates);

          await tester.enterText(find.byType(TextField), 'ali');
          await tester.pump();

          verify(() => cubit.queryChanged('ali')).called(1);
        },
      );

      testWidgets('the retry button reloads after a failure', (tester) async {
        final list = _buildList(id: 'list-1', name: 'Close Friends');
        when(() => bloc.state).thenReturn(_stateWith(lists: [list]));

        await pumpView(
          tester,
          userList: list,
          cubitState: const AddPeopleToListState(
            status: AddPeopleToListStatus.failure,
          ),
        );

        final retry = find.widgetWithText(
          DivineButton,
          l10n.peopleListsAddPeopleRetry,
        );
        expect(retry, findsOneWidget);

        await tester.tap(retry);
        await tester.pump();

        verify(() => cubit.retryRequested()).called(1);
      });
    });
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
          additionalOverrides: _tileOverrides(const {
            _candidateA: 'Alice',
            _candidateB: 'Bob',
          }),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.byType(UserProfileTile), findsNWidgets(2));
      expect(_addButtons(), findsNWidgets(2));
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

        expect(find.text(l10n.peopleListsNoPeopleToAdd), findsOneWidget);
        expect(find.byType(UserProfileTile), findsNothing);
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

        expect(
          find.text(l10n.peopleListsListNotFoundSubtitle),
          findsOneWidget,
        );
        expect(find.byType(UserProfileTile), findsNothing);
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
