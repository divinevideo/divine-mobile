// ABOUTME: Tests for the list info sheet: the form it renders, how each kind
// ABOUTME: of save closes or keeps it, and what the collaborators row allows.

import 'dart:async';

import 'package:content_blocklist_repository/content_blocklist_repository.dart';
import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:follow_repository/follow_repository.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/container_swap_host.dart';
import 'package:openvine/providers/database_provider.dart';
import 'package:openvine/providers/user_profile_providers.dart';
import 'package:openvine/services/curated_list_service.dart';
import 'package:openvine/utils/detached_future.dart';
import 'package:openvine/widgets/list_info_sheet/list_info_collaborators_row.dart';
import 'package:openvine/widgets/list_info_sheet/list_info_form.dart';
import 'package:openvine/widgets/list_info_sheet/list_info_save_button.dart';
import 'package:openvine/widgets/list_info_sheet/list_info_sheet.dart';
import 'package:openvine/widgets/user_picker_sheet.dart';
import 'package:profile_repository/profile_repository.dart';

import '../../helpers/test_provider_overrides.dart';

class _MockCuratedListService extends Mock implements CuratedListService {
  @override
  bool recoveryNeedsRepair = false;
}

class _MockProfileRepository extends Mock implements ProfileRepository {}

class _MockFollowRepository extends Mock implements FollowRepository {}

class _MockContentBlocklistRepository extends Mock
    implements ContentBlocklistRepository {}

/// Set before each test; read by [_FakeCuratedListsState].
_MockCuratedListService? _fakeService;

class _FakeCuratedListsState extends CuratedListsState {
  @override
  CuratedListService? get service => _fakeService;

  @override
  Future<List<CuratedList>> build() async => const [];

  void notifyRecoveryChanged() => state = AsyncData(List<CuratedList>.empty());

  void notifyListsChanged(List<CuratedList> lists) => state = AsyncData(lists);
}

// Full-length 64-char identifiers — never truncate.
const String _videoEventId =
    '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef';
const String _authorPubkey =
    'abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789';
const String _listId =
    'list_created_456789abcdef0123456789abcdef0123456789abcdef012345';
const String _listIdentity = '$_authorPubkey:$_listId';
final String _collaborator = 'c' * 64;
final String _otherCollaborator = 'd' * 64;

const String _openLabel = 'Open list editor';

