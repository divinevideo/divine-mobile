// ABOUTME: Tests for VideoEditorTuneBottomBar widget.
// ABOUTME: Validates adjustment chips, slider rendering, and selection.

import 'package:flutter/semantics.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/blocs/video_editor/tune_editor/video_editor_tune_bloc.dart';
import 'package:openvine/constants/video_editor_constants.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/video_editor/adjust_color_controls.dart';
import 'package:openvine/widgets/video_editor/main_editor/video_editor_scope.dart';
import 'package:openvine/widgets/video_editor/tune_editor/video_editor_tune_bottom_bar.dart';
import 'package:openvine/widgets/video_editor/tune_editor/video_editor_tune_color_panel.dart';
import 'package:openvine/widgets/video_editor/tune_editor/video_editor_tune_curve_panel.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final l10n = lookupAppLocalizations(const Locale('en'));

  Future<VideoEditorTuneBloc> pumpBar(WidgetTester tester) async {
    final bloc = VideoEditorTuneBloc();
    addTearDown(bloc.close);
    final bodySizeNotifier = ValueNotifier(Size.zero);
    addTearDown(bodySizeNotifier.dispose);
    final zoomNotifier = ValueNotifier(Matrix4.identity());
    addTearDown(zoomNotifier.dispose);

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: appLocalizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: BlocProvider.value(
          value: bloc,
          child: VideoEditorScope(
            editorKey: GlobalKey(),
            removeAreaKey: GlobalKey(),
            onOpenCamera: () {},
            onAddStickers: () {},
            onOpenClipsEditor: () {},
            onOpenMusicLibrary: () {},
            onOpenVoiceOver: () {},
            onOpenCaptions: () {},
            onOpenEffects: () {},
            onAddEditTextLayer: ([_]) async => null,
            originalClipAspectRatio: 9 / 16,
            bodySizeNotifier: bodySizeNotifier,
            zoomMatrixNotifier: zoomNotifier,
            playTimeNotifier: ValueNotifier(Duration.zero),
            playheadAdvancingNotifier: ValueNotifier<bool>(false),
            fromLibrary: false,
            child: const Scaffold(body: VideoEditorTuneBottomBar()),
          ),
        ),
      ),
    );
    await tester.pump();
    return bloc;
  }

  group(VideoEditorTuneBottomBar, () {
    testWidgets('renders a slider and the leading adjustment chips', (
      tester,
    ) async {
      await pumpBar(tester);

      // The chips live in a lazy horizontal list, so only the leading ones
      // are laid out; the full set is asserted in the bloc test.
      expect(find.byType(Slider), findsOneWidget);
      expect(find.text(l10n.videoEditorTuneBrightness), findsOneWidget);
      expect(find.text(l10n.videoEditorTuneContrast), findsOneWidget);
    });

    testWidgets('scrolling the chip list reveals the trailing adjustment', (
      tester,
    ) async {
      // Narrow the surface so the chips overflow and the trailing one starts
      // offscreen, independent of chip count and font-load-dependent widths.
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await pumpBar(tester);
      expect(find.text(l10n.videoEditorTuneSharpen), findsNothing);

      await tester.dragUntilVisible(
        find.text(l10n.videoEditorTuneSharpen),
        find.byType(ListView),
        const Offset(-120, 0),
      );

      expect(find.text(l10n.videoEditorTuneSharpen), findsOneWidget);
    });

    testWidgets('selecting a chip updates the bloc selected index', (
      tester,
    ) async {
      final bloc = await pumpBar(tester);
      expect(bloc.state.selectedIndex, 0);

      // Contrast is the second adjustment.
      await tester.tap(find.text(l10n.videoEditorTuneContrast));
      await tester.pump();

      expect(bloc.state.selectedIndex, 1);
      expect(
        bloc.state.selectedAdjustment.id,
        VideoEditorConstants.tuneAdjustments[1].id,
      );
    });

    testWidgets('dragging the slider changes the selected value', (
      tester,
    ) async {
      final bloc = await pumpBar(tester);
      expect(bloc.state.selectedValue, 0);

      await tester.drag(find.byType(Slider), const Offset(60, 0));
      await tester.pump();

      expect(bloc.state.selectedValue, isNot(0));
    });

    group('Color section', () {
      testWidgets('the Color chip opens the band swatches and their sliders', (
        tester,
      ) async {
        final bloc = await pumpBar(tester);

        await tester.dragUntilVisible(
          find.text(l10n.videoEditorTuneColor),
          find.byType(ListView),
          const Offset(-200, 0),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text(l10n.videoEditorTuneColor));
        await tester.pumpAndSettle();

        expect(bloc.state.section, VideoEditorTuneSection.color);
        expect(find.byType(VideoEditorTuneColorPanel), findsOneWidget);
        expect(find.bySemanticsLabel(l10n.videoEditorTuneColorAqua), findsOne);
        expect(find.byType(Slider), findsNWidgets(3));
        expect(find.text(l10n.videoEditorTuneLightness), findsOneWidget);
      });

      testWidgets("a slider changes only the picked band's value", (
        tester,
      ) async {
        final bloc = await pumpBar(tester);
        bloc.add(const VideoEditorTuneColorBandSelected(AdjustColorBand.red));
        await tester.pumpAndSettle();

        await tester.tap(find.bySemanticsLabel(l10n.videoEditorTuneColorBlue));
        await tester.pumpAndSettle();
        // The second slider is saturation.
        await tester.drag(find.byType(Slider).at(1), const Offset(-80, 0));
        await tester.pumpAndSettle();

        expect(bloc.state.colorBand, AdjustColorBand.blue);
        expect(bloc.state.valueOf('blueSaturation'), lessThan(0));
        expect(
          bloc.state.values.keys.where((kind) => kind != 'blueSaturation'),
          isEmpty,
        );
      });

      testWidgets('marks a changed band and the Color chip for screen readers', (
        tester,
      ) async {
        final bloc = await pumpBar(tester);
        bloc
          ..add(const VideoEditorTuneValueChanged(0.4, id: 'greenHue'))
          ..add(const VideoEditorTuneColorBandSelected(AdjustColorBand.red));
        await tester.pumpAndSettle();

        expect(
          find.bySemanticsLabel(
            '${l10n.videoEditorTuneColorGreen}, ${l10n.videoEditorTuneChanged}',
          ),
          findsOneWidget,
        );
        expect(
          find.bySemanticsLabel(l10n.videoEditorTuneColorRed),
          findsOneWidget,
        );
      });
    });

    group('Curve section', () {
      testWidgets('dragging the graph moves the nearest point of the curve', (
        tester,
      ) async {
        final bloc = await pumpBar(tester);
        bloc.add(
          const VideoEditorTuneCurveChannelSelected(AdjustCurveChannel.red),
        );
        await tester.pumpAndSettle();
        expect(find.byType(VideoEditorTuneCurvePanel), findsOneWidget);

        final graph = tester.getRect(
          find
              .descendant(
                of: find.byType(VideoEditorTuneCurvePanel),
                matching: find.byType(CustomPaint),
              )
              .last,
        );
        // Grab the midtones point, in the middle, and pull it up.
        await tester.dragFrom(graph.center, const Offset(0, -30));
        await tester.pumpAndSettle();

        expect(bloc.state.valueOf('curveRedMidtones'), greaterThan(0));
        expect(bloc.state.valueOf('curveRgbMidtones'), 0);
        expect(bloc.state.section, VideoEditorTuneSection.curve);
      });

      testWidgets('a point near the straight line snaps onto it', (
        tester,
      ) async {
        final bloc = await pumpBar(tester);
        bloc.add(
          const VideoEditorTuneCurveChannelSelected(AdjustCurveChannel.rgb),
        );
        await tester.pumpAndSettle();

        final graph = tester.getRect(
          find
              .descendant(
                of: find.byType(VideoEditorTuneCurvePanel),
                matching: find.byType(CustomPaint),
              )
              .last,
        );
        // Up and back down to just beside the line.
        final gesture = await tester.startGesture(graph.center);
        await gesture.moveBy(const Offset(0, -40));
        await gesture.moveBy(const Offset(0, 39));
        await gesture.up();
        await tester.pumpAndSettle();

        expect(bloc.state.valueOf('curveRgbMidtones'), 0);
      });

      testWidgets('a screen reader raises a point a step at a time', (
        tester,
      ) async {
        final bloc = await pumpBar(tester);
        bloc.add(
          const VideoEditorTuneCurveChannelSelected(AdjustCurveChannel.blue),
        );
        await tester.pumpAndSettle();

        // The points are the graph painter's own semantics nodes.
        final midtones = find.semantics.byLabel(
          l10n.videoEditorTuneCurveMidtones,
        );
        final node = midtones.evaluate().single;
        expect(node.value, '50%');
        expect(node.increasedValue, '55%');
        tester.semantics.performAction(midtones, SemanticsAction.increase);
        await tester.pumpAndSettle();

        expect(bloc.state.valueOf('curveBlueMidtones'), closeTo(0.05, 1e-9));
      });

      testWidgets('the bar grows to fit the open section', (tester) async {
        expect(
          VideoEditorTuneBottomBar.heightFor(VideoEditorTuneSection.slider),
          VideoEditorConstants.bottomBarHeight,
        );
        expect(
          VideoEditorTuneBottomBar.heightFor(VideoEditorTuneSection.curve),
          greaterThan(
            VideoEditorTuneCurvePanel.height,
          ),
        );
        expect(
          VideoEditorTuneBottomBar.heightFor(VideoEditorTuneSection.color),
          greaterThan(VideoEditorTuneColorPanel.height),
        );
      });
    });
  });
}
