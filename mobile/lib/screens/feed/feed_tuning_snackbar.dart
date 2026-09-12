// ABOUTME: Shared Undo snackbar for feed-tuning swipes (home + fullscreen feed)
// ABOUTME: Uses DivineSnackbarContainer so the receipt always auto-dismisses

import 'package:divine_ui/divine_ui.dart';
import 'package:feed_tuning_repository/feed_tuning_repository.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/l10n/l10n.dart';

/// Auto-dismiss window for the feed-tuning receipt.
const _feedTuningSnackbarDuration = Duration(seconds: 4);

/// Shows the "More/Less like this" receipt after a feed-tuning swipe, with an
/// optional Undo action.
///
/// Uses [DivineSnackbarContainer] rather than a bare [SnackBar] with a
/// [SnackBarAction]: a Material action defaults `SnackBar.persist` to `true`,
/// which suppresses the auto-dismiss timer and pins the snackbar on screen
/// until it's manually dismissed. Rendering the Undo button inside the
/// snackbar content keeps `persist == false`, so the receipt always clears on
/// its own after [_feedTuningSnackbarDuration].
///
/// Tapping Undo hides the receipt before running [onUndo], matching the
/// dismiss-on-tap and single-fire behavior a [SnackBarAction] provides.
void showFeedTuningSnackbar(
  BuildContext context, {
  required FeedTuningDirection direction,
  VoidCallback? onUndo,
}) {
  final l10n = context.l10n;
  final label = direction == FeedTuningDirection.more
      ? l10n.feedTuningMoreLabel
      : l10n.feedTuningLessLabel;
  final messenger = ScaffoldMessenger.of(context)..clearSnackBars();
  messenger.showSnackBar(
    DivineSnackbarContainer.snackBar(
      label,
      duration: _feedTuningSnackbarDuration,
      actionLabel: onUndo == null ? null : l10n.feedTuningUndo,
      onActionPressed: onUndo == null
          ? null
          : () {
              messenger.removeCurrentSnackBar(
                reason: SnackBarClosedReason.action,
              );
              onUndo();
            },
    ),
  );
}
