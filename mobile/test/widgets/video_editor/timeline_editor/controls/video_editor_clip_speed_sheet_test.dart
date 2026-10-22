// ABOUTME: Widget tests for VideoEditorClipSpeedSheet.
// ABOUTME: Covers rendering, clamping, speed presets, speed curves and cancel/confirm.

import 'dart:ui' show Tristate;

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/constants/video_editor_constants.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/video_editor/clip_speed_choice.dart';
import 'package:openvine/widgets/video_editor/timeline_editor/controls/video_editor_clip_speed_sheet.dart';
import 'package:pro_video_editor/pro_video_editor.dart' show VideoSpeedRamp;

// Sentinel shown on the base route so navigation-back tests can confirm
// that the sheet was popped.
class _HomeScreen extends StatelessWidget {
  const _HomeScreen();

  @override
  Widget build(BuildContext context) => const Scaffold(body: Text('home'));
}

Widget _buildSubject({
  double initialSpeed = 1.0,
  VideoSpeedRamp? initialRamp,
  Duration? sourceDuration,
  bool offerCurve = true,
}) {
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
                body: VideoEditorClipSpeedSheet(
                  initialSpeed: initialSpeed,
                  initialRamp: initialRamp,
                  sourceDuration: sourceDuration,
                  offerCurve: offerCurve,
                ),
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
Widget _buildPushingSubject({
  required ValueChanged<ClipSpeedChoice?> onResult,
  VideoSpeedRamp? initialRamp,
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
              onPressed: () async =>
                  onResult(await context.push<ClipSpeedChoice>('/speed')),
              child: const Text('open'),
            ),
          ),
          routes: [
            GoRoute(
              path: 'speed',
              builder: (context, state) => Scaffold(
                body: VideoEditorClipSpeedSheet(initialRamp: initialRamp),
              ),
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

/// Every speed preset chip currently announced as selected; their labels end
/// in the speed's `×`, unlike the Constant | Curve toggle.
SemanticsFinder _selectedNodes() => find.semantics.byPredicate(
  (node) =>
      node.getSemanticsData().flagsCollection.isSelected == Tristate.isTrue &&
      node.label.endsWith('×'),
);

AppLocalizations get _l10n => lookupAppLocalizations(const Locale('en'));

Finder get _confirmButton => find.byWidgetPredicate(
  (widget) => widget is DivineIconButton && widget.icon == DivineIconName.check,
);

/// The handle of the speed curve's point [index] (1-based) of [count].
Finder _curvePoint(int index, [int count = 5]) => find.bySemanticsLabel(
  _l10n.videoEditorSpeedCurvePointSemanticLabel('$index', '$count'),
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

      testWidgets('keeps a 48dp tap target on a 320dp-wide phone', (
        tester,
      ) async {
        await tester.binding.setSurfaceSize(const Size(320, 640));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await tester.pumpWidget(_buildSubject());
        await tester.pumpAndSettle();

        for (final label in ['0.25', '0.5', '1', '1.5', '2', '3']) {
          final size = tester.getSize(_preset(label));
          expect(size.width, greaterThanOrEqualTo(48), reason: label);
          expect(size.height, greaterThanOrEqualTo(48), reason: label);
        }
      });

      testWidgets('confirming returns the tapped preset', (tester) async {
        ClipSpeedChoice? result;
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

        expect(result, isA<ConstantClipSpeed>());
        expect((result! as ConstantClipSpeed).speed, equals(0.5));
      });
    });

    group('speed curve', () {
      testWidgets('opens on the curve when the clip has one', (tester) async {
        await tester.pumpWidget(
          _buildSubject(initialRamp: ClipSpeedRampPreset.hero.ramp),
        );
        await tester.pumpAndSettle();

        expect(
          tester.getSemantics(
            find.bySemanticsLabel(_l10n.videoEditorSpeedModeCurve),
          ),
          isSemantics(isSelected: true),
        );
        expect(
          tester.getSemantics(
            find.bySemanticsLabel(_l10n.videoEditorSpeedCurveHero),
          ),
          isSemantics(isSelected: true),
        );
        expect(find.byType(DivineSlider), findsNothing);
        expect(_curvePoint(3), findsOneWidget);
      });

      testWidgets('leaves the curve out where only one speed can play', (
        tester,
      ) async {
        // A sound plays at one speed; its sheet even ignores a curve handed in.
        await tester.pumpWidget(
          _buildSubject(
            initialRamp: ClipSpeedRampPreset.hero.ramp,
            offerCurve: false,
          ),
        );
        await tester.pumpAndSettle();

        expect(
          find.bySemanticsLabel(_l10n.videoEditorSpeedModeCurve),
          findsNothing,
        );
        expect(find.byType(DivineSlider), findsOneWidget);
        expect(_curvePoint(0), findsNothing);
      });

      testWidgets('confirming a preset returns its ramp', (tester) async {
        ClipSpeedChoice? result;
        await tester.pumpWidget(
          _buildPushingSubject(onResult: (value) => result = value),
        );
        await tester.tap(find.text('open'));
        await tester.pumpAndSettle();

        await tester.tap(find.text(_l10n.videoEditorSpeedModeCurve));
        await tester.pump();
        await tester.tap(find.text(_l10n.videoEditorSpeedCurveBullet));
        await tester.pump();
        await tester.tap(_confirmButton);
        await tester.pumpAndSettle();

        expect(result, isA<RampClipSpeed>());
        expect(
          (result! as RampClipSpeed).ramp,
          equals(ClipSpeedRampPreset.bullet.ramp),
        );
      });

      testWidgets('a flat curve comes back as a constant speed', (
        tester,
      ) async {
        ClipSpeedChoice? result;
        await tester.pumpWidget(
          _buildPushingSubject(onResult: (value) => result = value),
        );
        await tester.tap(find.text('open'));
        await tester.pumpAndSettle();

        await tester.tap(find.text(_l10n.videoEditorSpeedModeCurve));
        await tester.pump();
        await tester.tap(_confirmButton);
        await tester.pumpAndSettle();

        expect(result, isA<ConstantClipSpeed>());
        expect((result! as ConstantClipSpeed).speed, equals(1));
      });

      testWidgets('dragging a point up speeds that moment up and makes the '
          'curve custom', (tester) async {
        ClipSpeedChoice? result;
        await tester.pumpWidget(
          _buildPushingSubject(
            onResult: (value) => result = value,
            initialRamp: ClipSpeedRampPreset.hero.ramp,
          ),
        );
        await tester.tap(find.text('open'));
        await tester.pumpAndSettle();

        // The middle point of the hero preset sits at 0.3×. A finger moves
        // in many small steps, and the handle moves under it in between.
        final gesture = await tester.startGesture(
          tester.getCenter(_curvePoint(3)),
        );
        for (var step = 0; step < 8; step++) {
          await gesture.moveBy(const Offset(0, -5));
          await tester.pump();
        }
        await gesture.up();
        await tester.pumpAndSettle();

        expect(
          tester.getSemantics(
            find.bySemanticsLabel(_l10n.videoEditorSpeedCurveCustom),
          ),
          isSemantics(isSelected: true),
        );
        await tester.tap(_confirmButton);
        await tester.pumpAndSettle();

        final ramp = (result! as RampClipSpeed).ramp;
        // The handle follows the finger: 40 px up a 148 px plot that spans
        // 0.25× to 3× on a log scale is a factor of 12^(40/148), so 0.3×
        // becomes about 0.59×, which snaps to 0.6×. A handle that ran away
        // from the finger ends up at the 3× ceiling instead.
        expect(ramp.points[2].speed, closeTo(0.6, 1e-9));
        expect(ramp.points[2].position, 0.5);
        expect(ramp.points[0], ClipSpeedRampPreset.hero.ramp.points[0]);
      });

      testWidgets('a screen reader raises a point by one slider step', (
        tester,
      ) async {
        await tester.pumpWidget(_buildSubject(initialRamp: flatSpeedRamp));
        await tester.pumpAndSettle();

        expect(
          tester.getSemantics(_curvePoint(2)),
          isSemantics(isSlider: true, value: '1×', increasedValue: '1.05×'),
        );
        tester.semantics.increase(
          find.semantics.byLabel(
            _l10n.videoEditorSpeedCurvePointSemanticLabel('2', '5'),
          ),
        );
        await tester.pump();

        expect(
          tester.getSemantics(_curvePoint(2)),
          isSemantics(value: '1.05×'),
        );
      });

      testWidgets('shows how long the clip plays with the curve', (
        tester,
      ) async {
        const source = Duration(seconds: 3);
        final ramp = ClipSpeedRampPreset.bullet.ramp;
        await tester.pumpWidget(
          _buildSubject(initialRamp: ramp, sourceDuration: source),
        );
        await tester.pumpAndSettle();

        final seconds = (ramp.outputDuration(source).inMilliseconds / 1000)
            .toStringAsFixed(
              1,
            );
        expect(
          find.text(_l10n.videoEditorSpeedResultingLength(seconds)),
          findsOneWidget,
        );

        // A constant 2× plays the same 3 s in 1.5 s.
        await tester.tap(find.text(_l10n.videoEditorSpeedModeConstant));
        await tester.pump();
        await tester.tap(find.text('2×'));
        await tester.pump();
        expect(
          find.text(_l10n.videoEditorSpeedResultingLength('1.5')),
          findsOneWidget,
        );
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
