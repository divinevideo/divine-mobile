// ABOUTME: Widget tests for AddToPeopleListsSheet.
// ABOUTME: Covers list filtering, picking, applying the picks, and the empty state.

import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/features/feature_flags/models/feature_flag.dart';
import 'package:openvine/features/feature_flags/providers/feature_flag_providers.dart';
import 'package:openvine/features/people_lists/bloc/people_list_picks_cubit.dart';
import 'package:openvine/features/people_lists/bloc/people_lists_bloc.dart';
import 'package:openvine/features/people_lists/models/people_list_entry_point.dart';
import 'package:openvine/features/people_lists/view/add_to_people_lists_sheet.dart';
import 'package:openvine/features/people_lists/view/widgets/people_list_row.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/widgets/divine_list_thumbnail.dart';

import '../../../helpers/test_provider_overrides.dart';

class _MockPeopleListsBloc extends MockBloc<PeopleListsEvent, PeopleListsState>
    implements PeopleListsBloc {}

// Full-length Nostr pubkeys — never truncate.
const String _ownerPubkey =
    'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
const String _targetPubkey =
    'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';

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

/// The checks marking picked rows; the header's check button is a separate
/// widget outside the body.
Finder _rowChecks() => find.descendant(
  of: find.byType(AddToPeopleListsSheet),
  matching: find.byWidgetPredicate(
    (widget) => widget is DivineIcon && widget.icon == DivineIconName.check,
  ),
);

