// ABOUTME: Widget tests for CreatePeopleListPage full-screen form.
// ABOUTME: Covers name-entry, disabled-create guard, and create dispatching.

import 'package:bloc_test/bloc_test.dart';
import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/features/people_lists/bloc/people_lists_bloc.dart';
import 'package:openvine/features/people_lists/view/create_people_list_page.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';

class _MockPeopleListsBloc extends MockBloc<PeopleListsEvent, PeopleListsState>
    implements PeopleListsBloc {}

const String _ownerPubkey =
    'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';

void main() {
  setUpAll(() {
    registerFallbackValue(
      const PeopleListsCreateRequested(name: 'fallback'),
    );
  });

  const targetPubkey =
      'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';

  group(CreatePeopleListPage, () {
    late _MockPeopleListsBloc bloc;

    setUp(() {
      bloc = _MockPeopleListsBloc();
      when(() => bloc.state).thenReturn(
        const PeopleListsState(
          status: PeopleListsStatus.ready,
          ownerPubkey: _ownerPubkey,
        ),
      );
    });

    tearDown(() async {
      await bloc.close();
    });

    Widget buildSubject({String? initialPubkey}) {
      return MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: BlocProvider<PeopleListsBloc>.value(
          value: bloc,
          child: CreatePeopleListPage(initialPubkey: initialPubkey),
        ),
      );
    }

    test('exposes route name and path constants', () {
      expect(
        CreatePeopleListPage.routeName,
        equals('people-list-create'),
      );
      expect(CreatePeopleListPage.path, equals('/people-lists/new'));
    });

    testWidgets('renders name field and create button', (tester) async {
      await tester.pumpWidget(buildSubject());

      expect(find.byType(TextFormField), findsOneWidget);
      expect(find.widgetWithText(DivineButton, 'Create'), findsOneWidget);
    });

    testWidgets(
      'Create button is disabled while the name field is empty',
      (tester) async {
        await tester.pumpWidget(buildSubject());

        final button = tester.widget<DivineButton>(
          find.widgetWithText(DivineButton, 'Create'),
        );
        expect(button.onPressed, isNull);
      },
    );

    testWidgets(
      'Create button is disabled when the name is only whitespace',
      (tester) async {
        await tester.pumpWidget(buildSubject());

        await tester.enterText(find.byType(TextFormField), '    ');
        await tester.pump();

        final button = tester.widget<DivineButton>(
          find.widgetWithText(DivineButton, 'Create'),
        );
        expect(button.onPressed, isNull);
      },
    );

    testWidgets(
      'entering a name enables the Create button',
      (tester) async {
        await tester.pumpWidget(buildSubject());

        await tester.enterText(find.byType(TextFormField), 'Film Club');
        await tester.pump();

        final button = tester.widget<DivineButton>(
          find.widgetWithText(DivineButton, 'Create'),
        );
        expect(button.onPressed, isNotNull);
      },
    );

    testWidgets(
      'tapping Create dispatches $PeopleListsCreateRequested with the '
      'trimmed name',
      (tester) async {
        await tester.pumpWidget(buildSubject());

        await tester.enterText(
          find.byType(TextFormField),
          '  Close Friends  ',
        );
        await tester.pump();

        await tester.tap(find.widgetWithText(DivineButton, 'Create'));
        await tester.pump();

        verify(
          () => bloc.add(
            const PeopleListsCreateRequested(name: 'Close Friends'),
          ),
        ).called(1);
      },
    );

    testWidgets(
      'tapping Create with an initialPubkey dispatches '
      '$PeopleListsCreateRequested with the pubkey seeded into '
      'initialPubkeys (untruncated)',
      (tester) async {
        await tester.pumpWidget(buildSubject(initialPubkey: targetPubkey));

        await tester.enterText(
          find.byType(TextFormField),
          'Close Friends',
        );
        await tester.pump();

        await tester.tap(find.widgetWithText(DivineButton, 'Create'));
        await tester.pump();

        verify(
          () => bloc.add(
            const PeopleListsCreateRequested(
              name: 'Close Friends',
              initialPubkeys: [targetPubkey],
            ),
          ),
        ).called(1);
      },
    );

    testWidgets(
      'tapping Create with a null initialPubkey dispatches '
      '$PeopleListsCreateRequested with an empty initialPubkeys list',
      (tester) async {
        await tester.pumpWidget(buildSubject());

        await tester.enterText(
          find.byType(TextFormField),
          'Solo',
        );
        await tester.pump();

        await tester.tap(find.widgetWithText(DivineButton, 'Create'));
        await tester.pump();

        verify(
          () => bloc.add(
            const PeopleListsCreateRequested(
              name: 'Solo',
              // The explicit empty list is the submitted value under test.
              // ignore: avoid_redundant_argument_values
              initialPubkeys: [],
            ),
          ),
        ).called(1);
      },
    );

    testWidgets(
      'tapping Create with an empty string initialPubkey dispatches '
      '$PeopleListsCreateRequested with an empty initialPubkeys list '
      '(no throw)',
      (tester) async {
        await tester.pumpWidget(buildSubject(initialPubkey: ''));

        await tester.enterText(
          find.byType(TextFormField),
          'Solo',
        );
        await tester.pump();

        await tester.tap(find.widgetWithText(DivineButton, 'Create'));
        await tester.pump();

        verify(
          () => bloc.add(
            const PeopleListsCreateRequested(
              name: 'Solo',
              // The explicit empty list is the submitted value under test.
              // ignore: avoid_redundant_argument_values
              initialPubkeys: [],
            ),
          ),
        ).called(1);
      },
    );

    test(
      'pathWithInitialPubkey builds a URL with URI-encoded, untruncated '
      'pubkey',
      () {
        expect(
          CreatePeopleListPage.pathWithInitialPubkey(targetPubkey),
          equals(
            '${CreatePeopleListPage.path}'
            '?initialPubkey=${Uri.encodeQueryComponent(targetPubkey)}',
          ),
        );
      },
    );
  });

  group('GoRouter /people-lists/new', () {
    testWidgets(
      'route opens the create page using handwritten $GoRoute',
      (tester) async {
        final bloc = _MockPeopleListsBloc();
        addTearDown(() async => bloc.close());
        when(() => bloc.state).thenReturn(
          const PeopleListsState(
            status: PeopleListsStatus.ready,
            ownerPubkey: _ownerPubkey,
          ),
        );

        final router = GoRouter(
          initialLocation: CreatePeopleListPage.path,
          routes: [
            GoRoute(
              path: CreatePeopleListPage.path,
              name: CreatePeopleListPage.routeName,
              builder: (context, state) => const CreatePeopleListPage(),
            ),
          ],
        );

        await tester.pumpWidget(
          BlocProvider<PeopleListsBloc>.value(
            value: bloc,
            child: MaterialApp.router(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              routerConfig: router,
            ),
          ),
        );

        await tester.pump();

        expect(find.byType(CreatePeopleListPage), findsOneWidget);
      },
    );
  });
}
