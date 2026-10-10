// ABOUTME: Widget tests for VideoEditorEqualizerSheet.
// ABOUTME: Covers presets, the band curve, live changes and confirm/cancel.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/gestures.dart'
    show kDoubleTapMinTime, kDoubleTapTimeout;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:models/models.dart' show EqualizerSettings;
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/video_editor/equalizer_preset.dart';
import 'package:openvine/widgets/video_editor/timeline_editor/controls/video_editor_equalizer_sheet.dart';

/// Opens the sheet from a base route and keeps what it pops and reports.
class _Harness {
  EqualizerSettings? result;
  bool popped = false;
  final changes = <EqualizerSettings>[];

  Widget build(EqualizerSettings initial) {
    return MaterialApp.router(
      localizationsDelegates: appLocalizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      routerConfig: GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => Scaffold(
              body: TextButton(
                onPressed: () async {
                  result = await context.push<EqualizerSettings>('/eq');
                  popped = true;
                },
                child: const Text('open'),
              ),
            ),
            routes: [
              GoRoute(
                path: 'eq',
                builder: (context, state) => Scaffold(
                  body: VideoEditorEqualizerSheet(
                    initial: initial,
                    onChanged: changes.add,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

Future<_Harness> _open(
  WidgetTester tester, {
  EqualizerSettings initial = EqualizerSettings.none,
}) async {
  final harness = _Harness();
  await tester.pumpWidget(harness.build(initial));
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  return harness;
}

AppLocalizations _l10n(WidgetTester tester) =>
    AppLocalizations.of(tester.element(find.byType(VideoEditorEqualizerSheet)));

/// The labels the bands' points carry, lowest band first.
List<String> _bandLabels(AppLocalizations l10n) => [
  for (final hertz in const ['31', '62', '125', '250', '500'])
    l10n.videoEditorEqualizerHertz(hertz),
  for (final kilohertz in const ['1', '2', '4', '8', '16'])
    l10n.videoEditorEqualizerKilohertz(kilohertz),
];

String _signed(AppLocalizations l10n, int gain) =>
    l10n.videoEditorEqualizerGainValue(gain > 0 ? '+$gain' : '$gain');

void main() {
  group(VideoEditorEqualizerSheet, () {
    group('renders', () {
      testWidgets('the title, every preset and every band', (tester) async {
        await _open(tester);
        final l10n = _l10n(tester);

        expect(find.text(l10n.videoEditorEqualizerSheetTitle), findsOneWidget);
        expect(find.text(l10n.videoEditorVoiceEffectOriginal), findsOneWidget);
        expect(find.text(l10n.videoEditorEqualizerVoice), findsOneWidget);
        expect(find.text(l10n.videoEditorEqualizerBassy), findsOneWidget);
        expect(find.text(l10n.videoEditorEqualizerBright), findsOneWidget);
        for (final label in _bandLabels(l10n)) {
          expect(find.bySemanticsLabel(label), findsOneWidget, reason: label);
        }
        expect(find.text('31'), findsOneWidget);
        expect(
          find.text(l10n.videoEditorEqualizerKilohertzShort('16')),
          findsOneWidget,
        );
        expect(find.text(l10n.videoEditorEqualizerCurveHint), findsOneWidget);
      });

      testWidgets('the gains it starts with, signed, in decibels', (
        tester,
      ) async {
        await _open(
          tester,
          initial: const EqualizerSettings([0, 4, 0, -3, 0, 0, 0, 0, 0, 0]),
        );
        final l10n = _l10n(tester);

        expect(
          tester
              .getSemantics(find.bySemanticsLabel(_bandLabels(l10n)[3]))
              .value,
          _signed(l10n, -3),
        );
        expect(
          tester
              .getSemantics(find.bySemanticsLabel(_bandLabels(l10n)[1]))
              .value,
          _signed(l10n, 4),
        );
      });
    });

    group('interactions', () {
      testWidgets('a preset is reported at once and moves the points', (
        tester,
      ) async {
        final harness = await _open(tester);
        final l10n = _l10n(tester);

        await tester.tap(find.text(l10n.videoEditorEqualizerVoice));
        await tester.pump();

        expect(harness.changes, [EqualizerPreset.voice.settings]);
        expect(
          tester
              .getSemantics(find.bySemanticsLabel(_bandLabels(l10n).first))
              .value,
          _signed(l10n, EqualizerPreset.voice.settings.gains.first),
        );
      });

      testWidgets("dragging a band's point up raises only that band", (
        tester,
      ) async {
        final harness = await _open(tester);
        final l10n = _l10n(tester);
        final column = tester.getRect(
          find.bySemanticsLabel(_bandLabels(l10n)[1]),
        );

        await tester.dragFrom(column.center, Offset(0, -column.height));
        // Lets the point's double-tap detector give up on a second tap.
        await tester.pump(kDoubleTapTimeout);

        expect(
          harness.changes.last,
          EqualizerSettings.none.withGain(1, EqualizerSettings.maxGain),
        );
        // The readout names the point and its new gain.
        expect(find.text(_bandLabels(l10n)[1]), findsOneWidget);
        expect(
          find.text(_signed(l10n, EqualizerSettings.maxGain)),
          findsOneWidget,
        );
        expect(find.text(l10n.videoEditorEqualizerCurveHint), findsNothing);
      });

      testWidgets("dragging a band's point down lowers it", (tester) async {
        final harness = await _open(tester);
        final l10n = _l10n(tester);
        final column = tester.getRect(
          find.bySemanticsLabel(_bandLabels(l10n)[3]),
        );

        await tester.dragFrom(column.center, Offset(0, column.height));
        await tester.pump(kDoubleTapTimeout);

        expect(
          harness.changes.last,
          EqualizerSettings.none.withGain(3, EqualizerSettings.minGain),
        );
      });

      testWidgets("a tap picks a band and the readout's buttons step it", (
        tester,
      ) async {
        final harness = await _open(tester);
        final l10n = _l10n(tester);
        final label = _bandLabels(l10n)[3];

        await tester.tap(find.bySemanticsLabel(label));
        // A tap waits out the double tap it could still become.
        await tester.pump(kDoubleTapTimeout);
        expect(harness.changes, isEmpty);
        expect(find.text(label), findsOneWidget);

        await tester.tap(
          find.bySemanticsLabel(l10n.videoEditorEqualizerRaiseBand(label)),
        );
        await tester.pump();
        await tester.tap(
          find.bySemanticsLabel(l10n.videoEditorEqualizerRaiseBand(label)),
        );
        await tester.pump();
        await tester.tap(
          find.bySemanticsLabel(l10n.videoEditorEqualizerLowerBand(label)),
        );
        await tester.pump();

        expect(harness.changes, [
          EqualizerSettings.none.withGain(3, 1),
          EqualizerSettings.none.withGain(3, 2),
          EqualizerSettings.none.withGain(3, 1),
        ]);
      });

      testWidgets('a band at the end of its range cannot be stepped past it', (
        tester,
      ) async {
        await _open(
          tester,
          initial: EqualizerSettings.none.withGain(
            0,
            EqualizerSettings.maxGain,
          ),
        );
        final l10n = _l10n(tester);
        final label = _bandLabels(l10n).first;

        await tester.tap(find.bySemanticsLabel(label));
        await tester.pump(kDoubleTapTimeout);

        final raise = tester.widget<DivineIconButton>(
          find.ancestor(
            of: find.bySemanticsLabel(
              l10n.videoEditorEqualizerRaiseBand(label),
            ),
            matching: find.byType(DivineIconButton),
          ),
        );
        expect(raise.onPressed, isNull);
      });

      testWidgets('a double tap puts a band back to zero', (tester) async {
        final harness = await _open(
          tester,
          initial: const EqualizerSettings([0, 0, 7, 0, 0, 0, 0, 0, 0, 0]),
        );
        final l10n = _l10n(tester);
        final band = find.bySemanticsLabel(_bandLabels(l10n)[2]);

        await tester.tap(band);
        await tester.pump(kDoubleTapMinTime);
        await tester.tap(band);
        await tester.pumpAndSettle();

        expect(harness.changes, [EqualizerSettings.none]);
      });

      testWidgets('a screen reader raises and lowers a band a decibel at a '
          'time', (tester) async {
        final harness = await _open(
          tester,
          initial: const EqualizerSettings([0, 0, 0, 0, 2, 0, 0, 0, 0, 0]),
        );
        final l10n = _l10n(tester);
        final band = find.semantics.byLabel(_bandLabels(l10n)[4]);

        tester.semantics.increase(band);
        await tester.pump();
        tester.semantics.decrease(band);
        await tester.pump();

        expect(harness.changes, [
          const EqualizerSettings([0, 0, 0, 0, 3, 0, 0, 0, 0, 0]),
          const EqualizerSettings([0, 0, 0, 0, 2, 0, 0, 0, 0, 0]),
        ]);
      });

      testWidgets('confirm pops the settings', (tester) async {
        final harness = await _open(tester);
        final l10n = _l10n(tester);
        await tester.tap(find.text(l10n.videoEditorEqualizerBassy));
        await tester.pump();

        await tester.tap(find.bySemanticsLabel(l10n.videoEditorDoneLabel));
        await tester.pumpAndSettle();

        expect(harness.popped, isTrue);
        expect(harness.result, EqualizerPreset.bassy.settings);
      });

      testWidgets('cancel pops nothing', (tester) async {
        final harness = await _open(tester);
        final l10n = _l10n(tester);
        await tester.tap(find.text(l10n.videoEditorEqualizerBright));
        await tester.pump();

        await tester.tap(find.bySemanticsLabel(l10n.commonCancel));
        await tester.pumpAndSettle();

        expect(harness.popped, isTrue);
        expect(harness.result, isNull);
      });
    });
  });
}
