// ABOUTME: Confirmation shown before a list's visibility changes.
// ABOUTME: Warns what becoming public or private does to the list's videos.

import 'package:divine_ui/divine_ui.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/extensions/modal_pop_extension.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/utils/pause_aware_modals.dart';

/// Asks the owner to confirm flipping a list's visibility.
///
/// [wasPublic] is the visibility the list has now. Resolves to false when the
/// dialog is dismissed without an answer.
Future<bool> confirmListVisibilityChange(
  BuildContext context, {
  required bool wasPublic,
}) async {
  final confirmed = await context.showVideoPausingDialog<bool>(
    builder: (_) => _ListVisibilityChangeDialog(wasPublic: wasPublic),
  );
  return confirmed ?? false;
}

class _ListVisibilityChangeDialog extends StatelessWidget {
  const _ListVisibilityChangeDialog({required this.wasPublic});

  final bool wasPublic;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AlertDialog(
      backgroundColor: context.vineColors.card,
      title: Text(
        wasPublic ? l10n.listMakePrivateTitle : l10n.listMakePublicTitle,
        style: VineTheme.titleMediumFont(
          color: context.vineColors.primaryText,
        ),
      ),
      content: Text(
        wasPublic ? l10n.listMakePrivateWarning : l10n.listMakePublicWarning,
        style: VineTheme.bodyMediumFont(
          color: context.vineColors.secondaryText,
        ),
      ),
      actions: [
        DivineButton(
          label: l10n.commonCancel,
          type: DivineButtonType.link,
          onPressed: () => context.popModalIfMounted(false),
        ),
        DivineButton(
          label: l10n.listContinue,
          type: DivineButtonType.link,
          onPressed: () => context.popModalIfMounted(true),
        ),
      ],
    );
  }
}
