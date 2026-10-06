// ABOUTME: Local recovery action for unavailable saved-list entry points.
// ABOUTME: Keeps list mutations unavailable until initialization succeeds.

import 'package:divine_ui/divine_ui.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/l10n/l10n.dart';

class CuratedListInitializationFailure extends StatelessWidget {
  const CuratedListInitializationFailure({required this.onRetry, super.key});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    spacing: 16,
    children: [
      Text(
        context.l10n.listErrorLoading,
        textAlign: TextAlign.center,
        style: VineTheme.bodyMediumFont(
          color: context.vineColors.secondaryText,
        ),
      ),
      DivineButton(
        label: context.l10n.searchTryAgain,
        type: DivineButtonType.secondary,
        size: DivineButtonSize.small,
        onPressed: onRetry,
      ),
    ],
  );
}
