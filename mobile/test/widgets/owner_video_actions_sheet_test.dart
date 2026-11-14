// ABOUTME: Tests the shared owner-video action sheet helper.
// ABOUTME: Pins the onDeleted contract that lets the two grids differ.

import 'dart:async';

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:nostr_sdk/event.dart';
import 'package:openvine/blocs/owner_video_actions/owner_video_actions_cubit.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/repositories/creator_delete_enforcement_repository.dart';
import 'package:openvine/services/content_deletion_service.dart';
import 'package:openvine/services/video_event_service.dart';
import 'package:openvine/widgets/owner_video_actions_sheet.dart';

class _MockContentDeletionService extends Mock
    implements ContentDeletionService {}

class _MockVideoEventService extends Mock implements VideoEventService {}

class _MockEnforcementRepository extends Mock
    implements CreatorDeleteEnforcementRepository {}

class _FakeVideoEvent extends Fake implements VideoEvent {}

/// Runs [onDispose] when its subtree leaves the tree.
class _OnDispose extends StatefulWidget {
  const _OnDispose({required this.onDispose, required this.child});

  final VoidCallback onDispose;
  final Widget child;

  @override
  State<_OnDispose> createState() => _OnDisposeState();
}

class _OnDisposeState extends State<_OnDispose> {
  @override
  void dispose() {
    widget.onDispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

void main() {
  group('showOwnerVideoActionsSheet', () {
    final l10n = lookupAppLocalizations(const Locale('en'));
    final video = VideoEvent(
      id: '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef',
      pubkey:
          'abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789',
      createdAt: 1757385263,
      content: 'Test video content',
      timestamp: DateTime.fromMillisecondsSinceEpoch(1757385263 * 1000),
      videoUrl: 'https://example.com/video.mp4',
    );
    final deletionEvent = Event.fromJson({
      'id': 'delete-event-id',
      'pubkey': video.pubkey,
      'created_at': 1757385263,
      'kind': 5,
      'tags': [
        ['e', video.id],
      ],
      'content': '',
      'sig': '12' * 64,
    });

    late _MockContentDeletionService deletionService;
    late _MockVideoEventService videoEventService;
    late _MockEnforcementRepository enforcementRepository;
    late OwnerVideoActionsCubit cubit;

    setUpAll(() => registerFallbackValue(_FakeVideoEvent()));

    setUp(() {
      deletionService = _MockContentDeletionService();
      videoEventService = _MockVideoEventService();
      enforcementRepository = _MockEnforcementRepository();
      when(
        () => enforcementRepository.enforce(
          any(),
          deletionEvent: any(named: 'deletionEvent'),
        ),
      ).thenAnswer(
        (_) async => const CreatorDeleteEnforcementResult.confirmed(),
      );
      when(
        () => videoEventService.removeVideoEventCompletely(any()),
      ).thenAnswer((_) async {});
      cubit = OwnerVideoActionsCubit(
        contentDeletionService: () async => deletionService,
        videoEventService: () => videoEventService,
        enforcementRepository: () => enforcementRepository,
      );
    });

    tearDown(() => cubit.close());

    void stubDelete({required bool success}) {
      when(
        () => deletionService.quickDelete(
          video: video,
          reason: DeleteReason.personalChoice,
        ),
      ).thenAnswer(
        (_) async => success
            ? DeleteResult.createSuccess(
                'delete-event-id',
                acceptance: DeleteAcceptance.everyRelay,
                deleteEvent: deletionEvent,
              )
            : DeleteResult.failure(
                'rejected',
                DeleteFailureKind.relayRejected,
              ),
      );
    }

    Future<List<String>> openSheetAndDelete(WidgetTester tester) async {
      final calls = <String>[];
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: appLocalizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => showOwnerVideoActionsSheet(
                  context: context,
                  video: video,
                  cubit: cubit,
                  onEditRequested: () => calls.add('edit'),
                  onDeleted: () async => calls.add('deleted'),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.videoGridDeleteVideo));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.shareMenuDelete));
      await tester.pumpAndSettle();
      return calls;
    }

    testWidgets('runs onDeleted after a successful delete', (tester) async {
      stubDelete(success: true);

      final calls = await openSheetAndDelete(tester);

      expect(calls, contains('deleted'));
    });

    testWidgets('does not run onDeleted when the delete fails', (tester) async {
      stubDelete(success: false);

      final calls = await openSheetAndDelete(tester);

      expect(
        calls,
        isNot(contains('deleted')),
        reason:
            "onDeleted drops the tile from the caller's feed, so running it "
            'on a failed delete would hide a video that still exists.',
      );
    });

    testWidgets('reports a failed delete to the user', (tester) async {
      stubDelete(success: false);

      await openSheetAndDelete(tester);

      expect(find.byType(SnackBar), findsOneWidget);
    });

    group('confirmAndDeleteOwnerVideo', () {
      const sheetButton = 'delete from sheet';

      testWidgets(
        'still confirms the delete when onDeleted closes the sheet it was '
        'started from',
        (tester) async {
          stubDelete(success: true);
          // Holding cleanup open keeps the outcome on its first message, so
          // the cleanup-completion snackbar cannot queue ahead of it.
          final cleanup = Completer<CreatorDeleteEnforcementResult>();
          when(
            () => enforcementRepository.enforce(
              any(),
              deletionEvent: any(named: 'deletionEvent'),
            ),
          ).thenAnswer((_) => cleanup.future);
          late BuildContext opener;
          await tester.pumpWidget(
            MaterialApp(
              localizationsDelegates: appLocalizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Scaffold(
                body: Builder(
                  builder: (context) {
                    opener = context;
                    return const SizedBox();
                  },
                ),
              ),
            ),
          );
          // onDeleted returns only once the sheet is gone, so the context the
          // delete was started from is unmounted by the time it resolves.
          final sheetDisposed = Completer<void>();
          unawaited(
            VineBottomSheet.show<void>(
              context: opener,
              body: _OnDispose(
                onDispose: sheetDisposed.complete,
                child: Builder(
                  builder: (sheetContext) => TextButton(
                    onPressed: () => confirmAndDeleteOwnerVideo(
                      context: sheetContext,
                      video: video,
                      cubit: cubit,
                      onDeleted: () {
                        Navigator.of(sheetContext).pop();
                        return sheetDisposed.future;
                      },
                    ),
                    child: const Text(sheetButton),
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();

          await tester.tap(find.text(sheetButton));
          await tester.pumpAndSettle();
          await tester.tap(find.text(l10n.shareMenuDelete));
          await tester.pumpAndSettle();

          expect(find.text(sheetButton), findsNothing);
          expect(
            find.text(l10n.shareMenuDeleteCleanupInProgress),
            findsOneWidget,
          );
        },
      );

      testWidgets(
        'reports a failed delete once onFailed has closed the sheet it was '
        'started from',
        (tester) async {
          stubDelete(success: false);
          late BuildContext opener;
          await tester.pumpWidget(
            MaterialApp(
              localizationsDelegates: appLocalizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Scaffold(
                body: Builder(
                  builder: (context) {
                    opener = context;
                    return const SizedBox();
                  },
                ),
              ),
            ),
          );
          final sheetDisposed = Completer<void>();
          var deletedRan = false;
          unawaited(
            VineBottomSheet.show<void>(
              context: opener,
              body: _OnDispose(
                onDispose: sheetDisposed.complete,
                child: Builder(
                  builder: (sheetContext) => TextButton(
                    onPressed: () => confirmAndDeleteOwnerVideo(
                      context: sheetContext,
                      video: video,
                      cubit: cubit,
                      onDeleted: () async => deletedRan = true,
                      onFailed: () {
                        Navigator.of(sheetContext).pop();
                        return sheetDisposed.future;
                      },
                    ),
                    child: const Text(sheetButton),
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();

          await tester.tap(find.text(sheetButton));
          await tester.pumpAndSettle();
          await tester.tap(find.text(l10n.shareMenuDelete));
          await tester.pumpAndSettle();

          expect(deletedRan, isFalse);
          expect(find.text(sheetButton), findsNothing);
          expect(
            find.text(l10n.shareMenuDeleteFailedRelayRejected),
            findsOneWidget,
          );
        },
      );
    });
  });
}
