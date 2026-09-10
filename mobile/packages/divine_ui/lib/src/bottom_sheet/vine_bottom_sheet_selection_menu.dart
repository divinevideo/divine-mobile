// ABOUTME: Selection menu bottom sheet with multiple selectable options
// ABOUTME: Returns selected value when option is tapped

import 'package:divine_ui/divine_ui.dart';
import 'package:material_ui/material_ui.dart';

/// Data class representing a selectable option in the menu.
class VineBottomSheetSelectionOptionData {
  /// Creates a [VineBottomSheetSelectionOptionData].
  const VineBottomSheetSelectionOptionData({
    required this.label,
    required this.value,
    this.leadingIcon,
  });

  /// The display text for this option.
  final String label;

  /// The unique value identifier for this option.
  final String value;

  /// Optional icon displayed before the option label.
  final DivineIconName? leadingIcon;
}

/// A bottom sheet menu displaying selectable options with checkmark indicator.
///
/// Use [VineBottomSheetSelectionMenu.show] to display as a modal that returns
/// the selected value when an option is tapped.
///
/// Example:
/// ```dart
/// final selected = await VineBottomSheetSelectionMenu.show(
///   context: context,
///   selectedValue: 'new',
///   options: [
///     VineBottomSheetSelectionOptionData(label: 'New', value: 'new'),
///     VineBottomSheetSelectionOptionData(label: 'Popular', value: 'popular'),
///     VineBottomSheetSelectionOptionData(
///       label: 'Following',
///       value: 'following',
///     ),
///   ],
/// );
/// ```
class VineBottomSheetSelectionMenu {
  /// Shows the selection menu as a modal bottom sheet.
  ///
  /// Returns the selected option's value when tapped, or null if dismissed.
  static Future<String?> show({
    required BuildContext context,
    required List<VineBottomSheetSelectionOptionData> options,
    Widget? title,
    String? selectedValue,
    EdgeInsetsGeometry? headerPadding,
    DivineIconButton? headerLeadingAction,
    DivineIconButton? headerTrailingAction,
  }) {
    return VineBottomSheet.show<String>(
      context: context,
      title: title,
      expanded: false,
      scrollable: false,
      isScrollControlled: true,
      headerPadding: headerPadding,
      headerLeadingAction: headerLeadingAction,
      headerTrailingAction: headerTrailingAction,
      body: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final option in options)
              _VineBottomSheetSelectionOption(
                label: option.label,
                leadingIcon: option.leadingIcon,
                isSelected: option.value == selectedValue,
                onTap: () => Navigator.of(context).pop(option.value),
              ),
          ],
        ),
      ),
    );
  }
}

/// Private selectable option item for use in bottom sheet selection menus.
class _VineBottomSheetSelectionOption extends StatelessWidget {
  const _VineBottomSheetSelectionOption({
    required this.label,
    required this.onTap,
    this.leadingIcon,
    this.isSelected = false,
  });

  final String label;
  final DivineIconName? leadingIcon;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      selected: isSelected,
      onTap: onTap,
      excludeSemantics: true,
      child: Material(
        color: isSelected
            ? context.vineColors.surfaceContainer
            : VineTheme.transparent,
        child: InkWell(
          onTap: onTap,
          child: Container(
            height: 64,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                if (leadingIcon != null)
                  Padding(
                    padding: const EdgeInsetsDirectional.only(end: 12),
                    child: DivineIcon(
                      icon: leadingIcon!,
                      color: context.vineColors.onSurface,
                    ),
                  ),
                Expanded(
                  child: Text(
                    label,
                    style: VineTheme.titleMediumFont(
                      color: context.vineColors.onSurface,
                    ),
                  ),
                ),
                if (isSelected)
                  DivineIcon(
                    icon: .check,
                    color: context.vineColors.accentPositive,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
