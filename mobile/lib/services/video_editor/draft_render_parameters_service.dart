// ABOUTME: Rebuilds a draft's full render parameters outside the editor
// ABOUTME: Restores overlay layers, timed filters, tune and audio from storage

import 'dart:async';

// The models AspectRatio is the one this file means; the Flutter widget of the
// same name is unused here.
import 'package:flutter/widgets.dart' hide AspectRatio;
import 'package:flutter_svg/flutter_svg.dart';
import 'package:media_cache/media_cache.dart';
import 'package:models/models.dart' show AspectRatio, StickerData;
import 'package:openvine/constants/video_editor_constants.dart';
import 'package:openvine/extensions/aspect_ratio_extensions.dart';
import 'package:openvine/extensions/complete_parameters_extensions.dart';
import 'package:openvine/models/divine_video_draft.dart';
import 'package:openvine/models/video_editor/detached_clip_layer.dart';
import 'package:openvine/services/video_editor/video_editor_audio_render.dart';
import 'package:openvine/utils/editor_text_fonts.dart';
import 'package:openvine/utils/open_vine_image_cache.dart';
import 'package:openvine/widgets/video_editor/detached_clip/detached_clip_layer_view.dart';
import 'package:openvine/widgets/video_editor/sticker_editor/video_editor_sticker.dart';
import 'package:pro_image_editor/pro_image_editor.dart';
import 'package:unified_logger/unified_logger.dart';

/// Thrown when a draft's authored overlays cannot be reproduced for a render.
///
/// Publishing is blocked rather than degraded. A video that silently lacks the
/// text, stickers or drawings the user placed is the exact failure #5203 was
/// filed for, and a published Nostr event cannot be quietly corrected —
/// so a failure the user can retry beats a wrong post they cannot take back.
class DraftOverlayRestoreException implements Exception {
  /// Creates an exception explaining which overlays could not be restored.
  const DraftOverlayRestoreException(this.message);

  /// Why the overlays could not be reproduced.
  final String message;

  @override
  String toString() => 'DraftOverlayRestoreException: $message';
}

/// Rebuilds the [CompleteParameters] needed to render a draft when no editor
/// session is open — posting straight from the library, most importantly.
///
/// A draft persists its editing parameters via `CompleteParameters.toMap`,
/// which drops `capturedLayers`, `filterStates`, `tuneAdjustments` and
/// `audioTracks`. Rendering from the restored map alone therefore produces a
/// video with none of the overlays the user authored: no text, stickers or
/// drawings, no timed filters or tune adjustments, and no added music.
///
/// Everything needed to rebuild them survives elsewhere in the draft —
/// `editorStateHistory` keeps the layers, filters and tune, the audio timeline
/// lives in the parameters' own `meta`, and a recorder-picked sound sits on the
/// draft itself. Only the *rasterized* layer bytes are unrecoverable from
/// storage, which is what [LayerRasterizer] regenerates by briefly mounting the
/// layers offscreen.
class DraftRenderParametersService {
  /// Creates a service that rasterizes through [rasterizer].
  const DraftRenderParametersService({required LayerRasterizer rasterizer})
    : _rasterizer = rasterizer;

  final LayerRasterizer _rasterizer;

  static const _logName = 'DraftRenderParametersService';

  /// Returns render parameters for [draft] with its overlays restored, or
  /// `null` when the draft carries nothing to restore (a plain recording with
  /// no edits and no sound, which renders fine without parameters).
  ///
  /// Rasterization needs a mounted `LayerRasterizerHost`, which `main.dart`
  /// installs above every route.
  ///
  /// Throws [DraftOverlayRestoreException] when the draft has overlays that
  /// cannot be reproduced — an unreadable state history, layers with no body
  /// size to place them against, or a rasterization that failed or came back
  /// short. The caller must not publish in that case; the video would be
  /// missing them.
  ///
  /// A draft with no overlays to begin with is not an error, and neither is a
  /// single sticker image that fails to load — that one costs its own sticker
  /// and is logged.
  Future<CompleteParameters?> buildForDraft(DivineVideoDraft draft) async {
    // `selectedSound` counts: a sound picked in the recorder is stored on the
    // draft alone, so a draft that never entered the editor still has audio to
    // carry into the render.
    if (draft.editorEditingParameters.isEmpty &&
        draft.editorStateHistory.isEmpty &&
        draft.selectedSound == null) {
      return null;
    }

    final base = draft.editorEditingParameters.isNotEmpty
        ? completeParametersFromDraftMap(draft.editorEditingParameters)
        : CompleteParameters.fromMap(const {});

    final audioTracks = buildRenderAudioTracks(
      metaTracks: base.audioTracksFromMeta,
      // Mirrors the in-editor export: a recorder-picked sound never becomes a
      // timeline track, so without this the same draft publishes with music
      // from the editor and silent from the library.
      selectedSound: draft.selectedSound,
      logName: _logName,
    );

    final stickers = <StickerData>[];
    final history = _importHistory(draft.editorStateHistory, stickers);
    final entry = _activeEntry(history);

    // `bodySize` only reaches storage through the editor's complete callback,
    // which fires on Done — a draft saved by backing out has its layers but no
    // parameters at all. The exported history carries the size those layers
    // were laid out against, so it is the fallback; both the capture and the
    // render read whichever one we settle on, so they stay consistent either
    // way. `safeParseSize` yields `Size.zero` for a history that carries no
    // size, which is no more usable than none at all.
    final historySize = history?.lastRenderedImgSize;
    final bodySize =
        base.bodySize ??
        (historySize != null && !historySize.isEmpty ? historySize : null);

    final capturedLayers = entry == null
        ? const <ExportedLayer>[]
        : await _rasterizeLayers(
            layers: entry.layers,
            stickers: stickers,
            bodySize: bodySize,
            aspectRatio: draft.clips.isNotEmpty
                ? draft.clips.first.targetAspectRatio
                : AspectRatio.square,
          );

    Log.info(
      'Restored draft render parameters: ${capturedLayers.length} layer(s), '
      '${entry?.filters.length ?? 0} filter(s), '
      '${entry?.tuneAdjustments.length ?? 0} tune adjustment(s), '
      '${audioTracks.length} audio track(s)',
      name: _logName,
      category: LogCategory.video,
    );

    return base.copyWith(
      capturedLayers: capturedLayers,
      filterStates: entry?.filters ?? const [],
      tuneAdjustments: entry?.tuneAdjustments ?? const [],
      audioTracks: audioTracks,
      blur: entry?.blur ?? base.blur,
      // The render scales and centres the captured layers against this, so it
      // has to be the size they were captured at — otherwise a fallback size
      // would place them correctly in the raster and wrongly in the video.
      bodySize: bodySize,
    );
  }

