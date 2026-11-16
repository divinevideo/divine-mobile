// ABOUTME: Tests for opening a remix clip in the editor from a video sheet.
// ABOUTME: Covers keeping an autosaved session as a draft and the editor push.

import 'dart:async';
import 'dart:io';

import 'package:challenge_protocol/challenge_protocol.dart';
import 'package:db_client/db_client.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/constants/video_editor_constants.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/challenge_recording_context.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/models/divine_video_draft.dart';
import 'package:openvine/models/video_editor/video_editor_provider_state.dart';
import 'package:openvine/models/video_publish/video_publish_provider_state.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/clip_manager_provider.dart';
import 'package:openvine/providers/database_provider.dart';
import 'package:openvine/providers/editor_background_work.dart';
import 'package:openvine/providers/shared_preferences_provider.dart';
import 'package:openvine/providers/video_editor_provider.dart';
import 'package:openvine/providers/video_publish_provider.dart';
import 'package:openvine/screens/video_editor/video_editor_screen.dart';
import 'package:openvine/services/draft_storage_service.dart';
import 'package:openvine/widgets/video_feed_item/actions/remix_launcher.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:pro_video_editor/pro_video_editor.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../packages/challenges_repository/test/synthetic.dart';
import '../../../mocks/mock_path_provider_platform.dart';

class _MockDraftStorageService extends Mock implements DraftStorageService {}

/// Clears the clip manager the way the real teardown does, and records when.
class _FakeVideoPublishNotifier extends VideoPublishNotifier {
  _FakeVideoPublishNotifier(this.calls);

  final List<String> calls;
  final keepAutosavedDraftValues = <bool>[];

  @override
  VideoPublishProviderState build() => const VideoPublishProviderState();

  @override
  Future<void> clearAll({bool keepAutosavedDraft = false}) async {
    calls.add('clearAll');
    keepAutosavedDraftValues.add(keepAutosavedDraft);
    await ref.read(clipManagerProvider.notifier).clearSessionClips();
  }
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

/// The real draft store, reporting when the autosave row has been deleted.
class _ObservedDraftStorageService extends DraftStorageService {
  _ObservedDraftStorageService({
    required super.draftsDao,
    required super.clipsDao,
  });

  final autosaveDeleted = Completer<void>();

  /// Completes when a draft other than the autosave has been deleted.
  final keptDeleted = Completer<void>();

  /// Runs after a draft other than the autosave is written.
  void Function()? afterKeptSave;

  @override
  Future<void> saveDraft(
    DivineVideoDraft draft, {
    void Function(List<String?> orphanPaths)? deferOrphanCleanup,
    DraftOwnedFilesMemo? ownedFilesMemo,
  }) async {
    await super.saveDraft(
      draft,
      deferOrphanCleanup: deferOrphanCleanup,
      ownedFilesMemo: ownedFilesMemo,
    );
    if (draft.id != VideoEditorConstants.autoSaveId) afterKeptSave?.call();
  }

