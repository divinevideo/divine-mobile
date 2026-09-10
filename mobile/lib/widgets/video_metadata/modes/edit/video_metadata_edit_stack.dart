// ABOUTME: Full-screen scaffold for editing already-published video metadata.
// ABOUTME: Reuses VideoMetadataFormFields from the capture stack.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart' hide AspectRatio;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:models/models.dart';
import 'package:openvine/constants/video_editor_constants.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/providers/video_editor_provider.dart';
import 'package:openvine/screens/video_metadata/video_metadata_cover_screen.dart';
import 'package:openvine/widgets/video_clip/clip_thumbnail_image.dart';
import 'package:openvine/widgets/video_metadata/modes/edit/video_metadata_edit_bottom_bar.dart';
import 'package:openvine/widgets/video_metadata/video_metadata_form_fields.dart';
import 'package:openvine/widgets/vine_cached_image.dart';
import 'package:pro_video_editor/pro_video_editor.dart';

/// Full-screen scaffold for editing an already-published [VideoEvent].
///
/// Wraps an inner [ProviderScope] so that [videoEditorProvider] is isolated
/// from any pre-existing capture flow. The editor state is pre-seeded from
/// [video] via [VideoEditorNotifier.initFromPublishedVideo].
class VideoMetadataEditStack extends StatefulWidget {
  const VideoMetadataEditStack({required this.video, super.key});

  final VideoEvent video;

  @override
  State<VideoMetadataEditStack> createState() => _VideoMetadataEditStackState();
}

class _VideoMetadataEditStackState extends State<VideoMetadataEditStack> {
  late final Set<String> _initialCollaboratorPubkeys;
  late VideoEvent _video;

  @override
  void initState() {
    super.initState();
    _video = widget.video;
    _initialCollaboratorPubkeys = widget.video.collaboratorPubkeys.toSet();
  }

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      overrides: [videoEditorProvider.overrideWith(VideoEditorNotifier.new)],
      child: _VideoMetadataEditStackContent(
        video: _video,
        initialCollaboratorPubkeys: _initialCollaboratorPubkeys,
        onVideoUpdated: (video) => setState(() => _video = video),
      ),
    );
  }
}

/// Inner widget that seeds the isolated [videoEditorProvider] from [video]
/// and renders the edit scaffold.
class _VideoMetadataEditStackContent extends ConsumerStatefulWidget {
  const _VideoMetadataEditStackContent({
    required this.video,
    required this.initialCollaboratorPubkeys,
    required this.onVideoUpdated,
  });

  final VideoEvent video;
  final Set<String> initialCollaboratorPubkeys;
  final ValueChanged<VideoEvent> onVideoUpdated;

  @override
  ConsumerState<_VideoMetadataEditStackContent> createState() =>
      _VideoMetadataEditStackContentState();
}

