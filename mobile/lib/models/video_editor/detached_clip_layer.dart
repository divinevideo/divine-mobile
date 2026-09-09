// ABOUTME: Metadata identifying a WidgetLayer as a clip detached from the
// ABOUTME: timeline, so the canvas and the renderer can treat it as video

import 'package:openvine/models/divine_video_clip.dart';
import 'package:pro_image_editor/pro_image_editor.dart';

/// Marks a [WidgetLayer]'s export meta as a clip that was detached from the
/// timeline.
///
/// Stickers use the same `meta` channel, so the two are told apart by this key
/// rather than by widget type: after a draft round-trip the widget is rebuilt
/// from `meta` alone, and by then the original widget is long gone.
const String detachedClipLayerKind = 'divine.detachedClip';

/// Key under which [detachedClipLayerKind] is written.
const String detachedClipLayerKindKey = 'kind';

/// Key under which the serialized [DivineVideoClip] is written.
const String detachedClipLayerClipKey = 'clip';

/// Key under which the clip's playback length is written, in microseconds.
const String detachedClipLayerDurationKey = 'playbackDurationUs';

/// Key under which the id of the layer carrying the clip is written.
///
/// The canvas widget is handed nothing but this map, so without it there is no
/// way back to the layer — and it needs the layer's time window to know when to
/// play and where in the clip to be.
const String detachedClipLayerIdKey = 'layerId';

/// Key under which the layer's start inside the clip is written, in
/// microseconds of playback time.
///
/// Zero for a freshly detached clip and for a duplicate, which shows the same
/// stretch of footage. Splitting is what makes it non-zero: the tail half
/// starts where the head stopped, and without this it would rewind to the
/// clip's first frame at its own start.
const String detachedClipLayerSourceOffsetKey = 'sourceOffsetUs';

/// A clip lifted out of the timeline and turned into a freely placeable layer
/// on the editor canvas.
///
/// The whole [DivineVideoClip] travels in the layer's meta rather than just an
/// id: once detached, the clip is no longer in [ClipEditorState.clips], so
/// there is nothing left to look the id up in. Carrying the clip also keeps
/// trim, volume and speed with it, which both the canvas preview and the
/// export composition need.
class DetachedClipLayerData {
  const DetachedClipLayerData({
    required this.clip,
    required this.layerId,
    this.sourceOffset = Duration.zero,
  });

  /// The detached clip.
  final DivineVideoClip clip;

  /// Id of the layer this clip was placed on.
  final String layerId;

  /// Where this layer starts inside the clip, in playback time.
  final Duration sourceOffset;

  /// Serializes to the map stored in `WidgetLayer.exportConfigs.meta`.
  ///
  /// Paths inside are basenames — [DivineVideoClip.toJson]'s contract — so the
  /// map survives an iOS container-path change like every other persisted clip.
  Map<String, dynamic> toMeta() => {
    detachedClipLayerKindKey: detachedClipLayerKind,
    detachedClipLayerClipKey: clip.toJson(),
    detachedClipLayerDurationKey: clip.playbackDuration.inMicroseconds,
    detachedClipLayerIdKey: layerId,
    detachedClipLayerSourceOffsetKey: sourceOffset.inMicroseconds,
  };

  /// Whether [meta] describes a detached clip rather than a sticker.
  static bool isDetachedClipMeta(Map<String, dynamic>? meta) =>
      meta != null && meta[detachedClipLayerKindKey] == detachedClipLayerKind;

  /// Rebuilds the data from [meta], resolving clip file paths against
  /// [documentsPath].
  ///
  /// Returns `null` when [meta] is not a detached clip or its clip payload is
  /// unreadable. A corrupt layer resolving to `null` renders as nothing rather
  /// than taking down the whole editor import, which is the same tolerance
  /// [videoEditorStickerWidgetLoader] applies to a sticker with no meta.
  static DetachedClipLayerData? fromMeta(
    Map<String, dynamic>? meta,
    String documentsPath, {
    bool useOriginalPath = false,
  }) {
    if (!isDetachedClipMeta(meta)) return null;
    final raw = meta![detachedClipLayerClipKey];
    if (raw is! Map) return null;
    try {
      return DetachedClipLayerData(
        clip: DivineVideoClip.fromJson(
          Map<String, dynamic>.from(raw),
          documentsPath,
          useOriginalPath: useOriginalPath,
        ),
        layerId: meta[detachedClipLayerIdKey] as String? ?? '',
        sourceOffset: sourceOffsetOf(meta) ?? Duration.zero,
      );
    } on FormatException {
      return null;
    }
  }

  /// How long the clip plays, read straight from [meta].
  ///
  /// A detached clip is off the timeline and has no trim handles any more, so
  /// its length is fixed the moment it is detached — which is why the value is
  /// written into the meta rather than recomputed. Reading it needs no
  /// documents path, so the timeline can cap the layer's bar at the clip's real
  /// length without resolving files.
  ///
  /// Returns `null` when [meta] is not a detached clip or predates the key.
  static Duration? playbackDurationOf(Map<String, dynamic>? meta) {
    if (!isDetachedClipMeta(meta)) return null;
    final raw = meta![detachedClipLayerDurationKey];
    return raw is int && raw > 0 ? Duration(microseconds: raw) : null;
  }

