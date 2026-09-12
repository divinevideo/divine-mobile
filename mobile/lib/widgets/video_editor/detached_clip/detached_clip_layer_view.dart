// ABOUTME: Canvas widgets for a clip detached from the timeline: a companion
// ABOUTME: video player for the editor, a still poster for headless renders

import 'dart:async';
import 'dart:io';

import 'package:collection/collection.dart' show DeepCollectionEquality;
import 'package:divine_ui/divine_ui.dart';
import 'package:divine_video_player/divine_video_player.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/blocs/video_editor/timeline_overlay/timeline_overlay_bloc.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/models/video_editor/clip_chroma_key.dart';
import 'package:openvine/models/video_editor/detached_clip_layer.dart';
import 'package:openvine/utils/path_resolver.dart';
import 'package:openvine/widgets/video_editor/chroma_key/chroma_keyed_video.dart';
import 'package:openvine/widgets/video_editor/detached_clip/detached_clip_player.dart';
import 'package:openvine/widgets/video_editor/detached_clip/detached_clip_player_registry.dart';
import 'package:openvine/widgets/video_editor/main_editor/video_editor_scope.dart';

/// Corner rounding applied to a detached clip, so it reads as a placed object
/// rather than a second full-bleed video.
const double detachedClipCornerRadius = 8;

/// Nominal width the layer's content is laid out at, before the editor scales
/// it to the layer's own width.
///
/// pro_image_editor renders a layer inside a `FittedBox`, which measures its
/// child against **unbounded** constraints and then scales the result. An
/// `AspectRatio` cannot answer that — it threw `RenderAspectRatio has unbounded
/// constraints` in `performLayout` and the layer drew nothing at all. So the
/// content states a concrete size in the right ratio and lets the FittedBox do
/// the scaling; the number itself is arbitrary and never reaches the screen.
const double detachedClipLayoutWidth = 1000;

/// Identifies the media a detached-clip [meta] describes.
///
/// Two metas for the same clip share one player; a different clip, trim, speed
/// or volume gets its own. Read straight off the serialized clip so it needs no
/// documents path and cannot fail.
String? detachedClipSourceKey(Map<String, dynamic>? meta) {
  if (meta == null) return null;
  final raw = meta[detachedClipLayerClipKey];
  if (raw is! Map) return null;
  return '${raw['id']}|${raw['filePath']}|${raw['trimStartMs']}'
      '|${raw['trimEndMs']}|${raw['playbackSpeed']}|${raw['volume']}';
}

/// Identifies the player a detached-clip [meta] needs.
///
/// The media alone is not enough: a player carries one position and one time
/// window, so two layers of the same clip can only share it while they sit at
/// the same moment. That is where a duplicate starts, which is why sharing
/// looked right — but move one and the shared player can only be in one of the
/// two places. Splitting makes them differ by construction. So the layer is
/// part of the key, and each layer drives its own decoder.
String? detachedClipPlayerKey(Map<String, dynamic>? meta) {
  final source = detachedClipSourceKey(meta);
  if (source == null) return null;
  final layerId = DetachedClipLayerData.layerIdOf(meta);
  return layerId == null ? source : '$source|$layerId';
}

/// Renders a detached clip inside its `WidgetLayer` on the editor canvas.
///
/// The clip no longer sits on the timeline track, so the canvas' single
/// composition player cannot play it. It gets a companion player of its own,
/// borrowed from [detachedClipPlayers] rather than owned here: dragging
/// a layer re-parents it, which unmounts and remounts this widget about once a
/// second, and a player tied to that lifetime restarts just as often.
///
/// Built from the layer's serialized meta rather than from a
/// [DivineVideoClip], so the widget loader can rebuild it after a draft
/// round-trip with nothing but the map that survived export.
///
/// The editor renders a layer in **two** places at once (two `FittedBox`
/// parents, proven on device by a `GlobalKey` collision), and mints fresh
/// `GlobalKey`s for every copied layer, so this widget is torn down and rebuilt
/// on every frame of a drag and once per selection. A `GlobalKey` of our own
/// therefore cannot hold the element still — it lands in both trees and throws.
/// The pool behind [DetachedClipPlayer] is what keeps the decoder alive across
/// that churn; the poster under the surface is what keeps a rebuilt texture's
/// first frame from being a hole.
///
/// Use [DetachedClipPoster] instead wherever the layer is mounted only to be
/// rasterized: the draft render path mounts every layer offscreen, and a
/// native decoder started there would be spun up for an image nothing looks at.
class DetachedClipLayerView extends StatefulWidget {
  const DetachedClipLayerView({required this.meta, super.key});

