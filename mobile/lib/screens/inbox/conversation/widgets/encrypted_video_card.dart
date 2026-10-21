// ABOUTME: Conversation card for an encrypted (kind 15) video DM: the frame
// ABOUTME: this device keeps, else the sender's blurhash, never a network image.

import 'dart:io';

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

/// Why a video DM card holds back its preview, which it then says.
enum DmVideoHold {
  /// A message request, or a group member the user does not follow: the
  /// video downloads only when played.
  request,

  /// The user blocked the sender.
  blocked,

  /// The user muted the sender.
  muted,
}

/// Card for an encrypted video file message.
///
/// It shows [framePath], a frame this device read from the video it keeps,
/// once there is one; until then the sender's blurhash, decoded on the device;
/// and with neither a neutral play placeholder. It never fetches the sender's
/// encrypted thumbnail (`DmFileMetadata.thumbnailUrl`): that is encrypted under
/// the same key and nonce as the video, so reading it would reuse the GCM
/// nonce. The frame and blurhash are as private as the video and never logged.
/// Playback is owned by the video DM play page, opened through [onTap].
class EncryptedVideoCard extends StatefulWidget {
  const EncryptedVideoCard({
    required this.fileMetadata,
    required this.isSent,
    this.isClip = false,
    this.framePath,
    this.hold,
    this.onTap,
    super.key,
  });

  /// Metadata from the kind 15 file message. [DmFileMetadata.isVideo] is
  /// expected to be true; the caller branches on it before building the card.
  final DmFileMetadata fileMetadata;

  /// Whether the enclosing bubble is the current user's own message.
  final bool isSent;

  /// Whether the sender shared this as a raw clip from their library rather
  /// than a finished video. Labels the card so the recipient knows it can go
  /// into their clips.
  final bool isClip;

  /// Path of the frame this device read from the video it keeps, shown in
  /// place of the blurhash. Null until the video is kept and read.
  final String? framePath;

  /// Why the card holds back its preview, null when it does not. A held card
  /// shows no frame, keeps the blurhash only for a request, and says why.
  final DmVideoHold? hold;

  /// Opens playback. When null the card is not interactive, so it never
  /// becomes a dead tap target.
  final VoidCallback? onTap;

  @override
  State<EncryptedVideoCard> createState() => _EncryptedVideoCardState();
}

class _EncryptedVideoCardState extends State<EncryptedVideoCard> {
  @override
  Widget build(BuildContext context) {
    final hold = widget.hold;
    final metadataBlurhash = widget.fileMetadata.blurhash;
    final blurhash =
        metadataBlurhash == null ||
            metadataBlurhash.isEmpty ||
            (hold != null && hold != DmVideoHold.request)
        ? null
        : metadataBlurhash;
    final framePath = hold == null ? widget.framePath : null;
    final hint = switch (hold) {
      null => null,
      DmVideoHold.request => context.l10n.dmVideoCardTapToLoad,
      DmVideoHold.blocked => context.l10n.dmVideoCardHiddenSenderBlocked,
      DmVideoHold.muted => context.l10n.dmVideoCardHiddenSenderMuted,
    };
    final preview = framePath == null && blurhash == null
        ? _EncryptedVideoPlaceholderCard(hint: hint)
        : _PreviewSurface(blurhash: blurhash, framePath: framePath, hint: hint);
    final card = widget.isClip
        ? Stack(
            children: [
              preview,
              const PositionedDirectional(
                top: 12,
                start: 12,
                child: _ClipBadge(),
              ),
            ],
          )
        : preview;

    final onTap = widget.onTap;
    if (onTap == null) return card;
    return Semantics(
      button: true,
      label: context.l10n.videoPlayerPlayVideo,
      hint: hint,
      child: GestureDetector(onTap: onTap, child: card),
    );
  }
}

/// Neutral placeholder shown when a video DM carries no blurhash, or shows
/// none because its preview is held back.
class _EncryptedVideoPlaceholderCard extends StatelessWidget {
  const _EncryptedVideoPlaceholderCard({required this.hint});

