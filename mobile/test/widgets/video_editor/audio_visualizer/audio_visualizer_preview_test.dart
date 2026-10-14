// ABOUTME: Tests the live preview of the visualizer sheet: it moves, holds
// ABOUTME: still with reduced motion, and follows the video's sound once read.

import 'dart:io';
import 'dart:typed_data';

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:models/models.dart' as model show AspectRatio;
import 'package:models/models.dart' show AudioEvent;
import 'package:openvine/blocs/video_editor/audio_visualizer/video_editor_audio_visualizer_cubit.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/models/video_editor/audio_visualizer_layer.dart';
import 'package:openvine/services/video_editor/video_editor_audio_level_resolver.dart';
import 'package:openvine/widgets/video_editor/audio_visualizer/audio_visualizer_preview.dart';
import 'package:pro_video_editor/pro_video_editor.dart' show EditorVideo;

import '../../../helpers/audio_samples.dart';

void main() {
  group(AudioVisualizerPreview, () {
    final l10n = lookupAppLocalizations(const Locale('en'));
    const boundaryKey = Key('preview');

    Widget preview({
      VideoEditorAudioVisualizerCubit? soundLevels,
      bool reduceMotion = false,
    }) => MaterialApp(
      localizationsDelegates: appLocalizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(disableAnimations: reduceMotion),
        child: child!,
      ),
      home: Center(
        child: SizedBox(
          width: 300,
          child: RepaintBoundary(
            key: boundaryKey,
            child: AudioVisualizerPreview(
              data: const AudioVisualizerLayerData(
                color: VineTheme.whiteText,
              ),
              soundLevels: soundLevels,
            ),
          ),
        ),
      ),
    );

    /// The pixels the preview shows right now.
    Future<Uint8List> pixels(WidgetTester tester) async {
      final boundary =
          tester.renderObject(find.byKey(boundaryKey)) as RenderRepaintBoundary;
      final bytes = await tester.runAsync(() async {
        final image = await boundary.toImage();
        final data = await image.toByteData();
        image.dispose();
        return data!;
      });
      return bytes!.buffer.asUint8List();
    }

    /// How many pixels are drawn white, the visualizer's color.
    int whitePixels(Uint8List rgba) {
      var count = 0;
      for (var i = 0; i < rgba.length; i += 4) {
        if (rgba[i] > 200 && rgba[i + 1] > 200 && rgba[i + 2] > 200) count++;
      }
      return count;
    }

    group('renders', () {
      testWidgets("a sample beat that moves, saying so, without the video's "
          'sound', (tester) async {
        await tester.pumpWidget(preview());
        await tester.pump(const Duration(milliseconds: 50));
        final onBeat = await pixels(tester);
        await tester.pump(const Duration(milliseconds: 200));
        final offBeat = await pixels(tester);

        expect(
          find.text(l10n.videoEditorAudioVisualizerPreviewSampleBeat),
          findsOneWidget,
        );
        expect(whitePixels(onBeat), isNot(whitePixels(offBeat)));
      });

      testWidgets('the loudest moment, held still, with reduced motion', (
        tester,
      ) async {
        await tester.pumpWidget(preview(reduceMotion: true));
        final first = await pixels(tester);
        await tester.pump(const Duration(milliseconds: 250));
        final later = await pixels(tester);

        expect(whitePixels(first), greaterThan(0));
        expect(later, first);
        expect(tester.binding.hasScheduledFrame, isFalse);
      });
    });

    testWidgets("follows the video's sound once read, and asks for it only "
        'while it is open', (tester) async {
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
        duration: const Duration(seconds: 2),
        recordedAt: DateTime(2026),
        targetAspectRatio: model.AspectRatio.vertical,
        originalAspectRatio: 9 / 16,
        volume: 0,
      );
      final soundLevels = VideoEditorAudioVisualizerCubit(
        resolver: VideoEditorAudioLevelResolver(
          extractAudio: (configs) async => drumLoopWav(configs),
        ),
      );
      addTearDown(soundLevels.close);
      // Reading runs on an isolate, which the fake clock of a widget test
      // never lets finish, so the sound is read before the preview opens.
      await tester.runAsync(() async {
        soundLevels
          ..syncSources(sounds: [music], clips: [mutedClip])
          ..setActive(isActive: true);
        await soundLevels.stream.firstWhere(
          (state) => state.status == VideoEditorAudioLevelStatus.ready,
        );
        soundLevels.setActive(isActive: false);
      });

      await tester.pumpWidget(preview(soundLevels: soundLevels));
      await tester.pump();

      expect(soundLevels.state.isPreviewing, isTrue);
      expect(
        find.text(l10n.videoEditorAudioVisualizerPreviewSampleBeat),
        findsNothing,
      );

      await tester.pumpWidget(const SizedBox());
      expect(soundLevels.state.isPreviewing, isFalse);
    });
  });
}
