// ABOUTME: Composes a clip's live chroma-key preview: the backdrop below, the
// ABOUTME: shader-keyed video above. Degrades to the plain video when the
// ABOUTME: shader is unavailable, so the editor never depends on it.

import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:openvine/models/video_editor/clip_chroma_key.dart';
import 'package:openvine/widgets/video_editor/chroma_key/chroma_key_backdrop.dart';
import 'package:openvine/widgets/video_editor/chroma_key/chroma_key_shader.dart';

/// Applies [chromaKey] to [child] for preview, without rendering anything.
///
/// [child] is normally the video player. The key is evaluated per frame by the
/// same formula the exported render uses, so what the editor shows is what the
/// file will contain — see `shaders/chroma_key.frag`.
///
/// When [chromaKey] is `null`, or the shader can't run (a non-Impeller
/// backend, a failed asset load), this is a pass-through: the unkeyed video is
/// shown and the key still applies to the export.
class ChromaKeyedVideo extends StatefulWidget {
  const ChromaKeyedVideo({
    required this.child,
    this.chromaKey,
    this.backdropSync,
    this.previewTransparency = true,
    super.key,
  });

  final ClipChromaKey? chromaKey;
  final Widget child;

  /// Keeps a video backdrop in step with [child] instead of letting the two
  /// drift. See [ChromaKeyBackdropSync].
  final ChromaKeyBackdropSync? backdropSync;

  /// Whether a transparent key is shown over a checkerboard, the way an image
  /// editor stands in for "nothing here".
  ///
  /// On by default, for the green-screen screen: its preview has nothing real
  /// behind the clip, so the checkerboard is what makes the matte legible. Off
  /// on the editor canvas, where a detached clip sits over the composition and
  /// whatever is underneath *is* the backdrop — a checkerboard there would hide
  /// exactly what the key is meant to reveal.
  final bool previewTransparency;

  @override
  State<ChromaKeyedVideo> createState() => _ChromaKeyedVideoState();
}

class _ChromaKeyedVideoState extends State<ChromaKeyedVideo> {
  ui.FragmentShader? _shader;

  /// Whether this state has already waited on the program load once.
  ///
  /// A load that fails leaves the cached program `null`, so without this the
  /// retry below would re-request it on every rebuild it triggers itself.
  bool _awaitedProgram = false;

  @override
  void initState() {
    super.initState();
    _prepare();
  }

  @override
  void didUpdateWidget(ChromaKeyedVideo oldWidget) {
    super.didUpdateWidget(oldWidget);
    // A `FragmentShader`'s uniforms are read when the filter rasterizes, but
    // an `ImageFilter` that compares equal is not re-applied — so a changed key
    // needs a new shader object, not a mutated one.
    if (oldWidget.chromaKey?.key != widget.chromaKey?.key) _prepare();
  }

  void _prepare() {
    final key = widget.chromaKey?.key;
    if (key == null) {
      _disposeShader();
      return;
    }
    if (!ChromaKeyShader.isBackendSupported) return;

    if (ChromaKeyShader.programOrNull == null) {
      // First use in this process: load, then rebuild once it is ready. Until
      // then the unkeyed video shows, which is the same fallback as an
      // unsupported backend. A load that failed leaves the program null, so
      // only ever wait on it once — otherwise the rebuild this triggers would
      // request it again, forever.
      if (_awaitedProgram) return;
      _awaitedProgram = true;
      ChromaKeyShader.ensureLoaded().then((_) {
        if (mounted) setState(_prepare);
      });
      return;
    }

    final shader = ChromaKeyShader.build(key);
    if (shader == null) return;
    _disposeShader();
    _shader = shader;
  }

  void _disposeShader() {
    _shader?.dispose();
    _shader = null;
  }

  @override
  void dispose() {
    _disposeShader();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final chromaKey = widget.chromaKey;
    final shader = _shader;
    if (chromaKey == null || shader == null) return widget.child;

    return Stack(
      // The keyed video sizes the stack; the backdrop fills whatever that is.
      fit: StackFit.passthrough,
      children: [
        Positioned.fill(
          child: ChromaKeyBackdrop(
            chromaKey: chromaKey,
            sync: widget.backdropSync,
            previewTransparency: widget.previewTransparency,
          ),
        ),
        ImageFiltered(
          imageFilter: ui.ImageFilter.shader(shader),
          child: widget.child,
        ),
      ],
    );
  }
}
