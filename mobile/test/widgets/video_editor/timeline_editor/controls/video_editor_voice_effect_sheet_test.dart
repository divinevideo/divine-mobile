// ABOUTME: Widget tests for VideoEditorVoiceEffectSheet: what it offers, that
// ABOUTME: it auditions picks, what it pops, and how it shows a failed take.

import 'dart:async';

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart' show AudioEvent, VoiceEffect;
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/voice_over_effect_providers.dart';
import 'package:openvine/services/video_editor/voice_over_effect_service.dart';
import 'package:openvine/widgets/branded_loading_indicator.dart';
import 'package:openvine/widgets/video_editor/timeline_editor/controls/animation_picker_components.dart';
import 'package:openvine/widgets/video_editor/timeline_editor/controls/video_editor_voice_effect_sheet.dart';
import 'package:sound_service/sound_service.dart';

class _MockVoiceOverEffectService extends Mock
    implements VoiceOverEffectService {}

class _MockAudioClipPlayer extends Mock implements AudioClipPlayer {}

const _take = '/docs/voice_over_recordings/voice_over_1.m4a';
const _processedTake = '/docs/voice_over_recordings/voice_over_1_p-5.wav';

final _recording = AudioEvent(
  id: 'local_import_voice_over_1',
  pubkey: 'local_import',
  createdAt: 1700000000,
  url: _take,
  mimeType: 'audio/mp4',
);

/// Opens the sheet from a base route and keeps what it pops.
class _Harness {
  _Harness(this.service, this.player);

  final VoiceOverEffectService service;
  final AudioClipPlayer player;
  AudioEvent? result;
  bool popped = false;