  final String? hint;

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
          spacing: 8,
          children: [
            ExcludeSemantics(
              child: DivineIcon(
                icon: DivineIconName.playCircleFill,
                color: context.vineColors.onSurfaceMuted,
                size: 48,
              ),
            ),
            if (hint case final hint?) _HoldHint(hint),
          ],
        ),
      ),
    );
  }
}

/// A preview filling the card, with a play icon over it: the kept frame over
/// the blurhash, or over the card colour when there is no blurhash.
///
/// The layer under the frame shows while the frame decodes and when its file
/// is gone, so the card never goes blank.
class _PreviewSurface extends StatelessWidget {
  const _PreviewSurface({
    required this.blurhash,
    required this.framePath,
    required this.hint,
  });

  final String? blurhash;
  final String? framePath;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    final blurhash = this.blurhash;
    final framePath = this.framePath;
    return ClipRRect(
      borderRadius: BorderRadius.circular(encryptedVideoCardRadius),
      child: SizedBox(
        width: encryptedVideoCardWidth,
        height: encryptedVideoCardHeight,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Positioned.fill(
              child: blurhash != null
                  ? _Blurhash(blurhash: blurhash)
                  : ColoredBox(color: context.vineColors.card),
            ),
            if (framePath != null)
              Positioned.fill(child: _KeptFrame(path: framePath)),
            Column(
              mainAxisSize: MainAxisSize.min,
              spacing: 8,
              children: [
                const _PreviewPlayBadge(),
                if (hint case final hint?) _HoldHint(hint),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// The sender's blurhash, decoded on the device.
class _Blurhash extends StatelessWidget {
  const _Blurhash({required this.blurhash});

  final String blurhash;

  @override
  Widget build(BuildContext context) {
    return BlurhashDisplay(
      blurhash: blurhash,
      width: encryptedVideoCardWidth,
      height: encryptedVideoCardHeight,
    );
  }
}

/// The frame this device kept, decoded at the card's size. Draws nothing
/// until it decodes, or when the file is gone (the system can clear the cache
/// it lives in), so the layer under it shows.
class _KeptFrame extends StatelessWidget {
  const _KeptFrame({required this.path});

  final String path;

  @override
  Widget build(BuildContext context) {
    return Image.file(
      File(path),
      fit: BoxFit.cover,
      cacheWidth:
          (encryptedVideoCardWidth * MediaQuery.devicePixelRatioOf(context))
              .round(),
      excludeFromSemantics: true,
      errorBuilder: (_, _, _) => const SizedBox.shrink(),
    );
  }
}

/// Play affordance over a preview. The preview can be any colour, so
/// the glyph carries its own scrim, like the clip badge.
class _PreviewPlayBadge extends StatelessWidget {
  const _PreviewPlayBadge();

  @override
  Widget build(BuildContext context) {
    return const ExcludeSemantics(
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: VineTheme.scrim65,
          shape: BoxShape.circle,
        ),
        child: Padding(
          padding: EdgeInsets.all(12),
          child: DivineIcon(
            icon: DivineIconName.play,
            color: VineTheme.whiteText,
          ),
        ),
      ),
    );
  }
}

/// Says why the card holds back its preview. Sits over the card, so it
/// carries its own scrim and a fixed size; the card's semantics hint reads it.
class _HoldHint extends StatelessWidget {
  const _HoldHint(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: MediaQuery.withNoTextScaling(
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: encryptedVideoCardWidth - 32,
          ),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: VineTheme.scrim65,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Text(
                text,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: VineTheme.labelSmallFont(color: VineTheme.whiteText),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Label on a clip card. Sits over the preview, so it carries its own scrim
/// and keeps a fixed size rather than growing with the text scale.
class _ClipBadge extends StatelessWidget {
  const _ClipBadge();

  @override
  Widget build(BuildContext context) {
    return MediaQuery.withNoTextScaling(
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: VineTheme.scrim65,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            spacing: 4,
            children: [
              const ExcludeSemantics(
                child: DivineIcon(
                  icon: DivineIconName.filmSlate,
                  color: VineTheme.whiteText,
                  size: 14,
                ),
              ),
              Text(
                context.l10n.dmClipBadge,
                style: VineTheme.labelSmallFont(color: VineTheme.whiteText),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
