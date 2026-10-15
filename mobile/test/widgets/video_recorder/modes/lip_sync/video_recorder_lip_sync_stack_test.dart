import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart' show AudioEvent, VineSound;
import 'package:openvine/blocs/saved_sounds/saved_sounds_bloc.dart';
import 'package:openvine/blocs/sound_waveform/sound_waveform_bloc.dart';
import 'package:openvine/blocs/video_recorder/video_recorder_bloc.dart';
import 'package:openvine/constants/semantic_ids.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/clip_manager_state.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/models/video_editor/video_editor_provider_state.dart';
import 'package:openvine/models/video_recorder/video_recorder_mode.dart';
import 'package:openvine/models/video_recorder/video_recorder_state.dart';
import 'package:openvine/providers/clip_manager_provider.dart';
import 'package:openvine/providers/shared_preferences_provider.dart';
import 'package:openvine/providers/sound_library_service_provider.dart';
import 'package:openvine/providers/sounds_providers.dart';
import 'package:openvine/providers/video_editor_provider.dart';
import 'package:openvine/services/sound_library_service.dart';
import 'package:openvine/widgets/video_editor/audio_editor/audio_category_bar.dart';
import 'package:openvine/widgets/video_editor/audio_editor/audio_selection_bottom_sheet.dart';
import 'package:openvine/widgets/video_editor/audio_editor/video_editor_audio_chip.dart';
import 'package:openvine/widgets/video_recorder/modes/capture/video_recorder_capture_stack.dart';
import 'package:openvine/widgets/video_recorder/modes/lip_sync/video_recorder_lip_sync_stack.dart';
import 'package:openvine/widgets/video_recorder/video_recorder_audio_progress_bar.dart';
import 'package:pro_video_editor/pro_video_editor.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockVideoRecorderBloc
    extends MockBloc<VideoRecorderEvent, VideoRecorderBlocState>
    implements VideoRecorderBloc {}

