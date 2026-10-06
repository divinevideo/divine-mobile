// ABOUTME: Explains when saved video-list recovery keeps editing paused.
// ABOUTME: Leaves list browsing available while recovery records need repair.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:openvine/l10n/l10n.dart';

/// Shared notice for video-list surfaces held for verified recovery repair.
class CuratedListRecoveryReadOnlyNotice extends StatelessWidget {
  const CuratedListRecoveryReadOnlyNotice({super.key});

  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Text(
        context.l10n.listRecoveryReadOnly,
        style: VineTheme.bodyMediumFont(
          color: context.vineColors.onSurfaceVariant,
        ),
      ),
    ),
  );
}
