// ABOUTME: Full-screen green-screen editor for a single clip: auto-detect or
// ABOUTME: tune the key, choose what replaces it, all over a live preview that
// ABOUTME: needs no render.

import 'dart:async';
import 'dart:io';

import 'package:divine_ui/divine_ui.dart';
import 'package:divine_video_player/divine_video_player.dart';
import 'package:flutter/foundation.dart' show compute;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'package:openvine/blocs/video_editor/chroma_key/chroma_key_editor_cubit.dart';
import 'package:openvine/blocs/video_editor/clip_editor/clip_editor_bloc.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/models/video_editor/clip_chroma_key.dart';
import 'package:openvine/utils/image_orientation.dart';
import 'package:openvine/utils/loop_restarts.dart';
import 'package:openvine/utils/path_resolver.dart';
import 'package:openvine/widgets/branded_loading_indicator.dart';
import 'package:openvine/widgets/video_editor/chroma_key/chroma_key_backdrop.dart';
import 'package:openvine/widgets/video_editor/chroma_key/chroma_key_clip_picker_sheet.dart';
import 'package:openvine/widgets/video_editor/chroma_key/chroma_key_controls.dart';
import 'package:openvine/widgets/video_editor/chroma_key/chroma_keyed_video.dart';
import 'package:openvine/widgets/video_editor/video_editor_color_picker_sheet.dart';
import 'package:openvine/widgets/video_editor/video_editor_toolbar.dart';
import 'package:path/path.dart' as p;
import 'package:pro_video_editor/pro_video_editor.dart'
    show ChromaKey, EditorVideo, ProVideoEditor, ProgressModel;
import 'package:unified_logger/unified_logger.dart';

/// What the green-screen screen hands back for a detached clip.
///
/// A timeline clip's screen returns nothing — it bakes through the bloc and
/// stays up until the render lands. A detached clip's key is never baked, so
/// the screen pops with the settings instead and the caller writes them onto
/// the layer.
sealed class DetachedClipChromaKeyResult {
  const DetachedClipChromaKeyResult();
}

/// The user confirmed [chromaKey] for the layer.
class DetachedClipChromaKeyApplied extends DetachedClipChromaKeyResult {
  const DetachedClipChromaKeyApplied(this.chromaKey);

  final ClipChromaKey chromaKey;
}

/// The user took the layer's green screen off again.
class DetachedClipChromaKeyRemoved extends DetachedClipChromaKeyResult {
  const DetachedClipChromaKeyRemoved();
}

/// Sets up a clip's green screen.
///
/// Tuning is free, driven by the preview shader. For a timeline clip,
/// confirming dispatches the bake to [ClipEditorBloc] and keeps the screen up
/// — blocked, with the render's progress — until the clip's new file lands, so
/// the user sees the work finish instead of being dropped back onto an
/// unchanged timeline.
///
/// Re-opening a clip that already has a key restores its settings and previews
/// the footage as it was *before* the bake, so adjusting the key is a fresh
/// pass over clean pixels rather than a second key stacked on the first.
///
/// [VideoClipChromaKeyScreen.detached] is the same screen for a clip that was
/// detached onto the canvas. Nothing is baked there: the key stays live on the
/// layer, applied by the canvas shader and by the export composition, so
/// confirming pops with a [DetachedClipChromaKeyResult] straight away and the
/// panel offers only the backdrops a live key can carry.
class VideoClipChromaKeyScreen extends StatefulWidget {
  const VideoClipChromaKeyScreen({
    required this.clip,
    @visibleForTesting this.detect = ChromaKey.detect,
    super.key,
  }) : _layerChromaKey = null,
       surface = ChromaKeySurface.track;

  /// The screen for a clip detached onto the canvas, starting from the
  /// [chromaKey] its layer carries — `null` for a layer without one.
  ///
  /// The clip's own [DivineVideoClip.chromaKey] is deliberately not consulted:
  /// if the clip was keyed while still on the timeline, that key is already in
  /// its footage, and the layer's key goes on top of that.
  const VideoClipChromaKeyScreen.detached({
    required this.clip,
    required ClipChromaKey? chromaKey,
    @visibleForTesting this.detect = ChromaKey.detect,
    super.key,
  }) : _layerChromaKey = chromaKey,
       surface = ChromaKeySurface.canvas;

  final DivineVideoClip clip;

  final ClipChromaKey? _layerChromaKey;

