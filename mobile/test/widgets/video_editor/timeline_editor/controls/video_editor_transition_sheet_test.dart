// ABOUTME: Behavior tests for the transition picker view (preview + controls).

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/blocs/video_editor/transition_boundary/transition_boundary_cubit.dart';
import 'package:openvine/l10n/l10n.dart';
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
      bool Function(editor.ClipTransition transition)? flashSuppressed,
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
          localizationsDelegates: appLocalizationsDelegates,
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
                                flashSuppressed: flashSuppressed,
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

    group('moving, blurring and flashing transitions', () {
      // Wide enough that every tile is built without scrolling the row.
      Future<void> widen(WidgetTester tester) async {
        await tester.binding.setSurfaceSize(const Size(1600, 900));
        addTearDown(() => tester.binding.setSurfaceSize(null));
      }

      Future<void> pick(WidgetTester tester, String label) async {
        await tester.tap(find.text(label));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 250));
      }

      final labels = [
        l10n.videoEditorTransitionZoomIn,
        l10n.videoEditorTransitionZoomOut,
        l10n.videoEditorTransitionSpin,
        l10n.videoEditorTransitionWhipPan,
        l10n.videoEditorTransitionBlur,
        l10n.videoEditorTransitionGlitch,
        l10n.videoEditorTransitionFlash,
        l10n.videoEditorTransitionIris,
        l10n.videoEditorTransitionStretch,
      ];

      testWidgets('eases the flash tile with the native quadratic curve', (
        tester,
      ) async {
        await widen(tester);
        await openPicker(
          tester,
          disableAnimations: true,
          initial: const editor.ClipTransition(
            type: editor.ClipTransitionType.flash,
            curve: editor.AnimationCurve.easeIn,
          ),
        );

        // Reduced motion freezes raw progress at one half. Native ease-in
        // is t², so progress is 0.25 and flash alpha is (2 * 0.25)^4 * 0.85.
        // Flutter's similarly named Bézier produces a different brightness.
        final tile = find
            .ancestor(
              of: find.text(l10n.videoEditorTransitionFlash),
              matching: find.byType(Column),
            )
            .first;
        final overlay = tester.widget<ColoredBox>(
          find.descendant(of: tile, matching: find.byType(ColoredBox)),
        );

        expect(overlay.color.a, closeTo(0.053125, 0.000001));
      });

      testWidgets('offers each one and plays its preview through a loop', (
        tester,
      ) async {
        await widen(tester);
        await openPicker(tester);

        for (final label in labels) {
          expect(find.text(label), findsOneWidget, reason: label);
        }
        // Every preview runs through its whole transition, so a tile that
        // cannot draw some progress throws here.
        for (var step = 0; step < 30; step++) {
          await tester.pump(const Duration(milliseconds: 100));
        }
        expect(tester.takeException(), isNull);
      });

      testWidgets('changes the glitch pattern as often as the renderers', (
        tester,
      ) async {
        // The renderers change it 15 times a second, 30 times in this 2 s
        // transition; a change shows when an on-screen slice turns the other
        // way, and the tile used to change only 8 times per transition.
        Map<double, bool> shifts() {
          final tile = find
              .ancestor(
                of: find.text(l10n.videoEditorTransitionGlitch),
                matching: find.byType(Column),
              )
              .first;
          return {
            for (final slice
                in find
                    .descendant(
                      of: tile,
                      matching: find.byWidgetPredicate(
                        (w) => w is ClipRect && w.clipper != null,
                      ),
                    )
                    .evaluate())
              (slice.widget as ClipRect).clipper!
                      .getClip(const Size(64, 84))
                      .top:
                  tester
                      .widget<Transform>(
                        find.descendant(
                          of: find.byWidget(slice.widget),
                          matching: find.byType(Transform),
                        ),
                      )
                      .transform
                      .getTranslation()
                      .x >
                  0,
          };
        }

        await widen(tester);
        await openPicker(
          tester,
          initial: const editor.ClipTransition(
            type: editor.ClipTransitionType.glitch,
            duration: Duration(seconds: 2),
          ),
        );

        var changes = 0;
        var before = shifts();
        for (var frame = 0; frame < 175; frame++) {
          await tester.pump(const Duration(milliseconds: 16));
          final now = shifts();
          if (now.entries.any(
            (slice) =>
                before.containsKey(slice.key) &&
                before[slice.key] != slice.value,
          )) {
            changes++;
          }
          before = now;
        }

        expect(changes, greaterThan(10));
      });

      testWidgets('offers directions for whip pan and stretch only', (
        tester,
      ) async {
        await widen(tester);
        await openPicker(tester);

        await pick(tester, l10n.videoEditorTransitionZoomIn);
        expect(find.text(l10n.videoEditorTransitionDirection), findsNothing);

        await pick(tester, l10n.videoEditorTransitionWhipPan);
        expect(find.text(l10n.videoEditorTransitionDirection), findsOneWidget);

        await pick(tester, l10n.videoEditorTransitionStretch);
        expect(find.text(l10n.videoEditorTransitionDirection), findsOneWidget);
      });

      testWidgets('returns a picked stretch with its direction', (
        tester,
      ) async {
        await widen(tester);
        await openPicker(tester);

        await pick(tester, l10n.videoEditorTransitionStretch);
        await tester.tap(
          find.byWidgetPredicate(
            (w) => w is DivineIcon && w.icon == DivineIconName.arrowUp,
          ),
        );
        await tester.pump();
        await tester.tap(find.text(l10n.videoEditorDoneLabel));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 350));

        expect(result?.transition?.type, editor.ClipTransitionType.stretch);
        expect(
          result?.transition?.direction,
          editor.ClipTransitionDirection.up,
        );
      });

      testWidgets('explains a flash that plays as a dissolve', (tester) async {
        await widen(tester);
        final asked = <editor.ClipTransition>[];
        await openPicker(
          tester,
          flashSuppressed: (transition) {
            asked.add(transition);
            return transition.type.flashes;
          },
        );

        await pick(tester, l10n.videoEditorTransitionFlash);
        expect(
          find.text(l10n.videoEditorTransitionFlashTooClose),
          findsOneWidget,
        );
        expect(asked.last.type, editor.ClipTransitionType.flash);

        await pick(tester, l10n.videoEditorTransitionGlitch);
        expect(
          find.text(l10n.videoEditorTransitionFlashTooClose),
          findsNothing,
        );
      });

      testWidgets('keeps quiet about a flash with room around it', (
        tester,
      ) async {
        await widen(tester);
        await openPicker(tester, flashSuppressed: (_) => false);

        await pick(tester, l10n.videoEditorTransitionFlash);

        expect(
          find.text(l10n.videoEditorTransitionFlashTooClose),
          findsNothing,
        );
      });
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