  /// The layer's `exportConfigs.meta`, as written by
  /// [DetachedClipLayerData.toMeta].
  final Map<String, dynamic> meta;

  @override
  State<DetachedClipLayerView> createState() => _DetachedClipLayerViewState();
}

class _DetachedClipLayerViewState extends State<DetachedClipLayerView> {
  DivineVideoClip? _clip;

  /// The layer's live green screen, resolved from the meta alongside the clip.
  ///
  /// Held here rather than parsed in `build`: the preview rebuilds its shader
  /// whenever the key object changes, and a fresh parse per build would hand
  /// it a new one every frame of a drag.
  ClipChromaKey? _chromaKey;
  DetachedClipPlayer? _player;

  /// The registry key currently held, so the release matches the acquire even
  /// when the meta changed in between.
  String? _heldKey;

  /// Bumped by every load and by dispose, so a load still in flight can see
  /// itself superseded instead of installing into a dead state.
  int _loadGeneration = 0;

  /// Whether this state picked up an already-playing player.
  ///
  /// Suppresses the poster: `DivineVideoPlayer` restarts its thumbnail fade
  /// whenever it is mounted, and on a resumed player that is a 120ms flash of
  /// the still over live video — once per remount.
  bool _resumed = false;

  @override
  void initState() {
    super.initState();
    // A remount lands here about once a second while a layer is dragged, and
    // awaiting the load first would leave the layer blank for those frames.
    // When the player is already open the clip is known synchronously, so the
    // first frame after the remount draws the video and nothing flashes.
    final key = detachedClipPlayerKey(widget.meta);
    final ready = key == null ? null : detachedClipPlayers.acquireIfReady(key);
    final documentsPath = cachedDocumentsPath;
    if (ready != null) {
      _heldKey = key;
      _player = ready;
      _clip = ready.clip;
      _resumed = true;
      // The player carries the clip but not the layer's key, which is the
      // layer's own and has to be read off the meta the remount arrived with.
      if (documentsPath != null) {
        _chromaKey = DetachedClipLayerData.chromaKeyOf(
          widget.meta,
          documentsPath,
        );
      }
      return;
    }
    // No pooled player — but the clip itself is usually resolvable without an
    // await, and drawing its poster in the first frame is what makes an undo
    // put the layer straight back. Without it the layer is an empty box until
    // the decoder opens, which reads as the undo having lost it.
    if (documentsPath != null) {
      final data = DetachedClipLayerData.fromMeta(widget.meta, documentsPath);
      _clip = data?.clip;
      _chromaKey = data?.chromaKey;
    }
    unawaited(_load());
  }

  @override
  void didUpdateWidget(DetachedClipLayerView oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Compared by source, not by map identity: a history write can hand the
    // layer a fresh meta instance describing the same clip, and reloading on
    // that would restart the player.
    if (detachedClipPlayerKey(oldWidget.meta) !=
        detachedClipPlayerKey(widget.meta)) {
      unawaited(_load());
    } else if (!_chromaKeyEquality.equals(
      oldWidget.meta[detachedClipLayerChromaKeyKey],
      widget.meta[detachedClipLayerChromaKeyKey],
    )) {
      // Only the green screen changed: re-read it without touching the
      // player, which would restart the clip on every slider nudge.
      unawaited(_reloadChromaKey());
    }
  }

  static const _chromaKeyEquality = DeepCollectionEquality();

