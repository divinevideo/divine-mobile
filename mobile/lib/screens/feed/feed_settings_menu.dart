// ABOUTME: Top-app-bar settings menu for the home video feed.
// ABOUTME: Renders the More icon button and the playback-controls popover
// ABOUTME: that toggles auto-advance, audio mute, and closed captions.

import 'dart:async';

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:models/models.dart' hide LogCategory;
import 'package:openvine/blocs/owner_video_actions/owner_video_actions_cubit.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/creator_delete_enforcement_providers.dart';
import 'package:openvine/screens/video_metadata/video_metadata_edit_screen.dart';
import 'package:openvine/utils/delete_result_localization.dart';
import 'package:openvine/utils/owner_video_cleanup_feedback.dart';
import 'package:openvine/widgets/owner_video_delete_confirmation_dialog.dart';
import 'package:openvine/widgets/video_feed_item/feed_playback_toggles_pill.dart';

/// More icon button + playback-controls popover for feed surfaces.
///
/// Renders a 40 px scrim-15 [DivineIconButton] (48 px tap target). Used on
/// the home feed's top bar (as the trailing sibling of the feed-mode
/// selector) and on the fullscreen video screen (as a `customActions`
/// entry on its [DiVineAppBar]). Tapping opens a popover anchored 16 px
/// below the button's bottom-right corner with three scrim-toggled
/// controls: playback mode (auto-advance), audio mute, and closed captions.
///
/// The popover content is the shared [FeedPlaybackTogglesPill] widget. Feed
/// surfaces should pass [videoId] when they have current-video context so the
/// captions toggle stays scoped to that video instead of mutating Settings.
/// Pass [video] only on surfaces that should expose owner edit/delete actions.
class FeedSettingsMenu extends ConsumerStatefulWidget {
  const FeedSettingsMenu({super.key, this.video, this.videoId});

  final VideoEvent? video;
  final String? videoId;

  @override
  ConsumerState<FeedSettingsMenu> createState() => _FeedSettingsMenuState();
}

class _FeedSettingsMenuState extends ConsumerState<FeedSettingsMenu> {
  final OverlayPortalController _controller = OverlayPortalController();
  final LayerLink _link = LayerLink();
  late final OwnerVideoActionsCubit _ownerVideoActionsCubit;

  /// Mirrors [_controller.isShowing] so the trigger button can rebuild via a
  /// [ValueListenableBuilder] without setState on the whole subtree.
  /// [OverlayPortalController] is not a [Listenable], so we drive this
  /// notifier from the toggle / close callbacks alongside the controller.
  final ValueNotifier<bool> _isShowing = ValueNotifier(false);

  @override
  void initState() {
    super.initState();
    _ownerVideoActionsCubit = OwnerVideoActionsCubit(
      contentDeletionService: () =>
          ref.read(contentDeletionServiceProvider.future),
      videoEventService: () => ref.read(videoEventServiceProvider),
      enforcementRepository: () =>
          ref.read(creatorDeleteEnforcementRepositoryProvider),
    );
  }

  @override
  void dispose() {
    unawaited(_ownerVideoActionsCubit.close());
    _isShowing.dispose();
    super.dispose();
  }

  void _toggle() {
    if (_controller.isShowing) {
      _controller.hide();
      _isShowing.value = false;
    } else {
      _controller.show();
      _isShowing.value = true;
    }
  }

  void _close() {
    if (!_controller.isShowing) return;
    _controller.hide();
    _isShowing.value = false;
  }

  bool get _isOwnVideo {
    final video = widget.video;
    if (video == null) return false;
    final currentUserPubkey = ref
        .watch(authServiceProvider)
        .currentPublicKeyHex;
    return currentUserPubkey != null && currentUserPubkey == video.pubkey;
  }

  void _editVideo() {
    final video = widget.video;
    if (video == null) return;
    if (_ownerVideoActionsCubit.isDeleteInProgress(video.id)) return;
    _close();
    context.push(VideoMetadataEditScreen.pathFor(video.id), extra: video);
  }

  Future<void> _confirmDeleteVideo() async {
    final video = widget.video;
    if (video == null) return;

    final confirmed = await showOwnerVideoDeleteConfirmationDialog(context);
    if (confirmed && mounted) {
      await _deleteVideo(video);
    }
  }

