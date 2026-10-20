// ABOUTME: Tests for the split-screen layout preview: reframing one cell
// ABOUTME: leaves the others alone, posters and rings read in both modes

import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:models/models.dart' as model show AspectRatio;
import 'package:openvine/blocs/video_editor/split_screen_layout/split_screen_layout_cubit.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/models/stop_motion_clip_frame.dart';
import 'package:openvine/models/video_editor/split_screen_layout.dart';
import 'package:openvine/widgets/video_editor/split_screen_layout/split_screen_layout_preview.dart';
import 'package:pro_video_editor/pro_video_editor.dart' show EditorVideo;

import '../../../helpers/contrast.dart';

DivineVideoClip _clip(String id) => DivineVideoClip(
  id: id,
  video: EditorVideo.file('/documents/$id.mp4'),
  duration: const Duration(seconds: 2),
  recordedAt: DateTime(2026),
  targetAspectRatio: .vertical,
  originalAspectRatio: 9 / 16,
);

/// Completes once [provider] has loaded its image or failed to.
///
/// Run it through `tester.runAsync` before the cell is pumped: the load
/// then happens outside the test's fake clock, and the cell's own image
/// finds the result already in the cache.
Future<void> _settled(ImageProvider provider) {
  final settled = Completer<void>();
  final stream = provider.resolve(ImageConfiguration.empty);
  late final ImageStreamListener listener;
  void done() {
    stream.removeListener(listener);
    if (!settled.isCompleted) settled.complete();
  }

  listener = ImageStreamListener((_, _) => done(), onError: (_, _) => done());
  stream.addListener(listener);
  return settled.future;
}

