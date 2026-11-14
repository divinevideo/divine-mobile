// ABOUTME: Tests for the action row in the video info sheet.
// ABOUTME: Covers which actions show for whom, their order, and their effects.

import 'package:bloc_test/bloc_test.dart';
import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/owner_video_actions/owner_video_actions_cubit.dart';
import 'package:openvine/blocs/video_content_actions/video_content_actions_bloc.dart';
import 'package:openvine/features/feature_flags/models/feature_flag.dart';
import 'package:openvine/features/feature_flags/providers/feature_flag_providers.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/widgets/video_feed_item/actions/clip_title_sheet.dart';
import 'package:openvine/widgets/video_feed_item/actions/video_content_action_feedback.dart';
import 'package:openvine/widgets/video_feed_item/metadata/metadata_actions_section.dart';

import '../../../helpers/test_provider_overrides.dart';

class _MockVideoContentActionsBloc
    extends MockBloc<VideoContentActionsEvent, VideoContentActionsState>
    implements VideoContentActionsBloc {}

class _MockOwnerVideoActionsCubit extends MockCubit<OwnerVideoActionsState>
    implements OwnerVideoActionsCubit {}

const _videoId =
    '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef';
const _creatorPubkey =
    'abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789';
const _defaultClipTitle = 'Classic clip';

VideoEvent _video({
  Map<String, String> rawTags = const {},
  List<List<String>> tags = const [],
}) {
  return VideoEvent(
    id: _videoId,
    pubkey: _creatorPubkey,
    createdAt: 1757385263,
    content: 'Test video',
    timestamp: DateTime.fromMillisecondsSinceEpoch(1757385263 * 1000),
    videoUrl: 'https://example.com/video.mp4',
    rawTags: rawTags,
    nostrEventTags: tags,
  );
}

final VideoEvent _classicVine = _video(rawTags: const {'platform': 'vine'});