void main() {
  final l10n = lookupAppLocalizations(const Locale('en'));

  group('showListInfoSheet', () {
    late _MockCuratedListService service;
    late VideoEvent video;

    CuratedList list({
      String name = 'Puppets',
      bool isPublic = true,
      List<String> collaborators = const [],
    }) => CuratedList(
      id: _listId,
      pubkey: _authorPubkey,
      name: name,
      videoEventIds: const [],
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
      isPublic: isPublic,
      isCollaborative: collaborators.isNotEmpty,
      allowedCollaborators: collaborators,
    );

    setUp(() {
      service = _MockCuratedListService();
      when(() => service.getListById(any())).thenAnswer((_) => list());
      _fakeService = service;
      video = VideoEvent(
        id: _videoEventId,
        pubkey: _authorPubkey,
        createdAt: 1757385263,
        content: 'Test video',
        timestamp: DateTime.fromMillisecondsSinceEpoch(1757385263 * 1000),
        videoUrl: 'https://example.com/video.mp4',
        title: 'Test Video',
      );
    });

    void stubCreate(Future<CuratedList?> Function() answer) {
      when(
        () => service.createList(
          name: any(named: 'name'),
          description: any(named: 'description'),
          isPublic: any(named: 'isPublic'),
          isCollaborative: any(named: 'isCollaborative'),
          allowedCollaborators: any(named: 'allowedCollaborators'),
        ),
      ).thenAnswer((_) => answer());
    }

    void stubUpdate(Future<bool> Function() answer) {
      when(
        () => service.updateListWithResult(
          listId: any(named: 'listId'),
          name: any(named: 'name'),
          description: any(named: 'description'),
          isPublic: any(named: 'isPublic'),
          isCollaborative: any(named: 'isCollaborative'),
          allowedCollaborators: any(named: 'allowedCollaborators'),
          onLocalSaved: any(named: 'onLocalSaved'),
          onPublicationUnconfirmed: any(named: 'onPublicationUnconfirmed'),
        ),
      ).thenAnswer((invocation) {
        (invocation.namedArguments[#onLocalSaved] as void Function()?)?.call();
        return answer().then(
          (saved) => saved
              ? const CuratedListUpdateResult.saved()
              : const CuratedListUpdateResult.failed(),
        );
      });
    }

    /// An update whose relay answer the test decides when to deliver.
    Completer<bool> stubPendingUpdate() {
      final answer = Completer<bool>();
      addTearDown(() {
        if (!answer.isCompleted) answer.complete(true);
      });
      stubUpdate(() => answer.future);
      return answer;
    }

    /// Opens the sheet from a button; [outcomes] collects what each visit
    /// returned once it has closed.
    Future<void> openSheet(
      WidgetTester tester, {
      VideoEvent? video,
      CuratedList? existingList,
      ProfileRepository? profileRepository,
      FollowRepository? followRepository,
      List<Override> overrides = const [],
      Locale? locale,
      List<ListInfoSheetOutcome>? outcomes,
      // Tall enough by default that the whole form fits above the fold.
      Size surfaceSize = const Size(800, 1200),
    }) async {
      await tester.binding.setSurfaceSize(surfaceSize);
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        testMaterialApp(
          locale: locale,
          mockAuthService: createMockAuthService(
            currentPublicKeyHex: _authorPubkey,
          ),
          mockProfileRepository: profileRepository,
          mockFollowRepository: followRepository,
          additionalOverrides: [
            curatedListsStateProvider.overrideWith(_FakeCuratedListsState.new),
            ...overrides,
          ],
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => runDetached(
                  showListInfoSheet(
                    context,
                    video: video,
                    existingList: existingList,
                  ).then((outcome) => outcomes?.add(outcome)),
                  'open list info sheet',
                  logName: 'ListInfoSheetTest',
                  category: LogCategory.ui,
                ),
                child: const Text(_openLabel),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text(_openLabel));
      await tester.pumpAndSettle();
    }

    Finder saveButton({required bool editing}) => find.bySemanticsLabel(
      editing ? l10n.listSave : l10n.listCreate,
    );

    /// The save button as assistive tech reads it.
    SemanticsNode saveButtonNode({required bool editing}) => find.semantics
        .byLabel(editing ? l10n.listSave : l10n.listCreate)
        .evaluate()
        .single;

    DivineSwitchTile visibilityTile(WidgetTester tester) =>
        tester.widget<DivineSwitchTile>(find.byType(DivineSwitchTile));

    testWidgets('unreadable recovery keeps the form readable and inert', (
      tester,
    ) async {
      service.recoveryNeedsRepair = true;
      final pending = list(collaborators: [_collaborator]).copyWith(
        pendingRepublish: true,
      );
      await openSheet(tester, existingList: pending);
      expect(find.text(l10n.listRecoveryReadOnly), findsOneWidget);
      expect(find.text(l10n.listRetrySync), findsNothing);
      expect(find.text('Puppets'), findsOneWidget);
      final fields = tester.widgetList<TextField>(find.byType(TextField));
      expect(fields.every((field) => field.enabled == false), isTrue);
      expect(visibilityTile(tester).onChanged, isNull);
      final collaboratorRow = tester.widget<InkWell>(
        find.descendant(
          of: find.byType(ListInfoCollaboratorsRow),
          matching: find.byType(InkWell),
        ),
      );
      expect(collaboratorRow.onTap, isNull);
      final semantics = tester.ensureSemantics();
      expect(
        saveButtonNode(editing: true),
        isSemantics(hasEnabledState: true, isEnabled: false),
      );
      await tester.tap(find.bySemanticsLabel(l10n.commonClose));
      await tester.pumpAndSettle();
      expect(find.byType(ListInfoForm), findsNothing);
      verifyNever(
        () => service.updateListWithResult(listId: any(named: 'listId')),
      );
      verifyNever(() => service.retryListSync(any()));
      semantics.dispose();
    });

    testWidgets('an open form follows the service recovery hold and repair', (
      tester,
    ) async {
      await openSheet(tester, existingList: list());
      expect(visibilityTile(tester).onChanged, isNotNull);
      final container = ProviderScope.containerOf(
        tester.element(find.byType(ListInfoForm)),
      );
      final notifier = container.read(
        curatedListsStateProvider.notifier,
      ) as _FakeCuratedListsState;
      service.recoveryNeedsRepair = true;
      notifier.notifyRecoveryChanged();
      await tester.pumpAndSettle();
      expect(find.text(l10n.listRecoveryReadOnly), findsOneWidget);
      expect(visibilityTile(tester).onChanged, isNull);
      service.recoveryNeedsRepair = false;
      notifier.notifyRecoveryChanged();
      await tester.pumpAndSettle();
      expect(find.text(l10n.listRecoveryReadOnly), findsNothing);
      expect(visibilityTile(tester).onChanged, isNotNull);
      expect(find.text('Puppets'), findsOneWidget);
    });

    testWidgets(
      'accepted permissions explain Sync now and block editing until settled',
      (tester) async {
        final pending = list(isPublic: false).copyWith(
          pendingVisibility: const CuratedListVisibility(
            isPublic: true,
            isCollaborative: false,
            allowedCollaborators: [],
            relayAccepted: true,
          ),
        );
        var current = pending;
        when(() => service.getListById(any())).thenAnswer((_) => current);
        when(() => service.retryListSync(_listIdentity)).thenAnswer((_) async {
          current = pending.copyWith(
            isPublic: true,
            clearPendingVisibility: true,
          );
          return true;
        });
        await openSheet(tester, existingList: pending);
        expect(find.text(l10n.listPermissionsRecoveryPending), findsOneWidget);
        expect(find.text(l10n.listRecoveryPending), findsNothing);
        expect(find.text(l10n.listRetrySync), findsOneWidget);
        expect(visibilityTile(tester).value, isTrue);
        expect(visibilityTile(tester).onChanged, isNull);
        final fields = tester.widgetList<TextField>(find.byType(TextField));
        expect(fields.every((field) => field.enabled == false), isTrue);
        await tester.tap(find.text(l10n.listRetrySync));
        await tester.pumpAndSettle();
        expect(find.text(l10n.listPermissionsRecoveryPending), findsNothing);
        expect(visibilityTile(tester).onChanged, isNotNull);
        expect(
          find.byType(ListInfoForm),
          findsOneWidget,
          reason: 'Recovery leaves the form open for intentional edits',
        );
      },
    );

    testWidgets(
      'failed recovery shows its failure alongside accepted feedback without resubmission',
      (tester) async {
        final pending = list(isPublic: false).copyWith(
          pendingVisibility: const CuratedListVisibility(
            isPublic: true,
            isCollaborative: false,
            allowedCollaborators: [],
            relayAccepted: true,
          ),
        );
        when(() => service.getListById(any())).thenReturn(pending);
        when(
          () => service.retryListSync(_listIdentity),
        ).thenAnswer((_) async => false);
        await openSheet(tester, existingList: pending);
        await tester.tap(find.text(l10n.listRetrySync));
        await tester.pumpAndSettle();
        expect(find.text(l10n.listPermissionsRecoveryPending), findsOneWidget);
        expect(find.text(l10n.listRetrySync), findsOneWidget);
        expect(find.byType(ListInfoFailureMessage), findsOneWidget);
        expect(find.text(l10n.listUpdateFailed), findsOneWidget);
        expect(visibilityTile(tester).onChanged, isNull);
        verify(() => service.retryListSync(_listIdentity)).called(1);
        verifyNever(
          () => service.updateListWithResult(listId: any(named: 'listId')),
        );
      },
    );

    testWidgets(
      'deletion-only recovery does not claim failure or disable edits',
      (tester) async {
        final pending = list(
          isPublic: false,
        ).copyWith(pendingPlaintextEventIds: ['a' * 64]);
        when(() => service.getListById(any())).thenReturn(pending);
        await openSheet(tester, existingList: pending);
        expect(find.text(l10n.listRecoveryPending), findsOneWidget);
        expect(find.text(l10n.listPermissionsRecoveryPending), findsNothing);
        expect(find.text(l10n.listRetrySync), findsOneWidget);
        expect(find.byType(ListInfoFailureMessage), findsNothing);
        expect(visibilityTile(tester).onChanged, isNotNull);
      },
    );

    testWidgets(
      'Sync preserves typed edits and still requires privacy confirmation',
      (
        tester,
      ) async {
        final saved = list().copyWith(pendingRepublish: true);
        var current = saved;
        when(() => service.getListById(any())).thenAnswer((_) => current);
        when(() => service.retryListSync(_listIdentity)).thenAnswer((_) async {
          current = saved.copyWith(pendingRepublish: false);
          return true;
        });
        await openSheet(tester, existingList: saved);
        await tester.enterText(find.byType(TextField).first, 'Draft name');
        await tester.enterText(
          find.byType(TextField).last,
          'Draft description',
        );
        await tester.tap(find.byType(DivineSwitchTile));
        await tester.pump();
        expect(visibilityTile(tester).value, isFalse);

        await tester.tap(find.text(l10n.listRetrySync));
        await tester.pumpAndSettle();

        expect(find.text('Draft name'), findsOneWidget);
        expect(find.text('Draft description'), findsOneWidget);
        expect(visibilityTile(tester).value, isFalse);
        expect(find.text(l10n.listRetrySync), findsNothing);
        verify(() => service.retryListSync(_listIdentity)).called(1);
        verifyNever(
          () => service.updateListWithResult(listId: any(named: 'listId')),
        );
        await tester.tap(saveButton(editing: true));
        await tester.pumpAndSettle();
        expect(find.text(l10n.listMakePrivateTitle), findsOneWidget);
        await tester.tap(find.text(l10n.commonCancel));
        await tester.pumpAndSettle();
        verifyNever(
          () => service.updateListWithResult(listId: any(named: 'listId')),
        );
        expect(find.text('Draft name'), findsOneWidget);
        expect(visibilityTile(tester).value, isFalse);
      },
    );

    testWidgets(
      'background delivery updates Sync without replacing visible drafts',
      (
        tester,
      ) async {
        final saved = list().copyWith(pendingRepublish: true);
        var current = saved;
        when(() => service.getListById(any())).thenAnswer((_) => current);
        await openSheet(tester, existingList: saved);
        await tester.enterText(find.byType(TextField).first, 'Draft name');
        await tester.tap(find.byType(DivineSwitchTile));
        await tester.pump();
        expect(find.text(l10n.listRetrySync), findsOneWidget);
        final container = ProviderScope.containerOf(
          tester.element(find.byType(ListInfoForm)),
        );
        final notifier = container.read(
          curatedListsStateProvider.notifier,
        ) as _FakeCuratedListsState;
        current = saved.copyWith(pendingRepublish: false);

        notifier.notifyListsChanged([current]);
        await tester.pumpAndSettle();

        expect(find.text(l10n.listRetrySync), findsNothing);
        expect(find.text(l10n.listRecoveryPending), findsNothing);
        expect(find.text('Draft name'), findsOneWidget);
        expect(visibilityTile(tester).value, isFalse);
        expect(visibilityTile(tester).onChanged, isNotNull);
        verifyNever(() => service.retryListSync(any()));
        verifyNever(
          () => service.updateListWithResult(listId: any(named: 'listId')),
        );
      },
    );

    group('renders', () {
      testWidgets('the create form, public and without collaborators', (
        tester,
      ) async {
        await openSheet(tester);

        expect(find.text(l10n.listCreateNewList), findsOneWidget);
        expect(find.text(l10n.listNameLabel), findsOneWidget);
        expect(find.text(l10n.listDescriptionLabel), findsOneWidget);
        expect(find.text(l10n.metadataCollaboratorsLabel), findsOneWidget);
        expect(find.text(l10n.listCollaboratorsNone), findsOneWidget);
        expect(find.text(l10n.listMakePublicLabel), findsOneWidget);
        expect(find.text(l10n.listMakePublicSubtitle), findsOneWidget);
        expect(visibilityTile(tester).value, isTrue);
        expect(find.bySemanticsLabel(l10n.commonClose), findsOneWidget);
        expect(saveButton(editing: false), findsOneWidget);
      });

      testWidgets("the edit form on a private list's own values", (
        tester,
      ) async {
        await openSheet(tester, existingList: list(isPublic: false));

        expect(find.text(l10n.listEditTitle), findsOneWidget);
        expect(find.text('Puppets'), findsOneWidget);
        expect(find.text(l10n.listPrivateListSubtitle), findsOneWidget);
        expect(find.text(l10n.listMakePublicSubtitle), findsNothing);
        expect(visibilityTile(tester).value, isFalse);
        expect(saveButton(editing: true), findsOneWidget);
      });

      testWidgets('reads its copy from the app localizations', (tester) async {
        final german = lookupAppLocalizations(const Locale('de'));
        // Copy that reads the same in both languages could not tell them
        // apart.
        expect(german.listCreateNewList, isNot(l10n.listCreateNewList));
        expect(german.listNameLabel, isNot(l10n.listNameLabel));

        await openSheet(tester, locale: const Locale('de'));

        expect(find.text(german.listCreateNewList), findsOneWidget);
        expect(find.text(german.listNameLabel), findsOneWidget);
        expect(find.text(l10n.listCreateNewList), findsNothing);
        expect(find.text(l10n.listNameLabel), findsNothing);
      });
    });

    group('scrolling', () {
      testWidgets('keeps a failed save in view when the form is scrolled', (
        tester,
      ) async {
        stubCreate(() async => null);
        await openSheet(tester, surfaceSize: const Size(800, 360));
        final form = find.descendant(
          of: find.byType(ListInfoForm),
          matching: find.byType(SingleChildScrollView),
        );
        await tester.enterText(find.byType(TextField).first, 'Doomed List');
        await tester.pump();
        await tester.drag(form, const Offset(0, -400));
        await tester.pump();

        // Save sits in the pinned header, so the failure it reports has to
        // stay on screen however far the form has been scrolled.
        await tester.tap(saveButton(editing: false));
        await tester.pumpAndSettle();

        expect(find.text(l10n.listCreateFailed).hitTestable(), findsOneWidget);
      });
    });

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

    group('interactions', () {
      testWidgets('the visibility switch toggles and swaps its subtitle', (
        tester,
      ) async {
        await openSheet(tester);
        expect(visibilityTile(tester).value, isTrue);

        await tester.tap(find.byType(DivineSwitchTile));
        await tester.pump();

        expect(visibilityTile(tester).value, isFalse);
        expect(find.text(l10n.listPrivateListSubtitle), findsOneWidget);
      });

      testWidgets('the close button dismisses the sheet without saving', (
        tester,
      ) async {
        await openSheet(tester, existingList: list());

        await tester.enterText(find.byType(TextField).first, 'Marionettes');
        await tester.tap(find.bySemanticsLabel(l10n.commonClose));
        await tester.pumpAndSettle();

        expect(find.text(l10n.listEditTitle), findsNothing);
        verifyZeroInteractions(service);
      });

      testWidgets('the save button reads as disabled until the list has a '
          'name', (tester) async {
        final semantics = tester.ensureSemantics();
        await openSheet(tester);
        expect(
          saveButtonNode(editing: false),
          isSemantics(hasEnabledState: true, isEnabled: false),
        );

        await tester.enterText(find.byType(TextField).first, '   ');
        await tester.pump();
        expect(
          saveButtonNode(editing: false),
          isSemantics(hasEnabledState: true, isEnabled: false),
        );

        await tester.enterText(find.byType(TextField).first, 'Fresh List');
        await tester.pump();
        expect(
          saveButtonNode(editing: false),
          isSemantics(hasEnabledState: true, isEnabled: true),
        );
        semantics.dispose();
      });
    });

    group('creating', () {
      testWidgets('creates the list and closes, adding no video', (
        tester,
      ) async {
        stubCreate(() async => list(name: 'Fresh List'));
        await openSheet(tester);

        await tester.enterText(find.byType(TextField).first, 'Fresh List');
        await tester.enterText(find.byType(TextField).last, 'Brand new');
        await tester.pump();
        await tester.tap(saveButton(editing: false));
        await tester.pumpAndSettle();

        verify(
          () => service.createList(
            name: 'Fresh List',
            description: 'Brand new',
          ),
        ).called(1);
        verifyNever(() => service.addVideoToList(any(), any()));
        expect(find.text(l10n.listCreateNewList), findsNothing);
      });

      testWidgets('saves through the list service the app holds when Create is '
          'tapped, not the one it held when the sheet opened', (
        tester,
      ) async {
        final replacement = _MockCuratedListService();
        when(
          () => replacement.createList(
            name: any(named: 'name'),
            description: any(named: 'description'),
            isPublic: any(named: 'isPublic'),
            isCollaborative: any(named: 'isCollaborative'),
            allowedCollaborators: any(named: 'allowedCollaborators'),
          ),
        ).thenAnswer((_) async => list(name: 'Fresh List'));
        await openSheet(tester);

        // The app builds a new service when its relay client is replaced.
        _fakeService = replacement;
        await tester.enterText(find.byType(TextField).first, 'Fresh List');
        await tester.pump();
        await tester.tap(saveButton(editing: false));
        await tester.pumpAndSettle();

        verify(() => replacement.createList(name: 'Fresh List')).called(1);
        verifyZeroInteractions(service);
      });

      testWidgets('creates a private list when the switch is off', (
        tester,
      ) async {
        stubCreate(() async => list(isPublic: false));
        await openSheet(tester);

        await tester.enterText(find.byType(TextField).first, 'Secret List');
        await tester.tap(find.byType(DivineSwitchTile));
        await tester.pump();
        await tester.tap(saveButton(editing: false));
        await tester.pumpAndSettle();

        verify(
          () => service.createList(name: 'Secret List', isPublic: false),
        ).called(1);
      });

      testWidgets('adds the video to the list it created', (tester) async {
        stubCreate(() async => list(name: 'Video List'));
        when(
          () => service.addVideoToList(any(), any()),
        ).thenAnswer((_) async => true);
        await openSheet(tester, video: video);

        await tester.enterText(find.byType(TextField).first, 'Video List');
        await tester.pump();
        await tester.tap(saveButton(editing: false));
        await tester.pumpAndSettle();

        verify(() => service.addVideoToList(_listIdentity, _videoEventId))
            .called(1);
        expect(find.text(l10n.listCreateNewList), findsNothing);
      });

      testWidgets('closes and hands its caller createdWithoutVideo when the '
          'created list refused the video', (tester) async {
        stubCreate(() async => list(name: 'Video List'));
        when(
          () => service.addVideoToList(any(), any()),
        ).thenAnswer((_) async => false);
        final outcomes = <ListInfoSheetOutcome>[];
        await openSheet(tester, video: video, outcomes: outcomes);

        await tester.enterText(find.byType(TextField).first, 'Video List');
        await tester.pump();
        await tester.tap(saveButton(editing: false));
        await tester.pumpAndSettle();

        // The list exists, so the sheet does not invite a second one, and
        // the caller, not a snackbar the caller might cover, says so.
        expect(find.text(l10n.listCreateNewList), findsNothing);
        expect(find.byType(SnackBar), findsNothing);
        expect(outcomes, [ListInfoSheetOutcome.createdWithoutVideo]);
      });

      testWidgets('waits for creation after closing and returns a refused '
          'video outcome', (tester) async {
        final created = Completer<CuratedList?>();
        addTearDown(() {
          if (!created.isCompleted) created.complete(null);
        });
        stubCreate(() => created.future);
        when(
          () => service.addVideoToList(any(), any()),
        ).thenAnswer((_) async => false);
        final outcomes = <ListInfoSheetOutcome>[];
        await openSheet(tester, video: video, outcomes: outcomes);

        await tester.enterText(find.byType(TextField).first, 'Video List');
        await tester.pump();
        await tester.tap(saveButton(editing: false));
        await tester.pump();
        await tester.tap(find.bySemanticsLabel(l10n.commonClose));
        await tester.pumpAndSettle();

        expect(find.text(l10n.listCreateNewList), findsNothing);
        expect(outcomes, isEmpty);

        created.complete(list(name: 'Video List'));
        await tester.pumpAndSettle();

        verify(() => service.addVideoToList(_listIdentity, _videoEventId))
            .called(1);
        expect(outcomes, [ListInfoSheetOutcome.createdWithoutVideo]);
        expect(tester.takeException(), isNull);
      });

      testWidgets('reports a creation failure after the sheet closes', (
        tester,
      ) async {
        final created = Completer<CuratedList?>();
        addTearDown(() {
          if (!created.isCompleted) created.complete(null);
        });
        stubCreate(() => created.future);
        await openSheet(tester);

        await tester.enterText(find.byType(TextField).first, 'Video List');
        await tester.pump();
        await tester.tap(saveButton(editing: false));
        await tester.pump();
        await tester.tap(find.bySemanticsLabel(l10n.commonClose));
        await tester.pumpAndSettle();

        created.complete(null);
        await tester.pumpAndSettle();

        expect(find.text(l10n.listCreateFailed), findsOneWidget);
        expect(find.text(l10n.listCreateNewList), findsNothing);
        expect(tester.takeException(), isNull);
      });

      testWidgets('hands its caller saved when the created list took the '
          'video, and dismissed when closed from the X', (tester) async {
        stubCreate(() async => list(name: 'Video List'));
        when(
          () => service.addVideoToList(any(), any()),
        ).thenAnswer((_) async => true);
        final outcomes = <ListInfoSheetOutcome>[];
        await openSheet(tester, video: video, outcomes: outcomes);

        await tester.enterText(find.byType(TextField).first, 'Video List');
        await tester.pump();
        await tester.tap(saveButton(editing: false));
        await tester.pumpAndSettle();
        expect(outcomes, [ListInfoSheetOutcome.saved]);

        await tester.tap(find.text(_openLabel));
        await tester.pumpAndSettle();
        await tester.tap(find.bySemanticsLabel(l10n.commonClose));
        await tester.pumpAndSettle();
        expect(outcomes.last, ListInfoSheetOutcome.dismissed);
      });

      testWidgets('stays open and says so when the list cannot be created', (
        tester,
      ) async {
        stubCreate(() async => null);
        await openSheet(tester, video: video);

        await tester.enterText(find.byType(TextField).first, 'Doomed List');
        await tester.pump();
        await tester.tap(saveButton(editing: false));
        await tester.pumpAndSettle();

        expect(find.text(l10n.listCreateFailed), findsOneWidget);
        expect(find.text(l10n.listCreateNewList), findsOneWidget);
        expect(find.text('Doomed List'), findsOneWidget);
        verifyNever(() => service.addVideoToList(any(), any()));
      });

      testWidgets('does not report a failure again when the sheet is closed '
          'after showing it', (tester) async {
        stubCreate(() async => null);
        await openSheet(tester);

        await tester.enterText(find.byType(TextField).first, 'Doomed List');
        await tester.pump();
        await tester.tap(saveButton(editing: false));
        await tester.pumpAndSettle();
        expect(find.text(l10n.listCreateFailed), findsOneWidget);

        await tester.tap(find.bySemanticsLabel(l10n.commonClose));
        await tester.pumpAndSettle();

        expect(find.text(l10n.listCreateNewList), findsNothing);
        expect(find.text(l10n.listCreateFailed), findsNothing);
        expect(find.byType(SnackBar), findsNothing);
      });

      testWidgets('clears the failure once the form is edited again', (
        tester,
      ) async {
        stubCreate(() async => null);
        await openSheet(tester);

        await tester.enterText(find.byType(TextField).first, 'Doomed List');
        await tester.pump();
        await tester.tap(saveButton(editing: false));
        await tester.pumpAndSettle();
        expect(find.text(l10n.listCreateFailed), findsOneWidget);

        await tester.enterText(find.byType(TextField).first, 'Second Try');
        await tester.pump();

        expect(find.text(l10n.listCreateFailed), findsNothing);
      });
    });

    for (final creating in [true, false]) {
      testWidgets(
        creating
            ? 'account container replacement cancels a dismissed creation before adding video'
            : 'account container replacement safely settles a dismissed rename',
        (tester) async {
          final controller = AccountSwitchController();
          final first = ProviderContainer(
            overrides: [
              ...getStandardTestOverrides(
                mockAuthService: createMockAuthService(
                  currentPublicKeyHex: _authorPubkey,
                ),
              ),
              curatedListsStateProvider.overrideWith(
                _FakeCuratedListsState.new,
              ),
            ],
          );
          final next = ProviderContainer(
            overrides: [
              ...getStandardTestOverrides(
                mockAuthService: createMockAuthService(
                  currentPublicKeyHex: 'e' * 64,
                ),
              ),
              curatedListsStateProvider.overrideWith(
                _FakeCuratedListsState.new,
              ),
            ],
          );
          final created = Completer<CuratedList?>();
          final renamed = Completer<bool>();
          addTearDown(() {
            if (!created.isCompleted) created.complete(null);
            if (!renamed.isCompleted) renamed.complete(true);
          });
          if (creating) {
            stubCreate(() => created.future);
          } else {
            stubUpdate(() => renamed.future);
          }
          final outcomes = <ListInfoSheetOutcome>[];
          await tester.binding.setSurfaceSize(const Size(800, 1200));
          addTearDown(() => tester.binding.setSurfaceSize(null));
          await tester.pumpWidget(
            ContainerSwapHost(
              initialContainer: first,
              controller: controller,
              child: MaterialApp(
                localizationsDelegates: appLocalizationsDelegates,
                supportedLocales: AppLocalizations.supportedLocales,
                home: Builder(
                  builder: (context) => Scaffold(
                    body: TextButton(
                      child: const Text(_openLabel),
                      onPressed: () => runDetached(
                        showListInfoSheet(
                          context,
                          existingList: creating ? null : list(),
                          video: creating ? video : null,
                        ).then(outcomes.add),
                        'open editor during account swap',
                        logName: 'ListInfoSheetTest',
                        category: LogCategory.ui,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.tap(find.text(_openLabel));
          await tester.pumpAndSettle();
          await tester.enterText(
            find.byType(TextField).first,
            'Account A draft',
          );
          await tester.pump();
          await tester.tap(saveButton(editing: !creating));
          await tester.pump();
          if (creating) {
            await tester.tap(find.bySemanticsLabel(l10n.commonClose));
          }
          await tester.pumpAndSettle();
          expect(outcomes, isEmpty);
          await controller.swapTo(next);
          await tester.pumpAndSettle();
          expect(() => first.read(authServiceProvider), throwsStateError);
          if (creating) {
            created.complete(list());
          } else {
            renamed.complete(false);
          }
          await tester.pumpAndSettle();
          expect(outcomes, [ListInfoSheetOutcome.dismissed]);
          expect(find.byType(SnackBar), findsNothing);
          verifyNever(() => service.addVideoToList(any(), any()));
          expect(tester.takeException(), isNull);
        },
      );
    }

    group('editing', () {
      for (final locale in const [Locale('en'), Locale('es')]) {
        testWidgets(
          'private size rejection preserves drafts in ${locale.languageCode}',
          (tester) async {
            final localized = lookupAppLocalizations(locale);
            when(
              () => service.updateListWithResult(
                listId: any(named: 'listId'),
                name: any(named: 'name'),
                description: any(named: 'description'),
                isPublic: any(named: 'isPublic'),
                isCollaborative: any(named: 'isCollaborative'),
                allowedCollaborators: any(named: 'allowedCollaborators'),
                onLocalSaved: any(named: 'onLocalSaved'),
                onPublicationUnconfirmed: any(
                  named: 'onPublicationUnconfirmed',
                ),
              ),
            ).thenAnswer(
              (_) async => const CuratedListUpdateResult.privateListFull(),
            );
            await openSheet(tester, existingList: list(), locale: locale);
            await tester.enterText(
              find.byType(TextField).first,
              'Unsaved name',
            );
            await tester.enterText(
              find.byType(TextField).last,
              'Unsaved description',
            );
            await tester.tap(find.byType(DivineSwitchTile));
            await tester.pump();
            await tester.tap(find.bySemanticsLabel(localized.listSave));
            await tester.pumpAndSettle();
            await tester.tap(find.text(localized.listContinue));
            await tester.pumpAndSettle();
            expect(
              find.text(localized.listPrivateConversionTooLarge),
              findsOneWidget,
            );
            expect(find.text(localized.listUpdateFailed), findsNothing);
            expect(find.text('Unsaved name'), findsOneWidget);
            expect(find.text('Unsaved description'), findsOneWidget);
            expect(visibilityTile(tester).value, isFalse);
            expect(visibilityTile(tester).onChanged, isNotNull);
            expect(find.text(localized.listRetrySync), findsNothing);
            expect(find.byType(ListInfoForm), findsOneWidget);
            expect(find.text(localized.listPrivateFull), findsNothing);
          },
        );
      }

      testWidgets(
        'a late size rejection after dismissal does not claim to retain drafts',
        (tester) async {
          final answer = Completer<CuratedListUpdateResult>();
          addTearDown(() {
            if (!answer.isCompleted) {
              answer.complete(const CuratedListUpdateResult.failed());
            }
          });
          when(
            () => service.updateListWithResult(
              listId: any(named: 'listId'),
              name: any(named: 'name'),
              description: any(named: 'description'),
              isPublic: any(named: 'isPublic'),
              isCollaborative: any(named: 'isCollaborative'),
              allowedCollaborators: any(named: 'allowedCollaborators'),
              onLocalSaved: any(named: 'onLocalSaved'),
              onPublicationUnconfirmed: any(named: 'onPublicationUnconfirmed'),
            ),
          ).thenAnswer((_) => answer.future);
          final outcomes = <ListInfoSheetOutcome>[];
          await openSheet(tester, existingList: list(), outcomes: outcomes);
          await tester.enterText(find.byType(TextField).first, 'Unsaved name');
          await tester.tap(find.byType(DivineSwitchTile));
          await tester.pump();
          await tester.tap(saveButton(editing: true));
          await tester.pumpAndSettle();
          await tester.tap(find.text(l10n.listContinue));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 400));
          await tester.tap(find.bySemanticsLabel(l10n.commonClose));
          await tester.pumpAndSettle();
          expect(find.byType(ListInfoForm), findsNothing);
          expect(outcomes, isEmpty);
          answer.complete(const CuratedListUpdateResult.privateListFull());
          await tester.pumpAndSettle();
          expect(outcomes, [ListInfoSheetOutcome.dismissed]);
          expect(find.text(l10n.listUpdateFailed), findsOneWidget);
          expect(find.text(l10n.listPrivateConversionTooLarge), findsNothing);
          expect(find.text(l10n.listPrivateFull), findsNothing);
          expect(tester.takeException(), isNull);
        },
      );

      testWidgets(
        'an unconfirmed privacy change keeps the draft and reports uncertainty once',
        (tester) async {
          when(
            () => service.updateListWithResult(
              listId: any(named: 'listId'),
              name: any(named: 'name'),
              description: any(named: 'description'),
              isPublic: any(named: 'isPublic'),
              isCollaborative: any(named: 'isCollaborative'),
              allowedCollaborators: any(named: 'allowedCollaborators'),
              onLocalSaved: any(named: 'onLocalSaved'),
              onPublicationUnconfirmed: any(named: 'onPublicationUnconfirmed'),
            ),
          ).thenAnswer((invocation) async {
            (invocation.namedArguments[#onPublicationUnconfirmed]
                as void Function())();
            return const CuratedListUpdateResult.failed();
          });
          await openSheet(tester, existingList: list(isPublic: false));
          await tester.tap(find.byType(DivineSwitchTile));
          await tester.pump();
          await tester.tap(saveButton(editing: true));
          await tester.pumpAndSettle();
          await tester.tap(find.text(l10n.listContinue));
          await tester.pumpAndSettle();
          expect(find.text(l10n.listPermissionsUnconfirmed), findsOneWidget);
          expect(find.text(l10n.listUpdateFailed), findsNothing);
          expect(find.text(l10n.listEditTitle), findsOneWidget);
          expect(visibilityTile(tester).value, isTrue);
          await tester.tap(find.bySemanticsLabel(l10n.commonClose));
          await tester.pumpAndSettle();
          expect(find.text(l10n.listPermissionsUnconfirmed), findsNothing);
          expect(find.byType(SnackBar), findsNothing);
        },
      );

      testWidgets(
        'reports an unconfirmed permission change after manual dismissal',
        (tester) async {
          final answer = Completer<bool>();
          void Function()? unconfirmed;
          addTearDown(() {
            if (!answer.isCompleted) answer.complete(false);
          });
          when(
            () => service.updateListWithResult(
              listId: any(named: 'listId'),
              name: any(named: 'name'),
              description: any(named: 'description'),
              isPublic: any(named: 'isPublic'),
              isCollaborative: any(named: 'isCollaborative'),
              allowedCollaborators: any(named: 'allowedCollaborators'),
              onLocalSaved: any(named: 'onLocalSaved'),
              onPublicationUnconfirmed: any(named: 'onPublicationUnconfirmed'),
            ),
          ).thenAnswer((invocation) {
            unconfirmed =
                invocation.namedArguments[#onPublicationUnconfirmed]
                    as void Function()?;
            return answer.future.then(
              (saved) => saved
                  ? const CuratedListUpdateResult.saved()
                  : const CuratedListUpdateResult.failed(),
            );
          });
          await openSheet(tester, existingList: list(isPublic: false));
          await tester.tap(find.byType(DivineSwitchTile));
          await tester.pump();
          await tester.tap(saveButton(editing: true));
          await tester.pumpAndSettle();
          await tester.tap(find.text(l10n.listContinue));
          await tester.pump();
          await tester.tap(find.bySemanticsLabel(l10n.commonClose));
          await tester.pumpAndSettle();
          unconfirmed!();
          answer.complete(false);
          await tester.pumpAndSettle();
          expect(find.text(l10n.listPermissionsUnconfirmed), findsOneWidget);
          expect(find.text(l10n.listUpdateFailed), findsNothing);
          expect(find.text(l10n.listEditTitle), findsNothing);
        },
      );

      testWidgets('asks before publishing a private list', (tester) async {
        stubUpdate(() async => true);
        await openSheet(tester, existingList: list(isPublic: false));

        await tester.tap(find.byType(DivineSwitchTile));
        await tester.pump();
        await tester.tap(saveButton(editing: true));
        await tester.pumpAndSettle();

        expect(find.text(l10n.listMakePublicTitle), findsOneWidget);
        expect(find.text(l10n.listMakePublicWarning), findsOneWidget);
        verifyZeroInteractions(service);

        await tester.tap(find.text(l10n.listContinue));
        await tester.pumpAndSettle();

        verify(
          () => service.updateListWithResult(
            listId: _listIdentity,
            name: 'Puppets',
            description: '',
            isPublic: true,
            onLocalSaved: any(named: 'onLocalSaved'),
            onPublicationUnconfirmed: any(named: 'onPublicationUnconfirmed'),
          ),
        ).called(1);
      });

      testWidgets('asks before hiding a public list', (tester) async {
        stubUpdate(() async => true);
        await openSheet(tester, existingList: list());

        await tester.tap(find.byType(DivineSwitchTile));
        await tester.pump();
        await tester.tap(saveButton(editing: true));
        await tester.pumpAndSettle();

        expect(find.text(l10n.listMakePrivateTitle), findsOneWidget);
        expect(find.text(l10n.listMakePrivateWarning), findsOneWidget);
      });

      testWidgets('saves nothing when the visibility change is cancelled', (
        tester,
      ) async {
        stubUpdate(() async => true);
        await openSheet(tester, existingList: list(isPublic: false));

        await tester.tap(find.byType(DivineSwitchTile));
        await tester.pump();
        await tester.tap(saveButton(editing: true));
        await tester.pumpAndSettle();
        await tester.tap(find.text(l10n.commonCancel));
        await tester.pumpAndSettle();

        verifyZeroInteractions(service);
        expect(find.text(l10n.listEditTitle), findsOneWidget);
        expect(visibilityTile(tester).value, isTrue);
      });

      testWidgets('closes on a rename before any relay has answered, then '
          'reports the relay failure on the screen underneath', (tester) async {
        final answer = stubPendingUpdate();
        await openSheet(tester, existingList: list());

        await tester.enterText(find.byType(TextField).first, 'Marionettes');
        await tester.pump();
        await tester.tap(saveButton(editing: true));
        await tester.pumpAndSettle();

        verify(
          () => service.updateListWithResult(
            listId: _listIdentity,
            name: 'Marionettes',
            description: '',
            onLocalSaved: any(named: 'onLocalSaved'),
            onPublicationUnconfirmed: any(named: 'onPublicationUnconfirmed'),
          ),
        ).called(1);
        expect(find.text(l10n.listEditTitle), findsNothing);
        expect(find.text(l10n.listUpdateFailed), findsNothing);

        answer.complete(false);
        await tester.pumpAndSettle();

        expect(find.text(l10n.listUpdateFailed), findsOneWidget);
      });

      testWidgets('reports nothing when a relay accepts the rename', (
        tester,
      ) async {
        final answer = stubPendingUpdate();
        await openSheet(tester, existingList: list());

        await tester.enterText(find.byType(TextField).first, 'Marionettes');
        await tester.pump();
        await tester.tap(saveButton(editing: true));
        await tester.pumpAndSettle();
        expect(find.text(l10n.listEditTitle), findsNothing);

        answer.complete(true);
        await tester.pumpAndSettle();

        expect(find.text(l10n.listUpdateFailed), findsNothing);
        expect(find.byType(SnackBar), findsNothing);
      });

      testWidgets('waits on the relay before closing a visibility change', (
        tester,
      ) async {
        final answer = stubPendingUpdate();
        await openSheet(tester, existingList: list(isPublic: false));
        final buttonRect = tester.getRect(find.byType(ListInfoSaveButton));

        await tester.tap(find.byType(DivineSwitchTile));
        await tester.pump();
        await tester.tap(saveButton(editing: true));
        await tester.pumpAndSettle();
        await tester.tap(find.text(l10n.listContinue));
        // The spinner that replaces the save button never settles.
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));

        verify(
          () => service.updateListWithResult(
            listId: _listIdentity,
            name: 'Puppets',
            description: '',
            isPublic: true,
            onLocalSaved: any(named: 'onLocalSaved'),
            onPublicationUnconfirmed: any(named: 'onPublicationUnconfirmed'),
          ),
        ).called(1);
        expect(find.text(l10n.listEditTitle), findsOneWidget);
        expect(find.byType(DivineCircularProgressIndicator), findsOneWidget);
        // The spinner stands where the button stood.
        expect(
          tester.getRect(find.byType(ListInfoSaveButton)),
          equals(buttonRect),
        );

        answer.complete(true);
        await tester.pumpAndSettle();

        expect(find.text(l10n.listEditTitle), findsNothing);
      });

      testWidgets('reports a refused visibility change after the sheet '
          'closes', (tester) async {
        final answer = stubPendingUpdate();
        await openSheet(tester, existingList: list(isPublic: false));

        await tester.tap(find.byType(DivineSwitchTile));
        await tester.pump();
        await tester.tap(saveButton(editing: true));
        await tester.pumpAndSettle();
        await tester.tap(find.text(l10n.listContinue));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        await tester.tap(find.bySemanticsLabel(l10n.commonClose));
        await tester.pumpAndSettle();

        answer.complete(false);
        await tester.pumpAndSettle();

        expect(find.text(l10n.listUpdateFailed), findsOneWidget);
        expect(find.text(l10n.listEditTitle), findsNothing);
        expect(tester.takeException(), isNull);
      });

      testWidgets('keeps a rejected visibility change open for a retry', (
        tester,
      ) async {
        final semantics = tester.ensureSemantics();
        final answer = stubPendingUpdate();
        await openSheet(tester, existingList: list(isPublic: false));

        await tester.enterText(find.byType(TextField).first, 'Marionettes');
        await tester.tap(find.byType(DivineSwitchTile));
        await tester.pump();
        await tester.tap(saveButton(editing: true));
        await tester.pumpAndSettle();
        await tester.tap(find.text(l10n.listContinue));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));

        answer.complete(false);
        await tester.pumpAndSettle();

        expect(find.text(l10n.listUpdateFailed), findsOneWidget);
        // The service leaves isPublic at its old value on a rejected publish,
        // so the flip only survives if the form holding it is still on
        // screen with the typed name intact.
        expect(find.text(l10n.listEditTitle), findsOneWidget);
        expect(find.text('Marionettes'), findsOneWidget);
        expect(visibilityTile(tester).value, isTrue);
        expect(
          saveButtonNode(editing: true),
          isSemantics(hasEnabledState: true, isEnabled: true),
        );
        semantics.dispose();
      });

      testWidgets('does not report a rejected visibility change again when '
          'the sheet is closed after showing it', (tester) async {
        final answer = stubPendingUpdate();
        await openSheet(tester, existingList: list(isPublic: false));

        await tester.tap(find.byType(DivineSwitchTile));
        await tester.pump();
        await tester.tap(saveButton(editing: true));
        await tester.pumpAndSettle();
        await tester.tap(find.text(l10n.listContinue));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        answer.complete(false);
        await tester.pumpAndSettle();
        expect(find.text(l10n.listUpdateFailed), findsOneWidget);

        await tester.tap(find.bySemanticsLabel(l10n.commonClose));
        await tester.pumpAndSettle();

        expect(find.text(l10n.listEditTitle), findsNothing);
        expect(find.text(l10n.listUpdateFailed), findsNothing);
        expect(find.byType(SnackBar), findsNothing);
      });
    });

    group('collaborators', () {
      Finder collaboratorsRow() => find.byType(ListInfoCollaboratorsRow);

      testWidgets('names a collaborator by their fallback name until the '
          'profile resolves', (tester) async {
        await openSheet(
          tester,
          existingList: list(collaborators: [_collaborator]),
        );

        expect(find.text(l10n.listCollaboratorsNone), findsNothing);
        expect(
          find.descendant(
            of: collaboratorsRow(),
            matching: find.text(
              UserProfile.defaultDisplayNameFor(_collaborator),
            ),
          ),
          findsOneWidget,
        );
      });

      testWidgets("joins the collaborators' names with the locale's own "
          'separator', (tester) async {
        // Japanese lists names with 、, so a Latin ", " cannot pass here.
        final ja = lookupAppLocalizations(const Locale('ja'));
        await openSheet(
          tester,
          existingList: list(
            collaborators: [_collaborator, _otherCollaborator],
          ),
          locale: const Locale('ja'),
        );

        final names = [
          UserProfile.defaultDisplayNameFor(_collaborator),
          UserProfile.defaultDisplayNameFor(_otherCollaborator),
        ];
        expect(ja.listMemberNamesSeparator, isNot(', '));
        expect(
          find.descendant(
            of: collaboratorsRow(),
            matching: find.text(names.join(ja.listMemberNamesSeparator)),
          ),
          findsOneWidget,
        );
      });

      testWidgets(
        'removes an unresolved collaborator through the picker before saving',
        (tester) async {
          stubUpdate(() async => true);
          final profiles = _MockProfileRepository();
          when(
            () => profiles.getCachedProfiles(pubkeys: any(named: 'pubkeys')),
          ).thenAnswer((_) async => []);
          final follows = _MockFollowRepository();
          when(() => follows.followingPubkeys).thenReturn([]);
          when(
            follows.streamMyFollowers,
          ).thenAnswer((_) => Stream.value(<String>[]));
          await openSheet(
            tester,
            existingList: list(collaborators: [_collaborator]),
            profileRepository: profiles,
            followRepository: follows,
            overrides: [
              vanishedProfilePubkeysProvider.overrideWith(
                (ref) => Stream.value(const <String>{}),
              ),
              userProfileReactiveProvider(
                _collaborator,
              ).overrideWith((ref) => Stream.value(null)),
            ],
          );
          await tester.tap(collaboratorsRow());
          await tester.pumpAndSettle();
          final fallback = UserProfile.defaultDisplayNameFor(_collaborator);
          expect(
            find.bySemanticsLabel(
              l10n.userPickerRemoveSelectionSemantics(fallback),
            ),
            findsOneWidget,
          );
          await tester.tap(
            find.bySemanticsLabel(
              l10n.userPickerRemoveSelectionSemantics(fallback),
            ),
          );
          await tester.pumpAndSettle();
          await tester.tap(
            find.bySemanticsLabel(l10n.userPickerConfirmSemanticLabel),
          );
          await tester.pumpAndSettle();
          await tester.tap(saveButton(editing: true));
          await tester.pumpAndSettle();
          verify(
            () => service.updateListWithResult(
              listId: _listIdentity,
              name: 'Puppets',
              description: '',
              isCollaborative: false,
              allowedCollaborators: const [],
              onLocalSaved: any(named: 'onLocalSaved'),
              onPublicationUnconfirmed: any(named: 'onPublicationUnconfirmed'),
            ),
          ).called(1);
        },
      );

      testWidgets('opens the picker from a public list', (tester) async {
        await openSheet(tester);

        await tester.tap(collaboratorsRow());
        await tester.pumpAndSettle();

        final picker = tester.widget<UserPickerSheet>(
          find.byType(UserPickerSheet),
        );
        expect(picker.title, equals(l10n.listAddCollaboratorTitle));
        expect(
          picker.filterMode,
          equals(UserPickerFilterMode.mutualFollowsOnly),
        );
      });

      testWidgets('opens the picker from the keyboard', (tester) async {
        await openSheet(tester);

        bool rowHasFocus() =>
            FocusManager.instance.primaryFocus?.context
                ?.findAncestorWidgetOfExactType<ListInfoCollaboratorsRow>() !=
            null;
        for (var i = 0; i < 12 && !rowHasFocus(); i++) {
          await tester.sendKeyEvent(LogicalKeyboardKey.tab);
          await tester.pump();
        }
        expect(rowHasFocus(), isTrue, reason: 'Tab never reached the row');

        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pumpAndSettle();

        expect(find.byType(UserPickerSheet), findsOneWidget);
      });

      testWidgets('shows the people picked and saves them with the list', (
        tester,
      ) async {
        final mutual = UserProfile(
          pubkey: _collaborator,
          name: 'Mutual Friend',
          rawData: const {'name': 'Mutual Friend'},
          createdAt: DateTime(2026),
          eventId: 'e' * 64,
        );
        final profiles = _MockProfileRepository();
        when(
          () => profiles.getCachedProfile(pubkey: any(named: 'pubkey')),
        ).thenAnswer((_) async => mutual);
        when(
          () => profiles.getCachedProfiles(pubkeys: any(named: 'pubkeys')),
        ).thenAnswer((_) async => [mutual]);
        when(
          () => profiles.watchProfile(pubkey: any(named: 'pubkey')),
        ).thenAnswer((_) => Stream.value(mutual));
        final follows = _MockFollowRepository();
        when(() => follows.followingPubkeys).thenReturn([_collaborator]);
        when(
          () => follows.followingStream,
        ).thenAnswer((_) => Stream.value([_collaborator]));
        when(() => follows.isInitialized).thenReturn(true);
        when(() => follows.followingCount).thenReturn(1);
        when(follows.getMyFollowers).thenAnswer((_) async => [_collaborator]);
        when(
          follows.streamMyFollowers,
        ).thenAnswer((_) => Stream.value([_collaborator]));
        final blocklist = _MockContentBlocklistRepository();
        when(() => blocklist.shouldFilterFromFeeds(any())).thenReturn(false);
        stubCreate(() async => list(collaborators: [_collaborator]));

        await openSheet(
          tester,
          profileRepository: profiles,
          followRepository: follows,
          overrides: [
            contentBlocklistRepositoryProvider.overrideWithValue(blocklist),
            vanishedProfilePubkeysProvider.overrideWith(
              (ref) => Stream.value(const <String>{}),
            ),
          ],
        );
        await tester.enterText(find.byType(TextField).first, 'Shared List');
        await tester.pump();

        await tester.tap(collaboratorsRow());
        await tester.pumpAndSettle();
        await tester.tap(
          find.descendant(
            of: find.byType(UserPickerSheet),
            matching: find.text('Mutual Friend'),
          ),
        );
        await tester.pump();
        await tester.tap(
          find.bySemanticsLabel(l10n.userPickerConfirmSemanticLabel),
        );
        await tester.pumpAndSettle();

        expect(find.byType(UserPickerSheet), findsNothing);
        expect(
          find.descendant(
            of: collaboratorsRow(),
            matching: find.text('Mutual Friend'),
          ),
          findsOneWidget,
        );

        await tester.tap(saveButton(editing: false));
        await tester.pumpAndSettle();

        verify(
          () => service.createList(
            name: 'Shared List',
            isCollaborative: true,
            allowedCollaborators: [_collaborator],
          ),
        ).called(1);
      });

      testWidgets('is inert, and shows none, while the list is private', (
        tester,
      ) async {
        await openSheet(
          tester,
          existingList: list(collaborators: [_collaborator]),
        );

        await tester.tap(find.byType(DivineSwitchTile));
        await tester.pump();

        expect(
          find.descendant(
            of: collaboratorsRow(),
            matching: find.text(l10n.listCollaboratorsNone),
          ),
          findsOneWidget,
        );

        await tester.tap(collaboratorsRow());
        await tester.pumpAndSettle();

        expect(find.byType(UserPickerSheet), findsNothing);
      });

      testWidgets('drops them from a list saved as private', (tester) async {
        stubUpdate(() async => true);
        await openSheet(
          tester,
          existingList: list(collaborators: [_collaborator]),
        );

        await tester.tap(find.byType(DivineSwitchTile));
        await tester.pump();
        await tester.tap(saveButton(editing: true));
        await tester.pumpAndSettle();
        expect(
          find.textContaining(l10n.listPrivateCollaboratorsWarning),
          findsOneWidget,
        );
        await tester.tap(find.text(l10n.listContinue));
        await tester.pumpAndSettle();

        verify(
          () => service.updateListWithResult(
            listId: _listIdentity,
            name: 'Puppets',
            description: '',
            isPublic: false,
            isCollaborative: false,
            allowedCollaborators: const [],
            onLocalSaved: any(named: 'onLocalSaved'),
            onPublicationUnconfirmed: any(named: 'onPublicationUnconfirmed'),
          ),
        ).called(1);
      });
    });
  });
}
