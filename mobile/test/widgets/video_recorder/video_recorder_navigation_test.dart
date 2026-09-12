// ABOUTME: Tests for the recorder-exit auth gate in video_recorder_navigation.
// ABOUTME: Covers the authenticated (proceed) and restore-then-terminal
// ABOUTME: (draft + route to Welcome) paths for both recorder-exit entries.

import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/blocs/video_recorder/video_recorder_bloc.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/clip_manager_state.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/models/divine_video_draft.dart';
import 'package:openvine/models/video_editor/video_editor_provider_state.dart';
import 'package:openvine/models/video_publish/video_publish_provider_state.dart';
import 'package:openvine/models/video_recorder/video_recorder_mode.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/clip_manager_provider.dart';
import 'package:openvine/providers/video_editor_provider.dart';
import 'package:openvine/providers/video_publish_provider.dart';
import 'package:openvine/screens/auth/welcome_screen.dart';
import 'package:openvine/screens/feed/video_feed_page.dart';
import 'package:openvine/screens/library_screen.dart';
import 'package:openvine/screens/video_editor/video_editor_screen.dart';
import 'package:openvine/screens/video_metadata/video_metadata_screen.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/draft_storage_service.dart';
import 'package:openvine/widgets/video_recorder/clip_delete_snackbar.dart';
import 'package:openvine/widgets/video_recorder/video_recorder_navigation.dart';
import 'package:pro_video_editor/pro_video_editor.dart';
import 'package:sound_service/sound_service.dart';

class _MockAuthService extends Mock implements AuthService {}

class _MockVideoRecorderBloc
    extends MockBloc<VideoRecorderEvent, VideoRecorderBlocState>
    implements VideoRecorderBloc {}

class _MockAudioSessionService extends Mock implements AudioSessionService {}

class _MockDraftStorageService extends Mock implements DraftStorageService {}

class _FakeVideoPublishNotifier extends VideoPublishNotifier {
  final keepAutosavedDraftValues = <bool>[];

  @override
  VideoPublishProviderState build() => const VideoPublishProviderState();

  @override
  Future<void> clearAll({bool keepAutosavedDraft = false}) async {
    keepAutosavedDraftValues.add(keepAutosavedDraft);
  }
}

class _FakeVideoEditorNotifier extends VideoEditorNotifier {
  bool saveAsDraftCalled = false;
  bool startRenderVideoCalled = false;
  DraftSaveOutcome saveResult = DraftSaveOutcome.saved;
  int restoreDraftCalls = 0;
  int removeAutosavedDraftCalls = 0;

  /// Clips the autosave hands back, mirroring the real restore writing them
  /// into the clip manager.
  List<DivineVideoClip> clipsToRestore = const [];

  @override
  VideoEditorProviderState build() => VideoEditorProviderState();

  @override
  Future<bool> restoreDraft([String? draftId]) async {
    restoreDraftCalls++;
    if (clipsToRestore.isEmpty) return false;
    (ref.read(clipManagerProvider.notifier) as _FakeClipManagerNotifier)
        .setClips(clipsToRestore);
    return true;
  }

  @override
  Future<void> removeAutosavedDraft() async {
    removeAutosavedDraftCalls++;
  }

  @override
  Future<DraftSaveOutcome> saveAsDraft({
    bool enforceCreateNewDraft = false,
  }) async {
    saveAsDraftCalled = true;
    return saveResult;
  }