void main() {
  final l10n = lookupAppLocalizations(const Locale('en'));

  late _MockVideoContentActionsBloc contentActions;

  setUpAll(() => registerFallbackValue(const VideoContentSaveRequested()));

  setUp(() {
    contentActions = _MockVideoContentActionsBloc();
  });

  void stubContentActions({bool isSaving = false}) {
    when(
      () => contentActions.state,
    ).thenReturn(VideoContentActionsState(isSaving: isSaving));
    when(() => contentActions.defaultClipTitle).thenReturn(_defaultClipTitle);
  }

  OwnerVideoActionsCubit stubbedOwnerCubit() {
    final cubit = _MockOwnerVideoActionsCubit();
    when(() => cubit.state).thenReturn(const OwnerVideoActionsState());
    when(() => cubit.isDeleteInProgress(any())).thenReturn(false);
    return cubit;
  }

  Widget buildSubject({
    required VideoEvent video,
    VideoContentActionsBloc Function()? createBloc,
    OwnerVideoActionsCubit? ownerCubit,
    bool debugTools = false,
  }) {
    return testMaterialApp(
      additionalOverrides: [
        isFeatureEnabledProvider(
          FeatureFlag.debugTools,
        ).overrideWithValue(debugTools),
      ],
      home: Scaffold(
        body: MultiBlocProvider(
          providers: [
            if (createBloc != null)
              BlocProvider<VideoContentActionsBloc>(create: (_) => createBloc())
            else
              BlocProvider<VideoContentActionsBloc>.value(
                value: contentActions,
              ),
            if (ownerCubit != null)
              BlocProvider<OwnerVideoActionsCubit>.value(value: ownerCubit),
          ],
          child: VideoContentActionsFeedbackListener(
            child: MetadataActionsSection(video: video),
          ),
        ),
      ),
    );
  }

  group(MetadataActionsSection, () {
    group('renders', () {
      testWidgets('nothing when no content actions bloc is provided', (
        tester,
      ) async {
        await tester.pumpWidget(
          testMaterialApp(
            home: Scaffold(body: MetadataActionsSection(video: _classicVine)),
          ),
        );

        expect(find.text(l10n.shareSheetSave), findsNothing);
      });

      testWidgets('Save, Add to clips and Add to list for a classic Vine', (
        tester,
      ) async {
        stubContentActions();
        await tester.pumpWidget(buildSubject(video: _classicVine));

        expect(find.text(l10n.shareSheetSave), findsOneWidget);
        expect(find.text(l10n.shareSheetAddToClips), findsOneWidget);
        expect(find.text(l10n.shareSheetAddToList), findsOneWidget);
        expect(find.text(l10n.shareMenuEditVideo), findsNothing);
        expect(find.text(l10n.shareMenuDeleteVideo), findsNothing);
        expect(find.text(l10n.shareSheetEventJson), findsNothing);
        expect(find.text(l10n.shareSheetEventId), findsNothing);
      });

      testWidgets('Edit and Delete before Save on the viewer own video', (
        tester,
      ) async {
        stubContentActions();
        await tester.pumpWidget(
          buildSubject(video: _video(), ownerCubit: stubbedOwnerCubit()),
        );

        final editX = tester.getTopLeft(find.text(l10n.shareMenuEditVideo)).dx;
        final deleteX = tester
            .getTopLeft(find.text(l10n.shareMenuDeleteVideo))
            .dx;
        final saveX = tester.getTopLeft(find.text(l10n.shareSheetSave)).dx;

        expect(editX, lessThan(deleteX));
        expect(deleteX, lessThan(saveX));
        expect(find.text(l10n.shareSheetAddToClips), findsOneWidget);
      });

      testWidgets(
        'no Add to clips for another creator who does not allow reuse',
        (tester) async {
          stubContentActions();
          final video = _video();
          expect(video.allowVideoReuse, isFalse);

          await tester.pumpWidget(buildSubject(video: video));

          expect(find.text(l10n.shareSheetSave), findsOneWidget);
          expect(find.text(l10n.shareSheetAddToClips), findsNothing);
        },
      );

      testWidgets('a spinner on Save while the bookmark toggle is in flight', (
        tester,
      ) async {
        stubContentActions(isSaving: true);
        await tester.pumpWidget(buildSubject(video: _classicVine));

        expect(find.byType(DivineCircularProgressIndicator), findsOneWidget);
      });
    });

    group('interactions', () {
      testWidgets('tapping Save while it is pending adds nothing', (
        tester,
      ) async {
        stubContentActions(isSaving: true);
        await tester.pumpWidget(buildSubject(video: _classicVine));

        await tester.tap(find.text(l10n.shareSheetSave));
        await tester.pump();

        verifyNever(() => contentActions.add(any()));
      });

      testWidgets('tapping Save requests a bookmark toggle', (tester) async {
        stubContentActions();
        await tester.pumpWidget(buildSubject(video: _classicVine));

        await tester.tap(find.text(l10n.shareSheetSave));
        await tester.pump();

        verify(
          () => contentActions.add(const VideoContentSaveRequested()),
        ).called(1);
      });

      testWidgets('debug tools show Event JSON and copy the Event ID', (
        tester,
      ) async {
        stubContentActions();
        await tester.pumpWidget(
          buildSubject(video: _classicVine, debugTools: true),
        );

        expect(find.text(l10n.shareSheetEventJson), findsOneWidget);
        expect(find.text(l10n.shareSheetEventId), findsOneWidget);

        await tester.tap(find.text(l10n.shareSheetEventId));
        await tester.pump();

        verify(
          () => contentActions.add(const VideoContentCopyEventIdRequested()),
        ).called(1);
      });

      testWidgets('Add to clips prompts with the default title and adds it', (
        tester,
      ) async {
        stubContentActions();
        await tester.pumpWidget(buildSubject(video: _classicVine));

        await tester.tap(find.text(l10n.shareSheetAddToClips));
        await tester.pumpAndSettle();

        expect(find.byType(ClipTitleSheet), findsOneWidget);
        expect(find.text(_defaultClipTitle), findsOneWidget);

        await tester.tap(find.text(l10n.shareSheetSaveClip));
        await tester.pumpAndSettle();

        verify(
          () => contentActions.add(
            const VideoContentAddToClipsRequested(
              libraryTitle: _defaultClipTitle,
            ),
          ),
        ).called(1);
      });

      testWidgets('a signed-out Save reports the failure without throwing', (
        tester,
      ) async {
        // A real bloc without a bookmarks repository, as for a signed-out
        // viewer. The sheet owns it, so unmounting closes it.
        await tester.pumpWidget(
          buildSubject(
            video: _classicVine,
            createBloc: () => VideoContentActionsBloc(
              video: _classicVine,
              relayUrl: 'wss://relay.example.com',
            ),
          ),
        );

        await tester.tap(find.text(l10n.shareSheetSave));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.text(l10n.shareFailedToAddBookmark), findsOneWidget);
      });
    });
  });
}
