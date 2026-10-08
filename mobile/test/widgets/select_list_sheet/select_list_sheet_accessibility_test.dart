// ABOUTME: Keeps recovery notices, list rows and picker controls reachable at large text sizes.
// ABOUTME: Preserves read-only and acknowledged-permission recovery while scrolling and retrying sync.

import 'dart:async';

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/select_list/select_list_cubit.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/list_providers.dart';
import 'package:openvine/services/curated_list_service.dart';
import 'package:openvine/widgets/list_picker_create_button.dart';
import 'package:openvine/widgets/list_picker_row.dart';
import 'package:openvine/widgets/select_list_sheet/select_list_sheet.dart';

import '../../helpers/test_provider_overrides.dart';

class _MockCuratedListService extends Mock implements CuratedListService {
  @override
  bool recoveryNeedsRepair = false;
}

late _MockCuratedListService _service;
List<CuratedList> _lists = const [];

class _FixtureCuratedListsState extends CuratedListsState {
  @override
  CuratedListService get service => _service;

  @override
  Future<List<CuratedList>> build() async => _lists;
}

const _owner =
    'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
const _videoId =
    'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';
const _openLabel = 'Open list picker';

CuratedList _list(int index) => CuratedList(
  id: index.toString().padLeft(64, '0'),
  pubkey: _owner,
  name: 'Collection $index',
  videoEventIds: const [],
  createdAt: DateTime.utc(2026),
  updatedAt: DateTime.utc(2026),
);

Future<void> _open(
  WidgetTester tester, {
  required double scale,
  Size surface = const Size(390, 844),
}) async {
  final devicePixelRatio = tester.view.devicePixelRatio;
  final padding = EdgeInsets.fromViewPadding(
    tester.view.padding,
    devicePixelRatio,
  );
  final viewPadding = EdgeInsets.fromViewPadding(
    tester.view.viewPadding,
    devicePixelRatio,
  );
  final viewInsets = EdgeInsets.fromViewPadding(
    tester.view.viewInsets,
    devicePixelRatio,
  );
  // Keep native physical insets and the logical test surface in the same scale.
  tester.view.physicalSize = surface * devicePixelRatio;
  await tester.binding.setSurfaceSize(surface);
  addTearDown(() async {
    tester.view.reset();
    await tester.binding.setSurfaceSize(null);
  });
  final video = VideoEvent(
    id: _videoId,
    pubkey: _owner,
    createdAt: 1757385263,
    content: 'Test video',
    timestamp: DateTime.fromMillisecondsSinceEpoch(1757385263 * 1000),
    videoUrl: 'https://example.com/video.mp4',
  );
  await tester.pumpWidget(
    testProviderScope(
      mockAuthService: createMockAuthService(currentPublicKeyHex: _owner),
      additionalOverrides: [
        curatedListsStateProvider.overrideWith(_FixtureCuratedListsState.new),
        myListsWithThumbnailsProvider.overrideWith((ref) async => const []),
      ],
      child: MaterialApp(
        theme: VineTheme.theme,
        locale: const Locale('en'),
        localizationsDelegates: appLocalizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(scale),
          ),
          child: child!,
        ),
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => unawaited(
                showSelectListSheet(context, video: video),
              ),
              child: const Text(_openLabel),
            ),
          ),
        ),
      ),
    ),
  );
  final mediaQuery = MediaQuery.of(tester.element(find.text(_openLabel)));
  expect(mediaQuery.size, surface);
  expect(mediaQuery.padding, padding);
  expect(mediaQuery.viewPadding, viewPadding);
  expect(mediaQuery.viewInsets, viewInsets);
  await tester.tap(find.text(_openLabel));
  await tester.pumpAndSettle();
  expect(find.byType(SelectListSheetBody), findsOneWidget);
  expect(tester.takeException(), isNull);
}

Finder _rows() => find.descendant(
  of: find.byType(SelectListSheetBody),
  matching: find.byType(ListView),
);

Future<void> _reach(WidgetTester tester, Finder target) async {
  final scrollable = find.descendant(
    of: _rows(),
    matching: find.byType(Scrollable),
  );
  expect(scrollable, findsOneWidget);
  expect(tester.getSize(_rows()).height, greaterThan(0));
  // Cached rows can exist offscreen. Real drags also expand the picker.
  var drags = 0;
  while (target.hitTestable().evaluate().isEmpty && drags < 30) {
    await tester.drag(scrollable, const Offset(0, -60));
    await tester.pumpAndSettle();
    drags++;
  }
  await tester.pumpAndSettle();
  expect(target.hitTestable(), findsOneWidget);
  expect(tester.getSize(target).width, greaterThan(0));
  expect(tester.takeException(), isNull);
}

void _noMembershipWrites() {
  verifyNever(() => _service.addVideoToList(any(), any()));
  verifyNever(() => _service.removeVideoFromList(any(), any()));
}