class _MockSavedSoundsBloc extends MockBloc<SavedSoundsEvent, SavedSoundsState>
    implements SavedSoundsBloc {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group(VideoRecorderLipSyncStack, () {
    late _MockVideoRecorderBloc recorderBloc;
    late _MockSavedSoundsBloc savedSoundsBloc;
    late SharedPreferences testPrefs;
    late _TestClipManagerNotifier clipNotifier;
    late _TestVideoEditorNotifier editorNotifier;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      testPrefs = await SharedPreferences.getInstance();
      recorderBloc = _MockVideoRecorderBloc();
      savedSoundsBloc = _MockSavedSoundsBloc();
    });

    AudioEvent sound(String id) => AudioEvent(
      id: id,
      pubkey: 'pubkey',
      createdAt: 1704067200,
      url: 'https://example.com/audio/$id.mp3',
      title: id,
      duration: 5,
    );

    Widget buildWidget({
      VideoRecorderState recordingState = VideoRecorderState.idle,
      AudioEvent? selectedSound,
      List<DivineVideoClip>? clips,
      GoRouter? router,
      TrendingSounds Function() trendingSounds = _FakeTrendingSounds.new,
      TextDirection textDirection = TextDirection.ltr,
    }) {
      when(() => recorderBloc.isClosed).thenReturn(false);
      when(() => recorderBloc.state).thenReturn(
        VideoRecorderBlocState(
          recorderMode: VideoRecorderMode.lipSync,
          recordingState: recordingState,
          isCameraInitialized: true,
          canRecord: true,
        ),
      );
      when(() => savedSoundsBloc.state).thenReturn(
        const SavedSoundsState(status: SavedSoundsStatus.loaded),
      );

      clipNotifier = _TestClipManagerNotifier(clips: clips ?? []);
      editorNotifier = _TestVideoEditorNotifier(selectedSound: selectedSound);

      return ProviderScope(
        // A failing sound source shows its error instead of retrying.
        retry: (_, _) => null,
        overrides: [
          sharedPreferencesProvider.overrideWithValue(testPrefs),
          clipManagerProvider.overrideWith(() => clipNotifier),
          videoEditorProvider.overrideWith(() => editorNotifier),
          // The sound picker's sources: bundled sounds only, enough to scroll.
          soundLibraryServiceProvider.overrideWith(
            (_) async => _FakeSoundLibraryService(),
          ),
          trendingSoundsProvider.overrideWith(trendingSounds),
        ],
        child: MultiBlocProvider(
          providers: [
            BlocProvider<VideoRecorderBloc>.value(value: recorderBloc),
            BlocProvider<SavedSoundsBloc>.value(value: savedSoundsBloc),
            BlocProvider<SoundWaveformBloc>(create: (_) => SoundWaveformBloc()),
          ],
          child: router == null
              ? MaterialApp(
                  localizationsDelegates: appLocalizationsDelegates,
                  supportedLocales: AppLocalizations.supportedLocales,
                  home: Directionality(
                    textDirection: textDirection,
                    child: const Scaffold(body: VideoRecorderLipSyncStack()),
                  ),
                )
              : MaterialApp.router(
                  localizationsDelegates: appLocalizationsDelegates,
                  supportedLocales: AppLocalizations.supportedLocales,
                  routerConfig: router,
                ),
        ),
      );
    }

    Future<void> pickInlineSound(WidgetTester tester, AudioEvent picked) async {
      tester
          .widget<AudioSelectionBottomSheet>(
            find.byType(AudioSelectionBottomSheet),
          )
          .onSoundPicked!(picked);
      await tester.pumpAndSettle();
    }

    group('before a sound is picked', () {
      testWidgets('shows the sound picker instead of the viewfinder', (
        tester,
      ) async {
        await tester.pumpWidget(buildWidget());
        await tester.pumpAndSettle();

        expect(find.byType(AudioSelectionBottomSheet), findsOneWidget);
        expect(find.byType(VideoRecorderCaptureStack), findsNothing);
      });

      testWidgets('leaves the recorder from the close button left of the '
          'categories', (tester) async {
        final handle = tester.ensureSemantics();
        try {
          final router = GoRouter(
            routes: [
              GoRoute(
                path: '/',
                builder: (_, _) => const Scaffold(body: Text('feed')),
              ),
              GoRoute(
                path: '/recorder',
                builder: (_, _) =>
                    const Scaffold(body: VideoRecorderLipSyncStack()),
              ),
            ],
          );
          addTearDown(router.dispose);
          await tester.pumpWidget(buildWidget(router: router));
          unawaited(router.push('/recorder'));
          await tester.pumpAndSettle();

          await tester.tap(
            find.bySemanticsIdentifier(SemanticIds.cameraCloseButton),
          );
          await tester.pumpAndSettle();

          expect(find.byType(VideoRecorderLipSyncStack), findsNothing);
          expect(find.text('feed'), findsOneWidget);
        } finally {
          handle.dispose();
        }
      });

      testWidgets('insets the close button from the leading screen edge in '
          'right-to-left layouts', (tester) async {
        // Disposed in `finally`, not `addTearDown`: flutter_test checks for
        // live handles before tear-downs run.
        final handle = tester.ensureSemantics();
        try {
          await tester.pumpWidget(
            buildWidget(textDirection: TextDirection.rtl),
          );
          await tester.pumpAndSettle();
          final screenWidth =
              tester.view.physicalSize.width / tester.view.devicePixelRatio;

          final close = find.bySemanticsIdentifier(
            SemanticIds.cameraCloseButton,
          );

          expect(tester.getTopRight(close).dx, screenWidth - 12);
        } finally {
          handle.dispose();
        }
      });

      testWidgets('leaves the home-indicator inset to the mode wheel below '
          'it', (tester) async {
        tester.view
          ..padding = const FakeViewPadding(bottom: 102)
          ..viewPadding = const FakeViewPadding(bottom: 102);
        addTearDown(tester.view.reset);
        await tester.pumpWidget(buildWidget());
        await tester.pumpAndSettle();

        final picker = tester.element(find.byType(AudioSelectionBottomSheet));

        expect(MediaQuery.paddingOf(picker).bottom, 0);
        expect(MediaQuery.viewPaddingOf(picker).bottom, 0);
      });

      testWidgets('pauses remote recording while the picker shows', (
        tester,
      ) async {
        await tester.pumpWidget(buildWidget());
        await tester.pumpAndSettle();

        verify(
          () => recorderBloc.add(const VideoRecorderRemoteRecordPaused()),
        ).called(1);
        verifyNever(
          () => recorderBloc.add(const VideoRecorderRemoteRecordResumed()),
        );

        await pickInlineSound(tester, sound('picked'));

        verify(
          () => recorderBloc.add(const VideoRecorderRemoteRecordResumed()),
        ).called(1);
      });
    });

    group('sound picker scrolling', () {
      testWidgets('keeps the categories in place while the search scrolls '
          'away', (tester) async {
        await tester.pumpWidget(buildWidget());
        await tester.pumpAndSettle();
        final categories = find.byType(AudioCategoryBar);
        final search = find.byType(TextField);
        final categoriesTop = tester.getTopLeft(categories).dy;
        final searchTop = tester.getTopLeft(search).dy;

        await tester.drag(find.byType(TabBarView), const Offset(0, -40));
        await tester.pumpAndSettle();

        expect(tester.getTopLeft(categories).dy, categoriesTop);
        expect(tester.getTopLeft(search).dy, lessThan(searchTop));
      });

      testWidgets('floats only the search back in on scrolling up', (
        tester,
      ) async {
        final l10n = lookupAppLocalizations(const Locale('en'));
        await tester.pumpWidget(buildWidget());
        await tester.pumpAndSettle();
        final search = find.byType(TextField).hitTestable();
        final importAudio = find
            .text(l10n.videoEditorAudioImportAudio)
            .hitTestable();
        expect(importAudio, findsOneWidget);

        await tester.drag(find.byType(TabBarView), const Offset(0, -500));
        await tester.pumpAndSettle();
        expect(search, findsNothing);

        await tester.drag(find.byType(TabBarView), const Offset(0, 160));
        await tester.pumpAndSettle();

        expect(search, findsOneWidget);
        // Back without the list, or the import row above it, returning to the
        // top.
        expect(importAudio, findsNothing);
        expect(find.text('Bundled sound 0').hitTestable(), findsNothing);
      });
    });

    group('importing audio', () {
      Future<void> showCommunity(WidgetTester tester) async {
        tester
            .widget<AudioCategoryBar>(find.byType(AudioCategoryBar))
            .onSelect(AudioCategory.community);
        // The loading indicator keeps animating, so pumpAndSettle would not.
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));
      }

      testWidgets('offers importing while the community sounds load', (
        tester,
      ) async {
        final l10n = lookupAppLocalizations(const Locale('en'));
        await tester.pumpWidget(
          buildWidget(trendingSounds: _PendingTrendingSounds.new),
        );
        await tester.pump();

        await showCommunity(tester);

        expect(
          find.text(l10n.videoEditorAudioImportAudio).hitTestable(),
          findsOneWidget,
        );
      });

      testWidgets('offers importing when the community sounds fail to load', (
        tester,
      ) async {
        final l10n = lookupAppLocalizations(const Locale('en'));
        await tester.pumpWidget(
          buildWidget(trendingSounds: _FailingTrendingSounds.new),
        );
        await tester.pump();

        await showCommunity(tester);

        expect(
          find.text(l10n.videoEditorAudioFailedToLoadTitle),
          findsOneWidget,
        );
        expect(
          find.text(l10n.videoEditorAudioImportAudio).hitTestable(),
          findsOneWidget,
        );
      });
    });

    group('picking a sound', () {
      testWidgets('swaps the picker for the viewfinder with the sound', (
        tester,
      ) async {
        await tester.pumpWidget(buildWidget());
        await tester.pumpAndSettle();

        await pickInlineSound(tester, sound('picked'));

        expect(editorNotifier.selectRecorderAudioTrackCalls, [sound('picked')]);
        expect(find.byType(AudioSelectionBottomSheet), findsNothing);
        expect(find.byType(VideoRecorderCaptureStack), findsOneWidget);
        expect(find.textContaining('picked'), findsOneWidget);
      });

      testWidgets('drops a second pick while the clips are cleared for the '
          'first', (tester) async {
        await tester.pumpWidget(buildWidget(clips: [_clip()]));
        await tester.pumpAndSettle();
        final draftDeletion = Completer<void>();
        clipNotifier.draftDeletion = draftDeletion;

        await pickInlineSound(tester, sound('first'));
        await pickInlineSound(tester, sound('second'));
        draftDeletion.complete();
        await tester.pumpAndSettle();

        expect(clipNotifier.clearAllCallCount, 1);
        expect(editorNotifier.selectRecorderAudioTrackCalls, [sound('first')]);
      });

      testWidgets('stays on the picker and takes a new pick when adopting '
          'the sound fails', (tester) async {
        await tester.pumpWidget(buildWidget(clips: [_clip()]));
        await tester.pumpAndSettle();
        clipNotifier.clearAllError = Exception('draft deletion failed');

        await pickInlineSound(tester, sound('first'));

        expect(editorNotifier.selectRecorderAudioTrackCalls, isEmpty);
        expect(find.byType(AudioSelectionBottomSheet), findsOneWidget);

        clipNotifier.clearAllError = null;
        await pickInlineSound(tester, sound('second'));

        expect(editorNotifier.selectRecorderAudioTrackCalls, [sound('second')]);
      });

      testWidgets('brings the picker back when the sound is removed', (
        tester,
      ) async {
        await tester.pumpWidget(buildWidget(selectedSound: sound('a')));
        await tester.pumpAndSettle();

        tester
            .widget<VideoEditorAudioChip>(find.byType(VideoEditorAudioChip))
            .onSoundChanged(null);
        await tester.pumpAndSettle();

        expect(find.byType(VideoRecorderCaptureStack), findsNothing);
        expect(find.byType(AudioSelectionBottomSheet), findsOneWidget);
      });
    });

    group('with a sound picked', () {
      testWidgets('shows the viewfinder with the sound in the top bar', (
        tester,
      ) async {
        await tester.pumpWidget(
          buildWidget(
            selectedSound: AudioEvent(
              id: 'sound-1',
              pubkey: 'pubkey',
              createdAt: 1704067200,
              url: 'https://example.com/audio/sound-1.mp3',
              title: 'My Sound',
              duration: 5,
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(AudioSelectionBottomSheet), findsNothing);
        expect(find.byType(VideoRecorderCaptureStack), findsOneWidget);
        expect(find.byType(VideoEditorAudioChip), findsOneWidget);
        expect(find.textContaining('My Sound'), findsOneWidget);
      });

      testWidgets('wires in the $VideoRecorderAudioProgressBar', (
        tester,
      ) async {
        await tester.pumpWidget(buildWidget(selectedSound: sound('a')));
        await tester.pumpAndSettle();

        expect(find.byType(VideoRecorderAudioProgressBar), findsOneWidget);
      });

      testWidgets('hides the audio chip while recording', (tester) async {
        await tester.pumpWidget(
          buildWidget(
            recordingState: VideoRecorderState.recording,
            selectedSound: sound('a'),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(find.byType(VideoRecorderCaptureStack), findsOneWidget);
        expect(find.byType(VideoEditorAudioChip), findsNothing);
      });
    });

    group('leaving lip-sync', () {
      GoRouter recorderRouter() {
        final router = GoRouter(
          routes: [
            GoRoute(
              path: '/',
              builder: (_, _) => const Scaffold(body: Text('feed')),
            ),
            GoRoute(
              path: '/recorder',
              builder: (_, _) =>
                  const Scaffold(body: VideoRecorderLipSyncStack()),
            ),
            GoRoute(
              path: '/over',
              builder: (_, _) => const Scaffold(body: Text('over')),
            ),
          ],
        );
        addTearDown(router.dispose);
        return router;
      }

      testWidgets('keeps the viewfinder while switching to another mode', (
        tester,
      ) async {
        final widget = buildWidget(selectedSound: sound('a'));
        final states = StreamController<VideoRecorderBlocState>();
        addTearDown(states.close);
        final lipSync = recorderBloc.state;
        whenListen(recorderBloc, states.stream, initialState: lipSync);
        await tester.pumpWidget(widget);
        await tester.pumpAndSettle();

        // The bloc emits the new mode, then resets the editor.
        states.add(lipSync.copyWith(recorderMode: VideoRecorderMode.capture));
        await tester.pump();
        editorNotifier.resetForClearAll();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        expect(find.byType(AudioSelectionBottomSheet), findsNothing);
        expect(find.byType(VideoRecorderCaptureStack), findsOneWidget);
      });

      testWidgets('keeps the viewfinder while the recorder closes', (
        tester,
      ) async {
        final router = recorderRouter();
        await tester.pumpWidget(
          buildWidget(selectedSound: sound('a'), router: router),
        );
        unawaited(router.push('/recorder'));
        await tester.pumpAndSettle();

        // Popping discards the session, which resets the editor.
        router.pop();
        editorNotifier.resetForClearAll();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));

        expect(find.byType(VideoRecorderLipSyncStack), findsOneWidget);
        expect(find.byType(AudioSelectionBottomSheet), findsNothing);
      });

      testWidgets('follows a sound removed under another screen once it '
          'returns', (tester) async {
        final router = recorderRouter();
        await tester.pumpWidget(
          buildWidget(selectedSound: sound('a'), router: router),
        );
        unawaited(router.push('/recorder'));
        await tester.pumpAndSettle();
        unawaited(router.push('/over'));
        await tester.pumpAndSettle();

        editorNotifier.resetForClearAll();
        await tester.pumpAndSettle();
        router.pop();
        await tester.pumpAndSettle();

        expect(find.byType(AudioSelectionBottomSheet), findsOneWidget);
        expect(find.byType(VideoRecorderCaptureStack), findsNothing);
      });
    });

    group('changing the sound selection', () {
      Future<void> changeSound(WidgetTester tester, AudioEvent? next) async {
        final chip = tester.widget<VideoEditorAudioChip>(
          find.byType(VideoEditorAudioChip),
        );
        chip.onSoundChanged(next);
        await tester.pumpAndSettle();
      }

      testWidgets('clears recorded clips when a different sound is selected', (
        tester,
      ) async {
        await tester.pumpWidget(
          buildWidget(selectedSound: sound('a'), clips: [_clip()]),
        );
        await tester.pumpAndSettle();

        await changeSound(tester, sound('b'));

        expect(clipNotifier.clearAllCallCount, 1);
        expect(editorNotifier.selectRecorderAudioTrackCalls, [sound('b')]);
      });

      testWidgets('adopts the new sound when clearing the clips outlasts the '
          'swap to the picker', (tester) async {
        await tester.pumpWidget(
          buildWidget(selectedSound: sound('a'), clips: [_clip()]),
        );
        await tester.pumpAndSettle();
        final draftDeletion = Completer<void>();
        clipNotifier.draftDeletion = draftDeletion;

        await changeSound(tester, sound('b'));
        // The reset dropped the sound, so the chip that changed it is gone.
        expect(find.byType(VideoEditorAudioChip), findsNothing);

        draftDeletion.complete();
        await tester.pumpAndSettle();

        expect(editorNotifier.selectRecorderAudioTrackCalls, [sound('b')]);
        expect(find.byType(VideoRecorderCaptureStack), findsOneWidget);
      });

      testWidgets('does not clear clips when the same sound is reselected', (
        tester,
      ) async {
        await tester.pumpWidget(
          buildWidget(selectedSound: sound('a'), clips: [_clip()]),
        );
        await tester.pumpAndSettle();

        await changeSound(tester, sound('a'));

        expect(clipNotifier.clearAllCallCount, 0);
        expect(editorNotifier.selectRecorderAudioTrackCalls, [sound('a')]);
      });

      testWidgets('does not clear when there are no recorded clips', (
        tester,
      ) async {
        await tester.pumpWidget(buildWidget(selectedSound: sound('a')));
        await tester.pumpAndSettle();

        await changeSound(tester, sound('b'));

        expect(clipNotifier.clearAllCallCount, 0);
        expect(editorNotifier.selectRecorderAudioTrackCalls, [sound('b')]);
      });
    });
  });
}

