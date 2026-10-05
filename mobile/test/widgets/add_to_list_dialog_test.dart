// ABOUTME: Tests for SelectListDialog and its list creation entry point
// ABOUTME: Verifies list selection, list item interactions, and list creation form

import 'dart:async';

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/services/curated_list_service.dart';
import 'package:openvine/widgets/add_to_list_dialog.dart';
import 'package:openvine/widgets/list_info_sheet/list_info_form.dart';

import '../helpers/test_provider_overrides.dart';

class _MockCuratedListService extends Mock implements CuratedListService {}

/// Test data for the fake notifier - set before each test
List<CuratedList> _fakeLists = [];
bool _failInitialization = false;
int _initializationAttempts = 0;

Finder _divineIcon(DivineIconName name) =>
    find.byWidgetPredicate((w) => w is DivineIcon && w.icon == name);

/// Mock service for the fake notifier - set before tests that need interactions
_MockCuratedListService? _fakeService;

/// Fake notifier that provides test data for curatedListsStateProvider
class _FakeCuratedListsState extends CuratedListsState {
  @override
  CuratedListService? get service => _fakeService;

  @override
  Future<List<CuratedList>> build() async {
    _initializationAttempts++;
    if (_failInitialization && _initializationAttempts == 1) {
      throw Exception('local list initialization failed');
    }
    return _fakeLists;
  }

  void replaceLists(List<CuratedList> lists) => state = AsyncData(lists);
}

