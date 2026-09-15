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
/// the card falls back to the same unavailable pattern the shared-video card
/// uses for a dead reel.
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

  /// Opens playback. Null until the play page is wired (Task A7), which keeps
  /// the placeholder non-interactive rather than a dead tap target.
  final VoidCallback? onTap;

  @override
  State<EncryptedVideoCard> createState() => _EncryptedVideoCardState();
}

class _EncryptedVideoCardState extends State<EncryptedVideoCard> {
  @override
  Widget build(BuildContext context) {
    final blurhash = widget.fileMetadata.blurhash;
    final card = (blurhash == null || blurhash.isEmpty)
        ? const _EncryptedVideoUnavailableCard()
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
      child: GestureDetector(onTap: onTap, child: card),
    );
  }
}

/// Non-tappable placeholder shown when a received video DM carries no
/// blurhash. Mirrors the shared-video card's unavailable state.
class _EncryptedVideoUnavailableCard extends StatelessWidget {
  const _EncryptedVideoUnavailableCard();

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(encryptedVideoCardRadius),
      child: Container(
        width: encryptedVideoCardWidth,
        height: encryptedVideoCardHeight,
        color: context.vineColors.card,
        alignment: Alignment.center,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DivineIcon(
              icon: DivineIconName.warningCircle,
              color: context.vineColors.onSurfaceMuted,
              size: 32,
            ),
            const SizedBox(height: 8),
            Text(
              context.l10n.notificationsVideoUnavailable,
              style: VineTheme.bodyMediumFont(
                color: context.vineColors.onSurfaceMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
