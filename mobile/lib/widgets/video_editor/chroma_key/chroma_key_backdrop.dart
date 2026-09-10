// ABOUTME: Renders what a chroma key puts behind the subject in the preview:
// ABOUTME: a checkerboard, a colour, an image, or a looping library video.

import 'dart:async';
import 'dart:io';

import 'package:divine_ui/divine_ui.dart';
import 'package:divine_video_player/divine_video_player.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/models/video_editor/clip_chroma_key.dart';
import 'package:unified_logger/unified_logger.dart';

/// How a video backdrop is kept in step with the clip playing in front of it.
///
/// The two run on independent native clocks — one player cannot drive two
/// surfaces — so instead of a shared clock they are re-anchored every time the
/// clip loops. The anchor is chosen to match the exported file rather than to
/// look tidy: `ChromaKeyBakeService.backdropSegments` tiles the backdrop across
/// the *untrimmed* clip starting at source time zero, and trim and speed are
/// applied to the baked file afterwards. So the first frame the user sees sits
/// [sourceOffset] into the backdrop, and the pair advances at [playbackSpeed].
@immutable
class ChromaKeyBackdropSync {
  const ChromaKeyBackdropSync({
    required this.restarts,
    this.sourceOffset = Duration.zero,
    this.playbackSpeed = 1,
  });

  /// Fires whenever the clip in front loops back to its start.
  final Stream<void>? restarts;

  /// Where in the backdrop the clip's first *visible* frame sits — the clip's
  /// trim start, since the bake anchors the backdrop to the untrimmed source.
  final Duration sourceOffset;

  /// The clip's playback speed. The export applies it to the baked file, which
  /// already contains the backdrop, so the preview has to speed both up too.
  final double playbackSpeed;
}

/// The backdrop for a keyed clip, matching [chromaKey]'s background type.
///
/// Composited *behind* the keyed video rather than sampled inside the shader,
/// which keeps one shader for all four background types.
class ChromaKeyBackdrop extends StatelessWidget {
  const ChromaKeyBackdrop({
    required this.chromaKey,
    this.sync,
    this.previewTransparency = true,
    super.key,
  });

  final ClipChromaKey chromaKey;

  /// Keeps a video backdrop aligned with the clip in front. See
  /// [ChromaKeyBackdropSync].
  final ChromaKeyBackdropSync? sync;

  /// Whether "nothing behind the subject" is drawn as a checkerboard.
  ///
  /// Off when the widget sits on the editor canvas, where what is underneath is
  /// the real backdrop and must stay visible — see
  /// `ChromaKeyedVideo.previewTransparency`. Also covers a backdrop whose own
  /// source is gone, which reads as "nothing" either way.
  final bool previewTransparency;

  @override
  Widget build(BuildContext context) {
    final backgroundColor = chromaKey.key.backgroundColor;
    // `EditorLayerImage.file` is the plugin's conditionally-imported `File`,
    // not `dart:io`'s, so go through the path rather than the object.
    final imagePath = chromaKey.key.backgroundImage?.file?.path;
    final videoPath = chromaKey.backgroundVideoPath;

    final transparent = previewTransparency
        ? const ChromaKeyTransparencyCheckerboard()
        : const SizedBox.shrink();

    return switch (chromaKey.backgroundType) {
      ClipChromaKeyBackgroundType.color when backgroundColor != null =>
        ColoredBox(color: backgroundColor),
      ClipChromaKeyBackgroundType.image when imagePath != null =>
        _ImageBackdrop(path: imagePath, fallback: transparent),
      ClipChromaKeyBackgroundType.video when videoPath != null =>
        _VideoBackdrop(path: videoPath, sync: sync),
      // Transparent — and the degenerate cases where a background type's own
      // source went missing (a deleted library clip, a pruned cache file),
      // which read as "no backdrop" rather than as a crash.
      _ => transparent,
    };
  }
}

/// A still image backdrop, stretched to the frame the way the renderer
/// stretches the key's background image.
class _ImageBackdrop extends StatelessWidget {
  const _ImageBackdrop({required this.path, required this.fallback});

  final String path;

  /// Shown in place of a file that cannot be loaded, so the user still sees
  /// the matte — which is the point of the preview.
  final Widget fallback;

  @override
  Widget build(BuildContext context) {
    return Image.file(
      File(path),
      fit: BoxFit.fill,
      errorBuilder: (_, _, _) => fallback,
    );
  }
}

/// A looping, muted library video playing behind the subject.
///
/// It runs on its own native clock — two players cannot share one — but is
/// re-anchored whenever the clip in front loops, so the pair realigns every
/// cycle instead of drifting apart. Where it is anchored to, and why that is
/// not simply zero, is [ChromaKeyBackdropSync].
class _VideoBackdrop extends StatefulWidget {
  const _VideoBackdrop({required this.path, this.sync});

  final String path;
  final ChromaKeyBackdropSync? sync;

  @override
  State<_VideoBackdrop> createState() => _VideoBackdropState();
}

class _VideoBackdropState extends State<_VideoBackdrop> {
  DivineVideoPlayerController? _controller;
  StreamSubscription<void>? _restartSubscription;
  StreamSubscription<void>? _stateSubscription;

