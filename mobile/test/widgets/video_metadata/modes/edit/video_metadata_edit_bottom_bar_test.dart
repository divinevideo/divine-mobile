import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart' show VideoEvent;
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/models/video_editor/video_editor_provider_state.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/creator_delete_enforcement_providers.dart';
import 'package:openvine/providers/video_editor_provider.dart';
import 'package:openvine/repositories/creator_delete_enforcement_repository.dart';
import 'package:openvine/screens/subtitle_editor/subtitle_editor_screen.dart';
import 'package:openvine/services/content_deletion_service.dart';
import 'package:openvine/services/video_event_service.dart';
import 'package:openvine/services/video_metadata_update_service.dart';
import 'package:openvine/widgets/video_metadata/modes/edit/video_metadata_edit_bottom_bar.dart';
import 'package:riverpod/misc.dart' show Override;

import '../../../../helpers/go_router.dart';
import '../../../../helpers/test_helpers.dart';

class _MockVideoMetadataUpdateService extends Mock
    implements VideoMetadataUpdateService {}

class _MockVideoEditorNotifier extends VideoEditorNotifier {
  @override
  VideoEditorProviderState build() => VideoEditorProviderState();
}

class _MockContentDeletionService extends Mock
    implements ContentDeletionService {}

class _MockEnforcementRepository extends Mock
    implements CreatorDeleteEnforcementRepository {}

class _MockVideoEventService extends Mock implements VideoEventService {}

void main() {
  group(VideoMetadataEditBottomBar, () {
    final l10n = lookupAppLocalizations(const Locale('en'));
    late VideoEvent testVideo;

    setUpAll(() {
      registerFallbackValue(TestHelpers.createVideoEvent(id: 'fallback'));
      registerFallbackValue(VideoEditorProviderState());
      registerFallbackValue(<String>{});
    });

    setUp(() {
      testVideo = TestHelpers.createVideoEvent(
        id: '0000000000000000000000000000000000000000000000000000000000000000',
      );
    });

    Widget buildSubject(
      MockGoRouter goRouter, {
      ValueChanged<VideoEvent>? onVideoUpdated,
      VideoMetadataUpdateService? updateService,
      List<Override> additionalOverrides = const [],
    }) {
      return ProviderScope(
        overrides: [
          ...additionalOverrides,
          videoEditorProvider.overrideWith(_MockVideoEditorNotifier.new),
          if (updateService != null)
            videoMetadataUpdateServiceProvider.overrideWithValue(
              updateService,
            ),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: MockGoRouterProvider(
              goRouter: goRouter,
              child: VideoMetadataEditBottomBar(
                video: testVideo,
                initialCollaboratorPubkeys: const {},
                onVideoUpdated: onVideoUpdated,
              ),
            ),
          ),
        ),
      );
    }

    testWidgets('navigates to subtitle editor when tapped', (tester) async {
      final mockGoRouter = MockGoRouter();
      when(
        () => mockGoRouter.push<VideoEvent>(any(), extra: any(named: 'extra')),
      ).thenAnswer((_) async => null);

      await tester.pumpWidget(buildSubject(mockGoRouter));

      await tester.tap(find.text(l10n.videoEditEditSubtitles));
      await tester.pump();

      verify(
        () => mockGoRouter.push<VideoEvent>(
          SubtitleEditorScreen.pathFor(testVideo.id),
          extra: testVideo,
        ),
      ).called(1);
    });

    testWidgets('adopts returned subtitle editor video', (tester) async {
      final mockGoRouter = MockGoRouter();
      final updatedVideo = testVideo.copyWith(
        id: '1111111111111111111111111111111111111111111111111111111111111111',
        textTrackRef: 'https://media.divine.video/edited.vtt',
      );
      VideoEvent? adopted;
      when(
        () => mockGoRouter.push<VideoEvent>(any(), extra: any(named: 'extra')),
      ).thenAnswer((_) async => updatedVideo);

      await tester.pumpWidget(
        buildSubject(mockGoRouter, onVideoUpdated: (video) => adopted = video),
      );

      await tester.tap(find.text(l10n.videoEditEditSubtitles));
      await tester.pump();

      expect(adopted, updatedVideo);
    });

    testWidgets('uses DivineButton styling for subtitle editing', (
      tester,
    ) async {
      final mockGoRouter = MockGoRouter();

      await tester.pumpWidget(buildSubject(mockGoRouter));

      expect(find.byType(OutlinedButton), findsNothing);
      expect(find.byType(DivineButton), findsNWidgets(3));
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is DivineButton &&
              widget.leadingIcon == DivineIconName.closedCaptioning &&
              widget.type == DivineButtonType.secondary &&
              widget.expanded,
        ),
        findsOneWidget,
      );
    });

    testWidgets('explains when complete original metadata is unavailable', (
      tester,
    ) async {
      final mockGoRouter = MockGoRouter();
      final updateService = _MockVideoMetadataUpdateService();
      when(
        () => updateService.updateVideo(
          originalVideo: any(named: 'originalVideo'),
          editorState: any(named: 'editorState'),
          initialCollaboratorPubkeys: any(
            named: 'initialCollaboratorPubkeys',
          ),
          newThumbnailFile: any(named: 'newThumbnailFile'),
        ),
      ).thenAnswer((_) async => const VideoUpdateOriginalUnavailable());

      await tester.pumpWidget(
        buildSubject(mockGoRouter, updateService: updateService),
      );

      await tester.tap(find.text(l10n.shareMenuUpdate));
      await tester.pump();

      expect(find.byType(SnackBar), findsOneWidget);
      final snackbar = tester.widget<DivineSnackbarContainer>(
        find.byType(DivineSnackbarContainer),
      );
      expect(snackbar.label, l10n.shareMenuOriginalVideoUnavailable);
      expect(snackbar.error, isTrue);
    });

    testWidgets('reenables delete after a failed request', (tester) async {
      final mockGoRouter = MockGoRouter();
      final deletionService = _MockContentDeletionService();
      final enforcementRepository = _MockEnforcementRepository();
      final videoEventService = _MockVideoEventService();
      when(
        () => deletionService.quickDelete(
          video: testVideo,
          reason: DeleteReason.personalChoice,
        ),
      ).thenAnswer(
        (_) async => DeleteResult.failure(
          'relay rejected',
          DeleteFailureKind.relayRejected,
        ),
      );

      await tester.pumpWidget(
        buildSubject(
          mockGoRouter,
          additionalOverrides: [
            contentDeletionServiceProvider.overrideWith(
              (ref) async => deletionService,
            ),
            creatorDeleteEnforcementRepositoryProvider.overrideWithValue(
              enforcementRepository,
            ),
            videoEventServiceProvider.overrideWithValue(videoEventService),
          ],
        ),
      );

      for (var attempt = 0; attempt < 2; attempt++) {
        await tester.tap(find.text(l10n.shareMenuDeleteVideo));
        await tester.pumpAndSettle();
        await tester.tap(find.text(l10n.shareMenuDelete).last);
        await tester.pumpAndSettle();
      }

      verify(
        () => deletionService.quickDelete(
          video: testVideo,
          reason: DeleteReason.personalChoice,
        ),
      ).called(2);
    });
  });
}
