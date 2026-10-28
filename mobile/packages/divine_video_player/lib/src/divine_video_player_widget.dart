import 'dart:async';

import 'package:divine_video_player/src/divine_video_player_controller.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// Renders the native video surface for a [DivineVideoPlayerController].
///
/// The controller must be [DivineVideoPlayerController.isInitialized]
/// before this widget is inserted into the tree.
///
/// When [placeholder] is provided it is shown on top of the native
/// surface until the first video frame has been rendered. This
/// prevents black-frame flashes on Android where the platform view
/// composites before ExoPlayer has decoded the initial frame.
class DivineVideoPlayer extends StatelessWidget {
  /// Creates a video player widget bound to [controller].
  ///
  /// If [placeholder] is non-null it covers the video surface and
  /// fades out once [DivineVideoPlayerController.firstFrameRendered]
  /// completes.
  const DivineVideoPlayer({
    required this.controller,
    this.placeholder,
    this.crossFadePlaceholder = false,
    super.key,
  }) : assert(
         controller != null || placeholder != null,
         'Either controller or placeholder must be provided.',
       );

  /// The controller whose native player this widget renders.
  final DivineVideoPlayerController? controller;

  /// Optional widget displayed over the video surface until the
  /// first frame has been rendered.
  final Widget? placeholder;

  /// Whether to keep the [placeholder] mounted and cross-fade it out even when
  /// the first frame is *already* rendered at the moment this widget is first
  /// built.
  ///
  /// Defaults to `false`: when the first frame is already up, the surface is
  /// shown directly with no placeholder (the common fresh-load case where the
  /// placeholder bridged the decode gap and is no longer needed).
  ///
  /// Set to `true` when the placeholder was already on screen *before* this
  /// widget mounted — e.g. the video editor, where the host swaps an external
  /// thumbnail spinner straight to the player once the frame is decoded. There
  /// the early-out would hard-cut thumbnail→video; this keeps the placeholder
  /// long enough to cross-fade it out instead.
  final bool crossFadePlaceholder;

  @override
  Widget build(BuildContext context) {
    if (controller == null && placeholder != null) return placeholder!;
    final ctrl = controller!;

    final Widget surface;
    if (ctrl.usesWebBackend) {
      surface = ctrl.buildWebView();
    } else if (ctrl.usesLinuxBackend) {
      surface = ctrl.buildLinuxView();
    } else if (ctrl.useTexture && ctrl.textureId != null) {
      // SurfaceProducer does not forward ExoPlayer's GL transform matrix
      // (NATIVE_WINDOW_TRANSFORM_HINT) to Flutter, unlike the legacy
      // SurfaceTextureEntry which encoded rotation implicitly. The native
      // side reads Format.rotationDegrees and sends it explicitly so Dart
      // can apply a RotatedBox. Listen to stateStream because
      // onVideoSizeChanged fires after the first build.
      surface = _RotatingTexture(controller: ctrl);
    } else {
      final creationParams = <String, dynamic>{'playerId': ctrl.playerId};
      surface = switch (defaultTargetPlatform) {
        TargetPlatform.android => _AndroidPlayerView(
          viewType: ctrl.viewType,
          creationParams: creationParams,
        ),
        TargetPlatform.iOS => UiKitView(
          viewType: ctrl.viewType,
          creationParams: creationParams,
          creationParamsCodec: const StandardMessageCodec(),
        ),
        TargetPlatform.macOS => AppKitView(
          viewType: ctrl.viewType,
          creationParams: creationParams,
          creationParamsCodec: const StandardMessageCodec(),
        ),
        _ => const Center(child: Text('Platform not supported')),
      };
    }

    if (placeholder == null ||
        (!crossFadePlaceholder && ctrl.state.isFirstFrameRendered)) {
      return surface;
    }

    return Stack(
      fit: .expand,
      children: [
        surface,
        _PlaceholderOverlay(controller: ctrl, placeholder: placeholder!),
      ],
    );
  }
}

/// Android uses [PlatformViewLink] for Hybrid Composition which provides
/// better performance than Virtual Display for video surfaces.
class _AndroidPlayerView extends StatelessWidget {
  const _AndroidPlayerView({
    required this.viewType,
    required this.creationParams,
  });

  final String viewType;
  final Map<String, dynamic> creationParams;