void main() {
  final strings = lookupAppLocalizations(const Locale('en'));

  group('replacement list picker accessibility', () {
    setUp(() {
      _service = _MockCuratedListService();
      _lists = [_list(1), _list(2), _list(3)];
      when(() => _service.isCurrentSession).thenReturn(true);
      when(() => _service.myLists).thenAnswer((_) => _lists);
    });

    // These retain the original three externally demonstrated scale cases.
    for (final scale in [1.0, 1.5, 2.0]) {
      testWidgets('read-only lists remain reachable at ${scale}x text', (
        tester,
      ) async {
        _service.recoveryNeedsRepair = true;
        await _open(tester, scale: scale);
        final cubit = tester
            .element(find.byType(SelectListSaveButton))
            .read<SelectListCubit>();
        expect(find.text(strings.listRecoveryReadOnly), findsOneWidget);
        expect(cubit.state.recoveryReadOnly, isTrue);
        expect(
          tester
              .widget<ListPickerCreateButton>(
                find.byType(ListPickerCreateButton),
              )
              .onPressed,
          isNull,
        );
        for (var index = 1; index <= 3; index++) {
          final title = find.text('Collection $index');
          await _reach(tester, title);
          final row = find.ancestor(
            of: title,
            matching: find.byType(ListPickerRow),
          );
          expect(tester.widget<ListPickerRow>(row).onTap, isNull);
          await tester.tap(title);
          await tester.pump();
          expect(cubit.state.selectedListIds, isEmpty);
        }
        expect(find.text(strings.listRecoveryReadOnly), findsOneWidget);
        expect(
          find.byType(ListPickerCreateButton).hitTestable(),
          findsOneWidget,
        );
        expect(
          find.bySemanticsLabel(strings.commonClose).hitTestable(),
          findsOneWidget,
        );
        final done = find.bySemanticsLabel(strings.listDone);
        expect(done.hitTestable(), findsOneWidget);
        await tester.tap(done);
        await tester.pumpAndSettle();
        expect(find.byType(SelectListSheetBody), findsNothing);
        _noMembershipWrites();
        verifyNever(() => _service.retryListSync(any()));
        expect(tester.takeException(), isNull);
      });
    }

    for (final permissionRecovery in [false, true]) {
      testWidgets(
        permissionRecovery
            ? 'permission recovery and Sync stay reachable at 2x on a short screen'
            : 'pending video and Sync stay reachable at 2x on a short screen',
        (tester) async {
          final pending = permissionRecovery
              ? _list(3).copyWith(
                  pendingVisibility: const CuratedListVisibility(
                    isPublic: false,
                    isCollaborative: false,
                    allowedCollaborators: [],
                    relayAccepted: true,
                  ),
                )
              : _list(3).copyWith(
                  videoEventIds: const [_videoId],
                  pendingRepublish: true,
                );
          _lists = [_list(1), _list(2), pending];
          when(() => _service.retryListSync(pending.id))
              .thenAnswer((_) async => false);
          await _open(
            tester,
            scale: 2,
            surface: const Size(390, 780),
          );
          final cubit = tester
              .element(find.byType(SelectListSaveButton))
              .read<SelectListCubit>();
          for (var index = 1; index <= 3; index++) {
            await _reach(tester, find.text('Collection $index'));
          }
          if (permissionRecovery) {
            final title = find.text('Collection 3');
            final row = find.ancestor(
              of: title,
              matching: find.byType(ListPickerRow),
            );
            expect(tester.widget<ListPickerRow>(row).onTap, isNull);
            await tester.tap(title);
            await tester.pump();
            expect(cubit.state.selectedListIds, isEmpty);
          } else {
            expect(cubit.state.selectedListIds, {pending.id});
          }
          final notice = permissionRecovery
              ? strings.listPermissionsRecoveryPending
              : strings.listVideoPendingSync;
          await _reach(tester, find.text(notice));
          final sync = find.text(strings.listRetrySync);
          await _reach(tester, sync);
          expect(
            find.byType(ListPickerCreateButton).hitTestable(),
            findsOneWidget,
          );
          expect(
            find.bySemanticsLabel(strings.listDone).hitTestable(),
            findsOneWidget,
          );
          await tester.tap(sync);
          await tester.pumpAndSettle();
          verify(() => _service.retryListSync(pending.id)).called(1);
          expect(find.text(notice), findsOneWidget);
          expect(
            cubit.state.selectedListIds,
            permissionRecovery ? <String>{} : {pending.id},
          );
          expect(
            find.text(strings.listUpdateFailed),
            permissionRecovery ? findsNothing : findsOneWidget,
          );
          _noMembershipWrites();
          final close = find.bySemanticsLabel(strings.commonClose);
          expect(close.hitTestable(), findsOneWidget);
          await tester.tap(close);
          await tester.pumpAndSettle();
          expect(find.byType(SelectListSheetBody), findsNothing);
          expect(tester.takeException(), isNull);
        },
      );
    }
  });
}
