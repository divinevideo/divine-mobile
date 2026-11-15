// ABOUTME: Tests for the action row in the video info sheet.
// ABOUTME: Covers which actions show for whom, their order, and their effects.

import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/owner_video_actions/owner_video_actions_cubit.dart';
import 'package:openvine/blocs/video_content_actions/video_content_actions_bloc.dart';
import 'package:openvine/features/feature_flags/models/feature_flag.dart';
import 'package:openvine/features/feature_flags/providers/feature_flag_providers.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/models/video_editor/video_editor_provider_state.dart';
import 'package:openvine/models/video_publish/video_publish_provider_state.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/clip_manager_provider.dart';
import 'package:openvine/providers/video_editor_provider.dart';
import 'package:openvine/providers/video_publish_provider.dart';
import 'package:openvine/screens/video_editor/video_editor_screen.dart';
import 'package:openvine/services/draft_storage_service.dart';
import 'package:openvine/services/video_clip_import_service.dart';
import 'package:openvine/widgets/report_content_dialog.dart';
import 'package:openvine/widgets/video_feed_item/actions/video_content_action_feedback.dart';
import 'package:openvine/widgets/video_feed_item/metadata/metadata_actions_section.dart';
import 'package:openvine/widgets/video_feed_item/metadata/metadata_remix_button.dart';
import 'package:pro_video_editor/pro_video_editor.dart';

import '../../../helpers/test_provider_overrides.dart';

class _MockVideoContentActionsBloc
    extends MockBloc<VideoContentActionsEvent, VideoContentActionsState>
    implements VideoContentActionsBloc {}

class _MockOwnerVideoActionsCubit extends MockCubit<OwnerVideoActionsState>
    implements OwnerVideoActionsCubit {}

class _MockVideoClipImportService extends Mock
    implements VideoClipImportService {}

/// Counts routes popped off the router's navigator.
class _PopCounter extends NavigatorObserver {
  int count = 0;

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) => count++;
}

class _MockDraftStorageService extends Mock implements DraftStorageService {}

/// Clears the clip manager the way the real teardown does.
class _FakeVideoPublishNotifier extends VideoPublishNotifier {
  @override
  VideoPublishProviderState build() => const VideoPublishProviderState();

  @override
  Future<void> clearAll({bool keepAutosavedDraft = false}) =>
      ref.read(clipManagerProvider.notifier).clearSessionClips();
}

/// Keeps the clip manager's autosave hooks from reaching real storage.
class _FakeVideoEditorNotifier extends VideoEditorNotifier {
  @override
  VideoEditorProviderState build() => VideoEditorProviderState();

  @override
  void invalidateFinalRenderedClip() {}

  @override
  void triggerAutosave() {}
}

const _videoId =
    '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef';
