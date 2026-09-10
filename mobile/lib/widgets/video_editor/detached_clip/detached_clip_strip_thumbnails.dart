// ABOUTME: Filmstrip behind a detached clip's bar on the timeline, so the row
// ABOUTME: shows what the clip is rather than just naming it

import 'dart:io';

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:openvine/blocs/video_editor/detached_clip_thumbnails/detached_clip_thumbnails_cubit.dart';
import 'package:openvine/widgets/video_editor/detached_clip/detached_clip_layer_view.dart'
    show detachedClipSourceKey;

/// Frames of a detached clip, tiled across its bar on the timeline.
///
/// Deliberately not the clip strip's tile: that one carries a raster phase and
/// a trim offset so frames stay anchored to the source recording through trim
/// and zoom. A detached clip's bar has no trim handles and no zoom of its own,
/// so evenly spaced frames are all it needs.
class DetachedClipStripThumbnails extends StatelessWidget {
  const DetachedClipStripThumbnails({required this.meta, super.key});

  /// The layer's `exportConfigs.meta`, as written by
  /// `DetachedClipLayerData.toMeta`.
  final Map<String, dynamic> meta;

  @override
  Widget build(BuildContext context) {
    final sourceKey = detachedClipSourceKey(meta);
    if (sourceKey == null) return const SizedBox.shrink();

    return BlocProvider<DetachedClipThumbnailsCubit>(
      // Keyed on the media rather than the map: a history write hands the
      // layer a fresh meta instance for the same clip, and rebuilding on that
      // would drop a finished strip and extract it again.
      key: ValueKey(sourceKey),
      create: (_) => DetachedClipThumbnailsCubit(
        meta: meta,
        devicePixelRatio: MediaQuery.devicePixelRatioOf(context),
        sourceKey: sourceKey,
      ),
      child: const _Strip(),
    );
  }
}

class _Strip extends StatelessWidget {
  const _Strip();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<
      DetachedClipThumbnailsCubit,
      DetachedClipThumbnailsState
    >(
      builder: (context, state) {
        final aspectRatio = state.aspectRatio;
        if (aspectRatio == null) return const SizedBox.shrink();

        return LayoutBuilder(
          builder: (context, constraints) {
            final height = constraints.maxHeight;
            final width = constraints.maxWidth;
            if (!height.isFinite ||
                !width.isFinite ||
                height <= 0 ||
                width <= 0) {
              return const SizedBox.shrink();
            }

            // One frame per slot roughly as wide as the clip is at this
            // height, so the frames read as a filmstrip rather than a
            // stretched smear. The slots then share the bar exactly: a whole
            // number of clip-width slots almost never sums to the bar, and the
            // remainder overflows the Row. Each frame is cover-fitted, so the
            // small aspect difference crops rather than distorts.
            final preferred = (height * aspectRatio).clamp(8.0, width);
            final slots = (width / preferred).ceil();
            final slotWidth = width / slots;
            final cacheHeight =
                (height * MediaQuery.devicePixelRatioOf(context)).round();

            return Row(
              children: [
                for (var i = 0; i < slots; i++)
                  SizedBox(
                    width: slotWidth,
                    height: height,
                    child: _Frame(
                      posterPath: state.posterPath,
                      path: _frameFor(state, i, slots),
                      cacheHeight: cacheHeight,
                    ),
                  ),
              ],
            );
          },
        );
      },
    );
  }

  /// The frame nearest the middle of slot [index] of [slots].
  ///
  /// Nearest rather than exact: the extraction fills in over several batches,
  /// so early on a slot borrows whichever frame is closest instead of showing
  /// a hole.
  String? _frameFor(DetachedClipThumbnailsState state, int index, int slots) {
    if (state.frames.isEmpty) return null;
    final at = Duration(
      microseconds: (state.span.inMicroseconds * (index + 0.5) / slots).round(),
    );

    DetachedClipFrame? best;
    var bestDelta = Duration.zero;
    for (final frame in state.frames) {
      final delta = frame.timestamp > at
          ? frame.timestamp - at
          : at - frame.timestamp;
      if (best == null || delta < bestDelta) {
        best = frame;
        bestDelta = delta;
      }
    }
    return best?.path;
  }
}

/// One slot of the filmstrip, falling back to the clip's poster and then to a
/// plain block while extraction catches up.
class _Frame extends StatelessWidget {
  const _Frame({
    required this.posterPath,
    required this.path,
    required this.cacheHeight,
  });

  final String? posterPath;
  final String? path;
  final int cacheHeight;

  @override
  Widget build(BuildContext context) {
    final poster = posterPath;
    final fallback = poster != null && File(poster).existsSync()
        ? Image.file(
            File(poster),
            fit: BoxFit.cover,
            excludeFromSemantics: true,
            errorBuilder: (_, _, _) => _empty(context),
          )
        : _empty(context);

    if (path == null) return fallback;
    return Image.file(
      File(path!),
      fit: BoxFit.cover,
      cacheHeight: cacheHeight,
      gaplessPlayback: true,
      excludeFromSemantics: true,
      errorBuilder: (_, _, _) => fallback,
    );
  }

  Widget _empty(BuildContext context) =>
      ColoredBox(color: context.vineColors.surfaceContainerHigh);
}
