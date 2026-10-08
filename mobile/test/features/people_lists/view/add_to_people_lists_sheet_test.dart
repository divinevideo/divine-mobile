// ABOUTME: Widget tests for AddToPeopleListsSheet.
// ABOUTME: Covers list filtering, picking, applying the picks, and the empty state.

import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/rendering.dart';
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
import 'package:people_lists_repository/people_lists_repository.dart';
import 'package:unified_logger/unified_logger.dart';

import '../../../helpers/test_provider_overrides.dart';

class _MockPeopleListsBloc extends MockBloc<PeopleListsEvent, PeopleListsState>
    implements PeopleListsBloc {}

class _MockPeopleListsRepository extends Mock
    implements PeopleListsRepository {}

/// Counts actual UI listeners while keeping the real mutation actor.
class _TrackedPeopleListsBloc extends PeopleListsBloc {
  _TrackedPeopleListsBloc({
    required super.repository,
    required super.repositoryStream,
  }) : super(
         ownerPubkeyStream: const Stream.empty(),
         enabledStream: const Stream.empty(),
         initialOwnerPubkey: _ownerPubkey,
       );

  int activeStateListeners = 0;
  late final Stream<PeopleListsState> _trackedStream =
      Stream<PeopleListsState>.multi((controller) {
        activeStateListeners++;
        final subscription = super.stream.listen(
          controller.addSync,
          onError: controller.addErrorSync,
          onDone: controller.closeSync,
        );
        controller.onCancel = () {
          activeStateListeners--;
          unawaited(subscription.cancel());
        };
      }, isBroadcast: true);

