import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:models/models.dart' show AudioEvent;
import 'package:openvine/blocs/close_guard.dart';
import 'package:openvine/constants/video_editor_constants.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/models/video_editor/editor_video_effect.dart';
import 'package:openvine/models/video_editor/transition_geometry.dart';
import 'package:openvine/services/video_editor/video_editor_beat_resolver.dart';
import 'package:pro_video_editor/pro_video_editor.dart' show CustomVideoEffect;
import 'package:unified_logger/unified_logger.dart';
import 'package:uuid/uuid.dart';

part 'video_editor_effects_state.dart';

/// Manages the video effects of the editor: the ones committed to the
/// editor history, and the selection while the effects editor is open.
///
/// The editor history stays the source of truth for the committed effects;
/// the UI mirrors it in with [syncApplied] and writes a confirmed selection
/// back to it. The editor either adds a new effect or edits one already on
/// the timeline, see [startEditing].
///
/// While an effect fires on the beat, the cubit also keeps the beats of the
/// video's music, from what [syncBeatSource] last said plays.
class VideoEditorEffectsCubit extends Cubit<VideoEditorEffectsState>
    with CloseGuardedEmit<VideoEditorEffectsState> {
  VideoEditorEffectsCubit({
    String Function()? createId,
    VideoEditorBeatResolver? beatResolver,
  }) : _createId = createId ?? _uniqueId,
       _beatResolver = beatResolver ?? VideoEditorBeatResolver(),
       super(const VideoEditorEffectsState());

  /// The intensity an effect starts at when it is first picked.
  static const double defaultIntensity = 0.7;

  final String Function() _createId;
  final VideoEditorBeatResolver _beatResolver;

  static const _uuid = Uuid();

  static String _uniqueId() => 'effect_${_uuid.v4()}';

  /// Mirrors the effects committed to the editor history, after an undo,
  /// redo, timeline edit or draft restore.
  void syncApplied(List<EditorVideoEffect> effects) {
    if (listEquals(effects, state.applied)) return;
    emit(state.copyWith(applied: List.unmodifiable(effects)));
    unawaited(_refreshBeats());
  }

  /// Mirrors what plays in the video, [sounds] over [clips], which the beats
  /// of effects on the beat come from.
  void syncBeatSource({
    required List<AudioEvent> sounds,
    required List<DivineVideoClip> clips,
  }) {
    final timelineMap = TransitionTimelineMap.fromClips(clips);
    final outputDuration = timelineMap.outputDuration;
    final videoEnd = outputDuration < VideoEditorConstants.maxDuration
        ? outputDuration
        : VideoEditorConstants.maxDuration;
    emit(
      state.copyWith(
        beatInput: VideoEditorBeatInput(
          parts: beatSourceFor(
            sounds: sounds,
            clips: clips,
            videoEnd: videoEnd,
          ),
          videoEnd: videoEnd,
        ),
      ),
    );
    unawaited(_refreshBeats());
  }

  /// Opens the editor to add a new effect, or on the committed effect with
  /// [effectId] to change it in place, keeping its window on the timeline.
  ///
  /// An unknown [effectId] adds a new effect. Pass [startedPlayback] when
  /// opening the editor started the video, so closing it can pause it again.
  void startEditing({String? effectId, bool startedPlayback = false}) {
    final current = state.applied.where((e) => e.id == effectId).firstOrNull;
    emit(
      state.copyWith(
        isEditing: true,
        editingId: current?.id,
        clearEditingId: current == null,
        selectedType: current?.type,
        clearSelectedType: current == null,
        intensity: current?.intensity ?? defaultIntensity,
        onBeat: current?.onBeat ?? false,
        startedPlayback: startedPlayback,
      ),
    );
    unawaited(_refreshBeats());
  }

  /// Picks [type], or no effect for `null`.
  ///
  /// Switching to another effect keeps the intensity the user dialed in.
  void selectType(EditorEffectType? type) {
    emit(state.copyWith(selectedType: type, clearSelectedType: type == null));
    unawaited(_refreshBeats());
  }

  /// Makes the picked effect fire on the beat, or play all through its window.
  ///
  /// Kept for the next effect picked; it only applies to one that
  /// [EditorEffectType.supportsOnBeat].
  void setOnBeat({required bool onBeat}) {
    emit(state.copyWith(onBeat: onBeat));
    unawaited(_refreshBeats());
  }

  /// Sets the intensity of the picked effect, clamped to 0..1.
  void setIntensity(double intensity) {
    emit(state.copyWith(intensity: intensity.clamp(0.0, 1.0)));
  }

  /// Closes the editor without changing the committed effects.
  void cancel() => emit(state.copyWith(isEditing: false, clearEditingId: true));

  /// Closes the editor and returns the effects to commit to the history.
  ///
  /// A new effect is added over the whole video; an edited one keeps its
  /// window and place in the list. Picking no effect adds nothing, or removes
  /// the edited effect. A flashing effect replaces other flashing effects in
  /// its window (see [withoutFlashingOverlaps]); `replacedFlashing` says so,
  /// for the UI to explain.
  ({List<EditorVideoEffect> effects, bool replacedFlashing}) confirm() {
    final selection = state.selection;
    final picked = selection != null && selection.intensity > 0
        ? selection
        : null;
    var effects = <EditorVideoEffect>[];
    String? committedId;
    for (final entry in state.applied) {
      if (entry.id != state.editingId) {
        effects.add(entry);
        continue;
      }
      committedId = entry.id;
      if (picked == null) continue;
      effects.add(
        EditorVideoEffect.of(
          id: entry.id,
          type: picked.type,
          intensity: picked.intensity,
          startTime: entry.startTime,
          endTime: entry.endTime,
          onBeat: picked.onBeat,
        ),
      );
    }
    if (committedId == null && picked != null) {
      committedId = _createId();
      effects.add(picked.withId(committedId));
    }

    final separated = picked == null || committedId == null
        ? null
        : withoutFlashingOverlaps(
            effects,
            keepId: committedId,
            createId: _createId,
          );
    effects = separated ?? effects;

    emit(
      state.copyWith(
        isEditing: false,
        clearEditingId: true,
        applied: List.unmodifiable(effects),
      ),
    );
    return (effects: effects, replacedFlashing: separated != null);
  }

  /// Finds the beats when an effect needs them: right away when their music
  /// has been read before, and otherwise once it has been.
  ///
  /// A later call that changes what plays wins: the beats are placed with
  /// whatever the state says plays once the music is read.
  Future<void> _refreshBeats() async {
    final input = state.beatInput;
    if (input == null || !state.needsBeats) return;
    if (input.parts.isEmpty) {
      emit(
        state.copyWith(
          beats: const [],
          beatStatus: VideoEditorBeatStatus.noSound,
        ),
      );
      return;
    }
    if (!_beatResolver.hasRead(input.parts)) {
      emit(state.copyWith(beatStatus: VideoEditorBeatStatus.loading));
      try {
        await _beatResolver.read(input.parts);
      } on Exception catch (error, stackTrace) {
        Log.error(
          'Could not read the beats of the music',
          name: 'VideoEditorEffectsCubit',
          category: LogCategory.video,
          error: error,
          stackTrace: stackTrace,
        );
        if (state.beatInput == input) {
          emitIfOpen(
            state.copyWith(
              beats: const [],
              beatStatus: VideoEditorBeatStatus.failed,
            ),
          );
        }
        return;
      }
    }
    final current = state.beatInput;
    if (current == null || !_beatResolver.hasRead(current.parts)) return;
    emitIfOpen(
      state.copyWith(
        beats: _beatResolver.beatsOnOutput(
          current.parts,
          videoEnd: current.videoEnd,
        ),
        beatStatus: VideoEditorBeatStatus.ready,
      ),
    );
  }
}
