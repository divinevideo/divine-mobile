// ABOUTME: Widget tests for CreatePeopleListPage full-screen form.
// ABOUTME: Covers name-entry, disabled-create guard, and create dispatching.

import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/extensions/safe_pop_extension.dart';
import 'package:openvine/features/people_lists/bloc/people_lists_bloc.dart';
import 'package:openvine/features/people_lists/view/create_people_list_page.dart';
import 'package:openvine/l10n/l10n.dart';

import '../../../helpers/go_router.dart';
import '../../../helpers/test_provider_overrides.dart';

class _MockPeopleListsBloc extends MockBloc<PeopleListsEvent, PeopleListsState>
    implements PeopleListsBloc {}

const String _ownerPubkey =
    'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';

void main() {
  setUpAll(() {
    registerFallbackValue(
      const PeopleListsCreateRequested(
        expectedOwnerPubkey: _ownerPubkey,
        name: 'fallback',
      ),
    );
  });

  const targetPubkey =
      'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';

  group(CreatePeopleListPage, () {
    late _MockPeopleListsBloc bloc;
    late MockGoRouter router;

    setUp(() {
      router = MockGoRouter();
      when(() => router.canPop()).thenReturn(true);
      bloc = _MockPeopleListsBloc();
      when(() => bloc.submit(any()))
          .thenAnswer((_) async => PeopleListsOperationResult.succeeded);
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

    Widget buildSubject({
      String? initialPubkey,
      MockAuthService? auth,
      UserList? editingList,
    }) {
      return testProviderScope(
        mockAuthService:
            auth ?? createMockAuthService(currentPublicKeyHex: _ownerPubkey),
        child: MaterialApp(
          localizationsDelegates: appLocalizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: MockGoRouterProvider(
            goRouter: router,
            child: BlocProvider<PeopleListsBloc>.value(
              value: bloc,
              child: CreatePeopleListPage(
                initialPubkey: initialPubkey,
                editingList: editingList,
              ),
            ),
          ),
        ),
      );
    }

    testWidgets(
      'creation waits for confirmation, preserves failed fields, and retries',
      (tester) async {
        final pending = Completer<PeopleListsOperationResult>();
        when(() => bloc.submit(any())).thenAnswer((_) => pending.future);
        await tester.pumpWidget(buildSubject(initialPubkey: targetPubkey));
        await tester.enterText(find.byType(TextFormField).first, 'My people');
        await tester.enterText(
          find.byType(TextFormField).last,
          'Our description',
        );
        await tester.tap(find.widgetWithText(DivineButton, 'Create'));
        await tester.pump();
        expect(find.byType(CircularProgressIndicator), findsOneWidget);
        expect(
          tester
              .widget<DivineButton>(find.widgetWithText(DivineButton, 'Create'))
              .onPressed,
          isNull,
        );
        pending.complete(PeopleListsOperationResult.failed);
        await tester.pumpAndSettle();
        expect(find.text('My people'), findsOneWidget);
        expect(find.text('Our description'), findsOneWidget);
        expect(
          find.text(
            lookupAppLocalizations(const Locale('en')).listCreateFailed,
          ),
          findsOneWidget,
        );
        when(() => bloc.submit(any()))
            .thenAnswer((_) async => PeopleListsOperationResult.succeeded);
        await tester.tap(find.widgetWithText(DivineButton, 'Create'));
        await tester.pumpAndSettle();
        final requests = verify(() => bloc.submit(captureAny())).captured
            .cast<PeopleListsCreateRequested>();
        expect(requests, hasLength(2));
        expect(requests.last.initialPubkeys, [targetPubkey]);
        expect(requests.last.description, 'Our description');
      },
    );

    testWidgets(
      'edits public metadata without creating a second list and retains rejected edits',
      (tester) async {
        final list = UserList(
          id: 'crew',
          name: 'Original',
          description: 'Original description',
          pubkeys: const [targetPubkey],
          createdAt: DateTime.utc(2026),
          updatedAt: DateTime.utc(2026),
        );
        when(() => bloc.submit(any()))
            .thenAnswer((_) async => PeopleListsOperationResult.failed);
        await tester.pumpWidget(buildSubject(editingList: list));
        expect(find.text('Original description'), findsOneWidget);
        await tester.enterText(find.byType(TextFormField).first, 'Renamed');
        await tester.enterText(find.byType(TextFormField).last, '');
        await tester.tap(find.widgetWithText(DivineButton, 'Save'));
        await tester.pumpAndSettle();
        expect(find.text('Renamed'), findsOneWidget);
        expect(
          find.text(
            lookupAppLocalizations(const Locale('en')).listUpdateFailed,
          ),
          findsOneWidget,
        );
        final request =
            verify(() => bloc.submit(captureAny())).captured.single
                as PeopleListsUpdateRequested;
        expect(request.listId, 'crew');
        expect(request.name, 'Renamed');
        expect(request.description, isEmpty);
      },
    );

    testWidgets('fits a short viewport with the keyboard open and large text', (
      tester,
    ) async {
      tester.view
        ..physicalSize = const Size(320, 480)
        ..devicePixelRatio = 1
        ..viewInsets = const FakeViewPadding(bottom: 220);
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(() {
        tester.view
          ..resetPhysicalSize()
          ..resetDevicePixelRatio()
          ..resetViewInsets();
        tester.platformDispatcher.clearAllTestValues();
      });

      await tester.pumpWidget(buildSubject());
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.widgetWithText(DivineButton, 'Create'), findsOneWidget);
    });

    group('after a confirmed save', () {
      Future<void> save(WidgetTester tester) async {
        await tester.pumpWidget(buildSubject());
        await tester.enterText(find.byType(TextFormField).first, 'Film Club');
        await tester.pump();
        await tester.tap(find.widgetWithText(DivineButton, 'Create'));
        await tester.pumpAndSettle();
      }

      testWidgets('returns to the previous route', (tester) async {
        await save(tester);

        verify(() => router.pop()).called(1);
        verifyNever(() => router.go(any()));
      });

      testWidgets('leaves for the fallback when nothing is below', (
        tester,
      ) async {
        when(() => router.canPop()).thenReturn(false);

        await save(tester);

        verify(() => router.go(defaultSafePopFallback)).called(1);
        verifyNever(() => router.pop());
      });

      testWidgets('stays put after a failed save', (tester) async {
        when(() => bloc.submit(any()))
            .thenAnswer((_) async => PeopleListsOperationResult.failed);

        await save(tester);

        verifyNever(() => router.pop());
        verifyNever(() => router.go(any()));
      });
    });

    test('exposes route name and path constants', () {
      expect(
        CreatePeopleListPage.routeName,
        equals('people-list-create'),
      );
      expect(CreatePeopleListPage.path, equals('/people-lists/new'));
    });

    testWidgets('renders name field and create button', (tester) async {
      await tester.pumpWidget(buildSubject());

      expect(find.byType(TextFormField), findsNWidgets(2));
      expect(find.widgetWithText(DivineButton, 'Create'), findsOneWidget);
    });

    testWidgets('chains the name field into the description field', (
      tester,
    ) async {
      await tester.pumpWidget(buildSubject());

      final fields = tester
          .widgetList<EditableText>(find.byType(EditableText))
          .toList();

      expect(fields.map((field) => field.textInputAction), [
        TextInputAction.next,
        TextInputAction.done,
      ]);
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

        await tester.enterText(find.byType(TextFormField).first, '    ');
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

        await tester.enterText(find.byType(TextFormField).first, 'Film Club');
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
          find.byType(TextFormField).first,
          '  Close Friends  ',
        );
        await tester.pump();

        await tester.tap(find.widgetWithText(DivineButton, 'Create'));
        await tester.pump();

        verify(
          () => bloc.submit(
            const PeopleListsCreateRequested(
              expectedOwnerPubkey: _ownerPubkey,
              name: 'Close Friends',
            ),
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
          find.byType(TextFormField).first,
          'Close Friends',
        );
        await tester.pump();

        await tester.tap(find.widgetWithText(DivineButton, 'Create'));
        await tester.pump();

        verify(
          () => bloc.submit(
            const PeopleListsCreateRequested(
              expectedOwnerPubkey: _ownerPubkey,
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
          find.byType(TextFormField).first,
          'Solo',
        );
        await tester.pump();

        await tester.tap(find.widgetWithText(DivineButton, 'Create'));
        await tester.pump();

        verify(
          () => bloc.submit(
            const PeopleListsCreateRequested(
              expectedOwnerPubkey: _ownerPubkey,
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
          find.byType(TextFormField).first,
          'Solo',
        );
        await tester.pump();

        await tester.tap(find.widgetWithText(DivineButton, 'Create'));
        await tester.pump();

        verify(
          () => bloc.submit(
            const PeopleListsCreateRequested(
              expectedOwnerPubkey: _ownerPubkey,
              name: 'Solo',
              // The explicit empty list is the submitted value under test.
              // ignore: avoid_redundant_argument_values
              initialPubkeys: [],
            ),
          ),
        ).called(1);
      },
    );

    testWidgets('actual auth changes before bloc catches up do not submit', (
      tester,
    ) async {
      String? owner = _ownerPubkey;
      final auth = createMockAuthService(currentPublicKeyHex: owner);
      when(() => auth.currentPublicKeyHex).thenAnswer((_) => owner);
      await tester.pumpWidget(buildSubject(auth: auth));
      await tester.enterText(
        find.byType(TextFormField).first,
        'Account A fields',
      );
      await tester.pump();
      owner = targetPubkey;
      await tester.tap(find.widgetWithText(DivineButton, 'Create'));
      await tester.pump();
      expect(bloc.state.activeOwnerPubkey, _ownerPubkey);
      verifyNever(() => bloc.submit(any()));
    });

    testWidgets('opening auth different from bloc owner does not submit', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildSubject(
          auth: createMockAuthService(currentPublicKeyHex: targetPubkey),
        ),
      );
      await tester.enterText(
        find.byType(TextFormField).first,
        'Account B fields',
      );
      await tester.pump();
      await tester.tap(find.widgetWithText(DivineButton, 'Create'));
      await tester.pump();
      verifyNever(() => bloc.submit(any()));
    });

    testWidgets('does not submit after the opening account changes', (
      tester,
    ) async {
      await tester.pumpWidget(buildSubject());
      await tester.enterText(
        find.byType(TextFormField).first,
        'Account A fields',
      );
      await tester.pump();
      when(() => bloc.state).thenReturn(
        const PeopleListsState(
          status: PeopleListsStatus.ready,
          ownerPubkey: targetPubkey,
        ),
      );
      await tester.tap(find.widgetWithText(DivineButton, 'Create'));
      await tester.pump();
      verifyNever(() => bloc.submit(any()));
    });

    testWidgets('does not submit after the feature is disabled', (
      tester,
    ) async {
      await tester.pumpWidget(buildSubject());
      await tester.enterText(
        find.byType(TextFormField).first,
        'Account A fields',
      );
      await tester.pump();
      when(() => bloc.state).thenReturn(
        const PeopleListsState(ownerPubkey: _ownerPubkey, enabled: false),
      );
      await tester.tap(find.widgetWithText(DivineButton, 'Create'));
      await tester.pump();
      verifyNever(() => bloc.submit(any()));
    });

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
        when(() => bloc.submit(any()))
            .thenAnswer((_) async => PeopleListsOperationResult.succeeded);
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
          testProviderScope(
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

        expect(find.byType(CreatePeopleListPage), findsOneWidget);
      },
    );
  });
}
