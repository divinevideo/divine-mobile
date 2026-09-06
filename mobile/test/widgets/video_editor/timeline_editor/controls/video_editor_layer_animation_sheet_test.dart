// ABOUTME: Behavior tests for the layer enter/leave animation picker view.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/extensions/layer_animation_storage.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/widgets/video_editor/main_editor/video_editor_scope.dart';
import 'package:openvine/widgets/video_editor/timeline_editor/controls/video_editor_layer_animation_sheet.dart';
import 'package:pro_image_editor/pro_image_editor.dart'
    show Layer, ProImageEditorState;
import 'package:pro_video_editor/pro_video_editor.dart' as editor;

class _MockProImageEditorState extends Mock implements ProImageEditorState {
  @override
  String toString({DiagnosticLevel minLevel = DiagnosticLevel.info}) =>
      '_MockProImageEditorState';
}

void main() {
  final l10n = lookupAppLocalizations(const Locale('en'));

  group(LayerAnimationPickerView, () {
    late _LayerAnimationResult? result;
    late bool returned;

    Future<void> openPicker(
      WidgetTester tester, {
      List<editor.LayerAnimation> initialEnter = const [],
      List<editor.LayerAnimation> initialLeave = const [],
      double viewHeight = 1600,
      bool disableAnimations = false,
      ThemeData? theme,
    }) async {
      result = null;
      returned = false;
      // Tall viewport by default so the full picker (type tiles + curve wrap +
      // direction row + Done) fits without scrolling; individual tests shrink
      // it to exercise the scroll/pinned-Done behaviour.
      tester.view.physicalSize = Size(500, viewHeight);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
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
                      .push<_LayerAnimationResult>(
                        MaterialPageRoute(
                          builder: (_) => Scaffold(
                            body: LayerAnimationPickerView(
                              initialEnter: initialEnter,
                              initialLeave: initialLeave,
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
      // The preview loops forever, so never pumpAndSettle — advance manually.
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

    testWidgets('lists every animation type', (tester) async {
      await openPicker(tester);

      expect(find.text(l10n.videoEditorTransitionNone), findsOneWidget);
      expect(find.text(l10n.videoEditorLayerAnimationFade), findsOneWidget);
      expect(find.text(l10n.videoEditorTransitionSlide), findsOneWidget);
      expect(find.text(l10n.videoEditorLayerAnimationScale), findsOneWidget);
    });

    testWidgets('shows enter and leave toggles', (tester) async {
      await openPicker(tester);

      expect(find.text(l10n.videoEditorLayerAnimationEnter), findsOneWidget);
      expect(find.text(l10n.videoEditorLayerAnimationLeave), findsOneWidget);
    });

    testWidgets('picker chrome follows the light palette', (tester) async {
      await openPicker(tester, theme: VineTheme.lightTheme);

      const colors = VineTheme.lightColors;

      // Anchored on the two phase segments rather than "any box carrying this
      // token" — the sheet paints a dozen boxes in `containerLow`, so a
      // predicate over all of them stays green when a single site regresses.
      // Enter is the initially selected phase.
      final enter = _segmentDecoration(
        tester,
        l10n.videoEditorLayerAnimationEnter,
      );
      expect(enter.color, colors.controlSelectedFill);
      expect(
        (enter.border! as Border).top.color,
        colors.accentBrand,
      );

      final leave = _segmentDecoration(
        tester,
        l10n.videoEditorLayerAnimationLeave,
      );
      expect(leave.color, isNull);
      expect((leave.border! as Border).top.color, VineTheme.transparent);

      // The toggle these two segments sit in is the `containerLow` surface.
      final toggle = tester.widget<DecoratedBox>(
        find
            .ancestor(
              of: find.text(l10n.videoEditorLayerAnimationEnter),
              matching: find.byType(DecoratedBox),
            )
            .last,
      );
      expect((toggle.decoration as BoxDecoration).color, colors.controlFill);
    });

    testWidgets(
      'type tiles carry the selected-control ring language in light mode',
      (tester) async {
        await openPicker(tester, theme: VineTheme.lightTheme);

        const colors = VineTheme.lightColors;
        // The type tiles are the only width-2 borders in this sheet, so the
        // rings can be asserted by predicate: "None" is selected initially,
        // while Fade/Slide/Scale are not.
        Finder tileRings(Color ring) => find.byWidgetPredicate((w) {
          if (w is! DecoratedBox || w.decoration is! BoxDecoration) {
            return false;
          }
          final border = (w.decoration as BoxDecoration).border;
          return border is Border &&
              border.top.width == 2 &&
              border.top.color == ring;
        });

        expect(tileRings(colors.accentBrand), findsOneWidget);
        expect(tileRings(colors.controlOutline), findsNWidgets(3));
      },
    );

    testWidgets('shows duration + curve even for None', (tester) async {
      await openPicker(tester);

      // "None" is selected initially — duration and curve are still shown so
      // the values persist when a type is picked.
      expect(find.text(l10n.videoEditorTransitionDuration), findsOneWidget);
      expect(find.text(l10n.videoEditorTransitionCurve), findsOneWidget);
      // Type-specific controls stay hidden for None.
      expect(find.text(l10n.videoEditorTransitionDirection), findsNothing);
      expect(find.text(l10n.videoEditorLayerAnimationScaleFrom), findsNothing);
    });

    testWidgets('returns no animations when None stays selected', (
      tester,
    ) async {
      await openPicker(tester);

      await tester.tap(find.text(l10n.videoEditorDoneLabel));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      expect(returned, isTrue);
      expect(result?.enter, isEmpty);
      expect(result?.leave, isEmpty);
    });

    testWidgets('builds an enter animation for the chosen type', (
      tester,
    ) async {
      await openPicker(tester);

      await tester.tap(find.text(l10n.videoEditorLayerAnimationFade));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
      await tester.tap(find.text(l10n.videoEditorDoneLabel));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      expect(result?.enter.single.type, editor.LayerAnimationType.fade);
      expect(result?.enter.single.phase, editor.AnimationPhase.animateIn);
      expect(result?.leave, isEmpty);
    });

    testWidgets('edits the leave phase independently of enter', (tester) async {
      await openPicker(
        tester,
        initialEnter: const [
          editor.LayerAnimation(
            type: editor.LayerAnimationType.fade,
            phase: editor.AnimationPhase.animateIn,
            duration: Duration(milliseconds: 400),
          ),
        ],
      );

      await tester.tap(find.text(l10n.videoEditorLayerAnimationLeave));
      await tester.pump();
      await tester.tap(find.text(l10n.videoEditorLayerAnimationScale));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
      await tester.tap(find.text(l10n.videoEditorDoneLabel));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      expect(result?.enter.single.type, editor.LayerAnimationType.fade);
      expect(result?.leave.single.type, editor.LayerAnimationType.scale);
      expect(result?.leave.single.phase, editor.AnimationPhase.animateOut);
    });

    testWidgets('shows direction options only for slide', (tester) async {
      await openPicker(tester);

      await tester.tap(find.text(l10n.videoEditorLayerAnimationFade));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
      expect(find.text(l10n.videoEditorTransitionDirection), findsNothing);

      await tester.tap(find.text(l10n.videoEditorTransitionSlide));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
      expect(find.text(l10n.videoEditorTransitionDirection), findsOneWidget);
    });

    testWidgets('shows the scale-from control only for scale', (tester) async {
      await openPicker(tester);

      await tester.tap(find.text(l10n.videoEditorLayerAnimationScale));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));

      expect(
        find.text(l10n.videoEditorLayerAnimationScaleFrom),
        findsOneWidget,
      );
    });

    testWidgets('carries the chosen slide direction into the result', (
      tester,
    ) async {
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

      expect(result?.enter.single.type, editor.LayerAnimationType.slide);
      expect(result?.enter.single.slideDirection, editor.SlideDirection.top);
    });

    testWidgets('combines fade and slide into one phase', (tester) async {
      await openPicker(tester);

      await tester.tap(find.text(l10n.videoEditorLayerAnimationFade));
      await tester.pump();
      await tester.tap(find.text(l10n.videoEditorTransitionSlide));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
      await tester.tap(find.text(l10n.videoEditorDoneLabel));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      expect(
        result?.enter.map((a) => a.type),
        containsAll(<editor.LayerAnimationType>[
          editor.LayerAnimationType.fade,
          editor.LayerAnimationType.slide,
        ]),
      );
      expect(result?.enter, hasLength(2));
      expect(
        result?.enter.every((a) => a.phase == editor.AnimationPhase.animateIn),
        isTrue,
      );
      expect(result?.leave, isEmpty);
    });

    testWidgets('toggling a selected type removes it', (tester) async {
      await openPicker(tester);

      await tester.tap(find.text(l10n.videoEditorLayerAnimationFade));
      await tester.pump();
      await tester.tap(find.text(l10n.videoEditorLayerAnimationFade));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
      await tester.tap(find.text(l10n.videoEditorDoneLabel));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      expect(result?.enter, isEmpty);
    });

    testWidgets('keeps Done reachable on a short viewport with slide + scale', (
      tester,
    ) async {
      // Short enough that the tallest combination (slide + scale shows both the
      // direction and scale-from rows) overflows the body and must scroll.
      await openPicker(tester, viewHeight: 620);

      await tester.tap(find.text(l10n.videoEditorTransitionSlide));
      await tester.pump();
      await tester.tap(find.text(l10n.videoEditorLayerAnimationScale));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));

      // Done is pinned below the scrollable controls, so it stays hittable even
      // though the controls overflow the viewport.
      await tester.tap(find.text(l10n.videoEditorDoneLabel));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      expect(returned, isTrue);
      expect(
        result?.enter.map((a) => a.type),
        containsAll(<editor.LayerAnimationType>[
          editor.LayerAnimationType.slide,
          editor.LayerAnimationType.scale,
        ]),
      );
    });

    testWidgets('a type tile announces its label once, not twice', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await openPicker(tester);

      // The tile keeps an explicit Semantics(label:) and a visible Text(label).
      // The text is excluded from semantics so the merged node reads the label
      // once — "Fade", not "Fade\nFade".
      final node = tester.getSemantics(
        find.text(l10n.videoEditorLayerAnimationFade),
      );
      expect(node.label, l10n.videoEditorLayerAnimationFade);

      handle.dispose();
    });
  });

  group('resolveLayerEndTime', () {
    const total = Duration(seconds: 5);

    test('anchors an untrimmed layer to the window end for a leave '
        'animation', () {
      expect(
        resolveLayerEndTime(
          currentEndTime: null,
          startTime: Duration.zero,
          totalDuration: total,
          hasLeaveAnimation: true,
        ),
        total,
      );
    });

    test('keeps an explicit trim end for a leave animation', () {
      const trimEnd = Duration(seconds: 2);
      expect(
        resolveLayerEndTime(
          currentEndTime: trimEnd,
          startTime: Duration.zero,
          totalDuration: total,
          hasLeaveAnimation: true,
        ),
        trimEnd,
      );
    });

    test('leaves an untrimmed layer untrimmed without a leave animation', () {
      expect(
        resolveLayerEndTime(
          currentEndTime: null,
          startTime: Duration.zero,
          totalDuration: total,
          hasLeaveAnimation: false,
        ),
        isNull,
      );
    });

    test('preserves an explicit trim end without a leave animation', () {
      const trimEnd = Duration(seconds: 3);
      expect(
        resolveLayerEndTime(
          currentEndTime: trimEnd,
          startTime: Duration.zero,
          totalDuration: total,
          hasLeaveAnimation: false,
        ),
        trimEnd,
      );
    });

    test('drops a full-length end when the leave animation is removed', () {
      // The end was previously anchored to the window for a leave animation;
      // removing the leave must not leave the layer pinned (untrimmed again).
      expect(
        resolveLayerEndTime(
          currentEndTime: total,
          startTime: Duration.zero,
          totalDuration: total,
          hasLeaveAnimation: false,
        ),
        isNull,
      );
    });

    test('drops a stale end past the window without a leave animation', () {
      // e.g. the video was shortened after the end was anchored.
      expect(
        resolveLayerEndTime(
          currentEndTime: const Duration(seconds: 8),
          startTime: Duration.zero,
          totalDuration: total,
          hasLeaveAnimation: false,
        ),
        isNull,
      );
    });

    test('clamps a stale end past the window to the window for a leave', () {
      expect(
        resolveLayerEndTime(
          currentEndTime: const Duration(seconds: 8),
          startTime: Duration.zero,
          totalDuration: total,
          hasLeaveAnimation: true,
        ),
        total,
      );
    });

    test('does not collapse the layer when totalDuration is a transient '
        'zero', () {
      // A leave set before the player has reported its length: a zero total
      // must not anchor endTime at zero (== startTime), which would collapse
      // the layer to a zero-length window and drop it from the timeline.
      // Un-anchored (null) keeps it spanning the whole video instead.
      expect(
        resolveLayerEndTime(
          currentEndTime: null,
          startTime: Duration.zero,
          totalDuration: Duration.zero,
          hasLeaveAnimation: true,
        ),
        isNull,
      );
    });

    test('never anchors a late layer at or before its start on a stale '
        'small total', () {
      // A layer starting at 4s with a stale total of 3s must not anchor its
      // end at 3s (<= start). With no valid existing end it stays un-anchored
      // rather than vanish from the timeline.
      expect(
        resolveLayerEndTime(
          currentEndTime: null,
          startTime: const Duration(seconds: 4),
          totalDuration: const Duration(seconds: 3),
          hasLeaveAnimation: true,
        ),
        isNull,
      );
    });

    test('keeps the existing valid end when the total is stale small', () {
      // total (1s) is stale below the layer window; rather than collapse, keep
      // the real end (4s) that is still after the 2s start.
      expect(
        resolveLayerEndTime(
          currentEndTime: const Duration(seconds: 4),
          startTime: const Duration(seconds: 2),
          totalDuration: const Duration(seconds: 1),
          hasLeaveAnimation: true,
        ),
        const Duration(seconds: 4),
      );
    });
  });

  group('editLayerAnimation', () {
    const total = Duration(seconds: 5);
    const leaveFade = editor.LayerAnimation(
      type: editor.LayerAnimationType.fade,
      phase: editor.AnimationPhase.animateOut,
      duration: Duration(milliseconds: 300),
    );

    late _MockProImageEditorState mockEditor;

    setUp(() {
      mockEditor = _MockProImageEditorState();
      when(
        () => mockEditor.addHistory(layers: any(named: 'layers')),
      ).thenAnswer((_) {});
    });

    Future<void> openEditor(WidgetTester tester, Layer layer) async {
      when(() => mockEditor.activeLayers).thenReturn([layer]);
      tester.view.physicalSize = const Size(500, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: VideoEditorScope(
            editorKey: GlobalKey(),
            removeAreaKey: GlobalKey(),
            originalClipAspectRatio: 9 / 16,
            bodySizeNotifier: ValueNotifier(const Size(400, 600)),
            zoomMatrixNotifier: ValueNotifier(Matrix4.identity()),
            playTimeNotifier: ValueNotifier(Duration.zero),
            fromLibrary: false,
            onOpenCamera: () {},
            onOpenClipsEditor: () {},
            onAddStickers: () {},
            onAddEditTextLayer: ([layer]) async => null,
            onOpenMusicLibrary: () {},
            onOpenVoiceOver: () {},
            onOpenCaptions: () {},
            editorOverride: mockEditor,
            child: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () =>
                      editLayerAnimation(context, layer, totalDuration: total),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      // The preview loops forever, so never pumpAndSettle — advance manually.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
    }

    Future<void> tapDone(WidgetTester tester) async {
      await tester.tap(find.text(l10n.videoEditorDoneLabel));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
    }

    List<Layer> capturedLayers() {
      final result = verify(
        () => mockEditor.addHistory(layers: captureAny(named: 'layers')),
      )..called(1);
      return result.captured.single as List<Layer>;
    }

    testWidgets('anchors endTime to the window when a leave is added', (
      tester,
    ) async {
      await openEditor(tester, Layer(id: 'l1'));

      await tester.tap(find.text(l10n.videoEditorLayerAnimationLeave));
      await tester.pump();
      await tester.tap(find.text(l10n.videoEditorLayerAnimationFade));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
      await tapDone(tester);

      expect(capturedLayers().single.endTime, equals(total));
    });

    testWidgets('clears endTime to null when the leave is removed', (
      tester,
    ) async {
      // Untrimmed layer previously anchored to the window for a leave
      // animation; removing the leave must drop the stale end back to null so
      // copyWith's `endTime ?? this.endTime` can't keep it pinned.
      final layer = Layer(id: 'l1', animations: [leaveFade].toLayerAnimations())
        ..endTime = total;
      await openEditor(tester, layer);

      await tester.tap(find.text(l10n.videoEditorLayerAnimationLeave));
      await tester.pump();
      await tester.tap(find.text(l10n.videoEditorTransitionNone));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
      await tapDone(tester);

      expect(capturedLayers().single.endTime, isNull);
    });

    testWidgets('preserves a genuine trim when only an enter is added', (
      tester,
    ) async {
      // A layer trimmed to 2s (< total) gets an enter-only animation. Because
      // totalDuration is the true video length (not the layer's own end), the
      // 2s trim reads as a real trim and survives — it isn't mistaken for a
      // stale full-length anchor and dropped.
      final layer = Layer(id: 'l1')..endTime = const Duration(seconds: 2);
      await openEditor(tester, layer);

      await tester.tap(find.text(l10n.videoEditorLayerAnimationFade));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
      await tapDone(tester);

      expect(
        capturedLayers().single.endTime,
        equals(const Duration(seconds: 2)),
      );
    });
  });
}

typedef _LayerAnimationResult = ({
  List<editor.LayerAnimation> enter,
  List<editor.LayerAnimation> leave,
});

/// The decoration of the phase segment labelled [label].
BoxDecoration _segmentDecoration(WidgetTester tester, String label) {
  final container = tester.widget<Container>(
    find.ancestor(of: find.text(label), matching: find.byType(Container)).first,
  );
  return container.decoration! as BoxDecoration;
}
