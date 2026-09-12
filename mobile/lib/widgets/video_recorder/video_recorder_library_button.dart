import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/blocs/video_recorder/video_recorder_bloc.dart';
import 'package:openvine/constants/semantic_ids.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/clip_manager_provider.dart';
import 'package:openvine/widgets/video_clip/clip_thumbnail_image.dart';
import 'package:openvine/widgets/video_recorder/video_recorder_navigation.dart';

class VideoRecorderLibraryButton extends ConsumerStatefulWidget {
  const VideoRecorderLibraryButton({this.interactive = true, super.key});

  /// Whether tapping opens the library. The editor-hosted recorder shows the
  /// button purely as a capture-count indicator — navigating to the library
  /// mid editor session is not supported there.
  final bool interactive;

  @override
  ConsumerState<VideoRecorderLibraryButton> createState() =>
      _VideoRecorderLibraryButtonState();
}

class _VideoRecorderLibraryButtonState
    extends ConsumerState<VideoRecorderLibraryButton> {
  /// Last non-null thumbnail path seen, used as fallback while a new clip's
  /// thumbnail is still being generated (~1 s delay).
  String? _lastKnownThumbnailPath;

  /// Newest video-clip thumbnail from the persisted clip library.
  ///
  /// Kept separate from [_libraryStopMotionThumbnailPath] because each
  /// recorder mode opens a type-filtered library — the button must preview
  /// the newest entry of the current mode's type, not of the whole library.
  String? _libraryVideoThumbnailPath;

  /// Newest stop-motion-set thumbnail from the persisted clip library.
  String? _libraryStopMotionThumbnailPath;

  @override
  void initState() {
    super.initState();
    _loadLibraryThumbnail();
  }

  Future<void> _loadLibraryThumbnail() async {
    final service = ref.read(clipLibraryServiceProvider);
    final libraryClips = await service.getAllClips();
    if (!mounted) return;
    setState(() {
      _libraryVideoThumbnailPath = libraryClips
          .where((clip) => !clip.isStopMotion)
          .firstOrNull
          ?.thumbnailPath;
      _libraryStopMotionThumbnailPath = libraryClips
          .where((clip) => clip.isStopMotion)
          .firstOrNull
          ?.thumbnailPath;
    });
  }

  @override
  Widget build(BuildContext context) {
    final clips = ref.watch(clipManagerProvider.select((p) => p.clips));

    // Stop-motion captures accumulate frames in the recorder bloc (not the
    // clip manager) until assembled, so mirror the latest still and the
    // captured-frame count directly for a live preview during capture.
    final (capturesStills, stopMotionFrames) = context.select(
      (VideoRecorderBloc b) => (
        b.state.recorderMode.capturesStills,
        b.state.stopMotionFrames,
      ),
    );

    // Re-query library thumbnail whenever session clips change to empty
    // (e.g. user reset or deleted clips).
    // Reload library thumbnail whenever a clip is removed, since
    // scheduleDeleteLastClip soft-deletes from the clip library too.
    ref.listen(clipManagerProvider.select((p) => p.clips.length), (
      previous,
      next,
    ) {
      if (next < (previous ?? next + 1)) _loadLibraryThumbnail();
    });

    final currentPath = clips.lastOrNull?.thumbnailPath;
    if (currentPath != null) {
      _lastKnownThumbnailPath = currentPath;
    } else if (clips.isEmpty) {
      _lastKnownThumbnailPath = null;
    }

    final String? thumbnailPath;
    final int count;
    final bool hasClips;
    if (capturesStills) {
      // Newest still first, falling back to a prior library stop-motion set
      // so the button still opens the library before the first frame is shot.
      thumbnailPath =
          stopMotionFrames.lastOrNull ?? _libraryStopMotionThumbnailPath;
      count = stopMotionFrames.length;
      hasClips =
          stopMotionFrames.isNotEmpty ||
          _libraryStopMotionThumbnailPath != null;
    } else {
      thumbnailPath = _lastKnownThumbnailPath ?? _libraryVideoThumbnailPath;
      count = clips.length;
      hasClips = clips.isNotEmpty || _libraryVideoThumbnailPath != null;
    }

    return Padding(
      padding: const .only(left: 16),
      child: Semantics(
        identifier: SemanticIds.cameraLibraryButton,
        button: widget.interactive,
        // A stop-motion session counts captured stills, not clips — the clip
        // label would announce 12 stills as "12 clips". Its own label also
        // covers the zero case, which is reachable here: the button opens a
        // previous session's library before this one's first still is shot.
        label: hasClips
            ? (capturesStills
                  ? context.l10n.videoRecorderLibraryOpenStopMotionLabel(count)
                  : context.l10n.videoRecorderLibraryOpenLabel(count))
            : context.l10n.videoRecorderLibraryEmptyLabel,
        enabled: hasClips && widget.interactive,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: hasClips && widget.interactive
              ? () async {
                  await openRecorderLibrary(context, ref);

                  // Refresh library thumbnail after returning — user may have
                  // deleted clips or new thumbnails may have been recovered.
                  if (!context.mounted) return;
                  _loadLibraryThumbnail();
                }
              : null,
          child: Container(
            width: 40,
            height: 40,
            decoration: ShapeDecoration(
              color: context.vineColors.surfaceContainer,
              shape: RoundedRectangleBorder(
                side: BorderSide(width: 2, color: context.vineColors.onSurface),
                borderRadius: .circular(16),
              ),
            ),
            child: Stack(
              fit: StackFit.expand,
              children: [
                ClipRRect(
                  borderRadius: .circular(14),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    transitionBuilder: (child, animation) =>
                        FadeTransition(opacity: animation, child: child),
                    layoutBuilder: (currentChild, previousChildren) => Stack(
                      alignment: .center,
                      fit: .expand,
                      children: [...previousChildren, ?currentChild],
                    ),
                    child: thumbnailPath != null
                        ? ClipThumbnailImage(
                            key: ValueKey(thumbnailPath),
                            path: thumbnailPath,
                            fit: BoxFit.cover,
                            // Stop-motion stills are full-resolution photos;
                            // bound the decode to the 40px button.
                            cacheHeight:
                                (40 * MediaQuery.devicePixelRatioOf(context))
                                    .round(),
                            placeholder: const SizedBox.shrink(),
                          )
                        : const SizedBox.shrink(),
                  ),
                ),
                _SelectionCountBadge(count: count),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SelectionCountBadge extends StatelessWidget {
  const _SelectionCountBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: .topRight,
      child: FractionalTranslation(
        translation: const Offset(0.5, -0.5),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          transitionBuilder: (child, animation) =>
              ScaleTransition(scale: animation, child: child),
          child: count == 0
              ? const SizedBox.shrink()
              : Container(
                  constraints: const BoxConstraints(
                    minWidth: 20,
                    minHeight: 20,
                  ),
                  padding: const .symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    color: VineTheme.error,
                    shape: .circle,
                    border: .all(
                      width: 2,
                      color: context.vineColors.surfaceContainerHigh,
                    ),
                  ),
                  child: Column(
                    mainAxisSize: .min,
                    mainAxisAlignment: .center,
                    children: [
                      MediaQuery.withNoTextScaling(
                        child: Text(
                          count.toString(),
                          textAlign: .center,
                          style:
                              VineTheme.labelSmallFont(
                                color: VineTheme.whiteText,
                              ).copyWith(
                                fontFeatures: [const .tabularFigures()],
                              ),
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