  /// Where the keyed clip sits, which decides how the result leaves the
  /// screen and which backdrops the panel offers.
  final ChromaKeySurface surface;

  /// The key the screen opens on, or `null` to measure one off the footage.
  ClipChromaKey? get initialChromaKey => switch (surface) {
    ChromaKeySurface.track => clip.chromaKey,
    ChromaKeySurface.canvas => _layerChromaKey,
  };

  /// The screen-colour measurement implementation.
  ///
  /// Tests replace the native decoder while keeping the on-open behavior on.
  @visibleForTesting
  final ChromaKeyDetectFn detect;

  @override
  State<VideoClipChromaKeyScreen> createState() =>
      _VideoClipChromaKeyScreenState();
}

class _VideoClipChromaKeyScreenState extends State<VideoClipChromaKeyScreen> {
  late final ChromaKeyEditorCubit _cubit;
  DivineVideoPlayerController? _player;

  /// Background images this screen copied into the documents dir.
  ///
  /// They have to be tracked because nothing else can reclaim them: an image
  /// that is not the one the user ends up baking is referenced by no clip, and
  /// the draft orphan sweep only ever looks at paths a clip still points at.
  final _createdImagePaths = <String>{};

  /// The one created image the confirmed bake actually used, if any. Everything
  /// else in [_createdImagePaths] is garbage by the time this screen closes.
  String? _keptImagePath;

  /// The background image the pending bake was dispatched with, promoted to
  /// [_keptImagePath] once that bake lands.
  String? _pendingImagePath;

  @override
  void initState() {
    super.initState();
    _cubit = ChromaKeyEditorCubit(
      video: EditorVideo.file(_previewPath),
      initialChromaKey: widget.initialChromaKey,
      detect: widget.detect,
    );
    unawaited(_initializePlayer());
  }

  bool get _isDetached => widget.surface == ChromaKeySurface.canvas;

  /// Whether the pre-key footage is still on disk to preview and restore.
  ///
  /// Always false for a detached clip: its key is not in the footage, so there
  /// is no earlier file to go back to.
  late final bool _hasKeySource = () {
    if (_isDetached) return false;
    final source = widget.clip.chromaKeySourcePath;
    return source != null && File(source).existsSync();
  }();

  /// Whether the clip already has a key this screen can take off again.
  ///
  /// Undoing a timeline clip's key is a file swap, so it needs the pre-key
  /// footage on disk. A detached clip's key is a layer setting and can always
  /// be removed.
  bool get _canRemove => _isDetached
      ? widget.initialChromaKey != null
      : widget.clip.chromaKey != null && _hasKeySource;

  /// The footage the preview and the measurement run on.
  ///
  /// For an already-keyed timeline clip that is the pre-bake original: keying
  /// the baked video again would show a key applied twice, and measuring it
  /// would sample the replaced background instead of the screen. A detached
  /// clip's key sits on top of its footage as it is, so that is what is shown.
  String get _previewPath {
    final source = widget.clip.chromaKeySourcePath;
    if (source != null && _hasKeySource) return source;
    return widget.clip.video?.file?.path ?? '';
  }

  Future<void> _initializePlayer() async {
    final path = _previewPath;
    if (path.isEmpty) return;

    // Re-check `mounted` after every await and tear the controller down when
    // this screen went away mid-load, rather than leaking it.
    final player = DivineVideoPlayerController(
      useTexture: true,
      debugLabel: 'editor_chroma_key',
    );
    try {
      await player.initialize();
      if (!mounted) return await player.dispose();
      await player.setSource(
        VideoClip(
          uri: path,
          start: widget.clip.trimStart,
          end: widget.clip.duration - widget.clip.trimEnd,
          // Muted: the clip loops for minutes while the key is tuned, and this
          // screen is a purely visual judgement.
          volume: 0,
          playbackSpeed: widget.clip.playbackSpeed ?? 1.0,
        ),
      );
      if (!mounted) return await player.dispose();
      await player.setLooping(looping: true);
      if (!mounted) return await player.dispose();
      await player.play();
      if (!mounted) return await player.dispose();
      setState(() => _player = player);
    } catch (error, stackTrace) {
      Log.error(
        'Chroma-key preview player failed to start',
        name: 'VideoClipChromaKeyScreen',
        error: error,
        stackTrace: stackTrace,
        category: LogCategory.video,
      );
      await player.dispose();
    }
  }

