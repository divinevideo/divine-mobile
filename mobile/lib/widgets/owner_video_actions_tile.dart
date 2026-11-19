// ABOUTME: Grid tile wrapper that owns the own-video long-press affordance.
// ABOUTME: One semantics node carries the tap, the gated long-press and hint.

import 'package:flutter/widgets.dart';
import 'package:models/models.dart';
import 'package:openvine/constants/semantic_ids.dart';
import 'package:openvine/l10n/l10n.dart';

/// A video grid tile whose long-press opens the viewer's own-video actions.
///
/// The tile decides ownership itself: the long-press gesture, its semantics
/// action and its hint exist only when [viewerPubkey] is the video's author
/// and [ownerActionsEnabled] is true. A call site therefore cannot advertise
/// the action on someone else's video, or offer it without saying what it
/// does.
///
/// Tap and long-press live on one labelled `Semantics` node, and the gesture
/// detector is excluded from semantics: if it declared the same actions too,
/// the two could not merge and screen readers would meet an unlabelled twin
/// node repeating them.
class OwnerVideoActionsTile extends StatelessWidget {
  const OwnerVideoActionsTile({
    required this.video,
    required this.viewerPubkey,
    required this.index,
    required this.onTap,
    required this.onOwnerLongPress,
    required this.child,
    this.ownerActionsEnabled = true,
    this.selected,
    this.value,
    super.key,
  });

  /// The video the tile shows; its author decides ownership.
  final VideoEvent video;

  /// The signed-in viewer's hex pubkey, or `null` when no one is signed in.
  final String? viewerPubkey;

  /// Zero-based position in the grid, for the label and the identifier.
  final int index;

  /// Opens the video.
  final VoidCallback onTap;

  /// Opens the own-video actions; only wired when the viewer owns the video.
  final VoidCallback onOwnerLongPress;

  /// `false` withdraws the owner long-press, for example while the grid is
  /// in selection mode and a tap toggles the tile instead.
  final bool ownerActionsEnabled;

  /// Selection-mode state: `null` outside selection mode.
  final bool? selected;

  /// Read after the label, for example that the video is pinned.
  final String? value;

  /// The thumbnail and any overlays drawn on it.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final isOwner = viewerPubkey == video.pubkey;
    final onLongPress = isOwner && ownerActionsEnabled
        ? onOwnerLongPress
        : null;

    return Semantics(
      identifier: SemanticIds.videoThumbnail(index),
      label: l10n.profileVideoThumbnailLabel(index + 1),
      value: value,
      button: true,
      selected: selected,
      onTap: onTap,
      onLongPress: onLongPress,
      onLongPressHint: onLongPress == null ? null : l10n.videoGridOptionsTitle,
      child: GestureDetector(
        excludeFromSemantics: true,
        onTap: onTap,
        onLongPress: onLongPress,
        child: child,
      ),
    );
  }
}
