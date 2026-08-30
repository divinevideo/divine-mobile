// ABOUTME: Follow button widget for video overlay using BLoC pattern.
// ABOUTME: Circular 20x20 badge inside a 48x48 tap target, positioned near
// ABOUTME: the author avatar.
// ABOUTME: Only rendered when the viewer is NOT following the author; once
// ABOUTME: following, the button disappears entirely (no "following" state).

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nostr_sdk/nip19/pubkey_for_logs.dart';
import 'package:openvine/blocs/my_following/my_following_bloc.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/nostr_client_provider.dart';
import 'package:unified_logger/unified_logger.dart';

/// Diameter of the painted follow badge.
const double followButtonVisualSize = 20;

/// Side of the badge's tap target.
///
/// The painted badge is [followButtonVisualSize]; it sits at the top-start
/// corner of a target this size, which is the Android minimum and clears the
/// iOS one. Growing away from the avatar rather than centring on the badge is
/// deliberate: a target centred on a 20dp badge 31dp inside a 48dp avatar
/// would cover 63% of it.
const double followButtonTapTargetSize = kMinInteractiveDimension;

/// Page widget that creates the [MyFollowingBloc] and provides it to the view.
///
/// Uses StatefulConsumerWidget to avoid unnecessary rebuilds - the follow
/// repository and nostr client are read once during initState, not on every
/// build. The BLoC is created once and reused.
///
/// The button is only shown for videos authored by someone the viewer does
/// not yet follow. Once the viewer follows the author, the button hides for
/// good.
class VideoFollowButton extends ConsumerStatefulWidget {
  const VideoFollowButton({required this.pubkey, super.key});

  /// The public key of the video author to follow.
  final String pubkey;

  @override
  ConsumerState<VideoFollowButton> createState() => _VideoFollowButtonState();
}

class _VideoFollowButtonState extends ConsumerState<VideoFollowButton> {
  MyFollowingBloc? _bloc;
  bool _isOwnVideo = false;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _initializeButton();
  }

  void _initializeButton() {
    // Use read() to get values once, not watch() which causes rebuilds
    final followRepository = ref.read(followRepositoryProvider);
    final nostrClient = ref.read(nostrServiceProvider);
    final blocklistRepository = ref.read(contentBlocklistRepositoryProvider);

    // Check if this is the user's own video (read once, never changes)
    _isOwnVideo = nostrClient.publicKey == widget.pubkey;

    // Only create the BLoC when we might need to show the button: neither
    // the viewer's own video nor an author they already follow.
    if (!_isOwnVideo && !followRepository.isFollowing(widget.pubkey)) {
      _bloc = MyFollowingBloc(
        followRepository: followRepository,
        contentBlocklistRepository: blocklistRepository,
      )..add(const MyFollowingListLoadRequested());
    }

    _isInitialized = true;
  }

  @override
  void dispose() {
    _bloc?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Fast path: not initialized yet, viewer's own video, or already
    // following — never render the button.
    if (!_isInitialized || _isOwnVideo || _bloc == null) {
      return const SizedBox.shrink();
    }

    // Reserve the tap target as soon as the button *might* render, not when
    // it does. The guard above resolves in initState, so the author cluster is
    // laid out at its final size before first paint and never resizes later.
    // Own-video and already-following authors return above and pay nothing.
    return SizedBox(
      width: followButtonTapTargetSize,
      height: followButtonTapTargetSize,
      // If the author doesn't accept interactions from us (their published
      // block/mute list names us), render nothing — absence, never an
      // explanation (disclosure invariant).
      //
      // This sits inside the reservation rather than replacing it, because
      // canTargetUser watches blocklistVersion and so can flip while the item
      // is on screen. Collapsing the cluster 79 -> 58 at that moment would
      // shift the author name 21dp in front of the viewer, which is itself a
      // tell that correlates with the block. Holding the box keeps the
      // affordance's disappearance silent.
      child: ref.watch(canTargetUserProvider(widget.pubkey))
          ? BlocProvider.value(
              value: _bloc!,
              child: VideoFollowButtonView(pubkey: widget.pubkey),
            )
          : const SizedBox.shrink(),
    );
  }
}

/// View widget that consumes [MyFollowingBloc] state and renders the follow
/// button. Hides itself entirely once the viewer is following the author.
class VideoFollowButtonView extends StatelessWidget {
  @visibleForTesting
  const VideoFollowButtonView({required this.pubkey, super.key});

  final String pubkey;

  @override
  Widget build(BuildContext context) {
    return BlocSelector<
      MyFollowingBloc,
      MyFollowingState,
      ({bool isFollowing, bool isReady})
    >(
      selector: (state) => (
        isFollowing: state.isFollowing(pubkey),
        isReady:
            state.status == MyFollowingStatus.success ||
            state.status == MyFollowingStatus.toggleFailure,
      ),
      builder: (context, data) {
        // Do not render until the following list has loaded to avoid a
        // flash of the button for authors the viewer already follows.
        if (!data.isReady) {
          return const SizedBox.shrink();
        }

        // Hide permanently once following — no "following" affordance.
        if (data.isFollowing) {
          return const SizedBox.shrink();
        }

        return Semantics(
          identifier: 'follow_button',
          label: context.l10n.videoFollowButtonFollow,
          button: true,
          child: GestureDetector(
            // Opaque, so the whole target is tappable rather than only the
            // badge painted in its corner.
            behavior: HitTestBehavior.opaque,
            onTap: () {
              Log.info(
                'Follow button tapped for ${pubkeyForLogs(pubkey)}',
                name: 'VideoFollowButton',
                category: LogCategory.ui,
              );
              context.read<MyFollowingBloc>().add(
                MyFollowingToggleRequested(pubkey),
              );
            },
            child: SizedBox(
              width: followButtonTapTargetSize,
              height: followButtonTapTargetSize,
              child: Align(
                // The badge keeps the corner it has always painted in; the
                // target grows away from the avatar behind it.
                alignment: AlignmentDirectional.topStart,
                child: Container(
                  width: followButtonVisualSize,
                  height: followButtonVisualSize,
                  decoration: const BoxDecoration(
                    color: VineTheme.cameraButtonGreen,
                    shape: BoxShape.circle,
                    boxShadow: VineTheme.buttonBoxShadows,
                  ),
                  child: const Center(
                    child: DivineIcon(
                      icon: DivineIconName.follow,
                      size: 13,
                      color: VineTheme.whiteText,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