  Widget build(AudioEvent track) => ProviderScope(
    overrides: [
      voiceOverEffectServiceProvider.overrideWithValue(service),
      voiceOverAuditionPlayerFactoryProvider.overrideWithValue(() => player),
    ],
    child: MaterialApp.router(
      localizationsDelegates: appLocalizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      routerConfig: GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => Scaffold(
              body: TextButton(
                onPressed: () async {
                  result = await VideoEditorVoiceEffectSheet.show(
                    context: context,
                    track: track,
                  );
                  popped = true;
                },
                child: const Text('open'),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

void main() {
  group(VideoEditorVoiceEffectSheet, () {
    final l10n = lookupAppLocalizations(const Locale('en'));
    late _MockVoiceOverEffectService service;
    late _MockAudioClipPlayer player;
    late _Harness harness;

    setUpAll(() {
      registerFallbackValue(VoiceEffect.none);
      registerFallbackValue(const AudioSourceConfig.file(''));
    });

    setUp(() {
      service = _MockVoiceOverEffectService();
      player = _MockAudioClipPlayer();
      when(
        () => player.completionStream,
      ).thenAnswer((_) => const Stream<void>.empty());
      when(() => player.setClip(any())).thenAnswer((_) async {});
      when(() => player.play()).thenAnswer((_) async {});
      when(() => player.stop()).thenAnswer((_) async {});
      when(() => player.dispose()).thenAnswer((_) async {});
      when(
        () => service.renderAudition(
          takePath: any(named: 'takePath'),
          effect: any(named: 'effect'),
          noiseReduction: any(named: 'noiseReduction'),
        ),
      ).thenAnswer((_) async => '/tmp/audition.wav');
      when(() => service.discardAudition(any())).thenAnswer((_) async {});
      when(() => service.clearAuditions()).thenAnswer((_) async {});
      harness = _Harness(service, player);
    });

    Future<void> open(WidgetTester tester, [AudioEvent? track]) async {
      await tester.pumpWidget(harness.build(track ?? _recording));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
    }

    Future<void> tapDone(WidgetTester tester) => tester.tap(
      find.byWidgetPredicate(
        (w) =>
            w is DivineIconButton &&
            w.semanticLabel == l10n.videoEditorDoneLabel,
      ),
    );

    DivineSlider slider(WidgetTester tester, String label) => tester
        .widgetList<DivineSlider>(find.byType(DivineSlider))
        .singleWhere((slider) => slider.semanticLabel == label);

    Finder preset(String label) => find.descendant(
      of: find.byWidgetPredicate(
        (w) =>
            w is SingleChildScrollView && w.scrollDirection == Axis.horizontal,
      ),
      matching: find.text(label),
    );

    group('renders', () {
      testWidgets('every preset in one row that scrolls sideways', (
        tester,
      ) async {
        await open(tester);

        for (final label in [
          l10n.videoEditorVoiceEffectOriginal,
          l10n.videoEditorVoiceEffectHighPitch,
          l10n.videoEditorVoiceEffectLowPitch,
          l10n.videoEditorVoiceEffectRobot,
          l10n.videoEditorVoiceEffectEcho,
        ]) {
          expect(preset(label), findsOneWidget);
        }
      });

      testWidgets('the setting the track plays, on presets and sliders', (
        tester,
      ) async {
        await open(
          tester,
          _recording.copyWith(
            url: _processedTake,
            voiceEffect: const VoiceEffect(pitch: -5),
            originalUrl: _take,
          ),
        );

        expect(
          tester.getSemantics(
            find.bySemanticsLabel(l10n.videoEditorVoiceEffectLowPitch),
          ),
          isSemantics(isButton: true, isSelected: true),
        );
        expect(
          tester.getSemantics(
            find.bySemanticsLabel(l10n.videoEditorVoiceEffectOriginal),
          ),
          isSemantics(isButton: true, isSelected: false),
        );
        expect(slider(tester, l10n.videoEditorVoiceEffectPitch).value, -5);
        expect(find.text('-5'), findsOneWidget);
      });
    });

    group('interactions', () {
      testWidgets('loops the take as soon as the sheet opens', (tester) async {
        await open(tester);

        final config =
            verify(() => player.setClip(captureAny())).captured.single
                as AudioSourceConfig;
        expect(config.uri, _take);
        verify(() => player.play()).called(1);
      });

      testWidgets('auditions a slider setting once it is let go', (
        tester,
      ) async {
        await open(tester);

        slider(tester, l10n.videoEditorVoiceEffectEcho).onChanged!(40);
        await tester.pumpAndSettle();
        expect(
          find.text('40%'),
          findsOneWidget,
        );
        verifyNever(
          () => service.renderAudition(
            takePath: any(named: 'takePath'),
            effect: any(named: 'effect'),
            noiseReduction: any(named: 'noiseReduction'),
          ),
        );

        slider(tester, l10n.videoEditorVoiceEffectEcho).onChangeEnd!(40);
        await tester.pumpAndSettle();

        verify(
          () => service.renderAudition(
            takePath: _take,
            effect: const VoiceEffect(echo: 40),
            noiseReduction: false,
          ),
        ).called(1);
        expect(
          tester.getSemantics(
            find.bySemanticsLabel(l10n.videoEditorVoiceEffectOriginal),
          ),
          isSemantics(isButton: true, isSelected: false),
        );
      });

      testWidgets('pops the processed track once the take is processed', (
        tester,
      ) async {
        final processing = Completer<ProcessedVoiceOverTake>();
        when(
          () => service.process(
            takePath: _take,
            effect: const VoiceEffect(pitch: -5),
            noiseReduction: true,
          ),
        ).thenAnswer((_) => processing.future);
        await open(tester);

        await tester.tap(preset(l10n.videoEditorVoiceEffectLowPitch));
        await tester.pumpAndSettle();
        await tester.tap(find.text(l10n.videoEditorVoiceEffectNoiseReduction));
        await tester.pumpAndSettle();
        await tapDone(tester);
        await tester.pump();

        expect(find.byType(BrandedLoadingIndicator), findsOneWidget);
        expect(harness.popped, isFalse);

        processing.complete((path: _processedTake, mimeType: 'audio/wav'));
        await tester.pumpAndSettle();

        expect(harness.popped, isTrue);
        expect(harness.result?.url, _processedTake);
        expect(harness.result?.voiceEffect, const VoiceEffect(pitch: -5));
        expect(harness.result?.noiseReduction, isTrue);
        expect(harness.result?.originalUrl, _take);
      });

      testWidgets('can cancel with the barrier before saving', (tester) async {
        await open(tester);

        // The fixed-height sheet leaves this corner inside the modal barrier.
        await tester.tapAt(const Offset(5, 5));
        await tester.pumpAndSettle();

        expect(harness.popped, isTrue);
        expect(harness.result, isNull);
      });

      testWidgets('cannot cancel or change settings while saving', (
        tester,
      ) async {
        final processing = Completer<ProcessedVoiceOverTake>();
        when(
          () => service.process(
            takePath: any(named: 'takePath'),
            effect: any(named: 'effect'),
            noiseReduction: any(named: 'noiseReduction'),
          ),
        ).thenAnswer((_) => processing.future);
        await open(tester);
        await tester.tap(preset(l10n.videoEditorVoiceEffectLowPitch));
        await tester.pumpAndSettle();
        await tapDone(tester);
        await tester.pump();

        final cancel = tester.widget<DivineIconButton>(
          find.byWidgetPredicate(
            (w) =>
                w is DivineIconButton && w.semanticLabel == l10n.commonCancel,
          ),
        );
        expect(cancel.onPressed, isNull);
        for (final control in tester.widgetList<DivineSlider>(
          find.byType(DivineSlider),
        )) {
          expect(control.onChanged, isNull);
          expect(control.onChangeEnd, isNull);
        }
        for (final chip in tester.widgetList<AnimationPickerChip>(
          find.byType(AnimationPickerChip),
        )) {
          expect(chip.onTap, isNull);
        }
        // The fixed-height sheet leaves this corner inside the modal barrier.
        await tester.tapAt(const Offset(5, 5));
        await tester.pump(const Duration(milliseconds: 300));
        expect(harness.popped, isFalse);
        await tester.drag(find.byType(BottomSheet), const Offset(0, 500));
        await tester.pump(const Duration(milliseconds: 300));
        expect(harness.popped, isFalse);
        await tester.binding.handlePopRoute();
        await tester.pump(const Duration(milliseconds: 300));
        expect(harness.popped, isFalse);

        processing.complete((path: _processedTake, mimeType: 'audio/wav'));
        await tester.pumpAndSettle();
        expect(harness.result?.url, _processedTake);
      });

      testWidgets('pops nothing when the pick is what the track plays', (
        tester,
      ) async {
        await open(tester);

        await tapDone(tester);
        await tester.pumpAndSettle();

        expect(harness.popped, isTrue);
        expect(harness.result, isNull);
      });

      testWidgets('stays open and says so when the take cannot be processed', (
        tester,
      ) async {
        when(
          () => service.process(
            takePath: any(named: 'takePath'),
            effect: any(named: 'effect'),
            noiseReduction: any(named: 'noiseReduction'),
          ),
        ).thenThrow(const VoiceOverEffectException('decode failed'));
        await open(tester);

        await tester.tap(preset(l10n.videoEditorVoiceEffectEcho));
        await tester.pumpAndSettle();
        await tapDone(tester);
        await tester.pumpAndSettle();

        expect(harness.popped, isFalse);
        expect(find.text(l10n.videoEditorVoiceEffectFailed), findsOneWidget);
      });
    });
  });
}
