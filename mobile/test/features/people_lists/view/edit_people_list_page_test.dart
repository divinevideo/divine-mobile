// ABOUTME: Widget tests for EditPeopleListPage's resolution of an owned list.
// ABOUTME: A pending read is not absence, and a changed account is not edited.

import 'package:bloc_test/bloc_test.dart';
import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/features/people_lists/bloc/people_lists_bloc.dart';
import 'package:openvine/features/people_lists/view/create_people_list_page.dart';
import 'package:openvine/features/people_lists/view/edit_people_list_page.dart';
import 'package:openvine/l10n/l10n.dart';

import '../../../helpers/test_provider_overrides.dart';

class _MockPeopleListsBloc extends MockBloc<PeopleListsEvent, PeopleListsState>
    implements PeopleListsBloc {}

const String _owner =
    'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
const String _otherOwner =
    'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';

UserList _list({String id = 'crew', bool isEditable = true}) => UserList(
  id: id,
  name: 'Crew',
  pubkeys: const [],
  createdAt: DateTime.utc(2026),
  updatedAt: DateTime.utc(2026),
  isEditable: isEditable,
);

void main() {
  setUpAll(() {
    registerFallbackValue(const PeopleListsStarted());
  });

  group(EditPeopleListPage, () {
    final l10n = lookupAppLocalizations(const Locale('en'));
    late _MockPeopleListsBloc bloc;

    setUp(() {
      bloc = _MockPeopleListsBloc();
    });

    tearDown(() async {
      await bloc.close();
    });

    Future<void> pumpPage(
      WidgetTester tester, {
      required PeopleListsState state,
      String? signedInAs = _owner,
    }) async {
      whenListen(
        bloc,
        const Stream<PeopleListsState>.empty(),
        initialState: state,
      );
      await tester.pumpWidget(
        testProviderScope(
          mockAuthService: createMockAuthService(
            currentPublicKeyHex: signedInAs,
          ),
          child: MaterialApp(
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: BlocProvider<PeopleListsBloc>.value(
              value: bloc,
              child: const EditPeopleListPage(listId: 'crew'),
            ),
          ),
        ),
      );
    }

    testWidgets('opens the editor for an owned list', (tester) async {
      await pumpPage(
        tester,
        state: PeopleListsState(
          status: PeopleListsStatus.ready,
          ownerPubkey: _owner,
          lists: [_list()],
        ),
      );

      final editor = tester.widget<CreatePeopleListPage>(
        find.byType(CreatePeopleListPage),
      );
      expect(editor.editingList?.id, 'crew');
    });

    testWidgets('waits while the owner read is still pending', (tester) async {
      await pumpPage(
        tester,
        state: const PeopleListsState(
          status: PeopleListsStatus.ready,
          ownerPubkey: _owner,
          ownerReadStatus: PeopleListsOwnerReadStatus.pending,
        ),
      );

      expect(find.byType(DivineCircularProgressIndicator), findsOneWidget);
      expect(find.text(l10n.peopleListsListNotFoundTitle), findsNothing);
    });

    testWidgets('reports a list that is absent once the read settled', (
      tester,
    ) async {
      await pumpPage(
        tester,
        state: const PeopleListsState(
          status: PeopleListsStatus.ready,
          ownerPubkey: _owner,
        ),
      );

      expect(find.text(l10n.peopleListsListNotFoundTitle), findsOneWidget);
      expect(find.byType(CreatePeopleListPage), findsNothing);
    });

    testWidgets('does not edit a list the owner cannot edit', (tester) async {
      await pumpPage(
        tester,
        state: PeopleListsState(
          status: PeopleListsStatus.ready,
          ownerPubkey: _owner,
          lists: [_list(isEditable: false)],
        ),
      );

      expect(find.byType(CreatePeopleListPage), findsNothing);
      expect(find.text(l10n.peopleListsListNotFoundTitle), findsOneWidget);
    });

    testWidgets('offers a retry when the owner read failed', (tester) async {
      await pumpPage(
        tester,
        state: const PeopleListsState(
          status: PeopleListsStatus.ready,
          ownerPubkey: _owner,
          ownerReadStatus: PeopleListsOwnerReadStatus.failed,
        ),
      );

      expect(find.text(l10n.peopleListsLoadFailed), findsOneWidget);
      expect(find.text(l10n.peopleListsListNotFoundTitle), findsNothing);

      await tester.tap(
        find.widgetWithText(DivineButton, l10n.peopleListsAddPeopleRetry),
      );

      verify(() => bloc.add(const PeopleListsOwnerSyncRequested())).called(1);
    });

    testWidgets('refuses to edit after the signed-in account changed', (
      tester,
    ) async {
      await pumpPage(
        tester,
        state: PeopleListsState(
          status: PeopleListsStatus.ready,
          ownerPubkey: _otherOwner,
          lists: [_list()],
        ),
      );

      expect(find.text(l10n.peopleListsSessionChanged), findsOneWidget);
      expect(find.byType(CreatePeopleListPage), findsNothing);
    });

    testWidgets('refuses to edit while the feature is off', (tester) async {
      await pumpPage(
        tester,
        state: PeopleListsState(
          status: PeopleListsStatus.ready,
          ownerPubkey: _owner,
          enabled: false,
          lists: [_list()],
        ),
      );

      expect(find.text(l10n.peopleListsSessionChanged), findsOneWidget);
      expect(find.byType(CreatePeopleListPage), findsNothing);
    });
  });
}
