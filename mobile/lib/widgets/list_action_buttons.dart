// ABOUTME: Row of buttons at the foot of a list or sound header, just above
// ABOUTME: its grid, that share the width equally up to a readable maximum.

import 'package:flutter/widgets.dart';
import 'package:openvine/ui/adaptive_layout.dart';

/// Gap between the buttons of a [ListActionButtons] row.
const kListActionButtonsSpacing = 12.0;

/// Widest a [ListActionButtons] row grows in a window with the large-screen
/// layouts; past it the row keeps to the start of the header.
const kListActionButtonsMaxWidth = 600.0;

/// Space between a list page's hero header and the video grid beneath it,
/// shared by the video-list and people-list pages.
const kListHeroBottomPadding = 20.0;

/// [buttons] side by side, each taking an equal share of the width; a lone
/// button takes all of it, and no buttons draw nothing.
///
/// With the large-screen layouts the row stops at
/// [kListActionButtonsMaxWidth], so the buttons do not stretch across a
/// tablet or desktop window.
class ListActionButtons extends StatelessWidget {
  const ListActionButtons({required this.buttons, super.key});

  final List<Widget> buttons;

  @override
  Widget build(BuildContext context) {
    if (buttons.isEmpty) return const SizedBox.shrink();
    final row = Row(
      spacing: kListActionButtonsSpacing,
      children: [for (final button in buttons) Expanded(child: button)],
    );
    if (!context.adaptiveLayout.isLargeScreen) return row;
    return Align(
      alignment: AlignmentDirectional.centerStart,
      heightFactor: 1,
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: kListActionButtonsMaxWidth,
        ),
        child: row,
      ),
    );
  }
}