void main() {
  setUpAll(() {
    registerFallbackValue(
      const PeopleListsPubkeyToggleRequested(
        listId: 'fallback',
        pubkey:
            '0000000000000000000000000000000000000000000000000000000000000000',
      ),
    );
  });

  group(AddToPeopleListsSheet, () {
    final l10n = lookupAppLocalizations(const Locale('en'));
    late _MockPeopleListsBloc bloc;
    late PeopleListPicksCubit picks;

    setUp(() {
      bloc = _MockPeopleListsBloc();
      picks = PeopleListPicksCubit(memberListIds: const {});
      when(() => bloc.mutationSessionEpoch).thenReturn(0);
      when(() => bloc.submit(any())).thenAnswer(
        (_) async => PeopleListsOperationResult.succeeded,
      );
    });

    tearDown(() async {
      await bloc.close();
      await picks.close();
    });

    /// The body on its own; it seeds the picks from the bloc as it mounts.
    Widget buildSubject({
      required String pubkey,
      PeopleListEntryPoint entryPoint = PeopleListEntryPoint.shareMenu,
    }) {
      return ProviderScope(
        overrides: getStandardTestOverrides(),
        child: MaterialApp(
          localizationsDelegates: appLocalizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: BlocProvider<PeopleListsBloc>.value(
              value: bloc,
              child: BlocProvider<PeopleListPicksCubit>.value(
                value: picks,
                child: AddToPeopleListsSheet(
                  pubkey: pubkey,
                  entryPoint: entryPoint,
                ),
              ),
            ),
          ),
        ),
      );
    }

    /// Opens the real sheet from a button, as the app does.
    Future<void> openSheet(WidgetTester tester) async {
      await tester.pumpWidget(
        _withCuratedListsFlag(
          enabled: true,
          child: BlocProvider<PeopleListsBloc>.value(
            value: bloc,
            child: MaterialApp(
              localizationsDelegates: appLocalizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Scaffold(
                body: Builder(
                  builder: (context) => ElevatedButton(
                    onPressed: () => AddToPeopleListsSheet.show(
                      context,
                      pubkey: _targetPubkey,
                      entryPoint: PeopleListEntryPoint.shareMenu,
                    ),
                    child: const Text('open'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
    }

    group('renders', () {
      testWidgetsWithSurfaceSize(
        'shows only editable lists and filters read-only lists out',
        (tester) async {
          final editable = _buildList(id: 'list-1', name: 'Close Friends');
          final readOnly = _buildList(
            id: 'list-2',
            name: 'Divine Team',
            isEditable: false,
          );
          when(
            () => bloc.state,
          ).thenReturn(_stateWith(lists: [editable, readOnly]));

          await tester.pumpWidget(buildSubject(pubkey: _targetPubkey));

          expect(find.text('Close Friends'), findsOneWidget);
          expect(find.text('Divine Team'), findsNothing);
          expect(find.byType(PeopleListRow), findsOneWidget);
        },
      );

      testWidgetsWithSurfaceSize(
        'rows carry the collage, the member count, and a check on each '
        'list that already holds the person',
        (tester) async {
          final memberList = _buildList(
            id: 'list-1',
            name: 'Close Friends',
            pubkeys: [_targetPubkey],
          );
          final nonMemberList = _buildList(id: 'list-2', name: 'Work');
          when(
            () => bloc.state,
          ).thenReturn(_stateWith(lists: [memberList, nonMemberList]));

          await tester.pumpWidget(buildSubject(pubkey: _targetPubkey));

          expect(find.byType(DivineListMedia), findsNWidgets(2));
          expect(find.text(l10n.listMemberCount(1)), findsOneWidget);
          expect(find.text(l10n.listMemberCount(0)), findsOneWidget);
          expect(_rowChecks(), findsOneWidget);
          final checked = find.ancestor(
            of: _rowChecks(),
            matching: find.byType(PeopleListRow),
          );
          expect(
            tester.widget<PeopleListRow>(checked).list.id,
            equals('list-1'),
          );
        },
      );
    });

    group('interactions', () {
      testWidgetsWithSurfaceSize(
        'tapping rows picks and unpicks them without dispatching anything',
        (tester) async {
          final memberList = _buildList(
            id: 'list-1',
            name: 'Close Friends',
            pubkeys: [_targetPubkey],
          );
          final other = _buildList(id: 'list-2', name: 'Work');
          when(
            () => bloc.state,
          ).thenReturn(_stateWith(lists: [memberList, other]));

          await tester.pumpWidget(buildSubject(pubkey: _targetPubkey));

          await tester.tap(find.text('Work'));
          await tester.pump();
          expect(_rowChecks(), findsNWidgets(2));

          await tester.tap(find.text('Close Friends'));
          await tester.pump();
          expect(_rowChecks(), findsOneWidget);

          verifyNever(() => bloc.add(any()));
        },
      );

      testWidgetsWithSurfaceSize(
        'the check applies every pick through the bloc as one event, then '
        'closes',
        (tester) async {
          final memberList = _buildList(
            id: 'list-1',
            name: 'Close Friends',
            pubkeys: [_targetPubkey],
          );
          final first = _buildList(id: 'list-2', name: 'Work');
          final second = _buildList(id: 'list-3', name: 'Skaters');
          when(
            () => bloc.state,
          ).thenReturn(_stateWith(lists: [memberList, first, second]));

          await openSheet(tester);
          await tester.tap(find.text('Work'));
          await tester.tap(find.text('Skaters'));
          await tester.tap(find.text('Close Friends'));
          await tester.pump();
          await tester.tap(find.bySemanticsLabel(l10n.listDone));
          await tester.pumpAndSettle();

          final request =
              verify(() => bloc.submit(captureAny())).captured.single
                  as PeopleListsPicksApplied;
          expect(request.ownerPubkey, _ownerPubkey);
          expect(request.pubkey, _targetPubkey);
          expect(request.addListIds, {'list-2', 'list-3'});
          expect(request.removeListIds, {'list-1'});
          verifyNever(
            () => bloc.add(any(that: isA<PeopleListsPubkeyToggleRequested>())),
          );
          expect(find.byType(AddToPeopleListsSheet), findsNothing);
        },
      );

      testWidgetsWithSurfaceSize(
        'a pick the bloc rolls back after the sheet closed is reported on '
        'the screen underneath',
        (tester) async {
          final list = _buildList(id: 'list-1', name: 'Close Friends');
          final states = StreamController<PeopleListsState>.broadcast();
          addTearDown(states.close);
          // An outcome from an earlier visit is on the state already; the
          // sheet must wait for the one newer than it.
          final earlier = _stateWith(lists: [list]).copyWith(
            lastPicksOutcome: const PeopleListsPicksOutcome(
              requestId: 'earlier',
              sequence: 4,
              pubkey: _targetPubkey,
              refused: 1,
            ),
          );
          whenListen(bloc, states.stream, initialState: earlier);
          final completion = Completer<PeopleListsOperationResult>();
          when(() => bloc.submit(any())).thenAnswer((_) => completion.future);

          await openSheet(tester);
          await tester.tap(find.text('Close Friends'));
          await tester.pump();
          await tester.tap(find.bySemanticsLabel(l10n.listDone));
          await tester.pumpAndSettle();
          expect(find.byType(AddToPeopleListsSheet), findsNothing);
          expect(
            find.text(l10n.peopleListsMembershipUpdateFailed),
            findsNothing,
          );

          // The bloc applies the picks, a relay refuses one, and it records
          // the outcome.
          states.add(
            earlier.copyWith(
              lastPicksOutcome: PeopleListsPicksOutcome(
                requestId:
                    (verify(() => bloc.submit(captureAny())).captured.single
                            as PeopleListsPicksApplied)
                        .requestId,
                sequence: 5,
                pubkey: _targetPubkey,
                refused: 1,
              ),
            ),
          );
          completion.complete(PeopleListsOperationResult.failed);
          // The watch resumes on the stream's microtasks before the snackbar
          // can be scheduled.
          await tester.pumpAndSettle();

          expect(
            find.text(l10n.peopleListsMembershipUpdateFailed),
            findsOneWidget,
          );
        },
      );

      testWidgetsWithSurfaceSize(
        'reports a refusal emitted synchronously before the sheet closes',
        (tester) async {
          final list = _buildList(id: 'list-1', name: 'Close Friends');
          final states = StreamController<PeopleListsState>.broadcast(
            sync: true,
          );
          addTearDown(states.close);
          final initial = _stateWith(lists: [list]);
          whenListen(bloc, states.stream, initialState: initial);
          when(() => bloc.submit(any(that: isA<PeopleListsPicksApplied>())))
              .thenAnswer((invocation) {
                final request =
                    invocation.positionalArguments.single
                        as PeopleListsPicksApplied;
                states.add(
                  initial.copyWith(
                    lastPicksOutcome: PeopleListsPicksOutcome(
                      requestId: request.requestId,
                      sequence: 1,
                      pubkey: _targetPubkey,
                      refused: 1,
                    ),
                  ),
                );
                return Future.value(PeopleListsOperationResult.failed);
              });
          await openSheet(tester);
          await tester.tap(find.text('Close Friends'));
          await tester.pump();
          await tester.tap(find.bySemanticsLabel(l10n.listDone));
          await tester.pumpAndSettle();

          expect(find.byType(AddToPeopleListsSheet), findsNothing);
          expect(
            find.text(l10n.peopleListsMembershipUpdateFailed),
            findsOneWidget,
          );
        },
      );

      testWidgetsWithSurfaceSize(
        'a pick the bloc applies after the sheet closed reports nothing',
        (tester) async {
          final list = _buildList(id: 'list-1', name: 'Close Friends');
          final states = StreamController<PeopleListsState>.broadcast();
          addTearDown(states.close);
          whenListen(
            bloc,
            states.stream,
            initialState: _stateWith(lists: [list]),
          );

          await openSheet(tester);
          await tester.tap(find.text('Close Friends'));
          await tester.pump();
          await tester.tap(find.bySemanticsLabel(l10n.listDone));
          await tester.pumpAndSettle();

          final applied = _buildList(
            id: 'list-1',
            name: 'Close Friends',
            pubkeys: [_targetPubkey],
          );
          states.add(
            _stateWith(lists: [applied]).copyWith(
              lastPicksOutcome: PeopleListsPicksOutcome(
                requestId:
                    (verify(() => bloc.submit(captureAny())).captured.single
                            as PeopleListsPicksApplied)
                        .requestId,
                sequence: 1,
                pubkey: _targetPubkey,
                refused: 0,
              ),
            ),
          );
          await tester.pumpAndSettle();

          expect(
            find.text(l10n.peopleListsMembershipUpdateFailed),
            findsNothing,
          );
        },
      );

      testWidgetsWithSurfaceSize(
        'the check closes without dispatching when nothing was changed',
        (tester) async {
          final list = _buildList(
            id: 'list-1',
            name: 'Close Friends',
            pubkeys: [_targetPubkey],
          );
          when(() => bloc.state).thenReturn(_stateWith(lists: [list]));

          await openSheet(tester);
          await tester.tap(find.bySemanticsLabel(l10n.listDone));
          await tester.pumpAndSettle();

          verifyNever(() => bloc.add(any()));
          expect(find.byType(AddToPeopleListsSheet), findsNothing);
        },
      );

      testWidgetsWithSurfaceSize(
        'the check is disabled until a list is picked, and enabled again '
        'once one is',
        (tester) async {
          final list = _buildList(id: 'list-1', name: 'Close Friends');
          when(() => bloc.state).thenReturn(_stateWith(lists: [list]));
          SemanticsNode checkNode() =>
              find.semantics.byLabel(l10n.listDone).evaluate().single;

          await openSheet(tester);
          expect(
            checkNode(),
            isSemantics(hasEnabledState: true, isEnabled: false),
          );

          await tester.tap(find.text('Close Friends'));
          await tester.pump();
          expect(
            checkNode(),
            isSemantics(hasEnabledState: true, isEnabled: true),
          );

          await tester.tap(find.text('Close Friends'));
          await tester.pump();
          expect(
            checkNode(),
            isSemantics(hasEnabledState: true, isEnabled: false),
          );
        },
      );

      testWidgetsWithSurfaceSize(
        'the X discards the picks',
        (tester) async {
          final list = _buildList(id: 'list-1', name: 'Close Friends');
          when(() => bloc.state).thenReturn(_stateWith(lists: [list]));

          await openSheet(tester);
          await tester.tap(find.text('Close Friends'));
          await tester.pump();
          await tester.tap(find.bySemanticsLabel(l10n.commonClose));
          await tester.pumpAndSettle();

          verifyNever(() => bloc.add(any()));
          expect(find.byType(AddToPeopleListsSheet), findsNothing);
        },
      );

      testWidgetsWithSurfaceSize(
        'a list the bloc adds the person to shows up picked',
        (tester) async {
          final list = _buildList(id: 'list-1', name: 'Close Friends');
          final fresh = _buildList(
            id: 'list-2',
            name: 'Fresh',
            pubkeys: [_targetPubkey],
          );
          final later = _stateWith(lists: [list, fresh]);
          whenListen(
            bloc,
            Stream.fromIterable([later]),
            initialState: _stateWith(lists: [list]),
          );

          await openSheet(tester);
          await tester.pump();
          await tester.pump();

          expect(find.text('Fresh'), findsOneWidget);
          expect(_rowChecks(), findsOneWidget);
          final checked = find.ancestor(
            of: _rowChecks(),
            matching: find.byType(PeopleListRow),
          );
          expect(
            tester.widget<PeopleListRow>(checked).list.id,
            equals('list-2'),
          );
        },
      );
    });

    group('empty state', () {
      testWidgetsWithSurfaceSize(
        'shows hint text when there are no editable lists',
        (tester) async {
          when(() => bloc.state).thenReturn(_stateWith(lists: const []));

          await tester.pumpWidget(buildSubject(pubkey: _targetPubkey));

          expect(find.text(l10n.peopleListsEmptyTitle), findsOneWidget);
          // The Create list button lives in the VineBottomSheet bottomInput
          // slot, not inside the sheet body widget — so it is not present
          // when rendering AddToPeopleListsSheet directly.
          expect(find.byType(DivineButton), findsNothing);
        },
      );

      testWidgetsWithSurfaceSize(
        'ignores read-only lists when deciding whether the empty state is '
        'shown',
        (tester) async {
          final readOnly = _buildList(
            id: 'list-2',
            name: 'Divine Team',
            isEditable: false,
          );
          when(() => bloc.state).thenReturn(_stateWith(lists: [readOnly]));

          await tester.pumpWidget(buildSubject(pubkey: _targetPubkey));

          expect(find.text(l10n.peopleListsEmptyTitle), findsOneWidget);
          expect(find.byType(DivineButton), findsNothing);
        },
      );

      testWidgetsWithSurfaceSize(
        'Create New List button is present in the modal sheet and opens the '
        'new people list sheet when tapped',
        (tester) async {
          when(() => bloc.state).thenReturn(_stateWith(lists: const []));

          // BlocProvider must sit above the navigator so the bloc is
          // reachable from the modal route.
          await tester.pumpWidget(
            _withCuratedListsFlag(
              enabled: true,
              child: BlocProvider<PeopleListsBloc>.value(
                value: bloc,
                child: MaterialApp(
                  localizationsDelegates: appLocalizationsDelegates,
                  supportedLocales: AppLocalizations.supportedLocales,
                  home: Scaffold(
                    body: Builder(
                      builder: (innerContext) => ElevatedButton(
                        onPressed: () => AddToPeopleListsSheet.show(
                          innerContext,
                          pubkey: _targetPubkey,
                          entryPoint: PeopleListEntryPoint.shareMenu,
                        ),
                        child: const Text('open'),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );

          await tester.tap(find.text('open'));
          await tester.pumpAndSettle();

          // The Create New List button is pinned in the bottomInput slot of
          // the VineBottomSheet, worded as the video picker's.
          expect(
            find.widgetWithText(DivineButton, l10n.listCreateNewList),
            findsOneWidget,
          );

          // Tap opens the new people list sheet (another modal on top).
          await tester.tap(
            find.widgetWithText(DivineButton, l10n.listCreateNewList),
          );
          await tester.pumpAndSettle();

          // The new list sheet is shown — identified by its title key.
          expect(find.text(l10n.listNewPeopleList), findsOneWidget);
          await tester.enterText(
            find.byType(TextField).first,
            'Seeded without metadata',
          );
          await tester.pump();
          await tester.tap(find.bySemanticsLabel(l10n.listDone).last);
          await tester.pumpAndSettle();
          final request =
              verify(() => bloc.submit(captureAny())).captured.single
                  as PeopleListsCreateRequested;
          expect(request.initialPubkeys, [_targetPubkey]);
        },
      );
    });

    group('owner read and visit boundaries', () {
      testWidgetsWithSurfaceSize(
        'an unsettled empty owner read shows loading instead of no lists',
        (tester) async {
          when(() => bloc.state).thenReturn(
            _stateWith(lists: const []).copyWith(
              status: PeopleListsStatus.loading,
              ownerReadStatus: PeopleListsOwnerReadStatus.pending,
            ),
          );
          await tester.pumpWidget(buildSubject(pubkey: _targetPubkey));
          expect(find.byType(DivineCircularProgressIndicator), findsOneWidget);
          expect(find.text(l10n.peopleListsEmptyTitle), findsNothing);
        },
      );
      testWidgetsWithSurfaceSize(
        'an unsuccessful empty owner read offers its existing retry',
        (tester) async {
          when(() => bloc.state).thenReturn(
            _stateWith(lists: const []).copyWith(
              ownerReadStatus: PeopleListsOwnerReadStatus.failed,
            ),
          );
          await tester.pumpWidget(buildSubject(pubkey: _targetPubkey));
          expect(find.text(l10n.peopleListsLoadFailed), findsOneWidget);
          expect(find.text(l10n.peopleListsEmptyTitle), findsNothing);
          await tester.tap(find.text(l10n.peopleListsAddPeopleRetry));
          verify(() => bloc.add(const PeopleListsOwnerSyncRequested()))
              .called(1);
        },
      );
      for (final readStatus in [
        PeopleListsOwnerReadStatus.pending,
        PeopleListsOwnerReadStatus.failed,
      ]) {
        testWidgetsWithSurfaceSize(
          'cached rows remain usable during a $readStatus owner read',
          (tester) async {
            final list = _buildList(id: 'crew', name: 'Crew');
            when(() => bloc.state).thenReturn(
              _stateWith(lists: [list]).copyWith(ownerReadStatus: readStatus),
            );
            await tester.pumpWidget(buildSubject(pubkey: _targetPubkey));
            await tester.tap(find.text('Crew'));
            await tester.pump();
            expect(_rowChecks(), findsOneWidget);
            expect(find.text(l10n.peopleListsEmptyTitle), findsNothing);
            verifyNever(() => bloc.submit(any()));
          },
        );
      }
      testWidgetsWithSurfaceSize(
        'an account boundary returning to the same owner cancels stale Apply',
        (tester) async {
          final list = _buildList(id: 'crew', name: 'Crew');
          when(() => bloc.state).thenReturn(_stateWith(lists: [list]));
          await openSheet(tester);
          await tester.tap(find.text('Crew'));
          await tester.pump();
          // A -> B -> A has the same owner value and a different epoch.
          when(() => bloc.mutationSessionEpoch).thenReturn(2);
          await tester.tap(find.bySemanticsLabel(l10n.listDone));
          await tester.pumpAndSettle();
          verifyNever(() => bloc.submit(any()));
          expect(find.byType(AddToPeopleListsSheet), findsNothing);
          expect(find.text(l10n.peopleListsSessionChanged), findsOneWidget);
        },
      );
      testWidgetsWithSurfaceSize(
        'a changed account cannot create a list from a stale picker',
        (tester) async {
          when(() => bloc.state).thenReturn(_stateWith(lists: const []));
          await openSheet(tester);
          when(() => bloc.mutationSessionEpoch).thenReturn(1);
          await tester.tap(find.text(l10n.listCreateNewList));
          await tester.pumpAndSettle();
          expect(find.text(l10n.listNewPeopleList), findsNothing);
          expect(find.text(l10n.peopleListsSessionChanged), findsOneWidget);
          verifyNever(() => bloc.submit(any()));
        },
      );
      testWidgetsWithSurfaceSize(
        'queued cancellation uses its request-specific session notice',
        (tester) async {
          final list = _buildList(id: 'crew', name: 'Crew');
          final completion = Completer<PeopleListsOperationResult>();
          when(() => bloc.state).thenReturn(_stateWith(lists: [list]));
          when(() => bloc.submit(any())).thenAnswer((_) => completion.future);
          await openSheet(tester);
          await tester.tap(find.text('Crew'));
          await tester.pump();
          await tester.tap(find.bySemanticsLabel(l10n.listDone));
          await tester.pumpAndSettle();
          verify(() => bloc.submit(any(that: isA<PeopleListsPicksApplied>())))
              .called(1);
          expect(find.byType(AddToPeopleListsSheet), findsNothing);
          expect(find.text(l10n.peopleListsSessionChanged), findsNothing);
          completion.complete(PeopleListsOperationResult.cancelled);
          await tester.pumpAndSettle();
          expect(find.text(l10n.peopleListsSessionChanged), findsOneWidget);
          expect(
            find.text(l10n.peopleListsMembershipUpdateFailed),
            findsNothing,
          );
        },
      );
      testWidgetsWithSurfaceSize(
        'reordering rows preserves local picks by list identity',
        (tester) async {
          final first = _buildList(id: 'first', name: 'First');
          final second = _buildList(id: 'second', name: 'Second');
          final states = StreamController<PeopleListsState>();
          addTearDown(states.close);
          whenListen(
            bloc,
            states.stream,
            initialState: _stateWith(lists: [first, second]),
          );
          await tester.pumpWidget(buildSubject(pubkey: _targetPubkey));
          await tester.tap(find.text('First'));
          await tester.pump();
          states.add(_stateWith(lists: [second, first]));
          await tester.pump();
          expect(picks.state.selectedListIds, {'first'});
          final checks = find.byWidgetPredicate(
            (widget) =>
                widget is DivineIcon && widget.icon == DivineIconName.check,
          );
          expect(
            find.descendant(
              of: find.byKey(const ValueKey('first')),
              matching: checks,
            ),
            findsOneWidget,
          );
          expect(
            find.descendant(
              of: find.byKey(const ValueKey('second')),
              matching: checks,
            ),
            findsNothing,
          );
        },
      );
    });

    // The global PeopleListsBloc is registered unconditionally in main.dart
    // (a conditional entry re-inflated the Navigator on every flag flip), so
    // BlocProvider laziness is what keeps it unbuilt while curated lists are
    // off. These pin that: `create` firing means a relay query and cache
    // subscription started for a disabled feature.
    group('curatedLists gate', () {
      testWidgetsWithSurfaceSize(
        'show does not open the sheet or construct $PeopleListsBloc when '
        'curatedLists is off',
        (tester) async {
          var blocCreated = false;

          await tester.pumpWidget(
            _buildLazyBlocSubject(
              curatedListsEnabled: false,
              createBloc: () {
                blocCreated = true;
                return bloc;
              },
            ),
          );

          await tester.tap(find.text('open'));
          await tester.pumpAndSettle();

          expect(blocCreated, isFalse);
          expect(find.byType(AddToPeopleListsSheet), findsNothing);
        },
      );

      testWidgetsWithSurfaceSize(
        'show opens the sheet when curatedLists is on',
        (tester) async {
          var blocCreated = false;
          whenListen(
            bloc,
            const Stream<PeopleListsState>.empty(),
            initialState: _stateWith(lists: const []),
          );

          await tester.pumpWidget(
            _buildLazyBlocSubject(
              curatedListsEnabled: true,
              createBloc: () {
                blocCreated = true;
                return bloc;
              },
            ),
          );

          await tester.tap(find.text('open'));
          await tester.pumpAndSettle();

          expect(blocCreated, isTrue);
          expect(find.byType(AddToPeopleListsSheet), findsOneWidget);
        },
      );
    });

    group('theming', () {
      testWidgetsWithSurfaceSize(
        'renders inside $VineBottomSheet when shown as a modal',
        (tester) async {
          final list = _buildList(id: 'list-1', name: 'Close Friends');
          when(() => bloc.state).thenReturn(_stateWith(lists: [list]));

          // BlocProvider must sit above the navigator so the bloc is
          // reachable from the modal route. Wrapping the MaterialApp does
          // this because MaterialApp builds the root Navigator below it.
          await tester.pumpWidget(
            _withCuratedListsFlag(
              enabled: true,
              child: BlocProvider<PeopleListsBloc>.value(
                value: bloc,
                child: MaterialApp(
                  localizationsDelegates: appLocalizationsDelegates,
                  supportedLocales: AppLocalizations.supportedLocales,
                  home: Scaffold(
                    body: Builder(
                      builder: (context) {
                        return ElevatedButton(
                          onPressed: () => AddToPeopleListsSheet.show(
                            context,
                            pubkey: _targetPubkey,
                            entryPoint: PeopleListEntryPoint.shareMenu,
                          ),
                          child: const Text('open'),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
          );

          await tester.tap(find.text('open'));
          await tester.pumpAndSettle();

          expect(find.byType(VineBottomSheet), findsOneWidget);
          expect(find.byType(AddToPeopleListsSheet), findsOneWidget);
        },
      );
    });
  });
}

/// Mirrors the app shell: a lazy `BlocProvider` above the navigator, so
/// [createBloc] only runs if something below actually reads the bloc.
Widget _buildLazyBlocSubject({
  required bool curatedListsEnabled,
  required PeopleListsBloc Function() createBloc,
}) {
  return _withCuratedListsFlag(
    enabled: curatedListsEnabled,
    child: BlocProvider<PeopleListsBloc>(
      create: (_) => createBloc(),
      child: MaterialApp(
        localizationsDelegates: appLocalizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => AddToPeopleListsSheet.show(
                context,
                pubkey: _targetPubkey,
                entryPoint: PeopleListEntryPoint.profile,
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ),
  );
}

/// Scopes [child] with an explicit [FeatureFlag.curatedLists] value —
/// `AddToPeopleListsSheet.show` reads it before opening.
Widget _withCuratedListsFlag({required bool enabled, required Widget child}) {
  return ProviderScope(
    overrides: [
      ...getStandardTestOverrides(),
      authServiceProvider.overrideWithValue(
        createMockAuthService(currentPublicKeyHex: _ownerPubkey),
      ),
      isFeatureEnabledProvider(
        FeatureFlag.curatedLists,
      ).overrideWithValue(enabled),
    ],
    child: child,
  );
}

void testWidgetsWithSurfaceSize(
  String description,
  WidgetTesterCallback callback,
) {
  testWidgets(description, (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await callback(tester);
  });
}
