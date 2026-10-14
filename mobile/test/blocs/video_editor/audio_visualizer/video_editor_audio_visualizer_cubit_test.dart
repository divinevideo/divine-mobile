// ABOUTME: Tests when the editor reads the sound for its audio visualizers
// ABOUTME: and what it tells them while it does.

import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:models/models.dart' as model show AspectRatio;
import 'package:models/models.dart' show AudioEvent;
import 'package:openvine/blocs/video_editor/audio_visualizer/video_editor_audio_visualizer_cubit.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/services/video_editor/video_editor_audio_level_resolver.dart';
import 'package:openvine/utils/audio_band_energies.dart';
import 'package:pro_video_editor/pro_video_editor.dart';

import '../../../helpers/audio_samples.dart';

void main() {
  group(VideoEditorAudioVisualizerCubit, () {
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

    /// A cubit whose sound reads as a kick every half second, or fails to
    /// read with [failure].
    VideoEditorAudioVisualizerCubit buildCubit({
      List<AudioExtractConfigs>? reads,
      Object? failure,
    }) => VideoEditorAudioVisualizerCubit(
      resolver: VideoEditorAudioLevelResolver(
        extractAudio: (configs) async {
          reads?.add(configs);
          if (failure != null) throw failure;
          return drumLoopWav(configs);
        },
      ),
    );

    Future<VideoEditorAudioVisualizerState> settled(
      VideoEditorAudioVisualizerCubit cubit,
    ) => cubit.state.status == VideoEditorAudioLevelStatus.loading
        ? cubit.stream.firstWhere(
            (state) => state.status != VideoEditorAudioLevelStatus.loading,
          )
        : Future.value(cubit.state);

    test('reads nothing until a visualizer is on the canvas', () async {
      final reads = <AudioExtractConfigs>[];
      final cubit = buildCubit(reads: reads)
        ..syncSources(sounds: [music], clips: [mutedClip]);

      expect(cubit.state.status, VideoEditorAudioLevelStatus.idle);
      expect(cubit.state.energies, isNull);
      expect(reads, isEmpty);
      await cubit.close();
    });

    test('reads the sound once a visualizer needs it', () async {
      final reads = <AudioExtractConfigs>[];
      final cubit = buildCubit(reads: reads)
        ..syncSources(sounds: [music], clips: [mutedClip])
        ..setActive(isActive: true);
      final state = await settled(cubit);

      expect(state.status, VideoEditorAudioLevelStatus.ready);
      // Two seconds of video, 60 rows a second.
      expect(state.energies, hasLength(120 * audioBandCount));
      expect(state.energies!.any((energy) => energy > 0), isTrue);
      expect(reads, hasLength(1));
      await cubit.close();
    });

    test('reads the sound for the sheet preview before a visualizer is on '
        'the canvas', () async {
      final reads = <AudioExtractConfigs>[];
      final cubit = buildCubit(reads: reads)
        ..syncSources(sounds: [music], clips: [mutedClip])
        ..setPreviewing(isPreviewing: true);
      final state = await settled(cubit);

      expect(state.status, VideoEditorAudioLevelStatus.ready);
      expect(state.energies!.any((energy) => energy > 0), isTrue);
      expect(reads, hasLength(1));
      await cubit.close();
    });

    test('keeps what it read when the same sound is synced again', () async {
      final reads = <AudioExtractConfigs>[];
      final cubit = buildCubit(reads: reads)
        ..syncSources(sounds: [music], clips: [mutedClip])
        ..setActive(isActive: true);
      final first = await settled(cubit);
      expect(first.energies, isNotNull);

      cubit.syncSources(sounds: [music], clips: [mutedClip]);

      expect(identical(cubit.state.energies, first.energies), isTrue);
      expect(reads, hasLength(1));
      await cubit.close();
    });

    test('passes on the map from the editor timeline to the video', () async {
      final cubit = buildCubit()
        ..syncSources(sounds: const [], clips: [mutedClip]);

      expect(cubit.state.timelineMap?.outputDuration, mutedClip.duration);
      await cubit.close();
    });

    test('says when nothing makes a sound or it cannot be read', () async {
      final silent = buildCubit()
        ..syncSources(sounds: const [], clips: [mutedClip])
        ..setActive(isActive: true);
      final silentState = await settled(silent);
      expect(silentState.status, VideoEditorAudioLevelStatus.noSound);
      expect(silentState.energies!.every((energy) => energy == 0), isTrue);

      // A clip without an audio track plays nothing either.
      final noTrack = buildCubit(failure: const AudioNoTrackException())
        ..syncSources(sounds: const [], clips: [mutedClip.copyWith(volume: 1)])
        ..setActive(isActive: true);
      final noTrackState = await settled(noTrack);
      expect(noTrackState.status, VideoEditorAudioLevelStatus.noSound);
      expect(noTrackState.energies!.every((energy) => energy == 0), isTrue);

      final unreadable = buildCubit(failure: PlatformException(code: 'gone'))
        ..syncSources(sounds: [music], clips: [mutedClip])
        ..setActive(isActive: true);
      expect(
        (await settled(unreadable)).status,
        VideoEditorAudioLevelStatus.failed,
      );
      await silent.close();
      await noTrack.close();
      await unreadable.close();
    });

    test('follows a sound that failed once when it is read again', () async {
      var failMusic = true;
      final cubit = VideoEditorAudioVisualizerCubit(
        resolver: VideoEditorAudioLevelResolver(
          extractAudio: (configs) async {
            final video = configs.video;
            final source =
                video.file?.path ?? video.networkUrl ?? video.assetPath ?? '';
            if (failMusic && source.contains('music')) {
              throw PlatformException(code: 'busy');
            }
            return drumLoopWav(configs);
          },
        ),
      );
      final clip = mutedClip.copyWith(volume: 1);
      cubit
        ..syncSources(sounds: [music], clips: [clip])
        ..setActive(isActive: true);
      final clipOnly = await settled(cubit);
      expect(clipOnly.status, VideoEditorAudioLevelStatus.ready);

      failMusic = false;
      cubit
        ..setActive(isActive: false)
        ..setActive(isActive: true);
      final both = await settled(cubit);

      final clipEnergy = clipOnly.energies!.fold(0.0, (a, b) => a + b);
      final bothEnergy = both.energies!.fold(0.0, (a, b) => a + b);
      expect(bothEnergy, greaterThan(clipEnergy * 1.5));
      await cubit.close();
    });

    test('says it cannot read the sound when the platform returns no '
        'audio', () async {
      final cubit =
          buildCubit(
              failure: ArgumentError('Failed to extract audio from video'),
            )
            ..syncSources(sounds: [music], clips: [mutedClip])
            ..setActive(isActive: true);

      expect(
        (await settled(cubit)).status,
        VideoEditorAudioLevelStatus.failed,
      );
      await cubit.close();
    });
  });
}
