// ABOUTME: Tests for VideoAudioEditorTimingScreen widget
// ABOUTME: Validates rendering, navigation results, top bar controls,
// ABOUTME: and the AudioTimingResult sealed class hierarchy.

import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/video_editor/audio_timing/audio_timing_cubit.dart';
import 'package:openvine/constants/video_editor_constants.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/screens/video_editor/video_audio_editor_timing_screen.dart';
import 'package:openvine/widgets/stereo_waveform_painter.dart';
import 'package:openvine/widgets/video_editor/audio_editor/video_editor_audio_chip.dart';
import 'package:pro_video_editor/pro_video_editor.dart';
import 'package:sound_service/sound_service.dart';

class _MockAudioClipPlayer extends Mock implements AudioClipPlayer {}

/// Mock ProVideoEditor to prevent calls to native platform.
class _MockProVideoEditor extends ProVideoEditor {
  @override
  void initializeStream() {
    // Intentional no-op: testing stub for ProVideoEditor.
  }

  @override
  Future<bool> hasAudioTrack(
    EditorVideo value, {
    NativeLogLevel? nativeLogLevel,
  }) async {
    return true;
  }

  @override
  Future<VideoMetadata> getMetadata(
    EditorVideo value, {
    bool checkStreamingOptimization = false,
    NativeLogLevel? nativeLogLevel,
  }) async {
    return VideoMetadata(
      duration: const Duration(seconds: 10),
      extension: 'mp4',
      fileSize: 1024000,
      resolution: const Size(1920, 1080),
      rotation: 0,
      bitrate: 3000000,
    );
  }

  @override
  Future<WaveformData> getWaveform(
    WaveformConfigs value, {
    NativeLogLevel? nativeLogLevel,
  }) async {
    return WaveformData(
      leftChannel: Float32List(100),
      rightChannel: Float32List(100),
      sampleRate: 44100,
      duration: const Duration(seconds: 10),
      samplesPerSecond: 10,
    );
  }

  @override
  Future<String> extractAudioToFile(
    String filePath,
    AudioExtractConfigs value, {
    NativeLogLevel? nativeLogLevel,
  }) async {
    return filePath;
  }
}

