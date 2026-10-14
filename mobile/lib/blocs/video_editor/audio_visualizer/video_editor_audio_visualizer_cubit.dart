// ABOUTME: Keeps how loud everything that plays in the edited video is, band
// ABOUTME: by band, for the audio visualizers the preview draws.

import 'dart:async';
import 'dart:typed_data';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:models/models.dart' show AudioEvent;
import 'package:openvine/blocs/close_guard.dart';
import 'package:openvine/constants/video_editor_constants.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/models/video_editor/transition_geometry.dart';
import 'package:openvine/services/video_editor/video_editor_audio_level_resolver.dart';
import 'package:openvine/utils/audio_band_energies.dart';
import 'package:unified_logger/unified_logger.dart';

part 'video_editor_audio_visualizer_state.dart';

/// Reads the sound of the edited video for its audio visualizers, once one is
/// on the canvas or the visualizer sheet previews it, and again whenever what
/// plays changes.
///
/// The editor history stays the source of truth for the sounds and clips; the
/// canvas mirrors them in with [syncSources] and says with [setActive]
/// whether a visualizer needs them.
class VideoEditorAudioVisualizerCubit
    extends Cubit<VideoEditorAudioVisualizerState>
    with CloseGuardedEmit<VideoEditorAudioVisualizerState> {
  VideoEditorAudioVisualizerCubit({VideoEditorAudioLevelResolver? resolver})
    : _resolver = resolver ?? VideoEditorAudioLevelResolver(),
      super(const VideoEditorAudioVisualizerState());

  final VideoEditorAudioLevelResolver _resolver;

  /// Mirrors what plays in the video: [sounds] over [clips].
  void syncSources({
    required List<AudioEvent> sounds,
    required List<DivineVideoClip> clips,
  }) {
    final timelineMap = TransitionTimelineMap.fromClips(clips);
    final outputDuration = timelineMap.outputDuration;
    final videoEnd = outputDuration < VideoEditorConstants.maxDuration
        ? outputDuration
        : VideoEditorConstants.maxDuration;
    final input = VideoEditorAudioLevelInput(
      parts: audioLevelSourcesFor(
        sounds: sounds,
        clips: clips,
        videoEnd: videoEnd,
      ),
      videoEnd: videoEnd,
    );
    final changed = input != state.input;
    // The clips can move on the video without changing what plays, so the
    // map from the editor's timeline to the video is passed on every sync.
    emit(state.copyWith(input: input, timelineMap: timelineMap));
    if (changed) unawaited(_refresh());
  }

  /// Says whether a visualizer is on the canvas; the sound is read only
  /// while one is.
  void setActive({required bool isActive}) {
    if (isActive == state.isActive) return;
    emit(state.copyWith(isActive: isActive));
    unawaited(_refresh());
  }

  /// Says whether the visualizer sheet previews the sound, which reads it
  /// before a visualizer is on the canvas.
  void setPreviewing({required bool isPreviewing}) {
    // The sheet can outlive the editor it was opened from.
    if (isClosed || isPreviewing == state.isPreviewing) return;
    emit(state.copyWith(isPreviewing: isPreviewing));
    unawaited(_refresh());
  }

  /// Reads what plays when a visualizer needs it: right away when it has
  /// been read before, and otherwise once it has been.
  ///
  /// A later sync that changes what plays wins: the energies are added up for
  /// whatever the state says plays once the sound is read.
  Future<void> _refresh() async {
    final input = state.input;
    if (input == null || !state.needsSound) return;
    if (input.parts.isEmpty) {
      emit(
        state.copyWith(
          energies: _silence(input.videoEnd),
          status: VideoEditorAudioLevelStatus.noSound,
        ),
      );
      return;
    }
    if (!_resolver.hasRead(input.parts)) {
      emit(state.copyWith(status: VideoEditorAudioLevelStatus.loading));
      try {
        await _resolver.read(input.parts);
      } on Exception catch (error, stackTrace) {
        Log.error(
          'Could not read the sound for the audio visualizer',
          name: 'VideoEditorAudioVisualizerCubit',
          category: LogCategory.video,
          error: error,
          stackTrace: stackTrace,
        );
        if (state.input == input) {
          emitIfOpen(
            state.copyWith(
              energies: _silence(input.videoEnd),
              status: VideoEditorAudioLevelStatus.failed,
            ),
          );
        }
        return;
      }
    }
    final current = state.input;
    if (current == null || !_resolver.hasRead(current.parts)) return;
    final energies = _resolver.energiesOnOutput(
      current.parts,
      videoEnd: current.videoEnd,
    );
    emitIfOpen(
      state.copyWith(
        energies: energies,
        // Clips without an audio track read as silence: nothing plays, as
        // when every clip is muted.
        status: energies.every((energy) => energy == 0)
            ? VideoEditorAudioLevelStatus.noSound
            : VideoEditorAudioLevelStatus.ready,
      ),
    );
  }

  static Float32List _silence(Duration videoEnd) => Float32List(
    (videoEnd.inMicroseconds * audioBandFrameRate / 1e6).ceil() *
        audioBandCount,
  );
}