  @override
  Future<void> deleteDraft(String id) async {
    await super.deleteDraft(id);
    if (id == VideoEditorConstants.autoSaveId && !autosaveDeleted.isCompleted) {
      autosaveDeleted.complete();
    }
    if (id != VideoEditorConstants.autoSaveId && !keptDeleted.isCompleted) {
      keptDeleted.complete();
    }
  }
}

DivineVideoClip _clip(String id) => DivineVideoClip(
  id: id,
  video: EditorVideo.file('/tmp/$id.mp4'),
  duration: const Duration(seconds: 6),
  recordedAt: DateTime.utc(2026),
  targetAspectRatio: .square,
  originalAspectRatio: 1,
);

DivineVideoDraft _autosave({required List<DivineVideoClip> clips}) =>
    DivineVideoDraft.create(
      clips: clips,
      title: 'Half-finished idea',
      description: '',
      hashtags: const {},
      selectedApproach: 'native',
    ).copyWith(id: VideoEditorConstants.autoSaveId);

void main() {
  group('openRemixInEditor', () {
    const openSheetLabel = 'open sheet';
    const remixLabel = 'remix';
    const editorLabel = 'editor';
    final l10n = lookupAppLocalizations(const Locale('en'));
    final remixClip = _clip('classic_vine_remix');
    final sessionClip = _clip('earlier_session_clip');

    late _MockDraftStorageService draftStorage;
    late List<String> calls;
    late _FakeVideoPublishNotifier publish;
    late ProviderContainer container;
    late List<Uri> editorLocations;
    late List<Object> launchErrors;
    late BuildContext homeContext;

    setUpAll(() {
      registerFallbackValue(_autosave(clips: const []));
    });

    setUp(() {
      draftStorage = _MockDraftStorageService();
      calls = <String>[];
      editorLocations = <Uri>[];
      launchErrors = <Object>[];
      publish = _FakeVideoPublishNotifier(calls);
      when(() => draftStorage.draftExists(VideoEditorConstants.autoSaveId))
          .thenAnswer((_) async => false);
      when(() => draftStorage.saveDraft(any())).thenAnswer((_) async {
        calls.add('saveDraft');
      });
    });

    void stubAutosave(DivineVideoDraft draft) {
      when(() => draftStorage.draftExists(VideoEditorConstants.autoSaveId))
          .thenAnswer((_) async => true);
      when(() => draftStorage.getDraftById(VideoEditorConstants.autoSaveId))
          .thenAnswer((_) async => draft);
    }

    Widget buildSubject() {
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (context, _) {
              homeContext = context;
              return Scaffold(
                body: TextButton(
                  onPressed: () => showModalBottomSheet<void>(
                    context: context,
                    builder: (_) => Consumer(
                      builder: (sheetContext, ref, _) => TextButton(
                        onPressed: () =>
                            openRemixInEditor(
                              sheetContext,
                              ref,
                              remixClip,
                            ).then<void>(
                              (_) {},
                              onError: (Object error) =>
                                  launchErrors.add(error),
                            ),
                        child: const Text(remixLabel),
                      ),
                    ),
                  ),
                  child: const Text(openSheetLabel),
                ),
              );
            },
          ),
          GoRoute(
            path: VideoEditorScreen.path,
            builder: (_, state) {
              editorLocations.add(state.uri);
              return const Scaffold(body: Text(editorLabel));
            },
          ),
        ],
      );

      return ProviderScope(
        overrides: [
          draftStorageServiceProvider.overrideWithValue(draftStorage),
          videoPublishProvider.overrideWith(() => publish),
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
      );
    }

    Future<void> remixFromSheet(WidgetTester tester) async {
      await tester.tap(find.text(openSheetLabel));
      await tester.pumpAndSettle();
      await tester.tap(find.text(remixLabel));
      await tester.pumpAndSettle();
    }

    testWidgets(
      'saves an autosaved session as a new draft before clearing it',
      (tester) async {
        stubAutosave(_autosave(clips: [sessionClip]));

        await tester.pumpWidget(buildSubject());
        container.read(clipManagerProvider.notifier).insertClip(0, sessionClip);
        expect(container.read(clipManagerProvider).clips, [sessionClip]);

        await remixFromSheet(tester);

        expect(calls, ['saveDraft', 'clearAll']);
        final saved =
            verify(() => draftStorage.saveDraft(captureAny())).captured.single
                as DivineVideoDraft;
        expect(saved.id, isNot(VideoEditorConstants.autoSaveId));
        expect(saved.clips.map((clip) => clip.id), [sessionClip.id]);
        expect(saved.title, 'Half-finished idea');
        expect(publish.keepAutosavedDraftValues, [isFalse]);
        expect(container.read(clipManagerProvider).clips, [remixClip]);
      },
    );

    testWidgets('keeps the challenge and post time of the saved session', (
      tester,
    ) async {
      final signer = SyntheticSigner();
      final challenge = ChallengeRecordingContext(
        owner: signer.pubkey,
        generation: 'generation',
        definition: NostrEvent.fromJson(signer.definition()),
        recordingId: 'recording',
        clientTags: const [],
      );
      final postTime = DateTime.utc(2026, 12, 24, 9, 30);
      stubAutosave(
        _autosave(clips: [sessionClip])
            .copyWith(challengeContext: challenge, scheduledAt: postTime),
      );

      await tester.pumpWidget(buildSubject());

      await remixFromSheet(tester);

      final saved =
          verify(() => draftStorage.saveDraft(captureAny())).captured.single
              as DivineVideoDraft;
      expect(saved.id, isNot(VideoEditorConstants.autoSaveId));
      expect(saved.challengeContext, same(challenge));
      expect(saved.scheduledAt, postTime);
      expect(saved.publishStatus, PublishStatus.draft);
    });

    testWidgets('closes the sheet and opens the editor from the library', (
      tester,
    ) async {
      await tester.pumpWidget(buildSubject());

      await remixFromSheet(tester);

      expect(find.text(remixLabel), findsNothing);
      expect(find.text(editorLabel), findsOneWidget);
      expect(
        editorLocations.single.queryParameters[VideoEditorScreen
            .originQueryParameter],
        VideoEditorScreen.libraryOrigin,
      );
    });

    testWidgets('writes no draft when there is no autosaved session', (
      tester,
    ) async {
      await tester.pumpWidget(buildSubject());

      await remixFromSheet(tester);

      verifyNever(() => draftStorage.saveDraft(any()));
      verifyNever(() => draftStorage.getDraftById(any()));
      expect(calls, ['clearAll']);
      expect(container.read(clipManagerProvider).clips, [remixClip]);
    });

    testWidgets('writes no draft when the autosave holds no clips', (
      tester,
    ) async {
      stubAutosave(_autosave(clips: const []));

      await tester.pumpWidget(buildSubject());

      await remixFromSheet(tester);

      verifyNever(() => draftStorage.saveDraft(any()));
      expect(calls, ['clearAll']);
      expect(container.read(clipManagerProvider).clips, [remixClip]);
      expect(find.text(editorLabel), findsOneWidget);
    });

    testWidgets(
      'keeps the session and opens nothing when the draft cannot be saved',
      (tester) async {
        stubAutosave(_autosave(clips: [sessionClip]));
        when(() => draftStorage.saveDraft(any()))
            .thenThrow(Exception('disk full'));

        await tester.pumpWidget(buildSubject());
        container.read(clipManagerProvider.notifier).insertClip(0, sessionClip);

        await remixFromSheet(tester);

        expect(calls, isEmpty);
        expect(container.read(clipManagerProvider).clips, [sessionClip]);
        expect(find.text(editorLabel), findsNothing);
        expect(find.text(remixLabel), findsNothing);
        expect(find.text(l10n.shareActionFailed), findsOneWidget);
        expect(launchErrors, isEmpty);
      },
    );

    testWidgets(
      'shows the failure, then rethrows an Error from keeping the session',
      (tester) async {
        stubAutosave(_autosave(clips: [sessionClip]));
        when(() => draftStorage.saveDraft(any()))
            .thenThrow(StateError('draft without an id'));

        await tester.pumpWidget(buildSubject());
        container.read(clipManagerProvider.notifier).insertClip(0, sessionClip);

        await remixFromSheet(tester);

        expect(launchErrors, [isA<StateError>()]);
        expect(find.text(l10n.shareActionFailed), findsOneWidget);
        expect(calls, isEmpty);
        expect(container.read(clipManagerProvider).clips, [sessionClip]);
        expect(find.text(editorLabel), findsNothing);
      },
    );

    testWidgets(
      'removes the kept copy when a route covers the sheet during the save',
      (tester) async {
        stubAutosave(_autosave(clips: [sessionClip]));
        const coverLabel = 'covering route';
        when(() => draftStorage.saveDraft(any())).thenAnswer((_) async {
          calls.add('saveDraft');
          Navigator.of(homeContext).push(
            MaterialPageRoute<void>(
              builder: (_) => const Scaffold(body: Text(coverLabel)),
            ),
          );
        });
        when(() => draftStorage.deleteDraft(any())).thenAnswer((_) async {
          calls.add('deleteDraft');
        });

        await tester.pumpWidget(buildSubject());
        container.read(clipManagerProvider.notifier).insertClip(0, sessionClip);

        await remixFromSheet(tester);

        final copyId =
            (verify(() => draftStorage.saveDraft(captureAny())).captured.single
                    as DivineVideoDraft)
                .id;
        expect(copyId, isNot(VideoEditorConstants.autoSaveId));
        verify(() => draftStorage.deleteDraft(copyId)).called(1);
        verifyNever(
          () => draftStorage.deleteDraft(VideoEditorConstants.autoSaveId),
        );
        expect(calls, ['saveDraft', 'deleteDraft']);
        expect(container.read(clipManagerProvider).clips, [sessionClip]);
        expect(find.text(coverLabel), findsOneWidget);
        expect(find.text(editorLabel), findsNothing);
        expect(launchErrors, isEmpty);
      },
    );
  });

  // The group above mocks storage; this one runs the launcher against the
  // real draft store and the real editor reset, which deletes the autosave
  // and reaps files no draft names any more.
  group('openRemixInEditor with real draft storage', () {
    const openSheetLabel = 'open sheet';
    const remixLabel = 'remix';

    late Directory documents;
    late PathProviderPlatform originalPathProvider;
    late AppDatabase database;
    late _ObservedDraftStorageService draftStorage;
    late SharedPreferences preferences;
    late ProviderContainer container;
    late BuildContext homeContext;

    setUp(() async {
      documents = Directory.systemTemp.createTempSync('remix_launcher_docs');
      originalPathProvider = PathProviderPlatform.instance;
      PathProviderPlatform.instance = MockPathProviderPlatform()
        ..setApplicationDocumentsPath(documents.path);
      database = AppDatabase.test(NativeDatabase.memory());
      draftStorage = _ObservedDraftStorageService(
        draftsDao: database.draftsDao,
        clipsDao: database.clipsDao,
      );
      SharedPreferences.setMockInitialValues({});
      preferences = await SharedPreferences.getInstance();
    });

    tearDown(() async {
      PathProviderPlatform.instance = originalPathProvider;
      await database.close();
      if (documents.existsSync()) documents.deleteSync(recursive: true);
    });

    DivineVideoClip fileClip(String id) {
      final file = File(p.join(documents.path, '$id.mp4'))
        ..writeAsBytesSync(const [0, 1, 2, 3]);
      return DivineVideoClip(
        id: id,
        video: EditorVideo.file(file.path),
        duration: const Duration(seconds: 6),
        recordedAt: DateTime.utc(2026),
        targetAspectRatio: .square,
        originalAspectRatio: 1,
      );
    }

    Widget buildSubject(DivineVideoClip remixClip) {
      return ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(preferences),
          databaseProvider.overrideWithValue(database),
          draftStorageServiceProvider.overrideWithValue(draftStorage),
        ],
        child: Consumer(
          builder: (context, ref, _) {
            container = ProviderScope.containerOf(context);
            return MaterialApp.router(
              localizationsDelegates: appLocalizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              routerConfig: GoRouter(
                routes: [
                  GoRoute(
                    path: '/',
                    builder: (context, _) {
                      homeContext = context;
                      return Scaffold(
                        body: TextButton(
                          onPressed: () => showModalBottomSheet<void>(
                            context: context,
                            builder: (_) => Consumer(
                              builder: (sheetContext, ref, _) => TextButton(
                                onPressed: () => openRemixInEditor(
                                  sheetContext,
                                  ref,
                                  remixClip,
                                ),
                                child: const Text(remixLabel),
                              ),
                            ),
                          ),
                          child: const Text(openSheetLabel),
                        ),
                      );
                    },
                  ),
                  GoRoute(
                    path: VideoEditorScreen.path,
                    builder: (_, _) => const Scaffold(body: Text('editor')),
                  ),
                ],
              ),
            );
          },
        ),
      );
    }

    testWidgets('lists the kept session as a draft and keeps its clip files', (
      tester,
    ) async {
      final sessionClip = fileClip('earlier_session_clip');
      final remixClip = fileClip('classic_vine_remix');
      // Real storage encodes off the main isolate, so every storage await runs
      // in real time; the sheet and the editor push still need frames.
      await tester.runAsync(
        () => draftStorage.saveDraft(_autosave(clips: [sessionClip])),
      );

      await tester.pumpWidget(buildSubject(remixClip));
      await tester.tap(find.text(openSheetLabel));
      await tester.pumpAndSettle();
      await tester.runAsync(() async {
        await tester.tap(find.text(remixLabel));
        await draftStorage.autosaveDeleted.future;
        await container.read(editorBackgroundWorkProvider).settle();
      });
      await tester.pumpAndSettle();
      expect(find.text(remixLabel), findsNothing);
      expect(container.read(clipManagerProvider).clips, [remixClip]);

      await tester.runAsync(() async {
        // The new session's debounced autosave, written now rather than after
        // the test has torn the database down.
        await container
            .read(videoEditorProvider.notifier)
            .flushPendingAutosave();
        await container.read(editorBackgroundWorkProvider).settle();

        final summaries = await draftStorage.getDraftSummaries();
        final kept = summaries
            .where((draft) => draft.id != VideoEditorConstants.autoSaveId)
            .toList();
        expect(kept, hasLength(1));
        expect(kept.single.title, 'Half-finished idea');
        expect(kept.single.publishStatus, PublishStatus.draft);
        expect(kept.single.clipCount, 1);
        final keptDraft = await draftStorage.getDraftById(kept.single.id);
        expect(keptDraft!.clips.map((clip) => clip.id), [sessionClip.id]);
      });
      expect(
        File(p.join(documents.path, '${sessionClip.id}.mp4')).existsSync(),
        isTrue,
      );
    });

    testWidgets(
      'leaves only the autosave and its files when the launch gives up',
      (tester) async {
        final sessionClip = fileClip('earlier_session_clip');
        final remixClip = fileClip('classic_vine_remix');
        await tester.runAsync(
          () => draftStorage.saveDraft(_autosave(clips: [sessionClip])),
        );
        draftStorage.afterKeptSave = () => Navigator.of(homeContext).push(
          MaterialPageRoute<void>(
            builder: (_) => const Scaffold(body: Text('covering route')),
          ),
        );

        await tester.pumpWidget(buildSubject(remixClip));
        await tester.tap(find.text(openSheetLabel));
        await tester.pumpAndSettle();
        await tester.runAsync(() async {
          await tester.tap(find.text(remixLabel));
          // Bounded so a launch that never removes the copy fails the test
          // rather than hanging the shard.
          await draftStorage.keptDeleted.future.timeout(
            const Duration(seconds: 10),
          );
        });
        await tester.pumpAndSettle();

        expect(find.text('covering route'), findsOneWidget);
        expect(find.text('editor'), findsNothing);
        await tester.runAsync(() async {
          final ids = (await draftStorage.getDraftSummaries())
              .map((draft) => draft.id)
              .toList();
          expect(ids, [VideoEditorConstants.autoSaveId]);
        });
        expect(
          File(p.join(documents.path, '${sessionClip.id}.mp4')).existsSync(),
          isTrue,
        );
      },
    );
  });
}