DivineVideoClip _clip() => DivineVideoClip(
  id: 'clip1',
  video: EditorVideo.file('/test/clip1.mp4'),
  duration: const Duration(seconds: 2),
  recordedAt: DateTime.now(),
  targetAspectRatio: .vertical,
  originalAspectRatio: 9 / 16,
);

class _FakeSoundLibraryService extends SoundLibraryService {
  @override
  List<VineSound> get sounds => [
    for (var i = 0; i < 30; i++)
      VineSound(
        id: 'bundled-$i',
        title: 'Bundled sound $i',
        assetPath: 'assets/sounds/bundled-$i.mp3',
        duration: const Duration(seconds: 3),
      ),
  ];

  @override
  List<VineSound> get customSounds => const [];

  @override
  bool get isLoaded => true;

  @override
  Future<void> loadSounds() async {}

  @override
  Future<void> loadCustomSounds() async {}
}

class _FakeTrendingSounds extends TrendingSounds {
  @override
  Future<List<AudioEvent>> build() async => const [];
}

class _PendingTrendingSounds extends TrendingSounds {
  @override
  Future<List<AudioEvent>> build() => Completer<List<AudioEvent>>().future;
}

class _FailingTrendingSounds extends TrendingSounds {
  @override
  Future<List<AudioEvent>> build() async =>
      throw Exception('relay unreachable');
}

