// ABOUTME: Follow button widget for video overlay using BLoC pattern.
// ABOUTME: Circular 20x20 badge centred in a 44x44 tap target that overhangs
// ABOUTME: the author avatar's bottom-end corner.
// ABOUTME: Hidden for an author the viewer already follows; a follow made from
// ABOUTME: the badge cross-fades it to the selected state instead.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:nostr_sdk/nip19/pubkey_for_logs.dart';
import 'package:openvine/blocs/my_following/my_following_bloc.dart';
import 'package:openvine/constants/semantic_ids.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/nostr_client_provider.dart';
import 'package:unified_logger/unified_logger.dart';

/// Diameter of the painted follow badge.
const double followButtonVisualSize = DivineFollowButton.badgeSize;

/// Side of the badge's tap target: Apple's HIG minimum of 44pt, as designed
/// for the feed author row.
///
/// The painted badge is [followButtonVisualSize], centred in the target with
/// [followButtonPadding] on every side. The caller places the target so the
/// badge lands on the avatar's bottom-end corner.
const double followButtonTapTargetSize =
    DivineFollowButton.defaultTapTargetSize;

/// Padding between the painted badge and each edge of its tap target.
const double followButtonPadding =
    (followButtonTapTargetSize - followButtonVisualSize) / 2;

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

    // If the author doesn't accept interactions from us (their published
    // block/mute list names us), render nothing — absence, never an
    // explanation (disclosure invariant).
    if (!ref.watch(canTargetUserProvider(widget.pubkey))) {
      return const SizedBox.shrink();
    }

    return BlocProvider.value(
      value: _bloc!,
      child: VideoFollowButtonView(pubkey: widget.pubkey),
    );
  }
}

/// View widget that consumes [MyFollowingBloc] state and renders the follow
/// badge.
///
/// An author the viewer already followed when this item mounted gets no badge
/// at all. A follow made from this badge cross-fades it to the selected state,
/// which then stays for the life of the item.
class VideoFollowButtonView extends StatelessWidget {
  @visibleForTesting
  const VideoFollowButtonView({required this.pubkey, super.key});

  final String pubkey;

  @override
  Widget build(BuildContext context) {
    return BlocSelector<
      MyFollowingBloc,
      MyFollowingState,
      ({bool isFollowing, bool isReady, bool followedHere})
    >(
      selector: (state) => (
        isFollowing: state.isFollowing(pubkey),
        isReady:
            state.status == MyFollowingStatus.success ||
            state.status == MyFollowingStatus.toggleFailure,
        // Set by the bloc before a toggle resolves, so it is true for exactly
        // the follows made from this badge and false for an author the viewer
        // already followed when the item mounted.
        followedHere: state.hasLocalFollowEdit,
      ),
      builder: (context, data) {
        // Do not render until the following list has loaded to avoid a
        // flash of the button for authors the viewer already follows.
        if (!data.isReady) {
          return const SizedBox.shrink();
        }

        // Already following when this item mounted: no badge, no affordance.
        if (data.isFollowing && !data.followedHere) {
          return const SizedBox.shrink();
        }

        final l10n = context.l10n;
        if (data.isFollowing) {
          // A state, not a control: the badge is inert, so a tap on the avatar
          // corner beneath it opens the profile rather than unfollowing.
          return DivineFollowButton(
            variant: DivineFollowButtonVariant.selected,
            semanticLabel: l10n.profileFollowingLabel,
            semanticIdentifier: SemanticIds.videoFollowButton,
          );
        }

        return DivineFollowButton(
          variant: DivineFollowButtonVariant.follow,
          semanticLabel: l10n.videoFollowButtonFollow,
          semanticIdentifier: SemanticIds.videoFollowButton,
          onPressed: () {
            Log.info(
              'Follow button tapped for ${pubkeyForLogs(pubkey)}',
              name: 'VideoFollowButton',
              category: LogCategory.ui,
            );
            context.read<MyFollowingBloc>().add(
              MyFollowingToggleRequested(pubkey),
            );
          },
        );
      },
    );
  }
}
