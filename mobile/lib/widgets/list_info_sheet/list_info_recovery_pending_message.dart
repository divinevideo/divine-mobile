// ABOUTME: Neutral feedback for confirmed list recovery or deletion delivery.
// ABOUTME: Announces pending sync without promising remote deletion or erasure.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:openvine/l10n/l10n.dart';

/// Recovery can include a confirmed permission change or pending deletion IDs.
class ListInfoRecoveryPendingMessage extends StatelessWidget {
  const ListInfoRecoveryPendingMessage({super.key});

  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    child: Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Text(
        context.l10n.listRecoveryPending,
        style: VineTheme.bodyMediumFont(
          color: context.vineColors.onSurfaceVariant,
        ),
      ),
    ),
  );
}
