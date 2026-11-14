// ABOUTME: Bubble for an outgoing video DM that has not landed yet: its frame
// ABOUTME: with a ring or warning icon, and its status or failure below.

import 'dart:typed_data';

import 'package:divine_ui/divine_ui.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/outgoing_video_dm.dart';
import 'package:openvine/screens/inbox/conversation/widgets/encrypted_video_card.dart';

/// Right-aligned bubble for an outgoing video while it is queued, preparing,
/// uploading, publishing or failed.
///
/// The fixed-size card holds only the frame and a centred overlay: a progress
/// ring, or a warning icon once the send failed. The status line, and for a
/// failure its message and actions, sit below the card so they can grow with
/// the text scale.
///
/// The card and its text are one merged semantics node: while uploading it
/// reads the percent, while failed it says so, and in the other in-flight
/// phases it reads the status line. Retry and Remove stay separate buttons.
class PendingVideoBubble extends StatelessWidget {
  const PendingVideoBubble({
    required this.entry,
    required this.onRetry,
    required this.onRemove,
    super.key,
  });

  /// The outgoing video this bubble shows.
  final OutgoingVideoDm entry;

  /// Retries a send that failed with [OutgoingVideoDm.canRetry].
  final VoidCallback onRetry;

  /// Removes a failed send from the conversation.
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final isFailed = entry.phase == OutgoingVideoDmPhase.failed;
    final isUploading = entry.phase == OutgoingVideoDmPhase.uploading;
    final percent = ((entry.uploadProgress ?? 0) * 100).round().clamp(0, 100);
    final statusText = switch (entry.phase) {
      OutgoingVideoDmPhase.queued => l10n.dmPendingVideoWaiting,
      OutgoingVideoDmPhase.checking ||
      OutgoingVideoDmPhase.encrypting => l10n.dmPendingVideoPreparing,
      OutgoingVideoDmPhase.uploading => l10n.dmPendingVideoUploading(percent),
      OutgoingVideoDmPhase.publishing => l10n.dmPendingVideoSending,
      OutgoingVideoDmPhase.sent => null,
      OutgoingVideoDmPhase.failed => switch (entry.failure) {
        OutgoingVideoDmFailure.tooLarge => l10n.dmVideoTooLarge(
          '$videoDmMaxMegabytes',
        ),
        OutgoingVideoDmFailure.clipNotVerified => l10n.dmClipSendNotVerified,
        OutgoingVideoDmFailure.failed || null => l10n.dmVideoSendFailed,
      },
    };
    final semanticsLabel = isFailed
        ? l10n.dmPendingVideoFailedSemantics
        : isUploading
        ? l10n.dmPendingVideoSemantics(percent)
        : statusText;

    return Align(
      alignment: AlignmentDirectional.centerEnd,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: context.vineColors.mediaCard,
          borderRadius: BorderRadius.circular(encryptedVideoCardRadius + 4),
        ),
        child: SizedBox(
          width: encryptedVideoCardWidth,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            spacing: 8,
            children: [
              Semantics(
                container: true,
                label: semanticsLabel,
                child: ExcludeSemantics(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    spacing: 8,
                    children: [
                      _PendingCard(entry: entry),
                      if (statusText != null) _StatusText(statusText),
                    ],
                  ),
                ),
              ),
              if (isFailed)
                _FailedActions(
                  canRetry: entry.canRetry,
                  onRetry: onRetry,
                  onRemove: onRemove,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The fixed-size card: the frame, and over it a scrim with the ring or the
/// warning icon. A sent video drops the overlay.
class _PendingCard extends StatelessWidget {
  const _PendingCard({required this.entry});

  final OutgoingVideoDm entry;

  @override
  Widget build(BuildContext context) {
    final phase = entry.phase;
    return ClipRRect(
      borderRadius: BorderRadius.circular(encryptedVideoCardRadius),
      child: SizedBox(
        width: encryptedVideoCardWidth,
        height: encryptedVideoCardHeight,
        child: Stack(
          fit: StackFit.expand,
          children: [
            _PendingPreview(frame: entry.frame),
            if (phase != OutgoingVideoDmPhase.sent) ...[
              const ColoredBox(color: VineTheme.scrim50),
              Center(
                child: phase == OutgoingVideoDmPhase.failed
                    ? const DivineIcon(
                        icon: DivineIconName.warningCircle,
                        size: 40,
                        color: VineTheme.whiteText,
                      )
                    : DivineCircularProgressIndicator(
                        value: phase == OutgoingVideoDmPhase.uploading
                            ? (entry.uploadProgress ?? 0).clamp(0.0, 1.0)
                            : null,
                        color: VineTheme.whiteText,
                        backgroundColor: VineTheme.scrim50,
                      ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// The frame this device read from the video, else a neutral card colour.
class _PendingPreview extends StatelessWidget {
  const _PendingPreview({required this.frame});

  final Uint8List? frame;

  @override
  Widget build(BuildContext context) {
    final frame = this.frame;
    if (frame == null) {
      return ColoredBox(
        color: context.vineColors.card,
        child: Center(
          child: DivineIcon(
            icon: DivineIconName.playCircleFill,
            color: context.vineColors.onSurfaceMuted,
            size: 48,
          ),
        ),
      );
    }
    return Image.memory(
      frame,
      fit: BoxFit.cover,
      gaplessPlayback: true,
      excludeFromSemantics: true,
      errorBuilder: (_, _, _) => ColoredBox(color: context.vineColors.card),
    );
  }
}

/// Status or failure line under the card.
class _StatusText extends StatelessWidget {
  const _StatusText(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      textAlign: TextAlign.end,
      style: VineTheme.labelMediumFont(
        color: context.vineColors.onSurfaceMuted,
      ),
    );
  }
}

/// Retry (only when a retry could succeed) and Remove.
class _FailedActions extends StatelessWidget {
  const _FailedActions({
    required this.canRetry,
    required this.onRetry,
    required this.onRemove,
  });

  final bool canRetry;
  final VoidCallback onRetry;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Wrap(
      alignment: WrapAlignment.end,
      spacing: 8,
      runSpacing: 8,
      children: [
        if (canRetry)
          DivineButton(
            label: l10n.commonRetry,
            size: DivineButtonSize.small,
            onPressed: onRetry,
          ),
        DivineButton(
          label: l10n.dmPendingVideoRemove,
          type: DivineButtonType.secondary,
          size: DivineButtonSize.small,
          onPressed: onRemove,
        ),
      ],
    );
  }
}
