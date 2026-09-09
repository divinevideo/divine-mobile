import 'package:flutter/foundation.dart';
import 'package:models/models.dart';
import 'package:openvine/constants/video_editor_constants.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/models/video_editor/caption_track.dart';
import 'package:openvine/widgets/video_editor/video_editor_widget_layer_loader.dart';
import 'package:pro_image_editor/pro_image_editor.dart';
import 'package:unified_logger/unified_logger.dart';

/// Deserializes [CompleteParameters] from a persisted draft map, rehydrating
/// [WidgetLayer]s with [videoEditorWidgetLayerLoader].
///
/// Without a `widgetLoader`, [CompleteParameters.fromMap] throws "The
/// `widgetLoader` must be defined when importing the widget layer by id" for
/// any widget layer exported with an id, so the loader must be threaded
/// through here.
CompleteParameters completeParametersFromDraftMap(Map<String, dynamic> map) =>
    CompleteParameters.fromMap(
      map,
      widgetLoader: videoEditorWidgetLayerLoader,
    );

/// Deep equality extension for [CompleteParameters].
///
/// The built-in `==` uses reference equality for [Uint8List] `image`,
/// so two instances with identical bytes are considered unequal.
/// This extension compares all fields with proper list/byte equality.
extension CompleteParametersEquality on CompleteParameters {
  List<AudioEvent> get audioTracksFromMeta {
    try {
      final raw = meta[VideoEditorConstants.audioStateHistoryKey];
      if (raw is! List) return [];
      return raw.cast<Map<String, dynamic>>().map(AudioEvent.fromJson).toList();
    } catch (e, stackTrace) {
      Log.error(
        'Failed to parse audioTracks from meta',
        name: 'CompleteParametersEquality',
        category: LogCategory.video,
        error: e,
        stackTrace: stackTrace,
      );
      return [];
    }
  }

  /// Restores the caption track from the completion metadata, or `null` when
  /// the session has no captions (or the stored value is malformed).
  CaptionTrack? get captionTrackFromMeta {
    try {
      final raw = meta[VideoEditorConstants.captionsStateHistoryKey];
      if (raw is! Map<Object?, Object?>) return null;
      return CaptionTrack.fromJson(raw);
    } catch (e, stackTrace) {
      Log.error(
        'Failed to parse captionTrack from meta',
        name: 'CompleteParametersEquality',
        category: LogCategory.video,
        error: e,
        stackTrace: stackTrace,
      );
      return null;
    }
  }

  /// Restores [DivineVideoClip] objects from the completion metadata.
  ///
  /// [documentsPath] is required to resolve relative file paths stored in
  /// the serialized JSON back to absolute paths.
  /// The list order represents the clip playback order.
  List<DivineVideoClip> clipSnapshotsFromMeta(String documentsPath) {
    try {
      final raw = meta[VideoEditorConstants.clipsStateHistoryKey];
      if (raw is! List) return [];
      return raw
          .cast<Map<String, dynamic>>()
          .map((json) => DivineVideoClip.fromJson(json, documentsPath))
          .toList();
    } catch (e, stackTrace) {
      Log.error(
        'Failed to parse clipSnapshots from meta',
        name: 'CompleteParametersEquality',
        category: LogCategory.video,
        error: e,
        stackTrace: stackTrace,
      );
      return [];
    }
  }

  /// Returns `true` when all fields match [other] by value,
  /// including byte-level comparison of [image].
  ///
  /// Delegates to [diff] so equality and diff logging are always consistent.
  bool deepEquals(CompleteParameters other) {
    if (identical(this, other)) return true;
    return diff(other).isEmpty;
  }

  /// Returns a list of field names that differ from [other].
  List<String> diff(CompleteParameters other) {
    return <String>[
      if (blur != other.blur) 'blur',
      if (startTime != other.startTime) 'startTime',
      if (endTime != other.endTime) 'endTime',
      if (cropWidth != other.cropWidth) 'cropWidth',
      if (cropHeight != other.cropHeight) 'cropHeight',
      if (rotateTurns != other.rotateTurns) 'rotateTurns',
      if (cropX != other.cropX) 'cropX',
      if (cropY != other.cropY) 'cropY',
      if (flipX != other.flipX) 'flipX',
      if (flipY != other.flipY) 'flipY',
      if (isTransformed != other.isTransformed) 'isTransformed',
      if (!listEquals(audioTracks, other.audioTracks)) 'audioTracks',
      if (!listEquals(layers, other.layers)) 'layers',
      if (!listEquals(videoClips, other.videoClips)) 'videoClips',
      if (!listEquals(matrixFilterList, other.matrixFilterList))
        'matrixFilterList',
      if (!listEquals(
        matrixTuneAdjustmentsList,
        other.matrixTuneAdjustmentsList,
      ))
        'matrixTuneAdjustmentsList',
      if (!listEquals(image, other.image)) 'image',
    ];
  }

  /// Returns a log-friendly string representation.
  ///
  /// Truncates the `image` field to avoid flooding logs with raw bytes.
  String toLogString() {
    final map = toMap();
    final imageValue = map['image'];
    if (imageValue != null) {
      final str = imageValue.toString();
      map['image'] = str.length > 50
          ? '${str.substring(0, 50)}… (${str.length} chars)'
          : str;
    }
    return map.toString();
  }
}
