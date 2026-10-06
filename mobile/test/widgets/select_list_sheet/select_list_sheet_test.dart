// ABOUTME: Tests for the list picker sheet: the rows it renders, how picks
// ABOUTME: are made and saved, and how it follows a list created from it.

import 'dart:async';

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/select_list/select_list_cubit.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/container_swap_host.dart';
import 'package:openvine/providers/list_providers.dart';
import 'package:openvine/services/curated_list_service.dart';
import 'package:openvine/utils/detached_future.dart';
import 'package:openvine/widgets/divine_list_thumbnail.dart';
import 'package:openvine/widgets/list_info_sheet/list_info_form.dart';
import 'package:openvine/widgets/list_picker_create_button.dart';
import 'package:openvine/widgets/list_picker_row.dart';
import 'package:openvine/widgets/select_list_sheet/select_list_sheet.dart';
import 'package:openvine/widgets/video_thumbnail_widget.dart';

import '../../helpers/test_provider_overrides.dart';

class _MockCuratedListService extends Mock implements CuratedListService {
  @override
  bool recoveryNeedsRepair = false;
}

/// Set before each test; read by [_FakeCuratedListsState].
_MockCuratedListService? _fakeService;

class _FakeCuratedListsState extends CuratedListsState {
  @override
  CuratedListService? get service => _fakeService;

  @override
  Future<List<CuratedList>> build() async => const [];

  void publishSnapshot() => state = AsyncData(List<CuratedList>.empty());

  void failRefresh() =>
      state = AsyncError(StateError('unavailable'), StackTrace.current);
}

_MockCuratedListService? _replacementBeforeMount;

class _ReplacedBeforeMountCuratedListsState extends _FakeCuratedListsState {
  @override
  CuratedListService? get service {
    final current = super.service;
    if (_replacementBeforeMount != null) {
      _fakeService = _replacementBeforeMount;
      _replacementBeforeMount = null;
    }
    return current;
  }
}

bool _retryInitializationFails = true;

class _RetryableCuratedListsState extends _FakeCuratedListsState {
  @override
  Future<List<CuratedList>> build() async {
    if (_retryInitializationFails) throw StateError('no relay');
    return const [];
  }
}

class _FailingCuratedListsState extends CuratedListsState {
  @override
  Future<List<CuratedList>> build() async => throw StateError('no relay');
}

// Full-length 64-char identifiers — never truncate.
const String _videoEventId =
    '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef';
const String _authorPubkey =
    'abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789';
const String _openLabel = 'Open list picker';