  /// Keeps a video backdrop in step with the looping preview.
  ///
  /// The restart stream is broadcast because the backdrop widget subscribes and
  /// unsubscribes as the background type changes. The offset and speed are the
  /// clip's own, so the preview shows the alignment the export will produce —
  /// see [ChromaKeyBackdropSync].
  ChromaKeyBackdropSync get _backdropSync => ChromaKeyBackdropSync(
    restarts: _restarts ??= loopRestarts(
      _player!.stateStream.map((state) => state.position),
    ).asBroadcastStream(),
    sourceOffset: widget.clip.trimStart,
    playbackSpeed: widget.clip.playbackSpeed ?? 1,
  );
  Stream<void>? _restarts;

  @override
  void dispose() {
    // A pick the user walked away from is unreachable garbage the moment this
    // screen goes: nothing else in the app enumerates these files.
    unawaited(_pruneCreatedImages(keep: _keptImagePath));
    unawaited(_player?.dispose());
    unawaited(_cubit.close());
    super.dispose();
  }

  Future<void> _pickBackground(ClipChromaKeyBackgroundType type) async {
    switch (type) {
      case ClipChromaKeyBackgroundType.transparent:
        _cubit.useTransparentBackground();
      case ClipChromaKeyBackgroundType.color:
        final picked = await showFullColorPicker(
          context,
          initialColor:
              _cubit.state.chromaKey.key.backgroundColor ??
              VineTheme.surfaceBackground,
        );
        // Only the RGB channels are used — both renderers fill the keyed area
        // solidly — so a translucent pick would be rejected by the key.
        if (picked != null) {
          _cubit.useColorBackground(picked.withValues(alpha: 1));
        }
      case ClipChromaKeyBackgroundType.image:
        await _pickImageBackground();
      case ClipChromaKeyBackgroundType.video:
        if (!mounted) return;
        final path = await showChromaKeyClipPicker(context);
        if (!mounted) return;
        if (path != null) _cubit.useVideoBackground(path);
    }
  }

  /// Shoots a photo to sit behind the keyed subject.
  ///
  /// Camera only, deliberately: the gallery is a route for AI-generated
  /// imagery to enter a Divine video, and a backdrop the user photographs on
  /// the spot cannot be one.
  Future<void> _pickImageBackground() async {
    try {
      final picked = await ImagePicker().pickImage(source: ImageSource.camera);
      if (picked == null) return;
      // `image_picker` hands back a cache path the OS may prune, while clip
      // state persists as a documents-relative basename — so take a copy we
      // own before pointing the key at it.
      //
      // The copy is normalized rather than byte-for-byte: a photo shot in
      // portrait is stored as landscape pixels plus an EXIF orientation tag,
      // and the renderer decodes raw bytes, so it would show the backdrop
      // rotated. Baking the rotation in also caps the photo to a sane size for
      // a backdrop that is stretched to the video frame anyway.
      final documentsPath = await getDocumentsPath();
      final target = p.join(
        documentsPath,
        'chroma_bg_${widget.clip.id}_'
        '${DateTime.now().microsecondsSinceEpoch}.png',
      );
      final normalized = await compute(
        bakeImageOrientation,
        await File(picked.path).readAsBytes(),
      );
      await File(target).writeAsBytes(normalized, flush: true);
      if (!mounted) {
        await _deleteCreatedImage(target);
        return;
      }
      _createdImagePaths.add(target);
      _cubit.useImageBackground(target);
      // Trying five photos before settling on one should not cost five files.
      unawaited(_pruneCreatedImages(keep: target));
    } catch (error, stackTrace) {
      Log.error(
        'Failed to capture the chroma-key background image',
        name: 'VideoClipChromaKeyScreen',
        error: error,
        stackTrace: stackTrace,
        category: LogCategory.video,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        DivineSnackbarContainer.snackBar(
          context.l10n.videoEditorChromaKeyImagePickFailed,
        ),
      );
    }
  }

  /// Deletes every background image this screen created except [keep].
  ///
  /// Best-effort: a file that cannot be removed costs disk, not correctness, so
  /// a failure is logged rather than surfaced.
  Future<void> _pruneCreatedImages({String? keep}) async {
    final stale = _createdImagePaths.where((path) => path != keep).toList();
    _createdImagePaths.removeWhere((path) => path != keep);
    for (final path in stale) {
      await _deleteCreatedImage(path);
    }
  }

