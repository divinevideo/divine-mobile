// ABOUTME: Widget tests for VideoEditorClipSpeedSheet.
// ABOUTME: Covers rendering, clamping, speed presets and cancel/confirm.

import 'dart:ui' show Tristate;

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/constants/video_editor_constants.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/widgets/video_editor/timeline_editor/controls/video_editor_clip_speed_sheet.dart';

// Sentinel shown on the base route so navigation-back tests can confirm
// that the sheet was popped.
class _HomeScreen extends StatelessWidget {
  const _HomeScreen();

  @override
  Widget build(BuildContext context) => const Scaffold(body: Text('home'));
}

Widget _buildSubject({double initialSpeed = 1.0}) {
  return MaterialApp.router(
    localizationsDelegates: appLocalizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    routerConfig: GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => const _HomeScreen(),
          routes: [
            GoRoute(
              path: 'speed',
              builder: (context, state) => Scaffold(
                body: VideoEditorClipSpeedSheet(initialSpeed: initialSpeed),
              ),
            ),
          ],
        ),
      ],
      initialLocation: '/speed',
    ),
  );
}

/// Opens the sheet from a home route with `push`, so the value the sheet pops
/// reaches [onResult] the way it reaches the timeline clip controls.
Widget _buildPushingSubject({required ValueChanged<double?> onResult}) {
  return MaterialApp.router(
    localizationsDelegates: appLocalizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    routerConfig: GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => Scaffold(
            body: TextButton(
              onPressed: () async =>
                  onResult(await context.push<double>('/speed')),
              child: const Text('open'),
            ),
          ),
          routes: [
            GoRoute(
              path: 'speed',
              builder: (context, state) =>
                  const Scaffold(body: VideoEditorClipSpeedSheet()),
            ),
          ],
        ),
      ],
    ),
  );
}

/// The current-speed readout beside the "Speed" label. Scoped to that row
/// because a preset chip can show the same text (e.g. `0.25×`).
Finder _speedValue(String text) => find.descendant(
  of: find
      .ancestor(
        of: find.text(
          lookupAppLocalizations(const Locale('en')).videoEditorSpeedLabel,
        ),
        matching: find.byType(Row),
      )
      .first,
  matching: find.text(text),
);

/// The preset chip whose accessible name is the preset [label], e.g. `'0.5'`.
Finder _preset(String label) => find.bySemanticsLabel(
  lookupAppLocalizations(
    const Locale('en'),
  ).videoEditorSpeedPresetSemanticLabel(label),
);

/// Every semantics node currently announced as selected.
SemanticsFinder _selectedNodes() => find.semantics.byPredicate(
  (node) =>
      node.getSemanticsData().flagsCollection.isSelected == Tristate.isTrue,
);