  @override
  // coverage:ignore-start
  Widget build(BuildContext context) {
    return PlatformViewLink(
      viewType: viewType,
      surfaceFactory: (context, controller) {
        return AndroidViewSurface(
          controller: controller as AndroidViewController,
          hitTestBehavior: PlatformViewHitTestBehavior.opaque,
          gestureRecognizers: const <Factory<OneSequenceGestureRecognizer>>{},
        );
      },
      onCreatePlatformView: (params) {
        return PlatformViewsService.initSurfaceAndroidView(
            id: params.id,
            viewType: viewType,
            layoutDirection: TextDirection.ltr,
            creationParams: creationParams,
            creationParamsCodec: const StandardMessageCodec(),
            onFocus: () => params.onFocusChanged(true),
          )
          ..addOnPlatformViewCreatedListener(params.onPlatformViewCreated)
          // Flutter platform view API – fire-and-forget by design.
          // ignore: discarded_futures
          ..create();
      },
    );
  }

  // coverage:ignore-end
}

/// Renders the native [Texture] wrapped in a [RotatedBox] when the
/// player reports a non-zero rotation. The native side reads
/// `Format.rotationDegrees` and sends it via the event channel because
/// `SurfaceProducer` does not forward ExoPlayer's GL transform matrix
/// to Flutter (unlike the legacy `SurfaceTextureEntry`). Listens to
/// [DivineVideoPlayerController.stateStream] so the rotation updates
/// after the first build.
class _RotatingTexture extends StatelessWidget {
  const _RotatingTexture({required this.controller});

  final DivineVideoPlayerController controller;

  @override
  Widget build(BuildContext context) {
    final texture = Texture(textureId: controller.textureId!);
    final rotating = StreamBuilder<int>(
      stream: controller.stateStream.map((s) => s.rotationDegrees).distinct(),
      initialData: controller.state.rotationDegrees,
      builder: (context, snapshot) {
        final rotation = snapshot.data ?? 0;
        if (rotation == 0) return texture;
        return RotatedBox(quarterTurns: rotation ~/ 90, child: texture);
      },
    );
    if (!controller.upscalesFrames) return rotating;
    return _UpscaleTargetReporter(controller: controller, child: rotating);
  }
}

/// How often [_UpscaleTargetReporter] measures the texture again.
@visibleForTesting
const upscaleTargetSampleInterval = Duration(milliseconds: 400);

/// Measures the size the texture ends up at on screen, after every
/// enclosing transform such as a [FittedBox], and reports it to the player
/// so its upscale stage draws frames at exactly that size.
///
/// A texture off screen reports a zero size, so the player keeps its frames
/// at their own size: a feed preloads the videos around the current one,
/// and screen-sized buffers for all three cost about 240 MB of graphics
/// memory on a Galaxy S26, against about 80 MB for the one on screen.
///
/// The first measurement, and any move on or off screen, goes out at once,
/// so a feed video is sharp from its first frames. A new size while on
/// screen goes out only once two samples in a row agree, so a hero flight
/// does not resize the player's surface on every tick. Polls rather than
/// listening to layout, because a parent transform can change without this
/// subtree laying out again.
class _UpscaleTargetReporter extends StatefulWidget {
  const _UpscaleTargetReporter({required this.controller, required this.child});

  final DivineVideoPlayerController controller;
  final Widget child;

  @override
  State<_UpscaleTargetReporter> createState() => _UpscaleTargetReporterState();
}