  @override
  Future<void> startRenderVideo() async {
    startRenderVideoCalled = true;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _MockAuthService mockAuthService;
  late _MockVideoRecorderBloc recorderBloc;
  late _MockAudioSessionService audioSessionService;
  late _FakeVideoEditorNotifier fakeEditor;
  late _FakeVideoPublishNotifier fakePublish;
  late _FakeClipManagerNotifier fakeClipManager;
  late _MockDraftStorageService mockDraftStorageService;

  setUpAll(() {
    registerFallbackValue(const VideoRecorderCameraPausedForNavigation());
  });

  setUp(() {
    mockAuthService = _MockAuthService();
    recorderBloc = _MockVideoRecorderBloc();
    audioSessionService = _MockAudioSessionService();
    fakeEditor = _FakeVideoEditorNotifier();
    fakePublish = _FakeVideoPublishNotifier();
    fakeClipManager = _FakeClipManagerNotifier();
    mockDraftStorageService = _MockDraftStorageService();
    when(
      () => mockDraftStorageService.getAutosaveDraft(),
    ).thenAnswer((_) async => null);

    when(() => recorderBloc.state).thenReturn(const VideoRecorderBlocState());
    when(() => recorderBloc.isClosed).thenReturn(false);
    when(() => recorderBloc.add(any())).thenAnswer((invocation) {
      final event = invocation.positionalArguments.single as VideoRecorderEvent;
      if (event is VideoRecorderCameraPausedForNavigation) {
        event.completion?.complete();
      }
    });
    when(
      () => audioSessionService.configureForMixedPlayback(),
    ).thenAnswer((_) async {});
    when(
      () => audioSessionService.resetAudioSession(),
    ).thenAnswer((_) async {});
    when(
      () => mockAuthService.authStateStream,
    ).thenAnswer((_) => const Stream<AuthState>.empty());
  });

  Widget buildHarness() {
    final router = GoRouter(
      initialLocation: '/recorder',
      routes: [
        GoRoute(
          path: '/recorder',
          builder: (context, state) => BlocProvider<VideoRecorderBloc>.value(
            value: recorderBloc,
            child: const _RecorderHarness(),
          ),
        ),
        GoRoute(
          path: VideoEditorScreen.path,
          builder: (_, _) => const _StubScreen(label: 'editor'),
        ),
        GoRoute(
          path: VideoMetadataScreen.path,
          builder: (_, _) => const _StubScreen(label: 'metadata'),
        ),
        GoRoute(
          path: '/library-clips',
          name: LibraryScreen.clipsOnlyRouteName,
          builder: (_, _) => const _StubScreen(label: 'library'),
        ),
        GoRoute(
          path: WelcomeScreen.path,
          builder: (_, _) => const _StubScreen(label: 'welcome'),
        ),
        GoRoute(
          path: VideoFeedPage.pathForIndex(0),
          builder: (_, _) => const _StubScreen(label: 'feed'),
        ),
      ],
    );

    return ProviderScope(
      overrides: [
        authServiceProvider.overrideWithValue(mockAuthService),
        videoEditorProvider.overrideWith(() => fakeEditor),
        videoPublishProvider.overrideWith(() => fakePublish),
        clipManagerProvider.overrideWith(() => fakeClipManager),
        audioSessionServiceProvider.overrideWithValue(audioSessionService),
        draftStorageServiceProvider.overrideWithValue(mockDraftStorageService),
      ],
      child: MaterialApp.router(
        localizationsDelegates: appLocalizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        routerConfig: router,
      ),
    );
  }

  group('closeVideoRecorder', () {
    testWidgets('discards the session when it has to leave via go', (
      tester,
    ) async {
      await tester.pumpWidget(buildHarness());
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('close-recorder')));
      await tester.pumpAndSettle();

      expect(find.text('feed'), findsOneWidget);
      // Nothing to pop means the recorder's PopScope never runs, so this exit
      // has to end the session itself — otherwise its clips (and with them the
      // aspect ratio they lock in) survive into the next camera open.
      expect(fakePublish.keepAutosavedDraftValues, [isFalse]);
    });
  });

  group('recorder-exit auth gate', () {
    group('when already authenticated', () {
      setUp(() {
        when(
          () => mockAuthService.authState,
        ).thenReturn(AuthState.authenticated);
      });

      testWidgets('openVideoEditorFromRecorder proceeds to the editor '
          'without saving a draft', (tester) async {
        await tester.pumpWidget(buildHarness());
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('open-editor')));
        await tester.pumpAndSettle();

        expect(find.text('editor'), findsOneWidget);
        expect(fakeEditor.saveAsDraftCalled, isFalse);
        verify(() => audioSessionService.configureForMixedPlayback()).called(1);
        verifyNever(() => audioSessionService.resetAudioSession());
        // The lock guards the camera against a volume / BLE trigger racing the
        // push — it is the feature's only production trigger, so assert it
        // fired (deleting it would silently disable the lock).
        verify(
          () => recorderBloc.add(
            const VideoRecorderRecordingLockedForNavigation(),
          ),
        ).called(1);
      });

      testWidgets('openRecorderLibrary proceeds to the library '
          'without saving a draft', (tester) async {
        await tester.pumpWidget(buildHarness());
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('open-library')));
        await tester.pumpAndSettle();

        expect(find.text('library'), findsOneWidget);
        expect(fakeEditor.saveAsDraftCalled, isFalse);
        verify(() => audioSessionService.resetAudioSession()).called(1);
        verifyNever(() => audioSessionService.configureForMixedPlayback());
        // The lock guards the camera against a volume / BLE trigger racing the
        // push — it is the feature's only production trigger, so assert it
        // fired (deleting it would silently disable the lock).
        verify(
          () => recorderBloc.add(
            const VideoRecorderRecordingLockedForNavigation(),
          ),
        ).called(1);
      });

      testWidgets('openVideoEditorFromRecorder mutes clips in lip-sync mode', (
        tester,
      ) async {
        when(() => recorderBloc.state).thenReturn(
          const VideoRecorderBlocState(recorderMode: VideoRecorderMode.lipSync),
        );

        await tester.pumpWidget(buildHarness());
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('open-editor')));
        await tester.pumpAndSettle();

        expect(fakeClipManager.muteAllClipsCalled, isTrue);
        expect(find.text('editor'), findsOneWidget);
        verify(() => audioSessionService.configureForMixedPlayback()).called(1);
      });

      testWidgets('openVideoEditorFromRecorder does not mute clips in '
          'capture mode', (tester) async {
        await tester.pumpWidget(buildHarness());
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('open-editor')));
        await tester.pumpAndSettle();

        expect(fakeClipManager.muteAllClipsCalled, isFalse);
        expect(find.text('editor'), findsOneWidget);
        verify(() => audioSessionService.configureForMixedPlayback()).called(1);
      });

      testWidgets('openVideoEditorFromRecorder finalizes a pending clip '
          'deletion and dismisses the Undo snackbar', (tester) async {
        fakeClipManager.initialPendingDeletion = ClipPendingDeletion(
          clip: DivineVideoClip(
            id: 'pending-clip',
            video: EditorVideo.file('/path/to/video.mp4'),
            duration: const Duration(seconds: 1),
            recordedAt: DateTime(2026),
            targetAspectRatio: .vertical,
            originalAspectRatio: 9 / 16,
          ),
          originalIndex: 0,
        );

        await tester.pumpWidget(buildHarness());
        await tester.pumpAndSettle();
        final l10n = lookupAppLocalizations(const Locale('en'));

        await tester.tap(find.byKey(const Key('show-delete-snackbar')));
        await tester.pump();
        expect(find.text(l10n.videoRecorderClipUndoLabel), findsOneWidget);

        await tester.tap(find.byKey(const Key('open-editor')));
        await tester.pumpAndSettle();

        // The editor seeds its session from the clip list at navigation time
        // (classic renders it), so a pending Undo must not survive the push.
        expect(find.text('editor'), findsOneWidget);
        expect(fakeClipManager.commitPendingDeletionCalls, equals(1));
        expect(find.text(l10n.videoRecorderClipUndoLabel), findsNothing);
      });

      testWidgets('openVideoEditorFromRecorder resets the session for a mode '
          'without a video editor (routes to metadata)', (tester) async {
        when(() => recorderBloc.state).thenReturn(
          const VideoRecorderBlocState(recorderMode: VideoRecorderMode.classic),
        );

        await tester.pumpWidget(buildHarness());
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('open-editor')));
        await tester.pumpAndSettle();

        expect(find.text('metadata'), findsOneWidget);
        verify(() => audioSessionService.resetAudioSession()).called(1);
        verifyNever(() => audioSessionService.configureForMixedPlayback());
      });
    });

    group('when restore resolves to terminal unauthenticated', () {
      setUp(() {
        when(() => mockAuthService.authState).thenReturn(AuthState.checking);
        when(
          () => mockAuthService.authStateStream,
        ).thenAnswer((_) => Stream<AuthState>.value(AuthState.unauthenticated));
      });

      testWidgets('openVideoEditorFromRecorder saves a draft, shows the '
          'snackbar, and routes to Welcome', (tester) async {
        await tester.pumpWidget(buildHarness());
        await tester.pumpAndSettle();
        final l10n = lookupAppLocalizations(const Locale('en'));

        await tester.tap(find.byKey(const Key('open-editor')));
        await tester.pumpAndSettle();

        expect(fakeEditor.saveAsDraftCalled, isTrue);
        expect(
          find.text(l10n.uploadFailureSheetSavedToDraftsSnackbar),
          findsOneWidget,
        );
        expect(find.text('welcome'), findsOneWidget);
        expect(find.text('editor'), findsNothing);

        await tester.pumpAndSettle(const Duration(seconds: 5));
      });

      testWidgets('openRecorderLibrary saves a draft, shows the snackbar, '
          'and routes to Welcome', (tester) async {
        await tester.pumpWidget(buildHarness());
        await tester.pumpAndSettle();
        final l10n = lookupAppLocalizations(const Locale('en'));

        await tester.tap(find.byKey(const Key('open-library')));
        await tester.pumpAndSettle();

        expect(fakeEditor.saveAsDraftCalled, isTrue);
        expect(
          find.text(l10n.uploadFailureSheetSavedToDraftsSnackbar),
          findsOneWidget,
        );
        expect(find.text('welcome'), findsOneWidget);
        expect(find.text('library'), findsNothing);

        await tester.pumpAndSettle(const Duration(seconds: 5));
      });

      testWidgets('openVideoEditorFromRecorder with a save already in flight '
          'shows no snackbar and stays on the recorder', (tester) async {
        fakeEditor.saveResult = DraftSaveOutcome.alreadyInProgress;

        await tester.pumpWidget(buildHarness());
        await tester.pumpAndSettle();
        final l10n = lookupAppLocalizations(const Locale('en'));

        await tester.tap(find.byKey(const Key('open-editor')));
        await tester.pumpAndSettle();

        expect(fakeEditor.saveAsDraftCalled, isTrue);
        expect(
          find.text(l10n.uploadFailureSheetSavedToDraftsSnackbar),
          findsNothing,
        );
        expect(find.text(l10n.videoMetadataFailedToSaveSnackbar), findsNothing);
        expect(find.text('welcome'), findsNothing);
        expect(find.text('editor'), findsNothing);
        expect(find.byKey(const Key('open-editor')), findsOneWidget);
      });
    });
  });

  group('autosaved session after the library', () {
    final sessionClip = DivineVideoClip(
      id: 'session-clip',
      video: EditorVideo.file('/path/to/session.mp4'),
      duration: const Duration(seconds: 2),
      recordedAt: DateTime(2026),
      targetAspectRatio: .square,
      originalAspectRatio: 1,
    );

    setUp(() {
      when(() => mockAuthService.authState).thenReturn(AuthState.authenticated);
    });

    Future<void> openThenCloseLibrary(WidgetTester tester) async {
      await tester.tap(find.byKey(const Key('open-library')));
      await tester.pumpAndSettle();
      expect(find.text('library'), findsOneWidget);

      GoRouter.of(tester.element(find.text('library'))).pop();
      await tester.pumpAndSettle();
    }

    void stubAutosaveDraft() {
      when(() => mockDraftStorageService.getAutosaveDraft()).thenAnswer(
        (_) async => DivineVideoDraft.create(
          id: 'draft_autosave',
          clips: [sessionClip],
          title: '',
          description: '',
          hashtags: const {},
          selectedApproach: 'video',
        ),
      );
    }

    testWidgets('offers the session back when a draft emptied the recorder', (
      tester,
    ) async {
      // Opening a draft resets the shared clip manager while the recorder
      // stays mounted, so its own start-up check never re-runs.
      stubAutosaveDraft();
      fakeEditor.clipsToRestore = [sessionClip];

      await tester.pumpWidget(buildHarness());
      await tester.pumpAndSettle();
      final l10n = lookupAppLocalizations(const Locale('en'));

      await openThenCloseLibrary(tester);

      expect(find.text(l10n.videoRecorderAutosaveFoundTitle), findsOneWidget);

      await tester.tap(find.text(l10n.videoRecorderAutosaveContinueButton));
      await tester.pumpAndSettle();

      expect(fakeEditor.restoreDraftCalls, equals(1));
      expect(fakeClipManager.state.clips, equals([sessionClip]));
      verify(
        () => recorderBloc.add(
          VideoRecorderAspectRatioSet(sessionClip.targetAspectRatio),
        ),
      ).called(1);
      // Unlike the cold-start prompt, coming back from the library leaves the
      // user on the recorder they navigated to.
      expect(find.text('editor'), findsNothing);
    });

    testWidgets('stays quiet when the library left the clips alone', (
      tester,
    ) async {
      stubAutosaveDraft();
      fakeClipManager.initialClips = [sessionClip];

      await tester.pumpWidget(buildHarness());
      await tester.pumpAndSettle();
      final l10n = lookupAppLocalizations(const Locale('en'));

      await openThenCloseLibrary(tester);

      expect(find.text(l10n.videoRecorderAutosaveFoundTitle), findsNothing);
      expect(fakeEditor.restoreDraftCalls, isZero);
    });
  });
}

