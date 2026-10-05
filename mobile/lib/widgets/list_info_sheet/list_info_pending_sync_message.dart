// ABOUTME: Neutral feedback for video membership saved locally but not synced.
// ABOUTME: Announces the waiting state without styling it as a failed save.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:openvine/l10n/l10n.dart';

/// Indicates that local list membership is waiting for relay acceptance.
class ListInfoPendingSyncMessage extends StatelessWidget {
  /// Creates the pending sync notice.
  const ListInfoPendingSyncMessage({super.key});

  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    child: Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Text(
        context.l10n.listVideoPendingSync,
        style: VineTheme.bodyMediumFont(
          color: context.vineColors.onSurfaceVariant,
        ),
      ),
    ),
  );
}
