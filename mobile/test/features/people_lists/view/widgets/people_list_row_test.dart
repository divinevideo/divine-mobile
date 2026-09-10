// ABOUTME: Widget tests for PeopleListRow toggle affordance.
// ABOUTME: Verifies checkbox state, theming, and event dispatch on tap.

import 'package:bloc_test/bloc_test.dart';
import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/features/people_lists/bloc/people_lists_bloc.dart';
import 'package:openvine/features/people_lists/models/people_list_entry_point.dart';
import 'package:openvine/features/people_lists/view/widgets/people_list_row.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';

class _MockPeopleListsBloc extends MockBloc<PeopleListsEvent, PeopleListsState>
    implements PeopleListsBloc {}

// Full-length Nostr pubkeys — never truncate.
const String _ownerPubkey =
    'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
const String _targetPubkey =
    'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';
const String _otherPubkey =
    'cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc';

final DateTime _frozenNow = DateTime.utc(2026, 4, 20, 12);

UserList _buildList({
  required String id,
  required String name,
  List<String> pubkeys = const [],
}) {
  return UserList(
    id: id,
    name: name,
    pubkeys: pubkeys,
    createdAt: _frozenNow,
    updatedAt: _frozenNow,
  );
}

PeopleListsState _stateWith({
  required List<UserList> lists,
}) {
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

  group(PeopleListRow, () {
    late _MockPeopleListsBloc bloc;

    setUp(() {
      bloc = _MockPeopleListsBloc();
    });

    tearDown(() async {
      await bloc.close();
    });

    Widget buildSubject({
      required UserList list,
      required String pubkey,
      PeopleListEntryPoint entryPoint = PeopleListEntryPoint.shareMenu,
    }) {
      return MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: BlocProvider<PeopleListsBloc>.value(
            value: bloc,
            child: PeopleListRow(
              listId: list.id,
              listName: list.name,
              pubkey: pubkey,
              entryPoint: entryPoint,
            ),
          ),
        ),
      );
    }

    testWidgets('renders list name', (tester) async {
      final list = _buildList(id: 'list-1', name: 'Close Friends');
      when(() => bloc.state).thenReturn(_stateWith(lists: [list]));

      await tester.pumpWidget(
        buildSubject(list: list, pubkey: _targetPubkey),
      );

      expect(find.text('Close Friends'), findsOneWidget);
    });

    testWidgets(
      'shows selected checkbox when pubkey is a member of the list',
      (tester) async {
        final list = _buildList(
          id: 'list-1',
          name: 'Close Friends',
          pubkeys: [_targetPubkey],
        );
        when(() => bloc.state).thenReturn(_stateWith(lists: [list]));

        await tester.pumpWidget(
          buildSubject(list: list, pubkey: _targetPubkey),
        );

        final checkbox = tester.widget<DivineSpriteCheckbox>(
          find.byType(DivineSpriteCheckbox),
        );
        expect(checkbox.state, equals(DivineCheckboxState.selected));
      },
    );

    testWidgets(
      'shows unselected checkbox when pubkey is not a member',
      (tester) async {
        final list = _buildList(
          id: 'list-1',
          name: 'Close Friends',
          pubkeys: [_otherPubkey],
        );
        when(() => bloc.state).thenReturn(_stateWith(lists: [list]));

        await tester.pumpWidget(
          buildSubject(list: list, pubkey: _targetPubkey),
        );

        final checkbox = tester.widget<DivineSpriteCheckbox>(
          find.byType(DivineSpriteCheckbox),
        );
        expect(checkbox.state, equals(DivineCheckboxState.unselected));
      },
    );

    testWidgets(
      'tapping the row dispatches $PeopleListsPubkeyToggleRequested with the full pubkey',
      (tester) async {
        final list = _buildList(id: 'list-42', name: 'Close Friends');
        when(() => bloc.state).thenReturn(_stateWith(lists: [list]));

        await tester.pumpWidget(
          buildSubject(list: list, pubkey: _targetPubkey),
        );

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

    testWidgets('uses $VineTheme typography for the list name', (
      tester,
    ) async {
      final list = _buildList(id: 'list-1', name: 'Close Friends');
      when(() => bloc.state).thenReturn(_stateWith(lists: [list]));

      await tester.pumpWidget(
        buildSubject(list: list, pubkey: _targetPubkey),
      );

      final textWidget = tester.widget<Text>(find.text('Close Friends'));
      // VineTheme.titleMediumFont applies an explicit style; assert a
      // style is set and uses the onSurface color rather than locking to
      // the weight-suffixed family name returned by the theme.
      expect(textWidget.style, isNotNull);
      expect(textWidget.style?.color, equals(VineTheme.onSurface));
    });
  });
}