class _FakeClipManagerNotifier extends ClipManagerNotifier {
  bool muteAllClipsCalled = false;
  int commitPendingDeletionCalls = 0;
  ClipPendingDeletion? initialPendingDeletion;
  List<DivineVideoClip> initialClips = const [];

  @override
  ClipManagerState build() => ClipManagerState(
    clips: initialClips,
    pendingDeletion: initialPendingDeletion,
  );

  void setClips(List<DivineVideoClip> clips) {
    state = state.copyWith(clips: clips);
  }

  @override
  void muteAllClips() {
    muteAllClipsCalled = true;
  }

  @override
  Future<void> commitPendingDeletion() async {
    commitPendingDeletionCalls++;
    state = state.copyWith(clearPendingDeletion: true);
  }
}

class _RecorderHarness extends ConsumerWidget {
  const _RecorderHarness();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: Column(
        children: [
          ElevatedButton(
            key: const Key('open-editor'),
            onPressed: () =>
                unawaited(openVideoEditorFromRecorder(context, ref)),
            child: const Text('open editor'),
          ),
          ElevatedButton(
            key: const Key('open-library'),
            onPressed: () => unawaited(openRecorderLibrary(context, ref)),
            child: const Text('open library'),
          ),
          ElevatedButton(
            key: const Key('show-delete-snackbar'),
            onPressed: () => showClipDeleteSnackbar(context, ref),
            child: const Text('show delete snackbar'),
          ),
          ElevatedButton(
            key: const Key('close-recorder'),
            onPressed: () => closeVideoRecorder(context, ref),
            child: const Text('close recorder'),
          ),
        ],
      ),
    );
  }
}

class _StubScreen extends StatelessWidget {
  const _StubScreen({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Scaffold(body: Center(child: Text(label)));
  }
}
