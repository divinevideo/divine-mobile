// ABOUTME: Tests the shared owner-video action sheet helper.
// ABOUTME: Pins the onDeleted contract that lets the two grids differ.

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/owner_video_actions/owner_video_actions_cubit.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
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

    late _MockContentDeletionService deletionService;
    late _MockVideoEventService videoEventService;
    late _MockEnforcementRepository enforcementRepository;
    late OwnerVideoActionsCubit cubit;

    setUpAll(() => registerFallbackValue(_FakeVideoEvent()));

    setUp(() {
      deletionService = _MockContentDeletionService();
      videoEventService = _MockVideoEventService();
      enforcementRepository = _MockEnforcementRepository();
      when(() => enforcementRepository.enforce(any())).thenAnswer(
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
          localizationsDelegates: AppLocalizations.localizationsDelegates,
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
  });
}