void main() {
  final l10n = lookupAppLocalizations(const Locale('en'));

  group('showSelectListSheet', () {
    late _MockCuratedListService service;
    late VideoEvent video;
    late MockAuthService auth;
    late String? activeOwner;

    setUp(() {
      _retryInitializationFails = true;
      activeOwner = _authorPubkey;
      auth = createMockAuthService(currentPublicKeyHex: _authorPubkey);
      when(() => auth.currentPublicKeyHex).thenAnswer((_) => activeOwner);
      service = _MockCuratedListService();
      when(() => service.isCurrentSession).thenReturn(true);
      _fakeService = service;
      when(() => service.myLists).thenReturn(const []);
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

    CuratedList list(
      String name, {
      bool isPublic = true,
      List<String> videoEventIds = const [],
      List<String> thumbnailUrls = const [],
    }) => CuratedList(
      id: 'list_${name.toLowerCase().replaceAll(' ', '_')}',
      pubkey: _authorPubkey,
      name: name,
      isPublic: isPublic,
      videoEventIds: videoEventIds,
      thumbnailUrls: thumbnailUrls,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );

    /// Opens the sheet; [thumbnails] is what the resolver returns, null for
    /// a resolver that has not answered yet.
    Future<void> openSheet(
      WidgetTester tester, {
      CuratedListsState Function() listsState = _FakeCuratedListsState.new,
      List<CuratedList>? thumbnails = const [],
      Locale locale = const Locale('en'),
    }) async {
      await tester.binding.setSurfaceSize(const Size(800, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final neverResolves = Completer<List<CuratedList>>();
      await tester.pumpWidget(
        testMaterialApp(
          locale: locale,
          additionalOverrides: [
            authServiceProvider.overrideWithValue(auth),
            curatedListsStateProvider.overrideWith(listsState),
            myListsWithThumbnailsProvider.overrideWith(
              (ref) => thumbnails == null
                  ? neverResolves.future
                  : Future.value(thumbnails),
            ),
          ],
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => runDetached(
                  showSelectListSheet(context, video: video),
                  'open list picker sheet',
                  logName: 'SelectListSheetTest',
                  category: LogCategory.ui,
                ),
                child: const Text(_openLabel),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text(_openLabel));
      if (thumbnails == null) {
        // The shimmer never settles; two frames open the sheet.
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));
      } else {
        await tester.pumpAndSettle();
      }
    }

    /// The checks marking picked rows; the header's check button is a
    /// separate widget outside the body.
    Finder rowChecks() => find.descendant(
      of: find.byType(SelectListSheetBody),
      matching: find.byWidgetPredicate(
        (widget) => widget is DivineIcon && widget.icon == DivineIconName.check,
      ),
    );

    Finder saveButton() => find.bySemanticsLabel(l10n.listDone);

    /// The check button as assistive tech reads it.
    SemanticsNode saveButtonNode() =>
        find.semantics.byLabel(l10n.listDone).evaluate().single;

    group('renders', () {
      testWidgets('the title, one row per list, and a check on each list '
          'that holds the video', (tester) async {
        when(() => service.myLists).thenReturn([
          list('Holds it', videoEventIds: const [_videoEventId]),
          list('Watch later', isPublic: false),
        ]);

        await openSheet(tester);

        expect(find.text(l10n.listAddToLists), findsOneWidget);
        expect(find.text('Holds it'), findsOneWidget);
        expect(
          find.text('${l10n.listVideoCount(1)} • ${l10n.listVisibilityPublic}'),
          findsOneWidget,
        );
        expect(find.text('Watch later'), findsOneWidget);
        expect(
          find.text(
            '${l10n.listVideoCount(0)} • ${l10n.listVisibilityPrivate}',
          ),
          findsOneWidget,
        );
        expect(rowChecks(), findsOneWidget);
        expect(find.text(l10n.listCreateNewList), findsOneWidget);
      });

      testWidgets('over the lower part of the screen, at the height the '
          'people-list picker opens at', (tester) async {
        when(() => service.myLists).thenReturn([list('Empty')]);

        await openSheet(tester);

        // The surface is 1200 tall with no top inset, and the sheet opens at
        // VineBottomSheet.show's default 0.6 of that, as the people-list
        // picker does; a full-height picker is what the design review
        // rejected.
        final sheet = tester.getSize(find.byType(VineBottomSheet));
        expect(sheet.height, closeTo(720, 1));
        expect(find.text(l10n.listCreateNewList), findsOneWidget);
      });

      testWidgets('a hint when the viewer has no lists yet', (tester) async {
        await openSheet(tester);

        expect(find.text(l10n.profileListsEmpty), findsOneWidget);
        expect(find.text(l10n.listCreateNewList), findsOneWidget);
      });

      testWidgets("each row carries the list's card media, with its resolved "
          'thumbnails in the fan and a flat fan until then', (tester) async {
        when(() => service.myLists)
            .thenReturn([list('Pictured'), list('Bare')]);

        await openSheet(
          tester,
          thumbnails: [
            list('Pictured', thumbnailUrls: const ['https://example.com/t']),
          ],
        );

        expect(find.byType(DivineListMedia), findsNWidgets(2));
        final image = tester.widget<PassiveAuthThumbnailImage>(
          find.byType(PassiveAuthThumbnailImage),
        );
        expect(image.url, 'https://example.com/t');
        expect(find.byType(ListSkeletonizer), findsWidgets);
        expect(
          tester
              .widgetList<ListSkeletonizer>(find.byType(ListSkeletonizer))
              .map((skeleton) => skeleton.enabled),
          everyElement(isFalse),
        );
      });

      testWidgets("a row's fan drops the count badge the gallery card draws, "
          "since the row's own line carries the count", (tester) async {
        // Three videos: the card's badge would read "3" on its own, apart
        // from the "3 videos" the row's line says.
        when(() => service.myLists).thenReturn([
          list(
            'Three',
            videoEventIds: [
              for (var i = 1; i <= 3; i++) i.toRadixString(16).padLeft(64, '0'),
            ],
          ),
        ]);

        await openSheet(tester);

        expect(
          find.text('${l10n.listVideoCount(3)} • ${l10n.listVisibilityPublic}'),
          findsOneWidget,
        );
        expect(find.text('3'), findsNothing);
      });

      testWidgets('fans shimmer while the thumbnails are still resolving', (
        tester,
      ) async {
        when(() => service.myLists).thenReturn([list('Pending')]);

        await openSheet(tester, thumbnails: null);

        final skeleton = tester.widget<ListSkeletonizer>(
          find.byType(ListSkeletonizer),
        );
        expect(skeleton.enabled, isTrue);
      });

      testWidgets("a list waiting to sync says so in the rows' font", (
        tester,
      ) async {
        when(() => service.myLists).thenReturn([
          list(
            'Pending',
            videoEventIds: const [_videoEventId],
          ).copyWith(pendingRepublish: true),
        ]);

        await openSheet(tester);

        final notice = tester.renderObject<RenderParagraph>(
          find.text(l10n.listVideoPendingSync),
        );
        expect(
          notice.text.style?.fontFamily,
          VineTheme.bodyMediumFont().fontFamily,
        );
      });

      testWidgets('a failure to load the lists on the screen underneath '
          'instead of opening', (tester) async {
        await openSheet(tester, listsState: _FailingCuratedListsState.new);

        expect(find.byType(SelectListSheetBody), findsNothing);
        expect(find.text(l10n.listErrorLoading), findsOneWidget);
      });
    });

    group('read-only recovery', () {
      _FakeCuratedListsState notifier(WidgetTester tester) =>
          ProviderScope.containerOf(
            tester.element(find.byType(SelectListSheetBody)),
          ).read(curatedListsStateProvider.notifier) as _FakeCuratedListsState;

      testWidgets(
        'saved rows stay browsable, editing pauses, and Done only dismisses',
        (tester) async {
          final pending = list(
            'Holds',
            videoEventIds: const [_videoEventId],
          ).copyWith(pendingRepublish: true);
          when(() => service.myLists).thenReturn([pending, list('Empty')]);
          service.recoveryNeedsRepair = true;
          await openSheet(tester);

          expect(find.text(l10n.listRecoveryReadOnly), findsOneWidget);
          expect(find.text('Holds'), findsOneWidget);
          expect(rowChecks(), findsOneWidget);
          expect(
            tester
                .widget<ListPickerCreateButton>(
                  find.byType(ListPickerCreateButton),
                )
                .onPressed,
            isNull,
          );
          expect(
            tester
                .widget<DivineButton>(
                  find.widgetWithText(DivineButton, l10n.listRetrySync),
                )
                .onPressed,
            isNull,
          );
          await tester.tap(find.text('Empty'));
          await tester.pump();
          expect(rowChecks(), findsOneWidget);
          final cubit = tester
              .element(find.byType(SelectListSheetBody))
              .read<SelectListCubit>();
          await tester.tap(saveButton());
          await tester.pumpAndSettle();
          expect(find.byType(SelectListSheetBody), findsNothing);
          expect(cubit.state.status, SelectListStatus.editing);
          verifyNever(() => service.addVideoToList(any(), any()));
          verifyNever(() => service.removeVideoFromList(any(), any()));
          verifyNever(() => service.retryListSync(any()));
        },
      );

      testWidgets('Done dismisses an empty held picker', (tester) async {
        service.recoveryNeedsRepair = true;
        await openSheet(tester);
        expect(find.text(l10n.profileListsEmpty), findsOneWidget);
        await tester.tap(saveButton());
        await tester.pumpAndSettle();
        expect(find.byType(SelectListSheetBody), findsNothing);
      });

      testWidgets('a hold after unconfirmed picks restores stored membership', (
        tester,
      ) async {
        when(() => service.myLists).thenReturn([
          list('Holds', videoEventIds: const [_videoEventId]),
          list('Empty'),
        ]);
        await openSheet(tester);
        await tester.tap(find.text('Holds'));
        await tester.tap(find.text('Empty'));
        await tester.pump();
        final cubit = tester
            .element(find.byType(SelectListSheetBody))
            .read<SelectListCubit>();
        expect(cubit.state.selectedListIds, {'list_empty'});
        service.recoveryNeedsRepair = true;
        notifier(tester).publishSnapshot();
        await tester.pumpAndSettle();
        expect(cubit.state.selectedListIds, {'list_holds'});
        expect(find.text(l10n.listRecoveryReadOnly), findsOneWidget);
        expect(
          tester
              .widget<ListPickerRow>(
                find.widgetWithText(ListPickerRow, 'Empty'),
              )
              .onTap,
          isNull,
        );
        await tester.tap(saveButton());
        await tester.pumpAndSettle();
        verifyNever(() => service.addVideoToList(any(), any()));
        verifyNever(() => service.removeVideoFromList(any(), any()));
      });

      testWidgets('callbacks captured before a hold cannot toggle or create', (
        tester,
      ) async {
        when(() => service.myLists).thenReturn([list('Empty')]);
        await openSheet(tester);
        final toggle = tester
            .widget<ListPickerRow>(find.byType(ListPickerRow))
            .onTap!;
        final create = tester
            .widget<ListPickerCreateButton>(find.byType(ListPickerCreateButton))
            .onPressed!;
        service.recoveryNeedsRepair = true;
        toggle();
        create();
        await tester.pumpAndSettle();
        expect(rowChecks(), findsNothing);
        expect(find.byType(ListInfoForm), findsNothing);
        expect(find.text(l10n.listRecoveryReadOnly), findsOneWidget);
      });

      testWidgets(
        'a service replaced before the first frame is bound immediately',
        (tester) async {
          when(() => service.myLists).thenReturn([list('Old')]);
          final replacement = _MockCuratedListService()
            ..recoveryNeedsRepair = true;
          when(() => replacement.isCurrentSession).thenReturn(true);
          when(() => replacement.myLists).thenReturn([
            list('Replacement', videoEventIds: const [_videoEventId]),
          ]);
          _replacementBeforeMount = replacement;
          await openSheet(
            tester,
            listsState: _ReplacedBeforeMountCuratedListsState.new,
          );
          expect(find.text('Old'), findsNothing);
          expect(find.text('Replacement'), findsOneWidget);
          expect(find.text(l10n.listRecoveryReadOnly), findsOneWidget);
          expect(
            tester
                .widget<ListPickerCreateButton>(
                  find.byType(ListPickerCreateButton),
                )
                .onPressed,
            isNull,
          );
          await tester.tap(saveButton());
          await tester.pumpAndSettle();
          verifyNever(() => service.addVideoToList(any(), any()));
          verifyNever(() => replacement.addVideoToList(any(), any()));
        },
      );

      testWidgets('replacement service resets picks and renders its hold', (
        tester,
      ) async {
        when(() => service.myLists).thenReturn([list('Old')]);
        await openSheet(tester);
        await tester.tap(find.text('Old'));
        await tester.pump();
        final replacement = _MockCuratedListService()
          ..recoveryNeedsRepair = true;
        when(() => replacement.isCurrentSession).thenReturn(true);
        when(() => replacement.myLists).thenReturn([
          list('Replacement', videoEventIds: const [_videoEventId]),
        ]);
        _fakeService = replacement;
        notifier(tester).publishSnapshot();
        await tester.pumpAndSettle();
        expect(find.text('Old'), findsNothing);
        expect(find.text('Replacement'), findsOneWidget);
        expect(find.text(l10n.listRecoveryReadOnly), findsOneWidget);
        expect(rowChecks(), findsOneWidget);
        await tester.tap(saveButton());
        await tester.pumpAndSettle();
        verifyNever(() => service.addVideoToList(any(), any()));
        verifyNever(() => replacement.addVideoToList(any(), any()));
      });

      testWidgets('missing service preserves its known hold and safe rows', (
        tester,
      ) async {
        when(() => service.myLists).thenReturn([list('Stored')]);
        service.recoveryNeedsRepair = true;
        await openSheet(tester);
        _fakeService = null;
        notifier(tester).publishSnapshot();
        await tester.pumpAndSettle();
        expect(find.text('Stored'), findsOneWidget);
        expect(find.text(l10n.listRecoveryReadOnly), findsOneWidget);
        expect(
          tester
              .widget<ListPickerCreateButton>(
                find.byType(ListPickerCreateButton),
              )
              .onPressed,
          isNull,
        );
        await tester.tap(find.bySemanticsLabel(l10n.commonClose));
        await tester.pumpAndSettle();
        expect(find.byType(SelectListSheetBody), findsNothing);
      });

      testWidgets('verified repair restores the video picker controls', (
        tester,
      ) async {
        when(() => service.myLists).thenReturn([list('Empty')]);
        service.recoveryNeedsRepair = true;
        await openSheet(tester);
        service.recoveryNeedsRepair = false;
        notifier(tester).publishSnapshot();
        await tester.pumpAndSettle();
        expect(find.text(l10n.listRecoveryReadOnly), findsNothing);
        await tester.tap(find.text('Empty'));
        await tester.pump();
        expect(rowChecks(), findsOneWidget);
        expect(
          tester
              .widget<ListPickerCreateButton>(
                find.byType(ListPickerCreateButton),
              )
              .onPressed,
          isNotNull,
        );
      });

      testWidgets(
        'initialization failure offers a local retry that opens after recovery',
        (tester) async {
          when(() => service.myLists).thenReturn([list('Restored')]);
          await openSheet(tester, listsState: _RetryableCuratedListsState.new);
          expect(find.byType(SelectListSheetBody), findsNothing);
          expect(find.text(l10n.listErrorLoading), findsOneWidget);
          _retryInitializationFails = false;
          await tester.tap(find.text(l10n.searchTryAgain));
          await tester.pumpAndSettle();
          expect(find.text('Restored'), findsOneWidget);
        },
      );

      testWidgets(
        'an open picker exposes Retry after its service refresh fails',
        (tester) async {
          when(() => service.myLists).thenReturn([list('Stored')]);
          await openSheet(tester);
          notifier(tester).failRefresh();
          await tester.pumpAndSettle();
          expect(find.text(l10n.listErrorLoading), findsOneWidget);
          expect(
            tester
                .widget<ListPickerCreateButton>(
                  find.byType(ListPickerCreateButton),
                )
                .onPressed,
            isNull,
          );
          await tester.tap(find.text(l10n.searchTryAgain));
          await tester.pumpAndSettle();
          expect(find.text('Stored'), findsOneWidget);
          expect(
            tester
                .widget<ListPickerCreateButton>(
                  find.byType(ListPickerCreateButton),
                )
                .onPressed,
            isNotNull,
          );
        },
      );
    });

    group('interactions', () {
      testWidgets('tapping rows picks and unpicks them without writing', (
        tester,
      ) async {
        when(() => service.myLists).thenReturn([
          list('Holds it', videoEventIds: const [_videoEventId]),
          list('Empty'),
        ]);
        await openSheet(tester);

        await tester.tap(find.text('Empty'));
        await tester.pump();
        expect(rowChecks(), findsNWidgets(2));

        await tester.tap(find.text('Holds it'));
        await tester.pump();
        expect(rowChecks(), findsOneWidget);

        verifyNever(() => service.addVideoToList(any(), any()));
        verifyNever(() => service.removeVideoFromList(any(), any()));
      });

      testWidgets('the check writes every pick, so one visit can add the '
          'video to several lists, then closes', (tester) async {
        when(() => service.myLists).thenReturn([
          list('Holds it', videoEventIds: const [_videoEventId]),
          list('First'),
          list('Second'),
        ]);
        when(() => service.addVideoToList(any(), any()))
            .thenAnswer((_) async => true);
        when(() => service.removeVideoFromList(any(), any()))
            .thenAnswer((_) async => true);
        await openSheet(tester);

        await tester.tap(find.text('First'));
        await tester.tap(find.text('Second'));
        await tester.tap(find.text('Holds it'));
        await tester.pump();
        await tester.tap(saveButton());
        await tester.pumpAndSettle();

        verify(() => service.addVideoToList('list_first', _videoEventId))
            .called(1);
        verify(() => service.addVideoToList('list_second', _videoEventId))
            .called(1);
        verify(
          () => service.removeVideoFromList('list_holds_it', _videoEventId),
        ).called(1);
        expect(find.byType(SelectListSheetBody), findsNothing);
      });

      testWidgets('with the video in no list, the check is disabled until a '
          'list is picked, and again once it is unpicked', (tester) async {
        when(() => service.myLists).thenReturn([list('Empty')]);
        await openSheet(tester);

        expect(
          saveButtonNode(),
          isSemantics(hasEnabledState: true, isEnabled: false),
        );

        await tester.tap(find.text('Empty'));
        await tester.pump();
        expect(
          saveButtonNode(),
          isSemantics(hasEnabledState: true, isEnabled: true),
        );

        await tester.tap(find.text('Empty'));
        await tester.pump();
        expect(
          saveButtonNode(),
          isSemantics(hasEnabledState: true, isEnabled: false),
        );
      });

      testWidgets('unpicking the only list that holds the video leaves the '
          'check enabled, and the check takes the video out', (tester) async {
        when(() => service.myLists).thenReturn([
          list('Holds it', videoEventIds: const [_videoEventId]),
        ]);
        when(() => service.removeVideoFromList(any(), any()))
            .thenAnswer((_) async => true);
        await openSheet(tester);

        await tester.tap(find.text('Holds it'));
        await tester.pump();
        expect(rowChecks(), findsNothing);
        expect(
          saveButtonNode(),
          isSemantics(hasEnabledState: true, isEnabled: true),
        );

        await tester.tap(saveButton());
        await tester.pumpAndSettle();

        verify(
          () => service.removeVideoFromList('list_holds_it', _videoEventId),
        ).called(1);
        expect(find.byType(SelectListSheetBody), findsNothing);
      });

      testWidgets('the check closes at once when nothing was changed', (
        tester,
      ) async {
        when(() => service.myLists).thenReturn([
          list('Holds it', videoEventIds: const [_videoEventId]),
        ]);
        await openSheet(tester);

        await tester.tap(saveButton());
        await tester.pumpAndSettle();

        expect(find.byType(SelectListSheetBody), findsNothing);
        verifyNever(() => service.addVideoToList(any(), any()));
        verifyNever(() => service.removeVideoFromList(any(), any()));
      });

      testWidgets('a refused change keeps the sheet open, says so, and keeps '
          'the pick for a retry', (tester) async {
        when(() => service.myLists).thenReturn([list('Refuses')]);
        when(() => service.addVideoToList(any(), any()))
            .thenAnswer((_) async => false);
        await openSheet(tester);

        await tester.tap(find.text('Refuses'));
        await tester.pump();
        await tester.tap(saveButton());
        await tester.pumpAndSettle();

        expect(find.byType(SelectListSheetBody), findsOneWidget);
        expect(find.text(l10n.listUpdateFailed), findsOneWidget);
        expect(find.text(l10n.listPrivateFull), findsNothing);
        expect(rowChecks(), findsOneWidget);
      });

      testWidgets(
        'a refusal after closing a pending save is reported underneath',
        (tester) async {
          final answer = Completer<bool>();
          when(() => service.myLists).thenReturn([list('Refuses')]);
          when(() => service.addVideoToList(any(), any()))
              .thenAnswer((_) => answer.future);
          await openSheet(tester);
          await tester.tap(find.text('Refuses'));
          await tester.pump();
          await tester.tap(saveButton());
          await tester.pump();
          await tester.tap(find.bySemanticsLabel(l10n.commonClose));
          await tester.pumpAndSettle();
          expect(find.byType(SelectListSheetBody), findsNothing);

          answer.complete(false);
          await tester.pumpAndSettle();
          expect(find.text(l10n.listUpdateFailed), findsOneWidget);
          expect(find.text(_openLabel), findsOneWidget);
          expect(tester.takeException(), isNull);
        },
      );

      testWidgets('a full private list explains why rather than asking for '
          'a retry', (tester) async {
        // Before #7331 a failed toggle rendered nothing at all, so a private
        // list at the NIP-44 size ceiling swallowed every add silently.
        when(() => service.myLists).thenReturn([
          list(
            'Full',
            isPublic: false,
            // Enough references that one more cannot fit in a single NIP-44
            // plaintext, so the converter's real arithmetic decides.
            videoEventIds: [
              for (var i = 0; i < 1000; i++) i.toString().padLeft(64, '0'),
            ],
          ),
        ]);
        when(() => service.addVideoToList(any(), any()))
            .thenAnswer((_) async => false);
        await openSheet(tester);

        await tester.tap(find.text('Full'));
        await tester.pump();
        await tester.tap(saveButton());
        await tester.pumpAndSettle();

        expect(find.text(l10n.listPrivateFull), findsOneWidget);
        expect(find.text(l10n.listUpdateFailed), findsNothing);
      });

      testWidgets(
        'Sync now keeps the existing video checked and does not toggle it',
        (tester) async {
          final pending = list(
            'Pending',
            videoEventIds: const [_videoEventId],
          ).copyWith(pendingRepublish: true);
          when(() => service.myLists).thenReturn([pending]);
          when(() => service.retryListSync(pending.id))
              .thenAnswer((_) async => true);
          await openSheet(tester);
          expect(find.text(l10n.listVideoPendingSync), findsOneWidget);
          expect(rowChecks(), findsOneWidget);
          await tester.tap(find.text(l10n.listRetrySync));
          await tester.pumpAndSettle();
          expect(rowChecks(), findsOneWidget);
          verify(() => service.retryListSync(pending.id)).called(1);
          verifyNever(() => service.addVideoToList(any(), any()));
          verifyNever(() => service.removeVideoFromList(any(), any()));
        },
      );

      testWidgets(
        'accepted permission recovery offers Sync now without resubmitting picks',
        (tester) async {
          final pending =
              list(
                'Accepted change',
                videoEventIds: const [_videoEventId],
              ).copyWith(
                pendingRepublish: true,
                pendingVisibility: const CuratedListVisibility(
                  isPublic: false,
                  isCollaborative: false,
                  allowedCollaborators: [],
                  relayAccepted: true,
                ),
              );
          when(() => service.myLists).thenReturn([pending]);
          when(() => service.retryListSync(pending.id))
              .thenAnswer((_) async => false);
          await openSheet(tester);

          expect(
            find.text(l10n.listPermissionsRecoveryPending),
            findsOneWidget,
          );
          expect(find.text(l10n.listVideoPendingSync), findsNothing);
          expect(rowChecks(), findsOneWidget);
          await tester.tap(find.text(pending.name));
          await tester.pump();
          expect(rowChecks(), findsOneWidget);
          await tester.tap(find.text(l10n.listRetrySync));
          await tester.pumpAndSettle();

          expect(
            find.text(l10n.listPermissionsRecoveryPending),
            findsOneWidget,
          );
          expect(find.text(l10n.listUpdateFailed), findsNothing);
          expect(find.text(l10n.listRetrySync), findsOneWidget);
          expect(rowChecks(), findsOneWidget);
          verify(() => service.retryListSync(pending.id)).called(1);
          verifyNever(() => service.addVideoToList(any(), any()));
          verifyNever(() => service.removeVideoFromList(any(), any()));
        },
      );

      testWidgets(
        'ordinary sync errors remain visible beside accepted permission recovery',
        (tester) async {
          final accepted = list('Accepted change').copyWith(
            pendingVisibility: const CuratedListVisibility(
              isPublic: false,
              isCollaborative: false,
              allowedCollaborators: [],
              relayAccepted: true,
            ),
          );
          final ordinary = list('Ordinary change')
              .copyWith(pendingRepublish: true);
          when(() => service.myLists).thenReturn([accepted, ordinary]);
          when(() => service.retryListSync(any()))
              .thenAnswer((_) async => false);
          await openSheet(tester);
          await tester.tap(find.text(l10n.listRetrySync).first);
          await tester.pumpAndSettle();
          expect(find.text(l10n.listUpdateFailed), findsNothing);
          expect(
            find.text(l10n.listPermissionsRecoveryPending),
            findsOneWidget,
          );
          await tester.tap(find.text(l10n.listRetrySync).last);
          await tester.pumpAndSettle();
          expect(find.text(l10n.listUpdateFailed), findsOneWidget);
          expect(
            find.text(l10n.listPermissionsRecoveryPending),
            findsOneWidget,
          );
          expect(find.text(l10n.listRetrySync), findsNWidgets(2));
          verify(() => service.retryListSync(accepted.id)).called(1);
          verify(() => service.retryListSync(ordinary.id)).called(1);
          verifyNever(() => service.addVideoToList(any(), any()));
          verifyNever(() => service.removeVideoFromList(any(), any()));
        },
      );

      testWidgets(
        'deletion-only Sync now uses recovery copy and keeps the row unpicked',
        (tester) async {
          final pending = list('Redaction')
              .copyWith(pendingPlaintextEventIds: ['c' * 64]);
          when(() => service.myLists).thenReturn([pending]);
          when(() => service.retryListSync(pending.id))
              .thenAnswer((_) async => false);
          await openSheet(tester);
          expect(find.text(l10n.listRecoveryPending), findsOneWidget);
          expect(find.text(l10n.listVideoPendingSync), findsNothing);
          expect(find.text(l10n.listRetrySync), findsOneWidget);
          expect(rowChecks(), findsNothing);
          await tester.tap(find.text(l10n.listRetrySync));
          await tester.pumpAndSettle();
          expect(rowChecks(), findsNothing);
          expect(find.text(l10n.listUpdateFailed), findsOneWidget);
          verify(() => service.retryListSync(pending.id)).called(1);
          verifyNever(() => service.addVideoToList(any(), any()));
          verifyNever(() => service.removeVideoFromList(any(), any()));
        },
      );

      testWidgets(
        'a newer public winner with deletion evidence remains editable after a refused Sync',
        (tester) async {
          final winner = list('Public winner').copyWith(
            nostrEventId: 'd' * 64,
            updatedAt: DateTime(2026, 1, 2),
            pendingPlaintextEventIds: ['c' * 64],
          );
          when(() => service.myLists).thenReturn([winner]);
          when(() => service.retryListSync(winner.id))
              .thenAnswer((_) async => false);
          await openSheet(tester);
          final publicMeta =
              '${l10n.listVideoCount(0)} • ${l10n.listVisibilityPublic}';
          final privateMeta =
              '${l10n.listVideoCount(0)} • ${l10n.listVisibilityPrivate}';
          expect(find.text(publicMeta), findsOneWidget);
          expect(find.text(privateMeta), findsNothing);
          expect(find.text(l10n.listRecoveryPending), findsOneWidget);
          expect(find.text(l10n.listVideoPendingSync), findsNothing);
          expect(find.text(l10n.listRetrySync), findsOneWidget);
          await tester.tap(find.text('Public winner'));
          await tester.pump();
          expect(rowChecks(), findsOneWidget);

          await tester.tap(find.text(l10n.listRetrySync));
          await tester.pumpAndSettle();

          expect(find.text(publicMeta), findsOneWidget);
          expect(find.text(privateMeta), findsNothing);
          expect(find.text(l10n.listUpdateFailed), findsOneWidget);
          expect(find.text(l10n.listRecoveryPending), findsOneWidget);
          expect(rowChecks(), findsOneWidget);
          expect(service.myLists.single.pendingVisibility, isNull);
          expect(service.myLists.single.pendingPlaintextEventIds, ['c' * 64]);
          await tester.tap(find.text('Public winner'));
          await tester.pump();
          expect(rowChecks(), findsNothing);
          verify(() => service.retryListSync(winner.id)).called(1);
          verifyNever(() => service.addVideoToList(any(), any()));
          verifyNever(() => service.removeVideoFromList(any(), any()));
        },
      );

      for (final locale in [const Locale('en'), const Locale('ar')]) {
        for (final acknowledgedPublic in [false, true]) {
          final direction = locale.languageCode == 'ar'
              ? TextDirection.rtl
              : TextDirection.ltr;
          testWidgets(
            'ACKed ${acknowledgedPublic ? 'Public' : 'Private'} stays visible before and after Sync in ${locale.languageCode}',
            (tester) async {
              final strings = lookupAppLocalizations(locale);
              final pending = list('Recovery', isPublic: !acknowledgedPublic)
                  .copyWith(
                    pendingVisibility: CuratedListVisibility(
                      isPublic: acknowledgedPublic,
                      isCollaborative: false,
                      allowedCollaborators: const [],
                      relayAccepted: true,
                    ),
                  );
              final acceptedLabel = acknowledgedPublic
                  ? strings.listVisibilityPublic
                  : strings.listVisibilityPrivate;
              final oldLabel = acknowledgedPublic
                  ? strings.listVisibilityPrivate
                  : strings.listVisibilityPublic;
              final acceptedMeta =
                  '${strings.listVideoCount(0)} • $acceptedLabel';
              final oldMeta = '${strings.listVideoCount(0)} • $oldLabel';
              when(() => service.myLists).thenReturn([pending]);
              when(() => service.retryListSync(pending.id))
                  .thenAnswer((_) async {
                    when(() => service.myLists).thenReturn([
                      pending.copyWith(
                        isPublic: acknowledgedPublic,
                        clearPendingVisibility: true,
                      ),
                    ]);
                    return true;
                  });
              await openSheet(tester, locale: locale);
              expect(find.text(acceptedMeta), findsOneWidget);
              expect(find.text(oldMeta), findsNothing);
              expect(
                find.text(strings.listPermissionsRecoveryPending),
                findsOneWidget,
              );
              expect(find.text(strings.listRecoveryPending), findsNothing);
              expect(find.text(strings.listVideoPendingSync), findsNothing);
              expect(
                Directionality.of(tester.element(find.text('Recovery'))),
                direction,
              );
              await tester.tap(find.text('Recovery'));
              await tester.pump();
              expect(rowChecks(), findsNothing);
              await tester.tap(find.text(strings.listRetrySync));
              await tester.pumpAndSettle();
              expect(find.text(acceptedMeta), findsOneWidget);
              expect(find.text(oldMeta), findsNothing);
              expect(
                find.text(strings.listPermissionsRecoveryPending),
                findsNothing,
              );
              expect(find.text(strings.listRecoveryPending), findsNothing);
              expect(find.text(strings.listRetrySync), findsNothing);
              expect(rowChecks(), findsNothing);
              await tester.tap(find.text('Recovery'));
              await tester.pump();
              expect(rowChecks(), findsOneWidget);
              verify(() => service.retryListSync(pending.id)).called(1);
              verifyNever(() => service.addVideoToList(any(), any()));
              verifyNever(() => service.removeVideoFromList(any(), any()));
            },
          );
        }
      }

      for (final currentPublic in [false, true]) {
        testWidgets(
          'an unconfirmed proposal keeps the current ${currentPublic ? 'Public' : 'Private'} label and editable row',
          (tester) async {
            final unconfirmed = list('Unconfirmed', isPublic: currentPublic)
                .copyWith(
                  pendingVisibility: CuratedListVisibility(
                    isPublic: !currentPublic,
                    isCollaborative: false,
                    allowedCollaborators: const [],
                  ),
                );
            final currentLabel = currentPublic
                ? l10n.listVisibilityPublic
                : l10n.listVisibilityPrivate;
            final proposalLabel = currentPublic
                ? l10n.listVisibilityPrivate
                : l10n.listVisibilityPublic;
            when(() => service.myLists).thenReturn([unconfirmed]);
            await openSheet(tester);
            expect(
              find.text('${l10n.listVideoCount(0)} • $currentLabel'),
              findsOneWidget,
            );
            expect(
              find.text('${l10n.listVideoCount(0)} • $proposalLabel'),
              findsNothing,
            );
            expect(find.text(l10n.listRecoveryPending), findsNothing);
            expect(find.text(l10n.listRetrySync), findsNothing);
            await tester.tap(find.text('Unconfirmed'));
            await tester.pump();
            expect(rowChecks(), findsOneWidget);
            verifyNever(() => service.retryListSync(any()));
            verifyNever(() => service.addVideoToList(any(), any()));
            verifyNever(() => service.removeVideoFromList(any(), any()));
          },
        );
      }

      testWidgets(
        'an account change suppresses a dismissed pending save refusal',
        (tester) async {
          final answer = Completer<bool>();
          when(() => service.myLists).thenReturn([list('Empty')]);
          when(() => service.addVideoToList(any(), any()))
              .thenAnswer((_) => answer.future);
          await openSheet(tester);
          await tester.tap(find.text('Empty'));
          await tester.pump();
          await tester.tap(saveButton());
          await tester.pump();
          await tester.tap(find.bySemanticsLabel(l10n.commonClose));
          await tester.pumpAndSettle();
          activeOwner = 'e' * 64;
          answer.complete(false);
          await tester.pumpAndSettle();
          expect(find.byType(SnackBar), findsNothing);
        },
      );

      testWidgets(
        'pending membership sync exposes progress and failure then clears on acceptance',
        (tester) async {
          final pending = list(
            'Pending',
            videoEventIds: [_videoEventId],
          ).copyWith(pendingRepublish: true);
          when(() => service.myLists).thenReturn([pending]);
          final answer = Completer<bool>();
          addTearDown(() {
            if (!answer.isCompleted) answer.complete(false);
          });
          when(() => service.retryListSync(pending.id))
              .thenAnswer((_) => answer.future);
          await openSheet(tester);
          final listener =
              verify(() => service.addListener(captureAny())).captured.single
                  as VoidCallback;
          await tester.tap(find.text(l10n.listRetrySync));
          await tester.pump();
          expect(
            find.byType(DivineCircularProgressIndicator),
            findsNWidgets(2),
          );
          expect(find.text(l10n.listRetrySync), findsNothing);
          expect(rowChecks(), findsOneWidget);
          answer.complete(false);
          await tester.pumpAndSettle();
          expect(find.text(l10n.listUpdateFailed), findsOneWidget);
          expect(find.text(l10n.listVideoPendingSync), findsOneWidget);
          expect(find.text(l10n.listRetrySync), findsOneWidget);
          when(() => service.retryListSync(pending.id)).thenAnswer((_) async {
            when(() => service.myLists)
                .thenReturn([pending.copyWith(pendingRepublish: false)]);
            listener();
            return true;
          });
          await tester.tap(find.text(l10n.listRetrySync));
          await tester.pumpAndSettle();
          expect(find.text(l10n.listVideoPendingSync), findsNothing);
          expect(find.text(l10n.listUpdateFailed), findsNothing);
          expect(find.text(l10n.listRetrySync), findsNothing);
          expect(rowChecks(), findsOneWidget);
        },
      );

      testWidgets(
        'account scope replacement safely settles a dismissed membership save',
        (tester) async {
          final controller = AccountSwitchController();
          final first = ProviderContainer(
            overrides: [
              ...getStandardTestOverrides(mockAuthService: auth),
              curatedListsStateProvider.overrideWith(
                _FakeCuratedListsState.new,
              ),
              myListsWithThumbnailsProvider.overrideWith((ref) async => []),
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
              myListsWithThumbnailsProvider.overrideWith((ref) async => []),
            ],
          );
          when(() => service.myLists).thenReturn([list('Empty')]);
          final answer = Completer<bool>();
          addTearDown(() {
            if (!answer.isCompleted) answer.complete(false);
          });
          when(() => service.addVideoToList(any(), any()))
              .thenAnswer((_) => answer.future);
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
                        showSelectListSheet(context, video: video),
                        'open picker during account replacement',
                        logName: 'SelectListSheetTest',
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
          final cubit = tester
              .element(find.byType(SelectListSaveButton))
              .read<SelectListCubit>();
          await tester.tap(find.text('Empty'));
          await tester.pump();
          await tester.tap(saveButton());
          await tester.pump();
          await tester.tap(find.bySemanticsLabel(l10n.commonClose));
          await tester.pumpAndSettle();
          await controller.swapTo(next);
          await tester.pumpAndSettle();
          expect(() => first.read(authServiceProvider), throwsStateError);
          expect(cubit.isClosed, isTrue);
          expect(cubit.isSessionCurrent, isFalse);
          answer.complete(false);
          await tester.pumpAndSettle();
          expect(find.byType(SnackBar), findsNothing);
          expect(tester.takeException(), isNull);
        },
      );

      testWidgets('the X closes without writing the picks', (tester) async {
        when(() => service.myLists).thenReturn([list('Empty')]);
        await openSheet(tester);

        await tester.tap(find.text('Empty'));
        await tester.pump();
        await tester.tap(find.bySemanticsLabel(l10n.commonClose));
        await tester.pumpAndSettle();

        expect(find.byType(SelectListSheetBody), findsNothing);
        verifyNever(() => service.addVideoToList(any(), any()));
      });

      testWidgets('a created list that refused the video says so inside the '
          'picker, where a line underneath would be covered', (tester) async {
        when(() => service.myLists).thenReturn([list('Empty')]);
        final fresh = list('Fresh');
        when(
          () => service.createList(
            name: any(named: 'name'),
            description: any(named: 'description'),
            isPublic: any(named: 'isPublic'),
            isCollaborative: any(named: 'isCollaborative'),
            allowedCollaborators: any(named: 'allowedCollaborators'),
          ),
        ).thenAnswer((_) async => fresh);
        when(() => service.addVideoToList(any(), any()))
            .thenAnswer((_) async => false);
        await openSheet(tester);

        await tester.tap(find.text(l10n.listCreateNewList));
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextField).first, 'Fresh');
        await tester.pump();
        await tester.tap(find.bySemanticsLabel(l10n.listCreate));
        await tester.pumpAndSettle();

        expect(find.byType(ListInfoForm), findsNothing);
        expect(find.byType(SelectListSheetBody), findsOneWidget);
        expect(find.text(l10n.listVideoNotAdded), findsOneWidget);
        expect(find.byType(SnackBar), findsNothing);
      });

      for (final dismissPicker in [false, true]) {
        testWidgets(
          dismissPicker
              ? 'a created list that refuses the video after both sheets '
                    'close reports the failure underneath once'
              : 'a created list that refuses the video after creation closes '
                    'reports the failure inside the remaining picker',
          (tester) async {
            final answer = Completer<bool>();
            when(() => service.myLists).thenReturn([list('Empty')]);
            when(
              () => service.createList(
                name: any(named: 'name'),
                description: any(named: 'description'),
                isPublic: any(named: 'isPublic'),
                isCollaborative: any(named: 'isCollaborative'),
                allowedCollaborators: any(named: 'allowedCollaborators'),
              ),
            ).thenAnswer((_) async => list('Fresh'));
            when(() => service.addVideoToList(any(), any()))
                .thenAnswer((_) => answer.future);
            await openSheet(tester);
            await tester.tap(find.text(l10n.listCreateNewList));
            await tester.pumpAndSettle();
            await tester.enterText(find.byType(TextField).first, 'Fresh');
            await tester.pump();
            await tester.tap(find.bySemanticsLabel(l10n.listCreate));
            await tester.pump();
            verify(() => service.addVideoToList('list_fresh', _videoEventId))
                .called(1);

            await tester.tap(find.bySemanticsLabel(l10n.commonClose).last);
            await tester.pumpAndSettle();
            expect(find.byType(ListInfoForm), findsNothing);
            if (dismissPicker) {
              await tester.tap(find.bySemanticsLabel(l10n.commonClose));
              await tester.pumpAndSettle();
            }

            answer.complete(false);
            await tester.pumpAndSettle();

            expect(find.text(l10n.listVideoNotAdded), findsOneWidget);
            expect(
              find.byType(SelectListSheetBody),
              dismissPicker ? findsNothing : findsOneWidget,
            );
            expect(
              find.byType(SnackBar),
              dismissPicker ? findsOneWidget : findsNothing,
            );
            expect(tester.takeException(), isNull);
            if (dismissPicker) {
              await tester.pump(const Duration(seconds: 10));
              await tester.pumpAndSettle();
              expect(find.byType(SnackBar), findsNothing);
            }
          },
        );
      }

      testWidgets(
        'a newly created list with local video pending sync stays checked and offers sync',
        (tester) async {
          final empty = list('Empty');
          final fresh = list('Fresh');
          final pending = fresh.copyWith(
            videoEventIds: const [_videoEventId],
            pendingRepublish: true,
          );
          late VoidCallback listener;
          when(() => service.myLists).thenReturn([empty]);
          when(
            () => service.createList(
              name: any(named: 'name'),
              description: any(named: 'description'),
              isPublic: any(named: 'isPublic'),
              isCollaborative: any(named: 'isCollaborative'),
              allowedCollaborators: any(named: 'allowedCollaborators'),
            ),
          ).thenAnswer((_) async => fresh);
          when(() => service.getListById(fresh.id)).thenReturn(pending);
          when(() => service.addVideoToList(fresh.id, _videoEventId))
              .thenAnswer((_) async {
                when(() => service.myLists).thenReturn([empty, pending]);
                listener();
                return false;
              });
          when(() => service.retryListSync(fresh.id)).thenAnswer((_) async {
            when(() => service.myLists)
                .thenReturn([empty, pending.copyWith(pendingRepublish: false)]);
            listener();
            return true;
          });
          await openSheet(tester);
          listener =
              verify(() => service.addListener(captureAny())).captured.single
                  as VoidCallback;
          await tester.tap(find.text(l10n.listCreateNewList));
          await tester.pumpAndSettle();
          await tester.enterText(find.byType(TextField).first, 'Fresh');
          await tester.pump();
          await tester.tap(find.bySemanticsLabel(l10n.listCreate));
          await tester.pumpAndSettle();
          expect(find.byType(ListInfoForm), findsNothing);
          expect(find.text(l10n.listVideoNotAdded), findsNothing);
          expect(find.text(l10n.listVideoPendingSync), findsWidgets);
          expect(rowChecks(), findsOneWidget);
          await tester.tap(find.text(l10n.listRetrySync));
          await tester.pumpAndSettle();
          expect(rowChecks(), findsOneWidget);
          expect(find.text(l10n.listRetrySync), findsNothing);
          expect(find.text(l10n.listVideoPendingSync), findsNothing);
          verify(() => service.retryListSync(fresh.id)).called(1);
          verify(() => service.addVideoToList(fresh.id, _videoEventId))
              .called(1);
          verifyNever(() => service.removeVideoFromList(any(), any()));
        },
      );

      testWidgets('Create new list opens the create sheet, and the list it '
          'creates shows up picked', (tester) async {
        when(() => service.myLists).thenReturn([list('Empty')]);
        final fresh = list('Fresh', videoEventIds: const [_videoEventId]);
        when(
          () => service.createList(
            name: any(named: 'name'),
            description: any(named: 'description'),
            isPublic: any(named: 'isPublic'),
            isCollaborative: any(named: 'isCollaborative'),
            allowedCollaborators: any(named: 'allowedCollaborators'),
          ),
        ).thenAnswer((_) async => fresh);
        when(() => service.addVideoToList(any(), any()))
            .thenAnswer((_) async => true);
        await openSheet(tester);

        await tester.tap(find.text(l10n.listCreateNewList));
        await tester.pumpAndSettle();
        expect(find.byType(ListInfoForm), findsOneWidget);

        await tester.enterText(find.byType(TextField).first, 'Fresh');
        await tester.pump();
        await tester.tap(find.bySemanticsLabel(l10n.listCreate));
        await tester.pumpAndSettle();
        expect(find.byType(ListInfoForm), findsNothing);
        verify(() => service.addVideoToList(fresh.id, _videoEventId)).called(1);

        // The real service tells its listeners once the list exists.
        final listener =
            verify(() => service.addListener(captureAny())).captured.single
                as VoidCallback;
        when(() => service.myLists).thenReturn([list('Empty'), fresh]);
        listener();
        // One frame delivers the cubit's state, the next rebuilds the rows.
        await tester.pump();
        await tester.pump();

        expect(find.text('Fresh'), findsOneWidget);
        expect(rowChecks(), findsOneWidget);
      });
    });
  });
}