  @override
  Stream<PeopleListsState> get stream => _trackedStream;
}

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
    late MockAuthService auth;
    late String? activeOwner;

    setUp(() {
      activeOwner = _ownerPubkey;
      auth = createMockAuthService(currentPublicKeyHex: _ownerPubkey);
      when(() => auth.currentPublicKeyHex).thenAnswer((_) => activeOwner);
      bloc = _MockPeopleListsBloc();
      when(() => bloc.isClosed).thenReturn(false);
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
          auth: auth,
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

    testWidgets('pending owner read does not claim there are no lists', (
      tester,
    ) async {
      whenListen(
        bloc,
        const Stream<PeopleListsState>.empty(),
        initialState: _stateWith(lists: const [])
            .copyWith(ownerReadStatus: PeopleListsOwnerReadStatus.pending),
      );
      await tester.pumpWidget(buildSubject(pubkey: _targetPubkey));
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text(l10n.peopleListsEmptyTitle), findsNothing);
    });

    testWidgets('failed owner read offers an explicit retry', (tester) async {
      whenListen(
        bloc,
        const Stream<PeopleListsState>.empty(),
        initialState: _stateWith(lists: const [])
            .copyWith(ownerReadStatus: PeopleListsOwnerReadStatus.failed),
      );
      await tester.pumpWidget(buildSubject(pubkey: _targetPubkey));
      await tester.pump();
      expect(find.text(l10n.peopleListsEmptyTitle), findsNothing);
      expect(find.text(l10n.peopleListsLoadFailed), findsOneWidget);
      await tester.tap(find.text(l10n.peopleListsAddPeopleRetry));
      verify(() => bloc.add(any(that: isA<PeopleListsOwnerSyncRequested>())))
          .called(1);
    });

    testWidgets("the failed owner read is said in the sheet's font", (
      tester,
    ) async {
      whenListen(
        bloc,
        const Stream<PeopleListsState>.empty(),
        initialState: _stateWith(lists: const [])
            .copyWith(ownerReadStatus: PeopleListsOwnerReadStatus.failed),
      );
      await tester.pumpWidget(buildSubject(pubkey: _targetPubkey));
      await tester.pump();

      final message = tester.renderObject<RenderParagraph>(
        find.text(l10n.peopleListsLoadFailed),
      );
      expect(
        message.text.style?.fontFamily,
        VineTheme.bodyMediumFont().fontFamily,
      );
    });

    testWidgets('cached lists stay visible when the owner read fails', (
      tester,
    ) async {
      whenListen(
        bloc,
        const Stream<PeopleListsState>.empty(),
        initialState: _stateWith(
          lists: [_buildList(id: 'cached', name: 'Cached')],
        ).copyWith(ownerReadStatus: PeopleListsOwnerReadStatus.failed),
      );
      await tester.pumpWidget(buildSubject(pubkey: _targetPubkey));
      await tester.pump();
      expect(find.text('Cached'), findsOneWidget);
      expect(find.text(l10n.peopleListsEmptyTitle), findsNothing);
    });

    testWidgets(
      'applying a picker opened in another account does not send a batch',
      (tester) async {
        whenListen(
          bloc,
          const Stream<PeopleListsState>.empty(),
          initialState: _stateWith(
            lists: [_buildList(id: 'list', name: 'Friends')],
          ),
        );
        await openSheet(tester);
        await tester.tap(find.text('Friends'));
        await tester.pump();
        activeOwner = 'e' * 64;
        await tester.tap(find.bySemanticsLabel(l10n.listDone));
        await tester.pump();
        verifyNever(() => bloc.add(any()));
        verifyNever(() => bloc.submit(any()));
        expect(find.byType(AddToPeopleListsSheet), findsOneWidget);
      },
    );

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
          verifyNever(() => bloc.submit(any()));
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
          verifyNever(() => bloc.submit(any()));
          expect(find.byType(AddToPeopleListsSheet), findsNothing);
        },
      );

      testWidgetsWithSurfaceSize(
        'with the person in no list, the check is disabled until a list is '
        'picked, and again once it is unpicked',
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
        'unpicking the only list that holds the person leaves the check '
        'enabled, and the check takes them out',
        (tester) async {
          final list = _buildList(
            id: 'list-1',
            name: 'Close Friends',
            pubkeys: [_targetPubkey],
          );
          when(() => bloc.state).thenReturn(_stateWith(lists: [list]));

          await openSheet(tester);
          await tester.tap(find.text('Close Friends'));
          await tester.pump();
          expect(_rowChecks(), findsNothing);
          expect(
            find.semantics.byLabel(l10n.listDone).evaluate().single,
            isSemantics(hasEnabledState: true, isEnabled: true),
          );

          await tester.tap(find.bySemanticsLabel(l10n.listDone));
          await tester.pumpAndSettle();

          final request =
              verify(() => bloc.submit(captureAny())).captured.single
                  as PeopleListsPicksApplied;
          expect(request.addListIds, isEmpty);
          expect(request.removeListIds, {'list-1'});
          expect(find.byType(AddToPeopleListsSheet), findsNothing);
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
          verifyNever(() => bloc.submit(any()));
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

    group('real actor lifetime', () {
      _MockPeopleListsRepository repositoryWith(UserList list) {
        final repository = _MockPeopleListsRepository();
        when(() => repository.watchLists(ownerPubkey: _ownerPubkey))
            .thenAnswer((_) => Stream.value([list]));
        when(() => repository.syncOwner(ownerPubkey: _ownerPubkey))
            .thenAnswer((_) async {});
        when(
          () => repository.syncFollowedLists(
            viewerPubkey: any(named: 'viewerPubkey'),
            isCancelled: any(named: 'isCancelled'),
          ),
        ).thenAnswer((_) async {});
        return repository;
      }

      Widget realSubject(
        PeopleListsBloc realBloc, {
        bool startActor = true,
        ValueChanged<Future<void>>? onOpened,
      }) => _withCuratedListsFlag(
        enabled: true,
        auth: auth,
        child: BlocProvider<PeopleListsBloc>(
          create: (_) {
            if (startActor) realBloc.add(const PeopleListsStarted());
            return realBloc;
          },
          child: MaterialApp(
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () {
                    final opened = AddToPeopleListsSheet.show(
                      context,
                      pubkey: _targetPubkey,
                      entryPoint: PeopleListEntryPoint.shareMenu,
                    );
                    onOpened?.call(opened);
                  },
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      );

      testWidgetsWithSurfaceSize(
        'initialization opens the loading picker before its relay read finishes',
        (tester) async {
          final list = _buildList(id: 'crew', name: 'Crew');
          final repository = repositoryWith(list);
          final sync = Completer<void>();
          when(() => repository.watchLists(ownerPubkey: _ownerPubkey))
              .thenAnswer((_) => const Stream.empty());
          when(() => repository.syncOwner(ownerPubkey: _ownerPubkey))
              .thenAnswer((_) => sync.future);
          final realBloc = _TrackedPeopleListsBloc(
            repository: repository,
            repositoryStream: const Stream.empty(),
          );
          await tester.pumpWidget(realSubject(realBloc));
          await tester.tap(find.text('open'));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 500));
          expect(sync.isCompleted, isFalse);
          expect(
            realBloc.state.ownerReadStatus,
            PeopleListsOwnerReadStatus.pending,
          );
          expect(find.byType(AddToPeopleListsSheet), findsOneWidget);
          expect(find.byType(DivineCircularProgressIndicator), findsOneWidget);
          expect(find.text(l10n.peopleListsEmptyTitle), findsNothing);
          sync.complete();
          await tester.pumpWidget(const SizedBox());
          await tester.pumpAndSettle();
          expect(realBloc.activeStateListeners, 0);
        },
      );

      testWidgetsWithSurfaceSize(
        'a closed actor settles initial coordination without opening or hanging',
        (tester) async {
          final list = _buildList(id: 'crew', name: 'Crew');
          final realBloc = PeopleListsBloc(
            repository: repositoryWith(list),
            ownerPubkeyStream: const Stream.empty(),
            repositoryStream: const Stream.empty(),
            enabledStream: const Stream.empty(),
            initialOwnerPubkey: _ownerPubkey,
          );
          var openingCompleted = false;
          await tester.pumpWidget(
            realSubject(
              realBloc,
              startActor: false,
              onOpened: (opened) => unawaited(
                opened.then((_) {
                  openingCompleted = true;
                }),
              ),
            ),
          );
          await tester.tap(find.text('open'));
          await tester.pump();
          expect(openingCompleted, isFalse);
          expect(find.byType(AddToPeopleListsSheet), findsNothing);
          var closingCompleted = false;
          unawaited(
            realBloc.close().then((_) {
              closingCompleted = true;
            }),
          );
          // Some cancellation futures belong to the real zone, so service
          // that event-loop turn before draining the widget-clock callbacks.
          await tester.pump(Duration.zero);
          await tester.runAsync(() async {});
          await tester.pump(Duration.zero);
          expect(closingCompleted, isTrue);
          expect(openingCompleted, isTrue);
          expect(find.byType(AddToPeopleListsSheet), findsNothing);
          expect(realBloc.isClosed, isTrue);
          expect(tester.takeException(), isNull);
        },
      );

      testWidgetsWithSurfaceSize(
        'a first lazy startup establishes the epoch before accepting picks',
        (tester) async {
          final list = _buildList(id: 'crew', name: 'Crew');
          final repository = repositoryWith(list);
          when(
            () => repository.addPubkey(
              ownerPubkey: _ownerPubkey,
              listId: 'crew',
              pubkey: _targetPubkey,
            ),
          ).thenAnswer(
            (_) async => const PeopleListPublishResult(
              status: PeopleListPublishStatus.submitted,
            ),
          );
          final realBloc = _TrackedPeopleListsBloc(
            repository: repository,
            repositoryStream: const Stream.empty(),
          );
          await tester.pumpWidget(realSubject(realBloc));
          expect(realBloc.state.status, PeopleListsStatus.initial);
          expect(realBloc.mutationSessionEpoch, 0);
          await tester.tap(find.text('open'));
          await tester.pumpAndSettle();
          expect(realBloc.mutationSessionEpoch, greaterThan(0));
          await tester.tap(find.text('Crew'));
          await tester.pump();
          await tester.tap(find.bySemanticsLabel(l10n.listDone));
          await tester.pumpAndSettle();
          verify(
            () => repository.addPubkey(
              ownerPubkey: _ownerPubkey,
              listId: 'crew',
              pubkey: _targetPubkey,
            ),
          ).called(1);
          expect(find.text(l10n.peopleListsSessionChanged), findsNothing);
          await tester.pumpWidget(const SizedBox());
          await tester.pumpAndSettle();
          expect(realBloc.activeStateListeners, 0);
        },
      );

      testWidgetsWithSurfaceSize(
        'same-owner repository replacement cancels saved picks without an orphan listener',
        (tester) async {
          final list = _buildList(id: 'crew', name: 'Crew');
          final repository = repositoryWith(list);
          final next = repositoryWith(list);
          final write = Completer<PeopleListPublishResult>();
          when(
            () => repository.addPubkey(
              ownerPubkey: _ownerPubkey,
              listId: 'crew',
              pubkey: _targetPubkey,
            ),
          ).thenAnswer((_) => write.future);
          final replacements =
              StreamController<PeopleListsRepository>.broadcast();
          addTearDown(replacements.close);
          final realBloc = _TrackedPeopleListsBloc(
            repository: repository,
            repositoryStream: replacements.stream,
          );
          // Establish the actor before opening this already-live visit.
          realBloc.add(const PeopleListsStarted());
          await tester.pump();
          await tester.pump();
          await tester.pumpWidget(realSubject(realBloc));
          await tester.tap(find.text('open'));
          await tester.pumpAndSettle();
          await tester.tap(find.bySemanticsLabel(l10n.commonClose));
          await tester.pumpAndSettle();
          // The still-live BlocProvider owns its normal inherited listener.
          final liveProviderListeners = realBloc.activeStateListeners;
          expect(liveProviderListeners, greaterThan(0));
          await tester.tap(find.text('open'));
          await tester.pumpAndSettle();
          await tester.tap(find.text('Crew'));
          await tester.pump();
          await tester.tap(find.bySemanticsLabel(l10n.listDone));
          await tester.pumpAndSettle();
          verify(
            () => repository.addPubkey(
              ownerPubkey: _ownerPubkey,
              listId: 'crew',
              pubkey: _targetPubkey,
            ),
          ).called(1);
          expect(find.byType(AddToPeopleListsSheet), findsNothing);
          replacements.add(next);
          await tester.pumpAndSettle();
          expect(realBloc.state.activeOwnerPubkey, _ownerPubkey);
          expect(find.text(l10n.peopleListsSessionChanged), findsOneWidget);
          expect(realBloc.activeStateListeners, liveProviderListeners);
          write.complete(
            const PeopleListPublishResult(
              status: PeopleListPublishStatus.submitted,
            ),
          );
          await tester.pumpAndSettle();
          verifyNever(
            () => next.addPubkey(
              ownerPubkey: any(named: 'ownerPubkey'),
              listId: any(named: 'listId'),
              pubkey: any(named: 'pubkey'),
            ),
          );
          expect(realBloc.activeStateListeners, liveProviderListeners);
          await tester.pumpWidget(const SizedBox());
          await tester.pumpAndSettle();
          expect(realBloc.activeStateListeners, 0);
        },
      );

      testWidgetsWithSurfaceSize(
        'finishing after the account container is disposed reads no dead providers',
        (tester) async {
          final list = _buildList(id: 'crew', name: 'Crew');
          final completion = Completer<PeopleListsOperationResult>();
          when(() => bloc.state).thenReturn(_stateWith(lists: [list]));
          when(() => bloc.submit(any())).thenAnswer((_) => completion.future);
          final container = ProviderContainer(
            overrides: [
              ...getStandardTestOverrides(),
              authServiceProvider.overrideWithValue(auth),
              isFeatureEnabledProvider(FeatureFlag.curatedLists)
                  .overrideWithValue(true),
            ],
          );
          await tester.pumpWidget(
            UncontrolledProviderScope(
              container: container,
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
          await tester.tap(find.text('Crew'));
          await tester.pump();
          await tester.tap(find.bySemanticsLabel(l10n.listDone));
          await tester.pumpAndSettle();
          expect(find.byType(AddToPeopleListsSheet), findsNothing);
          final before = LogCaptureService().getRecentLogs().length;
          container.dispose();
          completion.complete(PeopleListsOperationResult.failed);
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          expect(
            find.text(l10n.peopleListsMembershipUpdateFailed),
            findsNothing,
          );
          expect(
            LogCaptureService()
                .getRecentLogs()
                .skip(before)
                .where(
                  (entry) =>
                      entry.name == 'AddToPeopleListsSheet' &&
                      entry.error != null,
                ),
            isEmpty,
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
Widget _withCuratedListsFlag({
  required bool enabled,
  required Widget child,
  MockAuthService? auth,
}) {
  return ProviderScope(
    overrides: [
      ...getStandardTestOverrides(),
      authServiceProvider.overrideWithValue(
        auth ?? createMockAuthService(currentPublicKeyHex: _ownerPubkey),
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