  /// Deserializes [stateHistory], recording every sticker it rehydrates into
  /// [stickers].
  ///
  /// Returns `null` for an empty history.
  ///
  /// Throws [DraftOverlayRestoreException] when a non-empty history cannot be
  /// read: it may well describe layers, and there is no way to tell from a map
  /// that failed to parse, so it counts as overlays we cannot reproduce.
  ImportStateHistory? _importHistory(
    Map<String, dynamic> stateHistory,
    List<StickerData> stickers,
  ) {
    if (stateHistory.isEmpty) return null;

    try {
      return ImportStateHistory.fromMap(
        stateHistory,
        configs: ImportEditorConfigs(
          widgetLoader: (id, {meta}) {
            if (meta == null) return const SizedBox.shrink();
            // A detached clip is composited from its own video file, so its
            // raster is thrown away — but the rasterizer drops a layer that
            // produces no image and reports the run as a partial bake, so it
            // still has to mount as something with a size. Its poster never
            // opens a decoder, unlike the canvas' live view.
            if (DetachedClipLayerData.isDetachedClipMeta(meta)) {
              return DetachedClipPoster(meta: meta);
            }
            final sticker = StickerData.fromJson(meta);
            stickers.add(sticker);
            return VideoEditorSticker(
              sticker: sticker,
              enableLimitCacheSize: false,
            );
          },
        ),
      );
    } catch (error, stackTrace) {
      Log.error(
        'Failed to restore editor state history for render',
        name: _logName,
        category: LogCategory.video,
        error: error,
        stackTrace: stackTrace,
      );
      throw DraftOverlayRestoreException(
        'The editor state history could not be read: $error',
      );
    }
  }

  /// Returns the entry the user last had active, or `null` for an editor
  /// position outside the history — `editorPosition` is `-1` for a session
  /// that was never edited.
  EditorStateHistory? _activeEntry(ImportStateHistory? history) {
    if (history == null) return null;
    final position = history.editorPosition;
    if (position < 0 || position >= history.stateHistory.length) return null;
    return history.stateHistory[position];
  }

