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
import 'package:openvine/models/sound_cover.dart';
import 'package:openvine/widgets/audio/sound_cover_image.dart';
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
      Locale? locale,
    }) {
      return MaterialApp(
        locale: locale,
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

    group('on a small phone', () {
      Future<void> pumpAt(
        WidgetTester tester, {
        required double textScale,
        Locale locale = const Locale('en'),
      }) async {
        tester.view
          ..physicalSize = const Size(375, 667)
          ..devicePixelRatio = 1;
        tester.platformDispatcher.textScaleFactorTestValue = textScale;
        addTearDown(() {
          tester.view.reset();
          tester.platformDispatcher.clearAllTestValues();
        });
        await tester.pumpWidget(
          buildWidget(
            audio: _createTestAudio(title: 'Sommerabend am See'),
            locale: locale,
          ),
        );
        await tester.pump();
      }

      Rect useButton(WidgetTester tester) =>
          tester.getRect(find.byType(DivineButton));
      Rect playButton(WidgetTester tester) =>
          tester.getRect(find.byType(DivineIconButton));

      testWidgets('keeps Use beside the sound at the normal text size', (
        tester,
      ) async {
        await pumpAt(tester, textScale: 1);

        expect(
          useButton(tester).center.dy,
          moreOrLessEquals(playButton(tester).center.dy),
        );
        expect(useButton(tester).left, greaterThan(playButton(tester).right));
      });

      testWidgets('moves a long Use label to a row of its own at a large '
          'text size', (tester) async {
        await pumpAt(tester, textScale: 2, locale: const Locale('de'));

        expect(
          useButton(tester).top,
          greaterThan(playButton(tester).bottom),
        );
        // Across the card, from the cover to the play button.
        expect(
          useButton(tester).left,
          moreOrLessEquals(tester.getRect(find.byType(SoundCoverImage)).left),
        );
        expect(
          useButton(tester).right,
          moreOrLessEquals(playButton(tester).right),
        );
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
      double ringOpacity(WidgetTester tester) => tester
          .widget<FadeTransition>(
            find
                .ancestor(
                  of: find.byType(DivineCircularProgressIndicator),
                  matching: find.byType(FadeTransition),
                )
                .first,
          )
          .opacity
          .value;

      testWidgets('shows pause with a ring around it while the sound loads', (
        tester,
      ) async {
        await tester.pumpWidget(
          buildWidget(audio: _createTestAudio(title: 'Track'), isLoading: true),
        );
        await tester.pump(const Duration(milliseconds: 400));

        final l10n = lookupAppLocalizations(const Locale('en'));
        expect(ringOpacity(tester), 1);
        expect(
          find.bySemanticsLabel(l10n.videoEditorAudioPausePreviewSemanticLabel),
          findsOneWidget,
        );
      });

      testWidgets('keeps the ring hidden through a load that ends at once', (
        tester,
      ) async {
        final audio = _createTestAudio(title: 'Track');
        // The card shows as the sound is picked, and its file starts loading
        // right after.
        await tester.pumpWidget(buildWidget(audio: audio));
        await tester.pumpWidget(buildWidget(audio: audio, isLoading: true));
        await tester.pump(const Duration(milliseconds: 150));

        expect(ringOpacity(tester), 0);

        await tester.pumpWidget(buildWidget(audio: audio));
        await tester.pump(const Duration(milliseconds: 300));

        expect(find.byType(DivineCircularProgressIndicator), findsNothing);
      });

      testWidgets('ignores taps on play while the sound loads', (
        tester,
      ) async {
        var toggled = false;
        await tester.pumpWidget(
          buildWidget(
            audio: _createTestAudio(title: 'Track'),
            onTogglePlayState: () => toggled = true,
            isLoading: true,
          ),
        );
        await tester.pump();

        final l10n = lookupAppLocalizations(const Locale('en'));
        await tester.tap(
          find.bySemanticsLabel(l10n.videoEditorAudioPausePreviewSemanticLabel),
          warnIfMissed: false,
        );
        await tester.pump();

        expect(toggled, isFalse);
      });

      testWidgets('keeps its size and layout once the sound has loaded', (
        tester,
      ) async {
        final audio = _createTestAudio(title: 'Track');
        final l10n = lookupAppLocalizations(const Locale('en'));
        final card = find.byType(AudioEditorSelectionOverlay);
        final use = find.text(l10n.videoEditorAudioUseSound);
        await tester.pumpWidget(buildWidget(audio: audio, isLoading: true));
        await tester.pump();
        final loadingCard = tester.getSize(card);
        final loadingUse = tester.getRect(use);

        await tester.pumpWidget(buildWidget(audio: audio));
        await tester.pump(const Duration(milliseconds: 300));

        expect(find.byType(DivineCircularProgressIndicator), findsNothing);
        expect(tester.getSize(card), loadingCard);
        expect(tester.getRect(use), loadingUse);
      });
    });
  });
}