class _TestClipManagerNotifier extends ClipManagerNotifier {
  _TestClipManagerNotifier({required this.clips});

  @override
  final List<DivineVideoClip> clips;

  int clearAllCallCount = 0;

  /// Holds [clearAll] after the editor reset, as deleting the autosave draft
  /// does, until it completes.
  Completer<void>? draftDeletion;

  /// Thrown by [clearAll] before it clears anything.
  Object? clearAllError;

  @override
  ClipManagerState build() {
    return ClipManagerState(clips: clips);
  }

  /// Clears the clips and resets the editor first, as the real one does, so
  /// the selected sound is gone while the draft is deleted.
  @override
  Future<void> clearAll({bool keepAutosavedDraft = false}) async {
    clearAllCallCount++;
    if (clearAllError case final error?) throw error;
    state = ClipManagerState();
    (ref.read(videoEditorProvider.notifier) as _TestVideoEditorNotifier)
        .resetForClearAll();
    await draftDeletion?.future;
  }
}

class _TestVideoEditorNotifier extends VideoEditorNotifier {
  _TestVideoEditorNotifier({this.selectedSound});

  final AudioEvent? selectedSound;
  final List<AudioEvent?> selectRecorderAudioTrackCalls = [];

  @override
  VideoEditorProviderState build() {
    return VideoEditorProviderState(selectedSound: selectedSound);
  }

  void resetForClearAll() => state = VideoEditorProviderState();

  @override
  void selectRecorderAudioTrack(AudioEvent? sound) {
    selectRecorderAudioTrackCalls.add(sound);
    state = state.copyWith(
      selectedSound: sound,
      clearSelectedSound: sound == null,
      seedSelectedSoundAsAudioTrack: sound != null,
    );
  }
}