void main() {
  group(VideoEditorClipSpeedSheet, () {
    group('renders', () {
      testWidgets('shows sheet title', (tester) async {
        await tester.pumpWidget(_buildSubject());
        await tester.pumpAndSettle();

        final l10n = lookupAppLocalizations(const Locale('en'));
        expect(find.text(l10n.videoEditorSpeedSheetTitle), findsOneWidget);
        expect(
          find.text(
            lookupAppLocalizations(
              const Locale('de'),
            ).videoEditorSpeedSheetTitle,
          ),
          findsNothing,
        );
      });

      testWidgets('shows speed label', (tester) async {
        await tester.pumpWidget(_buildSubject());
        await tester.pumpAndSettle();

        final l10n = lookupAppLocalizations(const Locale('en'));
        expect(find.text(l10n.videoEditorSpeedLabel), findsOneWidget);
      });

      testWidgets('shows formatted initial speed value', (tester) async {
        await tester.pumpWidget(_buildSubject(initialSpeed: 1.5));
        await tester.pumpAndSettle();

        expect(find.text('1.50×'), findsOneWidget);
      });

      testWidgets('shows DivineSlider', (tester) async {
        await tester.pumpWidget(_buildSubject());
        await tester.pumpAndSettle();

        expect(find.byType(DivineSlider), findsOneWidget);
      });

      testWidgets('shows cancel and confirm buttons', (tester) async {
        await tester.pumpWidget(_buildSubject());
        await tester.pumpAndSettle();

        expect(
          find.byWidgetPredicate(
            (widget) =>
                widget is DivineIconButton && widget.icon == DivineIconName.x,
          ),
          findsOneWidget,
        );
        expect(
          find.byWidgetPredicate(
            (widget) =>
                widget is DivineIconButton &&
                widget.icon == DivineIconName.check,
          ),
          findsOneWidget,
        );
      });
    });

    group('initial speed clamping', () {
      testWidgets('clamps below clipSpeedMin to clipSpeedMin', (tester) async {
        await tester.pumpWidget(_buildSubject(initialSpeed: -5));
        await tester.pumpAndSettle();

        final expected =
            '${VideoEditorConstants.clipSpeedMin.toStringAsFixed(2)}×';
        expect(_speedValue(expected), findsOneWidget);
      });

      testWidgets('clamps above clipSpeedMax to clipSpeedMax', (tester) async {
        await tester.pumpWidget(_buildSubject(initialSpeed: 99));
        await tester.pumpAndSettle();

        final expected =
            '${VideoEditorConstants.clipSpeedMax.toStringAsFixed(2)}×';
        expect(_speedValue(expected), findsOneWidget);
      });

      testWidgets('shows exact value at clipSpeedMin boundary', (tester) async {
        await tester.pumpWidget(
          _buildSubject(initialSpeed: VideoEditorConstants.clipSpeedMin),
        );
        await tester.pumpAndSettle();

        final expected =
            '${VideoEditorConstants.clipSpeedMin.toStringAsFixed(2)}×';
        expect(_speedValue(expected), findsOneWidget);
      });

      testWidgets('shows exact value at clipSpeedMax boundary', (tester) async {
        await tester.pumpWidget(
          _buildSubject(initialSpeed: VideoEditorConstants.clipSpeedMax),
        );
        await tester.pumpAndSettle();

        final expected =
            '${VideoEditorConstants.clipSpeedMax.toStringAsFixed(2)}×';
        expect(_speedValue(expected), findsOneWidget);
      });
    });

    group('speed presets', () {
      testWidgets('marks the preset matching the current speed as selected', (
        tester,
      ) async {
        await tester.pumpWidget(_buildSubject(initialSpeed: 0.5));
        await tester.pumpAndSettle();

        expect(
          tester.getSemantics(_preset('0.5')),
          isSemantics(isButton: true, isSelected: true),
        );
        expect(
          tester.getSemantics(_preset('1')),
          isSemantics(isSelected: false),
        );
        expect(_selectedNodes(), findsOne);
      });

      testWidgets('tapping a preset sets the speed and selects it', (
        tester,
      ) async {
        await tester.pumpWidget(_buildSubject());
        await tester.pumpAndSettle();
        expect(
          tester.getSemantics(_preset('1')),
          isSemantics(isSelected: true),
        );

        await tester.tap(find.text('2×'));
        await tester.pump();

        expect(find.text('2.00×'), findsOneWidget);
        expect(
          tester.getSemantics(_preset('2')),
          isSemantics(isSelected: true),
        );
        expect(
          tester.getSemantics(_preset('1')),
          isSemantics(isSelected: false),
        );
      });

      testWidgets('moving the slider off a preset deselects it', (
        tester,
      ) async {
        await tester.pumpWidget(_buildSubject());
        await tester.pumpAndSettle();
        expect(
          tester.getSemantics(_preset('1')),
          isSemantics(isSelected: true),
        );

        // Grabbing the track mid-way lands between presets (~1.6×–1.8×).
        await tester.drag(find.byType(DivineSlider), const Offset(20, 0));
        await tester.pumpAndSettle();

        expect(find.text('1.00×'), findsNothing);
        expect(_selectedNodes(), findsNothing);
      });

      testWidgets('confirming returns the tapped preset', (tester) async {
        double? result;
        await tester.pumpWidget(
          _buildPushingSubject(onResult: (value) => result = value),
        );
        await tester.tap(find.text('open'));
        await tester.pumpAndSettle();

        await tester.tap(find.text('0.5×'));
        await tester.pump();
        await tester.tap(
          find.byWidgetPredicate(
            (widget) =>
                widget is DivineIconButton &&
                widget.icon == DivineIconName.check,
          ),
        );
        await tester.pumpAndSettle();

        expect(result, equals(0.5));
      });
    });

    group('cancel button', () {
      testWidgets('tapping X pops the sheet', (tester) async {
        await tester.pumpWidget(_buildSubject());
        await tester.pumpAndSettle();

        final l10n = lookupAppLocalizations(const Locale('en'));
        expect(find.text(l10n.videoEditorSpeedSheetTitle), findsOneWidget);

        await tester.tap(
          find.byWidgetPredicate(
            (widget) =>
                widget is DivineIconButton && widget.icon == DivineIconName.x,
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('home'), findsOneWidget);
        expect(find.text(l10n.videoEditorSpeedSheetTitle), findsNothing);
      });
    });

    group('confirm button', () {
      testWidgets('tapping check pops the sheet', (tester) async {
        await tester.pumpWidget(_buildSubject());
        await tester.pumpAndSettle();

        final l10n = lookupAppLocalizations(const Locale('en'));
        expect(find.text(l10n.videoEditorSpeedSheetTitle), findsOneWidget);

        await tester.tap(
          find.byWidgetPredicate(
            (widget) =>
                widget is DivineIconButton &&
                widget.icon == DivineIconName.check,
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('home'), findsOneWidget);
        expect(find.text(l10n.videoEditorSpeedSheetTitle), findsNothing);
      });
    });
  });
}
