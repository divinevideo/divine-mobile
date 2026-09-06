// ABOUTME: Behavior tests for the transition picker view (preview + controls).

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/blocs/video_editor/transition_boundary/transition_boundary_cubit.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/widgets/video_editor/timeline_editor/controls/video_editor_transition_sheet.dart';
import 'package:pro_video_editor/pro_video_editor.dart' as editor;

/// Stand-in cubit that holds fixed (null) boundary frames without touching the
/// platform thumbnail service, so the picker renders its gradient fallback.
class _FakeTransitionBoundaryCubit extends Cubit<TransitionBoundaryState>
    implements TransitionBoundaryCubit {
  _FakeTransitionBoundaryCubit() : super(const TransitionBoundaryState());
}

void main() {
  final l10n = lookupAppLocalizations(const Locale('en'));

  group(TransitionPickerView, () {
    late ({editor.ClipTransition? transition})? result;
    late bool returned;

    Future<void> openPicker(
      WidgetTester tester, {
      editor.ClipTransition? initial,
      int overlapMaxMs = 2000,
      int dipMaxMs = 2000,
      bool limitedByNeighbor = false,
      bool disableAnimations = false,
      ThemeData? theme,
    }) async {
      result = null;
      returned = false;
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(disableAnimations: disableAnimations),
            child: child!,
          ),
          theme: theme,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async {
                  result = await Navigator.of(context)
                      .push<({editor.ClipTransition? transition})>(
                        MaterialPageRoute(
                          builder: (_) => BlocProvider<TransitionBoundaryCubit>(
                            create: (_) => _FakeTransitionBoundaryCubit(),
                            child: Scaffold(
                              body: TransitionPickerView(
                                initial: initial,
                                overlapMaxMs: overlapMaxMs,
                                dipMaxMs: dipMaxMs,
                                limitedByNeighbor: limitedByNeighbor,
                              ),
                            ),
                          ),
                        ),
                      );
                  returned = true;
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      // The picker loops forever, so never pumpAndSettle — advance manually.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
    }

    testWidgets('stops preview loops when animations are disabled', (
      tester,
    ) async {
      await openPicker(tester, disableAnimations: true);

      await tester.pumpAndSettle();
      expect(tester.binding.hasScheduledFrame, isFalse);
    });

    testWidgets('lists every transition option', (tester) async {
      await openPicker(tester);

      expect(find.text(l10n.videoEditorTransitionNone), findsOneWidget);
      expect(find.text(l10n.videoEditorTransitionDissolve), findsOneWidget);
      expect(find.text(l10n.videoEditorTransitionFadeToBlack), findsOneWidget);
      expect(find.text(l10n.videoEditorTransitionWipe), findsOneWidget);
    });

    testWidgets('shows the neighbor-limit hint once a transition is picked '
        'when the boundary is limited', (tester) async {
      await openPicker(tester, limitedByNeighbor: true);

      // "None" is selected initially — no transition, so no hint yet.
      expect(
        find.text(l10n.videoEditorTransitionDurationLimitedHint),
        findsNothing,
      );

      await tester.tap(find.text(l10n.videoEditorTransitionDissolve));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));

      expect(
        find.text(l10n.videoEditorTransitionDurationLimitedHint),
        findsOneWidget,
      );
    });

    testWidgets('hides the neighbor-limit hint when not limited', (
      tester,
    ) async {
      await openPicker(tester);

      await tester.tap(find.text(l10n.videoEditorTransitionDissolve));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));

      expect(
        find.text(l10n.videoEditorTransitionDurationLimitedHint),
        findsNothing,
      );
    });

    testWidgets('shows duration + curve even for a hard cut (none)', (
      tester,
    ) async {
      await openPicker(tester);

      // "None" is selected initially — duration and curve are still shown.
      expect(find.text(l10n.videoEditorTransitionDuration), findsOneWidget);
      expect(find.text(l10n.videoEditorTransitionCurve), findsOneWidget);

      // Picking a transition keeps them visible.
      await tester.tap(find.text(l10n.videoEditorTransitionDissolve));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));

      expect(find.text(l10n.videoEditorTransitionDuration), findsOneWidget);
      expect(find.text(l10n.videoEditorTransitionCurve), findsOneWidget);
    });

    testWidgets('keeps the duration when the type changes, on confirm', (
      tester,
    ) async {
      await openPicker(
        tester,
        initial: const editor.ClipTransition(
          type: editor.ClipTransitionType.dissolve,
          duration: Duration(milliseconds: 1200),
        ),
      );

      await tester.tap(find.text(l10n.videoEditorTransitionFadeToBlack));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
      await tester.tap(find.text(l10n.videoEditorDoneLabel));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      expect(returned, isTrue);
      expect(result?.transition?.type, editor.ClipTransitionType.fadeToBlack);
      expect(
        result?.transition?.duration,
        const Duration(milliseconds: 1200),
      );
    });

    testWidgets('dragging the slider to the end sets the max duration', (
      tester,
    ) async {
      await openPicker(tester);

      await tester.tap(find.text(l10n.videoEditorTransitionDissolve));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));

      // Drag well past the slider's right edge so the thumb pins to the
      // maximum regardless of the surface width under test — a fixed pixel
      // offset under-reaches when another test leaks a wider surface.
      final sliderWidth = tester.getSize(find.byType(DivineSlider)).width;
      await tester.drag(find.byType(DivineSlider), Offset(sliderWidth * 2, 0));
      await tester.pump();
      await tester.tap(find.text(l10n.videoEditorDoneLabel));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      expect(returned, isTrue);
      expect(
        result?.transition?.duration,
        const Duration(milliseconds: 2000),
      );
    });

    testWidgets('caps an over-long duration at the boundary maximum', (
      tester,
    ) async {
      await openPicker(
        tester,
        overlapMaxMs: 500,
        initial: const editor.ClipTransition(
          type: editor.ClipTransitionType.dissolve,
          duration: Duration(milliseconds: 1200),
        ),
      );

      await tester.tap(find.text(l10n.videoEditorDoneLabel));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      expect(
        result?.transition?.duration,
        const Duration(milliseconds: 500),
      );
    });

    testWidgets('a dip keeps a duration above the overlap ceiling', (
      tester,
    ) async {
      await openPicker(
        tester,
        overlapMaxMs: 300,
        dipMaxMs: 1000,
        initial: const editor.ClipTransition(
          type: editor.ClipTransitionType.fadeToBlack,
          duration: Duration(milliseconds: 900),
        ),
      );

      await tester.tap(find.text(l10n.videoEditorDoneLabel));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      expect(result?.transition?.type, editor.ClipTransitionType.fadeToBlack);
      expect(result?.transition?.duration, const Duration(milliseconds: 900));
    });

    testWidgets('switching a dip to an overlap re-clamps to the overlap '
        'ceiling', (tester) async {
      await openPicker(
        tester,
        overlapMaxMs: 300,
        dipMaxMs: 1000,
        initial: const editor.ClipTransition(
          type: editor.ClipTransitionType.fadeToBlack,
          duration: Duration(milliseconds: 900),
        ),
      );

      await tester.tap(find.text(l10n.videoEditorTransitionDissolve));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
      await tester.tap(find.text(l10n.videoEditorDoneLabel));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      expect(result?.transition?.type, editor.ClipTransitionType.dissolve);
      expect(result?.transition?.duration, const Duration(milliseconds: 300));
    });

    testWidgets('returns null (hard cut) when None is confirmed', (
      tester,
    ) async {
      await openPicker(
        tester,
        initial: const editor.ClipTransition(
          type: editor.ClipTransitionType.dissolve,
        ),
      );

      await tester.tap(find.text(l10n.videoEditorTransitionNone));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
      await tester.tap(find.text(l10n.videoEditorDoneLabel));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      expect(returned, isTrue);
      expect(result?.transition, isNull);
    });

    testWidgets('shows direction options only for directional transitions', (
      tester,
    ) async {
      await openPicker(tester);

      await tester.tap(find.text(l10n.videoEditorTransitionDissolve));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
      expect(find.text(l10n.videoEditorTransitionDirection), findsNothing);

      await tester.tap(find.text(l10n.videoEditorTransitionSlide));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
      expect(find.text(l10n.videoEditorTransitionDirection), findsOneWidget);
    });

    testWidgets('curve chips expose a semantic label and selected state', (
      tester,
    ) async {
      await openPicker(tester);

      // The curve glyphs carry no text, so each chip names itself for screen
      // readers via its position (1-based).
      expect(
        find.byWidgetPredicate(
          (w) =>
              w is Semantics &&
              w.properties.label ==
                  l10n.videoEditorTransitionCurveOptionSemanticLabel(1) &&
              w.properties.button == true,
        ),
        findsOneWidget,
      );
    });

    testWidgets('direction chips expose localized direction labels', (
      tester,
    ) async {
      await openPicker(tester);

      // Directions appear only for directional transitions.
      await tester.tap(find.text(l10n.videoEditorTransitionSlide));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));

      expect(
        find.byWidgetPredicate(
          (w) =>
              w is Semantics &&
              w.properties.label == l10n.videoEditorTransitionDirectionUp &&
              w.properties.button == true,
        ),
        findsOneWidget,
      );
    });

    testWidgets('selected tile ring and direction glyph share the light '
        'selected-control token', (tester) async {
      await openPicker(tester, theme: VineTheme.lightTheme);

      await tester.tap(find.text(l10n.videoEditorTransitionSlide));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));

      const colors = VineTheme.lightColors;
      final selectedDirectionIcon = tester.widget<DivineIcon>(
        find.byWidgetPredicate(
          (w) => w is DivineIcon && w.icon == DivineIconName.arrowLeft,
        ),
      );
      expect(selectedDirectionIcon.color, colors.accentBrand);

      expect(
        find.byWidgetPredicate((w) {
          if (w is! DecoratedBox || w.decoration is! BoxDecoration) {
            return false;
          }
          final decoration = w.decoration as BoxDecoration;
          final border = decoration.border;
          return border is Border &&
              border.top.width == 2 &&
              border.top.color == colors.accentBrand;
        }),
        findsOneWidget,
      );
    });

    testWidgets('returns the chosen direction on confirm', (tester) async {
      await openPicker(tester);

      await tester.tap(find.text(l10n.videoEditorTransitionSlide));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
      await tester.tap(
        find.byWidgetPredicate(
          (w) => w is DivineIcon && w.icon == DivineIconName.arrowUp,
        ),
      );
      await tester.pump();
      await tester.tap(find.text(l10n.videoEditorDoneLabel));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      expect(result?.transition?.type, editor.ClipTransitionType.slide);
      expect(
        result?.transition?.direction,
        editor.ClipTransitionDirection.up,
      );
    });

    testWidgets('a transition tile announces its label once, not twice', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await openPicker(tester);

      // The tile keeps an explicit Semantics(label:) and a visible Text(label).
      // The text is excluded from semantics so the merged node reads the label
      // once — "Dissolve", not "Dissolve\nDissolve".
      final node = tester.getSemantics(
        find.text(l10n.videoEditorTransitionDissolve),
      );
      expect(node.label, l10n.videoEditorTransitionDissolve);

      handle.dispose();
    });
  });
}
