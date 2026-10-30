import 'dart:async';

import 'package:divine_video_player/src/divine_video_player_controller.dart';
import 'package:divine_video_player/src/video_player_state.dart';
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
      // SurfaceTextureEntry which encoded rotation and crop implicitly. The
      // native side sends both explicitly so Dart can apply them. Listen to
      // stateStream because they arrive after the first build.
      surface = _PlayerTexture(controller: ctrl);
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

/// Renders the native [Texture] upright and without the decoder's padding.
///
/// `SurfaceProducer` does not forward ExoPlayer's GL transform matrix to
/// Flutter (unlike the legacy `SurfaceTextureEntry`), so the native side
/// sends `Format.rotationDegrees` and the decoder's crop, which this applies
/// with a [RotatedBox] and [_CroppedTexture]. Listens to
/// [DivineVideoPlayerController.stateStream] so both update after the first
/// build.
class _PlayerTexture extends StatelessWidget {
  const _PlayerTexture({required this.controller});

  final DivineVideoPlayerController controller;

  static (int, Rect?) _layoutOf(DivineVideoPlayerState state) =>
      (state.rotationDegrees, state.textureCrop);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<(int, Rect?)>(
      stream: controller.stateStream.map(_layoutOf).distinct(),
      initialData: _layoutOf(controller.state),
      builder: (context, snapshot) {
        final (rotation, crop) = snapshot.data ?? (0, null);
        Widget texture = Texture(textureId: controller.textureId!);
        // The crop is in the buffer's orientation, so it goes inside the
        // rotation.
        if (crop != null) texture = _CroppedTexture(crop: crop, child: texture);
        if (rotation == 0) return texture;
        return RotatedBox(quarterTurns: rotation ~/ 90, child: texture);
      },
    );
  }
}

/// Fills its box with only the [crop] part of [child], a texture whose
/// padding lies outside [crop]. See [DivineVideoPlayerState.textureCrop].
class _CroppedTexture extends StatelessWidget {
  const _CroppedTexture({required this.crop, required this.child});

  final Rect crop;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: CustomSingleChildLayout(
        delegate: _TextureCropLayout(crop),
        child: child,
      ),
    );
  }
}

/// Sizes the texture so [crop] covers the whole box, and moves the padding
/// before [crop] out of it.
class _TextureCropLayout extends SingleChildLayoutDelegate {
  const _TextureCropLayout(this.crop);

  final Rect crop;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) {
    final box = constraints.biggest;
    return BoxConstraints.tight(
      Size(box.width / crop.width, box.height / crop.height),
    );
  }

  @override
  Offset getPositionForChild(Size size, Size childSize) =>
      Offset(-crop.left * childSize.width, -crop.top * childSize.height);

  @override
  bool shouldRelayout(_TextureCropLayout oldDelegate) =>
      crop != oldDelegate.crop;
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
