// ABOUTME: Widget tests for the captions editor bottom sheet.
// ABOUTME: Covers generation states, cue editing, and the confirm result.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/blocs/video_editor/captions_editor/captions_editor_cubit.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/models/video_editor/caption_track.dart';
import 'package:openvine/services/video_editor/caption_generation_service.dart';
import 'package:openvine/widgets/video_editor/timeline_editor/controls/video_editor_captions_sheet.dart';

class _MockCaptionGenerationService extends Mock
    implements CaptionGenerationService {}

void main() {
  final l10n = lookupAppLocalizations(const Locale('en'));

  late _MockCaptionGenerationService service;

  setUp(() {
    service = _MockCaptionGenerationService();
  });

  void stubOutcome(CaptionGenerationOutcome outcome) {
    when(
      () => service.generateForClips(
        clips: any(named: 'clips'),
        localeIdentifier: any(named: 'localeIdentifier'),
      ),
    ).thenAnswer((_) async => outcome);
  }

  Widget buildHost({
    bool burnIn = false,
    List<CaptionCue>? initialCues,
    void Function(CaptionsEditorResult?)? onResult,
    ThemeData? theme,
  }) {
    return MaterialApp(
      theme: theme,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(
        builder: (context) => Center(
          child: ElevatedButton(
            onPressed: () async {
              final result = await showCaptionsEditorSheet(
                context,
                burnIn: burnIn,
                presetId: 'classic',
                languageTag: 'en-US',
                clips: const [],
                totalDuration: const Duration(seconds: 6),
                initialCues: initialCues,
                cubit: CaptionsEditorCubit(
                  clips: const [],
                  totalDuration: const Duration(seconds: 6),
                  burnIn: burnIn,
                  presetId: 'classic',
                  languageTag: 'en-US',
                  initialCues: initialCues,
                  generationService: service,
                ),
              );
              onResult?.call(result);
            },
            child: const Text('open'),
          ),
        ),
      ),
    );
  }

  Future<void> open(WidgetTester tester) async {
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  group('showCaptionsEditorSheet', () {
    testWidgets('shows generated cues after transcription', (tester) async {
      stubOutcome(
        const CaptionsGenerated([
          CaptionCue(
            id: 'cue-0',
            text: 'Hello world.',
            start: Duration.zero,
            end: Duration(seconds: 1),
          ),
        ]),
      );

      await tester.pumpWidget(buildHost());
      await open(tester);

      expect(find.text('Hello world.'), findsOneWidget);
    });

    testWidgets(
      'failure state offers writing captions manually',
      (tester) async {
        stubOutcome(
          const CaptionsFailed(CaptionGenerationFailure.recognizerUnavailable),
        );

        await tester.pumpWidget(buildHost());
        await open(tester);

        expect(
          find.text(l10n.videoEditorCaptionsUnavailableMessage),
          findsOneWidget,
        );

        await tester.tap(find.text(l10n.videoEditorCaptionsStartEmptyButton));
        await tester.pumpAndSettle();

        expect(find.text(l10n.videoEditorCaptionsAddCue), findsOneWidget);
      },
    );

    testWidgets(
      'confirm pops the edited cues and drops cleared ones',
      (tester) async {
        CaptionsEditorResult? result;
        await tester.pumpWidget(
          buildHost(
            initialCues: const [
              CaptionCue(
                id: 'cue-0',
                text: 'Keep me.',
                start: Duration.zero,
                end: Duration(seconds: 1),
              ),
              CaptionCue(
                id: 'cue-1',
                text: 'Clear me.',
                start: Duration(seconds: 2),
                end: Duration(seconds: 3),
              ),
            ],
            onResult: (r) => result = r,
          ),
        );
        await open(tester);

        await tester.enterText(
          find.widgetWithText(TextField, 'Clear me.'),
          '   ',
        );
        await tester.tap(
          find.bySemanticsLabel(l10n.videoEditorCaptionsDoneSemanticLabel),
        );
        await tester.pumpAndSettle();

        final confirmed = result! as CaptionsConfirmed;
        expect(confirmed.cues.map((c) => c.text), equals(['Keep me.']));
        expect(confirmed.track.burnIn, isFalse);
        expect(confirmed.track.cues.map((c) => c.id), equals(['cue-0']));
      },
    );

    testWidgets(
      'editing a cue time via the slider commits the new range',
      (tester) async {
        CaptionsEditorResult? result;
        await tester.pumpWidget(
          buildHost(
            initialCues: const [
              CaptionCue(
                id: 'cue-0',
                text: 'Hello.',
                start: Duration.zero,
                end: Duration(seconds: 1),
              ),
              CaptionCue(
                id: 'cue-1',
                text: 'World.',
                start: Duration(seconds: 2),
                end: Duration(seconds: 3),
              ),
            ],
            onResult: (r) => result = r,
          ),
        );
        await open(tester);

        // The slider spans the whole video; extending cue-0 past the next
        // cue is allowed (cues may overlap), so the value is applied as-is.
        final slider = tester.widget<RangeSlider>(
          find.byType(RangeSlider).first,
        );
        slider.onChanged!(const RangeValues(0, 5));
        await tester.pumpAndSettle();

        await tester.tap(
          find.bySemanticsLabel(l10n.videoEditorCaptionsDoneSemanticLabel),
        );
        await tester.pumpAndSettle();

        final confirmed = result! as CaptionsConfirmed;
        expect(
          confirmed.cues.first.end,
          equals(const Duration(seconds: 5)),
        );
      },
    );

    testWidgets('existing session skips generation', (tester) async {
      await tester.pumpWidget(
        buildHost(
          initialCues: const [
            CaptionCue(
              id: 'cue-0',
              text: 'Existing.',
              start: Duration.zero,
              end: Duration(seconds: 1),
            ),
          ],
        ),
      );
      await open(tester);

      expect(find.text('Existing.'), findsOneWidget);
      verifyNever(
        () => service.generateForClips(
          clips: any(named: 'clips'),
          localeIdentifier: any(named: 'localeIdentifier'),
        ),
      );
    });

    testWidgets('cue chrome follows the light palette', (tester) async {
      await tester.pumpWidget(
        buildHost(
          theme: VineTheme.lightTheme,
          initialCues: const [
            CaptionCue(
              id: 'cue-0',
              text: 'Existing.',
              start: Duration.zero,
              end: Duration(seconds: 1),
            ),
          ],
        ),
      );
      await open(tester);

      // The sheet body is `lightColors.surface` (#FFFFFF). A cue timestamp
      // or input surface still pinned to its dark constant renders at
      // 1.92:1 / 1.09:1 against it — readable only in dark mode.
      final timestamp = tester.widget<Text>(find.text('0.0s'));
      expect(
        timestamp.style?.color,
        equals(VineTheme.lightColors.secondaryText),
      );

      final inputSurface = tester.widget<DecoratedBox>(
        find
            .ancestor(
              of: find.byType(DivineTextField),
              matching: find.byType(DecoratedBox),
            )
            .first,
      );
      expect(
        (inputSurface.decoration as BoxDecoration).color,
        equals(VineTheme.lightColors.containerLow),
      );
    });
  });
}
