import 'dart:async';
import 'dart:io';

import 'package:divine_ui/divine_ui.dart';
import 'package:divine_video_player/divine_video_player.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/constants/video_editor_constants.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/providers/video_editor_provider.dart';
import 'package:openvine/services/video_thumbnail_service.dart';
import 'package:openvine/widgets/branded_loading_indicator.dart';
import 'package:openvine/widgets/video_clip/clip_thumbnail_image.dart';
import 'package:openvine/widgets/video_metadata/metadata_hero_corners.dart';
import 'package:openvine/widgets/vine_cached_image.dart';
import 'package:pro_video_editor/pro_video_editor.dart';
import 'package:time_formatter/time_formatter.dart';
import 'package:unified_logger/unified_logger.dart';

// Shared dimensions for the cover-strip thumbnails. These values appear
// in multiple places (slot generation, render layout, output sizing) and
// must stay in sync.
const double _stripHeight = 64;
const double _stripThumbWidth = 48;

/// Full-screen cover selector for a recorded video clip.
///
/// The user scrubs through a thumbnail strip at the bottom to pick the frame
/// that will be used as the post cover image.
class VideoMetadataCoverScreen extends ConsumerStatefulWidget {
  /// Creates a cover selection screen for the given [clip].
  ///
  /// [thumbnailUrl] is shown as a placeholder while the video player
  /// initialises. Pass the existing cover URL in the edit flow.
  const VideoMetadataCoverScreen({
    required this.clip,
    this.thumbnailUrl,
    super.key,
  });

  /// The clip whose cover is being edited.
  final DivineVideoClip clip;

  /// Optional thumbnail URL shown while the player is not yet ready.
  final String? thumbnailUrl;

  @override
  ConsumerState<VideoMetadataCoverScreen> createState() =>
      _VideoMetadataCoverScreenState();
}