class _VideoMetadataEditStackContentState
    extends ConsumerState<_VideoMetadataEditStackContent> {
  String? _pendingThumbnailPath;

  @override
  void initState() {
    super.initState();
    // IMPORTANT: must use addPostFrameCallback, NOT a direct ref.read() call.
    // This widget is the *direct child* of the overriding ProviderScope (see
    // VideoMetadataEditStack.build). During initState the ProviderScope has
    // not yet mounted its InheritedWidget, so ref.read(videoEditorProvider)
    // resolves to the outer scope and throws a ProviderNotFoundException.
    // Deferring to post-frame ensures the override is in the tree before the
    // notifier is accessed.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref
          .read(videoEditorProvider.notifier)
          .initFromPublishedVideo(widget.video);
    });
  }

  Future<void> _openCoverEditor() async {
    final videoUrl = widget.video.videoUrl;
    if (videoUrl == null) return;
    FocusManager.instance.primaryFocus?.unfocus();
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final duration = reduceMotion
        ? Duration.zero
        : const Duration(milliseconds: 300);
    final clip = DivineVideoClip(
      id: widget.video.id,
      video: EditorVideo.network(videoUrl),
      duration: Duration(seconds: widget.video.duration ?? 0),
      recordedAt: DateTime.fromMillisecondsSinceEpoch(
        widget.video.createdAt * 1000,
      ),
      targetAspectRatio: AspectRatio.vertical,
      originalAspectRatio: null,
    );
    final path = await Navigator.push<String?>(
      context,
      PageRouteBuilder<String?>(
        settings: const RouteSettings(name: 'video_metadata_cover'),
        transitionDuration: duration,
        reverseTransitionDuration: duration,
        pageBuilder: (_, _, _) => VideoMetadataCoverScreen(
          clip: clip,
          thumbnailUrl: widget.video.thumbnailUrl,
        ),
        transitionsBuilder: (_, animation, _, child) {
          if (reduceMotion) return child;
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
    if (path != null && mounted) {
      setState(() => _pendingThumbnailPath = path);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.vineColors.surfaceContainerHigh,
      appBar: DiVineAppBar(
        backgroundColor: context.vineColors.surfaceContainerHigh,
        leadingIcon: SvgIconSource(DivineIconName.caretLeft.assetPath),
        leadingActionSemanticLabel: context.l10n.commonBack,
        onLeadingPressed: context.pop,
        title: context.l10n.shareMenuEditVideo,
      ),
      body: Column(
        spacing: 12,
        children: [
          Expanded(
            child: SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Thumbnail preview, matching capture stack style.
                  Padding(
                    padding: const EdgeInsets.only(top: 8, bottom: 16),
                    child: _EditClipPreview(
                      video: widget.video,
                      onEditCover: _openCoverEditor,
                      pendingThumbnailPath: _pendingThumbnailPath,
                    ),
                  ),
                  // Editing is post-publish; expiration cannot be changed.
                  const VideoMetadataFormFields(
                    enableExpiration: false,
                    enableCaptionMentionAutocomplete: false,
                  ),
                ],
              ),
            ),
          ),
          SafeArea(
            top: false,
            child: VideoMetadataEditBottomBar(
              video: widget.video,
              initialCollaboratorPubkeys: widget.initialCollaboratorPubkeys,
              pendingThumbnailPath: _pendingThumbnailPath,
              onVideoUpdated: widget.onVideoUpdated,
            ),
          ),
        ],
      ),
    );
  }
}

/// Thumbnail preview for an already-published video, mirroring the visual
/// style of [VideoMetadataCaptureClipPreview] in the capture flow.
class _EditClipPreview extends StatelessWidget {
  const _EditClipPreview({
    required this.video,
    this.onEditCover,
    this.pendingThumbnailPath,
  });

  final VideoEvent video;
  final VoidCallback? onEditCover;
  final String? pendingThumbnailPath;

  /// Parses "WxH" dimension string into a width/height ratio.
  /// Falls back to 9/16 (vertical) if unavailable or unparseable.
  double _aspectRatio() {
    final dim = video.dimensions;
    if (dim == null) return 9 / 16;
    final parts = dim.split('x');
    if (parts.length != 2) return 9 / 16;
    final w = double.tryParse(parts[0]);
    final h = double.tryParse(parts[1]);
    if (w == null || h == null || h == 0) return 9 / 16;
    return w / h;
  }

  @override
  Widget build(BuildContext context) {
    final thumbnailUrl = video.thumbnailUrl;
    final ratio = _aspectRatio();
    return Center(
      // Rounds the thumbnail from outside the Hero: a clip inside the Hero
      // child rides into the flight shuttle and fights the shape the
      // preview's flightShuttleBuilder is morphing towards.
      child: ClipRRect(
        borderRadius: BorderRadius.circular(
          VideoEditorConstants.clipPreviewCornerRadius,
        ),
        child: Hero(
          tag: VideoEditorConstants.heroMetaPreviewId,
          child: SizedBox(
            height: 200,
            width: 200 * ratio,
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (pendingThumbnailPath != null)
                  ClipThumbnailImage(
                    path: pendingThumbnailPath!,
                    fit: BoxFit.cover,
                    placeholder: thumbnailUrl != null
                        ? VineCachedImage(imageUrl: thumbnailUrl)
                        : ColoredBox(color: context.vineColors.onSurfaceMuted),
                  )
                else if (thumbnailUrl != null)
                  VineCachedImage(imageUrl: thumbnailUrl)
                else
                  ColoredBox(
                    color: context.vineColors.onSurfaceMuted,
                    child: const DivineIcon(
                      icon: .playCircle,
                      size: 64,
                      color: VineTheme.whiteText,
                    ),
                  ),
                if (onEditCover != null)
                  Center(
                    child: Semantics(
                      button: true,
                      label: context.l10n.shareMenuChangeCover,
                      excludeSemantics: true,
                      child: DivineIconButton(
                        icon: .pencilSimpleLine,
                        type: .ghostOverMedia,
                        size: .small,
                        onPressed: onEditCover,
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
