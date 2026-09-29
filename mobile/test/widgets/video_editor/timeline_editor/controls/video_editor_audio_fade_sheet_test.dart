// ABOUTME: Widget tests for VideoEditorAudioFadeSheet.
// ABOUTME: Covers labels, fitting both fades into the sound, and cancel/confirm results.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/widgets/video_editor/timeline_editor/controls/video_editor_audio_fade_sheet.dart';

/// Opens the sheet from a base route and keeps what it pops.
class _Harness {
  AudioFadeSelection? result;
  bool popped = false;

  Widget build({
    required Duration soundLength,
    Duration initialFadeIn = Duration.zero,
    Duration initialFadeOut = Duration.zero,
  }) {
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
                  result = await context.push<AudioFadeSelection>('/fade');
                  popped = true;
                },
                child: const Text('open'),
              ),
            ),
            routes: [
              GoRoute(
                path: 'fade',
                builder: (context, state) => Scaffold(
                  body: VideoEditorAudioFadeSheet(
                    soundLength: soundLength,
                    initialFadeIn: initialFadeIn,
                    initialFadeOut: initialFadeOut,
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
  Duration soundLength = const Duration(seconds: 6),
  Duration initialFadeIn = Duration.zero,
  Duration initialFadeOut = Duration.zero,
}) async {
  final harness = _Harness();
  await tester.pumpWidget(
    harness.build(
      soundLength: soundLength,
      initialFadeIn: initialFadeIn,
      initialFadeOut: initialFadeOut,
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  return harness;
}

DivineSlider _slider(WidgetTester tester, String label) => tester
    .widgetList<DivineSlider>(find.byType(DivineSlider))
    .singleWhere((slider) => slider.semanticLabel == label);

Future<void> _drag(WidgetTester tester, String label, double seconds) async {
  _slider(tester, label).onChanged!(seconds);
  await tester.pump();
}

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

  group(VideoEditorAudioFadeSheet, () {
    group('renders', () {
      testWidgets('shows the title and a slider per fade', (tester) async {
        await _open(tester);

        expect(find.text(l10n.videoEditorFadeSheetTitle), findsOneWidget);
        expect(find.text(l10n.videoEditorFadeInLabel), findsOneWidget);
        expect(find.text(l10n.videoEditorFadeOutLabel), findsOneWidget);
        expect(
          find.text(
            lookupAppLocalizations(const Locale('de')).videoEditorFadeInLabel,
          ),
          findsNothing,
        );
        expect(find.byType(DivineSlider), findsNWidgets(2));
      });

      testWidgets('shows the initial fades in seconds', (tester) async {
        await _open(
          tester,
          initialFadeIn: const Duration(milliseconds: 500),
          initialFadeOut: const Duration(milliseconds: 1500),
        );

        expect(find.text('0.5s'), findsOneWidget);
        expect(find.text('1.5s'), findsOneWidget);
      });

      testWidgets('lets a fade run the whole length of the sound', (
        tester,
      ) async {
        await _open(
          tester,
          soundLength: const Duration(seconds: 6, milliseconds: 300),
        );

        expect(_slider(tester, l10n.videoEditorFadeInLabel).max, 6.3);
        expect(_slider(tester, l10n.videoEditorFadeOutLabel).max, 6.3);
      });
    });

    group('fitting', () {
      testWidgets('shortens a stored fade out that no longer fits beside the '
          'fade in', (tester) async {
        await _open(
          tester,
          soundLength: const Duration(seconds: 2),
          initialFadeIn: const Duration(milliseconds: 1500),
          initialFadeOut: const Duration(milliseconds: 1500),
        );

        expect(find.text('1.5s'), findsOneWidget);
        expect(find.text('0.5s'), findsOneWidget);
      });

      testWidgets('lengthening one fade shortens the other where they meet', (
        tester,
      ) async {
        final harness = await _open(
          tester,
          soundLength: const Duration(seconds: 4),
          initialFadeOut: const Duration(seconds: 2),
        );

        await _drag(tester, l10n.videoEditorFadeInLabel, 3);
        await _tapIcon(tester, DivineIconName.check);

        expect(harness.result?.fadeIn, const Duration(seconds: 3));
        expect(harness.result?.fadeOut, const Duration(seconds: 1));
      });
    });

    group('interactions', () {
      testWidgets('confirm returns the picked fades', (tester) async {
        final harness = await _open(tester);

        await _drag(tester, l10n.videoEditorFadeInLabel, 0.5);
        await _drag(tester, l10n.videoEditorFadeOutLabel, 2.04);
        await _tapIcon(tester, DivineIconName.check);

        expect(harness.popped, isTrue);
        expect(harness.result?.fadeIn, const Duration(milliseconds: 500));
        // Snapped to the 100 ms slider step.
        expect(harness.result?.fadeOut, const Duration(seconds: 2));
      });

      testWidgets('cancel returns nothing', (tester) async {
        final harness = await _open(
          tester,
          initialFadeIn: const Duration(seconds: 1),
        );

        await _drag(tester, l10n.videoEditorFadeInLabel, 2);
        await _tapIcon(tester, DivineIconName.x);

        expect(harness.popped, isTrue);
        expect(harness.result, isNull);
      });
    });
  });
}