  Future<void> _reloadChromaKey() async {
    final generation = _loadGeneration;
    final documentsPath = await getDocumentsPath();
    if (!mounted || generation != _loadGeneration) return;
    setState(() {
      _chromaKey = DetachedClipLayerData.chromaKeyOf(
        widget.meta,
        documentsPath,
      );
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _follow();
  }

  /// Points the player at the playhead and the layer's current time window.
  ///
  /// The window is read from the timeline rather than frozen into the meta, so
  /// dragging the layer along the strip moves what the companion plays with it.
  void _follow() {
    final window = _window;
    final scope = VideoEditorScope.maybeOf(context);
    _player?.follow(
      playhead: scope?.playTimeNotifier,
      advancing: scope?.playheadAdvancingNotifier,
      windowStart: window?.start ?? Duration.zero,
      windowEnd: window?.end,
      sourceOffset:
          DetachedClipLayerData.sourceOffsetOf(widget.meta) ?? Duration.zero,
    );
  }

  /// The timeline bloc, or `null` outside the editor.
  ///
  /// The same widget class is mounted by the draft render path, which has no
  /// providers around it, so this must not throw there.
  TimelineOverlayBloc? get _overlayBloc {
    try {
      return context.read<TimelineOverlayBloc>();
    } on ProviderNotFoundException {
      return null;
    }
  }

  /// This layer's slot on the timeline, or `null` when it has none.
  ({Duration start, Duration end})? get _window {
    final id = DetachedClipLayerData.layerIdOf(widget.meta);
    if (id == null) return null;
    for (final item in _overlayBloc?.state.items ?? const []) {
      if (item.id == id) return (start: item.startTime, end: item.endTime);
    }
    return null;
  }

  @override
  void dispose() {
    _loadGeneration++;
    // Detached, not torn down: the registry holds the player briefly so the
    // remount that follows a drag picks the same one back up, mid-playback.
    _player?.detach();
    final key = _heldKey;
    if (key != null) detachedClipPlayers.release(key);
    _player = null;
    _heldKey = null;
    super.dispose();
  }

  Future<void> _load() async {
    final generation = ++_loadGeneration;
    bool superseded() => !mounted || generation != _loadGeneration;

    final previousKey = _heldKey;
    _player?.detach();
    _heldKey = null;

    final key = detachedClipPlayerKey(widget.meta);
    final documentsPath = await getDocumentsPath();
    if (superseded()) return;

    final data = DetachedClipLayerData.fromMeta(widget.meta, documentsPath);
    final clip = data?.clip;
    if (clip == null || key == null) {
      if (previousKey != null) detachedClipPlayers.release(previousKey);
      return;
    }
    setState(() {
      _clip = clip;
      _chromaKey = data?.chromaKey;
    });

    final player = await detachedClipPlayers.acquire(
      key,
      () => DetachedClipPlayer.open(clip),
    );
    // Released only after the acquire, so reloading onto the same source keeps
    // the entry alive instead of dropping it to zero refs in between.
    if (previousKey != null) detachedClipPlayers.release(previousKey);

    if (superseded()) {
      detachedClipPlayers.release(key);
      return;
    }

    _heldKey = key;
    setState(() => _player = player);
    // `superseded()` above already proved this state is still mounted, but the
    // lint cannot see through the closure.
    if (!mounted) return;
    _follow();
  }

  @override
  Widget build(BuildContext context) {
    final clip = _clip;
    if (clip == null) return const SizedBox.shrink();

    final player = _player;
    final playhead = VideoEditorScope.maybeOf(context)?.playTimeNotifier;
    if (player == null || playhead == null) {
      return _DetachedClipFrame(
        clip: clip,
        child: ChromaKeyedVideo(
          chromaKey: _chromaKey,
          previewTransparency: false,
          child: _ClipThumbnail(clip: clip),
        ),
      );
    }

    // Outside its window the layer must not render a platform texture at all.
    // The editor hides a layer by painting it into an opacity-0 compositing
    // layer (deliberately, so it still rasterizes for export), and a texture is
    // not reliably bound by that — the video would show through at full
    // brightness where nothing should be.
    return _WindowChangeListener(
      enabled: _overlayBloc != null,
      onChanged: _follow,
      child: _DetachedClipFrame(
        clip: clip,
        // The key wraps the poster as well as the surface: both show the same
        // footage, and a poster left unkeyed would fill the removed area with
        // the very screen the key takes out. Transparent stays transparent —
        // the canvas underneath is the backdrop here, not a checkerboard.
        child: ChromaKeyedVideo(
          chromaKey: _chromaKey,
          previewTransparency: false,
          // The poster sits under the surface rather than beside it, so a
          // frame the texture has not painted yet shows the clip's own still
          // instead of a hole. The player is mounted once and kept:
          // rebuilding it per playhead tick — 60 times a second — is what a
          // `builder` around it would do.
          child: Stack(
            fit: StackFit.expand,
            children: [
              _ClipThumbnail(clip: clip),
              _WindowVisibility(
                playhead: playhead,
                isVisible: player.isWithinWindow,
                child: DivineVideoPlayer(
                  controller: player.controller,
                  placeholder: _resumed ? null : _ClipThumbnail(clip: clip),
                  crossFadePlaceholder: !_resumed,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Mounts [child] only while the playhead sits inside the layer's window.
///
/// Rebuilds on the *flip*, not on every tick: the child is a platform texture,
/// and rebuilding it at frame rate is both wasteful and a way to lose a frame.
class _WindowVisibility extends StatelessWidget {
  const _WindowVisibility({
    required this.playhead,
    required this.isVisible,
    required this.child,
  });

  final ValueNotifier<Duration> playhead;
  final bool Function(Duration playTime) isVisible;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Duration>(
      valueListenable: playhead,
      builder: (context, playTime, child) =>
          isVisible(playTime) ? child! : const SizedBox.shrink(),
      child: child,
    );
  }
}

/// Calls [onChanged] whenever the timeline's items change, so a layer dragged
/// along the strip re-reads its slot.
///
/// A listener rather than a `select` in `build`: following the window drives a
/// player, and that is a side effect which does not belong in a build method.
class _WindowChangeListener extends StatelessWidget {
  const _WindowChangeListener({
    required this.enabled,
    required this.onChanged,
    required this.child,
  });

  final bool enabled;
  final VoidCallback onChanged;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!enabled) return child;
    return BlocListener<TimelineOverlayBloc, TimelineOverlayState>(
      listenWhen: (previous, current) => previous.items != current.items,
      listener: (_, _) => onChanged(),
      child: child,
    );
  }
}

/// A detached clip as a still image, for contexts that mount the layer only to
/// rasterize it.
///
/// The draft render path mounts every restored layer offscreen and requires
/// each one to produce an image, so this cannot be an empty box — but it must
/// not open a decoder either. The rasterized bytes are discarded for a detached
/// clip: `DetachedClipRenderPass` composites the clip's own video instead.
class DetachedClipPoster extends StatefulWidget {
  const DetachedClipPoster({required this.meta, super.key});

  /// The layer's `exportConfigs.meta`, as written by
  /// [DetachedClipLayerData.toMeta].
  final Map<String, dynamic> meta;

  @override
  State<DetachedClipPoster> createState() => _DetachedClipPosterState();
}

class _DetachedClipPosterState extends State<DetachedClipPoster> {
  DivineVideoClip? _clip;

  @override
  void initState() {
    super.initState();
    unawaited(_resolve());
  }

  Future<void> _resolve() async {
    final documentsPath = await getDocumentsPath();
    if (!mounted) return;
    final clip = DetachedClipLayerData.fromMeta(
      widget.meta,
      documentsPath,
    )?.clip;
    if (clip == null) return;
    setState(() => _clip = clip);
  }

  @override
  Widget build(BuildContext context) {
    final clip = _clip;
    if (clip == null) return const SizedBox.shrink();
    return _DetachedClipFrame(
      clip: clip,
      child: _ClipThumbnail(clip: clip),
    );
  }
}

/// Shapes a detached clip's content: its source aspect ratio, rounded off.
///
/// Sized concretely rather than with an `AspectRatio`, because the editor lays
/// a layer out inside a `FittedBox` — see [detachedClipLayoutWidth].
class _DetachedClipFrame extends StatelessWidget {
  const _DetachedClipFrame({required this.clip, required this.child});

  final DivineVideoClip clip;
  final Widget child;

  /// Roughly the on-screen width a detached clip is created at, used only to
  /// keep the corner radius visually constant once the FittedBox has scaled
  /// the content.
  static const double _nominalScaleReference = 300;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: detachedClipLayoutWidth,
      height: detachedClipLayoutWidth / clip.originalAspectRatio,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(
          // The rounding is applied before the FittedBox scales the content
          // down, so it has to be stated in the same nominal units.
          detachedClipCornerRadius *
              detachedClipLayoutWidth /
              _nominalScaleReference,
        ),
        child: child,
      ),
    );
  }
}

/// The clip's thumbnail, shown while its player loads and as the fallback when
/// the file is gone.
class _ClipThumbnail extends StatelessWidget {
  const _ClipThumbnail({required this.clip});

  final DivineVideoClip clip;

  @override
  Widget build(BuildContext context) {
    final thumbnail = clip.thumbnailPath;
    if (thumbnail == null || !File(thumbnail).existsSync()) {
      return ColoredBox(color: context.vineColors.surfaceContainerHigh);
    }
    return Image.file(File(thumbnail), fit: BoxFit.cover);
  }
}
