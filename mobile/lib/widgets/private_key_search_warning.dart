// ABOUTME: Notice shown under a search field when the typed text looks like a
// ABOUTME: private key, in place of searching for it.

import 'package:divine_ui/divine_ui.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/utils/nostr_key_utils.dart';

/// Tells the user their search text looks like a private key, so it was not
/// searched for, and not to paste or share it.
///
/// Renders nothing unless [NostrKeyUtils.containsPrivateKey] matches
/// [query], so a search field can keep it in its tree and pass the live
/// text. It never shows the key back.
class PrivateKeySearchWarning extends StatelessWidget {
  const PrivateKeySearchWarning({
    required this.query,
    this.padding = EdgeInsets.zero,
    super.key,
  });

  /// The text currently in the search field.
  final String query;

  /// Space around the notice, applied only while it is shown.
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    if (!NostrKeyUtils.containsPrivateKey(query)) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: padding,
      child: Semantics(
        liveRegion: true,
        child: DivineInfoCard(
          message: context.l10n.searchPrivateKeyWarning,
          icon: DivineIconName.warning,
          tone: DivineInfoCardTone.warning,
          compact: true,
        ),
      ),
    );
  }
}
