// ABOUTME: Row of buttons at the foot of a list header, just above its grid,
// ABOUTME: that share the width equally.

import 'package:flutter/widgets.dart';

/// Gap between the buttons of a [ListActionButtons] row.
const kListActionButtonsSpacing = 12.0;

/// [buttons] side by side, each taking an equal share of the width; a lone
/// button takes all of it, and no buttons draw nothing.
class ListActionButtons extends StatelessWidget {
  const ListActionButtons({required this.buttons, super.key});

  final List<Widget> buttons;

  @override
  Widget build(BuildContext context) {
    if (buttons.isEmpty) return const SizedBox.shrink();
    return Row(
      spacing: kListActionButtonsSpacing,
      children: [for (final button in buttons) Expanded(child: button)],
    );
  }
}
