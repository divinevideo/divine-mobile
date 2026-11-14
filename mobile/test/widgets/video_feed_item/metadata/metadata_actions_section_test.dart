// ABOUTME: Tests for the action row in the video info sheet.
// ABOUTME: Covers which actions show for whom, their order, and their effects.

import 'dart:async';

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

  setUpAll(() {
    registerFallbackValue(const VideoContentSaveRequested());
    registerFallbackValue(_classicVine);
  });

  setUp(() {
    contentActions = _MockVideoContentActionsBloc();
  });

  void stubContentActions({
    bool isSaving = false,
    bool isImportingClip = false,
  }) {
    when(() => contentActions.state).thenReturn(
      VideoContentActionsState(
        isSaving: isSaving,
        isImportingClip: isImportingClip,
      ),
    );
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
            child: MetadataActionsSection(
              video: video,
              isOwnVideo: ownerCubit != null,
            ),
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

      testWidgets('every action in order on the viewer own video', (
        tester,
      ) async {
        stubContentActions();
        final video = _video(
          tags: const [
            ['allow_video_reuse', 'true'],
          ],
        );
        expect(video.allowVideoReuse, isTrue);

        await tester.pumpWidget(
          buildSubject(
            video: video,
            ownerCubit: stubbedOwnerCubit(),
            debugTools: true,
          ),
        );

        final labels = [
          l10n.shareMenuEditVideo,
          l10n.shareMenuDeleteVideo,
          l10n.shareSheetSave,
          l10n.shareSheetAddToClips,
          l10n.shareSheetAddToList,
          l10n.shareSheetEventJson,
          l10n.shareSheetEventId,
        ];
        final xs = [
          for (final label in labels) tester.getTopLeft(find.text(label)).dx,
        ];

        for (var i = 1; i < xs.length; i++) {
          expect(
            xs[i - 1],
            lessThan(xs[i]),
            reason: '${labels[i - 1]} should come before ${labels[i]}',
          );
        }
      });

      testWidgets(
        'no Edit or Delete from an owner cubit provided for a video the viewer '
        'does not own',
        (tester) async {
          stubContentActions();
          await tester.pumpWidget(
            testMaterialApp(
              additionalOverrides: [
                isFeatureEnabledProvider(
                  FeatureFlag.debugTools,
                ).overrideWithValue(false),
              ],
              home: Scaffold(
                body: MultiBlocProvider(
                  providers: [
                    BlocProvider<VideoContentActionsBloc>.value(
                      value: contentActions,
                    ),
                    BlocProvider<OwnerVideoActionsCubit>.value(
                      value: stubbedOwnerCubit(),
                    ),
                  ],
                  child: MetadataActionsSection(video: _classicVine),
                ),
              ),
            ),
          );

          expect(find.text(l10n.shareSheetSave), findsOneWidget);
          expect(find.text(l10n.shareMenuEditVideo), findsNothing);
          expect(find.text(l10n.shareMenuDeleteVideo), findsNothing);
        },
      );

      testWidgets(
        'Add to clips on the viewer own video, even without a reuse tag',
        (tester) async {
          stubContentActions();
          final video = _video();
          expect(video.allowVideoReuse, isFalse);
          expect(video.isOriginalVine, isFalse);

          await tester.pumpWidget(
            buildSubject(video: video, ownerCubit: stubbedOwnerCubit()),
          );

          expect(find.text(l10n.shareSheetAddToClips), findsOneWidget);
        },
      );

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

      testWidgets('a spinner on Add to clips while the clip is importing', (
        tester,
      ) async {
        stubContentActions(isImportingClip: true);
        await tester.pumpWidget(buildSubject(video: _classicVine));

        final addToClipsItem = find
            .ancestor(
              of: find.text(l10n.shareSheetAddToClips),
              matching: find.byType(GestureDetector),
            )
            .first;
        expect(
          find.descendant(
            of: addToClipsItem,
            matching: find.byType(DivineCircularProgressIndicator),
          ),
          findsOneWidget,
        );
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

      testWidgets(
        'tapping Add to clips while it is importing prompts nothing',
        (
          tester,
        ) async {
          stubContentActions(isImportingClip: true);
          await tester.pumpWidget(buildSubject(video: _classicVine));

          await tester.tap(find.text(l10n.shareSheetAddToClips));
          await tester.pump();

          expect(find.byType(ClipTitleSheet), findsNothing);
        },
      );

      testWidgets(
        'holds Save and Add to clips while the video is being deleted',
        (tester) async {
          stubContentActions();
          final ownerCubit = stubbedOwnerCubit() as _MockOwnerVideoActionsCubit;
          when(() => ownerCubit.isDeleteInProgress(any())).thenReturn(true);
          await tester.pumpWidget(
            buildSubject(video: _video(), ownerCubit: ownerCubit),
          );

          await tester.tap(find.text(l10n.shareSheetSave));
          await tester.tap(find.text(l10n.shareSheetAddToClips));
          // The delete spinner never settles; give a sheet time to open.
          await tester.pump(const Duration(seconds: 1));

          verifyNever(() => contentActions.add(any()));
          expect(find.byType(ClipTitleSheet), findsNothing);
        },
      );

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
    group('owner delete', () {
      const openSheetLabel = 'open sheet';
      final sheetList = find.byWidgetPredicate(
        (widget) =>
            widget is ListView && widget.scrollDirection == Axis.vertical,
      );

      // Pushes the section on its own route, standing in for the sheet, so the
      // delete has a route to close and an opener to report on.
      Future<void> openSheet(
        WidgetTester tester, {
        required VideoEvent video,
        required OwnerVideoActionsCubit ownerCubit,
      }) async {
        await tester.pumpWidget(
          testMaterialApp(
            additionalOverrides: [
              isFeatureEnabledProvider(
                FeatureFlag.debugTools,
              ).overrideWithValue(false),
            ],
            home: Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => Scaffold(
                        body: MultiBlocProvider(
                          providers: [
                            BlocProvider<VideoContentActionsBloc>.value(
                              value: contentActions,
                            ),
                            BlocProvider<OwnerVideoActionsCubit>.value(
                              value: ownerCubit,
                            ),
                          ],
                          child: ListView(
                            children: [
                              MetadataActionsSection(
                                video: video,
                                isOwnVideo: true,
                              ),
                              const SizedBox(height: 4000),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  child: const Text(openSheetLabel),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text(openSheetLabel));
        await tester.pumpAndSettle();
      }

      testWidgets(
        'confirms and closes the sheet after the row scrolls out of view',
        (tester) async {
          stubContentActions();
          final ownerCubit = stubbedOwnerCubit() as _MockOwnerVideoActionsCubit;
          final deleteStarted = Completer<OwnerVideoDeleteStart>();
          when(
            () => ownerCubit.deleteVideo(any()),
          ).thenAnswer((_) => deleteStarted.future);
          when(() => ownerCubit.cleanupCompletionFor(any())).thenReturn(null);
          final video = _video();

          await openSheet(tester, video: video, ownerCubit: ownerCubit);

          await tester.tap(find.text(l10n.shareMenuDeleteVideo));
          await tester.pumpAndSettle();
          await tester.tap(find.text(l10n.shareMenuDelete));
          await tester.pumpAndSettle();
          verify(() => ownerCubit.deleteVideo(video)).called(1);

          // Scroll well past the list's cache extent while the delete runs.
          await tester.drag(sheetList, const Offset(0, -3000));
          await tester.pumpAndSettle();

          when(() => ownerCubit.state).thenReturn(
            const OwnerVideoActionsState(
              operations: {
                _videoId: OwnerVideoOperationState(
                  deleteStatus: OwnerVideoDeleteStatus.success,
                  cleanupStatus: OwnerVideoCleanupStatus.confirmed,
                ),
              },
            ),
          );
          deleteStarted.complete(OwnerVideoDeleteStart.started);
          await tester.pumpAndSettle();

          expect(sheetList, findsNothing);
          expect(find.text(openSheetLabel), findsOneWidget);
          expect(
            find.text(l10n.shareMenuDeleteCleanupConfirmed),
            findsOneWidget,
          );
        },
      );

      testWidgets(
        'closes the sheet before reporting a failed delete on its opener',
        (tester) async {
          stubContentActions();
          final ownerCubit = stubbedOwnerCubit() as _MockOwnerVideoActionsCubit;
          when(() => ownerCubit.deleteVideo(any())).thenAnswer((_) async {
            when(() => ownerCubit.state).thenReturn(
              const OwnerVideoActionsState(
                operations: {
                  _videoId: OwnerVideoOperationState(
                    deleteStatus: OwnerVideoDeleteStatus.failure,
                  ),
                },
              ),
            );
            return OwnerVideoDeleteStart.started;
          });
          final video = _video();

          await openSheet(tester, video: video, ownerCubit: ownerCubit);
          await tester.tap(find.text(l10n.shareMenuDeleteVideo));
          await tester.pumpAndSettle();
          await tester.tap(find.text(l10n.shareMenuDelete));
          await tester.pumpAndSettle();

          expect(sheetList, findsNothing);
          expect(find.text(openSheetLabel), findsOneWidget);
          expect(find.text(l10n.shareMenuDeleteFailedGeneric), findsOneWidget);
        },
      );
    });
  });
}
