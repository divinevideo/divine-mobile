// ABOUTME: Tests for the split-screen layout preview: reframing one cell
// ABOUTME: leaves the others as they were, and a broken poster stays blank

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
import 'package:openvine/widgets/video_editor/split_screen_layout/split_screen_layout_preview.dart';
import 'package:pro_video_editor/pro_video_editor.dart' show EditorVideo;

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
      List<DivineVideoClip> clips,
    ) async {
      final cubit = SplitScreenLayoutCubit(
        aspectRatio: model.AspectRatio.vertical,
        borderColor: VineTheme.backgroundColor,
      )..clipsPicked(clips);
      addTearDown(cubit.close);
      await tester.pumpWidget(
        MaterialApp(
          theme: VineTheme.theme,
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
