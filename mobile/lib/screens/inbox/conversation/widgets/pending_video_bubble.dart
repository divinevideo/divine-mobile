// ABOUTME: Bubble for an outgoing video DM that has not landed yet: its frame
// ABOUTME: with a progress ring and status, or the failure with its actions.

import 'dart:typed_data';

import 'package:divine_ui/divine_ui.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/screens/inbox/conversation/widgets/encrypted_video_card.dart';
import 'package:openvine/services/video_dm_outbox.dart';

/// Right-aligned card for an outgoing video while it is queued, preparing,
/// uploading, publishing or failed.
///
/// The card is one merged semantics node: while uploading it reads the
/// percent, while failed it says so, and in the other in-flight phases it
/// reads the status line shown on the card.
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
    final isFailed = entry.phase == OutgoingVideoDmPhase.failed;
    return Align(
      alignment: AlignmentDirectional.centerEnd,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: context.vineColors.mediaCard,
            borderRadius: BorderRadius.circular(encryptedVideoCardRadius + 4),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(encryptedVideoCardRadius),
            child: SizedBox(
              width: encryptedVideoCardWidth,
              height: encryptedVideoCardHeight,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  _PendingPreview(frame: entry.frame),
                  const ColoredBox(color: VineTheme.scrim50),
                  Center(
                    child: isFailed
                        ? _FailedOverlay(
                            entry: entry,
                            onRetry: onRetry,
                            onRemove: onRemove,
                          )
                        : _ProgressOverlay(entry: entry),
                  ),
                ],
              ),
            ),
          ),
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
    return Image.memory(
      frame,
      fit: BoxFit.cover,
      gaplessPlayback: true,
      excludeFromSemantics: true,
      errorBuilder: (_, _, _) => ColoredBox(color: context.vineColors.card),
    );
  }
}

/// Ring and status line for a send still in flight.
class _ProgressOverlay extends StatelessWidget {
  const _ProgressOverlay({required this.entry});

  final OutgoingVideoDm entry;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final isUploading = entry.phase == OutgoingVideoDmPhase.uploading;
    final percent = ((entry.uploadProgress ?? 0) * 100).round().clamp(0, 100);
    final status = switch (entry.phase) {
      OutgoingVideoDmPhase.queued => l10n.dmPendingVideoWaiting,
      OutgoingVideoDmPhase.checking ||
      OutgoingVideoDmPhase.encrypting => l10n.dmPendingVideoPreparing,
      OutgoingVideoDmPhase.uploading => l10n.dmPendingVideoUploading(percent),
      OutgoingVideoDmPhase.publishing ||
      OutgoingVideoDmPhase.sent ||
      OutgoingVideoDmPhase.failed => l10n.dmPendingVideoSending,
    };
    return Semantics(
      container: true,
      label: isUploading ? l10n.dmPendingVideoSemantics(percent) : status,
      child: ExcludeSemantics(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          spacing: 12,
          children: [
            DivineCircularProgressIndicator(
              value: isUploading ? percent / 100 : null,
              color: VineTheme.whiteText,
              backgroundColor: VineTheme.scrim50,
            ),
            _OverlayText(status),
          ],
        ),
      ),
    );
  }
}

/// Failure line with Retry (only when a retry could succeed) and Remove.
class _FailedOverlay extends StatelessWidget {
  const _FailedOverlay({
    required this.entry,
    required this.onRetry,
    required this.onRemove,
  });

  final OutgoingVideoDm entry;
  final VoidCallback onRetry;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final message = switch (entry.failure) {
      OutgoingVideoDmFailure.tooLarge => l10n.dmVideoTooLarge(
        '$videoDmMaxMegabytes',
      ),
      OutgoingVideoDmFailure.clipNotVerified => l10n.dmClipSendNotVerified,
      OutgoingVideoDmFailure.failed || null => l10n.dmVideoSendFailed,
    };
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        spacing: 12,
        children: [
          Semantics(
            container: true,
            label: l10n.dmPendingVideoFailedSemantics,
            child: ExcludeSemantics(child: _OverlayText(message)),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            spacing: 8,
            children: [
              if (entry.canRetry)
                DivineButton(
                  label: l10n.commonRetry,
                  size: DivineButtonSize.small,
                  onPressed: onRetry,
                ),
              DivineButton(
                label: l10n.dmPendingVideoRemove,
                type: DivineButtonType.ghost,
                size: DivineButtonSize.small,
                onPressed: onRemove,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Text over the frame, which can be any colour, so it is white on the scrim.
class _OverlayText extends StatelessWidget {
  const _OverlayText(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      textAlign: TextAlign.center,
      style: VineTheme.labelLargeFont(color: VineTheme.whiteText),
    );
  }
}
