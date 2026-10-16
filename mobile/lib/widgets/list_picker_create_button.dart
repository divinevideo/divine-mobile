// ABOUTME: The "Create New List" button pinned under a list picker's rows,
// ABOUTME: the same in the video picker and the person picker.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:openvine/l10n/l10n.dart';

/// The full-width secondary button that opens a list's create sheet.
///
/// Goes in the picker sheet's bottom slot, which keeps it below the rows at
/// every height the sheet is dragged to and clear of the home indicator.
class ListPickerCreateButton extends StatelessWidget {
  /// Creates the button.
  const ListPickerCreateButton({required this.onPressed, super.key});

  /// Opens the create sheet; null while nothing may be created.
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: DivineButton(
        label: context.l10n.listCreateNewList,
        type: DivineButtonType.secondary,
        leadingIcon: DivineIconName.plus,
        expanded: true,
        onPressed: onPressed,
      ),
    );
  }
}
