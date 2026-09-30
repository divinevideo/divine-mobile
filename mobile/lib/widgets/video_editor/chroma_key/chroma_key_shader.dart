// ABOUTME: Loads and configures the live chroma-key preview fragment shader.
// ABOUTME: Wraps availability behind one guard so callers degrade to the
// ABOUTME: unkeyed video instead of throwing on unsupported backends.

import 'dart:ui' as ui;

import 'package:openvine/utils/chroma_key_math.dart';
import 'package:pro_video_editor/pro_video_editor.dart'
    show ChromaKey, ChromaKeyDetector;
import 'package:unified_logger/unified_logger.dart';

/// The compiled `shaders/chroma_key.frag` program.
///
/// The program is loaded once per process and cached: building the shader per
/// frame is cheap, compiling it is not.
abstract class ChromaKeyShader {
  static const _assetKey = 'shaders/chroma_key.frag';
  static const _logName = 'ChromaKeyShader';

  static ui.FragmentProgram? _program;
  static Future<void>? _loading;

  static bool _loggedUnsupported = false;

  /// Whether this backend can run a keyed preview at all.
  ///
  /// `ImageFilter.shader` is Impeller-only and throws on the Skia backend. That
  /// is not hypothetical: Android falls back to Skia below API 29 and to
  /// Impeller's OpenGLES backend without Vulkan. Callers show the unkeyed video
  /// instead; the key still applies to the exported file.
  ///
  /// Logs once per process the first time it reports `false`, so a preview that
  /// silently does nothing is diagnosable from a log rather than by bisecting
  /// the render stack.
  static bool get isBackendSupported {
    final supported = ui.ImageFilter.isShaderFilterSupported;
    if (!supported && !_loggedUnsupported) {
      _loggedUnsupported = true;
      Log.warning(
        'Chroma-key live preview is off: this renderer has no shader image '
        'filter (Impeller-only). The editor shows the unkeyed video; the key '
        'is still applied when the video is exported.',
        name: _logName,
        category: LogCategory.video,
      );
    }
    return supported;
  }

  /// Whether a keyed preview can be rendered right now.
  static bool get isSupported => isBackendSupported && _program != null;

  /// The loaded program, or `null` while loading or after a load failure.
  static ui.FragmentProgram? get programOrNull => _program;

  /// Loads and caches the program. Safe to call repeatedly and concurrently.
  ///
  /// Never throws: a shader that fails to load degrades the preview to the
  /// unkeyed video rather than taking the editor down with it.
  static Future<void> ensureLoaded() {
    if (_program != null) return Future<void>.value();
    return _loading ??= _load();
  }

  static Future<void> _load() async {
    if (!isBackendSupported) return;
    try {
      _program = await ui.FragmentProgram.fromAsset(_assetKey);
    } catch (error, stackTrace) {
      Log.error(
        'Failed to load the chroma-key preview shader; '
        'the editor will show the unkeyed video',
        name: _logName,
        error: error,
        stackTrace: stackTrace,
        category: LogCategory.video,
      );
    } finally {
      _loading = null;
    }
  }

  /// Builds a shader configured for [key], or `null` when unsupported.
  ///
  /// The caller owns the returned shader and must `dispose()` it.
  static ui.FragmentShader? build(ChromaKey key) {
    final program = _program;
    if (program == null || !isBackendSupported) return null;

    final projection = ChromaKeyProjection.of(key.color);
    // Uniforms 0 and 1 are the bound texture's size, which the engine sets.
    return program.fragmentShader()
      ..setFloat(2, projection.cb)
      ..setFloat(3, projection.cr)
      ..setFloat(4, projection.directionCb)
      ..setFloat(5, projection.directionCr)
      ..setFloat(6, key.similarity)
      ..setFloat(7, key.smoothness)
      ..setFloat(8, key.spill)
      ..setFloat(
        9,
        ChromaKeyDetector.lumaOf(key.color.r, key.color.g, key.color.b),
      )
      ..setFloat(
        10,
        ChromaKeyDetector.lumaWeightOf(projection.cb, projection.cr),
      );
  }
}
