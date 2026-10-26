// ABOUTME: The Adjust controls a colour matrix cannot draw — highlights,
// ABOUTME: shadows, vibrance and sharpening — as Divine's native effect.

import 'package:openvine/extensions/tune_adjustment_matrix_extensions.dart';
import 'package:pro_image_editor/pro_image_editor.dart';
import 'package:pro_video_editor/pro_video_editor.dart' show CustomVideoEffect;

/// The id the Adjust controls below are registered under with
/// pro_video_editor and divine_video_player, by the native
/// `AdjustVideoEffect` on Android, iOS and macOS (#10392).
const adjustVideoEffectId = 'divine.adjust';

/// The Adjust controls a colour matrix cannot express, which are also the
/// native effect's params.
///
/// Every other Adjust control, and every filter, reaches the video as a 4×5
/// colour matrix, which changes every pixel the same way. Highlights,
/// shadows and vibrance depend on each pixel's own brightness or saturation,
/// and sharpening on its neighbours, so these are drawn by the native
/// effect, for the editor preview and the export alike. They stay
/// `TuneAdjustmentMatrix` members of their Adjust set with an identity
/// matrix, so the timeline, undo and drafts treat them like the others.
const adjustVideoEffectKinds = {'highlights', 'shadows', 'vibrance', 'sharpen'};

/// The effect that draws [values], adjustment kind to value, between
/// [startTime] and [endTime], or `null` when none of
/// [adjustVideoEffectKinds] is set.
CustomVideoEffect? adjustVideoEffect(
  Map<String, double> values, {
  Duration? startTime,
  Duration? endTime,
}) {
  final params = <String, Object?>{
    for (final kind in adjustVideoEffectKinds)
      if (values[kind] case final value? when value != 0) kind: value,
  };
  if (params.isEmpty) return null;
  return CustomVideoEffect(
    id: adjustVideoEffectId,
    params: params,
    startTime: startTime,
    endTime: endTime,
  );
}

/// One effect for every Adjust set in [adjustments] that sets any of
/// [adjustVideoEffectKinds], over the set's time window, in the order the
/// sets come in.
///
/// The preview and the export both draw these after the effects editor's own
/// custom effects (Echo, Drops, Fisheye) and before the colour matrices. An
/// effect that reads earlier frames, like Echo, gets them unprocessed in the
/// preview and in the iOS export, but in the Android export from the effect
/// before it in the chain. Running Adjust last keeps it out of those frames, so
/// Echo's trail looks the same everywhere, and Adjust then grades the finished
/// picture, as brightness and contrast do.
List<CustomVideoEffect> adjustVideoEffectsOf(
  List<TuneAdjustmentMatrix> adjustments,
) => [
  for (final members in TuneSet.groupBySet(adjustments).values)
    ?adjustVideoEffect(
      {for (final member in members) member.tuneKind: member.value},
      // The window the set's timeline bar shows.
      startTime: members.first.startTime,
      endTime: members.first.endTime,
    ),
];

/// The Adjust effects the editor preview shows.
///
/// While the Adjust editor is open, [session] holds its sliders, which show
/// over the whole video and without the other sets, the way the editor
/// previews its colour matrix. Otherwise the [applied] sets show, each over
/// its own time window.
List<CustomVideoEffect> previewAdjustVideoEffects({
  required List<TuneAdjustmentMatrix> applied,
  Map<String, double>? session,
}) => session == null
    ? adjustVideoEffectsOf(applied)
    : [?adjustVideoEffect(session)];
