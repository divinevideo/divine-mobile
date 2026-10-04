// ABOUTME: Tests for the people list info sheet: what it renders, and how a
// ABOUTME: save closes it or keeps it open.

import 'dart:async';

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/features/people_lists/bloc/people_list_info_cubit.dart';
import 'package:openvine/features/people_lists/people_lists.dart';
import 'package:openvine/features/people_lists/view/people_list_info_sheet.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/utils/detached_future.dart';
import 'package:openvine/widgets/list_info_sheet/list_info_sheet.dart';
import 'package:people_lists_repository/people_lists_repository.dart';

import '../../../helpers/test_provider_overrides.dart';

class _MockPeopleListsRepository extends Mock
    implements PeopleListsRepository {}

// Full-length 64-char pubkey — never truncate.
final String _ownerPubkey = 'f' * 64;

const String _openLabel = 'Open list editor';

void main() {
  final l10n = lookupAppLocalizations(const Locale('en'));

  group('showPeopleListInfoSheet', () {
    late PeopleListsBloc bloc;
    late _MockPeopleListsRepository repository;

    setUp(() {
      repository = _MockPeopleListsRepository();
    });

    UserList list({String? description}) => UserList(
      id: 'punk-friends',
      name: 'Punk Friends',
      description: description,
      pubkeys: const [],
      createdAt: DateTime.utc(2026),
      updatedAt: DateTime.utc(2026),
    );

    void createMutationBloc(String? ownerPubkey) {
      bloc = PeopleListsBloc(
        repository: repository,
        ownerPubkeyStream: const Stream.empty(),
        repositoryStream: const Stream.empty(),
        enabledStream: const Stream.empty(),
        initialOwnerPubkey: ownerPubkey,
        clock: () => DateTime.utc(2026),
      );
      addTearDown(bloc.close);
      if (ownerPubkey != null) {
        bloc.add(
          PeopleListsRepositoryListsChanged(
            ownerPubkey: ownerPubkey,
            lists: [list()],
          ),
        );
      }
    }

    void stubUpdate(Future<PeopleListPublishResult> Function() answer) {
      when(
        () => repository.updateListInfo(
          ownerPubkey: any(named: 'ownerPubkey'),
          listId: any(named: 'listId'),
          name: any(named: 'name'),
          description: any(named: 'description'),
        ),
      ).thenAnswer((_) => answer());
    }

    Future<void> openSheet(
      WidgetTester tester, {
      String? description,
      String? ownerPubkey,
      Size surfaceSize = const Size(800, 1200),
      MockAuthService? auth,
    }) async {
      createMutationBloc(ownerPubkey ?? _ownerPubkey);
      // Tall enough that the whole form fits above the fold.
      await tester.binding.setSurfaceSize(surfaceSize);
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        testMaterialApp(
          mockAuthService:
              auth ??
              createMockAuthService(
                currentPublicKeyHex: ownerPubkey ?? _ownerPubkey,
              ),
          additionalOverrides: [
            peopleListsRepositoryProvider.overrideWithValue(repository),
          ],
          home: BlocProvider<PeopleListsBloc>.value(
            value: bloc,
            child: Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () => runDetached(
                    showPeopleListInfoSheet(
                      context,
                      list: list(description: description),
                    ),
                    'open people list info sheet',
                    logName: 'PeopleListInfoSheetTest',
                    category: LogCategory.ui,
                  ),
                  child: const Text(_openLabel),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text(_openLabel));
      await tester.pumpAndSettle();
    }

    Finder saveButton() => find.bySemanticsLabel(l10n.listSave);

    /// The save button as assistive tech reads it.
    SemanticsNode saveButtonNode() =>
        find.semantics.byLabel(l10n.listSave).evaluate().single;

    group('keyboard', () {
      testWidgets('keeps the description caret above it at a large text '
          'size', (tester) async {
        tester.platformDispatcher.textScaleFactorTestValue = 2;
        addTearDown(tester.platformDispatcher.clearAllTestValues);
        await openSheet(tester, surfaceSize: const Size(360, 640));

        const keyboardHeight = 280.0;
        tester.view.viewInsets = FakeViewPadding(
          bottom: keyboardHeight * tester.view.devicePixelRatio,
        );
        addTearDown(tester.view.resetViewInsets);
        await tester.pump();

        final description = find.byType(TextField).last;
        await tester.tap(description);
        await tester.enterText(description, 'One\nTwo\nThree\nFour');
        await tester.pumpAndSettle();

        final editable = tester.state<EditableTextState>(
          find.descendant(
            of: description,
            matching: find.byType(EditableText),
          ),
        );
        final render = editable.renderEditable;
        final caret = render.getLocalRectForCaret(
          editable.textEditingValue.selection.extent,
        );
        final caretBottom = render.localToGlobal(caret.bottomLeft).dy;
        expect(caretBottom, lessThanOrEqualTo(640 - keyboardHeight));
      });
    });

    group('renders', () {
      testWidgets("the list's name and description, nothing else", (
        tester,
      ) async {
        await openSheet(tester, description: 'The early crew');

        expect(find.text(l10n.listEditTitle), findsOneWidget);
        expect(find.text('Punk Friends'), findsOneWidget);
        expect(find.text('The early crew'), findsOneWidget);
        expect(find.text(l10n.listNameLabel), findsOneWidget);
        expect(find.text(l10n.listDescriptionLabel), findsOneWidget);
        expect(find.bySemanticsLabel(l10n.commonClose), findsOneWidget);
        expect(saveButton(), findsOneWidget);
        // A people list is always public and has no collaborators.
        expect(find.byType(DivineSwitchTile), findsNothing);
        expect(find.text(l10n.metadataCollaboratorsLabel), findsNothing);
      });

      testWidgets('nothing without a signed-in owner', (tester) async {
        createMutationBloc(null);
        await tester.pumpWidget(
          testMaterialApp(
            mockAuthService: createMockAuthService(),
            home: BlocProvider<PeopleListsBloc>.value(
              value: bloc,
              child: Builder(
                builder: (context) => Scaffold(
                  body: TextButton(
                    onPressed: () => runDetached(
                      showPeopleListInfoSheet(context, list: list()),
                      'open people list info sheet',
                      logName: 'PeopleListInfoSheetTest',
                      category: LogCategory.ui,
                    ),
                    child: const Text(_openLabel),
                  ),
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.text(_openLabel));
        await tester.pumpAndSettle();

        expect(find.text(l10n.listEditTitle), findsNothing);
      });
    });

    group('interactions', () {
      testWidgets('the close button dismisses the sheet without saving', (
        tester,
      ) async {
        await openSheet(tester);

        await tester.enterText(find.byType(TextField).first, 'Punk Family');
        await tester.tap(find.bySemanticsLabel(l10n.commonClose));
        await tester.pumpAndSettle();

        expect(find.text(l10n.listEditTitle), findsNothing);
        verifyZeroInteractions(repository);
      });

      testWidgets('the save button reads as disabled until the list has a '
          'name', (tester) async {
        final semantics = tester.ensureSemantics();
        await openSheet(tester);
        expect(
          saveButtonNode(),
          isSemantics(hasEnabledState: true, isEnabled: true),
        );

        await tester.enterText(find.byType(TextField).first, '   ');
        await tester.pump();

        expect(
          saveButtonNode(),
          isSemantics(hasEnabledState: true, isEnabled: false),
        );
        semantics.dispose();
      });
    });

    testWidgets('does not report an old account failure after dismissal', (
      tester,
    ) async {
      final auth = createMockAuthService(currentPublicKeyHex: _ownerPubkey);
      final pending = Completer<PeopleListPublishResult>();
      stubUpdate(() => pending.future);
      await openSheet(tester, auth: auth);
      await tester.tap(saveButton());
      await tester.pump();
      await tester.tap(find.bySemanticsLabel(l10n.commonClose));
      await tester.pumpAndSettle();
      when(() => auth.currentPublicKeyHex).thenReturn('b' * 64);
      pending.complete(const PeopleListPublishResult.failed());
      await tester.pumpAndSettle();
      expect(find.byType(SnackBar), findsNothing);
      expect(find.text(l10n.listUpdateFailed), findsNothing);
    });

    testWidgets('keeps a save failure visible above the scrolled fields', (
      tester,
    ) async {
      stubUpdate(() async => const PeopleListPublishResult.failed());
      await openSheet(
        tester,
        surfaceSize: const Size(800, 360),
        description: 'One\nTwo\nThree\nFour',
      );
      await tester.tap(saveButton());
      await tester.pumpAndSettle();
      await tester.drag(
        find.byType(SingleChildScrollView),
        const Offset(0, -400),
      );
      await tester.pump();
      expect(find.text(l10n.listUpdateFailed).hitTestable(), findsOneWidget);
    });

    group('saving', () {
      testWidgets('publishes the new name and description and closes', (
        tester,
      ) async {
        stubUpdate(
          () async => const PeopleListPublishResult.submitted(
            eventId: 'e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1',
          ),
        );
        await openSheet(tester, description: 'The early crew');

        await tester.enterText(find.byType(TextField).first, 'Punk Family');
        await tester.enterText(find.byType(TextField).last, 'Everyone');
        await tester.pump();
        await tester.tap(saveButton());
        await tester.pumpAndSettle();

        verify(
          () => repository.updateListInfo(
            ownerPubkey: _ownerPubkey,
            listId: 'punk-friends',
            name: 'Punk Family',
            description: 'Everyone',
          ),
        ).called(1);
        expect(find.text(l10n.listEditTitle), findsNothing);
      });

      testWidgets('shows the spinner where the button stood while the relay '
          'answers', (tester) async {
        final answer = Completer<PeopleListPublishResult>();
        addTearDown(() {
          if (!answer.isCompleted) {
            answer.complete(const PeopleListPublishResult.noop());
          }
        });
        stubUpdate(() => answer.future);
        await openSheet(tester);
        final buttonRect = tester.getRect(find.byType(ListInfoCheckButton));

        await tester.tap(saveButton());
        // The spinner never settles.
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));

        expect(find.byType(DivineCircularProgressIndicator), findsOneWidget);
        expect(
          tester.getRect(find.byType(ListInfoCheckButton)),
          equals(buttonRect),
        );
        expect(find.text(l10n.listEditTitle), findsOneWidget);

        answer.complete(
          const PeopleListPublishResult.submitted(
            eventId: 'e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1',
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text(l10n.listEditTitle), findsNothing);
      });

      testWidgets(
        'closing during a save disposes the cubit and leaves the page open',
        (tester) async {
          final answer = Completer<PeopleListPublishResult>();
          stubUpdate(() => answer.future);
          await openSheet(tester);
          final cubit = tester
              .element(find.byType(ListInfoCheckButton))
              .read<PeopleListInfoCubit>();
          await tester.tap(saveButton());
          await tester.pump();
          await tester.tap(find.bySemanticsLabel(l10n.commonClose));
          await tester.pumpAndSettle();
          expect(cubit.isClosed, isTrue);
          expect(find.text(l10n.listEditTitle), findsNothing);

          answer.complete(const PeopleListPublishResult.noop());
          await tester.pumpAndSettle();
          expect(find.text(_openLabel), findsOneWidget);
          expect(tester.takeException(), isNull);
        },
      );

      testWidgets('reports a refused save after the sheet closes', (
        tester,
      ) async {
        final answer = Completer<PeopleListPublishResult>();
        addTearDown(() {
          if (!answer.isCompleted) {
            answer.complete(const PeopleListPublishResult.noop());
          }
        });
        stubUpdate(() => answer.future);
        await openSheet(tester);

        await tester.enterText(find.byType(TextField).first, 'Punk Family');
        await tester.pump();
        await tester.tap(saveButton());
        await tester.pump();
        await tester.tap(find.bySemanticsLabel(l10n.commonClose));
        await tester.pumpAndSettle();

        answer.complete(const PeopleListPublishResult.failed());
        await tester.pumpAndSettle();

        expect(find.text(l10n.listEditTitle), findsNothing);
        expect(find.text(l10n.listUpdateFailed), findsOneWidget);
        expect(find.byType(SnackBar), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets('keeps a refused save open, with the typed values', (
        tester,
      ) async {
        stubUpdate(() async => const PeopleListPublishResult.failed());
        await openSheet(tester);

        await tester.enterText(find.byType(TextField).first, 'Punk Family');
        await tester.pump();
        await tester.tap(saveButton());
        await tester.pumpAndSettle();

        expect(find.text(l10n.listUpdateFailed), findsOneWidget);
        expect(find.text(l10n.listEditTitle), findsOneWidget);
        expect(find.text('Punk Family'), findsOneWidget);
        expect(saveButton(), findsOneWidget);
      });

      testWidgets('clears the failure once the form is edited again', (
        tester,
      ) async {
        stubUpdate(() async => const PeopleListPublishResult.failed());
        await openSheet(tester);

        await tester.tap(saveButton());
        await tester.pumpAndSettle();
        expect(find.text(l10n.listUpdateFailed), findsOneWidget);

        await tester.enterText(find.byType(TextField).first, 'Punk Family');
        await tester.pump();

        expect(find.text(l10n.listUpdateFailed), findsNothing);
      });
    });
  });
}
