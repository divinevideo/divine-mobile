// ABOUTME: Tests for AudioEditorSelectionOverlay widget
// ABOUTME: Validates rendering of audio metadata, play/pause toggle, and done.

import 'dart:async';
import 'dart:ui' show Tristate;

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/constants/semantic_ids.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/sound_cover.dart';
import 'package:openvine/widgets/audio/sound_cover_image.dart';
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
      SoundCover? cover,
      bool isLoading = false,
    }) {
      return MaterialApp(
        localizationsDelegates: appLocalizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: AudioEditorSelectionOverlay(
            audio: audio,
            cover: cover,
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

      testWidgets("leads with the cover of the sound's row", (tester) async {
        const cover = SoundCover(imageUrl: 'https://media.divine.video/cover');
        await tester.pumpWidget(
          buildWidget(
            audio: _createTestAudio(title: 'My Track'),
            cover: cover,
          ),
        );
        await tester.pump();

        final image = tester.widget<SoundCoverImage>(
          find.byType(SoundCoverImage),
        );
        expect(image.cover, cover);
        expect(image.colorSeed, 'sound-id');
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

      testWidgets('calls onTapDone when Use is tapped', (tester) async {
        var done = false;
        await tester.pumpWidget(
          buildWidget(
            audio: _createTestAudio(title: 'Track'),
            onTapDone: () => done = true,
          ),
        );
        await tester.pump();

        final l10n = lookupAppLocalizations(const Locale('en'));
        await tester.tap(find.text(l10n.videoEditorAudioUseSound));
        await tester.pump();

        expect(done, isTrue);
      });

      testWidgets('disables Use while audio is loading', (tester) async {
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
          find.text(l10n.videoEditorAudioUseSound),
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

    group('Progress line', () {
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

      double progress(WidgetTester tester) => tester
          .widget<FractionallySizedBox>(
            find.descendant(
              of: find.byKey(const Key('audio_selection_progress')),
              matching: find.byType(FractionallySizedBox),
            ),
          )
          .widthFactor!;

      Future<void> emitPosition(WidgetTester tester, Duration position) async {
        positionController.add(position);
        await tester.idle();
        await tester.pump();
      }

      // just_audio advances the position from the moment play() is requested,
      // while the platform reports the true, smaller, position once it
      // actually starts rendering audio. Drawing that correction would wind
      // the line back at the start of every preview.
      testWidgets('holds while the player corrects the position backwards', (
        tester,
      ) async {
        await tester.pumpWidget(buildWidget(audio: _createTestAudio()));
        await tester.pump();

        await emitPosition(tester, const Duration(milliseconds: 500));
        expect(progress(tester), 0.05);

        await emitPosition(tester, const Duration(milliseconds: 200));
        expect(progress(tester), 0.05);

        await emitPosition(tester, const Duration(milliseconds: 800));
        expect(progress(tester), 0.08);
      });

      testWidgets('starts over when the preview loops', (tester) async {
        await tester.pumpWidget(buildWidget(audio: _createTestAudio()));
        await tester.pump();

        await emitPosition(tester, const Duration(milliseconds: 9500));
        expect(progress(tester), 0.95);

        await emitPosition(tester, const Duration(milliseconds: 200));
        expect(progress(tester), 0.02);
      });

      testWidgets('starts over when playback is back at the beginning', (
        tester,
      ) async {
        await tester.pumpWidget(buildWidget(audio: _createTestAudio()));
        await tester.pump();

        await emitPosition(tester, const Duration(milliseconds: 500));
        expect(progress(tester), 0.05);

        await emitPosition(tester, Duration.zero);
        expect(progress(tester), 0);
      });

      testWidgets('is empty while the next sound loads', (tester) async {
        await tester.pumpWidget(buildWidget(audio: _createTestAudio()));
        await tester.pump();
        await emitPosition(tester, const Duration(seconds: 5));
        expect(progress(tester), 0.5);

        await tester.pumpWidget(
          buildWidget(audio: _createTestAudio(), isLoading: true),
        );
        await tester.pump();
        expect(progress(tester), 0);

        await tester.pumpWidget(buildWidget(audio: _createTestAudio()));
        await tester.pump();
        expect(progress(tester), 0);
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
