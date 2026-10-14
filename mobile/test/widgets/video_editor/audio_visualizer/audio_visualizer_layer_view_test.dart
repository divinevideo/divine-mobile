// ABOUTME: Tests the audio visualizer layer on the canvas: its shape, and that
// ABOUTME: it draws the sound once read and rests without the editor.

import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:models/models.dart' as model show AspectRatio;
import 'package:models/models.dart' show AudioEvent;
import 'package:openvine/blocs/video_editor/audio_visualizer/video_editor_audio_visualizer_cubit.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/models/video_editor/audio_visualizer_layer.dart';
import 'package:openvine/services/video_editor/video_editor_audio_level_resolver.dart';
import 'package:openvine/widgets/video_editor/audio_visualizer/audio_visualizer_layer_view.dart';
import 'package:pro_video_editor/pro_video_editor.dart';

import '../../../helpers/audio_samples.dart';

const _bars = AudioVisualizerLayerData(color: VineTheme.whiteText);

/// A steady 1 kHz tone of the stretch [configs] asks for.
Future<Uint8List> _toneWav(AudioExtractConfigs configs) async {
  final from = configs.startTime ?? Duration.zero;
  final to = configs.endTime ?? const Duration(seconds: 30);
  final samples = silentAudio(to - from);
  for (var i = 0; i < samples.length; i++) {
    samples[i] = 0.5 * math.sin(2 * math.pi * 1000 * i / testSampleRate);
  }
  return wavBytes(samples);
}

void main() {
  group(AudioVisualizerLayerView, () {
    const boundaryKey = Key('visualizer');

    Widget visualizer({VideoEditorAudioVisualizerCubit? cubit}) {
      const view = Directionality(
        textDirection: TextDirection.ltr,
        child: Center(
          child: SizedBox(
            width: 240,
            child: RepaintBoundary(
              key: boundaryKey,
              child: AudioVisualizerLayerView(data: _bars),
            ),
          ),
        ),
      );
      return cubit == null
          ? view
          : BlocProvider.value(value: cubit, child: view);
    }

    /// The alpha of the pixel at ([x], [y]) of the drawn visualizer.
    Future<int> alphaAt(WidgetTester tester, int x, int y) async {
      final boundary =
          tester.renderObject(find.byKey(boundaryKey)) as RenderRepaintBoundary;
      final bytes = await tester.runAsync(() async {
        final image = await boundary.toImage();
        final data = await image.toByteData();
        image.dispose();
        return data!;
      });
      final width = boundary.size.width.round();
      return bytes!.getUint8((y * width + x) * 4 + 3);
    }

    group('renders', () {
      testWidgets("a box of its style's shape", (tester) async {
        await tester.pumpWidget(visualizer());

        expect(
          tester.getSize(find.byType(AudioVisualizerLayerView)),
          const Size(240, 80),
        );
      });

      testWidgets('inside a box that does not bound it, as the canvas lays '
          'out a widget layer', (tester) async {
        // The canvas puts a widget layer in a FittedBox, which lays it out
        // without bounds, and scales it to the layer's width.
        await tester.pumpWidget(
          const Directionality(
            textDirection: TextDirection.ltr,
            child: Center(
              child: SizedBox(
                width: 120,
                child: FittedBox(child: AudioVisualizerLayerView(data: _bars)),
              ),
            ),
          ),
        );

        expect(tester.takeException(), isNull);
        expect(
          tester.getSize(find.byType(FittedBox).first),
          const Size(120, 40),
        );
      });

      testWidgets('at rest without the editor around it', (tester) async {
        await tester.pumpWidget(visualizer());

        // 24 bars ten pixels apart: the first one is a 7 px dot at the
        // bottom, with nothing above it.
        expect(await alphaAt(tester, 5, 76), 255);
        expect(await alphaAt(tester, 5, 10), 0);
        expect(tester.takeException(), isNull);
      });

      testWidgets('the sound once it is read', (tester) async {
        final music = AudioEvent(
          id: 'music',
          pubkey: 'a' * 64,
          createdAt: 1735689600,
          url: '/tmp/music.mp3',
          duration: 30,
        );
        final mutedClip = DivineVideoClip(
          id: 'clip',
          video: EditorVideo.file('${Directory.systemTemp.path}/clip.mp4'),
          duration: const Duration(seconds: 1),
          recordedAt: DateTime(2026),
          targetAspectRatio: model.AspectRatio.vertical,
          originalAspectRatio: 9 / 16,
          volume: 0,
        );
        final cubit = VideoEditorAudioVisualizerCubit(
          resolver: VideoEditorAudioLevelResolver(extractAudio: _toneWav),
        );
        addTearDown(cubit.close);

        await tester.pumpWidget(visualizer(cubit: cubit));
        await tester.runAsync(() async {
          cubit
            ..syncSources(sounds: [music], clips: [mutedClip])
            ..setActive(isActive: true);
          await cubit.stream.firstWhere(
            (state) => state.status == VideoEditorAudioLevelStatus.ready,
          );
        });
        await tester.pump();

        // A 1 kHz tone is band 12 of 24: its bar stands the full height,
        // while the first band stays a dot.
        expect(await alphaAt(tester, 125, 10), 255);
        expect(await alphaAt(tester, 5, 10), 0);
      });
    });
  });
}
