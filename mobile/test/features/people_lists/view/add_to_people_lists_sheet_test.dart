// ABOUTME: Widget tests for AddToPeopleListsSheet.
// ABOUTME: Covers list filtering, empty state, and toggle dispatching.

import 'package:bloc_test/bloc_test.dart';
import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/features/feature_flags/models/feature_flag.dart';
import 'package:openvine/features/feature_flags/providers/feature_flag_providers.dart';
import 'package:openvine/features/people_lists/bloc/people_lists_bloc.dart';
import 'package:openvine/features/people_lists/models/people_list_entry_point.dart';
import 'package:openvine/features/people_lists/view/add_to_people_lists_sheet.dart';
import 'package:openvine/features/people_lists/view/widgets/people_list_row.dart';
import 'package:openvine/l10n/l10n.dart';

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

    setUp(() {
      bloc = _MockPeopleListsBloc();
    });

    tearDown(() async {
      await bloc.close();
    });

    Widget buildSubject({
      required String pubkey,
      PeopleListEntryPoint entryPoint = PeopleListEntryPoint.shareMenu,
    }) {
      return MaterialApp(
        localizationsDelegates: appLocalizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: BlocProvider<PeopleListsBloc>.value(
            value: bloc,
            child: AddToPeopleListsSheet(
              pubkey: pubkey,
              entryPoint: entryPoint,
            ),
          ),
        ),
      );
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
        'selected row is checked when target pubkey is already in the list',
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

          final checkboxes = tester
              .widgetList<DivineSpriteCheckbox>(
                find.byType(DivineSpriteCheckbox),
              )
              .toList();
          expect(checkboxes, hasLength(2));
          // Sheet renders lists in the bloc's declared order; first list
          // contains the target pubkey so its checkbox is selected.
          expect(checkboxes[0].state, equals(DivineCheckboxState.selected));
          expect(checkboxes[1].state, equals(DivineCheckboxState.unselected));
        },
      );
    });

    group('interactions', () {
      testWidgetsWithSurfaceSize(
        'tapping a row dispatches $PeopleListsPubkeyToggleRequested with '
        'the target list id and full pubkey',
        (tester) async {
          final list = _buildList(id: 'list-42', name: 'Close Friends');
          when(() => bloc.state).thenReturn(_stateWith(lists: [list]));

          await tester.pumpWidget(buildSubject(pubkey: _targetPubkey));

          await tester.tap(find.byType(PeopleListRow));
          await tester.pump();

          verify(
            () => bloc.add(
              const PeopleListsPubkeyToggleRequested(
                listId: 'list-42',
                pubkey: _targetPubkey,
              ),
            ),
          ).called(1);
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
        'Create list button is present in the modal sheet and opens the '
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

          // The Create list button is pinned in the bottomInput slot of
          // the VineBottomSheet.
          expect(
            find.widgetWithText(DivineButton, 'Create list'),
            findsOneWidget,
          );

          // Tap opens the new people list sheet (another modal on top).
          await tester.tap(find.widgetWithText(DivineButton, 'Create list'));
          await tester.pumpAndSettle();

          // The new list sheet is shown — identified by its title key.
          expect(find.text(l10n.listNewPeopleList), findsOneWidget);
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
