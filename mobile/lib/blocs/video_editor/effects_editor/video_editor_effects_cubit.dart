import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:openvine/models/video_editor/editor_video_effect.dart';
import 'package:pro_video_editor/pro_video_editor.dart'
    show VideoEffect, VideoEffectType;

part 'video_editor_effects_state.dart';

/// Manages the video effects of the editor: the ones committed to the
/// editor history, and the selection while the effects editor is open.
///
/// The editor history stays the source of truth for the committed effects;
/// the UI mirrors it in with [syncApplied] and writes a confirmed selection
/// back to it. The editor either adds a new effect or edits one already on
/// the timeline, see [startEditing].
class VideoEditorEffectsCubit extends Cubit<VideoEditorEffectsState> {
  VideoEditorEffectsCubit({String Function()? createId})
    : _createId = createId ?? _timestampId,
      super(const VideoEditorEffectsState());

  /// The intensity an effect starts at when it is first picked.
  static const double defaultIntensity = 0.7;

  final String Function() _createId;

  static String _timestampId() =>
      'effect_${DateTime.now().microsecondsSinceEpoch}';

  /// Mirrors the effects committed to the editor history, after an undo,
  /// redo, timeline edit or draft restore.
  void syncApplied(List<EditorVideoEffect> effects) {
    if (listEquals(effects, state.applied)) return;
    emit(state.copyWith(applied: List.unmodifiable(effects)));
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
        selectedType: current?.effect.type,
        clearSelectedType: current == null,
        intensity: current?.effect.intensity ?? defaultIntensity,
        startedPlayback: startedPlayback,
      ),
    );
  }

  /// Picks [type], or no effect for `null`.
  ///
  /// Switching to another effect keeps the intensity the user dialed in.
  void selectType(VideoEffectType? type) {
    emit(state.copyWith(selectedType: type, clearSelectedType: type == null));
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
  /// the edited effect.
  List<EditorVideoEffect> confirm() {
    final selection = state.selection;
    final picked = selection != null && selection.intensity > 0
        ? selection
        : null;
    final effects = <EditorVideoEffect>[];
    var edited = false;
    for (final entry in state.applied) {
      if (entry.id != state.editingId) {
        effects.add(entry);
        continue;
      }
      edited = true;
      if (picked == null) continue;
      effects.add(
        EditorVideoEffect(
          id: entry.id,
          effect: VideoEffect(
            type: picked.type,
            intensity: picked.intensity,
            startTime: entry.effect.startTime,
            endTime: entry.effect.endTime,
          ),
        ),
      );
    }
    if (!edited && picked != null) {
      effects.add(EditorVideoEffect(id: _createId(), effect: picked));
    }
    emit(
      state.copyWith(
        isEditing: false,
        clearEditingId: true,
        applied: List.unmodifiable(effects),
      ),
    );
    return effects;
  }
}
