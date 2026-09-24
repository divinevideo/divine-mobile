// ABOUTME: Conversation card for a received encrypted (kind 15) video DM.
// ABOUTME: Renders a locally-decoded blurhash placeholder only — no network
// ABOUTME: image, since the encrypted thumbnail shares the file's GCM nonce.

import 'package:divine_ui/divine_ui.dart';
import 'package:material_ui/material_ui.dart';
import 'package:models/models.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/widgets/blurhash_display.dart';

/// Width of the encrypted video card, matching the shared-video card
/// thumbnail (`message_bubble.dart`). Kept in sync so both media cards line up.
const double encryptedVideoCardWidth = 248;

/// Height of the encrypted video card, matching the shared-video card.
const double encryptedVideoCardHeight = 350;

/// Corner radius of the encrypted video card across all states.
const double encryptedVideoCardRadius = 16;

/// Blurhash placeholder for a received encrypted video file message.
///
/// The card deliberately renders no thumbnail: the encrypted thumbnail in
/// `DmFileMetadata.thumbnailUrl` is encrypted under the same key and nonce as
/// the video, so fetching it as a plain image would reuse the GCM nonce. The
/// blurhash is a local, non-secret preview. Playback (decrypt + player) is
/// owned by the video DM play page; [onTap] is the future hook for it.
///
/// When the sender provided no blurhash there is nothing safe to preview, so
/// the card shows a neutral play placeholder. Divine's own sender attaches no
/// blurhash, so this is the normal state for its video DMs, not a failure.
class EncryptedVideoCard extends StatefulWidget {
  const EncryptedVideoCard({
    required this.fileMetadata,
    required this.isSent,
    this.onTap,
    super.key,
  });

  /// Metadata from the kind 15 file message. [DmFileMetadata.isVideo] is
  /// expected to be true; the caller branches on it before building the card.
  final DmFileMetadata fileMetadata;

  /// Whether the enclosing bubble is the current user's own message.
  final bool isSent;

  /// Opens playback. When null the card is not interactive, so it never
  /// becomes a dead tap target.
  final VoidCallback? onTap;

  @override
  State<EncryptedVideoCard> createState() => _EncryptedVideoCardState();
}

class _EncryptedVideoCardState extends State<EncryptedVideoCard> {
  @override
  Widget build(BuildContext context) {
    final blurhash = widget.fileMetadata.blurhash;
    final card = (blurhash == null || blurhash.isEmpty)
        ? const _EncryptedVideoPlaceholderCard()
        : ClipRRect(
            borderRadius: BorderRadius.circular(encryptedVideoCardRadius),
            child: SizedBox(
              width: encryptedVideoCardWidth,
              height: encryptedVideoCardHeight,
              child: BlurhashDisplay(
                blurhash: blurhash,
                width: encryptedVideoCardWidth,
                height: encryptedVideoCardHeight,
              ),
            ),
          );

    final onTap = widget.onTap;
    if (onTap == null) return card;
    return Semantics(
      button: true,
      label: context.l10n.videoPlayerPlayVideo,
      child: GestureDetector(onTap: onTap, child: card),
    );
  }
}

/// Neutral placeholder shown when a video DM carries no blurhash.
class _EncryptedVideoPlaceholderCard extends StatelessWidget {
  const _EncryptedVideoPlaceholderCard();

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(encryptedVideoCardRadius),
      child: Container(
        width: encryptedVideoCardWidth,
        height: encryptedVideoCardHeight,
        color: context.vineColors.card,
        alignment: Alignment.center,
        child: ExcludeSemantics(
          child: DivineIcon(
            icon: DivineIconName.playCircleFill,
            color: context.vineColors.onSurfaceMuted,
            size: 48,
          ),
        ),
      ),
    );
  }
}