class _UpscaleTargetReporterState extends State<_UpscaleTargetReporter> {
  late final Timer _timer;
  Size? _lastSample;
  Size? _sent;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(
      upscaleTargetSampleInterval,
      (_) => _sample(immediate: false),
    );
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _sample(immediate: true),
    );
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  /// The timer stops in [dispose] and the post-frame callback runs at the
  /// end of the frame that mounted this widget, so it is mounted here.
  void _sample({required bool immediate}) {
    final box = context.findRenderObject();
    // A subtree its parent never laid out has no size to report yet.
    if (box is! RenderBox || !box.hasSize) return;
    final rect = MatrixUtils.transformRect(
      box.getTransformTo(null),
      Offset.zero & box.size,
    );
    final view = View.of(context);
    final dpr = view.devicePixelRatio;
    final shown = Size(
      (rect.width * dpr).roundToDouble(),
      (rect.height * dpr).roundToDouble(),
    );
    // A FittedBox squeezed to nothing scales by infinity, which gives a
    // NaN size rather than an empty one.
    if (!shown.isFinite) return;
    final onScreen = rect.overlaps(Offset.zero & view.physicalSize / dpr);
    final sample = onScreen ? shown : Size.zero;
    final sent = _sent ?? Size.zero;
    final settled =
        immediate || sample == _lastSample || sample.isEmpty || sent.isEmpty;
    _lastSample = sample;
    if (!settled || sample == sent) return;
    _sent = sample;
    unawaited(
      widget.controller
          .setUpscaleTarget(
            width: sample.width.toInt(),
            height: sample.height.toInt(),
          )
          .catchError((Object _) {
            // A player disposed mid-call has nothing left to size.
          }),
    );
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// Shows the [placeholder] over the video surface and fades it out once
/// [DivineVideoPlayerController.firstFrameRendered] completes, then removes
/// it from the tree.
///
/// Fading — rather than hard-cutting to [SizedBox.shrink] — avoids a visible
/// flash when the first decoded frame doesn't pixel-match the placeholder
/// (e.g. a thumbnail cropped differently than the live texture, or a
/// black frame the platform view composites before the decoder catches up).
class _PlaceholderOverlay extends StatefulWidget {
  const _PlaceholderOverlay({
    required this.controller,
    required this.placeholder,
  });

  final DivineVideoPlayerController controller;
  final Widget placeholder;

  @override
  State<_PlaceholderOverlay> createState() => _PlaceholderOverlayState();
}

class _PlaceholderOverlayState extends State<_PlaceholderOverlay> {
  /// Fade-out duration from the placeholder to the first video frame.
  static const _fadeDuration = Duration(milliseconds: 120);

  /// Bumped whenever a fresh first-frame wait begins (mount, or a swap to a
  /// different controller), so a late completion from a superseded controller
  /// can't flip this overlay's state.
  var _firstFrameWaitToken = 0;
  bool _firstFrameRendered = false;
  bool _faded = false;

  @override
  void initState() {
    super.initState();
    _awaitFirstFrame();
  }

  @override
  void didUpdateWidget(covariant _PlaceholderOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Only a genuinely different controller restarts the fade. The *same*
    // controller reloading clips (setClips resets firstFrameRendered) does NOT
    // re-show the placeholder on purpose: the editor swaps clips in place on
    // every trim/reorder/speed/transition change, and re-showing would flash
    // the (first clip's) thumbnail over the live preview each time. This is a
    // one-shot fade for the initial thumbnail→video handoff.
    if (oldWidget.controller == widget.controller) return;
    setState(() {
      _firstFrameRendered = false;
      _faded = false;
    });
    _awaitFirstFrame();
  }

  void _awaitFirstFrame() {
    final token = ++_firstFrameWaitToken;
    unawaited(
      widget.controller.firstFrameRendered.then((_) {
        if (!mounted || token != _firstFrameWaitToken || _firstFrameRendered) {
          return;
        }
        setState(() => _firstFrameRendered = true);
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Fully faded out — drop the placeholder so it stops painting and
    // intercepting hit tests over the now-visible video.
    if (_faded ||
        (_firstFrameRendered && MediaQuery.disableAnimationsOf(context))) {
      return const SizedBox.shrink();
    }

    // The video surface stays mounted behind this overlay (the parent Stack).
    // The placeholder starts fully opaque (so it's actually visible) and fades
    // out once the first frame is up. AnimatedSwitcher is unsuitable here: it
    // also animates the initial child *in* (0→1), so when the first frame
    // arrives almost immediately the placeholder is reversed out before it
    // ever becomes visible — reading as an instant cut.
    return IgnorePointer(
      // Let taps reach the video surface the moment the frame is up, even
      // while the placeholder is still fading.
      ignoring: _firstFrameRendered,
      child: AnimatedOpacity(
        opacity: _firstFrameRendered ? 0.0 : 1.0,
        curve: Curves.easeInOut,
        duration: _fadeDuration,
        onEnd: () {
          if (_firstFrameRendered && mounted) {
            setState(() => _faded = true);
          }
        },
        child: widget.placeholder,
      ),
    );
  }
}