  /// Bakes [layers] into images the render can composite over the video.
  ///
  /// Returns an empty list when there is nothing to bake. Throws
  /// [DraftOverlayRestoreException] when there are layers but they cannot be
  /// baked — a missing [bodySize] leaves their offsets unresolvable, a failed
  /// capture leaves them unrendered, and a capture that comes back short
  /// dropped some of them. All three would otherwise publish a video without
  /// overlays the user can see in the draft.
  Future<List<ExportedLayer>> _rasterizeLayers({
    required List<Layer> layers,
    required List<StickerData> stickers,
    required Size? bodySize,
    required AspectRatio aspectRatio,
  }) async {
    if (layers.isEmpty) return const [];

    if (bodySize == null || bodySize.isEmpty) {
      throw DraftOverlayRestoreException(
        'The draft has ${layers.length} layer(s) but no editor body size, so '
        'their positions cannot be resolved',
      );
    }

    final videoSize = VideoEditorConstants.quality.resolutionForAspectRatio(
      aspectRatio,
    );

    try {
      // `configs` is deliberately left at the package default. Only a few
      // values change how a layer *renders* rather than how it is edited —
      // `textEditor.initFontSize` (which scales text and emoji layers),
      // `textEditor.style.leadingDistribution`, `emojiEditor.style.textStyle`,
      // `stickerEditor.initWidth` and `paintEditor.censorConfigs` — and the
      // editor canvas overrides none of them. Both sides reading the same
      // defaults is what keeps a re-render identical to what the user saw; if
      // the canvas ever overrides one, mirror it here.
      //
      // `configs.theme` is the one exception, and it is deliberate. The canvas
      // does override it (so its subtree can resolve `context.vineColors`
      // instead of the silent dark fallback), and the rasterizer host wraps
      // captured layers in it too. It stays unmirrored because nothing this
      // app puts in a layer reads the ambient text theme: emoji layers — the
      // only layer type that does, via `platformTextStyle` — cannot be created
      // here, and every `TextLayer` carries an explicit `textStyle`, which
      // `RoundedBackgroundText` uses instead of `DefaultTextStyle`. Introducing
      // an emoji layer, or a text layer with a null `textStyle`, makes the two
      // sides diverge and this has to be mirrored after all.
      final captured = await _rasterizer.capture(
        layers: layers,
        editorBodySize: bodySize,
        // The render scales each layer by `videoSize.width / bodySize.width`
        // (see VideoEditorRenderService.buildImageLayers), so capturing at
        // that ratio lands one raster pixel per output pixel.
        basePixelRatio: (videoSize.width / bodySize.width).clamp(1.0, 10.0),
        awaitContentReady: () => _prepareLayerContent(layers, stickers),
      );

      // `captureAllLayers` drops a layer whose repaint boundary produced no
      // image rather than reporting it, so a short result is a silent partial
      // bake — the exact degrade this service exists to prevent.
      if (captured.length != layers.length) {
        throw DraftOverlayRestoreException(
          'Only ${captured.length} of ${layers.length} layer(s) could be '
          'rasterized',
        );
      }
      return captured;
    } on DraftOverlayRestoreException {
      rethrow;
    } catch (error, stackTrace) {
      Log.error(
        'Failed to rasterize ${layers.length} draft layer(s) for render',
        name: _logName,
        category: LogCategory.video,
        error: error,
        stackTrace: stackTrace,
      );
      throw DraftOverlayRestoreException(
        'Rasterizing ${layers.length} layer(s) failed: $error',
      );
    }
  }

  /// Resolves everything the mounted layers need before they are captured.
  ///
  /// Runs while the layers are mounted but before the capture frame, so both
  /// halves land in the first build the rasterizer measures: fonts for text
  /// and emoji layers, images for stickers.
  Future<void> _prepareLayerContent(
    List<Layer> layers,
    List<StickerData> stickers,
  ) => Future.wait([
    if (layers.any((layer) => layer is TextLayer || layer is EmojiLayer))
      preloadEditorTextFonts(),
    _precacheStickers(stickers),
  ]);

  /// Loads every sticker's image into the cache the sticker widget reads from.
  ///
  /// Sticker layers paint nothing until their image resolves, and network
  /// stickers additionally fade in from fully transparent — capturing before
  /// either finishes yields a blank layer. Warming the cache first makes the
  /// mounted widget resolve on its first build, which also skips the fade
  /// (`AnimatedOpacity` does not animate into its initial value).
  ///
  /// Failures are logged and swallowed: one unreachable sticker should cost
  /// that sticker, not the whole publish.
  Future<void> _precacheStickers(List<StickerData> stickers) async {
    if (stickers.isEmpty) return;

    await Future.wait(
      stickers.map((sticker) async {
        try {
          final networkUrl = sticker.networkUrl;
          final assetPath = sticker.assetPath;
          if (networkUrl != null) {
            await _resolveImage(
              MediaCacheImageProvider(
                networkUrl,
                cacheManager: openVineImageCache,
              ),
            );
          } else if (assetPath != null) {
            // Populates flutter_svg's own cache, which SvgPicture.asset reads.
            await SvgAssetLoader(assetPath).loadBytes(null);
          }
        } catch (error) {
          Log.warning(
            'Could not preload sticker for render: $error',
            name: _logName,
            category: LogCategory.video,
          );
        }
      }),
    );
  }

  /// Resolves [provider] into the image cache and completes once it settled.
  ///
  /// This is `precacheImage` without the [BuildContext] — the service has no
  /// business holding one, and the sticker providers ignore the configuration
  /// a context would supply. Errors complete normally so a broken sticker
  /// image cannot stall the render.
  Future<void> _resolveImage(ImageProvider<Object> provider) {
    final completer = Completer<void>();
    final stream = provider.resolve(ImageConfiguration.empty);

    late final ImageStreamListener listener;
    void finish() {
      stream.removeListener(listener);
      if (!completer.isCompleted) completer.complete();
    }

    listener = ImageStreamListener(
      (image, _) {
        image.dispose();
        finish();
      },
      onError: (error, stackTrace) {
        Log.warning(
          'Could not preload sticker image for render: $error',
          name: _logName,
          category: LogCategory.video,
        );
        finish();
      },
    );
    stream.addListener(listener);

    return completer.future;
  }
}