void main() {
  setUp(() {
    _failInitialization = false;
    _initializationAttempts = 0;
  });
  group(SelectListDialog, () {
    late VideoEvent testVideo;
    late _MockCuratedListService mockListService;

    setUp(() {
      testVideo = VideoEvent(
        id: '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef',
        pubkey:
            'abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789',
        createdAt: 1757385263,
        content: 'Test video',
        timestamp: DateTime.fromMillisecondsSinceEpoch(1757385263 * 1000),
        videoUrl: 'https://example.com/video.mp4',
        title: 'Test Video',
      );
      _fakeLists = [];
      mockListService = _MockCuratedListService();
      _fakeService = mockListService;
      when(() => mockListService.editableLists).thenAnswer((_) => _fakeLists);
    });

    Widget buildSubject() => testProviderScope(
      mockAuthService: createMockAuthService(currentPublicKeyHex: 'a' * 64),
      additionalOverrides: [
        curatedListsStateProvider.overrideWith(_FakeCuratedListsState.new),
      ],
      child: MaterialApp(
        localizationsDelegates: appLocalizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: SelectListDialog(video: testVideo)),
      ),
    );

    testWidgets(
      'failed initialization can retry locally without exposing mutations',
      (tester) async {
        _failInitialization = true;
        _fakeLists = [
          CuratedList(
            id: 'retry-list',
            name: 'Retry list',
            videoEventIds: const [],
            createdAt: DateTime(2026),
            updatedAt: DateTime(2026),
          ),
        ];
        await tester.pumpWidget(buildSubject());
        await tester.pumpAndSettle();
        final l10n = lookupAppLocalizations(const Locale('en'));
        expect(find.text(l10n.listErrorLoading), findsOneWidget);
        expect(find.text(l10n.listNewList), findsNothing);
        expect(find.byType(ListTile), findsNothing);
        expect(find.text(l10n.listDone), findsOneWidget);

        await tester.tap(find.text(l10n.searchTryAgain));
        await tester.pumpAndSettle();
        expect(_initializationAttempts, 2);
        expect(find.text(l10n.listErrorLoading), findsNothing);
        expect(find.text('Retry list'), findsOneWidget);
        expect(find.text(l10n.listNewList), findsOneWidget);
      },
    );

    testWidgets('renders Add to List title', (tester) async {
      _fakeLists = [
        CuratedList(
          id: 'list0123456789abcdef0123456789abcdef0123456789abcdef0123456789',
          pubkey: 'abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789',
          name: 'My Test List',
          description: 'A test list',
          videoEventIds: const [],
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      ];

      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      expect(find.text('Add to List'), findsOneWidget);
      expect(find.text('My Test List'), findsOneWidget);
      expect(find.text('0 videos • Public'), findsOneWidget);
    });

    testWidgets('shows check icon for video already in list', (tester) async {
      _fakeLists = [
        CuratedList(
          id: 'list0123456789abcdef0123456789abcdef0123456789abcdef0123456789',
          pubkey: 'abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789',
          name: 'Contains Video',
          videoEventIds: const [
            '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef',
          ],
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      ];

      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      expect(_divineIcon(DivineIconName.checkCircle), findsOneWidget);
    });

    testWidgets('shows playlist icon for video not in list', (tester) async {
      _fakeLists = [
        CuratedList(
          id: 'list0123456789abcdef0123456789abcdef0123456789abcdef0123456789',
          pubkey: 'abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789',
          name: 'Empty List',
          videoEventIds: const [],
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      ];

      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      expect(_divineIcon(DivineIconName.playlist), findsOneWidget);
    });

    testWidgets('displays video count for each list', (tester) async {
      _fakeLists = [
        CuratedList(
          id: 'list0123456789abcdef0123456789abcdef0123456789abcdef0123456789',
          pubkey: 'abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789',
          name: 'Three Videos',
          videoEventIds: const ['vid1', 'vid2', 'vid3'],
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      ];

      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      expect(find.text('3 videos • Public'), findsOneWidget);
    });

    testWidgets('tapping list item adds video and shows snackbar', (
      tester,
    ) async {
      const listId =
          'list0123456789abcdef0123456789abcdef0123456789abcdef0123456789';
      _fakeLists = [
        CuratedList(
          id: listId,
          pubkey: 'abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789',
          name: 'My List',
          videoEventIds: const [],
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      ];

      when(
        () => mockListService.addVideoToList(any(), any()),
      ).thenAnswer((_) async => true);

      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      await tester.tap(find.text('My List'));
      await tester.pumpAndSettle();

      verify(
        () => mockListService.addVideoToList(
          _fakeLists.single.authorScopedId,
          testVideo.id,
        ),
      ).called(1);
      expect(find.text('Added to My List'), findsOneWidget);
    });

    testWidgets('tapping list item with video removes it and shows snackbar', (
      tester,
    ) async {
      const listId =
          'list0123456789abcdef0123456789abcdef0123456789abcdef0123456789';
      _fakeLists = [
        CuratedList(
          id: listId,
          pubkey: 'abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789',
          name: 'My List',
          videoEventIds: [testVideo.id],
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      ];

      when(
        () => mockListService.removeVideoFromList(any(), any()),
      ).thenAnswer((_) async => true);

      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      await tester.tap(find.text('My List'));
      await tester.pumpAndSettle();

      verify(
        () => mockListService.removeVideoFromList(
          _fakeLists.single.authorScopedId,
          testVideo.id,
        ),
      ).called(1);
      expect(find.text('Removed from My List'), findsOneWidget);
    });

    testWidgets('a failed add on a full private list explains why', (
      tester,
    ) async {
      // Before #7331 a failed toggle rendered nothing at all, so a private
      // list at the NIP-44 size ceiling swallowed every add silently.
      const listId =
          'list0123456789abcdef0123456789abcdef0123456789abcdef0123456789';
      _fakeLists = [
        CuratedList(
          id: listId,
          pubkey: 'abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789',
          name: 'My List',
          isPublic: false,
          // Enough references that one more cannot fit in a single NIP-44
          // plaintext, so the converter's real arithmetic decides.
          videoEventIds: [
            for (var i = 0; i < 1000; i++) i.toString().padLeft(64, '0'),
          ],
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      ];

      when(
        () => mockListService.addVideoToList(any(), any()),
      ).thenAnswer((_) async => false);

      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();
      await tester.tap(find.text('My List'));
      await tester.pumpAndSettle();

      final l10n = lookupAppLocalizations(const Locale('en'));
      expect(find.text(l10n.listPrivateFull), findsOneWidget);
      // Retrying cannot succeed, so the generic "try again" copy is wrong here.
      expect(find.text(l10n.listVideoNotAdded), findsNothing);
    });

    testWidgets('a failed add for any other reason stays generic', (
      tester,
    ) async {
      const listId =
          'list0123456789abcdef0123456789abcdef0123456789abcdef0123456789';
      _fakeLists = [
        CuratedList(
          id: listId,
          pubkey: 'abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789',
          name: 'My List',
          videoEventIds: const [],
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      ];

      when(
        () => mockListService.addVideoToList(any(), any()),
      ).thenAnswer((_) async => false);

      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();
      await tester.tap(find.text('My List'));
      await tester.pumpAndSettle();

      final l10n = lookupAppLocalizations(const Locale('en'));
      expect(find.text(l10n.listUpdateFailed), findsOneWidget);
      expect(find.text(l10n.listPrivateFull), findsNothing);
    });

    testWidgets('shows a refused video inline after creating a list', (
      tester,
    ) async {
      final l10n = lookupAppLocalizations(const Locale('en'));
      final created = CuratedList(
        id: 'new-list',
        pubkey: testVideo.pubkey,
        name: 'New collection',
        videoEventIds: const [],
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      );
      when(
        () => mockListService.createList(
          name: any(named: 'name'),
          description: any(named: 'description'),
          isPublic: any(named: 'isPublic'),
          isCollaborative: any(named: 'isCollaborative'),
          allowedCollaborators: any(named: 'allowedCollaborators'),
        ),
      ).thenAnswer((_) async => created);
      when(
        () => mockListService.addVideoToList(created.id, testVideo.id),
      ).thenAnswer((_) async => false);
      await tester.binding.setSurfaceSize(const Size(800, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      await tester.tap(find.text(l10n.listNewList));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, created.name);
      await tester.pump();
      await tester.tap(find.bySemanticsLabel(l10n.listCreate));
      await tester.pumpAndSettle();

      expect(find.byType(ListInfoForm), findsNothing);
      expect(
        find.descendant(
          of: find.byType(SelectListDialog),
          matching: find.text(l10n.listVideoNotAdded),
        ),
        findsOneWidget,
      );
      verify(
        () => mockListService.createList(
          name: created.name,
        ),
      ).called(1);
      verify(
        () => mockListService.addVideoToList(created.id, testVideo.id),
      ).called(1);
    });

    testWidgets('reports a refused creation after both dialogs close', (
      tester,
    ) async {
      final l10n = lookupAppLocalizations(const Locale('en'));
      final pending = Completer<CuratedList?>();
      final created = CuratedList(
        id: 'new-list',
        pubkey: testVideo.pubkey,
        name: 'New collection',
        videoEventIds: const [],
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      );
      when(
        () => mockListService.createList(
          name: any(named: 'name'),
          description: any(named: 'description'),
          isPublic: any(named: 'isPublic'),
          isCollaborative: any(named: 'isCollaborative'),
          allowedCollaborators: any(named: 'allowedCollaborators'),
        ),
      ).thenAnswer((_) => pending.future);
      when(
        () => mockListService.addVideoToList(created.id, testVideo.id),
      ).thenAnswer((_) async => false);
      final navigator = GlobalKey<NavigatorState>();
      await tester.binding.setSurfaceSize(const Size(800, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        testProviderScope(
          mockAuthService: createMockAuthService(currentPublicKeyHex: 'a' * 64),
          additionalOverrides: [
            curatedListsStateProvider.overrideWith(_FakeCuratedListsState.new),
          ],
          child: MaterialApp(
            navigatorKey: navigator,
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const Scaffold(body: Text('Underlying screen')),
          ),
        ),
      );
      unawaited(
        showDialog<void>(
          context: navigator.currentContext!,
          builder: (_) => SelectListDialog(video: testVideo),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.listNewList));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, created.name);
      await tester.pump();
      await tester.tap(find.bySemanticsLabel(l10n.listCreate));
      await tester.pump();
      navigator.currentState!.pop();
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.listDone));
      await tester.pumpAndSettle();
      expect(find.byType(SelectListDialog), findsNothing);
      expect(find.byType(ListInfoForm), findsNothing);

      pending.complete(created);
      await tester.pumpAndSettle();

      expect(find.text('Underlying screen'), findsOneWidget);
      expect(find.text(l10n.listVideoNotAdded), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'pending creation notice follows durable list state and clears after external sync',
      (tester) async {
        final l10n = lookupAppLocalizations(const Locale('en'));
        final pending = CuratedList(
          id: 'new-pending-list',
          pubkey: 'a' * 64,
          name: 'Pending collection',
          videoEventIds: [testVideo.id],
          pendingRepublish: true,
          createdAt: DateTime(2026),
          updatedAt: DateTime(2026),
        );
        when(
          () => mockListService.createList(
            name: any(named: 'name'),
            description: any(named: 'description'),
            isPublic: any(named: 'isPublic'),
            isCollaborative: any(named: 'isCollaborative'),
            allowedCollaborators: any(named: 'allowedCollaborators'),
          ),
        ).thenAnswer((_) async => pending.copyWith(videoEventIds: const []));
        when(() => mockListService.getListById(pending.id)).thenReturn(pending);
        await tester.binding.setSurfaceSize(const Size(800, 1200));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await tester.pumpWidget(buildSubject());
        await tester.pumpAndSettle();
        final container = ProviderScope.containerOf(
          tester.element(find.byType(SelectListDialog)),
        );
        final notifier = container.read(
          curatedListsStateProvider.notifier,
        ) as _FakeCuratedListsState;
        when(() => mockListService.addVideoToList(pending.id, testVideo.id))
            .thenAnswer((_) async {
              notifier.replaceLists([pending]);
              return false;
            });
        await tester.tap(find.text(l10n.listNewList));
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextField).first, pending.name);
        await tester.pump();
        await tester.tap(find.bySemanticsLabel(l10n.listCreate));
        await tester.pumpAndSettle();
        expect(find.text(l10n.listVideoPendingSync), findsOneWidget);
        final notice = tester.widget<Text>(
          find.text(l10n.listVideoPendingSync),
        );
        final context = tester.element(find.byType(SelectListDialog));
        expect(notice.style!.color, context.vineColors.onSurfaceVariant);
        expect(find.text(l10n.listVideoNotAdded), findsNothing);
        notifier.replaceLists([pending.copyWith(pendingRepublish: false)]);
        await tester.pumpAndSettle();
        expect(find.text(l10n.listVideoPendingSync), findsNothing);
        expect(find.text(l10n.listRetrySync), findsNothing);
        expect(_divineIcon(DivineIconName.checkCircle), findsOneWidget);
      },
    );

    testWidgets(
      'sync retry shows progress, reports rejection, and clears after confirmed sync',
      (tester) async {
        final l10n = lookupAppLocalizations(const Locale('en'));
        final pending = CuratedList(
          id: 'pending-list',
          pubkey: 'a' * 64,
          name: 'Pending collection',
          videoEventIds: [testVideo.id],
          pendingRepublish: true,
          createdAt: DateTime(2026),
          updatedAt: DateTime(2026),
        );
        _fakeLists = [pending];
        final answer = Completer<bool>();
        addTearDown(() {
          if (!answer.isCompleted) answer.complete(false);
        });
        when(() => mockListService.retryListSync(pending.id))
            .thenAnswer((_) => answer.future);
        await tester.pumpWidget(buildSubject());
        await tester.pumpAndSettle();
        await tester.tap(find.text(l10n.listRetrySync));
        await tester.pump();
        expect(find.byType(DivineCircularProgressIndicator), findsOneWidget);
        expect(find.text(l10n.listRetrySync), findsNothing);
        answer.complete(false);
        await tester.pumpAndSettle();
        expect(find.text(l10n.listUpdateFailed), findsOneWidget);
        expect(find.text(l10n.listRetrySync), findsOneWidget);
        final container = ProviderScope.containerOf(
          tester.element(find.byType(SelectListDialog)),
        );
        final notifier = container.read(
          curatedListsStateProvider.notifier,
        ) as _FakeCuratedListsState;
        when(() => mockListService.retryListSync(pending.id)).thenAnswer((
          _,
        ) async {
          notifier.replaceLists([pending.copyWith(pendingRepublish: false)]);
          return true;
        });
        await tester.tap(find.text(l10n.listRetrySync));
        await tester.pumpAndSettle();
        expect(find.text(l10n.listVideoPendingSync), findsNothing);
        expect(find.text(l10n.listUpdateFailed), findsNothing);
        expect(find.text(l10n.listRetrySync), findsNothing);
        expect(_divineIcon(DivineIconName.checkCircle), findsOneWidget);
        verify(() => mockListService.retryListSync(pending.id)).called(2);
        verifyNever(() => mockListService.addVideoToList(any(), any()));
        verifyNever(() => mockListService.removeVideoFromList(any(), any()));
      },
    );

    testWidgets('renders Done button', (tester) async {
      _fakeLists = [];

      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      expect(find.text('Done'), findsOneWidget);
    });

    testWidgets('renders multiple lists', (tester) async {
      _fakeLists = [
        CuratedList(
          id: 'list_a_23456789abcdef0123456789abcdef0123456789abcdef0123456789',
          pubkey: 'abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789',
          name: 'Favorites',
          videoEventIds: const [],
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
        CuratedList(
          id: 'list_b_23456789abcdef0123456789abcdef0123456789abcdef0123456789',
          pubkey: 'abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789',
          name: 'Watch Later',
          isPublic: false,
          videoEventIds: const [],
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      ];

      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      expect(find.text('Favorites'), findsOneWidget);
      expect(find.text('Watch Later'), findsOneWidget);
    });

    testWidgets('offers only lists the viewer owns', (tester) async {
      // A followed list cached under its author coordinate can share the
      // viewer's d-tag, and a bare-id add would land on the viewer's own row.
      final own = CuratedList(
        id: 'my_vine_list',
        pubkey: 'c' * 64,
        name: 'Own list',
        videoEventIds: const [],
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      );
      _fakeLists = [
        own,
        CuratedList(
          id: 'my_vine_list',
          pubkey: 'b' * 64,
          name: 'Followed list',
          videoEventIds: const [],
          createdAt: DateTime(2026),
          updatedAt: DateTime(2026),
        ),
      ];
      when(() => mockListService.editableLists).thenReturn([own]);

      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      expect(find.text('Own list'), findsOneWidget);
      expect(find.text('Followed list'), findsNothing);
    });
  });
}
