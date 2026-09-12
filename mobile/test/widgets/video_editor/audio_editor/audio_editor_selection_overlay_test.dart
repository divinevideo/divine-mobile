// ABOUTME: Tests for AudioEditorSelectionOverlay widget
// ABOUTME: Validates rendering of audio metadata, play/pause toggle, and done.

import 'dart:async';
import 'dart:ui' show Tristate;

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/constants/semantic_ids.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/widgets/branded_loading_indicator.dart';
import 'package:openvine/widgets/video_editor/audio_editor/audio_editor_selection_overlay.dart';
import 'package:sound_service/sound_service.dart';

class _MockAudioPlaybackService extends Mock implements AudioPlaybackService {}

AudioEvent _createTestAudio({
  String id = 'sound-id',
  String? title,
  String? source,
  double? duration = 65.0,
}) {
  return AudioEvent(
    id: id,
    pubkey: 'pubkey',
    createdAt: 1704067200,
    url: 'https://example.com/$id.mp3',
    title: title,
    source: source,
    duration: duration,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _MockAudioPlaybackService audioService;

  setUp(() {
    audioService = _MockAudioPlaybackService();
    when(
      () => audioService.playingStream,
    ).thenAnswer((_) => const Stream<bool>.empty());
    when(
      () => audioService.durationStream,
    ).thenAnswer((_) => const Stream<Duration?>.empty());
    when(
      () => audioService.positionStream,
    ).thenAnswer((_) => const Stream<Duration>.empty());
    when(() => audioService.isPlaying).thenReturn(false);
    when(() => audioService.duration).thenReturn(null);
  });

  group(AudioEditorSelectionOverlay, () {
    Widget buildWidget({
      required AudioEvent audio,
      VoidCallback? onTogglePlayState,
      VoidCallback? onTapDone,
      bool isLoading = false,
    }) {
      return MaterialApp(
        localizationsDelegates: appLocalizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: AudioEditorSelectionOverlay(
            audio: audio,
            audioService: audioService,
            onTogglePlayState: onTogglePlayState ?? () {},
            onTapDone: onTapDone ?? () {},
            isLoading: isLoading,
          ),
        ),
      );
    }

    group('semantics', () {
      // The lip-sync E2E flow confirms its sound with this button
      // (e2e/maestro/tests/lipSyncModeRecordClip.yaml). The label assertions
      // elsewhere in this file stay green when the identifier is dropped.
      testWidgets('exposes the E2E identifier on the done button', (
        tester,
      ) async {
        final handle = tester.ensureSemantics();
        await tester.pumpWidget(buildWidget(audio: _createTestAudio()));
        await tester.pump();

        expect(
          find.bySemanticsIdentifier(SemanticIds.audioSelectionDoneButton),
          findsOneWidget,
        );

        handle.dispose();
      });

      // The E2E waits for this button to become enabled before tapping it,
      // because the preview is still loading right after the tile tap.
      testWidgets('reports the done button as disabled while loading', (
        tester,
      ) async {
        final handle = tester.ensureSemantics();
        await tester.pumpWidget(
          buildWidget(audio: _createTestAudio(), isLoading: true),
        );
        await tester.pump();

        final node = tester.getSemantics(
          find.bySemanticsIdentifier(SemanticIds.audioSelectionDoneButton),
        );
        expect(node.flagsCollection.isEnabled, Tristate.isFalse);

        handle.dispose();
      });
    });

    group('Rendering', () {
      testWidgets('renders audio title', (tester) async {
        await tester.pumpWidget(
          buildWidget(audio: _createTestAudio(title: 'My Track')),
        );
        await tester.pump();

        expect(find.text('My Track'), findsOneWidget);
      });

      testWidgets('renders untitled fallback when title is null', (
        tester,
      ) async {
        await tester.pumpWidget(buildWidget(audio: _createTestAudio()));
        await tester.pump();

        final l10n = lookupAppLocalizations(const Locale('en'));
        expect(find.text(l10n.videoEditorAudioUntitledSound), findsOneWidget);
      });

      testWidgets('renders formatted duration', (tester) async {
        await tester.pumpWidget(
          buildWidget(audio: _createTestAudio(duration: 125.0)),
        );
        await tester.pump();

        expect(find.textContaining('02:05'), findsOneWidget);
      });

      testWidgets('renders source when available', (tester) async {
        await tester.pumpWidget(
          buildWidget(audio: _createTestAudio(source: 'Artist X')),
        );
        await tester.pump();

        expect(find.textContaining('Artist X'), findsOneWidget);
      });
    });

    group('Callbacks', () {
      testWidgets('calls onTogglePlayState when play button is tapped', (
        tester,
      ) async {
        var toggled = false;
        await tester.pumpWidget(
          buildWidget(
            audio: _createTestAudio(title: 'Track'),
            onTogglePlayState: () => toggled = true,
          ),
        );
        await tester.pump();

        final l10n = lookupAppLocalizations(const Locale('en'));
        await tester.tap(
          find.bySemanticsLabel(l10n.videoEditorAudioPlayPreviewSemanticLabel),
        );
        await tester.pump();

        expect(toggled, isTrue);
      });

      testWidgets('calls onTapDone when done button is tapped', (tester) async {
        var done = false;
        await tester.pumpWidget(
          buildWidget(
            audio: _createTestAudio(title: 'Track'),
            onTapDone: () => done = true,
          ),
        );
        await tester.pump();

        final l10n = lookupAppLocalizations(const Locale('en'));
        await tester.tap(
          find.bySemanticsLabel(l10n.videoEditorDoneSemanticLabel),
        );
        await tester.pump();

        expect(done, isTrue);
      });

      testWidgets('disables done while audio is loading', (tester) async {
        var done = false;
        await tester.pumpWidget(
          buildWidget(
            audio: _createTestAudio(title: 'Track'),
            onTapDone: () => done = true,
            isLoading: true,
          ),
        );
        await tester.pump();

        final l10n = lookupAppLocalizations(const Locale('en'));
        await tester.tap(
          find.bySemanticsLabel(l10n.videoEditorDoneSemanticLabel),
          warnIfMissed: false,
        );
        await tester.pump();

        expect(done, isFalse);
      });
    });

    group('Playing state', () {
      testWidgets('shows pause semantic label when playing', (tester) async {
        when(() => audioService.isPlaying).thenReturn(true);
        when(
          () => audioService.playingStream,
        ).thenAnswer((_) => Stream<bool>.value(true));

        await tester.pumpWidget(
          buildWidget(audio: _createTestAudio(title: 'Track')),
        );
        await tester.pump();

        final l10n = lookupAppLocalizations(const Locale('en'));
        expect(
          find.bySemanticsLabel(l10n.videoEditorAudioPausePreviewSemanticLabel),
          findsOneWidget,
        );
      });
    });

    group('Progress ring', () {
      late StreamController<Duration> positionController;

      setUp(() {
        positionController = StreamController<Duration>.broadcast();
        when(
          () => audioService.positionStream,
        ).thenAnswer((_) => positionController.stream);
        when(
          () => audioService.duration,
        ).thenReturn(const Duration(seconds: 10));
      });

      tearDown(() => positionController.close());

      // The ring is painted as the foreground of the box holding the
      // play/pause button, so it is the outermost paint in that subtree.
      CustomPainter progressPainter(WidgetTester tester) {
        final paint = tester.widget<CustomPaint>(
          find
              .descendant(
                of: find.byWidgetPredicate(
                  (widget) =>
                      widget is SizedBox &&
                      widget.width == 42 &&
                      widget.height == 42,
                ),
                matching: find.byType(CustomPaint),
              )
              .first,
        );
        return paint.foregroundPainter!;
      }

      Future<void> emitPosition(WidgetTester tester, Duration position) async {
        positionController.add(position);
        await tester.idle();
        await tester.pump();
      }

      // just_audio advances the position from the moment play() is requested,
      // while the platform reports the true — smaller — position once it
      // actually starts rendering audio. Painting that correction rewinds the
      // ring at the start of every preview.
      testWidgets('holds while the player corrects the position backwards', (
        tester,
      ) async {
        await tester.pumpWidget(buildWidget(audio: _createTestAudio()));
        await tester.pump();

        await emitPosition(tester, const Duration(milliseconds: 500));
        final ahead = progressPainter(tester);

        await emitPosition(tester, const Duration(milliseconds: 200));
        expect(progressPainter(tester).shouldRepaint(ahead), isFalse);

        await emitPosition(tester, const Duration(milliseconds: 800));
        expect(progressPainter(tester).shouldRepaint(ahead), isTrue);
      });

      // Loading swaps the ring out for the spinner, so the position
      // StreamBuilder remounts on the way back and its `initialData` of
      // `Duration.zero` is what clears the previous sound's progress. Nothing
      // else resets it on this path, so a change to that initial value would
      // silently leave the old ring on screen while the next sound loads.
      // pumpAndSettle is unusable here — the spinner animates forever.
      testWidgets('resets after a loading round-trip', (tester) async {
        await tester.pumpWidget(buildWidget(audio: _createTestAudio()));
        await tester.pump();
        final atStart = progressPainter(tester);

        await emitPosition(tester, const Duration(seconds: 5));
        expect(progressPainter(tester).shouldRepaint(atStart), isTrue);

        await tester.pumpWidget(
          buildWidget(audio: _createTestAudio(), isLoading: true),
        );
        await tester.pump();
        await tester.pump(VineTheme.defaultAnimationDuration);

        await tester.pumpWidget(buildWidget(audio: _createTestAudio()));
        await tester.pump();
        await tester.pump(VineTheme.defaultAnimationDuration);

        expect(progressPainter(tester).shouldRepaint(atStart), isFalse);
      });

      testWidgets('rewinds when playback restarts at the beginning', (
        tester,
      ) async {
        await tester.pumpWidget(buildWidget(audio: _createTestAudio()));
        await tester.pump();
        final atStart = progressPainter(tester);

        await emitPosition(tester, const Duration(milliseconds: 500));
        expect(progressPainter(tester).shouldRepaint(atStart), isTrue);

        await emitPosition(tester, Duration.zero);
        expect(progressPainter(tester).shouldRepaint(atStart), isFalse);
      });
    });

    group('Loading state', () {
      testWidgets('shows loading indicator instead of play control', (
        tester,
      ) async {
        await tester.pumpWidget(
          buildWidget(audio: _createTestAudio(title: 'Track'), isLoading: true),
        );
        await tester.pump();

        final l10n = lookupAppLocalizations(const Locale('en'));
        expect(find.byType(BrandedLoadingIndicator), findsOneWidget);
        expect(
          find.bySemanticsLabel(l10n.videoEditorAudioPlayPreviewSemanticLabel),
          findsNothing,
        );
      });
    });
  });
}