void main() {
  group(SplitScreenLayoutPreview, () {
    final l10n = lookupAppLocalizations(const Locale('en'));

    Future<SplitScreenLayoutCubit> pump(
      WidgetTester tester,
      List<DivineVideoClip> clips, {
      ThemeData? theme,
    }) async {
      final cubit = SplitScreenLayoutCubit(
        aspectRatio: model.AspectRatio.vertical,
        borderColor: VineTheme.backgroundColor,
      )..clipsPicked(clips);
      addTearDown(cubit.close);
      await tester.pumpWidget(
        MaterialApp(
          theme: theme ?? VineTheme.theme,
          localizationsDelegates: appLocalizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: BlocProvider.value(
              value: cubit,
              child: const SplitScreenLayoutPreview(),
            ),
          ),
        ),
      );
      return cubit;
    }

    testWidgets('leaves the other cells alone while one is reframed', (
      tester,
    ) async {
      final cubit = await pump(tester, [_clip('a'), _clip('b')]);
      final second = find.byWidgetPredicate(
        (widget) =>
            widget is Semantics &&
            widget.properties.label ==
                l10n.videoEditorLayoutCellSemanticLabel('2'),
      );
      final before = tester.widget(second);

      cubit.cellReframed(
        0,
        focalPoint: Offset.zero,
        delta: const Offset(10, 0),
        zoom: 2,
        cellSize: const Size(90, 320),
      );
      await tester.pump();

      expect(cubit.state.cells.first!.zoom, 2);
      expect(identical(tester.widget(second), before), isTrue);
    });

    for (final (name, theme) in [
      ('dark', VineTheme.theme),
      ('light', VineTheme.lightTheme),
    ]) {
      for (final (kind, clips, label) in [
        (
          'an empty',
          <DivineVideoClip>[],
          l10n.videoEditorLayoutCellEmptySemanticLabel('1'),
        ),
        (
          'a posterless',
          [_clip('a')],
          l10n.videoEditorLayoutCellSemanticLabel('1'),
        ),
      ]) {
        testWidgets('rings $kind selected cell at 3:1 or more in $name mode', (
          tester,
        ) async {
          final cubit = await pump(tester, clips, theme: theme);
          cubit.cellSelected(0);
          await tester.pumpAndSettle();
          final cell = find.byWidgetPredicate(
            (widget) => widget is Semantics && widget.properties.label == label,
          );
          final ring =
              (tester
                              .widget<AnimatedContainer>(
                                find.descendant(
                                  of: cell,
                                  matching: find.byType(AnimatedContainer),
                                ),
                              )
                              .decoration!
                          as BoxDecoration)
                      .border!
                  as Border;
          final fill = tester
              .widget<ColoredBox>(
                find.descendant(of: cell, matching: find.byType(ColoredBox)),
              )
              .color;
          // An empty cell is translucent over the layout's border colour.
          final ground = Color.alphaBlend(fill, cubit.state.borderColor);
          final ratio = contrastRatio(ring.top.color, ground);

          expect(cubit.state.selectedCellIndex, 0);
          expect(
            ratio,
            greaterThanOrEqualTo(3),
            reason: '$kind cell, $name: ${ratio.toStringAsFixed(2)}:1',
          );
        });
      }
    }

    testWidgets('moves the cells when the gap or the layout changes', (
      tester,
    ) async {
      final cubit = await pump(tester, [_clip('a'), _clip('b')]);
      final first = find.byWidgetPredicate(
        (widget) =>
            widget is Semantics &&
            widget.properties.label ==
                l10n.videoEditorLayoutCellSemanticLabel('1'),
      );
      final sideBySide = tester.getRect(first);

      cubit.gapChanged(SplitScreenLayoutGeometry.maxGap);
      await tester.pump();
      final withGap = tester.getRect(first);

      cubit.presetSelected(SplitScreenLayoutPreset.stacked);
      await tester.pump();
      final stacked = tester.getRect(first);

      expect(withGap, isNot(sideBySide));
      expect(withGap.width, lessThan(sideBySide.width));
      expect(stacked.width, greaterThan(withGap.width));
    });

    testWidgets('labels a filled cell with how long its clip plays', (
      tester,
    ) async {
      await pump(tester, [_clip('a').copyWith(playbackSpeed: 2)]);

      expect(find.text(l10n.libraryClipDuration('1.00')), findsOneWidget);
    });

    testWidgets('labels a short stop-motion set with its looped length', (
      tester,
    ) async {
      // A pick drops stills whose files are gone, so these have to exist.
      final directory = Directory.systemTemp.createTempSync('layout_set');
      addTearDown(() => directory.deleteSync(recursive: true));
      final file = File('${directory.path}/still.jpg')..writeAsBytesSync([0]);
      final still = StopMotionClipFrame(
        path: file.path,
        duration: const Duration(milliseconds: 100),
      );
      await pump(tester, [
        DivineVideoClip(
          id: 'set',
          stopMotionFrames: [still, still, still],
          duration: const Duration(milliseconds: 300),
          recordedAt: DateTime(2026),
          targetAspectRatio: .vertical,
          originalAspectRatio: 9 / 16,
        ),
      ]);

      expect(find.text(l10n.libraryClipDuration('1.20')), findsOneWidget);
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is Semantics &&
              widget.properties.value == l10n.libraryClipDuration('1.20'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('shows a poster that cannot be decoded as a blank frame', (
      tester,
    ) async {
      final directory = Directory.systemTemp.createTempSync('layout_poster');
      addTearDown(() => directory.deleteSync(recursive: true));
      final poster = File('${directory.path}/poster.jpg')
        ..writeAsBytesSync(const [1, 2, 3]);
      addTearDown(
        () => PaintingBinding.instance.imageCache.evict(FileImage(poster)),
      );

      await tester.runAsync(() => _settled(FileImage(poster)));
      await pump(tester, [_clip('a').copyWith(thumbnailPath: poster.path)]);
      await tester.pump();

      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is ColoredBox &&
              widget.color == VineTheme.darkColors.surfaceContainerHigh,
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('shows a poster that can be decoded', (tester) async {
      final directory = Directory.systemTemp.createTempSync('layout_poster');
      addTearDown(() => directory.deleteSync(recursive: true));
      final poster = File('${directory.path}/poster.png');
      await tester.runAsync(() async {
        final recorder = ui.PictureRecorder();
        ui.Canvas(recorder).drawColor(const Color(0xFF00FF00), BlendMode.src);
        final image = await recorder.endRecording().toImage(9, 16);
        final png = await image.toByteData(format: ui.ImageByteFormat.png);
        image.dispose();
        poster.writeAsBytesSync(png!.buffer.asUint8List());
      });
      addTearDown(
        () => PaintingBinding.instance.imageCache.evict(FileImage(poster)),
      );

      await tester.runAsync(() => _settled(FileImage(poster)));
      await pump(tester, [_clip('a').copyWith(thumbnailPath: poster.path)]);
      await tester.pump();

      expect(
        find.byWidgetPredicate(
          (widget) => widget is RawImage && widget.image != null,
        ),
        findsOneWidget,
      );
    });
  });
}