/// Helper to create test AudioEvent instances.
AudioEvent _createTestAudioEvent({
  String id = 'test-sound-id',
  String pubkey = 'test-pubkey',
  int createdAt = 1704067200,
  String? url,
  String? title,
  String? source,
  double? duration,
}) {
  return AudioEvent(
    id: id,
    pubkey: pubkey,
    createdAt: createdAt,
    url: url ?? 'https://example.com/audio/$id.mp3',
    title: title,
    source: source,
    duration: duration ?? 10.0,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    registerFallbackValue(const AudioSourceConfig.network(''));
  });

  group('AudioTimingResult', () {
    test('$AudioTimingConfirmed holds updated sound', () {
      final sound = _createTestAudioEvent(title: 'Test Sound');
      final result = AudioTimingConfirmed(sound);

      expect(result.sound, equals(sound));
      expect(result.sound.title, equals('Test Sound'));
    });

    test('$AudioTimingDeleted can be constructed', () {
      const result = AudioTimingDeleted();

      expect(result, isA<AudioTimingResult>());
    });

    test('$AudioTimingConfirmed is $AudioTimingResult', () {
      final sound = _createTestAudioEvent();
      final result = AudioTimingConfirmed(sound);

      expect(result, isA<AudioTimingResult>());
    });

    test('exhaustive switch works on $AudioTimingResult', () {
      final sound = _createTestAudioEvent();
      final AudioTimingResult result = AudioTimingConfirmed(sound);

      // Verify pattern matching compiles and resolves correctly
      final label = switch (result) {
        AudioTimingConfirmed(:final sound) => 'confirmed: ${sound.id}',
        AudioTimingDeleted() => 'deleted',
      };

      expect(label, contains('confirmed'));
      expect(label, contains('test-sound-id'));
    });

    test('exhaustive switch resolves $AudioTimingDeleted', () {
      const AudioTimingResult result = AudioTimingDeleted();

      final label = switch (result) {
        AudioTimingConfirmed(:final sound) => 'confirmed: ${sound.id}',
        AudioTimingDeleted() => 'deleted',
      };

      expect(label, equals('deleted'));
    });
  });

  group(VideoAudioEditorTimingScreen, () {
    late _MockProVideoEditor mockEditor;
    late _MockAudioClipPlayer mockClipPlayer;
    late ProVideoEditor originalProVideoEditor;

    setUp(() {
      originalProVideoEditor = ProVideoEditor.instance;
      mockEditor = _MockProVideoEditor();
      ProVideoEditor.instance = mockEditor;
      mockClipPlayer = _MockAudioClipPlayer();
      when(
        () => mockClipPlayer.completionStream,
      ).thenAnswer((_) => const Stream.empty());
      when(() => mockClipPlayer.setClip(any())).thenAnswer((_) async {});
      when(() => mockClipPlayer.play()).thenAnswer((_) async {});
      when(() => mockClipPlayer.pause()).thenAnswer((_) async {});
      when(() => mockClipPlayer.stop()).thenAnswer((_) async {});
      when(() => mockClipPlayer.dispose()).thenAnswer((_) async {});
    });

    tearDown(() {
      ProVideoEditor.instance = originalProVideoEditor;
    });

    Widget buildWidget({
      AudioEvent? sound,
      Locale? locale,
      bool enableDeleteButton = true,
    }) {
      final testSound =
          sound ?? _createTestAudioEvent(title: 'Test Audio', duration: 10.0);

      return ProviderScope(
        child: MaterialApp(
          locale: locale,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: VideoAudioEditorTimingScreen(
            sound: testSound,
            clipPlayer: mockClipPlayer,
            enableDeleteButton: enableDeleteButton,
          ),
        ),
      );
    }

    testWidgets('renders $VideoAudioEditorTimingScreen', (tester) async {
      await tester.pumpWidget(buildWidget());
      await tester.pump();

      expect(find.byType(VideoAudioEditorTimingScreen), findsOneWidget);
    });

    testWidgets('renders instruction text', (tester) async {
      await tester.pumpWidget(buildWidget());
      await tester.pump();

      expect(
        find.text(
          lookupAppLocalizations(
            const Locale('en'),
          ).videoEditorAudioSegmentInstruction,
        ),
        findsOneWidget,
      );
    });

    testWidgets('renders localized instruction text', (tester) async {
      await tester.pumpWidget(buildWidget(locale: const Locale('de')));
      await tester.pump();

      expect(
        find.text(
          lookupAppLocalizations(
            const Locale('de'),
          ).videoEditorAudioSegmentInstruction,
        ),
        findsOneWidget,
      );
      expect(
        find.text(
          lookupAppLocalizations(
            const Locale('en'),
          ).videoEditorAudioSegmentInstruction,
        ),
        findsNothing,
      );
    });

    testWidgets('close button announces removing the audio when it deletes', (
      tester,
    ) async {
      await tester.pumpWidget(buildWidget());
      await tester.pump();

      final l10n = lookupAppLocalizations(const Locale('en'));
      expect(
        find.bySemanticsLabel(l10n.videoEditorRemoveAudioSemanticLabel),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel(
          l10n.videoEditorDiscardToolChangesSemanticLabel(
            l10n.videoEditorAudioLabel,
          ),
        ),
        findsNothing,
      );
    });

    testWidgets('close button announces discarding when it only dismisses', (
      tester,
    ) async {
      // The label and the action are chosen off the same flag, so this is the
      // one branch where they can silently drift apart: announcing "Remove
      // audio" on a button that merely pops would tell a screen-reader user
      // their audio was deleted when it was not.
      await tester.pumpWidget(buildWidget(enableDeleteButton: false));
      await tester.pump();

      final l10n = lookupAppLocalizations(const Locale('en'));
      expect(
        find.bySemanticsLabel(
          l10n.videoEditorDiscardToolChangesSemanticLabel(
            l10n.videoEditorAudioLabel,
          ),
        ),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel(l10n.videoEditorRemoveAudioSemanticLabel),
        findsNothing,
      );
    });

    testWidgets('renders $VideoEditorAudioChip in top bar', (tester) async {
      await tester.pumpWidget(buildWidget());
      await tester.pump();

      expect(find.byType(VideoEditorAudioChip), findsOneWidget);
    });

    testWidgets('renders with bundled sound', (tester) async {
      final bundledSound = AudioEvent(
        id: 'bundled__lofi-beat',
        pubkey: 'bundled_',
        createdAt: 0,
        url: 'asset://assets/sounds/lofi-beat.mp3',
        title: 'Lo-Fi Beat',
        duration: 5.0,
      );

      await tester.pumpWidget(buildWidget(sound: bundledSound));
      await tester.pump();

      expect(find.byType(VideoAudioEditorTimingScreen), findsOneWidget);
    });

    testWidgets('renders with short audio (< maxDuration)', (tester) async {
      final shortSound = _createTestAudioEvent(
        title: 'Short Clip',
        duration: 3.0,
      );

      await tester.pumpWidget(buildWidget(sound: shortSound));
      await tester.pump();

      expect(find.byType(VideoAudioEditorTimingScreen), findsOneWidget);
    });

    testWidgets('renders with long audio (> maxDuration)', (tester) async {
      final longSound = _createTestAudioEvent(
        title: 'Long Track',
        duration: 30.0,
      );

      await tester.pumpWidget(buildWidget(sound: longSound));
      await tester.pump();

      expect(find.byType(VideoAudioEditorTimingScreen), findsOneWidget);
    });

    testWidgets(
      'shrinks the selected segment to the remaining audio tail at max offset',
      (tester) async {
        tester.view.physicalSize = const Size(800, 1200);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final sound = _createTestAudioEvent(
          title: 'Tail Track',
          duration: 10.0,
        );

        await tester.pumpWidget(buildWidget(sound: sound));
        await tester.pump();

        await tester.drag(
          find.byKey(VideoAudioEditorTimingScreen.videoDurationSegmentKey),
          const Offset(1000, 0),
        );
        await tester.pump();

        const screenWidth = 800.0 - 32.0;
        const expectedTailWidth = screenWidth * (0.5 / 10.0);

        expect(
          tester
              .getSize(
                find.byKey(
                  VideoAudioEditorTimingScreen.videoDurationSegmentKey,
                ),
              )
              .width,
          closeTo(expectedTailWidth, 0.1),
        );
        expect(
          tester
              .getSize(
                find.byKey(VideoAudioEditorTimingScreen.waveformSelectionKey),
              )
              .width,
          closeTo(expectedTailWidth, 0.1),
        );
      },
    );

    testWidgets('resolves the in-point to at most one frame per pixel', (
      tester,
    ) async {
      // The waveform is the fine control, and the timeline ruler labels
      // sub-second positions in frames — so a pixel of drag may never move the
      // in-point by more than a frame. Deriving the waveform's zoom from the
      // overview bar's proportional width (as it once did) breaks exactly this:
      // a 120s track collapsed the selection to ~40px, ~6 frames per pixel.
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        buildWidget(
          sound: _createTestAudioEvent(title: 'Long Track', duration: 120),
        ),
      );
      await tester.pump();

      // The selection window always spans maxDuration worth of audio, so its
      // width in pixels is what sets the scrub resolution.
      final selectionWidth = tester
          .getSize(
            find.byKey(VideoAudioEditorTimingScreen.waveformSelectionKey),
          )
          .width;
      final msPerPixel =
          VideoEditorConstants.maxDuration.inMilliseconds / selectionWidth;
      const frameMs = 1000 / VideoEditorConstants.editorFps;

      // One pixel per frame is the design target, so this lands on equality —
      // allow a hair of float slack rather than asserting strict inequality.
      expect(msPerPixel, lessThan(frameMs + 0.01));
    });

    testWidgets('overview segment reflects its true share of the track', (
      tester,
    ) async {
      // The upper bar spans the whole track, so its marker must not be inflated
      // to keep it grabbable — that would claim the selection covers several
      // times more audio than it does. Visibility is a pixel floor instead.
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      const audioDurationSecs = 120.0;
      await tester.pumpWidget(
        buildWidget(
          sound: _createTestAudioEvent(
            title: 'Long Track',
            duration: audioDurationSecs,
          ),
        ),
      );
      await tester.pump();

      const screenWidth = 800.0 - 32.0;
      final maxDurationSecs =
          VideoEditorConstants.maxDuration.inMilliseconds / 1000.0;
      final expectedWidth = screenWidth * (maxDurationSecs / audioDurationSecs);

      expect(
        tester
            .getSize(
              find.byKey(VideoAudioEditorTimingScreen.videoDurationSegmentKey),
            )
            .width,
        closeTo(expectedWidth, 0.1),
      );
    });

    testWidgets('draws the whole track across the waveform strip', (
      tester,
    ) async {
      // The strip is as wide as the track is long, but the painter was told it
      // only spanned one video duration — so it mapped the opening 6.3s across
      // the entire strip and the bars under the selection never corresponded
      // to the audio playing. Scrubbing to a visible transient landed
      // somewhere else entirely.
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      const audioDurationSecs = 120.0;
      await tester.pumpWidget(
        buildWidget(
          sound: _createTestAudioEvent(
            title: 'Long Track',
            duration: audioDurationSecs,
          ),
        ),
      );
      await tester.pump();

      final waveform = find.byWidgetPredicate(
        (widget) =>
            widget is CustomPaint && widget.painter is StereoWaveformPainter,
      );
      final painter =
          tester.widget<CustomPaint>(waveform).painter!
              as StereoWaveformPainter;

      // The selection is the scale reference: it is maxDuration wide by
      // construction. The strip must carry the painter's span at that same
      // scale, or the bars are stretched relative to the in-point.
      final maxDurationSecs =
          VideoEditorConstants.maxDuration.inMilliseconds / 1000.0;
      final pixelsPerSecond =
          tester
              .getSize(
                find.byKey(VideoAudioEditorTimingScreen.waveformSelectionKey),
              )
              .width /
          maxDurationSecs;

      expect(
        painter.maxDuration.inMilliseconds / 1000.0 * pixelsPerSecond,
        closeTo(tester.getSize(waveform).width, 0.5),
      );
      expect(painter.maxDuration, equals(painter.audioDuration));
    });

    testWidgets('scrolls a short track by its own length, not the window', (
      tester,
    ) async {
      // Audio shorter than the video still scrolls, up to
      // `duration - minRemainingAudio`. The scroll range was derived from the
      // selection window rather than the track's on-screen extent, so it ran
      // 6.3/duration times too far and the waveform left the window entirely
      // before the in-point reached its limit.
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      const audioDurationSecs = 3.0;
      await tester.pumpWidget(
        buildWidget(
          sound: _createTestAudioEvent(
            title: 'Short Clip',
            duration: audioDurationSecs,
          ),
        ),
      );
      await tester.pump();

      const screenWidth = 800.0 - 32.0;
      final maxDurationSecs =
          VideoEditorConstants.maxDuration.inMilliseconds / 1000.0;
      const pixelsPerSecond = screenWidth / 6.3;
      final selection = find.byKey(
        VideoAudioEditorTimingScreen.waveformSelectionKey,
      );

      // The video outlasts the audio, so the box covers the track, not the
      // full window.
      expect(maxDurationSecs, equals(6.3));
      expect(
        tester.getSize(selection).width,
        closeTo(audioDurationSecs * pixelsPerSecond, 0.1),
      );

      // The pointer lands on the selection's border overlay rather than the
      // keyed box, but both sit inside the strip's single drag detector.
      await tester.drag(selection, const Offset(-1000, 0), warnIfMissed: false);
      await tester.pump();

      // At the far end only `minRemainingAudio` is still under the box.
      expect(
        tester.getSize(selection).width,
        closeTo(AudioTimingCubit.minRemainingAudioSecs * pixelsPerSecond, 0.1),
      );
    });

    testWidgets('has route name and path constants', (tester) async {
      expect(
        VideoAudioEditorTimingScreen.routeName,
        equals('video-audio-timing'),
      );
      expect(VideoAudioEditorTimingScreen.path, equals('/video-audio-timing'));
    });
  });
}
