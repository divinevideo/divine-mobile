// ABOUTME: Ensures notices and every list remain scrollable at larger text sizes.
// ABOUTME: Covers read-only guards, real maximum notice states and lazy rows.

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

class _Service extends Mock implements CuratedListService {
  @override
  bool recoveryNeedsRepair = false;
}

late _Service _service;
List<CuratedList> _lists = [];

class _Lists extends CuratedListsState {
  @override
  CuratedListService? get service => _service;

  @override
  Future<List<CuratedList>> build() async => _lists;
}

const _owner =
    'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
const _event =
    'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';
const _redaction =
    'cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc';

CuratedList _list(int index, {bool pending = false}) => CuratedList(
  id: 'collection-$index',
  pubkey: _owner,
  name: 'Collection $index',
  videoEventIds: const [],
  isPublic: !pending,
  pendingPlaintextEventIds: pending ? const [_redaction] : const [],
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);

enum _Mode { healthy, readOnly, readOnlyPending, pending, threeNotices }

void main() {
  final l10n = lookupAppLocalizations(const Locale('en'));
  final video = VideoEvent(
    id: _event,
    pubkey: _owner,
    createdAt: 1757385263,
    content: 'Video',
    timestamp: DateTime(2026),
    videoUrl: 'https://example.com/video.mp4',
  );

  Future<ValueNotifier<double>> open(
    WidgetTester tester, {
    required _Mode mode,
    int count = 3,
    EdgeInsets? padding,
  }) async {
    _service = _Service();
    _service.recoveryNeedsRepair =
        mode == _Mode.readOnly || mode == _Mode.readOnlyPending;
    _lists = [
      for (var index = 1; index <= count; index++)
        _list(
          index,
          pending:
              (mode == _Mode.threeNotices ||
                  mode == _Mode.readOnlyPending ||
                  mode == _Mode.pending) &&
              index == 1,
        ),
    ];
    final scaler = ValueNotifier<double>(1);
    addTearDown(scaler.dispose);
    await tester.binding.setSurfaceSize(
      mode == _Mode.threeNotices ? const Size(800, 1200) : const Size(390, 844),
    );
    addTearDown(() => tester.binding.setSurfaceSize(null));
    if (mode == _Mode.pending) {
      when(() => _service.retryListSync(_lists.first.id))
          .thenAnswer((_) async => false);
    }
    if (mode == _Mode.threeNotices) {
      final created = _list(count + 1);
      when(
        () => _service.createList(
          name: any(named: 'name'),
          description: any(named: 'description'),
          isPublic: any(named: 'isPublic'),
          isCollaborative: any(named: 'isCollaborative'),
          allowedCollaborators: any(named: 'allowedCollaborators'),
        ),
      ).thenAnswer((_) async => created);
      when(
        () => _service.addVideoToList(created.authorScopedId, _event),
      ).thenAnswer((_) async => false);
      when(
        () => _service.getListById(created.authorScopedId),
      ).thenReturn(created);
      when(
        () => _service.retryListSync(_lists.first.id),
      ).thenAnswer((_) async => false);
    }
    await tester.pumpWidget(
      testProviderScope(
        mockAuthService: createMockAuthService(currentPublicKeyHex: _owner),
        additionalOverrides: [
          curatedListsStateProvider.overrideWith(_Lists.new),
        ],
        child: MaterialApp(
          localizationsDelegates: appLocalizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          builder: (context, child) => ValueListenableBuilder<double>(
            valueListenable: scaler,
            builder: (context, value, _) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaler: TextScaler.linear(value),
                padding: padding,
              ),
              child: child!,
            ),
          ),
          home: Scaffold(body: SelectListDialog(video: video)),
        ),
      ),
    );
    await tester.pumpAndSettle();
    if (mode == _Mode.threeNotices) {
      // Create through the real editor, then exercise a real failed Sync. These
      // three notice conditions coexist; read-only suppresses the other states.
      await tester.tap(find.text(l10n.listNewList));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, 'New collection');
      await tester.pump();
      await tester.tap(find.bySemanticsLabel(l10n.listCreate));
      await tester.pumpAndSettle();
      expect(find.byType(ListInfoForm), findsNothing);
      expect(find.text(l10n.listVideoNotAdded), findsOneWidget);
      await tester.tap(find.text(l10n.listRetrySync));
      await tester.pumpAndSettle();
      expect(find.text(l10n.listRecoveryPending), findsOneWidget);
      expect(find.text(l10n.listUpdateFailed), findsOneWidget);
      await tester.binding.setSurfaceSize(const Size(390, 844));
    }
    return scaler;
  }

  Finder scrollable() => find.descendant(
    of: find.byType(SelectListDialog),
    matching: find.byType(Scrollable),
  );

  Finder viewport() => find.descendant(
    of: find.byType(SelectListDialog),
    matching: find.byType(Viewport),
  );

  for (final mode in _Mode.values) {
    for (final scale in [1.0, 1.5, 2.0]) {
      testWidgets(
        '${mode.name} notices and all rows remain reachable at text scale $scale',
        (tester) async {
          final scaler = await open(tester, mode: mode);
          scaler.value = scale;
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          expect(scrollable(), findsOneWidget);
          expect(tester.getRect(viewport()).height, greaterThan(0));

          for (var index = 1; index <= 3; index++) {
            final row = find.text('Collection $index');
            await tester.scrollUntilVisible(
              row,
              80,
              scrollable: scrollable(),
              maxScrolls: 30,
            );
            await tester.pumpAndSettle();
            expect(row.hitTestable(), findsOneWidget);
            if (scale == 2.0) {
              final label = tester.getRect(row);
              expect(label.width, greaterThanOrEqualTo(100));
              expect(
                label.height,
                lessThanOrEqualTo(tester.getRect(viewport()).height),
              );
            }
            final tile = tester.widget<ListTile>(
              find.ancestor(of: row, matching: find.byType(ListTile)),
            );
            expect(
              tile.onTap,
              _service.recoveryNeedsRepair ? isNull : isNotNull,
            );
          }

          final notices = [
            if (_service.recoveryNeedsRepair) l10n.listRecoveryReadOnly,
            if (mode == _Mode.pending) l10n.listRecoveryPending,
            if (mode == _Mode.threeNotices) ...[
              l10n.listVideoNotAdded,
              l10n.listRecoveryPending,
              l10n.listUpdateFailed,
            ],
          ];
          final position = tester.state<ScrollableState>(scrollable()).position;
          for (final copy in notices) {
            position.jumpTo(position.minScrollExtent);
            await tester.pumpAndSettle();
            final text = find.text(copy);
            await tester.scrollUntilVisible(
              text,
              -80,
              scrollable: scrollable(),
              maxScrolls: 30,
            );
            await tester.pumpAndSettle();
            final renderObject = tester.renderObject(text);
            await position.ensureVisible(renderObject);
            await tester.pumpAndSettle();
            final top = tester.getRect(text).top;
            final bounds = tester.getRect(viewport());
            expect(top, inInclusiveRange(bounds.top, bounds.bottom));
            await position.ensureVisible(renderObject, alignment: 1);
            await tester.pumpAndSettle();
            final bottom = tester.getRect(text).bottom;
            expect(bottom, inInclusiveRange(bounds.top, bounds.bottom));
          }

          if (mode == _Mode.pending ||
              mode == _Mode.threeNotices ||
              mode == _Mode.readOnlyPending) {
            position.jumpTo(position.minScrollExtent);
            await tester.pumpAndSettle();
            final action = find.text(l10n.listRetrySync);
            await tester.scrollUntilVisible(
              action,
              80,
              scrollable: scrollable(),
              maxScrolls: 40,
            );
            await tester.pumpAndSettle();
            expect(action.hitTestable(), findsOneWidget);
            await tester.tap(action);
            await tester.pumpAndSettle();
            if (!_service.recoveryNeedsRepair) {
              verify(() => _service.retryListSync(_lists.first.id))
                  .called(mode == _Mode.threeNotices ? 2 : 1);
              verifyNever(() => _service.removeVideoFromList(any(), any()));
              if (mode == _Mode.pending) {
                verifyNever(() => _service.addVideoToList(any(), any()));
              }
            }
          }

          expect(find.text(l10n.listDone).hitTestable(), findsOneWidget);
          expect(find.text(l10n.listNewList).hitTestable(), findsOneWidget);
          final create = tester.widget<TextButton>(
            find.ancestor(
              of: find.text(l10n.listNewList),
              matching: find.byType(TextButton),
            ),
          );
          expect(
            create.onPressed,
            _service.recoveryNeedsRepair ? isNull : isNotNull,
          );
          if (_service.recoveryNeedsRepair) {
            verifyNever(() => _service.addVideoToList(any(), any()));
            verifyNever(() => _service.removeVideoFromList(any(), any()));
            verifyNever(() => _service.retryListSync(any()));
          }
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pumpAndSettle();
        },
      );
    }
  }

  testWidgets('fitting rows keep the existing automatic vertical insets', (
    tester,
  ) async {
    await open(
      tester,
      mode: _Mode.healthy,
      padding: const EdgeInsets.only(top: 24, bottom: 16),
    );
    final tile = find.ancestor(
      of: find.text('Collection 1'),
      matching: find.byType(ListTile),
    );
    expect(tester.getRect(tile).top, tester.getRect(viewport()).top + 24);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Sync remains beside the label when the default layout fits', (
    tester,
  ) async {
    await open(tester, mode: _Mode.pending);
    await tester.binding.setSurfaceSize(const Size(800, 1200));
    await tester.pumpAndSettle();
    final action = find.text(l10n.listRetrySync);
    expect(
      find.ancestor(of: action, matching: find.byType(ListTile)),
      findsOneWidget,
    );
    expect(action.hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a large collection remains lazy and its last row is reachable', (
    tester,
  ) async {
    await open(tester, mode: _Mode.healthy, count: 100);
    expect(find.byType(ListTile).evaluate().length, lessThan(30));
    await tester.scrollUntilVisible(
      find.text('Collection 100'),
      200,
      scrollable: scrollable(),
      maxScrolls: 100,
    );
    await tester.pumpAndSettle();
    expect(find.text('Collection 100').hitTestable(), findsOneWidget);
    expect(find.byType(ListTile).evaluate().length, lessThan(30));
    expect(tester.takeException(), isNull);
  });
}