  /// Where the layer starts inside the clip, or `null` when [meta] is not a
  /// detached clip. Absent (a layer written before splitting existed) reads as
  /// zero, which is what an unsplit layer means.
  static Duration? sourceOffsetOf(Map<String, dynamic>? meta) {
    if (!isDetachedClipMeta(meta)) return null;
    final raw = meta![detachedClipLayerSourceOffsetKey];
    return raw is int && raw > 0 ? Duration(microseconds: raw) : Duration.zero;
  }

  /// How much of the clip is still ahead of this layer's start.
  ///
  /// What the timeline caps the bar at: the head of a split has the whole clip
  /// behind it but only plays up to the cut, and the tail has only what is
  /// left. Stretching either past that would promise frames the file does not
  /// have there.
  static Duration? remainingPlaybackOf(Map<String, dynamic>? meta) {
    final total = playbackDurationOf(meta);
    if (total == null) return null;
    final offset = sourceOffsetOf(meta) ?? Duration.zero;
    final remaining = total - offset;
    return remaining > Duration.zero ? remaining : Duration.zero;
  }

  /// [meta] re-pointed at a new layer, for a copy of a detached clip.
  ///
  /// A copied `WidgetLayer` gets a fresh `Layer.id` but carries its meta
  /// verbatim, so without this the copy still names the *original* layer — and
  /// then reads the original's window off the timeline while the export uses
  /// its own. The two agree only while the copy sits at the same time as the
  /// original, which is exactly where a duplicate starts and why the mismatch
  /// only surfaces once it is moved.
  ///
  /// Edits the map rather than rebuilding through [fromMeta]: the clip payload
  /// is opaque here and needs no documents path to be carried across.
  static Map<String, dynamic>? rebase(
    Map<String, dynamic>? meta, {
    required String layerId,
    Duration? sourceOffset,
  }) {
    if (!isDetachedClipMeta(meta)) return null;
    return {
      ...meta!,
      detachedClipLayerIdKey: layerId,
      if (sourceOffset != null)
        detachedClipLayerSourceOffsetKey: sourceOffset.inMicroseconds,
    };
  }

  /// The id of the layer [meta] belongs to, or `null` when it predates the key.
  static String? layerIdOf(Map<String, dynamic>? meta) {
    if (!isDetachedClipMeta(meta)) return null;
    final id = meta![detachedClipLayerIdKey];
    return id is String && id.isNotEmpty ? id : null;
  }

  /// Whether [layer] is a detached clip.
  static bool isDetachedClipLayer(Layer layer) =>
      layer is WidgetLayer &&
      isDetachedClipMeta(layer.exportConfigs.meta ?? layer.meta);

  /// The meta a detached-clip [layer] carries, from whichever of the two meta
  /// slots holds it.
  ///
  /// `exportConfigs.meta` is what a re-imported layer comes back with (it is
  /// the slot `WidgetLayer.fromMap` hands to the widget loader); `Layer.meta`
  /// is what the live layer was built with. Both are written on creation, so
  /// reading either works — but only checking one would miss half the
  /// lifecycle.
  static Map<String, dynamic>? metaOf(Layer layer) {
    if (layer is! WidgetLayer) return null;
    final exported = layer.exportConfigs.meta;
    if (isDetachedClipMeta(exported)) return exported;
    final own = layer.meta;
    return isDetachedClipMeta(own) ? own : null;
  }

  /// Every file owned by a detached clip anywhere in serialized editor state.
  ///
  /// The whole history is walked, not only its active position: undo and redo
  /// entries are durable draft state and their media must survive cleanup too.
  static Set<String> ownedFilePathsInHistory(
    Map<String, dynamic> history,
    String documentsPath,
  ) {
    final paths = <String>{};

    void visit(Object? value) {
      if (value is Map) {
        final map = Map<String, dynamic>.from(value);
        if (isDetachedClipMeta(map)) {
          try {
            final data = fromMeta(map, documentsPath);
            if (data != null) {
              paths.addAll(
                data.clip.ownedFilePaths.whereType<String>().where(
                  (path) => path.isNotEmpty,
                ),
              );
            }
          } on Object {
            // A corrupt history entry must not prevent the rest of the draft
            // from saving or its other valid assets from being protected.
          }
        }
        map.values.forEach(visit);
      } else if (value is Iterable) {
        value.forEach(visit);
      }
    }

    visit(history);
    return paths;
  }

  /// Whether serialized editor state contains at least one detached clip.
  static bool historyContainsDetachedClip(Map<String, dynamic> history) {
    var found = false;

    void visit(Object? value) {
      if (found) return;
      if (value is Map) {
        final map = Map<String, dynamic>.from(value);
        if (isDetachedClipMeta(map)) {
          found = true;
          return;
        }
        map.values.forEach(visit);
      } else if (value is Iterable) {
        value.forEach(visit);
      }
    }

    visit(history);
    return found;
  }
}
