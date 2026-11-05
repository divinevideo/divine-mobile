// ABOUTME: Share button for a list, shown in the action row at the foot of
// ABOUTME: the video-list and people-list headers.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:openvine/l10n/l10n.dart';

/// Outline Share button that fills its slot in a [ListActionButtons] row.
class ShareListButton extends StatelessWidget {
  const ShareListButton({required this.onPressed, super.key});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return DivineButton(
      label: context.l10n.listShareButton,
      type: DivineButtonType.secondary,
      leadingIcon: DivineIconName.shareFat,
      expanded: true,
      onPressed: onPressed,
    );
  }
}
