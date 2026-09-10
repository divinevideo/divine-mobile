// ABOUTME: Bottom sheet shown when a video finishes publishing, offering to
// ABOUTME: view or share it rather than only to record another one.

import 'dart:typed_data';

import 'package:divine_ui/divine_ui.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/l10n/l10n.dart';

/// The payoff moment after a publish: a preview of what just went live, and
/// the two things a creator actually wants next.
///
/// Takes plain data and callbacks rather than reading repositories or
/// providers, so it renders in a widget test without the app's DI graph.
class PostPublishConfirmationSheet extends StatelessWidget {
  const PostPublishConfirmationSheet({
    required this.onView,
    required this.onShare,
    this.thumbnailBytes,
    super.key,
  });

  /// The published video's cover frame, already decoded from disk, or null
  /// when the draft carried none.
  ///
  /// Bytes rather than a path because publishing deletes the draft and
  /// reclaims its cover file; and never a network URL, since this renders
  /// before the event has propagated anywhere.
  final Uint8List? thumbnailBytes;

  final VoidCallback onView;
  final VoidCallback onShare;

  /// Shows the confirmation over [context]'s navigator.
  ///
  /// [onView] and [onShare] pop the sheet and then fire. `Navigator.pop` only
  /// starts the 200ms exit animation, so they run while it is still playing —
  /// the pop is ordered first so the sheet is off the navigator before either
  /// pushes a route.
  static Future<void> show({
    required BuildContext context,
    required VoidCallback onView,
    required VoidCallback onShare,
    Uint8List? thumbnailBytes,
  }) {
    return VineBottomSheet.show<void>(
      context: context,
      scrollable: false,
      // Explicit rather than left to default: `VineBottomSheet.show` reads
      // `isScrollControlled ?? expanded`, and the default (false) caps the
      // sheet at 9/16 of the screen — short enough to clip the preview on a
      // small display. `_FixedContent` already wraps to content.
      isScrollControlled: true,
      showHeaderDivider: false,
      headerTrailingAction: DivineIconButton(
        icon: .x,
        type: .secondary,
        size: .small,
        semanticLabel: context.l10n.commonClose,
        onPressed: () => Navigator.of(context).pop(),
      ),
      body: PostPublishConfirmationSheet(
        thumbnailBytes: thumbnailBytes,
        onView: () {
          Navigator.of(context).pop();
          onView();
        },
        onShare: () {
          Navigator.of(context).pop();
          onShare();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        spacing: 24,
        children: [
          _Preview(thumbnailBytes: thumbnailBytes),
          Text(
            l10n.postPublishConfirmationTitle,
            textAlign: TextAlign.center,
            style: VineTheme.titleMediumFont(
              color: context.vineColors.primaryText,
            ),
          ),
          Row(
            spacing: 12,
            children: [
              Expanded(
                child: DivineButton(
                  label: l10n.postPublishConfirmationView,
                  type: DivineButtonType.secondary,
                  leadingIcon: DivineIconName.play,
                  onPressed: onView,
                ),
              ),
              Expanded(
                child: DivineButton(
                  label: l10n.postPublishConfirmationShare,
                  leadingIcon: DivineIconName.share,
                  onPressed: onShare,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// The published video's cover frame, centre-cropped into a square tile that
/// echoes the profile grid.
class _Preview extends StatelessWidget {
  const _Preview({this.thumbnailBytes});

  final Uint8List? thumbnailBytes;

  static const _width = 132.0;

  @override
  Widget build(BuildContext context) {
    final bytes = thumbnailBytes;

    return SizedBox(
      width: _width,
      child: AspectRatio(
        aspectRatio: 1,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          // mediaCard, not card: `BoxFit.cover` fills the tile, so this only
          // shows through the no-cover and decode-failure placeholders — it
          // has to read as media chrome there rather than take the palette's
          // green cast in either appearance.
          child: ColoredBox(
            color: context.vineColors.mediaCard,
            child: bytes == null
                ? const _NoPreview()
                : Semantics(
                    label: context.l10n.postPublishConfirmationThumbnailLabel,
                    image: true,
                    child: Image.memory(
                      bytes,
                      fit: BoxFit.cover,
                      excludeFromSemantics: true,
                      // Undecodable bytes cost the preview, not the sheet.
                      errorBuilder: (_, _, _) => const _NoPreview(),
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

class _NoPreview extends StatelessWidget {
  const _NoPreview();

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: Center(
        child: DivineIcon(
          icon: DivineIconName.filmSlate,
          color: context.vineColors.secondaryText,
          size: 28,
        ),
      ),
    );
  }
}