  Future<void> _deleteVideo(VideoEvent video) async {
    final ownerVideoActionsCubit = _ownerVideoActionsCubit;
    final start = await ownerVideoActionsCubit.deleteVideo(video);
    if (start == OwnerVideoDeleteStart.busy) return;

    if (!mounted) return;

    final operation = ownerVideoActionsCubit.state.forVideo(video.id);
    if (operation.deleteStatus == OwnerVideoDeleteStatus.success) {
      showOwnerVideoCleanupCompletion(
        context,
        ownerVideoActionsCubit,
        video.id,
      );
      final messenger = ScaffoldMessenger.of(context);
      final snackBar = DivineSnackbarContainer.snackBar(
        localizedOwnerVideoDeleteSuccessMessage(context, operation),
        error: operation.cleanupStatus == OwnerVideoCleanupStatus.failed,
      );
      _close();
      messenger.showSnackBar(snackBar);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        DivineSnackbarContainer.snackBar(
          operation.deleteResult == null
              ? context.l10n.shareMenuDeleteFailedGeneric
              : localizedDeleteFailureMessage(context, operation.deleteResult!),
          error: true,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _link,
      child: OverlayPortal(
        controller: _controller,
        overlayChildBuilder: (_) => BlocProvider.value(
          value: _ownerVideoActionsCubit,
          child: BlocBuilder<OwnerVideoActionsCubit, OwnerVideoActionsState>(
            builder: (context, state) {
              final operation = state.forVideo(widget.video?.id ?? '');
              return _FeedSettingsOverlay(
                link: _link,
                onClose: _close,
                isOwnVideo: _isOwnVideo,
                isDeleting:
                    operation.deleteStatus == OwnerVideoDeleteStatus.deleting ||
                    operation.cleanupStatus ==
                        OwnerVideoCleanupStatus.inProgress,
                onEditVideo: _editVideo,
                onDeleteVideo: _confirmDeleteVideo,
                videoId: widget.videoId ?? widget.video?.id,
              );
            },
          ),
        ),
        child: ValueListenableBuilder<bool>(
          valueListenable: _isShowing,
          builder: (context, isShowing, _) => DivineIconButton(
            icon: isShowing ? DivineIconName.x : DivineIconName.dotsThree,
            size: DivineIconButtonSize.small,
            type: DivineIconButtonType.ghostOverMedia,
            semanticLabel: isShowing
                ? context.l10n.videoSettingsMenuClose
                : context.l10n.videoSettingsMenuOpen,
            onPressed: _toggle,
          ),
        ),
      ),
    );
  }
}

/// Overlay rendered while the popover is open: a full-screen tap catcher
/// that dismisses the popover, plus the popover itself anchored 16 px below
/// the trigger button's bottom-right corner.
class _FeedSettingsOverlay extends StatelessWidget {
  const _FeedSettingsOverlay({
    required this.link,
    required this.onClose,
    required this.isOwnVideo,
    required this.isDeleting,
    required this.onEditVideo,
    required this.onDeleteVideo,
    required this.videoId,
  });

  final LayerLink link;
  final VoidCallback onClose;
  final bool isOwnVideo;
  final bool isDeleting;
  final VoidCallback onEditVideo;
  final VoidCallback onDeleteVideo;
  final String? videoId;

  @override
  Widget build(BuildContext context) {
    // Wrap the *entire* overlay in a [TextFieldTapRegion]. While the
    // popover is open, every tap inside it — the pill (toggling
    // mute / captions / ...), the empty backdrop (which fires
    // [onClose] to dismiss the popover), and the area behind the
    // popover's X-button trigger in the app bar that the backdrop
    // catcher overlays — is treated as part of the focused
    // TextField's tap-region group. That keeps the inline comment
    // composer's keyboard up while the user adjusts playback, and
    // lets them close the popover (via X or backdrop tap) without
    // also losing the keyboard.
    return TextFieldTapRegion(
      child: Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onClose,
            ),
          ),
          CompositedTransformFollower(
            link: link,
            targetAnchor: Alignment.bottomRight,
            followerAnchor: Alignment.topRight,
            offset: const Offset(0, 16),
            child: Material(
              color: VineTheme.transparent,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isOwnVideo) ...[
                    _OwnerVideoActionsPill(
                      onEditVideo: onEditVideo,
                      onDeleteVideo: onDeleteVideo,
                      isDeleting: isDeleting,
                    ),
                    const SizedBox(height: 8),
                  ],
                  FeedPlaybackTogglesPill(videoId: videoId),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OwnerVideoActionsPill extends StatelessWidget {
  const _OwnerVideoActionsPill({
    required this.onEditVideo,
    required this.onDeleteVideo,
    required this.isDeleting,
  });

  final VoidCallback onEditVideo;
  final VoidCallback onDeleteVideo;
  final bool isDeleting;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: VineTheme.scrim30,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: VineTheme.scrim15),
        boxShadow: const [BoxShadow(color: VineTheme.shadow25, blurRadius: 4)],
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          spacing: 8,
          children: [
            _OwnerVideoAction(
              icon: DivineIconName.pencilSimpleLine,
              label: context.l10n.shareMenuEditVideo,
              onTap: onEditVideo,
              isDisabled: isDeleting,
            ),
            _OwnerVideoAction(
              icon: DivineIconName.trash,
              label: context.l10n.shareMenuDeleteVideo,
              onTap: onDeleteVideo,
              isDestructive: true,
              isBusy: isDeleting,
            ),
          ],
        ),
      ),
    );
  }
}

class _OwnerVideoAction extends StatelessWidget {
  const _OwnerVideoAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isDestructive = false,
    this.isBusy = false,
    this.isDisabled = false,
  });

  final DivineIconName icon;
  final String label;
  final VoidCallback onTap;
  final bool isDestructive;
  final bool isBusy;
  final bool isDisabled;

  @override
  Widget build(BuildContext context) {
    final color = isDisabled
        ? context.vineColors.secondaryText
        : isDestructive
        ? VineTheme.error
        : context.vineColors.onSurface;
    return Semantics(
      button: true,
      enabled: !isBusy && !isDisabled,
      label: label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: isBusy || isDisabled ? null : onTap,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: VineTheme.scrim15,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              spacing: 6,
              children: [
                if (isBusy)
                  const SizedBox.square(
                    dimension: 18,
                    child: DivineCircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  DivineIcon(icon: icon, color: color, size: 18),
                Text(label, style: VineTheme.labelSmallFont(color: color)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
