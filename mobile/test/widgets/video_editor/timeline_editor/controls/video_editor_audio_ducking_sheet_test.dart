// ABOUTME: Widget tests for VideoEditorAudioDuckingSheet.
// ABOUTME: Covers the hint without a voice-over, the strength slider and results.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/widgets/video_editor/timeline_editor/controls/video_editor_audio_ducking_sheet.dart';

/// Opens the sheet from a base route and keeps what it pops.
class _Harness {
  AudioDuckingSelection? result;
  bool popped = false;

  Widget build({
    required bool initialEnabled,
    required double initialVolume,
    required bool hasVoiceOver,
    Locale? locale,
    double textScale = 1,
  }) {
    return MaterialApp.router(
      locale: locale,
      localizationsDelegates: appLocalizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      routerConfig: GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => Scaffold(
              body: TextButton(
                onPressed: () async {
                  result = await context.push<AudioDuckingSelection>('/duck');
                  popped = true;
                },
                child: const Text('open'),
              ),
            ),
            routes: [
              GoRoute(
                path: 'duck',
                // On a ColoredBox like VineBottomSheet's body, which hides
                // the Scaffold's Material from the switch tile.
                builder: (context, state) => Scaffold(
                  body: ColoredBox(
                    color: VineTheme.surfaceBackground,
                    child: VideoEditorAudioDuckingSheet(
                      initialEnabled: initialEnabled,
                      initialVolume: initialVolume,
                      hasVoiceOver: hasVoiceOver,
                    ),
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
  bool initialEnabled = false,
  double initialVolume = 0.25,
  bool hasVoiceOver = true,
  Locale? locale,
  double textScale = 1,
}) async {
  final harness = _Harness();
  await tester.pumpWidget(
    harness.build(
      initialEnabled: initialEnabled,
      initialVolume: initialVolume,
      hasVoiceOver: hasVoiceOver,
      locale: locale,
      textScale: textScale,
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  return harness;
}

DivineSlider _slider(WidgetTester tester) =>
    tester.widget<DivineSlider>(find.byType(DivineSlider));

Future<void> _tapIcon(WidgetTester tester, DivineIconName icon) async {
  await tester.tap(
    find.byWidgetPredicate(
      (widget) => widget is DivineIconButton && widget.icon == icon,
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  final l10n = lookupAppLocalizations(const Locale('en'));

  group(VideoEditorAudioDuckingSheet, () {
    group('renders', () {
      testWidgets('explains how to start while there is no voice-over', (
        tester,
      ) async {
        await _open(tester, hasVoiceOver: false);

        expect(
          find.text(l10n.videoEditorDuckingNoVoiceOverHint),
          findsOneWidget,
        );
        expect(find.text(l10n.videoEditorDuckingDescription), findsNothing);
      });

      testWidgets('keeps the strength slider off until ducking is on', (
        tester,
      ) async {
        await _open(tester);
        expect(_slider(tester).onChanged, isNull);

        await tester.tap(find.byType(DivineSwitch));
        await tester.pump();

        expect(_slider(tester).onChanged, isNotNull);
        expect(find.text('75%'), findsOneWidget);
      });
    });

    testWidgets('keeps the percentage on a phone at a large text size', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      // Malay has the longest "How much quieter".
      await _open(tester, locale: const Locale('ms'), textScale: 2);

      expect(tester.takeException(), isNull);
      expect(find.text('75%'), findsOneWidget);
    });

    group('interactions', () {
      testWidgets('confirms ducking at the chosen strength', (tester) async {
        final harness = await _open(tester);

        await tester.tap(find.byType(DivineSwitch));
        await tester.pump();
        _slider(tester).onChanged!(0.9);
        await tester.pump();
        await _tapIcon(tester, DivineIconName.check);

        expect(harness.result?.enabled, isTrue);
        expect(harness.result?.volume, closeTo(0.1, 1e-9));
      });

      testWidgets('cancelling returns nothing', (tester) async {
        final harness = await _open(tester, initialEnabled: true);

        await tester.tap(find.byType(DivineSwitch));
        await tester.pump();
        await _tapIcon(tester, DivineIconName.x);

        expect(harness.popped, isTrue);
        expect(harness.result, isNull);
      });
    });
  });
}