const _creatorPubkey =
    'abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789';

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
    bool isPreparingRemix = false,
  }) {
    when(() => contentActions.state).thenReturn(
      VideoContentActionsState(
        isSaving: isSaving,
        isPreparingRemix: isPreparingRemix,
      ),
    );
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
    bool isRemixOfViewersVideo = false,
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
              isRemixOfViewersVideo: isRemixOfViewersVideo,
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

      testWidgets('only Save on another creator classic Vine', (
        tester,
      ) async {
        stubContentActions();
        await tester.pumpWidget(
          buildSubject(video: _classicVine, debugTools: true),
        );

        expect(find.text(l10n.shareSheetSave), findsOneWidget);
        expect(find.text(l10n.shareSheetAddToClips), findsNothing);
        expect(find.text(l10n.shareSheetAddToList), findsNothing);
        expect(find.text(l10n.shareMenuEditVideo), findsNothing);
        expect(find.text(l10n.shareMenuDeleteVideo), findsNothing);
        expect(find.text(l10n.shareSheetEventJson), findsNothing);
        expect(find.text(l10n.shareSheetEventId), findsNothing);
      });

      testWidgets('Edit, Delete and Save in order on the viewer own video', (
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
        // The remix button stands in for Add to clips; the rest stay in the
        // share sheet.
        expect(find.text(l10n.shareSheetAddToClips), findsNothing);
        expect(find.text(l10n.shareSheetAddToList), findsNothing);
        expect(find.text(l10n.shareSheetEventJson), findsNothing);
        expect(find.text(l10n.shareSheetEventId), findsNothing);
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

      testWidgets('Save, then Report this remix, on a remix of the viewer', (
        tester,
      ) async {
        stubContentActions();
        await tester.pumpWidget(
          buildSubject(video: _classicVine, isRemixOfViewersVideo: true),
        );

        expect(
          tester.getTopLeft(find.text(l10n.shareSheetSave)).dx,
          lessThan(tester.getTopLeft(find.text(l10n.metadataReportRemix)).dx),
        );
      });

      testWidgets('no Report this remix on a video that is not one', (
        tester,
      ) async {
        stubContentActions();
        await tester.pumpWidget(buildSubject(video: _classicVine));

        expect(find.text(l10n.shareSheetSave), findsOneWidget);
        expect(find.text(l10n.metadataReportRemix), findsNothing);
      });

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

      testWidgets('holds Save while the video is being deleted', (
        tester,
      ) async {
        stubContentActions();
        final ownerCubit = stubbedOwnerCubit() as _MockOwnerVideoActionsCubit;
        when(() => ownerCubit.isDeleteInProgress(any())).thenReturn(true);
        await tester.pumpWidget(
          buildSubject(video: _video(), ownerCubit: ownerCubit),
        );

        await tester.tap(find.text(l10n.shareSheetSave));
        // The delete spinner never settles.
        await tester.pump(const Duration(seconds: 1));

        verifyNever(() => contentActions.add(any()));
      });

      testWidgets('holds Delete while a save is in flight', (tester) async {
        stubContentActions(isSaving: true);
        await tester.pumpWidget(
          buildSubject(video: _video(), ownerCubit: stubbedOwnerCubit()),
        );

        await tester.tap(find.text(l10n.shareMenuDeleteVideo));
        // The save spinner never settles; give a dialog time to open.
        await tester.pump(const Duration(seconds: 1));

        expect(find.text(l10n.shareMenuDelete), findsNothing);
      });

      testWidgets('holds Edit, Delete and Save while a remix is prepared', (
        tester,
      ) async {
        stubContentActions(isPreparingRemix: true);
        await tester.pumpWidget(
          buildSubject(video: _video(), ownerCubit: stubbedOwnerCubit()),
        );

        await tester.tap(find.text(l10n.shareSheetSave));
        await tester.tap(find.text(l10n.shareMenuDeleteVideo));
        await tester.tap(find.text(l10n.shareMenuEditVideo));
        await tester.pump(const Duration(seconds: 1));

        verifyNever(() => contentActions.add(any()));
        expect(find.text(l10n.shareMenuDelete), findsNothing);
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
        'leaves a route opened over the sheet while the delete ran',
        (tester) async {
          const coverText = 'covering route';
          stubContentActions();
          final ownerCubit = stubbedOwnerCubit() as _MockOwnerVideoActionsCubit;
          final deleteStarted = Completer<OwnerVideoDeleteStart>();
          when(
            () => ownerCubit.deleteVideo(any()),
          ).thenAnswer((_) => deleteStarted.future);
          when(() => ownerCubit.cleanupCompletionFor(any())).thenReturn(null);

          await openSheet(tester, video: _video(), ownerCubit: ownerCubit);
          await tester.tap(find.text(l10n.shareMenuDeleteVideo));
          await tester.pumpAndSettle();
          await tester.tap(find.text(l10n.shareMenuDelete));
          await tester.pumpAndSettle();
          Navigator.of(tester.element(sheetList)).push(
            MaterialPageRoute<void>(
              builder: (_) => const Scaffold(body: Text(coverText)),
            ),
          );
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

          expect(find.text(coverText), findsOneWidget);
        },
      );

      testWidgets(
        'logs an unexpected delete error instead of leaving it unhandled',
        (tester) async {
          stubContentActions();
          final ownerCubit = stubbedOwnerCubit() as _MockOwnerVideoActionsCubit;
          when(
            () => ownerCubit.deleteVideo(any()),
          ).thenThrow(Exception('unexpected'));

          await openSheet(tester, video: _video(), ownerCubit: ownerCubit);
          await tester.tap(find.text(l10n.shareMenuDeleteVideo));
          await tester.pumpAndSettle();
          await tester.tap(find.text(l10n.shareMenuDelete));
          await tester.pumpAndSettle();

          verify(() => ownerCubit.deleteVideo(any())).called(1);
          expect(tester.takeException(), isNull);
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

    group('report remix', () {
      testWidgets('closes the sheet, then opens the report flow', (
        tester,
      ) async {
        stubContentActions();
        final router = GoRouter(
          routes: [
            GoRoute(
              path: '/',
              builder: (context, _) => Scaffold(
                body: TextButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => Scaffold(
                        body: BlocProvider<VideoContentActionsBloc>.value(
                          value: contentActions,
                          child: MetadataActionsSection(
                            video: _classicVine,
                            isRemixOfViewersVideo: true,
                          ),
                        ),
                      ),
                    ),
                  ),
                  child: const Text('open sheet'),
                ),
              ),
            ),
          ],
        );
        addTearDown(router.dispose);
        await tester.pumpWidget(
          testProviderScope(
            child: MaterialApp.router(
              localizationsDelegates: appLocalizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              routerConfig: router,
            ),
          ),
        );
        await tester.tap(find.text('open sheet'));
        await tester.pumpAndSettle();

        await tester.tap(find.text(l10n.metadataReportRemix));
        await tester.pumpAndSettle();

        expect(find.byType(MetadataActionsSection), findsNothing);
        expect(find.byType(ReportContentDialog), findsOneWidget);
      });

      testWidgets('is held while another action runs', (tester) async {
        stubContentActions(isPreparingRemix: true);
        await tester.pumpWidget(
          buildSubject(video: _classicVine, isRemixOfViewersVideo: true),
        );

        await tester.tap(find.text(l10n.metadataReportRemix));
        await tester.pump(const Duration(seconds: 1));

        expect(find.byType(ReportContentDialog), findsNothing);
      });
    });

    group('remix', () {
      const openSheetLabel = 'open sheet';
      const coverText = 'covering route';
      const editorLabel = 'editor';
      final remixClip = DivineVideoClip(
        id: 'classic_vine_remix',
        video: EditorVideo.file('/tmp/classic_vine_remix.mp4'),
        duration: const Duration(seconds: 6),
        recordedAt: DateTime.utc(2026),
        targetAspectRatio: .square,
        originalAspectRatio: 1,
      );
      final sheetList = find.byWidgetPredicate(
        (widget) =>
            widget is ListView && widget.scrollDirection == Axis.vertical,
      );

      late StreamController<VideoContentActionsState> results;
      late ProviderContainer container;
      late _MockDraftStorageService draftStorage;
      late _PopCounter pops;
      late int editorBuilds;

      setUp(() {
        // Broadcast, so closing it completes in tests that never listen.
        results = StreamController<VideoContentActionsState>.broadcast();
        whenListen(
          contentActions,
          results.stream,
          initialState: const VideoContentActionsState(),
        );
        when(() => contentActions.isClosed).thenReturn(false);
        draftStorage = _MockDraftStorageService();
        when(
          () => draftStorage.draftExists(any()),
        ).thenAnswer((_) async => false);
        pops = _PopCounter();
        editorBuilds = 0;
      });

      tearDown(() => results.close());

      // Pushes [sheetBody] on its own route, standing in for the sheet, under
      // a router that knows the editor. By default the body is the section in
      // a scrolling list, reading the mocked bloc.
      Future<void> openSheet(WidgetTester tester, {Widget? sheetBody}) async {
        final router = GoRouter(
          observers: [pops],
          routes: [
            GoRoute(
              path: '/',
              builder: (context, _) => Scaffold(
                body: TextButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => Scaffold(
                        body:
                            sheetBody ??
                            BlocProvider<VideoContentActionsBloc>.value(
                              value: contentActions,
                              child: ListView(
                                children: [
                                  MetadataActionsSection(video: _classicVine),
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
            GoRoute(
              path: VideoEditorScreen.path,
              builder: (_, _) {
                editorBuilds++;
                return const Scaffold(body: Text(editorLabel));
              },
            ),
          ],
        );
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              isFeatureEnabledProvider(
                FeatureFlag.debugTools,
              ).overrideWithValue(false),
              draftStorageServiceProvider.overrideWithValue(draftStorage),
              videoPublishProvider.overrideWith(_FakeVideoPublishNotifier.new),
              videoEditorProvider.overrideWith(_FakeVideoEditorNotifier.new),
            ],
            child: Consumer(
              builder: (context, ref, _) {
                container = ProviderScope.containerOf(context);
                return MaterialApp.router(
                  localizationsDelegates: appLocalizationsDelegates,
                  supportedLocales: AppLocalizations.supportedLocales,
                  routerConfig: router,
                );
              },
            ),
          ),
        );
        await tester.tap(find.text(openSheetLabel));
        await tester.pumpAndSettle();
      }

      testWidgets(
        'opens the editor with a remix that became ready after the row '
        'scrolled out of view',
        (tester) async {
          await openSheet(tester);
          await tester.drag(sheetList, const Offset(0, -3000));
          await tester.pumpAndSettle();

          results.add(
            VideoContentActionsState(
              actionResult: VideoContentRemixReady(clip: remixClip),
            ),
          );
          await tester.pumpAndSettle();

          expect(sheetList, findsNothing);
          expect(find.text(editorLabel), findsOneWidget);
          expect(container.read(clipManagerProvider).clips, [remixClip]);
        },
      );

      testWidgets('leaves a route opened over the sheet meanwhile', (
        tester,
      ) async {
        await openSheet(tester);
        Navigator.of(tester.element(sheetList)).push(
          MaterialPageRoute<void>(
            builder: (_) => const Scaffold(body: Text(coverText)),
          ),
        );
        await tester.pumpAndSettle();

        results.add(
          VideoContentActionsState(
            actionResult: VideoContentRemixReady(clip: remixClip),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text(coverText), findsOneWidget);
        expect(find.text(editorLabel), findsNothing);
        expect(container.read(clipManagerProvider).clips, isEmpty);
      });

      testWidgets(
        'leaves a route opened over the sheet while the autosave is checked',
        (tester) async {
          final sessionClip = DivineVideoClip(
            id: 'earlier_session_clip',
            video: EditorVideo.file('/tmp/earlier_session_clip.mp4'),
            duration: const Duration(seconds: 6),
            recordedAt: DateTime.utc(2026),
            targetAspectRatio: .square,
            originalAspectRatio: 1,
          );
          final autosaveCheck = Completer<bool>();
          when(
            () => draftStorage.draftExists(any()),
          ).thenAnswer((_) => autosaveCheck.future);
          await openSheet(tester);
          container
              .read(clipManagerProvider.notifier)
              .insertClip(0, sessionClip);

          results.add(
            VideoContentActionsState(
              actionResult: VideoContentRemixReady(clip: remixClip),
            ),
          );
          await tester.pump();
          verify(() => draftStorage.draftExists(any())).called(1);

          // The launcher is waiting on storage when the user opens a route.
          Navigator.of(tester.element(sheetList)).push(
            MaterialPageRoute<void>(
              builder: (_) => const Scaffold(body: Text(coverText)),
            ),
          );
          await tester.pumpAndSettle();
          autosaveCheck.complete(false);
          await tester.pumpAndSettle();

          expect(find.text(coverText), findsOneWidget);
          expect(pops.count, 0);
          expect(editorBuilds, 0);
          // Given up before the session was cleared.
          expect(container.read(clipManagerProvider).clips, [sessionClip]);
          verify(
            () => contentActions.add(const VideoContentRemixLaunchFinished()),
          ).called(1);
        },
      );

      testWidgets(
        'holds Remix and the row until the editor opens, then opens it once',
        (tester) async {
          final video = _video();
          final importer = _MockVideoClipImportService();
          when(
            () => importer.findImportedClipOf(any()),
          ).thenAnswer((_) async => remixClip);
          final ownerCubit = stubbedOwnerCubit();
          final autosaveCheck = Completer<bool>();
          when(
            () => draftStorage.draftExists(any()),
          ).thenAnswer((_) => autosaveCheck.future);
          final l10n = lookupAppLocalizations(const Locale('en'));

          await openSheet(
            tester,
            sheetBody: MultiBlocProvider(
              providers: [
                BlocProvider<VideoContentActionsBloc>(
                  create: (_) => VideoContentActionsBloc(
                    video: video,
                    relayUrl: 'wss://relay.example.com',
                    videoClipImportService: importer,
                    viewerPubkey: video.pubkey,
                  ),
                ),
                BlocProvider<OwnerVideoActionsCubit>.value(value: ownerCubit),
              ],
              child: ListView(
                children: [
                  MetadataRemixButton(video: video, isOwnVideo: true),
                  MetadataActionsSection(video: video, isOwnVideo: true),
                ],
              ),
            ),
          );
          final remixButton = find.widgetWithText(
            DivineButton,
            l10n.remixThisVideo,
          );

          await tester.tap(remixButton);
          await tester.pump();
          await tester.pump();
          verify(() => draftStorage.draftExists(any())).called(1);

          // The launcher is waiting on the autosave check; nothing more may
          // start meanwhile.
          await tester.tap(remixButton);
          await tester.tap(find.text(l10n.shareMenuDeleteVideo));
          await tester.pump(const Duration(seconds: 1));

          expect(find.text(l10n.shareMenuDelete), findsNothing);
          verify(() => importer.findImportedClipOf(video)).called(1);
          verifyNever(() => draftStorage.draftExists(any()));

          autosaveCheck.complete(false);
          await tester.pumpAndSettle();

          expect(editorBuilds, 1);
          expect(pops.count, 1);
          expect(find.text(editorLabel), findsOneWidget);
          expect(container.read(clipManagerProvider).clips, [remixClip]);
          verifyNever(() => ownerCubit.deleteVideo(any()));
        },
      );

      testWidgets('opens one editor when two ready remixes arrive at once', (
        tester,
      ) async {
        final autosaveCheck = Completer<bool>();
        when(
          () => draftStorage.draftExists(any()),
        ).thenAnswer((_) => autosaveCheck.future);
        await openSheet(tester);

        results
          ..add(
            VideoContentActionsState(
              actionResult: VideoContentRemixReady(clip: remixClip),
            ),
          )
          ..add(
            VideoContentActionsState(
              actionResult: VideoContentRemixReady(clip: remixClip),
            ),
          );
        await tester.pump();
        autosaveCheck.complete(false);
        await tester.pumpAndSettle();

        verify(() => draftStorage.draftExists(any())).called(1);
        expect(editorBuilds, 1);
        expect(pops.count, 1);
      });

      testWidgets('ends the launch when a covering route drops the remix', (
        tester,
      ) async {
        await openSheet(tester);
        Navigator.of(tester.element(sheetList)).push(
          MaterialPageRoute<void>(
            builder: (_) => const Scaffold(body: Text(coverText)),
          ),
        );
        await tester.pumpAndSettle();

        results.add(
          VideoContentActionsState(
            actionResult: VideoContentRemixReady(clip: remixClip),
          ),
        );
        await tester.pumpAndSettle();

        verify(
          () => contentActions.add(const VideoContentRemixLaunchFinished()),
        ).called(1);
      });

      testWidgets(
        'ends the launch when keeping the autosave throws an Error',
        (tester) async {
          when(
            () => draftStorage.draftExists(any()),
          ).thenThrow(StateError('broken autosave id'));
          await openSheet(tester);

          results.add(
            VideoContentActionsState(
              actionResult: VideoContentRemixReady(clip: remixClip),
            ),
          );
          await tester.pumpAndSettle();

          expect(tester.takeException(), isNull);
          expect(editorBuilds, 0);
          verify(
            () => contentActions.add(const VideoContentRemixLaunchFinished()),
          ).called(1);
        },
      );

      testWidgets('ends the launch once the editor has opened', (
        tester,
      ) async {
        await openSheet(tester);

        results.add(
          VideoContentActionsState(
            actionResult: VideoContentRemixReady(clip: remixClip),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text(editorLabel), findsOneWidget);
        verify(
          () => contentActions.add(const VideoContentRemixLaunchFinished()),
        ).called(1);
      });
    });
  });
}