class _VideoMetadataCoverScreenState
    extends ConsumerState<VideoMetadataCoverScreen> {
  DivineVideoPlayerController? _controller;

  List<StripThumbnail> _stripThumbnails = const [];
  // Tracks every strip thumbnail path the service has ever emitted, so
  // dispose can clean them up even if a later batch superseded the list
  // currently held in [_stripThumbnails].
  final Set<String> _allStripThumbnailPaths = <String>{};
  // Cancelled in _disposeStripResources through a local alias, so the field is
  // nulled before the await.
  // ignore: cancel_subscriptions
  StreamSubscription<List<StripThumbnail>>? _stripSubscription;

  Duration _selectedPosition = Duration.zero;

  bool _playerReady = false;

  /// True when the preview player conclusively failed to load the video
  /// (e.g. a decoder init that never recovered). The strip picker keeps
  /// working without a live preview in that case.
  bool _playerInitFailed = false;

  bool _isConfirming = false;

  bool _isSeeking = false;
  Duration _videoDuration = Duration.zero;
  Duration? _pendingSeekPosition;
  int _seekEpoch = 0;

  @override
  void initState() {
    super.initState();
    _selectedPosition = widget.clip.thumbnailTimestamp;
    unawaited(_initializePlayer());
  }

  Future<void> _initializePlayer() async {
    // Stop-motion clips have no scrubable video; their cover is the first
    // captured frame (already set as the thumbnail).
    final video = widget.clip.video;
    if (video == null) return;
    final localPath = await video.safeFilePath();

    if (!mounted) return;

    final metadata = await ProVideoEditor.instance.getMetadata(
      EditorVideo.file(localPath),
    );
    if (!mounted) return;
    _videoDuration = metadata.duration;

    final controller = DivineVideoPlayerController(
      useTexture: true,
      debugLabel: 'metadata_cover',
    );
    try {
      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      // Prepare directly at the cover position instead of loading at 0 and
      // seeking afterwards: the decoder's very first frame is then already
      // the selected one. Loading-then-seeking renders frame 0 first, which
      // flashed the wrong frame for the length of the seek right after the
      // hero landed.
      await controller.setClips(
        [VideoClip.file(localPath)],
        startPosition: _selectedPosition,
      );
      // Unmounting during the await leaves the controller unreachable but
      // still registered, so dispose() has already run against a null
      // _controller and nothing else will release the decoder.
      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() {
        _controller = controller;
        _playerReady = true;
        _seekEpoch++;
        _isSeeking = false;
        _pendingSeekPosition = null;
      });
    } catch (e, stackTrace) {
      // A dead preview must not take the cover picker down with it — the
      // strip below still lets the user scrub and confirm a frame.
      Log.error(
        'Cover preview player failed to load the video',
        name: 'VideoMetadataCoverScreen',
        error: e,
        stackTrace: stackTrace,
      );
      unawaited(controller.dispose());
      if (!mounted) return;
      setState(() => _playerInitFailed = true);
    }

    // Start strip extraction only after the player has acquired its decoder
    // (or conclusively failed to). Both read the same file; the
    // MediaMetadataRetriever strip frames would otherwise contend with the
    // player's decoder init and can leave the preview stuck on
    // DECODER_INIT_FAILED (a scarce hardware-decoder pool).
    if (mounted) _startStripGeneration(localPath);
  }

  Future<void> _startStripGeneration(String videoPath) async {
    final view = WidgetsBinding.instance.platformDispatcher.views.first;
    final pixelRatio = view.devicePixelRatio;
    final screenWidth = view.physicalSize.width / pixelRatio;

    final slotCount = ((screenWidth - 32) / _stripThumbWidth).ceil().clamp(
      1,
      100,
    );
    final durationMs = _videoDuration.inMilliseconds;

    // One timestamp per slot, evenly distributed across the video duration.
    // These are passed as priorityTimestamps so the first batch already
    // covers every slot — no remapping as later batches arrive.
    final slotTimestamps = List<Duration>.generate(
      slotCount,
      // (i + 0.5) targets the slot's midpoint so the priority frame is
      // visually centered in the thumbnail.
      (i) => Duration(
        milliseconds: ((i + 0.5) * durationMs / slotCount).round().clamp(
          0,
          durationMs,
        ),
      ),
    );

    // thumbsPerSecond drives how many density thumbnails the service adds
    // on top of the priority set. Setting it to slotCount / durationSec
    // (minimum 1) keeps the total as close to slotCount as possible,
    // avoiding large numbers of thumbnails that will never be displayed.
    final durationSec = _videoDuration.inSeconds.clamp(1, 99999);
    final thumbsPerSecond = (slotCount / durationSec).ceil().clamp(1, 20);

    _stripSubscription =
        VideoThumbnailService.generateStripThumbnails(
          videoPath: videoPath,
          clipId: widget.clip.id,
          duration: _videoDuration,
          outputSize: Size(
            _stripThumbWidth * pixelRatio,
            _stripHeight * pixelRatio,
          ),
          thumbsPerSecond: thumbsPerSecond,
          priorityTimestamps: slotTimestamps,
          batchSize: 10,
        ).listen(
          (thumbnails) {
            for (final t in thumbnails) {
              _allStripThumbnailPaths.add(t.path);
            }
            if (mounted) {
              setState(() => _stripThumbnails = thumbnails);
            }
          },
          // A mid-stream extraction failure is already logged by the
          // service; keep the batches that arrived so the strip stays
          // usable for cover selection.
          onError: (Object _, StackTrace _) {},
        );
  }

  Future<void> _seekTo(Duration position) async {
    // With a failed player the strip still drives frame selection — move
    // the cursor without a live preview so the user can pick a cover.
    if (!_playerReady && !_playerInitFailed) return;
    _selectedPosition = position;
    if (mounted) setState(() {});
    if (!_playerReady) return;

    if (_isSeeking) {
      _pendingSeekPosition = position;
      return;
    }

    _isSeeking = true;
    final epoch = _seekEpoch;
    try {
      await _controller?.seekTo(position);
      if (_seekEpoch != epoch) {
        _pendingSeekPosition = null;
        return;
      }

      while (_pendingSeekPosition != null && mounted) {
        final pending = _pendingSeekPosition!;
        _pendingSeekPosition = null;
        await _controller?.seekTo(pending);
        if (_seekEpoch != epoch) {
          _pendingSeekPosition = null;
          break;
        }
      }
    } finally {
      if (_seekEpoch == epoch) {
        _isSeeking = false;
      }
    }
  }

  Future<void> _confirm() async {
    if (_isConfirming) return;
    setState(() => _isConfirming = true);

    var didSucceed = false;
    try {
      final video = widget.clip.video;
      if (video == null) {
        // Stop-motion: the cover is the first captured frame; nothing to
        // re-extract. Close without changes.
        if (mounted) Navigator.of(context).pop();
        return;
      }
      final videoPath = await video.safeFilePath();
      if (videoPath.isNotEmpty) {
        final result = await VideoThumbnailService.extractThumbnail(
          videoPath: videoPath,
          targetTimestamp: _selectedPosition,
        );
        if (result != null && mounted) {
          if (video.networkUrl != null) {
            // Published video — return the local path to the caller.
            // The Blossom upload and republish happen when the user presses Update.
            Navigator.of(context).pop(result.path);
            return;
          } else {
            // Draft video — update via videoEditorProvider.
            ref
                .read(videoEditorProvider.notifier)
                .updateCover(
                  thumbnailPath: result.path,
                  thumbnailTimestamp: _selectedPosition,
                );
            didSucceed = true;
          }
        }
      }
    } catch (e, stackTrace) {
      Log.error(
        'Failed to extract cover thumbnail',
        name: 'VideoMetadataCoverScreen',
        error: e,
        stackTrace: stackTrace,
      );
    }

    if (!mounted) return;
    if (didSucceed) {
      SemanticsService.sendAnnouncement(
        View.of(context),
        context.l10n.videoMetadataEditCoverSuccessAnnouncement,
        Directionality.of(context),
      );
      context.pop();
      return;
    }

    // Stay on screen so the user can retry. Surface the failure.
    final message = context.l10n.videoMetadataEditCoverFailedSnackbar;
    SemanticsService.sendAnnouncement(
      View.of(context),
      message,
      Directionality.of(context),
    );
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(DivineSnackbarContainer.snackBar(message));
    setState(() => _isConfirming = false);
  }

  @override
  void dispose() {
    unawaited(_disposeStripResources());
    unawaited(_controller?.dispose());
    super.dispose();
  }

  /// Cancels the strip generation stream and deletes every thumbnail file
  /// the service ever produced for this screen instance. Awaiting the
  /// cancel before deleting ensures any in-flight batch has been flushed
  /// into [_allStripThumbnailPaths] first.
  Future<void> _disposeStripResources() async {
    final subscription = _stripSubscription;
    _stripSubscription = null;
    if (subscription != null) {
      await subscription.cancel();
    }
    for (final path in _allStripThumbnailPaths) {
      File(path).delete().ignore();
    }
    _allStripThumbnailPaths.clear();
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: VideoEditorConstants.uiOverlayStyleFor(context.vineColors),
      child: SafeArea(
        child: Scaffold(
          backgroundColor: context.vineColors.surfaceContainerHigh,
          body: Stack(
            fit: .expand,
            children: [
              Column(
                crossAxisAlignment: .stretch,
                spacing: 8,
                children: [
                  Expanded(
                    child: Stack(
                      fit: .expand,
                      children: [
                        RepaintBoundary(
                          child: _VideoArea(
                            clip: widget.clip,
                            thumbnailUrl: widget.thumbnailUrl,
                            controller: _playerReady ? _controller : null,
                          ),
                        ),

                        if (!_playerInitFailed &&
                            (_controller == null ||
                                !_controller!.isInitialized))
                          const Center(child: BrandedLoadingIndicator()),
                      ],
                    ),
                  ),
                  _BottomArea(
                    clip: widget.clip,
                    thumbnail: (
                      path: widget.clip.thumbnailPath,
                      networkUrl: widget.thumbnailUrl,
                    ),
                    stripThumbnails: _stripThumbnails,
                    clipDuration: _videoDuration,
                    selectedPosition: _selectedPosition,
                    onSeek: _seekTo,
                  ),
                ],
              ),
              _TopBar(
                isConfirming: _isConfirming,
                onClose: () => context.pop(),
                onConfirm: _confirm,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _VideoArea extends StatefulWidget {
  const _VideoArea({
    required this.clip,
    required this.controller,
    this.thumbnailUrl,
  });

  final DivineVideoClip clip;
  final DivineVideoPlayerController? controller;
  final String? thumbnailUrl;

  @override
  State<_VideoArea> createState() => _VideoAreaState();
}

class _VideoAreaState extends State<_VideoArea> {
  StreamSubscription<DivineVideoPlayerState>? _sub;
  double _videoAR = 0;

  @override
  void initState() {
    super.initState();
    _subscribeToController(widget.controller);
  }

  @override
  void didUpdateWidget(_VideoArea oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      _sub?.cancel();
      _subscribeToController(widget.controller);
    }
  }

  void _subscribeToController(DivineVideoPlayerController? controller) {
    _videoAR = controller?.state.aspectRatio ?? 0;
    _sub = controller?.stateStream.listen((state) {
      final ar = state.aspectRatio;
      if (ar > 0 && ar != _videoAR) {
        setState(() => _videoAR = ar);
      }
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  Widget _buildPlaceholder() {
    final networkUrl = widget.thumbnailUrl;
    if (networkUrl != null) {
      return VineCachedImage(imageUrl: networkUrl);
    }
    final localPath = widget.clip.thumbnailPath;
    if (localPath != null) {
      return ClipThumbnailImage(path: localPath, fit: BoxFit.cover);
    }
    return ColoredBox(color: context.vineColors.onSurfaceMuted);
  }

  @override
  Widget build(BuildContext context) {
    final videoAR = _videoAR > 0
        ? _videoAR
        : widget.clip.targetAspectRatio.value;
    final isSquare = widget.clip.targetAspectRatio.value == 1.0;
    final coverBorderRadius = isSquare
        ? BorderRadius.circular(12)
        : const BorderRadius.vertical(bottom: Radius.circular(32));
    final player = ClipRRect(
      borderRadius: coverBorderRadius,
      child: FittedBox(
        fit: isSquare ? BoxFit.contain : BoxFit.cover,
        child: SizedBox(
          width: 1000 * videoAR,
          height: 1000,
          child: DivineVideoPlayer(
            controller: widget.controller,
            placeholder: _buildPlaceholder(),
            // The thumbnail is already on screen (it is what the hero flew
            // in) and the player is swapped in only once its first frame is
            // decoded. Without this the widget hard-cuts thumbnail→texture,
            // which reads as a flicker; cross-fade instead.
            crossFadePlaceholder: true,
          ),
        ),
      ),
    );
    return Hero(
      tag: VideoEditorConstants.heroMetaPreviewId,
      createRectTween: (begin, end) => RectTween(begin: begin, end: end),
      // The thumbnails round themselves from outside their Hero, so on the way
      // back the shuttle arrives with no rounding of its own.
      flightShuttleBuilder: (_, animation, _, _, toHeroContext) =>
          MetadataHeroCorners(
            animation: animation,
            destinationBorderRadius: coverBorderRadius,
            child: (toHeroContext.widget as Hero).child,
          ),
      child: AspectRatio(
        aspectRatio: widget.clip.targetAspectRatio.value,
        child: isSquare ? Center(child: player) : player,
      ),
    );
  }
}

/// Controls overlaying the preview, held back until the route transition has
/// settled.
///
/// The hero flies in the navigator's overlay, which sits above everything the
/// route itself paints. A bar rendered from the first frame is therefore
/// covered by the flying video for the length of the flight and only pops in
/// front once the hero lands — so it fades in on arrival instead.
class _TopBar extends StatefulWidget {
  const _TopBar({
    required this.isConfirming,
    required this.onClose,
    required this.onConfirm,
  });

  static const _fadeDuration = Duration(milliseconds: 180);

  final bool isConfirming;
  final VoidCallback onClose;
  final VoidCallback onConfirm;

  @override
  State<_TopBar> createState() => _TopBarState();
}

class _TopBarState extends State<_TopBar> {
  Animation<double>? _entranceAnimation;
  bool _entered = false;

  /// Only a bar that actually waited for a flight has something to fade in
  /// from. Shown without a transition it just belongs on screen.
  bool _fadeIn = false;

  @override
  void initState() {
    super.initState();
    // Armed from a post-frame callback, the same shape
    // [CodecHeavySurfaceGuard] uses, for two independent reasons. Reading the
    // route in initState throws outright, and reading it during the first
    // build resolves the right route but the wrong animation: Navigator
    // renders a newly pushed route offstage on its first frame so heroes can
    // be measured, and ModalRoute swaps in kAlwaysCompleteAnimation while
    // offstage. The bar would see `completed` and decide it had nothing to
    // wait for.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _armAfterEntrance();
    });
  }

  void _armAfterEntrance() {
    final animation = ModalRoute.of(context)?.animation;
    if (animation == null || animation.isCompleted) {
      _reveal(fadeIn: false);
      return;
    }
    _entranceAnimation = animation..addStatusListener(_onEntranceStatus);
  }

  void _onEntranceStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed) return;
    _detachEntranceListener();
    if (mounted) _reveal(fadeIn: true);
  }

  void _reveal({required bool fadeIn}) {
    if (_entered) return;
    setState(() {
      _entered = true;
      _fadeIn = fadeIn;
    });
  }

  void _detachEntranceListener() {
    _entranceAnimation?.removeStatusListener(_onEntranceStatus);
    _entranceAnimation = null;
  }

  @override
  void dispose() {
    _detachEntranceListener();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      // Opacity 0 drops the buttons from the semantics tree but still hit
      // tests, so taps have to be blocked separately.
      ignoring: !_entered,
      child: AnimatedOpacity(
        opacity: _entered ? 1 : 0,
        duration: _fadeIn && !MediaQuery.disableAnimationsOf(context)
            ? _TopBar._fadeDuration
            : Duration.zero,
        curve: Curves.easeOut,
        child: _TopBarContent(
          isConfirming: widget.isConfirming,
          onClose: widget.onClose,
          onConfirm: widget.onConfirm,
        ),
      ),
    );
  }
}

class _TopBarContent extends StatelessWidget {
  const _TopBarContent({
    required this.isConfirming,
    required this.onClose,
    required this.onConfirm,
  });

  final bool isConfirming;
  final VoidCallback onClose;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: .topCenter,
      child: SafeArea(
        bottom: false,
        child: Container(
          height: kToolbarHeight,
          padding: const .symmetric(horizontal: 16),
          child: Row(
            spacing: 16,
            children: [
              DivineIconButton(
                icon: .x,
                type: .ghostOverMedia,
                size: .small,
                semanticLabel:
                    context.l10n.videoMetadataEditCoverCloseSemanticLabel,
                onPressed: onClose,
              ),
              Expanded(
                child: Text(
                  context.l10n.videoMetadataEditCoverTitle,
                  style: VineTheme.titleMediumFont(
                    color: VineTheme.primaryText,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (isConfirming)
                Semantics(
                  label:
                      context.l10n.videoMetadataEditCoverConfirmSemanticLabel,
                  button: true,
                  enabled: false,
                  // The indicator's own "Loading" label merges in, so the
                  // disabled confirm button announces that it is busy rather
                  // than just unavailable.
                  child: const BrandedLoadingIndicator(size: 44),
                )
              else
                DivineIconButton(
                  icon: .check,
                  size: .small,
                  semanticLabel:
                      context.l10n.videoMetadataEditCoverConfirmSemanticLabel,
                  onPressed: onConfirm,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BottomArea extends StatelessWidget {
  const _BottomArea({
    required this.clip,
    required this.thumbnail,
    required this.stripThumbnails,
    required this.clipDuration,
    required this.selectedPosition,
    required this.onSeek,
  });

  final DivineVideoClip clip;
  final ({String? path, String? networkUrl})? thumbnail;
  final List<StripThumbnail> stripThumbnails;
  final Duration clipDuration;
  final Duration selectedPosition;
  final ValueChanged<Duration> onSeek;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const .fromLTRB(16, 0, 16, 12),
      child: ClipRRect(
        borderRadius: .circular(4),
        child: _ThumbnailStrip(
          clip: clip,
          thumbnail: thumbnail,
          stripThumbnails: stripThumbnails,
          clipDuration: clipDuration,
          selectedPosition: selectedPosition,
          onSeek: onSeek,
        ),
      ),
    );
  }
}

class _ThumbnailStrip extends StatefulWidget {
  const _ThumbnailStrip({
    required this.clip,
    required this.thumbnail,
    required this.stripThumbnails,
    required this.clipDuration,
    required this.selectedPosition,
    required this.onSeek,
  });

  final DivineVideoClip clip;
  final ({String? path, String? networkUrl})? thumbnail;
  final List<StripThumbnail> stripThumbnails;
  final Duration clipDuration;
  final Duration selectedPosition;
  final ValueChanged<Duration> onSeek;

  @override
  State<_ThumbnailStrip> createState() => _ThumbnailStripState();
}

class _ThumbnailStripState extends State<_ThumbnailStrip> {
  static const double _cursorWidth = 36;
  static const Duration _semanticSeekStep = Duration(milliseconds: 500);

  List<StripThumbnail>? _cachedThumbnails;
  int? _cachedCount;
  List<String?> _cachedPaths = const [];

  void _updateSlotCache(int count) {
    if (widget.stripThumbnails == _cachedThumbnails && count == _cachedCount) {
      return;
    }
    _cachedThumbnails = widget.stripThumbnails;
    _cachedCount = count;
    _cachedPaths = List<String?>.generate(
      count,
      (i) => _thumbnailForSlot(i, count),
    );
  }

  Duration _positionFromDx(double dx, double stripWidth) {
    final fraction = (dx / stripWidth).clamp(0.0, 1.0);
    final ms = (fraction * widget.clipDuration.inMilliseconds).round();
    return Duration(milliseconds: ms);
  }

  double _dxFromPosition(Duration position, double stripWidth) {
    if (widget.clipDuration <= Duration.zero) return 0;
    final fraction =
        position.inMilliseconds / widget.clipDuration.inMilliseconds;
    return (fraction * stripWidth).clamp(0.0, stripWidth);
  }

  Duration _clampPosition(Duration position) {
    final maxMs = widget.clipDuration.inMilliseconds;
    return Duration(milliseconds: position.inMilliseconds.clamp(0, maxMs));
  }

  void _seekBySemanticsDelta(Duration delta) {
    final target = _clampPosition(widget.selectedPosition + delta);
    widget.onSeek(target);
  }

  /// Maps a visual slot index to the best [StripThumbnail] path for that
  /// time window (mirrors the logic in the timeline strip tiles).
  String? _thumbnailForSlot(int slotIndex, int slotCount) {
    if (widget.stripThumbnails.isEmpty) return null;
    final durationMs = widget.clipDuration.inMilliseconds;
    if (durationMs <= 0) return widget.stripThumbnails.first.path;

    final slotStartMs = durationMs * slotIndex / slotCount;
    final slotEndMs = durationMs * (slotIndex + 1) / slotCount;
    final slotCenterMs = (slotStartMs + slotEndMs) / 2;

    var lo = 0;
    var hi = widget.stripThumbnails.length;
    while (lo < hi) {
      final mid = (lo + hi) ~/ 2;
      if (widget.stripThumbnails[mid].timestamp.inMilliseconds < slotStartMs) {
        lo = mid + 1;
      } else {
        hi = mid;
      }
    }

    String? bestPath;
    var bestDist = double.infinity;
    for (var i = lo; i < widget.stripThumbnails.length; i++) {
      final tsMs = widget.stripThumbnails[i].timestamp.inMilliseconds;
      if (tsMs >= slotEndMs) break;
      final dist = (tsMs - slotCenterMs).abs();
      if (dist < bestDist) {
        bestDist = dist;
        bestPath = widget.stripThumbnails[i].path;
      }
    }
    return bestPath;
  }

  @override
  Widget build(BuildContext context) {
    final increasedPosition = _clampPosition(
      widget.selectedPosition + _semanticSeekStep,
    );
    final decreasedPosition = _clampPosition(
      widget.selectedPosition - _semanticSeekStep,
    );

    return Semantics(
      label: context.l10n.videoMetadataEditCoverStripSemanticLabel,
      slider: true,
      value: TimeFormatter.formatMinutesSeconds(widget.selectedPosition),
      increasedValue: TimeFormatter.formatMinutesSeconds(increasedPosition),
      decreasedValue: TimeFormatter.formatMinutesSeconds(decreasedPosition),
      onIncrease: () => _seekBySemanticsDelta(_semanticSeekStep),
      onDecrease: () => _seekBySemanticsDelta(-_semanticSeekStep),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final stripWidth = constraints.maxWidth;
          final count = (stripWidth / _stripThumbWidth).ceil().clamp(1, 500);
          _updateSlotCache(count);
          final slotWidth = stripWidth / count;
          final cursorDx = _dxFromPosition(widget.selectedPosition, stripWidth);
          final cursorLeft = (cursorDx - _cursorWidth / 2).clamp(
            0.0,
            stripWidth - _cursorWidth,
          );

          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: (d) =>
                widget.onSeek(_positionFromDx(d.localPosition.dx, stripWidth)),
            onHorizontalDragUpdate: (d) =>
                widget.onSeek(_positionFromDx(d.localPosition.dx, stripWidth)),
            child: SizedBox(
              width: stripWidth,
              height: _stripHeight,
              child: Stack(
                fit: .expand,
                children: [
                  SizedBox(
                    width: stripWidth,
                    child: Row(
                      children: [
                        for (var i = 0; i < count; i++)
                          SizedBox(
                            width: slotWidth,
                            height: _stripHeight,
                            child: _SlotImage(
                              thumbnail: widget.thumbnail,
                              stripThumbnailPath: _cachedPaths[i],
                            ),
                          ),
                      ],
                    ),
                  ),
                  Positioned(
                    top: 0,
                    bottom: 0,
                    left: 0,
                    width: cursorLeft,
                    child: const IgnorePointer(
                      child: ColoredBox(color: VineTheme.scrim35),
                    ),
                  ),
                  Positioned(
                    top: 0,
                    bottom: 0,
                    left: cursorLeft + _cursorWidth,
                    right: 0,
                    child: const IgnorePointer(
                      child: ColoredBox(color: VineTheme.scrim35),
                    ),
                  ),
                  Positioned(
                    top: 0,
                    bottom: 0,
                    left: cursorLeft,
                    child: IgnorePointer(
                      child: Container(
                        width: _cursorWidth,
                        decoration: ShapeDecoration(
                          shape: RoundedRectangleBorder(
                            side: const BorderSide(
                              width: 2,
                              color: VineTheme.onSurface,
                            ),
                            borderRadius: .circular(4),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _SlotImage extends StatelessWidget {
  const _SlotImage({required this.thumbnail, this.stripThumbnailPath});

  final ({String? path, String? networkUrl})? thumbnail;
  final String? stripThumbnailPath;

  @override
  Widget build(BuildContext context) {
    final fallback = thumbnail?.networkUrl != null
        ? ExcludeSemantics(
            child: VineCachedImage(
              imageUrl: thumbnail!.networkUrl!,
              placeholder: (_, _) =>
                  ColoredBox(color: context.vineColors.surfaceContainerHigh),
              errorWidget: (_, _, _) =>
                  ColoredBox(color: context.vineColors.surfaceContainerHigh),
            ),
          )
        : thumbnail?.path != null
        ? ClipThumbnailImage(
            path: thumbnail!.path!,
            fit: .cover,
            excludeFromSemantics: true,
            placeholder: ColoredBox(
              color: context.vineColors.surfaceContainerHigh,
            ),
          )
        : ColoredBox(color: context.vineColors.surfaceContainerHigh);

    final path = stripThumbnailPath;
    if (path == null) return fallback;

    return _FadingSlotImage(path: path, fallback: fallback);
  }
}

/// Fades an extracted strip frame in over [fallback] instead of swapping it
/// in the moment it decodes.
///
/// The priority timestamps cover every slot, so the first batch fills the
/// whole strip at once — a hard swap flips all tiles from the stretched
/// cover thumbnail to their real frames on a single frame boundary, which
/// reads as a jolt.
class _FadingSlotImage extends StatefulWidget {
  const _FadingSlotImage({required this.path, required this.fallback});

  /// Absolute path of the extracted strip frame.
  final String path;

  /// Painted underneath until the frame has faded in, and on the error path.
  final Widget fallback;

  @override
  State<_FadingSlotImage> createState() => _FadingSlotImageState();
}

class _FadingSlotImageState extends State<_FadingSlotImage> {
  static const _fadeDuration = Duration(milliseconds: 220);

  /// Sticky once a frame has been painted: a later batch reassigning this
  /// slot keeps the previous frame up (via `gaplessPlayback`) rather than
  /// dipping back to the fallback while the new file decodes.
  bool _hasFrame = false;

  /// Set once the frame is fully opaque, at which point the fallback beneath
  /// it is nothing but a second full-size image painted behind an opaque one
  /// — on every frame, for every slot, for as long as the picker is open.
  /// Dropping it is safe because both paths that could still want it are
  /// covered: the error path keeps its own copy via
  /// [ClipThumbnailImage.placeholder], and a reassigned slot holds its
  /// previous frame through `gaplessPlayback`.
  bool _covered = false;

  /// Always deferred to the next frame: [AnimatedOpacity] fires `onEnd`
  /// synchronously when its duration is zero and the target changed, which
  /// lands mid-build and would mark this ancestor dirty while the [Image]
  /// below is still building.
  void _dropFallback() {
    if (_covered || !_hasFrame || !mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _covered || !_hasFrame) return;
      setState(() => _covered = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: .expand,
      children: [
        if (_covered) const SizedBox.shrink() else widget.fallback,
        ClipThumbnailImage(
          path: widget.path,
          fit: .cover,
          gaplessPlayback: true,
          excludeFromSemantics: true,
          placeholder: widget.fallback,
          frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
            if (frame != null || wasSynchronouslyLoaded) _hasFrame = true;
            if (wasSynchronouslyLoaded) {
              // Painted opaque on this very build, so there is no transition
              // for `onEnd` to report — drop the layer on the next frame.
              _dropFallback();
            }
            return AnimatedOpacity(
              opacity: _hasFrame ? 1 : 0,
              // A cache hit paints on the first build; fading in from
              // nothing there would invent a transition nobody asked for.
              duration:
                  wasSynchronouslyLoaded ||
                      MediaQuery.disableAnimationsOf(context)
                  ? Duration.zero
                  : _fadeDuration,
              curve: Curves.easeOut,
              onEnd: _dropFallback,
              child: child,
            );
          },
        ),
      ],
    );
  }
}
