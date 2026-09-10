// ABOUTME: Tests for VideoEditorTuneBottomBar widget.
// ABOUTME: Validates adjustment chips, slider rendering, and selection.

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/blocs/video_editor/tune_editor/video_editor_tune_bloc.dart';
import 'package:openvine/constants/video_editor_constants.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/widgets/video_editor/main_editor/video_editor_scope.dart';
import 'package:openvine/widgets/video_editor/tune_editor/video_editor_tune_bottom_bar.dart';

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
      expect(find.text(l10n.videoEditorTuneFade), findsNothing);

      await tester.dragUntilVisible(
        find.text(l10n.videoEditorTuneFade),
        find.byType(ListView),
        const Offset(-120, 0),
      );

      expect(find.text(l10n.videoEditorTuneFade), findsOneWidget);
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
  });
}