  /// The backdrop's own length, needed to wrap [_restartPosition] into it.
  /// Zero until the player reports it, which anchors at zero until then.
  Duration _backdropDuration = Duration.zero;

  /// Bumped by every load. A load whose generation is no longer current has
  /// been superseded by a newer path and must tear its controller down instead
  /// of installing it — `mounted` alone does not catch that, since the widget
  /// is still very much mounted.
  int _loadGeneration = 0;

  @override
  void initState() {
    super.initState();
    _listenForRestarts();
    unawaited(_initialize());
  }

  void _listenForRestarts() {
    unawaited(_restartSubscription?.cancel());
    _restartSubscription = widget.sync?.restarts?.listen((_) {
      unawaited(_controller?.seekTo(_restartPosition));
    });
  }

  /// Where the backdrop belongs when the clip in front wraps.
  ///
  /// Not zero: the bake tiles the backdrop across the untrimmed clip from
  /// source time zero, so the clip's first *visible* frame sits `sourceOffset`
  /// (its trim start) into the backdrop. Wrapped into the backdrop's own
  /// length, which is where its tiling repeats.
  Duration get _restartPosition {
    final offset = widget.sync?.sourceOffset ?? Duration.zero;
    if (offset <= Duration.zero || _backdropDuration <= Duration.zero) {
      return Duration.zero;
    }
    return Duration(
      microseconds: offset.inMicroseconds % _backdropDuration.inMicroseconds,
    );
  }

  @override
  void didUpdateWidget(_VideoBackdrop oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.sync?.restarts != widget.sync?.restarts) {
      _listenForRestarts();
    }
    if (oldWidget.path != widget.path) {
      final previous = _controller;
      setState(() => _controller = null);
      unawaited(_stateSubscription?.cancel());
      unawaited(previous?.dispose());
      unawaited(_initialize());
    }
  }

  Future<void> _initialize() async {
    final generation = ++_loadGeneration;
    // Hold the controller locally and re-check after every await: a path change
    // or a dispose can supersede this load mid-flight, and the half-built
    // controller has to be torn down rather than leaked.
    // Opt out of the one-video-at-a-time rule: this is a layer of the clip in
    // front, not a video of its own, so the two must run together instead of
    // stopping each other.
    final controller = DivineVideoPlayerController(
      useTexture: true,
      exclusivePlayback: false,
      debugLabel: 'editor_chroma_backdrop',
    );
    bool superseded() => !mounted || generation != _loadGeneration;
    try {
      await controller.initialize();
      if (superseded()) return await controller.dispose();
      await controller.setSource(
        // ChromaKeyBakeService.backdropSegments tiles the export by the
        // container duration. Keep that same loop boundary in the preview by
        // leaving trimToCommonTrackEnd at false.
        VideoClip.file(
          widget.path,
          volume: 0,
          playbackSpeed: widget.sync?.playbackSpeed ?? 1,
        ),
      );
      if (superseded()) return await controller.dispose();
      await controller.setLooping(looping: true);
      if (superseded()) return await controller.dispose();
      await controller.play();
      if (superseded()) return await controller.dispose();
      _stateSubscription = controller.stateStream.listen(
        (state) => _backdropDuration = state.duration,
      );
      setState(() => _controller = controller);
    } catch (error, stackTrace) {
      Log.error(
        'Chroma-key backdrop video failed to load; showing no backdrop',
        name: 'ChromaKeyBackdrop',
        error: error,
        stackTrace: stackTrace,
        category: LogCategory.video,
      );
      await controller.dispose();
    }
  }

  @override
  void dispose() {
    // Bump so any load still in flight sees itself superseded and disposes its
    // own controller instead of installing it into a dead state.
    _loadGeneration++;
    unawaited(_restartSubscription?.cancel());
    unawaited(_stateSubscription?.cancel());
    unawaited(_controller?.dispose());
    _controller = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    if (controller == null) return const ChromaKeyTransparencyCheckerboard();
    // The player expands to its box, which is the same "stretched to fill the
    // frame" placement the renderer gives a full-canvas background layer.
    return DivineVideoPlayer(controller: controller);
  }
}

/// The standard "nothing behind the subject" checkerboard.
class ChromaKeyTransparencyCheckerboard extends StatelessWidget {
  const ChromaKeyTransparencyCheckerboard({super.key});

  @override
  Widget build(BuildContext context) {
    return const CustomPaint(painter: _CheckerboardPainter(), size: .infinite);
  }
}

class _CheckerboardPainter extends CustomPainter {
  const _CheckerboardPainter();

  static const _cell = 12.0;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = VineTheme.surfaceContainer,
    );
    final darkPaint = Paint()..color = VineTheme.surfaceContainerHigh;
    final columns = (size.width / _cell).ceil();
    final rows = (size.height / _cell).ceil();
    for (var row = 0; row < rows; row++) {
      for (var column = row.isEven ? 0 : 1; column < columns; column += 2) {
        canvas.drawRect(
          Rect.fromLTWH(column * _cell, row * _cell, _cell, _cell),
          darkPaint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_CheckerboardPainter oldDelegate) => false;
}