  Future<void> _deleteCreatedImage(String path) async {
    try {
      final file = File(path);
      if (file.existsSync()) await file.delete();
    } catch (error) {
      Log.warning(
        '⚠️ Failed to delete unused chroma-key background $path: $error',
        name: 'VideoClipChromaKeyScreen',
        category: LogCategory.video,
      );
    }
  }

  /// The render id of *this* clip's bake, or `null` when the bake in flight
  /// belongs to another clip.
  ///
  /// Scoped to the clip rather than the bloc-wide flag so a bake started
  /// elsewhere never locks this screen.
  String? _bakeInFlight(ClipEditorState state) =>
      state.isChromaKeying && state.chromaKeyingClipId == widget.clip.id
      ? state.chromaKeyingRenderId
      : null;

  @override
  Widget build(BuildContext context) {
    // A detached clip never bakes, and its route carries no clip bloc: the
    // key leaves through the pop instead.
    final bakingRenderId = _isDetached
        ? null
        : context.select<ClipEditorBloc, String?>(
            (bloc) => _bakeInFlight(bloc.state),
          );
    final isBaking = bakingRenderId != null;

    return BlocProvider<ChromaKeyEditorCubit>.value(
      value: _cubit,
      child: PopScope(
        // A half-written clip file is not something to hand back, so the
        // system back gesture waits with everything else.
        canPop: !isBaking,
        child: Scaffold(
          backgroundColor: context.vineColors.surfaceContainerHigh,
          body: SafeArea(
            child: MultiBlocListener(
              listeners: [
                BlocListener<ChromaKeyEditorCubit, ChromaKeyEditorState>(
                  listenWhen: (previous, current) =>
                      previous.detectionStatus != current.detectionStatus,
                  listener: (context, state) {
                    if (state.detectionStatus !=
                        ChromaKeyDetectionStatus.failure) {
                      return;
                    }
                    ScaffoldMessenger.of(context).showSnackBar(
                      DivineSnackbarContainer.snackBar(
                        context.l10n.videoEditorChromaKeyDetectFailed,
                      ),
                    );
                    context
                        .read<ChromaKeyEditorCubit>()
                        .acknowledgeDetectionFailure();
                  },
                ),
                if (!_isDetached)
                  BlocListener<ClipEditorBloc, ClipEditorState>(
                    listenWhen: (previous, current) =>
                        !identical(
                          previous.lastChromaKeyResult,
                          current.lastChromaKeyResult,
                        ) &&
                        current.lastChromaKeyResult != null,
                    listener: _onBakeResult,
                  ),
              ],
              child: Stack(
                children: [
                  Column(
                    children: [
                      VideoEditorToolbar(
                        onClose: () {
                          if (!isBaking) Navigator.of(context).pop();
                        },
                        onDone: isBaking ? null : () => _confirm(context),
                        closeSemanticLabel:
                            context.l10n.videoEditorChromaKeyCloseSemanticLabel,
                        doneSemanticLabel:
                            context.l10n.videoEditorChromaKeyDoneSemanticLabel,
                        center: Text(
                          context.l10n.videoEditorChromaKeyTitle,
                          style: VineTheme.titleMediumFont(
                            color: context.vineColors.onSurface,
                          ),
                        ),
                      ),
                      Expanded(
                        child: _Preview(
                          // A detached clip is a free-floating box in its
                          // own shape; a timeline clip fills the
                          // composition's frame.
                          aspectRatio: _isDetached
                              ? widget.clip.originalAspectRatio
                              : widget.clip.targetAspectRatio.value,
                          player: _player,
                          backdropSync: _player == null ? null : _backdropSync,
                        ),
                      ),
                      if (_canRemove)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: DivineButton(
                            label: context.l10n.videoEditorChromaKeyRemove,
                            type: .ghost,
                            size: .small,
                            expanded: true,
                            onPressed: isBaking ? null : () => _remove(context),
                          ),
                        ),
                      Flexible(
                        child: ChromaKeyControls(
                          onPickBackground: _pickBackground,
                          surface: widget.surface,
                        ),
                      ),
                    ],
                  ),
                  if (bakingRenderId != null)
                    _BakingOverlay(renderId: bakingRenderId),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _confirm(BuildContext context) {
    final chromaKey = _cubit.state.chromaKey;
    if (_isDetached) {
      // Nothing to render: the layer takes the settings as they are, so the
      // image they point at is the one to keep.
      _keptImagePath = chromaKey.backgroundImagePath;
      Navigator.of(context).pop(DetachedClipChromaKeyApplied(chromaKey));
      return;
    }
    // The bloc owns the render so it survives this screen; the screen stays up
    // and blocked until the result lands, which is what makes the wait legible.
    _pendingImagePath = chromaKey.backgroundImagePath;
    context.read<ClipEditorBloc>().add(
      ClipEditorChromaKeyRequested(
        clipId: widget.clip.id,
        chromaKey: chromaKey,
      ),
    );
  }

  void _remove(BuildContext context) {
    // Going back to the pre-key footage leaves the clip with no key at all, so
    // no background image survives it — including one an earlier failed bake
    // had queued.
    _pendingImagePath = null;
    if (_isDetached) {
      Navigator.of(context).pop(const DetachedClipChromaKeyRemoved());
      return;
    }
    context.read<ClipEditorBloc>().add(
      ClipEditorChromaKeyRemoved(widget.clip.id),
    );
  }

  void _onBakeResult(BuildContext context, ClipEditorState state) {
    switch (state.lastChromaKeyResult) {
      case ChromaKeySuccess():
        // The clip now points at this bake's background image, so it is the one
        // image the teardown must not delete. Null after a Remove, which leaves
        // the clip with no key and every created image unreferenced.
        _keptImagePath = _pendingImagePath;
        Navigator.of(context).pop();
      case ChromaKeyFailure():
        // Stay open: the settings are still on screen, so retrying costs
        // nothing but another tap.
        _showResult(context, context.l10n.videoEditorChromaKeyFailed);
      case ChromaKeyRemoveFailure():
        _showResult(context, context.l10n.videoEditorChromaKeyRemoveFailed);
      case ChromaKeyDiscarded():
        // The clip is gone from under us — there is nothing left to edit.
        Navigator.of(context).pop();
      case null:
        break;
    }
  }

  void _showResult(BuildContext context, String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(DivineSnackbarContainer.snackBar(message));
  }
}

/// Blocks the screen while the clip is re-rendered, showing the render's own
/// progress rather than an indefinite spinner.
class _BakingOverlay extends StatelessWidget {
  const _BakingOverlay({required this.renderId});

  final String renderId;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      // `ColoredBox` already absorbs pointers, but semantics travel their own
      // path: without `BlockSemantics` the controls underneath stay reachable
      // to a screen reader, and edits made there are silently dropped — the
      // bake captured its settings at Done. Worse, activating the clip picker
      // would put a sheet on this Navigator that the success handler's `pop()`
      // would close instead of this screen.
      child: BlockSemantics(
        child: ColoredBox(
          color: VineTheme.backgroundCamera.withValues(alpha: 0.85),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              spacing: 16,
              children: [
                // The label below already announces the wait.
                const ExcludeSemantics(
                  child: BrandedLoadingIndicator(size: 44),
                ),
                Text(
                  context.l10n.videoEditorChromaKeyApplying,
                  style: VineTheme.titleSmallFont(color: VineTheme.onSurface),
                ),
                // RepaintBoundary: without it the progress text repaints the
                // whole overlay on every tick.
                RepaintBoundary(
                  child: StreamBuilder<ProgressModel>(
                    stream: ProVideoEditor.instance.progressStreamById(
                      renderId,
                    ),
                    builder: (context, snapshot) {
                      final progress = snapshot.data?.progress ?? 0;
                      return Text(
                        '${(progress * 100).round()}%',
                        style: VineTheme.bodyMediumFont(
                          color: VineTheme.onSurfaceVariant,
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The looping clip with the key applied live.
class _Preview extends StatelessWidget {
  const _Preview({
    required this.aspectRatio,
    required this.player,
    required this.backdropSync,
  });

  final double aspectRatio;
  final DivineVideoPlayerController? player;

  /// Keeps a video backdrop aligned with the clip. See [ChromaKeyBackdropSync].
  final ChromaKeyBackdropSync? backdropSync;

  @override
  Widget build(BuildContext context) {
    final controller = player;
    if (controller == null) {
      return const Center(child: BrandedLoadingIndicator());
    }

    final chromaKey = context.select(
      (ChromaKeyEditorCubit c) => c.state.chromaKey,
    );

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Center(
        child: AspectRatio(
          aspectRatio: aspectRatio,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: ChromaKeyedVideo(
              chromaKey: chromaKey,
              backdropSync: backdropSync,
              child: DivineVideoPlayer(controller: controller),
            ),
          ),
        ),
      ),
    );
  }
}
